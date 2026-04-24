# JVM Optimization Cheat Sheet
## Quarkus 3.33.1 LTS / Java 21 & 25 / OpenShift & Kubernetes

Quick-reference card for JVM tuning on container platforms. All flags
verified on Red Hat UBI9 with Podman and OpenShift.

---

## Container Heap Sizing

```bash
# ✅ Always include — reads cgroup limits not host RAM
-XX:+UseContainerSupport

# Heap as percentage of container memory limit
-XX:MaxRAMPercentage=75.0       # 75% → heap, 25% → off-heap
-XX:InitialRAMPercentage=50.0   # avoids startup GC pressure
-XX:MinRAMPercentage=25.0       # floor for very small containers

# Verify what the JVM sees
jcmd <pid> VM.flags | grep -E "MaxHeap|RAMPercentage"
java -XX:+PrintFlagsFinal -version 2>&1 | grep MaxHeapSize
```

**Rule:** Never set `-Xmx` directly in containers. Use `MaxRAMPercentage` so
the heap scales automatically when you resize the pod.

---

## Garbage Collector Quick-Select

```
Workload type?
├─ General purpose, throughput-oriented, loose SLA → G1GC (default on Temurin/Corretto)
├─ Deployed on OpenShift / UBI9 → Shenandoah (already the default)
├─ p99 SLA < 20ms, heap < 32GB → Shenandoah
├─ p99 SLA < 1ms, or heap > 32GB → ZGC + Generational
└─ Batch/analytics, GC pauses acceptable → G1GC or Parallel GC
```

### G1GC

```bash
-XX:+UseG1GC
-XX:MaxGCPauseMillis=200        # soft target
-XX:G1HeapRegionSize=4m         # 1-32MB; match to huge page size
-XX:ParallelGCThreads=<N>       # match to CPU request
-XX:ConcGCThreads=<N/2>
```

### Shenandoah (Red Hat UBI9 default, JDK 8+)

```bash
-XX:+UseShenandoahGC
-XX:ShenandoahGCHeuristics=adaptive    # default
# Other heuristics: compact, aggressive, static
```

### ZGC Generational (JDK 21+)

```bash
-XX:+UseZGC
-XX:+ZGenerational              # generational mode — lower CPU overhead
-XX:+AlwaysPreTouch             # pre-fault heap; eliminates page fault jitter
```

**ZGC throughput note:** ZGC inserts a load barrier at every object reference
read — ~5-15% throughput overhead vs G1GC. In micro-benchmarks that maximise
allocation, ZGC will show lower throughput. The benefit is consistent sub-ms
pause times and smooth CPU profile (no HPA false triggers).

---

## GC Defaults by Container Image

| Image | Default GC | Pauses |
|-------|-----------|--------|
| `ubi9/openjdk-21-runtime` | **Shenandoah** | 1–20ms |
| `eclipse-temurin:21` | G1GC | 10–300ms |
| `amazoncorretto:21` | G1GC | 10–300ms |
| `mcr.microsoft.com/openjdk/jdk:21` | G1GC | 10–300ms |
| `azul/zulu-openjdk:21` | G1GC | 10–300ms |
| `ibm-semeru-runtime-open-21` | OpenJ9 Balanced | Different JVM |

> Demos 02 and 06 explicitly override UBI9's Shenandoah default with
> `-XX:+UseG1GC` and `-XX:+UseZGC` for clean comparison.

---

## Thread Count Tuning

```bash
# Always set explicitly — JVM may see node CPUs not container CPUs
-XX:ActiveProcessorCount=<cpu-request>
-XX:ParallelGCThreads=<cpu-request>       # stop-the-world GC threads
-XX:ConcGCThreads=<cpu-request/2>         # background GC threads
-XX:CICompilerCount=2                     # JIT compiler threads (usually 2)

# Example: 2-CPU container
-XX:ActiveProcessorCount=2
-XX:ParallelGCThreads=2
-XX:ConcGCThreads=1
-XX:CICompilerCount=2
```

