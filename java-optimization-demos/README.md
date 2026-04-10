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
├── demo-02-gc-monitoring/             ← Demo 02: GC metrics (Spring Boot comparison)
└── demo-03-appcds/                    ← Demo 03: AppCDS (Spring Boot comparison)
```

---

## Prerequisites

| Tool | Version | Notes |
|------|---------|-------|
| **Podman** | 4.x+ | `brew install podman` / `dnf install podman` / `apt install podman` |
| **podman-compose** | 1.x+ | `pip install podman-compose` — required for Demo 02 only |
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
```

> **Demo 04 first run:** `mvn verify` runs inside the container and downloads
> ~500 MB of Quarkus 3.33.1 dependencies. Subsequent runs use Podman's layer
> cache and are significantly faster.

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

## Container Images Used

| Stage | Image | Used in |
|-------|-------|---------|
| Build | `docker.io/library/maven:3.9-eclipse-temurin-21` | Demos 02, 03 |
| Build | `docker.io/library/maven:3.9-eclipse-temurin-25` | Demo 04 |
| Runtime | `registry.access.redhat.com/ubi9/openjdk-21-runtime` | Demos 02, 03 |
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

---

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