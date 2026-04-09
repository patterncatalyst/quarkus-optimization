# JVM Optimization Cheat Sheet — Java 21 on OpenShift / Kubernetes
## *Taming the JVM* — Quick Reference Card

---

## 1. Container-Aware JVM Flags (Add to EVERY Container)

```bash
# Java 21 defaults: UseContainerSupport is ON — MaxRAMPercentage is NOT set to 75
-XX:MaxRAMPercentage=75.0          # Heap = 75% of container memory limit
-XX:InitialRAMPercentage=50.0      # Start at 50% to reduce startup footprint
-XX:MinRAMPercentage=25.0          # Never go below 25% (small container safety)
-XX:NativeMemoryTracking=summary   # Enable: jcmd <pid> VM.native_memory summary
```

**In OpenShift Deployment:**
```yaml
env:
- name: JAVA_OPTS
  value: "-XX:MaxRAMPercentage=75.0 -XX:+UseZGC -XX:+ZGenerational"
resources:
  requests: { memory: "256Mi", cpu: "250m" }
  limits:   { memory: "512Mi", cpu: "1000m" }
```

**Verify:** `java -XX:+PrintFlagsFinal -version | grep MaxRAMPercentage`

---

## 2. Garbage Collector Selection

| GC | Use When | Java 21 Flags |
|----|----------|---------------|
| **G1GC** | General microservices, SLO > 200ms | `-XX:+UseG1GC -XX:MaxGCPauseMillis=200` |
| **ZGC (Gen)** | Low-latency APIs, any heap size ⭐ | `-XX:+UseZGC -XX:+ZGenerational` |
| **Shenandoah** | RHEL/OpenJDK default, sub-ms pauses | `-XX:+UseShenandoahGC` |
| **Serial GC** | Batch only, heap < 256MB | `-XX:+UseSerialGC` |

**Decision rule:** If `jvm_gc_pause_seconds P99 > 500ms` → switch to ZGC/Shenandoah

---

## 3. Critical GC Tuning Flags

```bash
# ALWAYS match ParallelGCThreads to your CPU limit!
-XX:ParallelGCThreads=2            # = your CPU limit (NOT host CPU count)
-XX:ConcGCThreads=1                # Background GC threads (half of Parallel)

# G1GC specific
-XX:G1HeapRegionSize=16m           # Larger regions = less bookkeeping
-XX:InitiatingHeapOccupancyPercent=45  # Start GC earlier in containers
-XX:+G1UseAdaptiveIHOP             # Self-tune IHOP threshold

# ZGC specific (Java 21)
-XX:+UseZGC -XX:+ZGenerational     # Enable Generational ZGC (Java 21)
-XX:SoftMaxHeapSize=384m           # Soft limit: GC more aggressively above this
-XX:ZCollectionInterval=5          # Proactive GC every 5 seconds

# Shenandoah specific
-XX:ShenandoahGCMode=adaptive      # Self-tuning heuristic
```

---

## 4. Startup Acceleration

### AppCDS (35–55% faster startup)
```bash
# Step 1: Capture class list (training run)
java -Xshare:off \
     -XX:DumpLoadedClassList=app.lst \
     -Dspring.context.exit=onRefresh \
     -jar app.jar

# Step 2: Generate archive
java -Xshare:dump \
     -XX:SharedClassListFile=app.lst \
     -XX:SharedArchiveFile=app.jsa \
     -jar app.jar

# Step 3: Production run
java -Xshare:on \
     -XX:SharedArchiveFile=/app/app.jsa \
     -XX:MaxRAMPercentage=75.0 \
     -jar app.jar
```

### Spring Boot 4.0 (Maven, one command)
```bash
./mvnw spring-boot:build-image  # Generates AppCDS archive automatically
```

### Other startup flags
```bash
-XX:ReservedCodeCacheSize=128m      # Prevent JIT cache exhaustion
-Djava.security.egd=file:/dev/./urandom  # Fix slow SecureRandom at startup
```

---

## 5. Java 21 Virtual Threads (JEP 444)

```properties
# application.properties — Spring Boot 4.0
spring.threads.virtual.enabled=true  # One line. Done.
```

```java
// Explicit usage — identical API to platform threads
try (var executor = Executors.newVirtualThreadPerTaskExecutor()) {
    futures = tasks.stream()
        .map(t -> executor.submit(() -> process(t)))
        .toList();
}

// Debug pinning issues (synchronized + I/O = carrier thread blocked)
-Djdk.tracePinnedThreads=full
```

**Container sizing impact:** 200 platform threads × 1MB = 200MB off-heap.  
200 virtual threads × ~few KB = near-zero stack overhead → shrink your memory limit.

---

## 6. Native Memory Tracking (What's Eating My Memory?)

```bash
# Enable at startup
-XX:NativeMemoryTracking=summary

# Query at runtime
jcmd <pid> VM.native_memory summary
jcmd <pid> VM.native_memory detail   # per-allocation site
jcmd <pid> VM.native_memory baseline # take snapshot
jcmd <pid> VM.native_memory diff     # compare to baseline

# Key regions to watch:
# Java Heap, Class (Metaspace), Code (JIT), Thread, GC
```

---

## 7. Essential JVM Diagnostic Commands

