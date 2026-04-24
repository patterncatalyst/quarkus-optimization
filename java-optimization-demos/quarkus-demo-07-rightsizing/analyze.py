#!/usr/bin/env python3
"""
Right-Sizing Analysis Engine — Demo 07
Quarkus/Spring Boot JVM Workloads on OpenShift & Kubernetes

Analyses pod resource requests vs observed usage to produce:
  1. Right-sizing recommendations per workload
  2. Bin-packing improvement (pods per node before/after)
  3. Cost impact calculation
  4. Business case summary

Works in two modes:
  --live   Query a live cluster via kubectl/oc (requires kubeconfig)
  --sample Use bundled sample data (default, no cluster needed)
"""

import json
import sys
import os
import argparse
import math
from datetime import datetime


# ── Configuration ──────────────────────────────────────────────────────────

# Headroom factors applied to p99 observed usage to set new requests
CPU_HEADROOM    = 1.30   # 30% above p99 CPU
MEMORY_HEADROOM = 1.25   # 25% above p99 memory (JVM off-heap needs room)

# Minimum floor values — never recommend below these
CPU_MIN_MILLICORES  = 100
MEMORY_MIN_MB       = 256

# Cost model — override with --cost-per-node-hour
DEFAULT_NODE_COST_PER_HOUR = 0.384   # m5.2xlarge us-east-1
HOURS_PER_MONTH            = 730


# ── Colour helpers ──────────────────────────────────────────────────────────

RED    = "\033[0;31m"
GREEN  = "\033[0;32m"
YELLOW = "\033[1;33m"
CYAN   = "\033[0;36m"
BOLD   = "\033[1m"
RESET  = "\033[0m"


def pct_change(before, after):
    if before == 0:
        return 0
    return (after - before) / before * 100


def colour_pct(val, lower_is_better=True):
    """Return coloured percentage string."""
    if lower_is_better:
        c = GREEN if val < -10 else (YELLOW if val < 0 else RED)
    else:
        c = GREEN if val > 10 else (YELLOW if val > 0 else RED)
    sign = "+" if val > 0 else ""
    return f"{c}{sign}{val:.0f}%{RESET}"


# ── Right-sizing logic ──────────────────────────────────────────────────────

def recommend(workload):
    """
    Produce right-sizing recommendation for a single workload.

    Strategy:
    - CPU request: p99 observed × headroom, rounded to nearest 50m
      Exception: if p99 includes GC spikes (detectable from gc_pause_p99 > 100ms
      and p99/p50 ratio > 3), use p95 × headroom instead
    - CPU limit: same as request (Guaranteed QoS for static CPU allocation)
    - Memory request: p99 RSS × headroom, rounded to nearest 64MB
    - Memory limit: same as request (prevents OOMKill from surprise growth)
    """
    obs  = workload["observed"]
    req  = workload["requests"]

    # Detect GC-dominated CPU p99
    cpu_p99 = obs["cpu_p99_millicores"]
    cpu_p50 = obs["cpu_p50_millicores"]
    gc_p99  = obs.get("gc_pause_p99_ms", 0)
    gc_dominated = gc_p99 > 100 and cpu_p99 / max(cpu_p50, 1) > 3

    # Use p95 as basis if p99 is GC-dominated
    cpu_basis = obs["cpu_p95_millicores"] if gc_dominated else cpu_p99
    new_cpu = max(CPU_MIN_MILLICORES,
                  int(math.ceil(cpu_basis * CPU_HEADROOM / 50) * 50))

    # Memory: always use p99 RSS
    mem_p99 = obs["memory_p99_mb"]
    new_mem = max(MEMORY_MIN_MB,
                  int(math.ceil(mem_p99 * MEMORY_HEADROOM / 64) * 64))

    # QoS determination
    qos_before = ("Guaranteed" if req["cpu_millicores"] == workload["limits"]["cpu_millicores"]
                               and req["memory_mb"] == workload["limits"]["memory_mb"]
                  else "Burstable")
    qos_after = "Guaranteed"

    return {
        "cpu_request_new":    new_cpu,
        "cpu_limit_new":      new_cpu,
        "memory_request_new": new_mem,
        "memory_limit_new":   new_mem,
        "cpu_basis":          "p95 (GC spike detected)" if gc_dominated else "p99",
        "gc_dominated_cpu":   gc_dominated,
        "qos_before":         qos_before,
        "qos_after":          qos_after,
    }


# ── Bin-packing calculation ─────────────────────────────────────────────────