**Why:** On a 64-CPU node with a 2-CPU container request, the JVM reads
`/proc/cpuinfo` and sees 64 CPUs. It spawns 64 GC threads, all competing
for 2 CPUs. Setting these flags explicitly prevents that.

---

## Startup Optimization

### AppCDS (Application Class Data Sharing)

Caches parsed + verified bytecode. JDK 10+.
Quarkus: ~5% improvement. Spring Boot: ~40% improvement.

```properties
# application.properties (Quarkus)
quarkus.package.jar.appcds.enabled=true
```

```bash
# Spring Boot jarmode extract approach
java -Djarmode=tools -jar app.jar extract
java -XX:ArchiveClassesAtExit=app.jsa \
     -Dspring.context.exit=onRefresh -jar app/app.jar
java -XX:SharedArchiveFile=app.jsa -jar app/app.jar
```

### Project Leyden AOT Cache (JDK 25)

Caches parsed + linked classes + JIT profiles. 60–75% improvement.
Verified: 609ms → 148ms on Quarkus 3.33.1 LTS.

```properties
# application.properties (Quarkus)
quarkus.package.jar.aot.enabled=true    # must use aot-jar, not fast-jar
```

```bash
# Training run (during build — creates the cache)
mvn verify -DskipITs=false

# Runtime
java -XX:AOTCache=app.aot -jar quarkus-run.jar
```

**Critical:** JVM fingerprint (vendor + version) must match between training
and runtime. Use the same UBI image in both stages of your multi-stage Dockerfile.

### Startup Improvement Ladder

```
Cold JVM (no optimisation):
  Spring Boot 4.0.5:  ~2,700ms
  Quarkus 3.33.1:     ~600ms

+ AppCDS:
  Spring Boot:        ~1,600ms  (-40%)
  Quarkus:            ~570ms    (-5%)

+ Leyden AOT (JDK 25):
  Quarkus:            ~148ms    (-75%)

+ Native (Mandrel/GraalVM):
  Quarkus native:     ~17ms     (no JIT at runtime)
```

---

## Kubernetes Resource Configuration

### Guaranteed QoS (recommended for JVM workloads)

```yaml
resources:
  requests:
    cpu: "2"          # integer — enables CPU Manager static allocation
    memory: "2Gi"
  limits:
    cpu: "2"          # must equal request for Guaranteed QoS
    memory: "2Gi"
```

### Memory sizing formula

```
Container memory limit = (Xmx × 1.3) + 256Mi overhead

Where Xmx ≈ MaxRAMPercentage × limit

Example: 2GB limit, MaxRAMPercentage=75%
  Xmx = 1.5GB
  Off-heap (Metaspace + threads + JIT + Netty) ≈ 500MB
  → Set limit to 2GB minimum
```

### Right-sizing from observed data

```bash
# CPU: p99 observed × 1.30 headroom (use p95 if GC-dominated spikes)
# Memory: p99 RSS × 1.25 headroom, round to nearest 64MB

# Detect GC-dominated CPU: p99/p50 > 3× AND GC pause p99 > 100ms
# → use p95 as CPU basis to avoid over-provisioning for millisecond events
```

---

## HPA (Horizontal Pod Autoscaler) for JVM

### The problem

G1GC stop-the-world pauses → CPU spike → HPA scales out →
JIT warmup on new pod → HPA scales in → repeat. ("HPA thrash")

### Minimum fix: stabilisation window

```yaml
behavior:
  scaleUp:
    stabilizationWindowSeconds: 120    # 2 min — ignores GC spikes
    policies:
    - type: Pods
      value: 1
      periodSeconds: 60
  scaleDown:
    stabilizationWindowSeconds: 300
```

### Better: RPS-based scaling (not CPU)

