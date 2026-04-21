# Demo 06 — Low-Latency JVM: G1GC vs ZGC

**Quarkus 3.33.1 LTS / Java 21**

Two identical Quarkus applications run simultaneously under identical GC
pressure. The only difference is the garbage collector. This demo shows
why that choice matters for p99 SLAs and HPA stability — and explains
the honest result when ZGC appears slower in a throughput test.

---

## Run the Demo

```bash
chmod +x demo.sh
./demo.sh
```

**Optional — for the Step 6 throughput comparison:**
```bash
brew install hey       # macOS
# Linux: https://github.com/rakyll/hey/releases
```

---

## What's Running

```
┌────────────────────────────────────────┐
│  G1GC app   → http://localhost:8080    │
│  -XX:+UseG1GC                          │
│  Stop-the-world: 50–300ms pauses       │
├────────────────────────────────────────┤
│  ZGC app    → http://localhost:8081    │
│  -XX:+UseZGC -XX:+ZGenerational       │
│  Concurrent: < 1ms pauses always      │
├────────────────────────────────────────┤
│  Prometheus → http://localhost:9090    │
│  Scrapes both apps every 5s           │
└────────────────────────────────────────┘
Same code. Same heap (75% of 512MB). Different GC.
```

---

## Why ZGC Appears Slower in Load Tests (and Why That's Fine)

You will likely see ZGC showing **lower throughput and higher average
latency** than G1GC in Step 6 (the `hey` load test). This is expected,
honest, and worth explaining to your audience.

### The load barrier cost

ZGC's concurrent design requires inserting a **load barrier** at every
point where application code reads an object reference from the heap.
When ZGC is relocating objects concurrently, the barrier checks whether
the reference is stale and transparently updates it. This overhead is
present on every object read, all the time — not just during GC.

G1GC has no equivalent constant overhead. It pays its cost differently:
by stopping all application threads for tens to hundreds of milliseconds
when a collection runs.

In a micro-benchmark like `/pressure` that allocates and reads many byte
arrays in a tight loop, you maximise the load barrier hit rate. ZGC pays
more per object access, which shows up as lower rps and higher average
latency in `hey`.

### What actually matters for SLAs

The `hey` p99 measures **total request duration**, which includes wall
time during allocation, GC time, and application logic. It blends the
load barrier overhead with everything else.

The number that matters for SLAs is the **GC pause delta** — how much
cumulative time application threads were completely stopped, serving zero
requests. This is what Steps 4 and 5 measure:

| Metric | G1GC | ZGC |
|--------|------|-----|
| `hey` throughput | ✅ Higher | Lower (load barrier cost) |
| `hey` p99 latency | Lower | Higher (load barrier cost) |
| **GC pause delta** | **50–300ms per run** | **~0ms per run** |
| Application frozen for | Tens to hundreds of ms | Never |
| Will breach a 50ms p99 SLA? | **Yes, on every major GC** | No |

### The on-stage framing

> "ZGC is slower in total throughput here — that's the load barrier
> cost, and it's real. But G1GC froze the application for [N]ms during
> that test. ZGC froze it for less than 1ms. If you have a p99 SLA of
> 50ms, and G1GC pauses for 150ms every 30 seconds, you will breach it
> on schedule. ZGC won't. Choose based on your SLA, not this benchmark."

### When to choose each

| Workload | Choose |
|----------|--------|
| Batch processing, loose SLA, max throughput | G1GC |
| Latency-sensitive, p99 SLA < 50ms | ZGC |
| Very large heap (> 32GB) | ZGC (G1GC pauses scale with heap size) |
| CPU-constrained environment | G1GC (lower constant overhead) |
| HPA stability (avoid false scale-out from GC CPU spikes) | ZGC |

---

## The HPA Connection

