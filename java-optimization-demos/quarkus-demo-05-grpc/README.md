# Demo 05 — REST vs gRPC: Same Service, Two Protocols

**Quarkus 3.33.1 LTS / Java 25**

The same JVM metrics exposed over REST (JSON/HTTP 1.1) and gRPC (Protobuf/HTTP 2)
simultaneously from a single Quarkus application. Demonstrates throughput,
latency, and the streaming capability that REST cannot match.

---

## Run the Demo

```bash
chmod +x demo.sh
./demo.sh
```

**Prerequisites:** `podman`, `grpcurl`, `hey`, `ghz`, and `python3` on PATH.

```bash
brew install hey grpcurl ghz      # macOS (podman + python3 via brew too)
# Linux: download binaries from github.com/rakyll/hey, fullstorydev/grpcurl, bojand/ghz
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

> **Honest result — localhost skews *against* gRPC.** The numbers below were
> measured on a single machine over loopback, where there is effectively no
> network latency. That flatters REST's simpler per-call stack and hides
> gRPC's real advantages. Do not extrapolate localhost numbers to production.

| Scenario | REST (JSON/HTTP1.1) | gRPC (Protobuf/HTTP2) | Winner |
|----------|---------------------|------------------------|--------|
| Unary, low concurrency (c=50, localhost) | ~26,700 rps | ~10,200 rps | **REST** |
| Unary, high concurrency (c=500, localhost) | gap narrows | ~parity to gRPC-ahead (varies run-to-run) | ~tie |
| Server streaming (1 conn, 1000 msgs) | no equivalent | decisive | **gRPC** |
| Wire payload | ~220 bytes | ~40 bytes | **gRPC** (−82%) |

**What this actually shows:**

- **REST is faster for localhost unary calls.** Over loopback there is no
  network latency to amortize, so REST's lighter per-call machinery wins
  outright (~26.7k vs ~10.2k rps at c=50).
- **gRPC is decisively faster for streaming.** One persistent HTTP/2
  connection pushes a continuous stream of snapshots; REST has no equivalent
  (you would need SSE/WebSocket plus hand-rolled framing).
- **They reach ~parity at high concurrency** on localhost, as HTTP/2
  multiplexing over a single connection starts to pay off (c=500).
- **gRPC pulls ahead over a real network** (pod-to-pod, cross-AZ) where
  connection reuse, HTTP/2 multiplexing, and the ~82% smaller Protobuf
  payload matter — exactly the conditions a loopback benchmark hides.

*Results vary by hardware and network. The localhost unary win for REST is
real but is not the production story — pick the protocol for your topology.*

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
- `grpcurl` CLI: https://github.com/fullstorydev/grpcurl
