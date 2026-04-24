# Shenandoah GC — Comparison Guide
## Red Hat's Default JVM Garbage Collector for OpenShift & Kubernetes

---

## What Is Shenandoah?

Shenandoah is a low-pause concurrent garbage collector developed by Red Hat
and contributed to upstream OpenJDK via JEP 189. It has been available in
Red Hat builds since JDK 8 and in upstream OpenJDK since JDK 12.

The design goal is to perform as much GC work as possible concurrently with
the running application — including compaction — so that pause times are no
longer proportional to heap size. A 1GB heap and a 200GB heap pause for
roughly the same duration.

**It is the default GC in every Red Hat UBI9 OpenJDK container image.**
If you deploy on OpenShift using `registry.access.redhat.com/ubi9/openjdk-21-runtime`
without setting any GC flags, you are already running Shenandoah.

---

## GC Defaults by Container Image

The GC you get depends entirely on who built your container image.

| Image | Vendor | Default GC | Typical Pause |
|-------|--------|-----------|---------------|
| `registry.access.redhat.com/ubi9/openjdk-21-runtime` | Red Hat | **Shenandoah** | 1–20ms |
| `registry.access.redhat.com/ubi9/openjdk-25-runtime` | Red Hat | **Shenandoah** | 1–20ms |
| `eclipse-temurin:21` | Eclipse Adoptium | G1GC | 10–300ms |
| `amazoncorretto:21` | Amazon | G1GC | 10–300ms |
| `mcr.microsoft.com/openjdk/jdk:21-ubuntu` | Microsoft | G1GC | 10–300ms |
| `azul/zulu-openjdk:21` | Azul Systems | G1GC | 10–300ms |
| `ibm-semeru-runtime-open-21` | IBM | OpenJ9 Balanced | Different JVM entirely |

> **Why does this matter for your demos and benchmarks?**
> If you compare GC behaviour across different base images without explicitly
> setting the GC algorithm, you are comparing Shenandoah (UBI9) against G1GC
> (Temurin/Corretto/Azure/Microsoft). The demos in this repo override the
> default explicitly — `-XX:+UseG1GC` and `-XX:+UseZGC` — to ensure a clean,
> intentional comparison.

---

## How Shenandoah Works

Shenandoah is a **region-based, concurrent, compacting** collector. It divides
the heap into equal-sized regions (similar to G1GC) and collects them
concurrently with running application threads.

### The key mechanism — Brooks Pointers

Unlike ZGC which uses coloured pointers and load barriers, Shenandoah uses
**Brooks pointers**: each Java object has an additional forwarding pointer
word in its header. When Shenandoah needs to relocate an object, it updates
the forwarding pointer and installs a **write barrier** that transparently
redirects any write to the old location.

This is the fundamental difference from ZGC:
- **Shenandoah** — write barrier (fires on object writes)
- **ZGC** — load barrier (fires on object reads)

Reads vastly outnumber writes in most Java applications, which is why
Shenandoah's constant overhead is lower than ZGC's — but ZGC's pause
guarantees are correspondingly tighter.

### Collection phases

Shenandoah operates in 2-3 concurrent phases:

1. **Concurrent Mark** — finds all live objects while application runs
2. **Concurrent Evacuation** — copies live objects to new regions (concurrent)
3. **Concurrent Update References** — updates all references to relocated objects

Stop-the-world pauses occur only for brief synchronisation points (root
scanning, which is O(threads) not O(heap)), typically lasting 1–5ms. Under
extreme allocation pressure, Shenandoah can degenerate into a full
stop-the-world collection as a safety fallback (logged as `DegeneratedGC`).

### Not generational (JDK 21)

Shenandoah in JDK 21 is not generational — there is no Young/Old division in
the heap. This means GC logs will not show Young/Old generation collections.
Generational Shenandoah (Shenandoah NG) is in active development but was
not stable in JDK 21.

---

## Shenandoah vs G1GC vs ZGC — Full Comparison

