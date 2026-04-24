# Presenter Guide
## Taming the JVM: Optimizing Java Workloads on OpenShift & Kubernetes

**Talk length:** 60 minutes core + bonus slides for extended sessions  
**Slide count:** 54 slides (30 core + 24 bonus)  
**Demo count:** 9 demos (3 core + 6 bonus/extended)  
**Repo:** github.com/patterncatalyst/quarkus-optimization

---

## Before You Present

### Day-before checklist

- [ ] Pull latest demo images: `podman pull docker.io/grafana/otel-lgtm:0.8.1` and `docker.io/prom/prometheus:v3.2.1`
- [ ] Run `./demo.sh` for Demo 01, 02, 03 end-to-end — verify outputs
- [ ] Confirm `podman-compose` version: `podman-compose --version`
- [ ] Verify Grafana loads at `http://localhost:3000` during Demo 02 dry run
- [ ] Check `quarkus.micrometer.distribution.percentiles-histogram.jvm.gc.pause=true` is set in Demo 02 `application.properties` — without this, Grafana panels show no data
- [ ] For bonus Demo 04: confirm JDK 25 image pulls correctly
- [ ] Close all non-essential browser tabs and apps; disable Slack/email notifications
- [ ] Set screen resolution to 1920×1080 minimum; bump terminal font to 18pt

### What to have open before you start

```
Terminal 1: repo root (for demo.sh commands)
Terminal 2: spare (for jcmd / curl commands live)
Browser tab 1: slides (presenter view)
Browser tab 2: Grafana http://localhost:3000 (for Demo 02 — load in advance)
Browser tab 3: github.com/patterncatalyst/quarkus-optimization (for QR code reference)
```

### Known audience reactions to prepare for

- "Why not just use native image?" → Leyden is the answer: JVM dynamics preserved, no closed-world constraint, 60-75% startup gain. Native is the extreme case.
- "Isn't this Spring Boot content too?" → Demo 03 side-by-side shows the honest comparison. Quarkus + AppCDS is 14× faster than Spring Boot baseline.
- "Our Kubernetes admin won't let us change CPU Manager" → Start with items 1-3 on the tuning ladder — ZGC + thread counts + heap sizing need zero cluster config changes.
- "ZGC was slower in your benchmark" → Demo 06 caveat: the load barrier cost is real, the GC pause delta is the number that matters for SLAs.

---

## Talk Structure — 60-Minute Core

```
Slides 1-2:   Opening + Agenda         (3 min)
Slides 3-7:   Section 01 — Heap        (8 min, DEMO 01)
Slides 8-9:   Section 02 — Right-Sizing (5 min)
Slides 10-14: Section 03 — GC          (8 min, DEMO 02)
Slides 15-17: Section 04 — Startup     (7 min, DEMO 03)
Slides 18-20: Section 05 — Observability (5 min)
Slides 21-23: Section 06 — Autoscaling  (5 min)
Slides 24-25: Section 07 — Tuning + ROI (4 min)
Slides 26-28: Demo recaps              (3 min)
Slides 29-30: Key takeaways + Q&A      (5 min)
────────────────────────────────────────────────
Buffer + Q&A: 7 min
Total: 60 min
```

### Extended session bonus content (30 min)

```
Slides 31-33: Project Leyden + DEMO 04     (8 min)
Slides 34-37: REST vs gRPC + DEMO 05       (7 min)
Slides 38-42: Low-Latency + DEMO 06        (7 min)
Slides 43-47: Right-Sizing + DEMO 07       (5 min)
Slides 48-50: Panama + DEMO 08/09          (5 min)
Slides 51-52: Valhalla                     (3 min)
Slides 53-54: Anti-Patterns                (5 min)
```

---

## Slide-by-Slide Presenter Notes

---

### Slide 1 — Title

**Taming the JVM: Optimizing Java Workloads on OpenShift & Kubernetes**

Open with the tension: Java is the most deployed enterprise language in the world, and it's also one of the most frequently misconfigured in containers.

> "Java was designed in an era when it owned the whole machine. In Kubernetes, it shares a cgroup with 20 other pods. The JVM doesn't know that — unless you tell it."

Point to the subtitle technology list. These aren't abstract topics — every one of them will have a live demo.

---

### Slide 2 — Agenda

Seven sections plus bonus. For a 60-minute session, sections 01-07 are the core. Bonus content covers Leyden, gRPC, low-latency, Panama, and Valhalla — available for extended sessions or as follow-up material.

Call out that the repo is live and all demos are runnable at home.

---

### Slide 3 — Why Java + Kubernetes = Complexity

The four statistics are real:
- **60% of Java apps overprovision memory** — teams set requests based on fear, not measurement
- **4-8s cold start** — default Spring Boot startup during a scale-out event breaches SLAs
- **2-3× infrastructure waste** — poor bin-packing is the #1 preventable cost driver
- **$$$** — every one of these failures has a monthly cloud bill attached

The four failure patterns are the four things this talk fixes. Walk through them briefly:

