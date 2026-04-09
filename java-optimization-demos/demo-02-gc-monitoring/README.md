# Demo 02 — GC Monitoring with Prometheus, Grafana & Jaeger

## What This Demo Shows

A complete observability stack running locally via Docker Compose:
- **Prometheus + Grafana** — live JVM GC pause histograms, heap utilization, thread counts
- **Jaeger** — distributed traces via Spring Boot 4.0's built-in OpenTelemetry support
- **G1GC vs Generational ZGC** side-by-side comparison under identical load

## Stack

| Service    | Port  | Purpose |
|------------|-------|---------|
| G1GC App   | 8080  | Spring Boot 4.0.5 + Micrometer, G1GC |
| ZGC App    | 8081  | Same app, Generational ZGC (Java 21) |
| Prometheus | 9090  | Scrapes `/actuator/prometheus` every 5s |
| Grafana    | 3000  | Pre-built JVM GC dashboard (admin/admin) |
| Jaeger     | 16686 | Distributed trace UI (OTLP receiver on 4318) |

## Prerequisites

- Docker Desktop with Compose V2
- 6 GB RAM available to Docker
- Ports 3000, 4317, 4318, 8080, 8081, 9090, 16686 free

## Running

```bash
chmod +x demo.sh
./demo.sh
```

Or manually:

```bash
# Start everything
docker compose up -d --build

# URLs once healthy (~60s first run):
# Grafana:    http://localhost:3000  (admin / admin)
# Prometheus: http://localhost:9090/alerts
# Jaeger UI:  http://localhost:16686

# Generate GC load — watch Grafana AND Jaeger simultaneously
curl "http://localhost:8080/allocate?mb=100&iterations=10"

# Virtual threads demo (500 concurrent tasks, 5ms simulated I/O each)
curl "http://localhost:8081/virtual-threads?tasks=500&workMs=5"

# Tear down
docker compose down -v
```

## Key Prometheus Queries

```promql
# GC pause P99 (ms) — alert if > 500ms
histogram_quantile(0.99, rate(jvm_gc_pause_seconds_bucket[1m])) * 1000

# Heap utilization — alert if > 85%
jvm_memory_used_bytes{area="heap"} / jvm_memory_max_bytes{area="heap"}

# GC collections per minute
rate(jvm_gc_pause_seconds_count[1m]) * 60

# Time in GC vs wall clock (should be < 5%)
rate(jvm_gc_pause_seconds_sum[1m])
```

## Spring Boot 4.0 Changes Used

| Feature | Old (Boot 3.x) | New (Boot 4.0.5) |
|---------|----------------|------------------|
| Prometheus enable | `management.metrics.export.prometheus.enabled=true` | `management.prometheus.metrics.export.enabled=true` |
| Endpoint access | `management.endpoint.prometheus.enabled=true` | `management.endpoint.prometheus.access=unrestricted` |
| OpenTelemetry | Manual setup | `spring-boot-starter-opentelemetry` auto-configures SDK |
| Tracing export | Third-party lib | OTLP export built-in, targets Jaeger/Tempo/OTLP collector |

## Viewing Traces in Jaeger

1. Open http://localhost:16686
2. Select service: `gc-monitoring-demo`
3. Click **Find Traces**
4. Each `/allocate` and `/virtual-threads` call appears as a trace with timing breakdown

## Alert Thresholds (Prometheus Rules)

| Alert | Condition | Severity |
|-------|-----------|----------|
| HighGCPauseP99 | P99 > 500ms for 30s | warning |
| HighHeapUtilization | Heap > 85% for 1m | warning |
| CriticalHeapUtilization | Heap > 95% for 10s | critical |

## Reference

- *SRE with Java Microservices* — Ch. 5: Observability for Java
- Spring Boot 4.0 OpenTelemetry: https://docs.spring.io/spring-boot/reference/actuator/tracing.html
- Micrometer JVM metrics: https://micrometer.io/docs/ref/jvm
