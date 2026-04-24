# Taming the JVM: Optimizing Java Workloads on OpenShift & Kubernetes

## Conference Demo Repository

Companion demos for the talk **"Taming the JVM: Optimizing Java Workloads on OpenShift & Kubernetes"**.

Based on:
- 📗 *Optimizing Cloud Native Java* (O'Reilly)
- 📗 *SRE with Java Microservices* (O'Reilly — Jonathan Schneider)

All demos use **Podman** and **UBI (Universal Base Image)** runtime containers — the same toolchain and base images used in production OpenShift environments.

> **Note on GC defaults:** The UBI9 OpenJDK 21 runtime image ships **Shenandoah** as the default GC — Red Hat's concurrent low-latency collector, supported since JDK 8. This is different from Eclipse Temurin, Amazon Corretto, and Microsoft OpenJDK which all default to G1GC. Demos that compare GC algorithms explicitly override the default with `-XX:+UseG1GC` or `-XX:+UseZGC` to ensure a clean comparison.

---

## Repository Structure

```
java-optimization-demos/
│
├── README.md                           ← You are here
│
├── demo-01-heap-sizing/                ← Demo 01: Container-aware JVM heap (plain Java)
│   └── demo.sh
│
├── quarkus-demo-02-gc-monitoring/      ← Demo 02: GC monitoring with Prometheus + Grafana LGTM
│   ├── demo.sh
│   ├── app/                            Quarkus 3.33.1 — G1GC and ZGC variants
│   ├── prometheus/
│   └── grafana/
│
├── quarkus-demo-03-appcds/             ← Demo 03: AppCDS startup acceleration (Quarkus)
│   ├── demo.sh
│   └── app/
│
├── demo-03-appcds/                     ← Demo 03: AppCDS startup acceleration (Spring Boot comparison)
│   ├── demo.sh
│   └── app/
│
├── quarkus-demo-04-leyden/             ← Demo 04: Project Leyden AOT cache (JDK 25 LTS)
│   ├── demo.sh
│   └── app/
│
├── quarkus-demo-05-grpc/               ← Demo 05: REST vs gRPC — same service, two protocols
│   ├── demo.sh
│   └── app/
│
├── quarkus-demo-06-latency/            ← Demo 06: Low-latency JVM — G1GC vs ZGC pause delta
│   ├── demo.sh
│   └── app/
│
├── quarkus-demo-07-rightsizing/        ← Demo 07: Right-sizing & cost impact analysis
│   ├── demo.sh
│   ├── analyze.py
│   └── sample-data/
│
├── quarkus-demo-08-panama/             ← Demo 08: Project Panama — C++20 → Quarkus via FFM
│   ├── demo.sh
│   ├── native/                         C++20 shared library (jvmstats)
│   └── app/
│
└── quarkus-demo-09-onnx/               ← Demo 09: AI inference — LangChain4j + ONNX + Panama
    ├── demo.sh
    └── app/
```

---

## Prerequisites

| Tool | Version | Notes |
|------|---------|-------|
| **podman** | 4.x+ | `dnf install podman` / `brew install podman` |
| **podman-compose** | 1.x+ | `pip install podman-compose` — required for Demo 02 only |
| **JDK 21** | Eclipse Temurin 21 | For local dev; containers bring their own JDK |
| **JDK 25** | Eclipse Temurin 25 | Demo 04 + Demo 08 + Demo 09 only |
| **Python 3** | stdlib only | Demo 07 analysis engine — no pip installs |
| **g++ / cmake** | g++ 10+, cmake 3.20+ | Demo 08 native library compilation (inside container) |
| **hey** | latest | `brew install hey` — REST load tester, Demos 05/06 |
| **ghz** | latest | `brew install ghz` — gRPC load tester, Demo 05 |
| **grpcurl** | latest | `brew install grpcurl` — gRPC CLI, Demo 05 |

> **SDKMAN users:** A `.sdkmanrc` file at the repo root pins Java 21.0.10-tem. Run `sdk env` from the repo root to activate it.

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

# Demo 07 — Right-sizing & cost impact analysis (~3 min, no cluster needed)
cd quarkus-demo-07-rightsizing && chmod +x demo.sh && ./demo.sh

# Demo 08 — Project Panama: C++20 → Quarkus via FFM (~8 min)
cd quarkus-demo-08-panama && chmod +x demo.sh && ./demo.sh

# Demo 09 — AI inference: LangChain4j + ONNX + Panama (~10 min)
cd quarkus-demo-09-onnx && chmod +x demo.sh && ./demo.sh
```

> **Demo 04 first run:** `mvn verify` runs inside the container and downloads ~500MB of Quarkus 3.33.1 + JDK 25 dependencies. Subsequent runs use Podman's layer cache.

> **Demo 05 load testing** requires `hey`, `ghz`, and `grpcurl`. Without them the demo runs in observe mode — streaming still works, just without the throughput table.

> **Demo 06 ZGC throughput:** ZGC will show lower throughput than G1GC in the `hey` load test. This is expected — ZGC pays a small constant load barrier cost on every object read. The meaningful comparison is the **GC pause delta** in Steps 4 and 5, not the `hey` p99.

> **Demo 07** requires only `python3` (stdlib). No containers, no network access, no cluster needed.

> **Demo 09 first run** downloads ~300MB of Maven dependencies (ONNX Runtime + MiniLM model). Subsequent builds use the Podman layer cache.

---

## What Each Demo Teaches

### Demo 01 — Container-Aware Heap Sizing

**Problem:** Default JVM reads host RAM, not your container memory limit. A pod with a 512MB limit can end up with a 4GB heap → OOMKill on first GC.

**Fix:**
```bash
-XX:+UseContainerSupport        # reads cgroup limits (v1 and v2) — default since JDK 10
-XX:MaxRAMPercentage=75.0       # 75% of container memory → heap
-XX:InitialRAMPercentage=50.0   # avoid startup GC pressure
```

**You'll see:** Live `jcmd` output comparing heap sizes in a misconfigured vs correctly configured container.

---

### Demo 02 — GC Monitoring with Prometheus + Grafana

**Stack:** Two Quarkus apps (G1GC on `:8080`, ZGC on `:8081`) + Grafana LGTM (`otel-lgtm`) + standalone Prometheus scraping `/q/metrics`.

**Architecture note:** `otel-lgtm` bundles its own internal Prometheus for OTLP metrics. The standalone `prom/prometheus` container scrapes `/q/metrics` separately and provides the "JVM Metrics" Grafana datasource. Do not mount custom config into `otel-lgtm` — it breaks the internal OTel→Prometheus→Grafana pipeline.

**Fedora/RHEL SELinux note:** All bind mounts use `:Z` label. Prometheus uses `tmpfs` storage (`user: root`) to avoid named volume permission issues with rootless Podman.

**Key metrics to show:**
```promql
# GC pause p99 — compare G1GC vs ZGC
histogram_quantile(0.99, rate(jvm_gc_pause_seconds_bucket[1m])) * 1000

# Heap utilisation
jvm_memory_used_bytes{area="heap"} / jvm_memory_max_bytes{area="heap"}
```

---

### Demo 03 — AppCDS Startup Acceleration

**The honest result:** AppCDS gives ~5% startup improvement on Quarkus (which already pre-processes at build time) but ~40% on Spring Boot (which does it at runtime).

**Quarkus:**
```properties
quarkus.package.jar.appcds.enabled=true
```

**Spring Boot:**
```bash
java -Djarmode=tools -jar app.jar extract
java -XX:ArchiveClassesAtExit=app.jsa -jar app/app.jar
java -XX:SharedArchiveFile=app.jsa -jar app/app.jar
```

**Story:** The small Quarkus improvement *proves the point* — Quarkus moved class-loading work to build time. CDS has less to cache because there's less to do at runtime.

---

### Demo 04 — Project Leyden AOT Cache (JDK 25)

**Verified result:** 609ms → 148ms startup (**−75%**) on JDK 25 LTS.

**How it works:** Unlike AppCDS which caches parsed bytecode, Leyden caches parsed + linked classes AND JIT method profiles from the training run. First requests after startup get near-peak JIT performance instead of interpreted performance.

```properties
quarkus.package.jar.aot.enabled=true   # switches to aot-jar, not fast-jar
```

Training workload is `@QuarkusIntegrationTest`:
```bash
mvn verify -DskipITs=false
```

**Three-stage Dockerfile:** `temurin-25` compiler → `ubi9/openjdk-25` trainer → `ubi9/openjdk-25` runtime. JVM fingerprint must match between trainer and runtime — same reason.

---

### Demo 05 — REST vs gRPC: Same Service, Two Protocols

> **⚠️ Localhost benchmark caveat:** gRPC unary will be *slower* than REST on `localhost`. Network cost is zero — gRPC's advantages (HTTP/2 persistent connections, no per-request TCP handshake, HPACK header compression, binary Protobuf encoding) only materialise with real network latency. On loopback, REST's simpler framing wins.
>
> **What the demo shows clearly even on localhost:**
> - **Streaming** — 1,000 gRPC messages on 1 connection vs 1,000 REST requests
> - **High concurrency (c=500)** — HTTP/2 multiplexing vs 500 TCP connections
>
> **In production (pod-to-pod):** gRPC wins ~3-4× on throughput, ~73% on p50 latency.

**One Quarkus app, both protocols simultaneously:**
```
REST  → http://localhost:8080/metrics   (JSON / HTTP 1.1)
gRPC  → localhost:9000                  (Protobuf / HTTP 2)
```

**gRPC streaming uses `count` field:**
- `count=0` — live mode, one push per second
- `count=N` — benchmark mode, emit N messages as fast as possible

---

### Demo 06 — Low-Latency JVM: G1GC vs ZGC

Two identical Quarkus apps, same heap, same load. One runs G1GC, one runs ZGC.

> **ZGC will show lower throughput in the `hey` load test. This is expected.**
> ZGC inserts load barriers at every object reference read — this enables concurrent object relocation but adds ~5-15% constant overhead. In a micro-benchmark that hammers allocation, this is maximally visible.
>
> **The number that matters for SLAs is the GC pause delta** (Steps 4 and 5): how much cumulative time application threads were completely stopped. G1GC accumulates 50–300ms per pressure run. ZGC accumulates near-zero.

**On-stage framing:**
> "ZGC is slower in throughput here — that's the load barrier cost. But G1GC froze the application for [N]ms. ZGC froze it for less than 1ms. If your p99 SLA is 50ms and G1GC pauses for 150ms, you breach it on schedule."

**UBI9 default:** `ubi9/openjdk-21-runtime` ships **Shenandoah** as the default GC. Demo 06 overrides it explicitly for the clean comparison:
```yaml
# G1GC container
JAVA_OPTS: "-XX:+UseG1GC"

# ZGC container
JAVA_OPTS: "-XX:+UseZGC -XX:+ZGenerational"
```

---

### Demo 07 — Right-Sizing & Cost Impact Analysis

Pure Python analysis tool — no containers, no network access. Uses bundled sample data (14-day Prometheus export, 7 workloads spanning Spring Boot and Quarkus services).

**Methodology:** `p99 observed × 1.30 headroom` for CPU, `p99 × 1.25` for memory. GC spike detection: if CPU `p99/p50 > 3×` and GC pause p99 > 100ms, the tool switches to p95 as the CPU basis.

**Typical results on the sample cluster:**
- CPU requests cut 50-75% on most services
- Memory requests cut 40-56%
- 4 nodes → 2 nodes (+67% pod density)
- $6,720/month saving, 17× ROI on engineering effort

**Output:** `rightsizing-report.json` — machine-readable for CI/CD integration. kubectl commands generated and ready to apply.

```bash
./demo.sh                                    # sample data
./demo.sh --live                             # try kubectl first, fall back
python3 analyze.py --cost-per-node-hour 0.768  # override node cost
```

**OpenShift Cost Management** (Console → Cost Management → Optimizations tab) provides this analysis automatically at cluster scale with cloud billing integration.

---

### Demo 08 — Project Panama: C++20 → Quarkus via FFM

**JDK 25 LTS / Quarkus 3.33.1 / C++20**

Demonstrates the Foreign Function & Memory API (JEP 454, finalized JDK 22) calling a native C++20 shared library without any JNI wrapper code.

**C++ library (`native/src/jvmstats.cpp`):** Uses `std::span`, `std::ranges::sort`, structured bindings, and `std::transform_reduce` to analyse JVM metrics arrays and recommend GC algorithms.

**Java side:** `SymbolLookup` + `MethodHandle` + `Arena` — the entire FFM pattern:
```java
try (Arena arena = Arena.ofConfined()) {
    MemorySegment data = arena.allocateFrom(JAVA_DOUBLE, values);
    int result = (int) methodHandle.invoke(data, values.length, outP99);
} // native memory freed here — zero leaks possible
```

**Three-stage Dockerfile:** `debian` for g++/cmake → `temurin-25` for Maven → `ubi9/openjdk-25-runtime` with `ldconfig`.

**API note:** `Arena.allocateFrom()` (JDK 22+ final API) — not `allocateArray()` (preview API, removed).

---

### Demo 09 — AI Inference: LangChain4j + ONNX + Panama

**JDK 25 LTS / Quarkus 3.33.1 / all-MiniLM-L6-v2 (~25MB)**

The `langchain4j-embeddings-all-minilm-l6-v2` dependency bundles the ONNX model and ONNX Runtime Java, which uses Panama FFM to call native inference kernels in-process.

```
Quarkus REST → LangChain4j API → ONNX Runtime Java → Panama FFM → native .so
```

No Python sidecar. No gRPC. No subprocess. The model runs in the JVM.

**Endpoints:**
- `GET /embed?text=...` — 384-dimension float vector
- `GET /similarity?a=...&b=...` — cosine similarity between sentences
- `GET /classify?alert=...` — categorise an alert against runbook descriptions
- `POST /rank` — rank a list of past incidents by similarity to a reference

**First run:** Downloads ~300MB (ONNX Runtime + model). Subsequent builds use Podman layer cache.

**Practical use case:** Embed alert descriptions → find semantically similar past incidents → retrieve their runbooks → feed into an LLM for remediation. Full RAG pipeline in a Quarkus pod, no Python.

---

## Verified Demo Results

| Demo | Metric | Result |
|------|--------|--------|
| Demo 03 Quarkus AppCDS | Startup improvement | ~5% (intentional — proves build-time wins) |
| Demo 03 Spring Boot AppCDS | Startup improvement | ~40% |
| Demo 04 Leyden AOT | Startup improvement | 609ms → 148ms (−75%) |
| Demo 05 gRPC streaming | 1,000 messages | 1 connection vs 1,000 REST requests |
| Demo 06 ZGC | GC pause delta | ~0ms vs G1GC 50–300ms per run |
| Demo 07 Right-sizing | Node reduction | 4 → 2 nodes (+67% pod density) |
| Demo 07 Cost impact | Annual saving | ~$6,720/year (m5.2xlarge cluster) |

---

## Technology Stack

| Component | Version | Notes |
|-----------|---------|-------|
| Quarkus | 3.33.1 LTS | All Quarkus demos |
| Spring Boot | 4.0.5 | Demo 03 comparison only |
| Java (demos 01-06) | 21 LTS (Eclipse Temurin) | UBI9 openjdk-21-runtime |
| Java (demos 04, 08, 09) | 25 LTS (Eclipse Temurin) | UBI9 openjdk-25-runtime |
| GC default (UBI9) | **Shenandoah** | Red Hat's concurrent GC |
| Container runtime | Podman 4.x+ | Rootless, SELinux-aware |
| Base image (builder) | `docker.io/library/maven:3.9-eclipse-temurin-21/25` | |
| Base image (runtime) | `registry.access.redhat.com/ubi9/openjdk-21-runtime` | |
| Observability | Grafana LGTM (`docker.io/grafana/otel-lgtm:0.8.1`) | |
| Metrics scraping | `docker.io/prom/prometheus:v3.2.1` | |
| LangChain4j | 0.36.2 | Demo 09 |
| ONNX model | all-MiniLM-L6-v2 | Bundled in Maven dep |

---

## Podman on Fedora/RHEL — Known Issues

All demos are developed and tested on Fedora with rootless Podman. Key gotchas:

**Unqualified image names** prompt a registry selection dialog in non-interactive mode. All image names in `docker-compose.yml` and `Dockerfile` must be fully qualified (`docker.io/library/maven:...`, `registry.access.redhat.com/ubi9/...`).

**SELinux bind mounts** require `:Z` label. Without it, SELinux silently blocks container access to mounted files (no error in application logs). All bind mounts in Demo 02 use `:Z`.

**Named volumes** in rootless Podman are created owned by root. Prometheus (uid 65534) cannot write to them. Demo 02 uses `tmpfs` + `user: root` for Prometheus storage.

**`dependency:go-offline`** hangs in UBI containers. Removed from all Dockerfiles — use `--no-transfer-progress` with standard Maven goals only.

---

## Reference Links

| Resource | URL |
|----------|-----|
| Quarkus AppCDS | https://quarkus.io/guides/appcds |
| Quarkus + Project Leyden | https://quarkus.io/blog/leyden-2/ |
| Project Leyden (OpenJDK) | https://openjdk.org/projects/leyden/ |
| JEP 483 — AOT Class Loading & Linking | https://openjdk.org/jeps/483 |
| JEP 514 — AOT Command-Line Ergonomics | https://openjdk.org/jeps/514 |
| JEP 515 — AOT Method Profiling | https://openjdk.org/jeps/515 |
| JEP 454 — Foreign Function & Memory API | https://openjdk.org/jeps/454 |
| JEP 401 — Value Classes (Valhalla) | https://openjdk.org/jeps/401 |
| ZGC overview | https://wiki.openjdk.org/display/zgc |
| Generational ZGC (JEP 439) | https://openjdk.org/jeps/439 |
| Shenandoah GC (Red Hat) | https://developers.redhat.com/articles/2024/05/28/beginners-guide-shenandoah-garbage-collector |
| Red Hat Shenandoah docs (JDK 21) | https://docs.redhat.com/en/documentation/red_hat_build_of_openjdk/21/html-single/using_shenandoah_garbage_collector_with_red_hat_build_of_openjdk_21/index |
| UBI OpenJDK 21 runtime image | https://catalog.redhat.com/software/containers/ubi9/openjdk-21-runtime/6501ce769a0d86945c422d5f |
| UBI OpenJDK 25 runtime image | https://catalog.redhat.com/software/containers/ubi9/openjdk-25 |
| OpenShift Cost Management | https://docs.redhat.com/en/documentation/cost_management_service |
| OpenShift low-latency tuning | https://docs.openshift.com/container-platform/latest/scalability_and_performance/cnf-low-latency-tuning.html |
| Micrometer JVM metrics | https://micrometer.io/docs/ref/jvm |
| LangChain4j ONNX embeddings | https://docs.langchain4j.dev/integrations/embedding-models/in-process |
| KEDA | https://keda.sh |
| Quarkus gRPC guide | https://quarkus.io/guides/grpc-getting-started |
| `grpcurl` CLI | https://github.com/fullstorydev/grpcurl |
| `ghz` gRPC load tester | https://ghz.sh |
| VPA (Vertical Pod Autoscaler) | https://github.com/kubernetes/autoscaler/tree/master/vertical-pod-autoscaler |
| Kubernetes CPU Manager | https://kubernetes.io/docs/tasks/administer-cluster/cpu-management-policies/ |