1. **Default JVM ignores cgroup limits** → Section 01 fix
2. **OOMKill storms** → Section 02 fix (right-sizing)
3. **GC pause autoscaling** → Section 03 + 06 fix
4. **Slow startup throttles** → Section 04 fix

> "If I had to pick one failure pattern that costs enterprises the most money per year, it's the first one. The JVM reads host RAM, claims 25% of 256GB, and you OOMKill within minutes. UseContainerSupport is free. It ships on by default in Java 21. Most people still haven't turned on MaxRAMPercentage."

---

### Slide 4 — Container-Native JVM Fundamentals (Section 01)

**Key points:**

The JVM's memory discovery behaviour changed progressively:
- Before containers: reads `/proc/meminfo` — sees the node's full RAM
- Java 10+: `UseContainerSupport` reads cgroup limits (off by default before 10, on by default from 10 onwards)
- Java 21 baseline: `UseContainerSupport` is on by default — the key flag to tune is `MaxRAMPercentage`
- cgroup v2 (RHEL 9 / OCP 4.14+): JVM reads `/sys/fs/cgroup/memory.max` — fully supported from Java 15+

**The fix code block** — walk through what changed:
```bash
# ❌ BEFORE — breaks silently when VPA or cluster admin resizes
-Xms512m -Xmx2048m

# ✅ Java 21 — scales automatically with container limit
-XX:MaxRAMPercentage=75.0
-XX:InitialRAMPercentage=50.0
-XX:MinRAMPercentage=25.0
```

**Why 75%:** The remaining 25% covers Metaspace, thread stacks, JIT code cache, and Netty direct buffers. If you set it to 90%, you will eventually OOMKill when these regions grow.

Reference: *Optimizing Cloud Native Java* Ch. 3

---

### Slide 5 — Container-Aware JVM Memory: Before and After

Visual diagram slide. Use it to show the contrast between a misconfigured pod (JVM claiming 64GB heap inside a 512MB container) and a correctly configured one.

No notes needed — let the visual carry it. Pause here for 10-15 seconds.

---

### Slide 6 — JVM Memory Regions

**This is the "aha" slide for most audiences.**

Teams set `MaxRAMPercentage=75` thinking that controls all memory. It only controls the heap. Five other regions also consume RAM:

| Region | Typical size | Flag to control |
|--------|-------------|-----------------|
| Heap (Old Gen + Young Gen) | 50-75% of limit | `MaxRAMPercentage` |
| Metaspace | 50-200MB | `MaxMetaspaceSize` |
| Platform Thread Stacks | 1MB/thread | `-Xss` to reduce |
| Native Memory (JIT, GC) | 100-300MB | — |
| Direct ByteBuffers | Varies | — |

> "Java 21 Virtual Threads eliminate the platform thread stack budget for I/O-bound workloads. A REST service that needed 512m for 200 platform threads can handle 10,000 virtual threads with the same memory — because virtual thread stacks live in heap, not OS stack."

**NMT tip:** `-XX:NativeMemoryTracking=summary` then `jcmd <pid> VM.native_memory summary` gives you a breakdown of exactly where memory is going.

---

### Slide 7 — JVM Memory Regions in a Container (Visual)

Visual diagram — `MaxRAMPercentage=75` controls only the Heap box. The other 5 regions are outside it.

Pause. Let this land. This is usually the moment someone in the audience realises why their pods keep getting OOMKilled even though "the heap was sized correctly."

---

### **DEMO 01 — Container-Aware Heap Sizing** (Slide 26)

**Demo directory:** `demo-01-heap-sizing/`  
**Command:** `./demo.sh`  
**Time budget:** ~5 minutes

**What to narrate:**

1. First run: JVM without `UseContainerSupport` — `jcmd` output shows it claiming host RAM
2. Second run: `UseContainerSupport` + `MaxRAMPercentage=75.0` — JVM respects 512m limit, heap = ~384m
3. OOMKill simulation: JVM ignoring limits → Kubernetes terminates the pod mid-request

> "This is the foundational fix. Everything else in this talk builds on getting this right first."

---

### Slides 8-9 — Right-Sizing Java Workloads (Section 02)

**Slide 8 — Requests vs Limits**

Two concepts that teams consistently confuse:

- **requests** = scheduling guarantee — Kubernetes uses this to find a node. Set to P50 steady-state RSS.
- **limits** = hard ceiling — memory limit causes OOMKill; CPU limit causes throttling (not kill).

**Memory sizing formula:**
```
Measure: jcmd <pid> VM.native_memory summary
Budget: Heap + Metaspace + Threads + Native + 20% buffer
Request = P50 steady-state RSS
Limit = P99 peak + 15% safety margin
```

**CPU sizing:** Two schools of thought — no limit (burst freely) vs 2-4× request (predictable GC). Whatever you choose, ensure metrics exist to correlate CPU spikes with GC events.

**Slide 9 — Pod Bin-Packing**

