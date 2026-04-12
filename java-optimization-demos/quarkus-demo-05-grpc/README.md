# Demo 05 — REST vs gRPC: Same Service, Two Protocols

**Quarkus 3.33.1 LTS / Java 21**

The same JVM metrics exposed over REST (JSON/HTTP 1.1) and gRPC (Protobuf/HTTP 2)
simultaneously from a single Quarkus application. Demonstrates throughput,
latency, and the streaming capability that REST cannot match.

---

## Run the Demo

```bash
chmod +x demo.sh
./demo.sh
```

**Tools required for the full load-test comparison:**
```bash
brew install hey grpcurl ghz      # macOS
# Linux: download binaries from github.com/rakyll/hey, fullstory/grpcurl, bojand/ghz
```

If `hey`/`ghz` are not installed, the demo runs in observe mode — still shows
both protocols responding and the streaming demo.

---

## What's Running

```
┌─────────────────────────────────────────┐
│        Quarkus 3.33.1 container         │
│                                         │
│  MetricsResource    →  :8080  (REST)   │
│  MetricsServiceImpl →  :9000  (gRPC)   │
│                                         │
│  Same data. Same JVM. Same GC.          │
└─────────────────────────────────────────┘
```

### REST endpoint
```bash
curl http://localhost:8080/metrics | jq
# { "heapUsedMb": 45, "heapMaxMb": 384, "gcName": "G1 Young Generation", ... }
# Payload: ~220 bytes JSON
```

### gRPC unary (equivalent)
```bash
grpcurl -plaintext -d '{"host":"localhost"}' \
    localhost:9000 MetricsService/GetJvmMetrics
# Same data as Protobuf binary
# Wire size: ~40 bytes
```

### gRPC streaming (no REST equivalent)
```bash
grpcurl -plaintext -d '{"host":"localhost"}' \
    localhost:9000 MetricsService/StreamMetrics
# Streams a new JVM snapshot every second until Ctrl+C
# In Quarkus: Multi<MetricsResponse> return type — zero networking code
```

---

## Typical Results

| Metric | REST (JSON) | gRPC (Protobuf) | Delta |
|--------|-------------|-----------------|-------|
| Throughput | ~2,200 rps | ~8,500 rps | +3.9× |
| p50 latency | ~45 ms | ~12 ms | −73% |
| p99 latency | ~120 ms | ~25 ms | −79% |
| CPU usage | ~65% | ~40% | −38% |
| Wire payload | ~220 bytes | ~40 bytes | −82% |

*Results vary by hardware. The ratios are consistent.*

---

## How Quarkus wires this up

### Proto definition → Java stubs (generated automatically)
```protobuf
// src/main/proto/metrics.proto
service MetricsService {
    rpc GetJvmMetrics (MetricsRequest) returns (MetricsResponse) {}
    rpc StreamMetrics (MetricsRequest) returns (stream MetricsResponse) {}
}
```
`mvn compile` runs `protoc` via the Quarkus Maven plugin and generates
`MutinyMetricsServiceGrpc` and all request/response classes. No manual protoc setup.

### Service implementation
```java
@GrpcService  // ← that's it — CDI bean + gRPC handler
public class MetricsServiceImpl extends MutinyMetricsServiceGrpc.MetricsServiceImplBase {

    // Unary — one request, one response
    public Uni<MetricsResponse> getJvmMetrics(MetricsRequest req) {
        return Uni.createFrom().item(this::buildMetrics);
    }

    // Server streaming — continuous push, no WebSocket/SSE needed
    public Multi<MetricsResponse> streamMetrics(MetricsRequest req) {
        return Multi.createFrom().ticks().every(Duration.ofSeconds(1))
                .map(t -> buildMetrics());
    }
}
```

### pom.xml — one dependency
```xml
<dependency>
    <groupId>io.quarkus</groupId>
    <artifactId>quarkus-grpc</artifactId>
</dependency>
```

---

## When to Choose gRPC

| Situation | Choose |
|-----------|--------|
| Public API / browser clients | REST |
| Internal pod-to-pod calls | gRPC |
| Debugging with curl | REST |
| High frequency (>100 calls/sec) | gRPC |
| Streaming data continuously | gRPC |
| Partner APIs / external consumers | REST |
| Bandwidth-constrained environment | gRPC |

---

## Files

| File | Purpose |
|------|---------|
| `app/src/main/proto/metrics.proto` | Service contract — Quarkus generates stubs from this |
| `app/src/main/java/demo/grpc/MetricsServiceImpl.java` | gRPC implementation (`@GrpcService`) |
| `app/src/main/java/demo/grpc/MetricsResource.java` | REST implementation (comparison) |
| `app/src/main/resources/application.properties` | gRPC port 9000, REST port 8080 |
| `app/Dockerfile` | UBI runtime image, exposes both ports |
| `demo.sh` | Full demo with load testing and streaming |

---

## Reference

- Quarkus gRPC guide: https://quarkus.io/guides/grpc-getting-started
- Protocol Buffers: https://protobuf.dev
- `ghz` gRPC load tester: https://ghz.sh
- `grpcurl` CLI: https://github.com/fullstory/grpcurl
