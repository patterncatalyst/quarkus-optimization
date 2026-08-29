# Taming the JVM: Optimizing Java Workloads on OpenShift & Kubernetes

> Conference talk companion repository — demos, slides, and diagrams for a 60-minute session on JVM performance engineering for cloud-native Java teams.

**Talk abstract:** Most Java teams deploy to Kubernetes with misconfigured heaps, oversized resource requests, wrong GC algorithms, and no visibility into what the JVM is actually doing. This session walks through nine live demos covering container-aware JVM tuning, startup acceleration, GC monitoring, protocol selection, latency engineering, right-sizing, native interop via Project Panama, and AI inference — all on Quarkus 3.33.1 LTS with real metrics and reproducible benchmark results.

---

## Repository Structure

```
quarkus-optimization/
│
├── README.md                    ← You are here
├── .sdkmanrc                    ← Pins Java 25.0.1-tem (Eclipse Temurin) via SDKMAN
├── .gitignore
│
├── diagrams/                    ← Architecture and flow diagrams (Excalidraw)
│   └── 07-grpc-vs-rest.excalidraw
│
├── presentation/                ← Conference slide deck (PowerPoint)
│   └── optimizing-quarkus-on-kubernetes.pptx  Full 56-slide deck
│
└── java-optimization-demos/     ← All runnable demos
    ├── README.md                ← Full demo documentation (start here)
    ├── demo-01-heap-sizing/
    ├── quarkus-demo-02-gc-monitoring/
    ├── quarkus-demo-03-appcds/
    ├── demo-03-appcds/          (Spring Boot comparison)
    ├── quarkus-demo-04-leyden/
    ├── quarkus-demo-05-grpc/
    ├── quarkus-demo-06-latency/
    ├── quarkus-demo-07-rightsizing/
    ├── quarkus-demo-08-panama/
    └── quarkus-demo-09-onnx/
```

---

## Quick Navigation

| Section | Contents | Start here |
|---------|----------|------------|
| **[Demos](./java-optimization-demos/README.md)** | 9 runnable demos, all with `./demo.sh` | `java-optimization-demos/README.md` |
| **[Slides](./presentation/)** | 56-slide deck covering the full talk | `presentation/` |
| **[Diagrams](./diagrams/)** | Excalidraw architecture diagrams | `diagrams/` |

---

## The Demos

All demos run on **Podman** with **Red Hat UBI 10** runtime containers — the same toolchain used in production OpenShift environments. Java 25 LTS.