The visual is stark: 3 pods per node with default `-Xmx8192m` vs 6 pods per node after right-sizing.

> "This is how you go from 4 nodes to 2 nodes without changing a single line of application code. The workloads are identical. We just stopped lying to the scheduler about how much resource each pod needs."

---

### Slides 10-14 — Garbage Collection Optimization (Section 03)

**Slide 10 — GC in Containers: The Four Challenges**

Walk through each challenge with its container-specific implication:

1. **CPU throttling extends GC** — a 100ms G1GC pause becomes 400ms under CPU throttle. Set limit ≥ 2× request.
2. **Parallel GC thread count** — JVM defaults to host CPU count. 64-core node + 4 CPU limit = 64 threads competing for 4 CPUs. Fix: `-XX:ParallelGCThreads=4`
3. **GC-induced HPA thrash** — the false scale-out cycle. Cover in detail.
4. **Heap sizing vs GC pressure** — small heap = frequent GC; too large = infrequent but long GC.

**Slide 11 — GC-Induced HPA Thrash Cycle (Visual)**

The cycle: GC pause → CPU spike → HPA fires → new pods → GC on new pods → repeat.

This diagram is the emotional centre of the talk for platform engineers. Let it breathe.

> "HPA is doing exactly what it was designed to do — scale out when CPU is high. The problem is it can't tell the difference between 'we have too many requests' and 'garbage collection fired for 300 milliseconds.' The fix is either slowing HPA down with stabilisation windows, or switching to a metric that actually reflects user demand."

---

### **DEMO 02 — GC Monitoring with Prometheus** (Slide 27)

**Demo directory:** `quarkus-demo-02-gc-monitoring/`  
**Command:** `./demo.sh` (runs `podman-compose up`)  
**Time budget:** ~10 minutes  
**Grafana:** http://localhost:3000 (admin/admin)

**What to narrate:**

- Stack: Quarkus 3.33.1 LTS + `quarkus-micrometer-opentelemetry` + Grafana LGTM (Tempo + Prometheus)
- Show live GC pause histograms at `/q/metrics` — `jvm_gc_pause_seconds`
- Generate GC pressure: `curl "http://localhost:8080/allocate?mb=100&iterations=10"`
- Point to Grafana — both metrics dashboard and Grafana Tempo traces simultaneously
- Side-by-side G1GC (port 8080) vs Generational ZGC (port 8081) pause comparison
- Virtual threads: `curl "http://localhost:8080/virtual-threads?tasks=500&workMs=5"`

**Critical setup note:** The histogram configuration in `application.properties` is essential:
```properties
quarkus.micrometer.distribution.percentiles-histogram.jvm.gc.pause=true
```
Without this, the Grafana GC pause panels show no data.

**Known issue (Fedora/RHEL):** All bind mounts need `:Z` for SELinux. Prometheus uses `tmpfs` + `user: root` to avoid rootless Podman volume permission issues.

---

### Slide 12 — GC Selection Guide

**Walk the table:**

| Collector | When to use |
|-----------|-------------|
| G1GC | General-purpose microservices; `-XX:+UseG1GC -XX:MaxGCPauseMillis=200` |
| ZGC (Gen) | Low-latency APIs, any heap size; `-XX:+UseZGC -XX:+ZGenerational` |
| Shenandoah | Alternative to ZGC; OpenJDK/RHEL default; excellent for all heap sizes |
| Serial GC | CLI tools, batch, < 256MB heap only |

> "Tip from SRE with Java Microservices: if your P99 GC pause is over 500ms, that's your signal to switch from G1GC to ZGC or Shenandoah. Don't tune G1GC parameters hoping to get there — switch the algorithm."

**UBI9 note:** If you're on OpenShift using `ubi9/openjdk-21-runtime`, Shenandoah is your default — you're already getting 1-20ms pauses without any configuration. The demos override it explicitly for clean comparison.

---

### Slide 13 — Essential GC Tuning Parameters

Walk through the three blocks:

**G1GC container settings:**
- `MaxGCPauseMillis=200` — soft target, not guaranteed
- `G1HeapRegionSize=16m` — larger regions reduce fragmentation and bookkeeping
- `ParallelGCThreads=4` — **must match your CPU limit**
- `InitiatingHeapOccupancyPercent=45` — start GC earlier to avoid emergency collections in containers

**ZGC settings:**
- `SoftMaxHeapSize` — soft limit within the hard container limit; gives ZGC room to return memory to OS
- `ZCollectionInterval=5` — proactive GC every 5s prevents heap buildup

**Shenandoah:**
- `ShenandoahGCMode=adaptive` — self-tuning heuristic; correct for most workloads

---

### Slide 14 — The AOT Cache Progression: CDS → AppCDS → Leyden

Visual showing the progression. Use as a bridge to Section 04. No extended notes needed — Section 04 covers it in depth.

---

### Slides 15-17 — Startup Time Reduction (Section 04)

**Slide 15 — Spring Boot vs Quarkus Baseline**

