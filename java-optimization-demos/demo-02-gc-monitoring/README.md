# Quarkus Demo 02 — GC Monitoring with Prometheus, Grafana & Jaeger

## Framework
**Quarkus 3.33.1 LTS** / Java 21 (released March 25, 2026)

## What This Demo Shows

Identical observability story to the Spring Boot version — but running on
Quarkus, which changes several important specifics that the audience needs
to know for real-world adoption.

## Key Quarkus Differences from Spring Boot

| Aspect | Spring Boot 4.0.5 | Quarkus 3.33.1 LTS |
|--------|-------------------|--------------------|
| Prometheus endpoint | `/actuator/prometheus` | `/q/metrics` |
| Health endpoint | `/actuator/health` | `/q/health/live` |
| Virtual threads | `spring.threads.virtual.enabled=true` | `@RunOnVirtualThread` annotation |
| Custom trace spans | `Observation.createNotStarted()` | `@WithSpan` (OTel native) |
| REST annotations | `@RestController` + `@GetMapping` | `@Path` + `@GET` (Jakarta REST) |
| Dependency injection | Spring DI / constructor | CDI `@Inject` + `@ApplicationScoped` |

## Stack

| Service | Port | Notes |
|---------|------|-------|
| Quarkus G1GC App | 8080 | metrics at `/q/metrics`, health at `/q/health` |
| Quarkus ZGC App  | 8081 | same app, Generational ZGC |
| Prometheus | 9090 | scrapes `/q/metrics` every 5s |
| Grafana | 3000 | JVM GC dashboard (admin/admin) |
| Jaeger | 16686 | OTel traces via OTLP gRPC port 4317 |

## Prerequisites

- Docker Desktop with at least 4 GB RAM available
- Ports 3000, 4317, 4318, 8080, 8081, 9090, 16686 free

## Running

```bash
chmod +x demo.sh
./demo.sh
```

Or manually:

```bash
docker compose up -d --build

# Wait ~60s for first-time build, then:
# Grafana:     http://localhost:3000  (admin / admin)
# Prometheus:  http://localhost:9090
# Jaeger:      http://localhost:16686  → service: quarkus-gc-monitoring-demo

# Generate GC load
curl "http://localhost:8080/allocate?mb=100&iterations=10"   # G1GC
curl "http://localhost:8081/allocate?mb=100&iterations=10"   # ZGC

# Virtual threads demo (Quarkus: @RunOnVirtualThread annotation)
curl "http://localhost:8080/virtual-threads?tasks=500&workMs=5"

# View raw Prometheus metrics
curl http://localhost:8080/q/metrics | grep jvm_gc

# Tear down
docker compose down -v
```

## Quarkus-Specific Extensions Used

```xml
<!-- RESTEasy Reactive (Quarkus 3.x REST layer) -->
<dependency>
    <groupId>io.quarkus</groupId>
    <artifactId>quarkus-rest</artifactId>
</dependency>

<!-- Micrometer Prometheus — auto-publishes /q/metrics -->
<dependency>
    <groupId>io.quarkus</groupId>
    <artifactId>quarkus-micrometer-registry-prometheus</artifactId>
</dependency>

<!-- OpenTelemetry — auto-instruments REST, OTLP to Jaeger -->
<dependency>
    <groupId>io.quarkus</groupId>
    <artifactId>quarkus-opentelemetry</artifactId>
</dependency>
```

## Key Prometheus Queries (same PromQL as Spring Boot)

```promql
# GC pause P99 (ms) — alert if > 500ms
histogram_quantile(0.99,
  rate(jvm_gc_pause_seconds_bucket[1m])
) * 1000

# Heap utilization — alert if > 85%
jvm_memory_used_bytes{area="heap"} / jvm_memory_max_bytes{area="heap"}

# Quarkus HTTP request rate
rate(http_server_requests_seconds_count[1m])
```

## Dev Mode (live reload)

```bash
cd app
./mvnw quarkus:dev

# Dev UI:    http://localhost:8080/q/dev
# Metrics:   http://localhost:8080/q/metrics
# Health:    http://localhost:8080/q/health
```

## Reference

- Quarkus Micrometer guide: https://quarkus.io/guides/telemetry-micrometer
- Quarkus OTel guide: https://quarkus.io/guides/opentelemetry
- Virtual threads: https://quarkus.io/guides/virtual-threads
