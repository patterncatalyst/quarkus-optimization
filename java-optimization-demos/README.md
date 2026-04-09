# Taming the JVM: Optimizing Java Workloads on OpenShift & Kubernetes
## Conference Demo Repository

Companion demos for the 60-minute talk based on:
- 📗 *Optimizing Cloud Native Java* (O'Reilly)
- 📗 *SRE with Java Microservices* (O'Reilly — Jonathan Schneider)

---

## Repository Structure

```
.
├── java-openshift-optimization.pptx   ← 26-slide presentation
│
├── demo-01-heap-sizing/               ← Demo 01: Container-aware JVM heap
│   ├── README.md
│   ├── demo.sh                        ← Run this!
│   ├── src/HeapInfo.java
│   ├── Dockerfile.bad                 ← JVM ignoring container limits
│   └── Dockerfile.good                ← UseContainerSupport + MaxRAMPercentage
│
├── demo-02-gc-monitoring/             ← Demo 02: GC metrics in Prometheus
│   ├── README.md
│   ├── demo.sh                        ← Run this!
│   ├── docker-compose.yml             ← Full stack (app + Prometheus + Grafana)
│   ├── app/                           ← Spring Boot + Micrometer app
│   ├── prometheus/                    ← prometheus.yml + alerting rules
│   └── grafana/                       ← Pre-built JVM GC dashboard
│
└── demo-03-appcds/                    ← Demo 03: AppCDS startup acceleration
    ├── README.md
    ├── demo.sh                        ← Run this!
    └── app/
        ├── Dockerfile.baseline        ← Cold class loading (before)
        └── Dockerfile.appcds          ← CDS archive baked in (after)
```

---

## Prerequisites

| Tool | Version | Install |
|------|---------|---------|
| Docker Desktop | 4.x+ | https://www.docker.com/products/docker-desktop |
| Docker Compose | V2 (bundled) | Included with Docker Desktop |

**No Java or Maven installation needed** — all builds happen inside Docker.

---

## Quick Start

```bash
# Clone / download this repo, then:

# Demo 01 — Container-aware heap sizing (~5 min)
cd demo-01-heap-sizing && chmod +x demo.sh && ./demo.sh

# Demo 02 — GC monitoring with Prometheus (~10 min)
cd demo-02-gc-monitoring && chmod +x demo.sh && ./demo.sh

# Demo 03 — AppCDS startup acceleration (~8 min)
cd demo-03-appcds && chmod +x demo.sh && ./demo.sh
```

---

## What Each Demo Teaches

### Demo 01 — Container-Aware Heap Sizing

**Problem:** Default JVM reads host RAM, not your container limit.
A 512 MB container ends up with a 4 GB heap → OOMKill.

**Fix demonstrated:**
```bash
-XX:+UseContainerSupport
-XX:MaxRAMPercentage=75.0
-XX:InitialRAMPercentage=50.0
```

**You'll see:** Live `jcmd` output comparing heap sizes before and after.

---

### Demo 02 — GC Monitoring with Prometheus

**Problem:** GC pauses cause CPU spikes that trigger false HPA scale-out.
Without JVM metrics in Prometheus, you're tuning blind.

**Stack started:** Spring Boot app → Prometheus → Grafana dashboard

**You'll see:**
- `jvm_gc_pause_seconds` P50/P99 histograms
- Side-by-side G1GC vs ZGC pause comparison under load
- PrometheusRule alerts firing when P99 > 500ms
- PromQL queries for GC analysis

---

### Demo 03 — AppCDS Startup Acceleration

**Problem:** Cold JVM startup takes 4–6 seconds → HPA scale-out is slow.

**Fix demonstrated:** AppCDS archive baked into Docker image at build time.

**You'll see:** 5 timed runs baseline vs AppCDS showing ~40% improvement.

---

## Mapping to Presentation Sections

| Slide(s) | Demo | Key Concept |
|----------|------|------------|
| 4–5      | 01   | UseContainerSupport, MaxRAMPercentage |
| 6–7      | 01   | Resource requests/limits, bin-packing |
| 8–10     | 02   | GC tuning, G1GC vs ZGC |
| 11–13    | 03   | AppCDS, tiered compilation |
| 14–16    | 02   | Cryostat, Prometheus, Micrometer |
| 17–19    | 02   | HPA, VPA, autoscaling thrash |
| 20–21    | all  | Tuning workflow, cost ROI |

---

## Troubleshooting

**Docker build fails on first run:**
- Increase Docker memory limit to 4 GB (Settings → Resources → Memory)
- The Maven build inside Docker needs internet access to download dependencies

**Port conflicts:**
- Demo 02 uses ports 3000, 8080, 8081, 9090
- Run `docker compose down` from the demo-02 directory to release them

**AppCDS archive not found (Demo 03):**
- The `-Xshare:on` flag is strict — if the archive path is wrong it exits
- Check: `docker run --rm startup-demo:appcds ls -lh /app/app.jsa`

**Spring Boot app takes > 60s to start:**
- On first run, Docker pulls the base images (~300 MB)
- Subsequent runs use the cache and start in the expected time

---

## Customizing for Your Application

### Change the GC in Demo 02
Edit `docker-compose.yml`:
```yaml
environment:
  GC_TYPE: shenandoah   # g1gc | zgc | shenandoah
```

### Add your own JVM flags
Set `JAVA_OPTS` in any Dockerfile or docker-compose environment block:
```yaml
JAVA_OPTS: >-
  -XX:+UseContainerSupport
  -XX:MaxRAMPercentage=75.0
  -XX:MaxGCPauseMillis=100
  -XX:ParallelGCThreads=2
```

### Apply AppCDS to your own Spring Boot app
Copy `Dockerfile.appcds` to your project and replace:
- `startup-demo-*.jar` → your app JAR name
- Adjust training run flags if your app needs different init args

---

## Reference Links

| Resource | URL |
|----------|-----|
| Cryostat (JFR on OpenShift) | https://cryostat.io |
| Micrometer JVM metrics | https://micrometer.io/docs/ref/jvm |
| Grafana JVM dashboard | https://grafana.com/grafana/dashboards/4701 |
| KEDA (event-driven autoscaling) | https://keda.sh |
| OpenShift Cost Management | https://console.redhat.com/openshift/cost-management |
| JVM NMT (native memory) | https://docs.oracle.com/en/java/javase/21/vm/native-memory-tracking.html |
| AppCDS JEP-350 | https://openjdk.org/jeps/350 |

---

## Quarkus Demos (Quarkus 3.33.1 LTS / Java 21)

See **`QUARKUS-README.md`** for the full comparison guide.

| Demo | Directory | Command |
|------|-----------|---------|
| Demo 01 | `demo-01-heap-sizing/` | Same — plain Java, framework-agnostic |
| Demo 02 | `quarkus-demo-02-gc-monitoring/` | `./demo.sh` |
| Demo 03 | `quarkus-demo-03-appcds/` | `./demo.sh` |

### Key differences from Spring Boot demos

- Prometheus: `/q/metrics` (not `/actuator/prometheus`)
- Health: `/q/health/live` (not `/actuator/health`)
- Virtual threads: `@RunOnVirtualThread` annotation (not a property)
- AppCDS: `quarkus.package.jar.appcds.enabled=true` (one line — fully automatic)
- Startup: Quarkus baseline ~300-800 ms vs Spring Boot ~4000-8000 ms