The framing: Spring Boot cold start 4-8s vs Quarkus 3.33.1 JVM 0.3-0.8s vs Quarkus + AOT cache 0.15-0.4s.

Break down where the time goes in Spring Boot:
- JVM Bootstrap: ~200ms (same for both)
- Class Loading: ~800ms (Spring loads ~10,000+ classes at runtime; Quarkus pre-processes at build time)
- Framework Context Init: ~1,500ms Spring vs ~50ms Quarkus
- JIT Compilation: ~600ms (same for both initially)

> "Quarkus is already 5-10× faster than Spring Boot before any startup optimisation. That's because Quarkus does at build time what Spring does at runtime — classpath scanning, dependency injection wiring, configuration validation. The AOT cache is the next layer on top of that."

**Slide 16 — AOT Caching: CDS → AppCDS → Leyden**

Three tiers:

1. **CDS (Java 21, on by default)** — JDK ships a pre-built shared archive for JDK classes. Active by default, saves 150-300ms, zero configuration.

2. **AOT Cache / AppCDS (Quarkus 3.33.1)** — `quarkus.package.jar.aot.enabled=true` in `application.properties`. Quarkus Maven plugin trains on `@QuarkusIntegrationTest` suite. No manual steps. Dockerfile just needs to copy `*.cds` alongside the JARs.

3. **Leyden full AOT (JDK 25)** — extends AppCDS to cache fully linked classes AND JIT method profiles. Quarkus 3.33.1 LTS supports this with the same property.

**Key benchmark:**
- Quarkus 0.6s JVM baseline → 0.3s with AppCDS (50% faster)
- Spring Boot 4.2s → 2.4s with AppCDS
- Quarkus + AppCDS is **14× faster** than Spring Boot baseline

**Slide 17 — Virtual Threads (@RunOnVirtualThread)**

JEP 444 — Java 21. One annotation in Quarkus:

```java
@GET
@RunOnVirtualThread   // ← One annotation. Done.
public AllocResponse allocate(@QueryParam("mb") int mb) { ... }
```

**Container sizing impact:**
- Platform thread stacks are 1MB each — 200 threads = 200MB
- Virtual thread stacks live in heap — 10,000 virtual threads ≈ same memory as 200 platform threads
- Pods that needed 512Mi for 200 platform threads can handle 10,000 concurrent I/O-bound tasks with the same memory

**Podman measurement command:**
```bash
# Verify with Prometheus metric
/q/metrics → jvm_threads_live_threads (platform carrier count stays small)
```

---

### **DEMO 03 — AppCDS Startup Acceleration** (Slide 28)

**Demo directory:** `quarkus-demo-03-appcds/`  
**Command:** `./demo.sh`  
**Time budget:** ~8 minutes

**What to narrate:**

- Quarkus JVM baseline: ~0.3-0.8s (vs Spring Boot ~4-8s — already 10× faster)
- One property: `quarkus.package.jar.aot.enabled=true`
- Maven plugin handles training on `@QuarkusIntegrationTest` — no manual `-Xshare:dump`
- Quarkus + AOT Cache: ~0.15-0.4s (30-50% additional gain)
- Progression: AppCDS (JDK 21) → Leyden `-XX:AOTCache` (JDK 25)

**Honest result to flag:** AppCDS gives ~5% improvement on Quarkus vs ~40% on Spring Boot — because Quarkus already moved class-loading work to build time. The small improvement *proves the point*.

---

### Slides 18-20 — Observability & Instrumentation (Section 05)

**Slide 18 — Observability Stack**

> "You can't tune what you can't see. Build observability before you tune — otherwise you're guessing."

Four components:

1. **JFR (JDK Flight Recorder)** — built-in, < 1% overhead, captures GC events + allocations + IO. Start with `jcmd <pid> JFR.start duration=60s`

2. **Cryostat** — OpenShift-native JFR management. Discovers pods via annotation, manages recordings via UI, stores in PVC, integrates with Grafana.

3. **OTel → Grafana LGTM** — `quarkus-micrometer-opentelemetry` single extension (preview since 3.19). One extension replaces separate Prometheus registry + OTel extension. All telemetry flows through OTel SDK.

4. **Micrometer → OTel (unified)** — `jvm.gc.pause`, `jvm.memory.used`, `jvm.threads.live` via `quarkus.micrometer.binder.jvm=true`

**Key point on quarkus-micrometer-opentelemetry:** This new unified extension means all Micrometer metrics, OTel traces, and logs flow through a single OTLP pipeline. If you're on Quarkus 3.19+, use this instead of the separate extensions.

**Slide 19 — Cryostat: Production JFR on OpenShift**

Walk the architecture: JFR Agent in pod → Cryostat Server (operator) → Grafana/JMC.

Quick setup steps:
1. Install via OperatorHub → "Cryostat"
2. Annotate pod: `cryostat.io/scrape_port: "9097"`
3. Add agent JAR to image: `COPY --from=cryostat/cryostat-agent:latest /cryostat-agent.jar /opt/agent.jar`
4. Start recording via UI or REST API