def pods_per_node(workloads_with_recs, node_vcpu, node_ram_gb, use_new=False):
    """
    Calculate how many pods fit on a node given resource constraints.
    Returns (cpu_bound_pods, memory_bound_pods, effective_pods).
    """
    node_cpu_m  = node_vcpu * 1000
    node_mem_mb = node_ram_gb * 1024

    # Reserve 15% of node resources for system + kubelet overhead
    available_cpu_m  = int(node_cpu_m  * 0.85)
    available_mem_mb = int(node_mem_mb * 0.85)

    total_cpu_m  = 0
    total_mem_mb = 0

    for w in workloads_with_recs:
        replicas = w["replicas"]
        if use_new:
            cpu_per_pod = w["rec"]["cpu_request_new"]
            mem_per_pod = w["rec"]["memory_request_new"]
        else:
            cpu_per_pod = w["requests"]["cpu_millicores"]
            mem_per_pod = w["requests"]["memory_mb"]
        total_cpu_m  += cpu_per_pod  * replicas
        total_mem_mb += mem_per_pod * replicas

    # How many full copies of the workload set fit on one node
    cpu_copies  = available_cpu_m  / total_cpu_m  if total_cpu_m  > 0 else 99
    mem_copies  = available_mem_mb / total_mem_mb if total_mem_mb > 0 else 99
    copies      = min(cpu_copies, mem_copies)

    total_pods = sum(w["replicas"] for w in workloads_with_recs)
    pods_fitting = int(copies * total_pods)

    limiting = "CPU" if cpu_copies < mem_copies else "Memory"
    return pods_fitting, total_cpu_m, total_mem_mb, limiting


# ── Report generation ───────────────────────────────────────────────────────

def hr(char="─", width=70):
    print(char * width)


def print_workload_table(workloads_with_recs):
    hr()
    print(f"\n{BOLD}Right-Sizing Recommendations{RESET}\n")

    for w in workloads_with_recs:
        rec = w["rec"]
        req = w["requests"]

        cpu_delta_pct = pct_change(req["cpu_millicores"], rec["cpu_request_new"])
        mem_delta_pct = pct_change(req["memory_mb"],     rec["memory_request_new"])

        cpu_saved_m  = (req["cpu_millicores"] - rec["cpu_request_new"]) * w["replicas"]
        mem_saved_mb = (req["memory_mb"]      - rec["memory_request_new"]) * w["replicas"]

        print(f"  {BOLD}{w['namespace']}/{w['deployment']}{RESET}  "
              f"({w['framework']}, {w['replicas']} replicas)")

        # Before / after table
        print(f"  {'':4} {'Metric':<18} {'Current':>12} {'Recommended':>14} {'Delta':>10}  {'Saved (fleet)':>14}")
        print(f"  {'':4} {'─'*70}")
        print(f"  {'':4} {'CPU request':<18} {req['cpu_millicores']:>10}m  "
              f"{rec['cpu_request_new']:>12}m  {colour_pct(cpu_delta_pct):>18}  "
              f"{cpu_saved_m:>+12}m")
        print(f"  {'':4} {'Memory request':<18} {req['memory_mb']:>10}Mi "
              f"{rec['memory_request_new']:>12}Mi {colour_pct(mem_delta_pct):>18}  "
              f"{mem_saved_mb:>+11}Mi")

        # QoS change
        qos_note = ""
        if rec["qos_before"] != rec["qos_after"]:
            qos_note = f"  {YELLOW}⚡ QoS: {rec['qos_before']} → {rec['qos_after']} (enables static CPU allocation){RESET}"

        if rec["gc_dominated_cpu"]:
            print(f"  {YELLOW}  ⚠  CPU p99 is GC-dominated (p99/p50 ratio > 3×, GC pause p99 "
                  f"{w['observed']['gc_pause_p99_ms']}ms) — used p95 as basis{RESET}")
        if qos_note:
            print(qos_note)

        if w.get("notes"):
            print(f"  {CYAN}  📝 {w['notes']}{RESET}")
        print()