G1GC's stop-the-world pauses cause CPU spikes — all GC threads run flat
out for the pause duration, then drop back to zero. This looks exactly
like a traffic spike to CPU-based HPA. It scales out, the new pod runs
JIT warmup (more CPU), HPA scales back in. Continuous thrash.

ZGC's CPU profile is smooth. Load barriers add a small constant overhead
rather than periodic spikes. HPA has nothing to react to. The fix is
switching GC, not tuning `stabilizationWindowSeconds`.

---

## Endpoints

| Endpoint | Description |
|----------|-------------|
| `GET /info` | GC algorithm, heap usage, JVM version, collector names |
| `GET /pressure?mb=50&iterations=10` | Allocate N×MB, measure GC pause delta |
| `GET /gc-stats` | Cumulative GC collection count and total pause time |
| `GET /q/health/live` | Liveness probe |
| `GET /q/metrics` | Prometheus metrics |

---

## Key Prometheus Queries

```promql
# GC pause P99 — compare G1GC vs ZGC side by side
histogram_quantile(0.99,
  rate(jvm_gc_pause_seconds_bucket[1m])
) * 1000

# Rate of GC pause time accumulation — shows G1GC spike pattern
rate(jvm_gc_pause_seconds_sum[1m]) * 1000

# Heap utilisation
jvm_memory_used_bytes{area="heap"} / jvm_memory_max_bytes{area="heap"}
```

---

## What You Cannot Demo Locally

These require real hardware or cluster configuration. The slides explain
each — demonstrate via configuration examples, not live:

| Tuning | Requires | Effect |
|--------|----------|--------|
| Huge pages | Kernel + K8s `hugepages-2Mi` resource | Reduces TLB pressure |
| CPU Manager `static` | Integer CPU requests + Guaranteed QoS | NUMA-local, no contention |
| Topology Manager | Multi-socket server | Single NUMA node for pod |
| `isolcpus` / `nohz_full` | Kernel cmdline + reboot | Removes kernel tick jitter |
| OpenShift PerformanceProfile | Node Tuning Operator | Automates all of the above |
| RT kernel | PREEMPT_RT kernel | Deterministic worst-case scheduling |

---

## Production JVM Flags

```bash
# Minimum viable: switch GC (biggest impact, zero infrastructure change)
-XX:+UseZGC
-XX:+ZGenerational

# Add: match thread counts to your CPU request
-XX:ActiveProcessorCount=<N>
-XX:ParallelGCThreads=<N>
-XX:ConcGCThreads=<N/2>
-XX:CICompilerCount=2

# Add: pre-fault heap to eliminate page fault jitter at startup
-XX:+AlwaysPreTouch

# Add (with kernel + K8s config): huge pages
-XX:+UseLargePages

# Add (with Topology Manager single-numa-node): NUMA awareness
-XX:+UseNUMA
```

---

## OpenShift PerformanceProfile

```yaml
apiVersion: performance.openshift.io/v2
kind: PerformanceProfile
metadata:
  name: low-latency-profile
spec:
  cpu:
    isolated: "4-11"
    reserved:  "0-3"
  hugepages:
    defaultHugePagesSize: 2Mi
    pages:
    - size: 2Mi
      count: 4096
  numa:
    topologyPolicy: single-numa-node
  realTimeKernel:
    enabled: false
```

This single CR sets `isolcpus`, `nohz_full`, `rcu_nocbs`, CPU Manager
`static` policy, Topology Manager `single-numa-node`, and huge page
allocation automatically.

---

## Reference

- ZGC overview: https://wiki.openjdk.org/display/zgc
- Generational ZGC (JDK 21, JEP 439): https://openjdk.org/jeps/439
- Quarkus performance: https://quarkus.io/guides/performance-measure
- OpenShift low-latency: https://docs.openshift.com/container-platform/latest/scalability_and_performance/cnf-low-latency-tuning.html
- Kubernetes CPU Manager: https://kubernetes.io/docs/tasks/administer-cluster/cpu-management-policies/