```yaml
metrics:
- type: External
  external:
    metric:
      name: http_requests_per_second
    target:
      type: AverageValue
      averageValue: "500"
```

### Best: KEDA with Prometheus query

```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
spec:
  triggers:
  - type: prometheus
    metadata:
      query: sum(rate(http_server_requests_seconds_count[2m]))
      threshold: "500"
```

---

## Prometheus Metrics (Quarkus + Micrometer)

```properties
# application.properties — required for Grafana GC dashboards
quarkus.micrometer.export.prometheus.enabled=true
quarkus.micrometer.binder.jvm=true
quarkus.micrometer.binder.http-server.enabled=true

# Histograms — required for percentile queries to work
quarkus.micrometer.distribution.percentiles-histogram.jvm.gc.pause=true
quarkus.micrometer.distribution.percentiles.jvm.gc.pause=0.5,0.95,0.99
quarkus.micrometer.distribution.percentiles-histogram.http.server.requests=true
quarkus.micrometer.distribution.percentiles.http.server.requests=0.5,0.95,0.99
```

### Key PromQL queries

```promql
# GC pause P99 (ms)
histogram_quantile(0.99, rate(jvm_gc_pause_seconds_bucket[1m])) * 1000

# Heap utilisation %
jvm_memory_used_bytes{area="heap"} / jvm_memory_max_bytes{area="heap"} * 100

# HTTP request P99 (ms)
histogram_quantile(0.99, rate(http_server_requests_seconds_bucket[1m])) * 1000

# CPU waste — requested minus actual (right-sizing)
kube_pod_container_resource_requests{resource="cpu"}
  - on(pod,namespace) avg_over_time(container_cpu_usage_seconds_total[14d])

# Memory waste — requested minus actual
kube_pod_container_resource_requests{resource="memory"}
  - on(pod,namespace) avg_over_time(container_memory_working_set_bytes[14d])
```

---

## Low-Latency Kubernetes Tuning

Listed by impact. Items 1-3 are practical for any latency-sensitive service.
Items 4-6 require cluster configuration changes.

### 1. Switch to ZGC (biggest single impact)

```bash
-XX:+UseZGC -XX:+ZGenerational
```

### 2. Match thread counts to CPU request

```bash
-XX:ActiveProcessorCount=<N>
-XX:ParallelGCThreads=<N>
-XX:ConcGCThreads=<N/2>
-XX:CICompilerCount=2
```

### 3. Huge pages + pre-touch

```bash
-XX:+UseLargePages
-XX:+AlwaysPreTouch
```

```yaml
resources:
  requests:
    hugepages-2Mi: "4Gi"
    memory: "4Gi"
```

### 4. CPU Manager + Topology Manager (cluster config)

```yaml
# kubelet-config.yaml
cpuManagerPolicy: static
topologyManagerPolicy: single-numa-node
memoryManagerPolicy: Static
```

### 5. Kernel CPU isolation (node config)

```bash
# /etc/default/grub
GRUB_CMDLINE_LINUX="isolcpus=4-11 nohz_full=4-11 rcu_nocbs=4-11"
```

### 6. OpenShift PerformanceProfile (automates 4+5)

```yaml
apiVersion: performance.openshift.io/v2
kind: PerformanceProfile
metadata:
  name: low-latency
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

---

## Panama FFM (JDK 22+) — Quick Reference

```java
// Load native library
SymbolLookup lib = SymbolLookup.libraryLookup(
    System.mapLibraryName("mylib"), Arena.global());

// Bind C function: int my_fn(double*, int32_t, double*)
MethodHandle fn = Linker.nativeLinker().downcallHandle(
    lib.find("my_fn").orElseThrow(),
    FunctionDescriptor.of(JAVA_INT, ADDRESS, JAVA_INT, ADDRESS));

