# Demo 07 — Right-Sizing & Cost Impact Analysis

**Quarkus 3.33.1 LTS / Java 21**

A complete right-sizing exercise: observe actual resource usage, generate
recommendations, model bin-packing improvements, and build a business case.

---

## Run the Demo

```bash
chmod +x demo.sh cost-calculator.sh
./demo.sh
```

## What's Running

```
app-over       :8080  cpu: 2000m  mem: 2048Mi  (over-provisioned)
app-rightsized :8081  cpu:  250m  mem:  512Mi  (right-sized)
Prometheus     :9090  scrapes both every 5s
```

Same Quarkus app. Same load. Identical actual usage. The gap = waste = money.

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

## Tools

### rightsizing-analysis.py

```bash
python3 rightsizing-analysis.py
python3 rightsizing-analysis.py --node-type m5.4xlarge --node-count 50 --pod-count 400
```

Queries Prometheus, computes waste, generates YAML recommendations, models
bin-packing improvement, calculates infrastructure and engineering time savings.

Node types: `m5.xlarge`, `m5.2xlarge`, `m5.4xlarge`, `m5.8xlarge`, `n2-standard-8`,
`n2-standard-16`, `Standard_D8s_v3`, `custom`.

### cost-calculator.sh

```bash
bash cost-calculator.sh
```

Interactive — enter your cluster node count, instance type, actual usage,
and OOMKill rate. Outputs infrastructure savings, engineering savings,
payback period, and 5-year NPV.

---

## Business Case Formula

```
Annual savings = (current_nodes − right_sized_nodes) × node_cost_hr × 8,760
              + oomkills_per_month × mttr_hours × eng_cost_hr × 12

Payback period = implementation_cost / annual_savings × 365
```

Typical results: $150K–$500K/year infra savings, payback < 10 days.

---

## OpenShift Cost Management

`console.redhat.com/openshift/cost-management` — free with subscription.

- **Optimisation Advisor**: automated right-sizing recommendations with savings
- **Cost allocation**: breaks infrastructure cost down to namespace for chargeback
- **Showback reports**: monthly exports for budget conversations

Without OpenShift: Kubecost, OpenCost (CNCF), AWS Cost Explorer for EKS.

---

## Endpoints

| Endpoint | Description |
|----------|-------------|
| `GET /process?items=N` | Simulate N business transactions |
| `GET /metrics-snapshot` | JVM heap, GC, threads snapshot |
| `GET /q/health/live` | Liveness probe |
| `GET /q/metrics` | Prometheus metrics |

---

## Reference

- VPA: https://github.com/kubernetes/autoscaler/tree/master/vertical-pod-autoscaler
- OpenCost: https://opencost.io
- Kubecost: https://kubecost.com
- *Optimizing Cloud Native Java* (O'Reilly)