**Slide 20 — Prometheus & Micrometer**

Essential metrics to monitor:

| Metric | Alert threshold |
|--------|----------------|
| `jvm_gc_pause_seconds` | P99 > 500ms → switch GC algorithm |
| `jvm_memory_used_bytes` | > 80% of limit → risk of OOMKill |
| `jvm_threads_live` | sudden spike → thread leak |
| `process_cpu_usage` | correlate spikes with GC events |

**Alert rule** — show the PrometheusRule example. This is the minimum viable GC alerting:
```yaml
- alert: JVMHighGCPause
  expr: histogram_quantile(0.99, rate(jvm_gc_pause_seconds_bucket[5m])) > 0.5
  for: 2m
```

---

### Slides 21-23 — Autoscaling Integration (Section 06)

**Slide 21 — HPA with JVM-Aware Metrics**

The anti-pattern is CPU-based HPA. The fix has three layers:

1. `minReplicas: 2` — never 1. Single pod + GC stop-the-world = 100% downtime during the pause.

2. `stabilizationWindowSeconds: 120` on scaleUp — absorbs GC CPU spikes up to 2 minutes. GC pauses last milliseconds; a 2-minute stabilisation window makes them invisible to HPA.

3. Scale on RPS not CPU:
```yaml
metrics:
- type: External
  external:
    metric: { name: http_requests_per_second }
    target: { type: AverageValue, averageValue: "50" }
- type: External
  external:
    metric: { name: jvm_memory_used_ratio }
    target: { type: AverageValue, averageValue: "0.80" }  # scale before OOMKill
```

**Slide 22 — VPA for Java**

VPA workflow: 48-72 hours in Off mode → validate recommendations against JVM memory budget → apply in Auto mode during low-traffic window → monitor for OOMKills.

**Critical warning:** Don't run VPA + HPA on CPU/memory simultaneously. Use HPA on custom metrics (RPS) + VPA on resource right-sizing, or use KEDA for combined scaling.

**Slide 23 — Preventing GC-Induced Autoscaling Thrash**

Six concrete actions — walk through each briefly:
1. Request-rate HPA, not CPU
2. Extend stabilisation windows (120-300s)
3. GC-aware alerting (independent of scaling)
4. `minReplicas: 2` minimum
5. Correlate GC with business metrics
6. Memory limit buffer (25-30% above request)

---

### Slides 24-25 — Systematic Tuning Workflow & Cost ROI (Section 07)

**Slide 24 — Iterative Tuning Loop**

Five steps: Instrument → Baseline → Diagnose → Tune → Validate & Repeat.

> "The most important word in that loop is 'one.' Apply one change at a time. If you change GC algorithm, heap size, and thread count in the same deployment, you cannot attribute the improvement to any of them."

**Slide 25 — Cost Optimization & Business Value**

The four headline numbers:
- 40-60% memory reduction after right-sizing
- 2-3× pod density increase per node
- 55% startup time reduction with AppCDS
- $$$ node cost savings from bin-packing

**ROI measurement tools:**
- OpenShift Cost Management (`cost.openshift.io`)
- Node reduction formula: Nodes saved = (total pods / old density) − (total pods / new density) × node hourly rate
- SLO improvement: fewer OOMKills + fewer GC pauses = fewer on-call incidents

---

### Slide 29 — Key Takeaways

Seven numbered takeaways — read each one slowly. This is the audience's callback for their own environments.

1. `UseContainerSupport + MaxRAMPercentage` — hardcoded `-Xmx` is an anti-pattern
2. Right-size first, then tune — measure RSS + off-heap before setting resource requests
3. Match GC to workload — G1GC general, ZGC/Shenandoah for latency-sensitive
4. Quarkus AppCDS: one property — baseline is already 5-10× faster than Spring Boot
5. Observe before you tune — JFR + Cryostat + Prometheus validates every change
6. Autoscale on RPS not CPU — GC pauses lie to HPA; use `@RunOnVirtualThread`
7. Quantify savings — track cost per namespace to show business value

---

### Slide 30 — Resources & Q&A

Reference the four key links:
- *Optimizing Cloud Native Java* — the book this talk is based on
- *SRE with Java Microservices* — SLI/SLO framing and autoscaling patterns
- Demo repo: github.com/patterncatalyst/quarkus-optimization
- Grafana JVM dashboard 4701

> "Slides and all demos are available at the GitHub repo. PRs and issues welcome — especially if you find a demo that breaks on your platform. I want to know."

---

## Bonus Slides (Extended Session / 90 minutes)

---

### Slides 31-33 — Project Leyden + DEMO 04

**Slides 31-32 — Leyden Deep Dive**

The AOT cache progression:
- JDK 24 (JEP 483): AOT class loading & linking — ~40% startup gain
- JDK 25 LTS (JEP 514+515): Ergonomics + JIT method profiles — 60-75% startup gain
- JDK 26 (JEP 516): ZGC support added (previously G1GC only)
- Future: Pre-compiled native code in cache → instant peak performance