// Call with arena — memory freed on close
try (Arena arena = Arena.ofConfined()) {
    MemorySegment data = arena.allocateFrom(JAVA_DOUBLE, myArray);  // JDK 22+
    MemorySegment out  = arena.allocate(JAVA_DOUBLE);
    int rc = (int) fn.invoke(data, myArray.length, out);
    double result = out.get(JAVA_DOUBLE, 0);
}
// ⚠️ allocateFrom() not allocateArray() — preview API was renamed at GA
// ⚠️ Do not put JAX-RS annotations on record declarations — only on methods
```

---

## gRPC vs REST — Decision Matrix

| Scenario | REST | gRPC | Winner |
|----------|------|------|--------|
| Localhost benchmark (demo) | ✅ faster | slower | REST |
| Production pod-to-pod | baseline | ✅ ~3-4× faster | gRPC |
| Server streaming | ❌ boilerplate | ✅ native | gRPC |
| High concurrency (500+) | many TCP conns | ✅ HTTP/2 mux | gRPC |
| Large payloads (>5KB) | verbose JSON | ✅ 10× smaller | gRPC |
| Public API / browser | ✅ native | needs proxy | REST |
| curl / Postman debug | ✅ trivial | needs grpcurl | REST |
| Small heap microservice | either | either | context |

---

## Right-Sizing Quick Reference

```
CPU request  = observed p99 CPU × 1.30
               (use p95 if p99/p50 > 3× AND GC pause p99 > 100ms)

Memory request = observed p99 RSS × 1.25
                 rounded to nearest 64MB
                 minimum 256MB

QoS target = Guaranteed (requests == limits)
             → enables CPU Manager static allocation
             → scheduler can pin CPUs to NUMA node

Apply with:
kubectl set resources deployment/<n> \
  --requests=cpu=<new>m,memory=<new>Mi \
  --limits=cpu=<new>m,memory=<new>Mi
