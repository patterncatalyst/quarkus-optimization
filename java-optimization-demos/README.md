# Taming the JVM: Optimizing Java Workloads on OpenShift & Kubernetes
## Conference Demo Repository

Companion demos for the 60-minute talk based on:
- 📗 *Optimizing Cloud Native Java* (O'Reilly)
- 📗 *SRE with Java Microservices* (O'Reilly — Jonathan Schneider)

All demos use **Podman** and **UBI (Universal Base Image)** runtime containers —
the same toolchain and base images used in production OpenShift environments.

---

## Repository Structure

```
.
├── README.md                          ← You are here
│
├── demo-01-heap-sizing/               ← Demo 01: Container-aware JVM heap (plain Java)
│   ├── demo.sh
│   └── src/HeapInfo.java
│
├── quarkus-demo-02-gc-monitoring/     ← Demo 02: GC metrics (Quarkus)
│   ├── demo.sh
│   ├── docker-compose.yml             ← Quarkus app + Prometheus + Grafana + Jaeger
│   ├── app/                           ← Quarkus 3.33.1 LTS / Java 21
│   ├── prometheus/
│   └── grafana/
│
├── quarkus-demo-03-appcds/            ← Demo 03: AppCDS startup acceleration (Quarkus)
│   ├── demo.sh
│   └── app/
│       ├── Dockerfile.baseline        ← fast-jar, no AppCDS
│       └── Dockerfile.appcds          ← AppCDS archive baked in at build time
│
├── quarkus-demo-04-leyden/            ← Demo 04: Project Leyden AOT cache (JDK 25 LTS)
│   ├── demo.sh
│   └── app/
│       ├── Dockerfile.baseline        ← fast-jar baseline (JDK 25)
│       └── Dockerfile.leyden          ← 3-stage: compile → train (UBI JDK 25) → runtime
│
├── quarkus-demo-05-grpc/              ← Demo 05: REST vs gRPC (Quarkus)
│   ├── demo.sh
│   └── app/
│
└── quarkus-demo-06-latency/           ← Demo 06: Low-Latency JVM — G1GC vs ZGC
    ├── demo.sh
    └── app/

└── quarkus-demo-07-rightsizing/       ← Demo 07: Right-Sizing & Cost Impact Analysis
    ├── demo.sh
    ├── analyze.py
    └── sample-data/
│       ├── src/main/proto/metrics.proto   ← service contract, stubs generated at build
│       ├── MetricsServiceImpl.java        ← @GrpcService, unary + streaming
│       └── Dockerfile                     ← exposes :8080 (REST) and :9000 (gRPC)
│
├── demo-02-gc-monitoring/             ← Demo 02: GC metrics (Spring Boot comparison)
└── demo-03-appcds/                    ← Demo 03: AppCDS (Spring Boot comparison)
```

---

## Prerequisites

| Tool | Version | Notes |
|------|---------|-------|
| **Podman** | 4.x+ | `brew install podman` / `dnf install podman` / `apt install podman` |
| **podman-compose** | 1.x+ | `pip install podman-compose` — required for Demo 02 only |
| **hey** | latest | `brew install hey` — REST load tester, Demo 05 only |
| **ghz** | latest | `brew install ghz` — gRPC load tester, Demo 05 only |
| **grpcurl** | latest | `brew install grpcurl` — gRPC CLI, Demo 05 only |
| Java / Maven | — | **Not required** — all builds run inside containers |

> **No local Java or Maven installation needed.**
> Every build runs inside the container. UBI runtime images
> (`registry.access.redhat.com/ubi9/openjdk-21-runtime` and `openjdk-25`)
> are pulled automatically on first run.

---

## Quick Start

```bash
# Demo 01 — Container-aware heap sizing (~5 min, plain Java)
cd demo-01-heap-sizing && chmod +x demo.sh && ./demo.sh

# Demo 02 — GC monitoring with Prometheus + Grafana (~10 min)
cd quarkus-demo-02-gc-monitoring && chmod +x demo.sh && ./demo.sh

# Demo 03 — AppCDS startup acceleration, Quarkus (~8 min)
cd quarkus-demo-03-appcds && chmod +x demo.sh && ./demo.sh

# Demo 03 — AppCDS startup acceleration, Spring Boot comparison (~8 min)
cd demo-03-appcds && chmod +x demo.sh && ./demo.sh

# Demo 04 — Project Leyden AOT cache, JDK 25 LTS (~12 min)
cd quarkus-demo-04-leyden && chmod +x demo.sh && ./demo.sh

# Demo 05 — REST vs gRPC, same Quarkus service two protocols (~10 min)
cd quarkus-demo-05-grpc && chmod +x demo.sh && ./demo.sh

# Demo 06 — Low-latency JVM: G1GC vs ZGC pause delta (~10 min)
cd quarkus-demo-06-latency && chmod +x demo.sh && ./demo.sh

# Demo 07 — Right-sizing & cost impact analysis (~8 min, no cluster needed)
cd quarkus-demo-07-rightsizing && chmod +x demo.sh && ./demo.sh
```

> **Demo 04 first run:** `mvn verify` runs inside the container and downloads
> ~500 MB of Quarkus 3.33.1 dependencies. Subsequent runs use Podman's layer
> cache and are significantly faster.

> **Demo 05 load testing** requires `hey`, `ghz`, and `grpcurl`. If not installed,
> the demo runs in observe mode — both protocols still respond and the streaming
> demo still works, just without the throughput comparison table.

> **Demo 06 ZGC throughput:** ZGC will likely show lower throughput and higher
> average latency than G1GC in the `hey` load test. This is **expected and
> correct** — ZGC pays a small constant cost (load barriers) on every object
> read. The meaningful comparison is the **GC pause delta** shown in Steps 4
> and 5: how much time application threads were completely frozen. G1GC
> accumulates 50–300ms of pause time per run; ZGC accumulates near-zero.
> See the demo README for the full on-stage framing.

---

## What Each Demo Teaches

### Demo 01 — Container-Aware Heap Sizing

**Problem:** Default JVM reads host RAM, not your container memory limit.
A pod with a 512 MB limit can end up with a 4 GB heap → OOMKill on first GC.

**Fix:**
```bash
-XX:+UseContainerSupport        # reads cgroup limits (v1 and v2)
-XX:MaxRAMPercentage=75.0       # 75% of container memory → heap
-XX:InitialRAMPercentage=50.0   # avoid startup GC pressure
```

**You'll see:** Live `jcmd` output comparing heap sizes in a misconfigured vs
correctly configured container.

---

### Demo 02 — GC Monitoring with Prometheus + Grafana

**Problem:** GC pauses spike CPU, triggering false HPA scale-out.
Without JVM metrics in Prometheus, you're guessing at the cause.

**Stack:** Quarkus app → `/q/metrics` → Prometheus → Grafana dashboard + Jaeger traces

**You'll see:**
- `jvm_gc_pause_seconds` histograms in a pre-built Grafana dashboard
- G1GC vs ZGC pause comparison under synthetic load
- PrometheusRule alerts firing at P99 > 500 ms
- OpenTelemetry traces correlated with GC events

**Quarkus differences from Spring Boot:**

| | Quarkus | Spring Boot |
|---|---|---|
| Metrics endpoint | `/q/metrics` | `/actuator/prometheus` |
| Health endpoint | `/q/health/live` | `/actuator/health` |
| OTel extension | `quarkus-opentelemetry` | `spring-boot-starter-actuator` |

---

### Demo 03 — AppCDS Startup Acceleration

**Problem:** Cold JVM startup takes seconds → pods are slow to become ready,
HPA scale-out leaves a window where traffic is dropped.

**Quarkus** — one property, fully automatic:
```properties
quarkus.package.jar.appcds.enabled=true
```
The Quarkus Maven plugin runs a training pass and bakes the CDS archive
into the image. No manual steps.

**Spring Boot** — three manual steps (shown for comparison):
```dockerfile
RUN java -Djarmode=tools -jar app.jar extract --destination extracted  # 1. unpack
RUN java -XX:ArchiveClassesAtExit=app.jsa -jar app/app.jar             # 2. train
ENTRYPOINT ["java", "-XX:SharedArchiveFile=app.jsa", "-jar", "app.jar"] # 3. use
```

**Verified results (UBI images, Podman):**

| | Quarkus baseline | Quarkus + AppCDS | Spring Boot baseline | Spring Boot + AppCDS |
|---|---|---|---|---|
| Avg startup | ~480 ms | ~465 ms | ~2700 ms | ~1600 ms |
| Improvement | — | ~5% | — | ~40% |

> The Quarkus result tells the real story: AppCDS barely moves the needle because
> Quarkus already eliminated most class-loading work at *build time* with its
> annotation processor and metadata pre-computation. Build-time optimisation
> beats runtime optimisation.

---

### Demo 04 — Project Leyden AOT Cache (JDK 25 LTS)

**The complete JVM startup story.** Where AppCDS caches parsed bytecode, Project
Leyden (JEP 483 + 514 + 515, JDK 25) caches loaded, linked, and JIT-profiled
classes — cutting warmup time too.

**One property:**
```properties
quarkus.package.jar.aot.enabled=true
```

**Training workload = your existing `@QuarkusIntegrationTest` suite:**
```bash
./mvnw verify -Dquarkus.package.jar.aot.enabled=true -DskipITs=false
```

**Verified results (UBI images, Podman, Red Hat OpenJDK 25):**

| Run | Baseline (fast-jar) | Leyden AOT (aot-jar) |
|-----|--------------------|--------------------|
| 1   | 606 ms             | 150 ms             |
| 2   | 593 ms             | 156 ms             |
| 3   | 601 ms             | 137 ms             |
| 4   | 621 ms             | 146 ms             |
| 5   | 624 ms             | 149 ms             |
| **Avg** | **609 ms** | **148 ms (-75%)** |

**The full startup ladder (JVM-only, no native):**
```
Spring Boot 4.0.5 baseline                 ~2700 ms
Quarkus 3.33.1 JVM baseline (fast-jar)      ~609 ms   (4.4× faster)
Quarkus 3.33.1 + Leyden AOT (aot-jar)       ~148 ms   (18× faster than Spring Boot)
Quarkus native (Mandrel)                     ~17 ms
```

**Critical implementation detail — JVM fingerprint matching:**

The AOT cache is cryptographically bound to the JVM build that created it.
This demo uses a **3-stage Dockerfile** to ensure the training JVM exactly matches
the runtime JVM:

```
Stage 1 (compiler)  docker.io/library/maven:3.9-eclipse-temurin-25
                    └─ compiles source, downloads dependencies

Stage 2 (trainer)   registry.access.redhat.com/ubi9/openjdk-25
                    └─ runs mvn verify → @QuarkusIntegrationTest → writes app.aot
                    └─ uses Red Hat OpenJDK 25 ← same vendor as runtime

Stage 3 (runtime)   registry.access.redhat.com/ubi9/openjdk-25  ← same JVM ✅
                    └─ app.aot fingerprint matches → 75% faster startup
```

If training JVM ≠ runtime JVM — even same version, different vendor — the cache
is **silently rejected** with no error message, and you get identical timings.
This is the kind of subtle production bug that kills a Kubernetes rolling deployment.

**AOT cache progression across JDK versions:**

| JDK | JEPs | Cache contains |
|-----|------|----------------|
| JDK 21 LTS | AppCDS | Parsed bytecode |
| JDK 24 | JEP 483 | + Loaded & linked classes |
| **JDK 25 LTS** | **JEP 514 + 515** | **+ JIT method profiles** |
| JDK 26 | JEP 516 | + ZGC support |

Same `quarkus.package.jar.aot.enabled=true` throughout. Better JDK = richer cache.
Zero code changes.

---

### Demo 05 — REST vs gRPC: Same Service, Two Protocols

**The internal communication question.** REST works everywhere but carries overhead
that adds up at scale. gRPC uses HTTP/2 and binary Protobuf — the same data, the
same JVM, a very different wire format.

**One Quarkus app, both protocols simultaneously:**
```
REST  → http://localhost:8080/metrics   (JSON / HTTP 1.1)
gRPC  → localhost:9000                  (Protobuf / HTTP 2)
```

> **⚠️ Localhost benchmark caveat:** gRPC unary will likely be *slower* than REST
> when both run on `localhost`. This is expected — gRPC's advantages (persistent
> HTTP/2 connections, no per-request TCP handshake, header compression) only
> materialise when there is real network latency between caller and callee.
> On loopback, network cost is zero and REST's simpler framing wins.
>
> **What the demo shows clearly even on localhost:**
> - **Streaming** — 1,000 gRPC messages over 1 connection vs 1,000 REST requests
> - **High concurrency (c=500)** — HTTP/2 multiplexing vs 500 TCP connections
>
> **In production (pod-to-pod, real Kubernetes network):** gRPC wins ~3-4× on
> throughput and ~73% on p50 latency. The demo is designed to show the honest
> result and explain why, not hide it.

**One dependency:**
```xml
<dependency>
    <groupId>io.quarkus</groupId>
    <artifactId>quarkus-grpc</artifactId>
</dependency>
```

Drop a `.proto` file in `src/main/proto/` and `mvn compile` generates all Java stubs.
Implement with `@GrpcService`. That's it.

**Server streaming — no REST equivalent without SSE/WebSocket boilerplate:**
```java
@GrpcService
public class MetricsServiceImpl extends MutinyMetricsServiceGrpc.MetricsServiceImplBase {
    public Multi<MetricsResponse> streamMetrics(MetricsRequest req) {
        return Multi.createFrom().ticks().every(Duration.ofSeconds(1))
                .map(t -> buildMetrics());
    }
}
```

**Benchmark results (same Quarkus JVM, `hey` vs `ghz`, 10,000 requests, 50 concurrent):**

| Metric | REST (JSON) | gRPC (Protobuf) | Delta |
|--------|-------------|-----------------|-------|
| Throughput | ~2,200 rps | ~8,500 rps | +3.9× |
| p50 latency | ~45 ms | ~12 ms | −73% |
| p99 latency | ~120 ms | ~25 ms | −79% |
| CPU usage | ~65% | ~40% | −38% |
| Wire payload | ~220 bytes | ~40 bytes | −82% |

**Test it yourself:**
```bash
# gRPC unary
grpcurl -plaintext -d '{"host":"localhost"}' localhost:9000 MetricsService/GetJvmMetrics

# gRPC streaming — streams live JVM metrics every second until Ctrl+C
grpcurl -plaintext -d '{"host":"localhost"}' localhost:9000 MetricsService/StreamMetrics

# Load test comparison
ghz --insecure --proto app/src/main/proto/metrics.proto \
    --call MetricsService/GetJvmMetrics -n 10000 -c 50 localhost:9000
hey -n 10000 -c 50 http://localhost:8080/metrics
```

**When to choose each:**

| Situation | Choose |
|-----------|--------|
| Public API / browser clients | REST |
| Internal pod-to-pod calls | gRPC |
| Debugging with curl | REST |
| High frequency (>100 calls/sec) | gRPC |
| Streaming data continuously | gRPC |
| External partners / integrations | REST |

---

## Container Images Used

| Stage | Image | Used in |
|-------|-------|---------|
| Build | `docker.io/library/maven:3.9-eclipse-temurin-21` | Demos 02, 03, 05 |
| Build | `docker.io/library/maven:3.9-eclipse-temurin-25` | Demo 04 |
| Runtime | `registry.access.redhat.com/ubi9/openjdk-21-runtime` | Demos 02, 03, 05 |
| Training + Runtime | `registry.access.redhat.com/ubi9/openjdk-25` | Demo 04 |

UBI images are freely redistributable, Red Hat-certified, and run as non-root
user `185` by default — the expected security posture for OpenShift workloads.

---

## Mapping to Presentation Slides

| Slide(s) | Demo | Key Concept |
|----------|------|-------------|
| 4–7      | 01   | `UseContainerSupport`, cgroup v1/v2, heap sizing |
| 8–12     | 02   | G1GC vs ZGC, GC pause metrics, Prometheus alerting |
| 13–17    | 02   | OpenTelemetry, Grafana dashboards, HPA correlation |
| 18–22    | 03   | AppCDS, build-time vs runtime optimisation |
| 23–26    | 03   | Quarkus build-time model, startup ladder |
| 27–28    | 04   | Project Leyden, JEP 483/514/515, AOT progression |
| 29–30    | —    | JVM anti-patterns + remediation (bonus slides) |
| 31–33    | 05   | REST vs gRPC, benchmarks, `@GrpcService` setup |

---

## Troubleshooting

**`podman-compose: command not found`**
```bash
pip install podman-compose        # or: pipx install podman-compose
```

**First Demo 04 build is slow (10+ minutes)**
Normal — downloading ~500 MB of Quarkus 3.33.1 + JDK 25 dependencies on first run.
Podman layer-caches the result; subsequent builds skip the download entirely.

**Demo 04 shows no improvement (identical baseline and Leyden timings)**
The AOT cache was silently rejected — most likely a JVM vendor mismatch between
the image that trained the cache and the image running it. Rebuild with:
```bash
podman build --no-cache -f app/Dockerfile.leyden -t quarkus-leyden:leyden ./app
```

**Port conflicts (Demo 02)**
Demo 02 uses ports `3000` (Grafana), `4317` (OTLP), `8080` (app), `9090` (Prometheus).
```bash
cd quarkus-demo-02-gc-monitoring && podman-compose down
```

**`Unable to create directory /app/extracted/lib` (Spring Boot Demo 03)**
UBI runs as non-root user 185. The Dockerfile includes `USER root` before the
extract step — ensure you're using the latest version and rebuild with `--no-cache`.

**Unqualified image name prompts for registry (Podman on RHEL/Fedora)**
All `FROM` lines in the Dockerfiles are fully qualified
(`docker.io/library/...` or `registry.access.redhat.com/...`).
If you add custom Dockerfiles, always prefix with the registry.

**Demo 05 — `grpcurl: command not found`**
```bash
brew install grpcurl          # macOS
# Linux: download from github.com/fullstorydev/grpcurl/releases
```

**Demo 05 — gRPC connection refused on port 9000**
The container exposes both `8080` and `9000`. If only 8080 responds, check the
`podman run` command in `demo.sh` includes `-p 9000:9000`. Also verify gRPC server
started: `podman logs grpc-demo | grep "gRPC server"`.

**Demo 05 — `ghz` proto import error**
`ghz` needs the proto file path relative to where you run the command.
The `demo.sh` passes `--proto app/src/main/proto/metrics.proto` — run from
the `quarkus-demo-05-grpc/` directory, not from inside `app/`.

---

---

### Demo 06 — Low-Latency JVM: G1GC vs ZGC

**The GC algorithm choice question.** G1GC is the right default for most
workloads. But if your service has a p99 SLA tighter than your GC pause
time, G1GC will breach it on schedule. ZGC eliminates GC as a cause of
latency breaches.

**Two apps, one Quarkus codebase, one flag difference:**
```
G1GC  → http://localhost:8080  (-XX:+UseG1GC)
ZGC   → http://localhost:8081  (-XX:+UseZGC -XX:+ZGenerational)
```

> **⚠️ ZGC will show lower throughput in load tests — this is expected.**
> ZGC inserts load barriers at every object reference read, enabling
> concurrent object relocation. This costs ~5-15% throughput. In a
> micro-benchmark that hammers allocation, the cost is maximally visible.
>
> **The number that matters is the GC pause delta** (Steps 4 and 5): how
> much cumulative time application threads were completely frozen. G1GC
> accumulates 50–300ms per run. ZGC accumulates near-zero. That delta is
> the ms your service served zero requests — and the ms that breaches SLAs.
>
> **On-stage framing:** "ZGC is slower in throughput here — that's the load
> barrier cost, and it's real. But G1GC froze the app for [N]ms. ZGC froze
> it for less than 1ms. If your p99 SLA is 50ms and G1GC pauses for 150ms,
> you breach it on schedule. Choose based on your SLA, not this benchmark."

**The HPA connection:** G1GC's CPU bursts during stop-the-world pauses look
like traffic spikes to CPU-based HPA → false scale-out → JIT warmup on new
pod → false scale-in → repeat. ZGC's smooth CPU profile eliminates this.

**What you cannot demo locally** (shown via slides and config examples):
huge pages, CPU Manager static policy, Topology Manager single-numa-node,
`isolcpus`/`nohz_full` kernel isolation, OpenShift PerformanceProfile.

---

### Demo 07 — Right-Sizing & Cost Impact Analysis

**The infrastructure waste question.** Most Java teams set resource requests
once at deployment and never revisit them. After 6-12 months, 40-60% of
requested memory is unused and CPU requests are 3-5× actual steady-state
load (set to GC spike peaks that last milliseconds).

**No cluster needed — runs on sample data:**
```bash
python3 analyze.py                               # bundled 7-workload dataset
python3 analyze.py --data my-cluster.json        # your own Prometheus export
python3 analyze.py --cost-per-node-hour 0.768    # override node cost
./demo.sh --live                                 # try kubectl, fall back to sample
```

**What the analysis produces:**
- Right-sizing recommendations per workload: `p99 observed × 1.30` for CPU,
  `p99 × 1.25` for memory — evidenced headroom, not guesswork
- **GC spike detection:** if CPU p99/p50 ratio > 3× and GC pause p99 > 100ms,
  the tool uses p95 as the CPU basis to avoid provisioning for millisecond events
- QoS improvement flags: workloads where `requests != limits` are Burstable —
  setting them equal gives Guaranteed QoS and enables static CPU allocation
- Bin-packing: pods per node before/after, nodes required before/after
- Cost calculation: monthly and annual saving with ROI business case
- GC algorithm recommendations: which workloads need ZGC based on pause p99
- Machine-readable JSON report for CI/CD integration

**Typical results (7-workload sample cluster):**
- CPU requests cut by 50-75% across most services
- Memory requests cut by 40-56%
- 4 nodes → 2 nodes (+67% pod density)
- $6,720/month saving for ~4 hours of engineering work (17× ROI)

**OpenShift Cost Management** provides this analysis automatically at cluster
scale via Console → Cost Management → **Optimizations tab**, with cloud
billing integration and per-namespace chargeback.

## Reference Links

| Resource | URL |
|----------|-----|
| Quarkus AppCDS guide | https://quarkus.io/guides/appcds |
| Quarkus + Project Leyden | https://quarkus.io/blog/leyden-2/ |
| Project Leyden (OpenJDK) | https://openjdk.org/projects/leyden/ |
| JEP 483 — AOT Class Loading & Linking | https://openjdk.org/jeps/483 |
| JEP 514 — AOT Command-Line Ergonomics | https://openjdk.org/jeps/514 |
| JEP 515 — AOT Method Profiling | https://openjdk.org/jeps/515 |
| Red Hat AppCDS article | https://developers.redhat.com/articles/2024/01/23/speed-java-application-startup-time-appcds |
| UBI OpenJDK 21 runtime image | https://catalog.redhat.com/software/containers/ubi9/openjdk-21-runtime |
| UBI OpenJDK 25 image | https://catalog.redhat.com/software/containers/ubi9/openjdk-25 |
| Micrometer JVM metrics | https://micrometer.io/docs/ref/jvm |
| KEDA (event-driven autoscaling) | https://keda.sh |
| Quarkus gRPC guide | https://quarkus.io/guides/grpc-getting-started |
| Protocol Buffers | https://protobuf.dev |
| `ghz` gRPC load tester | https://ghz.sh |
| `grpcurl` CLI | https://github.com/fullstorydev/grpcurl |
| ZGC overview | https://wiki.openjdk.org/display/zgc |
| Generational ZGC (JEP 439) | https://openjdk.org/jeps/439 |
| OpenShift low-latency tuning | https://docs.openshift.com/container-platform/latest/scalability_and_performance/cnf-low-latency-tuning.html |
| Kubernetes CPU Manager | https://kubernetes.io/docs/tasks/administer-cluster/cpu-management-policies/ |
| VPA (Vertical Pod Autoscaler) | https://github.com/kubernetes/autoscaler/tree/master/vertical-pod-autoscaler |
| OpenShift Cost Management | https://docs.redhat.com/en/documentation/cost_management_service |
| Kubernetes resource management | https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/ |
| Koku (Cost Management backend) | https://github.com/project-koku/koku |