> **Running on Fedora/RHEL?** See the [Podman gotchas section](./java-optimization-demos/README.md#podman-on-fedoraenterprise-linux--known-issues) in the demos README — SELinux bind mount labels and rootless Podman volume permissions require specific configuration covered there.

### Core JVM Tuning

| Demo | Topic | Runtime | Time |
|------|-------|---------|------|
| [Demo 01](./java-optimization-demos/demo-01-heap-sizing/) | Container-aware heap sizing — `UseContainerSupport` + `MaxRAMPercentage` | Java 25 | ~5 min |
| [Demo 02](./java-optimization-demos/quarkus-demo-02-gc-monitoring/) | GC monitoring with Prometheus + Grafana LGTM | Quarkus 3.33.1 / Java 25 | ~10 min |
| [Demo 03 (Quarkus)](./java-optimization-demos/quarkus-demo-03-appcds/) | AppCDS startup acceleration — ~5% improvement | Quarkus 3.33.1 / Java 25 | ~8 min |
| [Demo 03 (Spring Boot)](./java-optimization-demos/demo-03-appcds/) | AppCDS startup acceleration — ~40% improvement | Spring Boot 4.0.5 / Java 25 | ~8 min |
| [Demo 04](./java-optimization-demos/quarkus-demo-04-leyden/) | Project Leyden AOT cache — 609ms → 148ms (−75%) | Quarkus 3.33.1 / **Java 25** | ~12 min |

### Protocol & Latency

| Demo | Topic | Runtime | Time |
|------|-------|---------|------|
| [Demo 05](./java-optimization-demos/quarkus-demo-05-grpc/) | REST vs gRPC — same service, two protocols | Quarkus 3.33.1 / Java 25 | ~10 min |
| [Demo 06](./java-optimization-demos/quarkus-demo-06-latency/) | Low-latency JVM: G1GC vs ZGC GC pause delta | Quarkus 3.33.1 / Java 25 | ~10 min |

### Operations & Economics

| Demo | Topic | Runtime | Time |
|------|-------|---------|------|
| [Demo 07](./java-optimization-demos/quarkus-demo-07-rightsizing/) | Right-sizing & cost impact — no cluster needed | Python 3 (stdlib) | ~3 min |

### Future of Java

| Demo | Topic | Runtime | Time |
|------|-------|---------|------|
| [Demo 08](./java-optimization-demos/quarkus-demo-08-panama/) | Project Panama: C++20 → Quarkus via FFM API | Quarkus 3.33.1 / **Java 25** | ~8 min |
| [Demo 09](./java-optimization-demos/quarkus-demo-09-onnx/) | AI inference: LangChain4j + ONNX + Panama | Quarkus 3.33.1 / **Java 25** | ~10 min |

---

## The Slides

One 56-slide deck in the `presentation/` directory — [`optimizing-quarkus-on-kubernetes.pptx`](./presentation/optimizing-quarkus-on-kubernetes.pptx) — using a consistent dark navy / teal theme with extensive speaker notes on every slide. It carries the full talk end to end: agenda and methodology, seven core sections of content, nine demo dividers, a takeaways/resources close, and five topic deep-dives (Leyden, gRPC, low-latency, right-sizing, Panama, Valhalla, anti-patterns) that expand on their respective demos.

| Slides | Topic |
|--------|-------|
| 1–4 | Title, agenda, the Java-on-Kubernetes problem, measurement methodology & caveats |
| 5–7 | Section 01 — Container-native JVM fundamentals (heap sizing, memory regions) |
| 8–10 | Section 02 — Right-sizing Java workloads & pod bin-packing |
| 11–15 | Section 03 — Garbage collection optimization (GC/HPA thrash, GC selection, tuning parameters) |
| 16–19 | Section 04 — Startup: CDS → AppCDS → Leyden AOT cache, virtual threads & execution models |
| 20–22 | Section 05 — Observability & instrumentation (JFR, Cryostat, Prometheus/Micrometer) |
| 23–25 | Section 06 — Autoscaling integration (HPA, VPA, GC-induced thrash prevention) |
| 26–27 | Section 07 — Systematic tuning workflow & cost optimization |
| 28–30 | Demo dividers 01–03 (heap sizing, GC monitoring, AppCDS) |
| 31–32 | Key takeaways & resources / Q&A |
| 33–35 | Project Leyden deep dive + Demo 04 divider |
| 36–39 | REST vs gRPC deep dive + Demo 05 divider |
| 40–44 | Low-latency JVM tuning deep dive + Demo 06 divider |
| 45–49 | Right-sizing analysis & cost impact deep dive + Demo 07 divider |
| 50–52 | Project Panama deep dive + Demos 08/09 |
| 53–54 | Project Valhalla deep dive |
| 55–56 | Common JVM anti-patterns & remediation |

---

## The Diagrams

Architecture and flow diagrams in `diagrams/` — all in Excalidraw format, editable at [excalidraw.com](https://excalidraw.com).

| File | Contents |
|------|----------|
| `07-grpc-vs-rest.excalidraw` | gRPC vs REST wire format comparison — HTTP/2 vs HTTP/1.1, Protobuf frame layout, streaming connection model |

---

## Tool Versions & Setup

```bash
# SDKMAN (recommended) — activates Java 25.0.1-tem automatically
sdk env

# Verify
java -version    # should show Eclipse Temurin 25.0.1
podman --version # 4.x+

# For gRPC demos (Demo 05)
brew install grpcurl ghz hey   # macOS
# Linux: see individual tool release pages

# For Panama demo (Demo 08) — native library built inside container
# No local g++/cmake needed unless developing the native library
```

**JDK 25 for Demos 04, 08, 09:**
```bash
sdk install java 25.0.1-tem   # Eclipse Temurin 25
sdk use java 25.0.1-tem       # for the session
```

Containers for all demos bring their own JDK via the UBI base images — local JDK is only needed if running Quarkus in dev mode.

---

## Key Technical Context

**GC defaults by container image:**

| Image | Default GC | Notes |
|-------|-----------|-------|
| `registry.access.redhat.com/ubi10/openjdk-25-runtime` | **Shenandoah** | Red Hat's concurrent GC, 1–20ms pauses |
| `eclipse-temurin:21` | G1GC | OpenJDK upstream default |
| `amazoncorretto:21` | G1GC | Shenandoah available as option |
| `mcr.microsoft.com/openjdk/jdk:21` | G1GC | Upstream default |
| `azul/zulu-openjdk:21` | G1GC | Upstream default |
| `ibm-semeru-runtime-open-21` | OpenJ9 GC | Different JVM entirely |

Demos 02 and 06 explicitly override the UBI 10 Shenandoah default with `-XX:+UseG1GC` and `-XX:+UseZGC` for clean comparison. In production on OpenShift, Shenandoah (the default) gives 1–20ms pauses without any configuration.

**The two problems these demos solve:**

Most JVM performance problems in Kubernetes come down to two root causes:

1. **Wrong defaults** — heap sized to host RAM not container limit, GC algorithm not matched to latency SLA, CPU requests set to GC spike peak not steady-state load
2. **No visibility** — teams don't see GC pause times in Grafana, don't know what Prometheus queries to run, don't know their pods are over-provisioned by 3-4×

These demos address both: right defaults first, then visibility, then optimisation.

---

## Companion Reading

- Evans, B. J., & Gough, J. *Optimizing Cloud Native Java*, 2nd ed., O'Reilly, 2024 (ISBN 9781098149345) — the book this talk is based on
- Schneider, J., *SRE with Java Microservices*, O'Reilly, 2020 (ISBN 9781492073925) — SLI/SLO framing
- Shirazi, J., *javaperformancetuning.com* — living performance newsletters: #308 (measurement methodology, 2026-07-27), #306 (low-latency / allocation reduction), #307 (LLM-assisted tuning). Scope: current newsletters, not the legacy J2EE-era tips index.
- [Quarkus guides](https://quarkus.io/guides/) — authoritative Quarkus configuration reference
- [Red Hat build of OpenJDK docs](https://docs.redhat.com/en/documentation/red_hat_build_of_openjdk) — UBI image details, Shenandoah tuning
- [OpenJDK Project Leyden](https://openjdk.org/projects/leyden/) — AOT cache design docs
- [OpenJDK Project Panama](https://openjdk.org/projects/panama/) — FFM API and Vector API
- [OpenJDK Project Valhalla](https://openjdk.org/projects/valhalla/) — value classes and universal generics

---

## Contributing

Issues and pull requests welcome. If you find a demo that doesn't build on your platform — especially differences between Fedora/RHEL and macOS Podman behaviour — please open an issue with your Podman version and OS.

---

*Talk delivered at various conferences 2025–2026. All demos tested on Fedora 41 with Podman 5.x and macOS with Podman 4.x.*
