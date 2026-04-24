#!/usr/bin/env bash
# ============================================================
# Demo 07: JVM Right-Sizing & Cost Impact Analysis
# Quarkus 3.33.1 LTS + Spring Boot 4.0.5 / Java 21
#
# Pure analysis tool — no containers, no network access needed.
# Uses bundled sample data (14-day Prometheus export, 7 workloads)
# or connects to a live cluster via kubectl.
#
# Prerequisites:
#   python3   — stdlib only, no pip installs required
#   kubectl   — optional, for --live mode
#
# Run: ./demo.sh [--live]
# ============================================================

set -e

CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
RESET='\033[0m'

hr() { printf "%0.s─" {1..65}; echo; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LIVE_FLAG=""
[ "$1" = "--live" ] && LIVE_FLAG="--live"

echo
echo -e "${CYAN}${BOLD}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  DEMO 07: Right-Sizing & Cost Impact Analysis               ║"
echo "║  Quarkus 3.33.1 LTS + Spring Boot 4.0.5 / Java 21          ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${RESET}"

# ── Step 1: Context ───────────────────────────────────────────────────
hr
echo -e "${YELLOW}Step 1: The over-provisioning problem${RESET}"
hr
echo
echo "  The typical Java team sets resource requests like this:"
echo "    • Xmx = 2GB  →  set memory request to 3GB  (50% safety buffer)"
echo "    • See CPU spike during GC  →  set CPU request to the GC peak"
echo "    • Fear of OOMKill  →  double the number and never revisit it"
echo
echo "  After 14 days of real traffic, the data tells a different story."
echo "  The analysis below uses p99 observed usage + 25-30% headroom,"
echo "  which is more than sufficient and based on evidence not fear."
echo

read -p "  Press Enter to run the analysis..."
echo

# ── Step 2: Run analysis ──────────────────────────────────────────────
hr
echo -e "${YELLOW}Step 2: Running right-sizing analysis${RESET}"
hr
echo
cd "$SCRIPT_DIR"
python3 analyze.py $LIVE_FLAG \
  --data sample-data/workloads.json \
  --output /tmp/rightsizing-report.json
echo

# ── Step 3: Show JSON report ──────────────────────────────────────────
hr
echo -e "${YELLOW}Step 3: Machine-readable report (for CI/CD integration)${RESET}"
hr
echo
echo -e "${CYAN}  /tmp/rightsizing-report.json summary:${RESET}"
python3 - << 'PYEOF'
import json
with open("/tmp/rightsizing-report.json") as f:
    r = json.load(f)
s = r["summary"]
print(f"    nodes_before:         {s['nodes_before']}")
print(f"    nodes_after:          {s['nodes_after']}")
print(f"    nodes_saved:          {s['nodes_saved']}")
print(f"    monthly_saving_usd:   ${s['monthly_saving_usd']:,.2f}")
print(f"    annual_saving_usd:    ${s['annual_saving_usd']:,.2f}")
print()
print("    Per-workload recommendations:")
for w in r["workloads"]:
    cur = w["current"]
    rec = w["recommended"]
    cpu_d = rec["cpu_request_millicores"] - cur["cpu_request_millicores"]
    mem_d = rec["memory_request_mb"]      - cur["memory_request_mb"]
    print(f"      {w['namespace']}/{w['deployment']:<30}  "
          f"cpu: {cur['cpu_request_millicores']:>5}m → {rec['cpu_request_millicores']:>4}m ({cpu_d:+}m)  "
          f"mem: {cur['memory_request_mb']:>5}Mi → {rec['memory_request_mb']:>4}Mi ({mem_d:+}Mi)")
PYEOF
echo

# ── Step 4: kubectl commands ──────────────────────────────────────────
hr
echo -e "${YELLOW}Step 4: Generated kubectl commands — ready to apply${RESET}"
hr
echo
python3 - << 'PYEOF'
import json
with open("/tmp/rightsizing-report.json") as f:
    r = json.load(f)
for w in r["workloads"]:
    rec = w["recommended"]
    print(f"  kubectl set resources deployment/{w['deployment']} \\")
    print(f"    --namespace={w['namespace']} \\")
    print(f"    --requests=cpu={rec['cpu_request_millicores']}m,memory={rec['memory_request_mb']}Mi \\")
    print(f"    --limits=cpu={rec['cpu_request_millicores']}m,memory={rec['memory_request_mb']}Mi")
    print()
PYEOF

# ── Step 5: OpenShift Cost Management context ─────────────────────────
hr
echo -e "${YELLOW}Step 5: OpenShift Cost Management integration${RESET}"
hr
echo
cat << 'COST'
  OpenShift Cost Management (powered by Cost Management Operator + Koku)
  provides this analysis at cluster scale, automatically:

  UI:  OpenShift Console → Cost Management → Optimizations tab
       → workloads ranked by saving potential, kubectl commands generated

  API: GET /api/cost-management/v1/recommendations/openshift/
       → machine-readable recommendations for all namespaces

  What it adds on top of this demo:
    • Historical cost trend (did last sprint's change reduce spend?)
    • Chargeback: cost per namespace / team / label
    • Idle cost: nodes running but pods underutilising them
    • Commitment coverage: on-demand vs reserved/savings plan split

  PromQL queries to run this analysis on any Prometheus:
    # CPU waste per pod (requested minus average used):
    kube_pod_container_resource_requests{resource="cpu"}
      - on(pod, namespace) avg_over_time(
          container_cpu_usage_seconds_total[14d])

    # Memory waste per pod:
    kube_pod_container_resource_requests{resource="memory"}
      - on(pod, namespace) avg_over_time(
          container_memory_working_set_bytes[14d])
COST
echo

echo -e "${GREEN}${BOLD}✅ Demo 07 complete${RESET}"
echo
echo "  Output: /tmp/rightsizing-report.json"
echo
