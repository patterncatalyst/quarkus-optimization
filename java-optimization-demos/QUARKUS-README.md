# Quarkus on OpenShift & Kubernetes — Configuration Reference

Comprehensive configuration reference for Quarkus 3.33.1 LTS workloads running
on OpenShift and Kubernetes. Covers container-aware JVM tuning, GC selection,
startup optimization, observability, and gRPC — with accurate defaults for the
Red Hat UBI9 container images used throughout these demos.

---

## Table of Contents

- [Container Images](#container-images)
- [JVM Heap Sizing](#jvm-heap-sizing)
- [Garbage Collector Selection](#garbage-collector-selection)
- [Startup Optimization](#startup-optimization)
- [Project Leyden AOT Cache](#project-leyden-aot-cache)
- [Observability — Metrics](#observability--metrics)
- [Observability — Tracing](#observability--tracing)
- [gRPC Configuration](#grpc-configuration)
- [Kubernetes Resource Configuration](#kubernetes-resource-configuration)
- [HPA Configuration for JVM Workloads](#hpa-configuration-for-jvm-workloads)
- [Panama FFM (JDK 22+)](#panama-ffm-jdk-22)
- [LangChain4j ONNX Embeddings](#langchain4j-onnx-embeddings)
- [Native Image](#native-image)
- [Development Mode](#development-mode)
- [Common Pitfalls](#common-pitfalls)

---

## Container Images

### UBI9 Images (used throughout these demos)

```dockerfile
# Builder — includes Maven + full JDK
FROM docker.io/library/maven:3.9-eclipse-temurin-21 AS builder

# Runtime — lean, no compiler, no Maven
FROM registry.access.redhat.com/ubi9/openjdk-21-runtime

# JDK 25 variants (Demo 04, 08, 09)
FROM docker.io/library/maven:3.9-eclipse-temurin-25 AS builder
FROM registry.access.redhat.com/ubi9/openjdk-25-runtime
```

> **⚠️ Default GC on UBI9:** `ubi9/openjdk-21-runtime` ships **Shenandoah** as
> the default GC — Red Hat's concurrent low-latency collector. This differs from
> Eclipse Temurin, Amazon Corretto, and Microsoft OpenJDK which default to G1GC.
> To reproduce a G1GC vs ZGC comparison, override explicitly:
> `JAVA_OPTS="-XX:+UseG1GC"` / `JAVA_OPTS="-XX:+UseZGC -XX:+ZGenerational"`

### GC Default by Image

| Image | Default GC | Pause Target |
|-------|-----------|--------------|
| `ubi9/openjdk-21-runtime` (Red Hat) | **Shenandoah** | 1–20ms |
| `eclipse-temurin:21` | G1GC | 10–300ms |
| `amazoncorretto:21` | G1GC | 10–300ms |
| `mcr.microsoft.com/openjdk/jdk:21` | G1GC | 10–300ms |
| `azul/zulu-openjdk:21` | G1GC | 10–300ms |
| `ibm-semeru-runtime-open-21` | OpenJ9 Balanced | Different JVM |

### Multi-Stage Dockerfile Pattern (all demos)

```dockerfile
FROM docker.io/library/maven:3.9-eclipse-temurin-21 AS builder
WORKDIR /build
USER root                                    # required for UBI build stage
COPY pom.xml .
COPY src ./src
RUN mvn package -Dmaven.test.skip=true --no-transfer-progress

FROM registry.access.redhat.com/ubi9/openjdk-21-runtime
WORKDIR /deployments

COPY --from=builder /build/target/quarkus-app/lib/     ./lib/
COPY --from=builder /build/target/quarkus-app/*.jar    ./
COPY --from=builder /build/target/quarkus-app/app/     ./app/
COPY --from=builder /build/target/quarkus-app/quarkus/ ./quarkus/

EXPOSE 8080
USER 185                                     # UBI9 runtime default user
ENTRYPOINT ["java", \
  "-XX:+UseContainerSupport", \
  "-XX:MaxRAMPercentage=75.0", \
  "-jar", "quarkus-run.jar"]
```

**Critical notes:**
- `USER root` in builder stages (UBI requirement)
- `USER 185` before ENTRYPOINT in runtime stage
- `-Dmaven.test.skip=true` not `-DskipTests` (skips compilation of tests too)
- Never use `dependency:go-offline` — hangs in UBI containers
- All image names must be fully qualified for Podman (no implicit Docker Hub)

---

## JVM Heap Sizing

### Core flags (all containers)

```bash
-XX:+UseContainerSupport        # reads cgroup limits — default since JDK 10
-XX:MaxRAMPercentage=75.0       # 75% of container limit → max heap
-XX:InitialRAMPercentage=50.0   # avoids startup GC pressure
-XX:MinRAMPercentage=25.0       # minimum heap floor
```

### In application.properties

```properties
# Quarkus passes these through to the JVM at startup
quarkus.jvm.additional-jvm-args=-XX:MaxRAMPercentage=75.0
quarkus.jvm.additional-jvm-args=-XX:InitialRAMPercentage=50.0
```

### In Dockerfile ENTRYPOINT

```dockerfile
ENTRYPOINT ["java", \
  "-XX:+UseContainerSupport", \
  "-XX:MaxRAMPercentage=75.0", \
  "-XX:InitialRAMPercentage=50.0", \
  "-jar", "quarkus-run.jar"]
```

### Via environment variable

```yaml
# docker-compose.yml or Kubernetes Deployment
env:
  - name: JAVA_OPTS
    value: "-XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0"
```

### Verify at runtime

```bash
# Check what heap the JVM actually configured
podman exec <container> java -XX:+PrintFlagsFinal -version 2>&1 | grep MaxHeapSize

# Via jcmd inside the container
podman exec <container> jcmd 1 VM.flags | grep RAM
```

---

## Garbage Collector Selection

### G1GC (general purpose — not UBI9 default)

```bash
-XX:+UseG1GC
-XX:MaxGCPauseMillis=200        # soft target (not guaranteed)
-XX:G1HeapRegionSize=4m         # match to huge page size if using huge pages
-XX:ParallelGCThreads=2         # match to CPU request (integer)
-XX:ConcGCThreads=1             # half of ParallelGCThreads
```

**Best for:** General-purpose workloads, throughput-oriented services, heaps under 32GB.

### Shenandoah (UBI9 default — Red Hat's concurrent GC)

```bash
-XX:+UseShenandoahGC
-XX:ShenandoahGCHeuristics=adaptive    # default — adapts to allocation rate
# -XX:ShenandoahGCHeuristics=compact   # for memory-constrained environments
# -XX:ShenandoahGCHeuristics=aggressive # for lowest possible pauses
```

**Best for:** Latency-sensitive services, 1–20ms pause target, JDK 8+ (Red Hat builds), JDK 12+ (upstream).

### ZGC Generational (sub-millisecond — JDK 21+)

```bash
-XX:+UseZGC
-XX:+ZGenerational              # required for generational mode (JDK 21+)
-XX:+AlwaysPreTouch             # pre-fault heap pages at startup
```

**Best for:** Services with p99 SLA < 10ms, heaps > 32GB (pauses don't scale with heap size), HPA stability (smooth CPU profile — no GC spike false scale-outs).

### Thread count tuning (all GCs)

```bash
# Set explicitly based on CPU request — never rely on JVM auto-detection
-XX:ActiveProcessorCount=<N>    # match to cpu request (integer)
-XX:ParallelGCThreads=<N>       # GC stop-the-world threads
-XX:ConcGCThreads=<N/2>         # background GC threads
-XX:CICompilerCount=2           # JIT compiler threads (usually 2)
```

### In application.properties

```properties
quarkus.jvm.additional-jvm-args=-XX:+UseZGC
quarkus.jvm.additional-jvm-args=-XX:+ZGenerational
quarkus.jvm.additional-jvm-args=-XX:ActiveProcessorCount=2
```

---

## Startup Optimization

### AppCDS (Application Class Data Sharing)

Caches parsed and verified class bytecode. ~5% improvement on Quarkus
(already pre-processes at build time), ~40% on Spring Boot.

```properties
# application.properties
quarkus.package.jar.appcds.enabled=true
```

```dockerfile
# The Quarkus Maven plugin runs a training pass during build
# Archive is embedded in the container image automatically
```

**Verify AppCDS is active:**
```bash
podman exec <container> jcmd 1 VM.flags | grep SharedArchive
```

### Startup pre-touch

```bash
# Pre-fault all heap pages at startup — eliminates page fault jitter at runtime
-XX:+AlwaysPreTouch
```

Makes startup slower but eliminates the latency spike during the first GC cycle
when the JVM maps physical pages for the first time.

---

## Project Leyden AOT Cache

Available in JDK 25 LTS. Caches parsed + linked classes AND JIT method profiles
from a training run. Typically achieves 60–75% startup improvement on top of
Quarkus's already-fast baseline.

**Verified result:** 609ms → 148ms (−75%) on JDK 25 with Quarkus 3.33.1 LTS.

### Configuration

```properties
# application.properties
quarkus.package.jar.aot.enabled=true
# This switches packaging from fast-jar to aot-jar automatically
# fast-jar uses a custom classloader incompatible with Leyden
# aot-jar uses standard classloaders that Leyden can cache
```

### Training workload

```bash
# @QuarkusIntegrationTest IS the training run — must not skip it
mvn verify -Dquarkus.package.jar.aot.enabled=true -DskipITs=false
```

### Runtime invocation

```bash
java -XX:AOTCache=app.aot -jar quarkus-run.jar
```

### Three-stage Dockerfile (required)

```dockerfile
# Stage 1: Compile with JDK 25
FROM docker.io/library/maven:3.9-eclipse-temurin-25 AS compiler
WORKDIR /build
COPY pom.xml .
COPY src ./src
RUN mvn package -Dmaven.test.skip=true --no-transfer-progress

# Stage 2: Training run — creates the AOT cache
# JVM fingerprint MUST match between trainer and runtime
FROM registry.access.redhat.com/ubi9/openjdk-25 AS trainer
WORKDIR /deployments
COPY --from=compiler /build/target/quarkus-app/ .
RUN java -XX:AOTMode=record -XX:AOTCache=app.aot -jar quarkus-run.jar \
    -Dquarkus.http.host=0.0.0.0 &                    \
    sleep 15 && curl http://localhost:8080/q/health && \
    pkill -f quarkus-run.jar || true

# Stage 3: Runtime
FROM registry.access.redhat.com/ubi9/openjdk-25-runtime
WORKDIR /deployments
COPY --from=compiler /deployments/ .
COPY --from=trainer  /deployments/app.aot .
USER 185
ENTRYPOINT ["java", "-XX:AOTCache=app.aot", "-jar", "quarkus-run.jar"]
```

---

## Observability — Metrics

### Dependencies

```xml
<dependency>
    <groupId>io.quarkus</groupId>
    <artifactId>quarkus-micrometer-registry-prometheus</artifactId>
</dependency>
```

### application.properties

```properties
# Enable Micrometer + Prometheus export
quarkus.micrometer.export.prometheus.enabled=true

# JVM metrics (heap, GC, threads, classloader)
quarkus.micrometer.binder.jvm=true

# HTTP server metrics (request count, duration)
quarkus.micrometer.binder.http-server.enabled=true

# Histogram for GC pause percentiles (p50, p95, p99)
quarkus.micrometer.distribution.percentiles-histogram.jvm.gc.pause=true
quarkus.micrometer.distribution.percentiles.jvm.gc.pause=0.5,0.95,0.99

# Histogram for HTTP request duration
quarkus.micrometer.distribution.percentiles-histogram.http.server.requests=true
quarkus.micrometer.distribution.percentiles.http.server.requests=0.5,0.95,0.99
```

> **⚠️ The histogram configuration is required for Grafana dashboard panels
> to display GC pause percentile data. Without it, the panels show no data.**

### Key Prometheus endpoints

```
GET /q/metrics          → Prometheus text format
GET /q/metrics/json     → JSON format
GET /q/health/live      → Liveness probe
GET /q/health/ready     → Readiness probe
```

### Key PromQL queries

```promql
# GC pause P99 per collector (ms)
histogram_quantile(0.99,
  rate(jvm_gc_pause_seconds_bucket[1m])
) * 1000

# GC pause rate of accumulation (ms/s) — shows spike pattern
rate(jvm_gc_pause_seconds_sum[1m]) * 1000

# Heap utilisation %
jvm_memory_used_bytes{area="heap"}
  / jvm_memory_max_bytes{area="heap"} * 100

# HTTP request p99 (ms)
histogram_quantile(0.99,
  rate(http_server_requests_seconds_bucket[1m])
) * 1000

# Thread count
jvm_threads_live_threads

# CPU waste (requested minus observed) — for right-sizing
kube_pod_container_resource_requests{resource="cpu"}
  - on(pod, namespace)
    avg_over_time(container_cpu_usage_seconds_total[14d])
```

---

## Observability — Tracing

### Dependencies

```xml
<dependency>
    <groupId>io.quarkus</groupId>
    <artifactId>quarkus-opentelemetry</artifactId>
</dependency>
```

### application.properties

```properties
# OTLP exporter (sends to otel-lgtm or any OpenTelemetry Collector)
quarkus.otel.exporter.otlp.traces.endpoint=http://grafana-lgtm:4317

# Service name appears in trace search
quarkus.otel.service.name=my-quarkus-service

# Sampling rate (1.0 = 100%, reduce in high-traffic production)
quarkus.otel.traces.sampler=parentbased_always_on
```

### Grafana LGTM (otel-lgtm) — docker-compose usage

```yaml
# Do NOT mount custom config into otel-lgtm
# It has an internal OTel Collector → Prometheus → Grafana pipeline
# Mounting prometheus.yml breaks that pipeline → blank dashboards
grafana-lgtm:
  image: docker.io/grafana/otel-lgtm:0.8.1
  ports:
    - "3000:3000"   # Grafana
    - "4317:4317"   # OTLP gRPC
    - "4318:4318"   # OTLP HTTP
  volumes:
    # ONLY mount additional datasource files — don't touch prometheus config
    - ./grafana/provisioning/datasources/external-prometheus.yml:/etc/grafana/provisioning/datasources/external-prometheus.yml:Z
```

---

## gRPC Configuration

### Dependencies

```xml
<dependency>
    <groupId>io.quarkus</groupId>
    <artifactId>quarkus-grpc</artifactId>
</dependency>
```

### Proto file location

```
src/main/proto/myservice.proto
```

Quarkus Maven plugin generates Java stubs automatically at compile time.

### Service implementation

```java
@GrpcService
public class MetricsServiceImpl
    extends MutinyMetricsServiceGrpc.MetricsServiceImplBase {

    // Unary — request/response
    @Override
    public Uni<MetricsResponse> getJvmMetrics(MetricsRequest request) {
        return Uni.createFrom().item(buildMetrics());
    }

    // Server streaming — push multiple responses on one connection
    // count=0: live mode (1/sec), count=N: benchmark mode (N messages fast)
    @Override
    public Multi<MetricsResponse> streamMetrics(MetricsRequest request) {
        int count = request.getCount();
        if (count > 0) {
            return Multi.createFrom().range(0, count)
                    .map(i -> buildMetrics());
        }
        return Multi.createFrom().ticks().every(Duration.ofSeconds(1))
                .map(tick -> buildMetrics());
    }
}
```

### application.properties

```properties
# gRPC server port (default 9000)
quarkus.grpc.server.port=9000

# Enable reflection service (required for grpcurl)
quarkus.grpc.server.enable-reflection-service=true
```

### Localhost benchmark reality

> **gRPC unary is slower than REST on localhost.** Network cost is zero —
> gRPC's advantages (HTTP/2, HPACK header compression, Protobuf encoding)
> only materialise with real pod-to-pod network latency.
>
> **gRPC wins even on localhost:** server streaming (1 connection vs N requests)
> and high concurrency (c=500+, HTTP/2 multiplexing vs TCP connection per worker).
>
> **In production (pod-to-pod):** gRPC wins ~3-4× on throughput and ~73% on p50 latency.

---

## Kubernetes Resource Configuration

### Guaranteed QoS (required for CPU Manager static allocation)

```yaml
# requests == limits → Guaranteed QoS class
# Required for -XX:ActiveProcessorCount to be accurate
resources:
  requests:
    cpu: "2"          # integer — static CPU allocation via CPU Manager
    memory: "2Gi"
  limits:
    cpu: "2"          # must equal request for Guaranteed QoS
    memory: "2Gi"

# Burstable QoS (requests != limits) — CPU Manager cannot pin
# GC spikes can steal CPU from adjacent pods
resources:
  requests:
    cpu: "500m"
  limits:
    cpu: "2000m"      # 4× the request — Burstable, not Guaranteed
```

### Health probes for Quarkus

```yaml
livenessProbe:
  httpGet:
    path: /q/health/live
    port: 8080
  initialDelaySeconds: 10
  periodSeconds: 10
  failureThreshold: 3

readinessProbe:
  httpGet:
    path: /q/health/ready
    port: 8080
  initialDelaySeconds: 5
  periodSeconds: 5

startupProbe:
  httpGet:
    path: /q/health/live
    port: 8080
  failureThreshold: 30     # allow up to 60s startup (30 × 2s period)
  periodSeconds: 2
```

### Huge pages (with kernel config)

```yaml
resources:
  requests:
    hugepages-2Mi: "4Gi"
    memory: "4Gi"          # must also specify memory equal to hugepage amount
  limits:
    hugepages-2Mi: "4Gi"
    memory: "4Gi"
```

Add to JVM flags: `-XX:+UseLargePages`

---

## HPA Configuration for JVM Workloads

### The problem with CPU-based HPA + JVM

G1GC stop-the-world pauses cause CPU spikes that look like traffic spikes to
CPU-based HPA → false scale-out → JIT warmup on new pod → false scale-in →
repeat. This is called HPA thrash.

### Stabilisation window (minimum fix)

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
spec:
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 120    # ignore spikes shorter than 2 min
      policies:
      - type: Pods
        value: 1
        periodSeconds: 60               # add at most 1 pod per minute
    scaleDown:
      stabilizationWindowSeconds: 300   # wait 5 min before scaling in
```

### Better: scale on RPS (not CPU)

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

### Best: KEDA with Prometheus

```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
spec:
  triggers:
  - type: prometheus
    metadata:
      serverAddress: http://prometheus:9090
      query: sum(rate(http_server_requests_seconds_count[2m]))
      threshold: "500"
```

---

## Panama FFM (JDK 22+)

Foreign Function & Memory API — call native C/C++ libraries from pure Java.
Finalized in JDK 22, stable in JDK 25 LTS. No `--enable-preview` required.

### Core pattern

```java
import java.lang.foreign.*;
import java.lang.invoke.MethodHandle;
import static java.lang.foreign.ValueLayout.*;

// Load native library
SymbolLookup lib = SymbolLookup.libraryLookup(
    System.mapLibraryName("mylib"),   // "libmylib.so" on Linux
    Arena.global()
);

// Create MethodHandle for: int my_function(double*, int32_t, double*)
MethodHandle myFunc = Linker.nativeLinker().downcallHandle(
    lib.find("my_function").orElseThrow(),
    FunctionDescriptor.of(JAVA_INT, ADDRESS, JAVA_INT, ADDRESS)
);

// Call with Arena for native memory management
try (Arena arena = Arena.ofConfined()) {
    // Allocate native double array — JDK 22+ API
    MemorySegment data  = arena.allocateFrom(JAVA_DOUBLE, myDoubleArray);
    MemorySegment outP99 = arena.allocate(JAVA_DOUBLE);

    int result = (int) myFunc.invoke(data, myDoubleArray.length, outP99);
    double p99 = outP99.get(JAVA_DOUBLE, 0);
} // all native memory freed here

// ⚠️ API note: allocateFrom() (JDK 22+ final) — NOT allocateArray() (removed preview API)
```

### Arena types

| Arena | Lifetime | Thread safety |
|-------|----------|---------------|
| `Arena.ofConfined()` | Explicit close (try-with-resources) | Single thread |
| `Arena.ofShared()` | Explicit close | Multi-thread safe |
| `Arena.ofAuto()` | GC-managed | Multi-thread safe |
| `Arena.global()` | Never freed | Multi-thread safe |

### Pom.xml — no special flags needed on JDK 25

```xml
<properties>
    <maven.compiler.release>25</maven.compiler.release>
</properties>
<!-- FFM is finalized — no --enable-preview required -->
```

---

## LangChain4j ONNX Embeddings

Run AI inference in-process via LangChain4j → ONNX Runtime → Panama FFM.
No Python sidecar. No gRPC. Same JVM.

### Dependencies

```xml
<!-- Bundles: all-MiniLM-L6-v2 model (~25MB) + ONNX Runtime + Panama bindings -->
<dependency>
    <groupId>dev.langchain4j</groupId>
    <artifactId>langchain4j-embeddings-all-minilm-l6-v2</artifactId>
    <version>0.36.2</version>
</dependency>
<dependency>
    <groupId>dev.langchain4j</groupId>
    <artifactId>langchain4j-core</artifactId>
    <version>0.36.2</version>
</dependency>
```

### CDI Producer

```java
@ApplicationScoped
public class EmbeddingModelProducer {
    @Produces
    @ApplicationScoped
    public EmbeddingModel embeddingModel() {
        return new AllMiniLmL6V2EmbeddingModel();  // loads model ~200ms
    }
}
```

### Usage

```java
@Inject EmbeddingModel model;

// Embed text → 384-dimension float vector
Embedding embedding = model.embed("OutOfMemoryError heap space").content();

// Cosine similarity between two sentences
double sim = CosineSimilarity.between(
    model.embed("JVM ran out of memory").content(),
    model.embed("database connection timeout").content()
);
// ~0.85 for related, ~0.15 for unrelated
```

### Memory allocation

The ONNX model (~25MB) + ONNX Runtime native library load into the JVM process.
Set container memory limit to at least 768MB (512MB heap + 256MB for ONNX Runtime overhead).

---

## Native Image

Builds to a native binary via Mandrel (Red Hat's GraalVM distribution for OpenShift).
Startup ~17ms, RSS ~60MB. No JIT at runtime — peak throughput lower than JVM mode.

### Build

```bash
# Requires Mandrel or GraalVM installed, or use container build
mvn package -Dnative

# Container build (no local GraalVM needed)
mvn package -Dnative -Dquarkus.native.container-build=true \
  -Dquarkus.native.builder-image=quay.io/quarkus/ubi-quarkus-mandrel-builder-image:jdk-21
```

### When to use native vs JVM

| Concern | JVM Mode | Native Mode |
|---------|----------|-------------|
| Startup time | 300–600ms | ~17ms |
| RSS at startup | ~200MB | ~60MB |
| Peak throughput | High (JIT optimises hot paths) | Lower (AOT compiled only) |
| Build time | Fast (~30s) | Slow (3–10 min) |
| Debuggability | Full (JFR, jcmd, jstack) | Limited |
| Leyden AOT | ✅ 75% improvement | N/A |
| JFR profiling | ✅ | Limited |

**Use native for:** Serverless, batch, CLI tools, anything with strict cold-start SLA.
**Use JVM for:** Long-running services, anything that benefits from JIT warmup.

---

## Development Mode

```bash
# Hot reload — changes applied without restart
mvn quarkus:dev

# With debug port open
mvn quarkus:dev -Dsuspend=false -Ddebug=5005

# Dev UI — browser-based development console
# http://localhost:8080/q/dev/
```

### Dev Services (automatic containers in dev mode)

Quarkus starts containers automatically for declared extensions:
- `quarkus-jdbc-postgresql` → starts PostgreSQL
- `quarkus-kafka` → starts Redpanda/Kafka
- `quarkus-redis` → starts Redis

```properties
# Disable if you want to manage your own containers
quarkus.devservices.enabled=false
```

---

## Common Pitfalls

### Unqualified image names in Podman

Podman on Fedora/RHEL has no default registry. Unqualified names trigger an
interactive registry selection prompt — which hangs in non-interactive builds.

```yaml
# ❌ Fails silently in CI / non-interactive
image: prom/prometheus:v3.2.1

# ✅ Always fully qualify
image: docker.io/prom/prometheus:v3.2.1
```

### SELinux bind mounts on Fedora/RHEL

Without `:Z`, SELinux silently blocks container read access to mounted files.
No error message appears in container or application logs.

```yaml
# ❌ Container cannot read the file
volumes:
  - ./prometheus.yml:/etc/prometheus/prometheus.yml:ro

# ✅ :Z relabels for the container's SELinux context
volumes:
  - ./prometheus.yml:/etc/prometheus/prometheus.yml:Z
```

### Named volume permissions in rootless Podman

Named volumes are created owned by root. Prometheus (uid 65534) and other
non-root processes cannot write to them.

```yaml
# ❌ Prometheus crashes silently — can't write to /prometheus
volumes:
  - prometheus_data:/prometheus

# ✅ Use tmpfs for demo workloads (no persistence needed)
prometheus:
  user: root
  tmpfs:
    - /prometheus
  command:
    - "--storage.tsdb.path=/prometheus"
```

### dependency:go-offline hangs in UBI containers

Maven's `dependency:go-offline` goal behaves incorrectly in UBI containers
and hangs indefinitely.

```dockerfile
# ❌ Hangs
RUN mvn dependency:go-offline && mvn package

# ✅ Go straight to package
RUN mvn package -Dmaven.test.skip=true --no-transfer-progress
```

### Mounting config into otel-lgtm

`grafana/otel-lgtm` bundles its own internal Prometheus for OTLP metrics.
Mounting a custom `prometheus.yml` into it replaces the internal config and
breaks the OTel Collector → Prometheus → Grafana pipeline → blank dashboards.

```yaml
# ❌ Breaks internal pipeline → blank Grafana dashboards
grafana-lgtm:
  volumes:
    - ./prometheus.yml:/etc/prometheus/prometheus.yml:Z

# ✅ Mount only additional Grafana datasource files
grafana-lgtm:
  volumes:
    - ./grafana/provisioning/datasources/external-prometheus.yml:/etc/grafana/provisioning/datasources/external-prometheus.yml:Z

# ✅ Standalone prom/prometheus handles /q/metrics scraping
prometheus:
  image: docker.io/prom/prometheus:v3.2.1
```

### AppCDS / AOT cache JVM fingerprint mismatch

The JVM that creates the cache must be identical to the one that reads it.
Different vendors (Temurin vs UBI), different patch versions, or different
build flags all invalidate the cache silently — no error, just no improvement.

```dockerfile
# ✅ All stages must use the same JVM vendor and version
FROM docker.io/library/maven:3.9-eclipse-temurin-25 AS compiler
FROM registry.access.redhat.com/ubi9/openjdk-25 AS trainer      # same vendor
FROM registry.access.redhat.com/ubi9/openjdk-25-runtime          # same vendor
```

### fast-jar vs aot-jar for Leyden

Project Leyden only caches classes loaded by standard JDK classloaders.
Quarkus's `fast-jar` uses a custom classloader that Leyden cannot cache.

```properties
# ❌ Leyden sees no improvement — fast-jar uses custom classloader
quarkus.package.jar.type=fast-jar

# ✅ aot-jar uses standard classloaders — set automatically when AOT is enabled
quarkus.package.jar.aot.enabled=true   # switches to aot-jar automatically
```

### Arena.allocateArray() removed in final FFM API

`allocateArray()` was the preview API name. The final JDK 22 API uses `allocateFrom()`.

```java
// ❌ Compilation error on JDK 22+ final API
MemorySegment seg = arena.allocateArray(JAVA_DOUBLE, myArray);

// ✅ Final API (JDK 22+)
MemorySegment seg = arena.allocateFrom(JAVA_DOUBLE, myArray);
```

### JAX-RS annotations on record declarations

JAX-RS annotations (`@GET`, `@POST`, `@Path`, `@Consumes`) can only be applied
to methods and classes — not to record type declarations.

```java
// ❌ Compilation error: annotation interface not applicable to this kind of declaration
@POST @Path("/rank")
public record RankRequest(String reference, List<String> candidates) {}

// ✅ Record is just a data class — annotations go on the method
record RankRequest(String reference, List<String> candidates) {}

@POST
@Path("/rank")
@Consumes(MediaType.APPLICATION_JSON)
public List<Result> rank(RankRequest req) { ... }
```