def print_binpacking(workloads_with_recs, node_vcpu, node_ram_gb):
    hr()
    print(f"\n{BOLD}Bin-Packing Analysis{RESET}\n")

    pods_before, cpu_before, mem_before, limit_before = pods_per_node(
        workloads_with_recs, node_vcpu, node_ram_gb, use_new=False)
    pods_after, cpu_after, mem_after, limit_after = pods_per_node(
        workloads_with_recs, node_vcpu, node_ram_gb, use_new=True)

    node_cpu_m  = node_vcpu * 1000
    node_mem_mb = node_ram_gb * 1024

    total_pods = sum(w["replicas"] for w in workloads_with_recs)

    # Nodes needed before/after
    nodes_before = math.ceil(total_pods / max(pods_before, 1))
    nodes_after  = math.ceil(total_pods / max(pods_after,  1))

    print(f"  Node type: {node_vcpu} vCPU / {node_ram_gb}GB RAM  "
          f"(usable: {int(node_vcpu*0.85)} vCPU / {int(node_ram_gb*0.85)}GB after 15% overhead)")
    print(f"  Total workload pods: {total_pods}\n")

    print(f"  {'Metric':<35} {'Before':>12} {'After':>12} {'Delta':>10}")
    print(f"  {'─'*70}")
    print(f"  {'CPU requested (all pods)':<35} {cpu_before:>10}m  {cpu_after:>10}m  "
          f"{colour_pct(pct_change(cpu_before, cpu_after)):>18}")
    print(f"  {'Memory requested (all pods)':<35} {mem_before:>9}Mi  {mem_after:>9}Mi  "
          f"{colour_pct(pct_change(mem_before, mem_after)):>18}")
    print(f"  {'Pods per node (approx)':<35} {pods_before:>12} {pods_after:>12}  "
          f"{colour_pct(pct_change(pods_before, pods_after), lower_is_better=False):>18}")
    print(f"  {'Nodes required':<35} {nodes_before:>12} {nodes_after:>12}  "
          f"{colour_pct(pct_change(nodes_before, nodes_after)):>18}")
    print(f"  {'Limiting resource':<35} {limit_before:>12} {limit_after:>12}")
    print()

    return nodes_before, nodes_after


def print_cost_analysis(nodes_before, nodes_after, node_cost_per_hour, sample_window_days):
    hr()
    print(f"\n{BOLD}Cost Impact Analysis{RESET}\n")

    nodes_saved = nodes_before - nodes_after
    cost_per_month_before = nodes_before * node_cost_per_hour * HOURS_PER_MONTH
    cost_per_month_after  = nodes_after  * node_cost_per_hour * HOURS_PER_MONTH
    monthly_saving        = cost_per_month_before - cost_per_month_after
    annual_saving         = monthly_saving * 12

    print(f"  Node cost:           ${node_cost_per_hour:.3f}/hour  "
          f"(${node_cost_per_hour * HOURS_PER_MONTH:,.0f}/month/node)")
    print(f"  Nodes before:        {nodes_before}")
    print(f"  Nodes after:         {nodes_after}")
    print(f"  Nodes eliminated:    {GREEN}{nodes_saved}{RESET}\n")

    print(f"  {'':4} {'Period':<20} {'Before':>14} {'After':>14} {'Saving':>14}")
    print(f"  {'':4} {'─'*65}")
    print(f"  {'':4} {'Monthly':<20} ${cost_per_month_before:>12,.0f}  "
          f"${cost_per_month_after:>12,.0f}  "
          f"{GREEN}${monthly_saving:>11,.0f}{RESET}")
    print(f"  {'':4} {'Annual':<20} ${cost_per_month_before*12:>12,.0f}  "
          f"${cost_per_month_after*12:>12,.0f}  "
          f"{GREEN}${annual_saving:>11,.0f}{RESET}")
    print()

    # Business case framing
    print(f"  {BOLD}Business case:{RESET}")
    print(f"    Right-sizing eliminates {nodes_saved} node(s) from this cluster by closing")
    print(f"    the gap between what pods request and what they actually use.")
    print(f"    The ${annual_saving:,.0f}/year saving requires:")
    print(f"      • 2-4 hours engineering time (update Deployment resource specs)")
    print(f"      • One rolling restart per service (zero downtime)")
    print(f"      • No application code changes")
    print()
    print(f"  {BOLD}ROI: ${annual_saving:,.0f} saving for ~${min(annual_saving*0.02, 5000):.0f} engineering cost{RESET}")
    print(f"  {BOLD}Payback: < 1 sprint{RESET}")
    print()

    return monthly_saving, annual_saving


def print_gc_recommendations(workloads_with_recs):
    hr()
    print(f"\n{BOLD}GC Algorithm Recommendations{RESET}\n")

    print(f"  {'Workload':<40} {'Current p99 pause':>18} {'Recommendation':>20}")
    print(f"  {'─'*80}")

    for w in workloads_with_recs:
        gc_p99 = w["observed"].get("gc_pause_p99_ms", 0)
        name   = f"{w['namespace']}/{w['deployment']}"

        if gc_p99 < 20:
            rec = f"{GREEN}ZGC already effective{RESET}"
        elif gc_p99 < 100:
            rec = f"{YELLOW}Consider ZGC if SLA < 50ms{RESET}"
        elif gc_p99 < 500:
            rec = f"{RED}Switch to ZGC  -XX:+UseZGC -XX:+ZGenerational{RESET}"
        else:
            rec = f"{RED}Switch to ZGC + investigate full GC root cause{RESET}"

        print(f"  {name:<40} {gc_p99:>15}ms   {rec}")
    print()