What the cache stores:
- Fully loaded and linked class state (extends AppCDS beyond parsed bytes)
- JIT method profiles — hot paths pre-identified so JIT compiles immediately at startup
- Self-invalidating — JVM detects changed JARs and rebuilds

Leyden vs GraalVM Native:
- Native: 95-99% faster startup, closed-world AOT, no JIT after start
- Leyden: 40-55% startup + 15-25% warmup gain, no code changes, full JVM dynamics preserved
- Different tools for different tradeoffs: Leyden for JVM workloads, Native for footprint-critical

**Slide 33 — DEMO 04**

```
Demo directory: quarkus-demo-04-leyden/
Command: ./demo.sh
JDK required: 25 LTS
Time budget: ~12 min
```

What to narrate:
- One property: `quarkus.package.jar.aot.enabled=true`
- Build trains on `@QuarkusIntegrationTest` — Maven plugin handles everything
- Output: `app.aot` alongside `quarkus-run.jar` — Quarkus sets `-XX:AOTCache` automatically
- Compare baseline startup vs AOT cache: expect 30-50% improvement on JDK 25
- Progression context: AppCDS (JDK 21) → Leyden AOT (JDK 25) → JDK 26 + ZGC

**Verified result:** 609ms → 148ms (−75%) on JDK 25 with Quarkus 3.33.1 LTS.

**Known requirements:**
- Three-stage Dockerfile: `temurin-25` compiler → `ubi9/openjdk-25` trainer → `ubi9/openjdk-25-runtime`
- JVM fingerprint must match between trainer and runtime (same vendor + version)
- `aot-jar` packaging (not `fast-jar`) — Quarkus sets this automatically

---

### Slides 34-37 — REST vs gRPC + DEMO 05

**Slides 34-35 — REST vs gRPC Comparison**

Protocol comparison table — the key differentiators:
- Protocol: HTTP/1.1 vs HTTP/2 (always)
- Format: JSON ~400 bytes vs Protobuf ~40 bytes (10× smaller)
- Connection: new per request vs multiplexed, persistent
- Streaming: SSE/WebSocket boilerplate vs built-in 4 modes

Performance benchmarks (pod-to-pod, real network):
- Throughput: REST 2,200 rps vs gRPC 8,500 rps (3.9×)
- CPU usage: REST 65% vs gRPC 40% (−38%)
- p99 latency: REST 120ms vs gRPC 25ms (−79%)

**Slide 37 — DEMO 05**

```
Demo directory: quarkus-demo-05-grpc/
Command: ./demo.sh
Time budget: ~10 min
```

> **⚠️ Critical caveat to mention before running:** gRPC unary will likely be slower than REST on localhost. Network cost is zero on loopback — gRPC's advantages (HTTP/2 persistent connections, HPACK compression, binary encoding) only materialise with real pod-to-pod network latency.
>
> What the demo shows clearly even on localhost: streaming (1 connection vs 1,000 requests) and high concurrency (c=500, HTTP/2 multiplexing).
>
> On-stage framing: "I'm showing you the localhost result because hiding it would be dishonest. In your cluster with real pod-to-pod latency, gRPC wins by 3-4×. The streaming comparison is real regardless of where you run it."

---

### Slides 38-42 — Low-Latency JVM + DEMO 06

**Slides 38-40 — G1GC vs ZGC, Tuning Ladder, K8s Config**

Walk the pause comparison (Slide 38):
- G1GC: Young GC 10-200ms, Mixed 50-500ms, Full 1-10s, scales with heap size, CPU spike causes HPA false scale-out
- ZGC: < 1ms across all collection types, scales with thread count not heap, smooth CPU profile

Tuning ladder (Slide 39) — six levels, easy to advanced:
1. ZGC + Generational — biggest single impact, zero infrastructure change
2. Explicit thread counts — prevents GC/JIT oversubscription
3. Huge pages + AlwaysPreTouch — TLB pressure + page fault jitter
4. CPU Manager static + Topology Manager — NUMA-local, no cross-socket
5. `isolcpus` + `nohz_full` + `rcu_nocbs` — kernel tick jitter
6. RT kernel + ZGC + SCHED_FIFO — deterministic worst-case

K8s config (Slide 40) — PerformanceProfile automates levels 4-6 in a single CR.

**Slide 41 — Which GC Ships by Default**

The vendor comparison table — key takeaway: if you're on OpenShift using UBI9, you already have Shenandoah (1-20ms pauses) without any configuration. ZGC takes you further to sub-millisecond.

**Slide 42 — DEMO 06**

```
Demo directory: quarkus-demo-06-latency/
Command: ./demo.sh
Time budget: ~10 min
```

> **⚠️ ZGC throughput caveat:** ZGC will show lower throughput than G1GC in the `hey` load test. Load barriers add ~5-15% constant overhead. The meaningful comparison is the GC pause delta in Steps 4 and 5, not the `hey` p99.
>
> On-stage framing: "ZGC is slower in throughput here — that's the load barrier cost. But G1GC froze the application for [N]ms. ZGC froze it for less than 1ms. If your p99 SLA is 50ms and G1GC pauses for 150ms, you breach it on schedule. Choose based on your SLA, not this benchmark."