```

---

## Podman on Fedora/RHEL — Required Fixes

| Problem | Symptom | Fix |
|---------|---------|-----|
| Unqualified image name | Interactive registry prompt blocks build | Prefix all images: `docker.io/prom/prometheus:...` |
| SELinux bind mount | Container can't read mounted file, no error | Use `:Z` label: `./file:/container/file:Z` |
| Named volume permissions | Prometheus crashes silently (uid 65534 can't write to root-owned volume) | `user: root` + `tmpfs: - /prometheus` |
| `dependency:go-offline` | Maven hangs indefinitely in UBI | Remove entirely — use `--no-transfer-progress` only |
| Old cached image | Build uses stale Dockerfile with old `FROM` | `podman rmi <image>`, then rebuild |

---

## JVM Flags Cookbook

### Minimum safe container config

```bash
-XX:+UseContainerSupport
-XX:MaxRAMPercentage=75.0
-XX:InitialRAMPercentage=50.0
```

### Production latency-sensitive service

```bash
-XX:+UseContainerSupport
-XX:MaxRAMPercentage=75.0
-XX:InitialRAMPercentage=50.0
-XX:+UseZGC
-XX:+ZGenerational
-XX:ActiveProcessorCount=<N>
-XX:ParallelGCThreads=<N>
-XX:ConcGCThreads=<N/2>
-XX:CICompilerCount=2
-XX:+AlwaysPreTouch
```

### Quarkus + Leyden AOT (JDK 25)

```bash
-XX:+UseContainerSupport
-XX:MaxRAMPercentage=75.0
-XX:AOTCache=app.aot
-XX:ActiveProcessorCount=<N>
```

### High-throughput batch

```bash
-XX:+UseContainerSupport
-XX:MaxRAMPercentage=75.0
-XX:+UseG1GC
-XX:MaxGCPauseMillis=500
-XX:ParallelGCThreads=<N>
-XX:+AlwaysPreTouch
```

---

## Key Flags Reference

| Flag | Default | Purpose |
|------|---------|---------|
| `+UseContainerSupport` | on (JDK 10+) | Read cgroup memory limit |
| `MaxRAMPercentage=75.0` | 25.0 | Heap as % of container limit |
| `InitialRAMPercentage=50.0` | varies | Initial heap |
| `+UseG1GC` | yes (Temurin/Corretto) | G1GC — general purpose |
| `+UseShenandoahGC` | yes (UBI9) | Shenandoah — 1-20ms pauses |
| `+UseZGC` | no | ZGC — sub-ms pauses |
| `+ZGenerational` | no | Generational ZGC (JDK 21+) |
| `ActiveProcessorCount=N` | auto | Override CPU count for JVM |
| `ParallelGCThreads=N` | auto | Stop-the-world GC threads |
| `ConcGCThreads=N` | auto | Background GC threads |
| `CICompilerCount=N` | auto | JIT compiler threads |
| `MaxGCPauseMillis=200` | 200 | G1GC pause target (soft) |
| `+AlwaysPreTouch` | off | Pre-fault heap at startup |
| `+UseLargePages` | off | Huge pages (requires kernel config) |
| `+UseNUMA` | off | NUMA-aware allocation |
| `AOTCache=app.aot` | off | Leyden AOT cache path (JDK 25) |

---

## AppCDS vs Leyden vs Native

| | AppCDS | Leyden AOT | Native |
|---|---|---|---|
| JDK | 10+ (GA) | 25 LTS | Any (GraalVM/Mandrel) |
| Caches | Parsed bytecode | Bytecode + links + JIT profiles | Everything (compiled to native) |
| Quarkus improvement | ~5% | ~75% | ~97% |
| Spring Boot improvement | ~40% | TBD | ~97% |
| Training required | Yes (startup) | Yes (`@QuarkusIntegrationTest`) | Yes (build-time analysis) |
| JIT at runtime | Yes | Yes (pre-warmed) | No |
| Config | `appcds.enabled=true` | `aot.enabled=true` | `-Pnative` profile |
| Packaging | `fast-jar` | **`aot-jar`** (auto) | native binary |

---

## Health Check Endpoints (Quarkus)

```
/q/health        → combined liveness + readiness
/q/health/live   → liveness (is the JVM alive?)
/q/health/ready  → readiness (is the app ready to serve traffic?)
/q/health/started→ started (one-time startup check)
/q/metrics       → Prometheus metrics
/q/dev/          → Dev UI (dev mode only)
/q/swagger-ui/   → OpenAPI (if quarkus-smallrye-openapi is present)
```

---

## OpenShift Cost Management

```
Console → Cost Management → Optimizations
→ over-provisioned workloads ranked by saving potential
→ generates kubectl commands automatically

API:
GET /api/cost-management/v1/recommendations/openshift/

PromQL equivalents (any Prometheus):
# CPU waste:
kube_pod_container_resource_requests{resource="cpu"}
  - on(pod,namespace) avg_over_time(container_cpu_usage_seconds_total[14d])

# Memory waste:
kube_pod_container_resource_requests{resource="memory"}
  - on(pod,namespace) avg_over_time(container_memory_working_set_bytes[14d])
```

---

## Version Matrix

| Component | Demo 01-06 | Demo 04, 08, 09 | Notes |
|-----------|-----------|-----------------|-------|
| Java | 21 LTS | 25 LTS | |
| Quarkus | 3.33.1 LTS | 3.33.1 LTS | |
| Spring Boot | 4.0.5 | — | Demo 03 comparison |
| UBI runtime | openjdk-21-runtime | openjdk-25-runtime | |
| Default GC (UBI) | **Shenandoah** | **Shenandoah** | |
| Podman | 4.x+ | 4.x+ | |
| podman-compose | 1.x+ | — | Demo 02 only |
| LangChain4j | — | 0.36.2 | Demo 09 |
| ONNX Runtime | — | bundled | Demo 09 |
| g++ / cmake | — | 10+ / 3.20+ | Demo 08 (inside container) |