```bash
# Heap and GC
jcmd <pid> GC.heap_info             # Heap regions and usage
jcmd <pid> GC.run                   # Trigger full GC (test only!)
jcmd <pid> VM.flags                 # All active JVM flags

# Memory
jcmd <pid> VM.native_memory summary # Off-heap breakdown
jcmd <pid> VM.native_memory detail  # Per-region detail

# Threads (Java 21 virtual thread aware)
jcmd <pid> Thread.print             # All thread stacks (slow if many VTs)
jcmd <pid> Thread.print -e          # Exclude idle virtual threads

# JFR Recordings
jcmd <pid> JFR.start name=profile duration=60s filename=/tmp/profile.jfr
jcmd <pid> JFR.dump filename=/tmp/snapshot.jfr
jcmd <pid> JFR.stop

# Find PID in container
jcmd                                # Lists all JVM processes
```

---

## 8. Key Prometheus / Micrometer Queries

```promql
# GC pause P99 (milliseconds) — alert if > 500ms
histogram_quantile(0.99,
  rate(jvm_gc_pause_seconds_bucket[5m])
) * 1000

# Heap utilization — alert if > 85%
jvm_memory_used_bytes{area="heap"}
/ jvm_memory_max_bytes{area="heap"}

# GC collections per minute
rate(jvm_gc_pause_seconds_count[1m]) * 60

# Time spent in GC (seconds per second of wall clock)
rate(jvm_gc_pause_seconds_sum[1m])

# Live thread count (includes virtual threads in Micrometer 1.12+)
jvm_threads_live_threads

# Non-heap memory (Metaspace + JIT code cache)
jvm_memory_used_bytes{area="nonheap"}
```

**application.properties for full JVM metrics:**
```properties
management.metrics.distribution.percentiles-histogram.jvm.gc.pause=true
management.metrics.distribution.percentiles.jvm.gc.pause=0.5,0.95,0.99
management.metrics.distribution.slo.jvm.gc.pause=50ms,100ms,200ms,500ms
```

---

## 9. HPA Anti-Patterns → Fixes

| Anti-Pattern | Problem | Fix |
|-------------|---------|-----|
| `resource: cpu` HPA | GC pauses = false CPU spikes | Scale on RPS or custom metric |
| `stabilizationWindowSeconds: 0` | Scales out on every GC pulse | Use `120s` for scaleUp |
| `minReplicas: 1` | GC STW = 100% downtime | Set `minReplicas: 2` |
| Memory limit = request | No GC surge buffer | Limit = request × 1.3 |
| HPA + VPA on same resource | Fight each other | VPA for memory, HPA on RPS |

---

## 10. Resource Sizing Formula

```
Container Memory Limit =
  Max Heap (MaxRAMPercentage% of limit)     ← set limit first, then %
+ Metaspace (typically 100–250 MB)
+ Thread Stacks (platform: N × 1MB; virtual: ~0)
+ JIT Code Cache (128–256 MB)
+ GC Structures (50–150 MB)
+ Safety Buffer (15–20%)

Requests  = P50 steady-state RSS
Limits    = P99 peak RSS × 1.15–1.25

Measure RSS with: kubectl top pod --containers
                  jcmd <pid> VM.native_memory summary
```

---

## 11. Tuning Workflow Checklist

```
□ 1. INSTRUMENT: Enable JFR + Prometheus (Micrometer) + Cryostat agent
□ 2. BASELINE:   Run load test, capture P50/P99 latency + GC pause + RSS
□ 3. DIAGNOSE:   Open JFR in Java Mission Control, find top allocation sites
□ 4. TUNE:       Change ONE thing, document the hypothesis
□ 5. VALIDATE:   Re-run load test, compare against baseline
□ 6. COMMIT / REVERT: If improved → merge. If not → revert, try next thing.
□ 7. REPEAT: Until SLO met or cost target achieved
```

---

## 12. Quick Reference — Java Versions

| Version | LTS? | Key Container Features |
|---------|------|------------------------|
| Java 21 | ✅ LTS (2023–2026) | Virtual Threads (JEP 444), Generational ZGC, AppCDS mature, cgroup v2 |
| Java 17 | ✅ LTS (2021–2026) | UseContainerSupport default, ZGC production-ready |
| Java 11 | ✅ LTS (EOL 2026) | UseContainerSupport (8u191 backport), basic CDS |
| < Java 11 | ❌ EOL | Upgrade now — missing container support |

**Recommended: Java 21 LTS for all new and migrated workloads.**

---

## 13. Useful Tools

| Tool | Purpose | Link |
|------|---------|-------|
| **Cryostat** | JFR on OpenShift — Kubernetes-native | cryostat.io |
| **Java Mission Control** | JFR recording analysis | adoptium.net/jmc |
| **Grafana JVM Dashboard** | Pre-built Micrometer dashboard | grafana.com/dashboards/4701 |
| **KEDA** | Kubernetes event-driven autoscaling | keda.sh |
| **Eclipse Memory Analyzer** | Heap dump analysis (OOM post-mortem) | eclipse.dev/mat |
| **async-profiler** | Low-overhead CPU/alloc profiler | github.com/async-profiler |

---

*Based on: "Optimizing Cloud Native Java" & "SRE with Java Microservices" (O'Reilly)*  
*Demo repo: github.com/[your-repo]/java-openshift-optimization-demos*