---

### Slides 43-47 — Right-Sizing + DEMO 07

**Slides 43-46 — Over-Provisioning, Analysis, Bin-Packing, Cost**

The three-step anti-pattern (Slide 43): set Xmx + buffer → set CPU to GC spike peak → double everything + never revisit. After 12 months: 40-60% memory wasted, 3-5× CPU over-requested, 30-40% nodes wasted, $100k+/year waste.

Right-sizing analysis results (Slide 44): 7-workload table. Key callouts:
- `payment-service`: CPU 2000m → 560m (−72%) — GC spike detected, used p95 as basis
- `fraud-detection`: 1500m → 280m (−81%) — Quarkus requests copied from Spring Boot, never revisited
- `report-generator`: almost no change — honest exception, batch workload with real CPU

Bin-packing (Slide 45): 4 nodes → 2 nodes, +67% pod density, $6,720/month saving.

Cost case (Slide 46): $80,640 annual saving from 2 nodes eliminated. ROI: $6,720 saving for ~$400 engineering time = 17×.

**Slide 47 — DEMO 07**

```
Demo directory: quarkus-demo-07-rightsizing/
Command: ./demo.sh
No containers, no cluster needed — python3 stdlib only
Time budget: ~3 min
```

Runs against bundled sample data — 14 days of Prometheus export, 7 workloads. Generates `rightsizing-report.json` and kubectl commands ready to apply.

---

### Slides 48-50 — Panama + DEMO 08/09

**Slide 48 — Project Panama: The End of JNI**

Six JNI pain points vs four Panama solutions. The key message: FFM is finalized in JDK 22 — production ready, no `--enable-preview` on JDK 25.

Arena types — the key safety feature: `try (Arena arena = Arena.ofConfined())` — all native memory freed deterministically on close. You cannot leak if you use try-with-resources.

**Slide 49 — Demo 08: C++20 → FFM**

Five-step workflow. The code on the slide shows the jextract-generated calling pattern.

> **Note:** The slide shows `arena.allocateArray()` — this is the **preview API name** which was renamed to `arena.allocateFrom()` in the JDK 22 GA release. The actual demo code uses `allocateFrom()`.

```
Demo directory: quarkus-demo-08-panama/
Command: ./demo.sh
JDK required: 25 LTS
Builds C++ with g++ inside container — no local compiler needed
Time budget: ~8 min
```

**Slide 50 — Demo 09: LangChain4j ONNX**

The Panama stack: Quarkus REST → LangChain4j → ONNX Runtime → Panama FFM → native `.so` → MiniLM-L6-v2.

Single dependency bundles model + ONNX Runtime + Panama bindings:
```xml
<dependency>
    <groupId>dev.langchain4j</groupId>
    <artifactId>langchain4j-embeddings-all-minilm-l6-v2</artifactId>
    <version>0.36.2</version>
</dependency>
```

Use case to highlight: embed alert descriptions → find semantically similar past incidents → retrieve runbooks → full RAG pipeline in a Quarkus pod, no Python.

```
Demo directory: quarkus-demo-09-onnx/
Command: ./demo.sh
First run: downloads ~300MB (ONNX Runtime + model)
Time budget: ~10 min
```

---

### Slides 51-52 — Project Valhalla

**Slide 51 — The 30-Year Gap**

Two incompatible worlds: primitives (inline, cache-friendly, no GC cost, no generics) vs objects (heap pointer, scattered, GC-tracked, generics via boxing).

The cost: `List<Double>` uses 3× memory of `double[]`, destroys cache locality. `IntStream` exists only because `Stream<int>` is illegal.

Valhalla bridges both: `value class Point { double x; double y; }` — stored inline, no header, no GC tracking. `List<int>`, `Map<long,double>` — no boxing.

Status: value classes in preview JDK 25+; stable ~JDK 27-29 (2026-2027).

**Slide 52 — Why It Matters for Kubernetes**

Three columns — the cloud-native impact:
- Memory Footprint: `List<Double>` 3× memory → `List<double>` 1× memory → pod requests cut up to 50%
- GC Pressure: every boxed value GC-tracked → value types zero heap allocation → fewer pauses, HPA stays quiet
- Cache Performance: pointer array → inline data → L1/L2 cache-friendly → 2-10× throughput on data-intensive loops

Valhalla + Vector API: dense value arrays are what SIMD instructions operate on — the two projects land together.

---

### Slides 53-54 — JVM Anti-Patterns + Remediation

**Slide 53 — Common JVM Anti-Patterns on Kubernetes**

Four categories, 16 patterns. Don't read every one — pick 2-3 from each category that resonate with your audience:

