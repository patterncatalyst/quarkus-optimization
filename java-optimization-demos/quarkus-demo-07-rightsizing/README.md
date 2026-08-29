# Demo 07 — Right-Sizing & Cost Impact Analysis

**Quarkus 3.33.1 LTS / Java 25**

A complete right-sizing exercise: observe actual resource usage, generate
recommendations, model bin-packing improvements, and build a business case.

---

## Run the Demo

```bash
chmod +x demo.sh
./demo.sh            # analyze bundled 14-day sample data (7 workloads)
./demo.sh --live     # optional: pull live usage from the current cluster via kubectl
```

## What it does

This demo is a **pure analysis tool — no containers, no ports, no network required.**
`demo.sh` runs `analyze.py` over a bundled 14-day Prometheus export
(`sample-data/workloads.json`, 7 representative workloads). It computes actual
p95/p99 usage, generates right-sizing recommendations (GC-aware), models
bin-packing improvement, and prints the fleet-level cost impact.

`--live` mode reads real usage from the current cluster via `kubectl` instead of
the sample data.

---

## The Methodology

### Step 1 — Observe (1–2 weeks minimum)

Run VPA in Off mode, then query Prometheus:

```promql
# CPU p95 over 2 weeks
quantile_over_time(0.95, rate(container_cpu_usage_seconds_total[5m])[2w:5m])

# Memory p99 RSS over 2 weeks
quantile_over_time(0.99, container_memory_working_set_bytes[2w:5m])
```

### Step 2 — Calculate

```
CPU request  = p95 actual × 1.30    (30% headroom)
CPU limit    = OMIT                 (throttling hurts JVM more than contention)
Memory req   = p99 RSS × 1.25      (25% headroom)
Memory limit = memory request × 1.20
```

**Why no CPU limit?** JIT compilation and GC threads cause legitimate bursts.
Throttling extends GC pauses, slows JIT warmup, and breaks rollouts.

**Why p95 CPU but p99 memory?** CPU is compressible — throttle slows the pod.
Memory is non-compressible — exceeding the limit causes an immediate OOMKill.

### Step 3 — Apply

```yaml
resources:
  requests:
    cpu: "250m"      # was 2000m
    memory: "512Mi"  # was 2Gi
  limits:
    # cpu: intentionally omitted
    memory: "614Mi"  # 512Mi × 1.2
```

### Step 4 — Measure and repeat quarterly

---

## Tool

### analyze.py

`demo.sh` invokes this; you can also run it directly:

```bash
python3 analyze.py                              # bundled sample data
python3 analyze.py --live                        # pull usage from the live cluster (kubectl)
python3 analyze.py --data sample-data/workloads.json --output rightsizing-report.json
python3 analyze.py --cost-per-node-hour 0.384    # override node price for savings math
```

Flags: `--live`, `--data <file>` (default `sample-data/workloads.json`),
`--output <file>` (default `rightsizing-report.json`), `--cost-per-node-hour <float>`.
Node type and cost come from the data file (or `--cost-per-node-hour`), not CLI flags.

Computes p95/p99 waste, generates YAML recommendations, models bin-packing
improvement, and calculates infrastructure + engineering-time savings. Python 3
stdlib only — no pip installs.

---

## Business Case Formula

```
Annual savings = (current_nodes − right_sized_nodes) × node_cost_hr × 8,760
              + oomkills_per_month × mttr_hours × eng_cost_hr × 12

Payback period = implementation_cost / annual_savings × 365
```

Typical results: $13,455/year on this 7-service demo dataset (payback < 10 days); ~$38K/yr at 20 services (labeled extrapolation).

---

## OpenShift Cost Management

`console.redhat.com/openshift/cost-management` — free with subscription.

- **Optimisation Advisor**: automated right-sizing recommendations with savings
- **Cost allocation**: breaks infrastructure cost down to namespace for chargeback
- **Showback reports**: monthly exports for budget conversations

Without OpenShift: Kubecost, OpenCost (CNCF), AWS Cost Explorer for EKS.

---

## Reference

- VPA: https://github.com/kubernetes/autoscaler/tree/master/vertical-pod-autoscaler
- OpenCost: https://opencost.io
- Kubecost: https://kubecost.com
- *Optimizing Cloud Native Java* (O'Reilly)