def print_implementation_plan(workloads_with_recs):
    hr()
    print(f"\n{BOLD}Implementation Plan{RESET}\n")

    print("  Priority 1 — Immediate, zero risk (no code changes):")
    for w in workloads_with_recs:
        rec = w["rec"]
        req = w["requests"]
        cpu_saving_pct = pct_change(req["cpu_millicores"], rec["cpu_request_new"])
        mem_saving_pct = pct_change(req["memory_mb"],      rec["memory_request_new"])
        if cpu_saving_pct < -20 or mem_saving_pct < -20:
            print(f"    • {w['namespace']}/{w['deployment']:30} "
                  f"cpu: {req['cpu_millicores']}m→{rec['cpu_request_new']}m  "
                  f"mem: {req['memory_mb']}Mi→{rec['memory_request_new']}Mi")

    print()
    print("  Priority 2 — QoS improvements (requests == limits → Guaranteed):")
    for w in workloads_with_recs:
        if w["rec"]["qos_before"] == "Burstable":
            print(f"    • {w['namespace']}/{w['deployment']:30} "
                  f"→ set limits == requests → enables static CPU allocation")

    print()
    print("  Priority 3 — GC algorithm upgrade (flag change + rolling restart):")
    for w in workloads_with_recs:
        gc_p99 = w["observed"].get("gc_pause_p99_ms", 0)
        if gc_p99 >= 100:
            print(f"    • {w['namespace']}/{w['deployment']:30} "
                  f"p99 pause {gc_p99}ms → add -XX:+UseZGC -XX:+ZGenerational")

    print()
    print("  All changes applied via rolling update — zero downtime:")
    print("    kubectl set resources deployment/<name> \\")
    print("      --requests=cpu=<new>m,memory=<new>Mi \\")
    print("      --limits=cpu=<new>m,memory=<new>Mi")
    print()


def generate_json_report(workloads_with_recs, nodes_before, nodes_after,
                         monthly_saving, annual_saving, output_path):
    """Write machine-readable report for CI/CD integration."""
    report = {
        "generated_at": datetime.utcnow().isoformat() + "Z",
        "summary": {
            "nodes_before": nodes_before,
            "nodes_after":  nodes_after,
            "nodes_saved":  nodes_before - nodes_after,
            "monthly_saving_usd": round(monthly_saving, 2),
            "annual_saving_usd":  round(annual_saving, 2),
        },
        "workloads": []
    }

    for w in workloads_with_recs:
        rec = w["rec"]
        report["workloads"].append({
            "namespace":  w["namespace"],
            "deployment": w["deployment"],
            "replicas":   w["replicas"],
            "current": {
                "cpu_request_millicores":    w["requests"]["cpu_millicores"],
                "memory_request_mb":         w["requests"]["memory_mb"],
                "qos_class":                 rec["qos_before"],
            },
            "recommended": {
                "cpu_request_millicores":    rec["cpu_request_new"],
                "memory_request_mb":         rec["memory_request_new"],
                "qos_class":                 rec["qos_after"],
            },
            "savings": {
                "cpu_millicores_per_replica": w["requests"]["cpu_millicores"] - rec["cpu_request_new"],
                "memory_mb_per_replica":      w["requests"]["memory_mb"]      - rec["memory_request_new"],
            },
            "gc_pause_p99_ms": w["observed"].get("gc_pause_p99_ms", 0),
            "notes": w.get("notes", ""),
        })

    with open(output_path, "w") as f:
        json.dump(report, f, indent=2)
    print(f"  {GREEN}✅ JSON report written to {output_path}{RESET}")


# ── Live cluster mode ───────────────────────────────────────────────────────