**Memory anti-patterns:**
- Hardcoded `-Xmx/-Xms` — breaks silently with VPA or cluster admin resize
- `MaxRAMPercentage=90` — starves Metaspace + threads + Netty buffers → OOMKill
- No `MaxMetaspaceSize` — framework-heavy apps can leak to 800MB+ Metaspace

**GC & CPU:**
- Default `ParallelGCThreads` on large node — 64 threads for 2 CPU container
- CPU-based HPA with Java — GC pauses spike CPU → false scale-out
- `minReplicas: 1` — single pod + GC = 100% error rate

**AOT / Startup:**
- Using `@QuarkusTest` for AOT training (not `@QuarkusIntegrationTest`)
- `mvn package` instead of `mvn verify` — skips integration tests, empty cache
- Ignoring JDK version on cache rebuild — silent invalidation

**Observability:**
- No GC pause histogram — can't distinguish GC latency from application slowness
- `quarkus-micrometer-registry-prometheus` alone — misses unified OTel pipeline
- Tuning JVM flags without baseline — can't tell if change helped or hurt

**Slide 54 — Anti-Pattern Remediation**

Drop-in fixes for every anti-pattern on the previous slide. This slide can serve as a leave-behind — photograph-friendly for audience members.

---

## Timing Reference Card

| Section | Slides | Core time | Extended |
|---------|--------|-----------|----------|
| Opening + Agenda | 1-2 | 3 min | — |
| Heap (Section 01) | 3-7 | 8 min | — |
| Right-Sizing (Section 02) | 8-9 | 5 min | — |
| GC (Section 03) | 10-14 | 8 min | — |
| Startup (Section 04) | 15-17 | 7 min | — |
| Observability (Section 05) | 18-20 | 5 min | — |
| Autoscaling (Section 06) | 21-23 | 5 min | — |
| Tuning + ROI (Section 07) | 24-25 | 4 min | — |
| Demo recaps | 26-28 | 3 min | — |
| Takeaways + Q&A | 29-30 | 5 min | — |
| **Core total** | | **53 min** | |
| Leyden + Demo 04 | 31-33 | — | 8 min |
| gRPC + Demo 05 | 34-37 | — | 7 min |
| Low-Latency + Demo 06 | 38-42 | — | 7 min |
| Right-Sizing + Demo 07 | 43-47 | — | 5 min |
| Panama + Demo 08/09 | 48-50 | — | 5 min |
| Valhalla | 51-52 | — | 3 min |
| Anti-Patterns | 53-54 | — | 5 min |
| **Extended total** | | | **40 min** |

---

## Demo Troubleshooting

### Demo 01 — heap sizing
- If `jcmd` not found: use `podman exec <container> java -XX:+PrintFlagsFinal -version | grep MaxHeapSize`
- If container OOMKills immediately: reduce `--memory` flag in the demo script

### Demo 02 — GC monitoring
- **Blank Grafana dashboards:** Check `application.properties` has histogram config enabled. Check that `external-prometheus.yml` is mounted into `grafana-lgtm` with `:Z`.
- **Prometheus won't start:** Named volume permissions issue. Ensure `user: root` and `tmpfs: - /prometheus` in compose.
- **Registry selection prompt:** Image names must be fully qualified with `docker.io/` prefix.
- **Stack starts but no metrics:** Check Prometheus targets at http://localhost:9090/targets — both Quarkus apps should show as UP within 30s.

### Demo 03 — AppCDS
- **Build hangs:** Remove `dependency:go-offline` — hangs in UBI containers.
- **`-DskipTests` compiles tests:** Use `-Dmaven.test.skip=true` instead.

### Demo 04 — Leyden
- **No improvement:** Verify packaging is `aot-jar` not `fast-jar`. Check `mvn verify` was used not `mvn package`.
- **AOT cache doesn't load:** JVM fingerprint mismatch — trainer and runtime must be same UBI image tag.

### Demo 05 — gRPC
- **gRPC slower than REST:** Expected on localhost. State the caveat, show streaming benchmark instead.
- **`grpcurl` not found:** Demo continues in observe mode — streaming still works.

### Demo 06 — latency
- **ZGC slower in `hey` test:** Expected. Lead with GC pause delta from Steps 4-5, not `hey` p99.

### Demo 07 — right-sizing
- **`podman-compose` error:** v3 zip uses Python-only, no containers. Ensure running from `quarkus-demo-07-rightsizing/` directory.

### Demo 08 — Panama
- **Build fails: `allocateArray` not found:** API changed in JDK 22 GA. Use `allocateFrom()`.
- **Library not found at runtime:** Check `ldconfig` ran in Dockerfile and library is in `/usr/local/lib`.
- **Annotations on record:** JAX-RS annotations cannot be placed on record declarations — only on methods.

### Demo 09 — ONNX
- **First run slow:** ~300MB Maven download (ONNX Runtime + model). Normal. Use `--no-transfer-progress`.
- **Build context error:** Must run from inside the `quarkus-demo-09-onnx/` directory. `./demo.sh` handles this via `SCRIPT_DIR` cd.
