# Taming the JVM: Optimizing Java Workloads on OpenShift & Kubernetes

> Conference talk companion repository — demos, slides, and diagrams for a 60-minute session on JVM performance engineering for cloud-native Java teams.

**Talk abstract:** Most Java teams deploy to Kubernetes with misconfigured heaps, oversized resource requests, wrong GC algorithms, and no visibility into what the JVM is actually doing. This session walks through nine live demos covering container-aware JVM tuning, startup acceleration, GC monitoring, protocol selection, latency engineering, right-sizing, native interop via Project Panama, and AI inference — all on Quarkus 3.33.1 LTS with real metrics and honest benchmark results.

---

## Repository Structure

```
quarkus-optimization/
│
├── README.md                    ← You are here
├── .sdkmanrc                    ← Pins Java 21.0.10-tem (Eclipse Temurin) via SDKMAN
├── .gitignore
│
├── diagrams/                    ← Architecture and flow diagrams (Excalidraw)
│   └── 07-grpc-vs-rest.excalidraw
│
├── presentation/                ← Conference slide decks (PowerPoint)
│   ├── java-openshift-optimization.pptx       Main 32-slide deck
│   ├── grpc-slides.pptx                        Standalone gRPC slides (3)
│   ├── low-latency-slides.pptx                 Low-latency + GC vendor slides (5)
│   ├── rightsizing-slides.pptx                 Right-sizing + cost analysis slides (5)
│   ├── panama-slides.pptx                      Project Panama slides (3)
│   └── valhalla-slides.pptx                    Project Valhalla slides (2)
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
| **[Slides](./presentation/)** | 6 PowerPoint decks covering the full talk | `presentation/` |
| **[Diagrams](./diagrams/)** | Excalidraw architecture diagrams | `diagrams/` |

---

## The Demos

All demos run on **Podman** with **Red Hat UBI9** runtime containers — the same toolchain used in production OpenShift environments. Java 21 LTS for most demos; Java 25 LTS for Demos 04, 08, and 09.

> **Running on Fedora/RHEL?** See the [Podman gotchas section](./java-optimization-demos/README.md#podman-on-fedoraenterprise-linux--known-issues) in the demos README — SELinux bind mount labels and rootless Podman volume permissions require specific configuration covered there.

### Core JVM Tuning

| Demo | Topic | Runtime | Time |
|------|-------|---------|------|
| [Demo 01](./java-optimization-demos/demo-01-heap-sizing/) | Container-aware heap sizing — `UseContainerSupport` + `MaxRAMPercentage` | Java 21 | ~5 min |
| [Demo 02](./java-optimization-demos/quarkus-demo-02-gc-monitoring/) | GC monitoring with Prometheus + Grafana LGTM | Quarkus 3.33.1 / Java 21 | ~10 min |
| [Demo 03 (Quarkus)](./java-optimization-demos/quarkus-demo-03-appcds/) | AppCDS startup acceleration — ~5% improvement | Quarkus 3.33.1 / Java 21 | ~8 min |
| [Demo 03 (Spring Boot)](./java-optimization-demos/demo-03-appcds/) | AppCDS startup acceleration — ~40% improvement | Spring Boot 4.0.5 / Java 21 | ~8 min |
| [Demo 04](./java-optimization-demos/quarkus-demo-04-leyden/) | Project Leyden AOT cache — 609ms → 148ms (−75%) | Quarkus 3.33.1 / **Java 25** | ~12 min |

### Protocol & Latency

| Demo | Topic | Runtime | Time |
|------|-------|---------|------|
| [Demo 05](./java-optimization-demos/quarkus-demo-05-grpc/) | REST vs gRPC — same service, two protocols | Quarkus 3.33.1 / Java 21 | ~10 min |
| [Demo 06](./java-optimization-demos/quarkus-demo-06-latency/) | Low-latency JVM: G1GC vs ZGC GC pause delta | Quarkus 3.33.1 / Java 21 | ~10 min |

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

Six PowerPoint decks in the `presentation/` directory, all using a consistent dark navy / teal theme with extensive speaker notes on every slide.

### [Main Deck](./presentation/java-openshift-optimization.pptx) — 32 slides

The complete talk from container heap sizing through Project Leyden. Structured for a 60-minute session with optional bonus slides for extended Q&A.

| Slides | Topic |
|--------|-------|
| 1–5 | Container-aware JVM heap — the `UseContainerSupport` story |
| 6–12 | GC monitoring — Micrometer, Prometheus, Grafana, HPA interaction |
| 13–16 | AppCDS — what it caches, Spring Boot vs Quarkus, honest results |
| 17–22 | Project Leyden — AOT cache, training workload, 3-stage Dockerfile |
| 23–26 | REST vs gRPC — wire format, streaming, honest localhost results |
| 27–32 | Bonus: JVM anti-patterns + remediation, gRPC protocol deep dive |

### [gRPC Slides](./presentation/grpc-slides.pptx) — 3 slides

Standalone deep-dive on gRPC vs REST: intro, protocol comparison (HTTP/2 vs HTTP/1.1, Protobuf vs JSON, header compression), and benchmark results table with localhost caveat.

### [Low-Latency Slides](./presentation/low-latency-slides.pptx) — 5 slides

Covers Demo 06's territory in depth:
1. Demo 06 intro (G1GC vs ZGC)
2. The latency problem — stop-the-world vs concurrent GC
3. Low-latency tuning ladder — 6 levels from easy to advanced
4. Kubernetes + OpenShift configuration (CPU Manager, Topology Manager, PerformanceProfile)
5. **Which GC ships by default** — Shenandoah (UBI9), G1GC (Temurin/Corretto/Azure/Microsoft), OpenJ9 (IBM Semeru) — vendor comparison with barrier type and pause characteristics

### [Right-Sizing Slides](./presentation/rightsizing-slides.pptx) — 5 slides

Covers Demo 07's territory:
1. Demo 07 intro
2. The over-provisioning problem — how teams set requests (and why they're wrong)
3. Right-sizing analysis results — 7-workload table with GC spike detection
4. Bin-packing improvement — before/after node density
5. Cost impact & business case — $80,640/year headline, ROI calculation, OpenShift Cost Management

### [Panama Slides](./presentation/panama-slides.pptx) — 3 slides

Covers Demos 08 and 09:
1. Project Panama intro — JNI pain points vs FFM/Vector API/jextract solution
2. Demo 08 — C++20 → FFM architecture, Arena memory model, code comparison
3. Demo 09 — LangChain4j ONNX stack diagram, four "no Python sidecar" benefits

### [Valhalla Slides](./presentation/valhalla-slides.pptx) — 2 slides

1. The 30-year gap — primitives vs objects, boxing cost, Valhalla value classes
2. Why it matters for Kubernetes — memory footprint, GC pressure, cache performance (three-column impact analysis)

---

## The Diagrams

Architecture and flow diagrams in `diagrams/` — all in Excalidraw format, editable at [excalidraw.com](https://excalidraw.com).

| File | Contents |
|------|----------|
| `07-grpc-vs-rest.excalidraw` | gRPC vs REST wire format comparison — HTTP/2 vs HTTP/1.1, Protobuf frame layout, streaming connection model |

---

## Tool Versions & Setup

```bash
# SDKMAN (recommended) — activates Java 21.0.10-tem automatically
sdk env