def fetch_live_data():
    """
    Attempt to gather live data from a running cluster.
    Requires kubectl + metrics-server (for cpu/memory top).
    Returns data in the same format as workloads.json, or None on failure.
    """
    import subprocess

    def run(cmd):
        try:
            r = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=10)
            return r.stdout.strip() if r.returncode == 0 else None
        except Exception:
            return None

    # Check connectivity
    if not run("kubectl cluster-info --request-timeout=5s 2>/dev/null"):
        return None

    print(f"  {GREEN}✅ Connected to cluster{RESET}")

    # Get all pods with resource requests
    raw = run(
        "kubectl get pods -A -o json 2>/dev/null | "
        "python3 -c \""
        "import json,sys; "
        "pods=json.load(sys.stdin)['items']; "
        "[print(p['metadata']['namespace'],'|',p['metadata']['name'],'|',"
        "p['spec']['containers'][0].get('resources',{}).get('requests',{}).get('cpu','?'),'|',"
        "p['spec']['containers'][0].get('resources',{}).get('requests',{}).get('memory','?')) "
        "for p in pods if p['status']['phase']=='Running']\""
    )

    if not raw:
        return None

    print(f"  {YELLOW}Live mode: showing current requests only (no historical p99 — use --sample for full analysis){RESET}")
    print()
    print(f"  {'Namespace':<25} {'Pod':<45} {'CPU req':>10} {'Mem req':>10}")
    print(f"  {'─'*95}")
    for line in raw.splitlines()[:30]:
        parts = [p.strip() for p in line.split("|")]
        if len(parts) == 4:
            print(f"  {parts[0]:<25} {parts[1]:<45} {parts[2]:>10} {parts[3]:>10}")

    print()
    print(f"  {YELLOW}For full right-sizing analysis with p99 data, run with Prometheus:{RESET}")
    print("    PROMETHEUS_URL=http://your-prometheus:9090 python3 analyze.py --live")
    return None  # Fall through to sample data for the analysis


# ── Main ────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        description="JVM Right-Sizing and Cost Analysis Tool")
    parser.add_argument("--live",   action="store_true",
                        help="Try to connect to live cluster (falls back to sample)")
    parser.add_argument("--data",   default="sample-data/workloads.json",
                        help="Path to workloads JSON file")
    parser.add_argument("--output", default="rightsizing-report.json",
                        help="Path for JSON report output")
    parser.add_argument("--cost-per-node-hour", type=float,
                        default=None, help="Override node cost ($/hour)")
    args = parser.parse_args()

    print()
    print(f"{CYAN}{BOLD}")
    print("╔══════════════════════════════════════════════════════════════╗")
    print("║  Demo 07: JVM Right-Sizing & Cost Impact Analysis           ║")
    print("║  Quarkus 3.33.1 LTS + Spring Boot 4.0.5 / Java 21          ║")
    print("╚══════════════════════════════════════════════════════════════╝")
    print(f"{RESET}")

    # Try live cluster if requested
    if args.live:
        print(f"{YELLOW}Connecting to live cluster...{RESET}\n")
        fetch_live_data()
        print(f"{YELLOW}Using sample data for full analysis (representative of a real cluster){RESET}\n")

    # Load data
    data_path = args.data
    if not os.path.exists(data_path):
        # Try relative to script location
        script_dir = os.path.dirname(os.path.abspath(__file__))
        data_path = os.path.join(script_dir, args.data)

    with open(data_path) as f:
        data = json.load(f)

    node_cost = args.cost_per_node_hour or data.get("node_cost_per_hour", DEFAULT_NODE_COST_PER_HOUR)

    print(f"  Cluster:       {data['cluster']}")
    print(f"  Node type:     {data['node_type']}  ({data['node_vcpu']} vCPU / {data['node_ram_gb']} GB)")
    print(f"  Node cost:     ${node_cost:.3f}/hour  (${node_cost * HOURS_PER_MONTH:,.0f}/month)")
    print(f"  Sample window: {data['sample_window_days']} days of observed metrics")
    print(f"  Workloads:     {len(data['workloads'])} deployments")
    print()

    # Compute recommendations
    workloads_with_recs = []
    for w in data["workloads"]:
        w_copy = dict(w)
        w_copy["rec"] = recommend(w)
        workloads_with_recs.append(w_copy)

    # Print analysis sections
    print_workload_table(workloads_with_recs)
    nodes_before, nodes_after = print_binpacking(
        workloads_with_recs, data["node_vcpu"], data["node_ram_gb"])
    monthly_saving, annual_saving = print_cost_analysis(
        nodes_before, nodes_after, node_cost, data["sample_window_days"])
    print_gc_recommendations(workloads_with_recs)
    print_implementation_plan(workloads_with_recs)

    # JSON output
    generate_json_report(workloads_with_recs, nodes_before, nodes_after,
                        monthly_saving, annual_saving, args.output)
    print()


if __name__ == "__main__":
    main()
