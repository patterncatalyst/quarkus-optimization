# Quarkus Demos — Taming the JVM on OpenShift
## Quarkus 3.33.1 LTS / Java 21

These are the **Quarkus** versions of Demo 02 and Demo 03. Demo 01
(heap sizing) is framework-agnostic plain Java and works for both.

---

## What Changes vs Spring Boot

| Aspect | Spring Boot 4.0.5 | Quarkus 3.33.1 LTS |
|--------|-------------------|---------------------|
| Prometheus endpoint | `/actuator/prometheus` | `/q/metrics` |
| Health endpoint | `/actuator/health` | `/q/health/live` |
| Virtual Threads | `spring.threads.virtual.enabled=true` | `@RunOnVirtualThread` annotation |
| OTel tracing | `spring-boot-starter-opentelemetry` | `quarkus-opentelemetry` (built-in) |
| AppCDS | 3-step manual process | `quarkus.package.jar.aot.enabled=true` |
| REST | `@RestController` + `@GetMapping` | `@Path` + `@GET` (Jakarta REST) |
| DI | Spring DI / `@Autowired` | CDI / `@Inject` + `@ApplicationScoped` |
| Startup time | ~4000-8000 ms | ~300-800 ms (5-10x faster) |
| Artifact | Fat JAR (`app.jar`) | `quarkus-app/quarkus-run.jar` + layers |

---

## Running the Demos

```bash
# Demo 02 — GC Monitoring (Quarkus)
cd quarkus-demo-02-gc-monitoring
chmod +x demo.sh && ./demo.sh

# Demo 03 — AppCDS Startup (Quarkus)
cd quarkus-demo-03-appcds
chmod +x demo.sh && ./demo.sh
```

---

## quarkus-demo-02-gc-monitoring

Full observability stack:
- **G1GC App** (port 8080) — Quarkus 3.33.1 + Micrometer + OTel
- **ZGC App** (port 8081) — same app, Generational ZGC (Java 21)
- **Prometheus** (port 9090) — scrapes `/q/metrics` every 5s
- **Grafana** (port 3000) — JVM GC dashboard (admin/admin)
- **Jaeger** (port 16686) — distributed traces via OTLP gRPC

Key Prometheus queries for Quarkus:
```promql
# GC pause P99 (ms)
histogram_quantile(0.99, rate(jvm_gc_pause_seconds_bucket[1m])) * 1000

# Heap utilization
jvm_memory_used_bytes{area="heap"} / jvm_memory_max_bytes{area="heap"}

# HTTP request rate
rate(http_server_requests_seconds_count[1m])
```

---

## quarkus-demo-03-appcds

Compares Quarkus startup with and without AppCDS.

**The Quarkus AppCDS story:**

```properties
# application.properties — that's it!
quarkus.package.jar.aot.enabled=true
```

```bash
# Maven handles everything automatically
mvn package -DskipTests
# → builds JAR, runs training pass, generates archive, bundles it
```

Typical results:
```
Quarkus baseline:    ~400 ms   (vs Spring Boot ~4200 ms)
Quarkus + AppCDS:    ~220 ms   (additional 45% improvement)
Quarkus Native:      ~20 ms    (GraalVM — see below)
```

**Going further — Native compilation:**
```bash
# Build a GraalVM native image (requires GraalVM JDK or mandrel)
mvn package -Pnative -DskipTests
# Startup: ~0.01-0.05s — sub-millisecond startup!
```

---

## Dev Mode

Quarkus Dev Mode gives live reload and Dev UI:

```bash
cd quarkus-demo-02-gc-monitoring/app
./mvnw quarkus:dev

# Dev UI at: http://localhost:8080/q/dev
# Live metrics: http://localhost:8080/q/metrics
# Live health:  http://localhost:8080/q/health
```

---

## Reference

- Quarkus 3.33.1 release: https://quarkus.io/blog/quarkus-3-33-released/
- Quarkus LTS policy: https://quarkus.io/blog/lts-releases/
- Micrometer guide: https://quarkus.io/guides/telemetry-micrometer
- OpenTelemetry guide: https://quarkus.io/guides/opentelemetry
- AppCDS guide: https://quarkus.io/guides/appcds
- Virtual threads: https://quarkus.io/guides/virtual-threads