# Verify
java -version    # should show Eclipse Temurin 21.0.10
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
| `registry.access.redhat.com/ubi9/openjdk-21-runtime` | **Shenandoah** | Red Hat's concurrent GC, 1–20ms pauses |
| `eclipse-temurin:21` | G1GC | OpenJDK upstream default |
| `amazoncorretto:21` | G1GC | Shenandoah available as option |
| `mcr.microsoft.com/openjdk/jdk:21` | G1GC | Upstream default |
| `azul/zulu-openjdk:21` | G1GC | Upstream default |
| `ibm-semeru-runtime-open-21` | OpenJ9 GC | Different JVM entirely |

Demos 02 and 06 explicitly override the UBI9 Shenandoah default with `-XX:+UseG1GC` and `-XX:+UseZGC` for clean comparison. In production on OpenShift, Shenandoah (the default) gives 1–20ms pauses without any configuration.

**The two problems these demos solve:**

Most JVM performance problems in Kubernetes come down to two root causes:

1. **Wrong defaults** — heap sized to host RAM not container limit, GC algorithm not matched to latency SLA, CPU requests set to GC spike peak not steady-state load
2. **No visibility** — teams don't see GC pause times in Grafana, don't know what Prometheus queries to run, don't know their pods are over-provisioned by 3-4×

These demos address both: right defaults first, then visibility, then optimisation.

---

## Companion Reading

- *Optimizing Cloud Native Java* (O'Reilly) — the book this talk is based on
- *SRE with Java Microservices* (O'Reilly, Jonathan Schneider) — SLI/SLO framing
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