| Feature | G1GC | Shenandoah | ZGC (JDK 21+) |
|---------|------|-----------|---------------|
| **Default in** | Temurin, Corretto, Microsoft, Azul | **UBI9 / Red Hat builds** | Not default (opt-in) |
| **Pause mechanism** | Stop-the-world (STW) | Concurrent (Brooks pointers + SATB write barrier) | Concurrent (colored pointers + load barrier) |
| **Typical Young GC pause** | 10–200ms | 1–5ms | < 1ms |
| **Typical Mixed/Full GC pause** | 50–500ms (scales with heap) | 1–20ms | < 1ms |
| **Pause scales with heap?** | Yes | Sub-linear | No — flat at any size |
| **Barrier type** | Write barrier | **Write barrier** | Load barrier |
| **Constant throughput overhead** | Lowest | ~5–10% | ~5–15% (reads) |
| **Memory overhead** | Low (~remembered sets) | ~8% (Brooks pointer per object) | ~10–20% (colored pointers + metadata) |
| **Generational** | Yes | No (JDK 21) | Yes (`-XX:+ZGenerational`, JDK 21+) |
| **JDK availability** | JDK 9+ (default) | **JDK 8+ (Red Hat), JDK 12+ (upstream)** | JDK 11+ (production from JDK 15) |
| **Large heap (> 32GB)** | Pauses grow | Good | Excellent (pauses don't scale) |
| **HPA interaction** | CPU spikes from STW → false scale-out | Smoother than G1GC | Smoothest (flat CPU profile) |
| **NUMA awareness** | Yes | Yes | Yes |
| **Degenerated fallback** | Full GC | `DegeneratedGC` (STW fallback) | None (always concurrent) |

---

## Shenandoah vs G1GC — When Each Wins

### Choose G1GC when:

- Your workload is **throughput-oriented** — batch processing, data pipelines,
  report generation where occasional GC pauses are acceptable
- You need the **lowest constant overhead** — G1GC has no write/load barrier
  overhead outside of GC cycles
- Your **heap is small** (< 4GB) — the concurrent GC overhead may not be
  worth it for small-heap microservices
- You are on a **non-Red Hat image** and G1GC is already the default — no
  reason to change if pauses are acceptable for your SLA
- You need **fine-grained pause tuning** — `MaxGCPauseMillis` gives you a
  soft target to tune against

### Choose Shenandoah when:

- You are **already on OpenShift / UBI9** — it's your default, and it gives
  you 1–20ms pauses with zero configuration
- Your service has a **p99 SLA between 20ms and 100ms** — Shenandoah reliably
  stays under 20ms; G1GC cannot guarantee this
- You want **lower-latency than G1GC** but don't need ZGC's sub-millisecond
  guarantee
- You need **JDK 8 or JDK 11 support** — Shenandoah (Red Hat builds) works
  there; ZGC requires JDK 11+ and was only production-ready from JDK 15
- Your **heap is medium to large** (4GB–100GB) — Shenandoah handles this
  well; G1GC pauses grow with heap size
- You want **cloud-native microservice** performance with minimal configuration

### Choose ZGC when:

- Your service has a **p99 SLA tighter than 10ms** — ZGC consistently
  delivers sub-millisecond pauses
- Your **heap exceeds 32GB** — ZGC pauses don't scale with heap size; G1GC and
  Shenandoah both start to show longer pauses at very large heaps
- You need **HPA stability** — ZGC's flat CPU profile produces no spikes that
  could trigger false scale-out events; Shenandoah is better than G1GC here
  but not as smooth as ZGC
- You are on **JDK 21+** and can afford the ~5–15% throughput overhead from
  load barriers

---

## The Barrier Type Distinction — Why It Matters

This is the most important technical difference between Shenandoah and ZGC.

**Shenandoah uses a write barrier.** It fires when your application code
*writes* an object reference. Since object writes are relatively infrequent
compared to reads, the constant overhead is lower.

**ZGC uses a load barrier.** It fires when your application code *reads* an
object reference — every time any field access, array element read, or method
call occurs through an object pointer. In a typical Java application, reads
outnumber writes by 10:1 or more. This is why ZGC carries a slightly higher
constant overhead (~5–15%) than Shenandoah (~5–10%).

The trade-off is that ZGC's load barriers enable stricter pause guarantees —
it has the information it needs to ensure relocation is transparent at every
possible access point. Shenandoah's write barriers are sufficient to guarantee
concurrent compaction but cannot achieve the same sub-millisecond ceiling.

In practical terms for Kubernetes:

```
Shenandoah: 1-20ms pauses    Lower barrier overhead
ZGC:        < 1ms pauses     Higher barrier overhead
G1GC:       10-500ms pauses  No barrier overhead (during normal execution)
```

---

## Configuration Reference

### Enable Shenandoah explicitly

```bash
# Override UBI9's default (already Shenandoah, but being explicit is clearer in demos)
-XX:+UseShenandoahGC

# Heuristics (controls when collection is triggered)
-XX:ShenandoahGCHeuristics=adaptive     # default — adapts to allocation rate
-XX:ShenandoahGCHeuristics=compact      # memory-constrained environments
-XX:ShenandoahGCHeuristics=aggressive   # lowest possible pauses, highest CPU cost
-XX:ShenandoahGCHeuristics=static       # fixed occupancy thresholds
```

### In Quarkus application.properties

```properties
quarkus.jvm.additional-jvm-args=-XX:+UseShenandoahGC
quarkus.jvm.additional-jvm-args=-XX:ShenandoahGCHeuristics=adaptive
```

### In docker-compose.yml

```yaml
environment:
  JAVA_OPTS: "-XX:+UseShenandoahGC -XX:ShenandoahGCHeuristics=adaptive"
```

### In Kubernetes Deployment

```yaml
env:
  - name: JAVA_OPTS
    value: >-
      -XX:+UseContainerSupport
      -XX:MaxRAMPercentage=75.0
      -XX:+UseShenandoahGC
      -XX:ShenandoahGCHeuristics=adaptive
      -XX:ActiveProcessorCount=2
```

### Paired with heap flags

```bash
-XX:+UseContainerSupport
-XX:MaxRAMPercentage=75.0
-XX:InitialRAMPercentage=50.0
-XX:+UseShenandoahGC
-XX:ShenandoahGCHeuristics=adaptive
-XX:ActiveProcessorCount=<N>       # match to CPU request
```

---

## Monitoring Shenandoah

### Prometheus / Micrometer metrics

```properties
# application.properties — required for GC pause histogram panels in Grafana
quarkus.micrometer.binder.jvm=true
quarkus.micrometer.distribution.percentiles-histogram.jvm.gc.pause=true
quarkus.micrometer.distribution.percentiles.jvm.gc.pause=0.5,0.95,0.99
```

### Key PromQL queries

```promql
# GC pause P99 (ms) — Shenandoah should consistently show < 20ms
histogram_quantile(0.99,
  rate(jvm_gc_pause_seconds_bucket[1m])
) * 1000

# GC pause rate — spikes indicate allocation pressure
rate(jvm_gc_pause_seconds_sum[1m]) * 1000

# Watch for DegeneratedGC events (Shenandoah fallback to STW)
jvm_gc_pause_seconds_count{cause="ShenandoahDegeneratedGC"}
```

### Alert rule

```yaml
# Fire if Shenandoah pauses exceed 50ms — indicates DegeneratedGC or extreme pressure
- alert: ShenandoahHighGCPause
  expr: >
    histogram_quantile(0.99,
      rate(jvm_gc_pause_seconds_bucket[5m])
    ) > 0.05
  for: 2m
  labels:
    severity: warning
  annotations:
    summary: "Shenandoah GC P99 pause > 50ms on {{ $labels.pod }}"
    description: "Check for DegeneratedGC events — may indicate allocation rate exceeds concurrent GC capacity"
```

### GC log flags

```bash
# Enable GC logging to understand pause events
-Xlog:gc*:file=/tmp/gc.log:time,uptime:filecount=5,filesize=20m

# Shenandoah-specific logging
-Xlog:gc+stats=info

# Watch for DegeneratedGC in the log:
# [info][gc] GC(42) Concurrent Mark Roots 2.1ms
# [info][gc] GC(42) Pause Degenerated GC (Mark) 45.3ms  ← this is a warning sign
```

---

## DegeneratedGC — What It Means

Shenandoah can fall back to a stop-the-world collection if the concurrent
collector cannot keep up with the allocation rate. This is logged as
`DegeneratedGC` and represents a significant pause (tens to hundreds of ms).

**Common causes:**
- Allocation rate is too high for the concurrent collector to keep up
- Heap is too small — very little free space forces emergency GC
- `ShenandoahGCHeuristics=static` with thresholds set too high

**What to do if you see DegeneratedGC:**
1. Increase heap size (`MaxRAMPercentage`) — give Shenandoah more room
2. Switch to `ShenandoahGCHeuristics=compact` for memory-constrained pods
3. Check allocation rate — identify which code paths create short-lived objects
4. Consider `ShenandoahGCHeuristics=aggressive` if latency matters more than CPU

---

## The On-Stage Framing

When presenting the GC comparison in the context of OpenShift demos:

> "If you're deploying on OpenShift using the standard UBI9 OpenJDK 21 runtime
> image, you're already getting Shenandoah out of the box — without any
> configuration. That gets you to 1-20ms pauses before you've changed a single
> flag. The question is whether you need to go further."
>
> "ZGC takes you to sub-millisecond, at a slightly higher throughput cost.
> The decision between Shenandoah and ZGC is whether your SLA needs
> 'almost never over 20ms' or 'never over 1ms'."
>
> "G1GC is the right default for the vast majority of workloads on non-Red Hat
> images — high throughput, well understood, lowest constant overhead. If you
> see P99 GC pauses consistently above 500ms, that's your signal to switch to
> Shenandoah or ZGC."

---

## Reference Links

| Resource | URL |
|----------|-----|
| Shenandoah OpenJDK wiki | https://wiki.openjdk.org/display/shenandoah/Main |
| Red Hat beginner's guide to Shenandoah | https://developers.redhat.com/articles/2024/05/28/beginners-guide-shenandoah-garbage-collector |
| Red Hat Shenandoah docs (JDK 21) | https://docs.redhat.com/en/documentation/red_hat_build_of_openjdk/21/html-single/using_shenandoah_garbage_collector_with_red_hat_build_of_openjdk_21/index |
| JEP 189 — Shenandoah GC (OpenJDK 12) | https://openjdk.org/jeps/189 |
| UBI9 OpenJDK 21 runtime image | https://catalog.redhat.com/software/containers/ubi9/openjdk-21-runtime/6501ce769a0d86945c422d5f |
| ZGC overview (for comparison) | https://wiki.openjdk.org/display/zgc |
| Generational ZGC (JEP 439) | https://openjdk.org/jeps/439 |
| Shenandoah DegeneratedGC explained | https://access.redhat.com/solutions/6411161 |
