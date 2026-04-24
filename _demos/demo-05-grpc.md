---
title: "Demo 05 — REST vs gRPC: Two Protocols"
demo_number: "05"
session: bonus
runtime: "Quarkus 3.33.1 / Java 21"
time: "~10 min"
demo_dir: "quarkus-demo-05-grpc"
run_command: "./demo.sh"
prev_url: "/demos/demo-04-leyden/"
prev_title: "Demo 04 — Leyden"
next_url: "/demos/demo-06-latency/"
next_title: "Demo 06 — Low Latency"
---

One Quarkus app simultaneously serves REST on `:8080` and gRPC on `:9000`. Same service, two protocols, honest comparison including the localhost caveat.

## The honest localhost caveat

> ⚠️ **gRPC unary is slower than REST on localhost.** Network cost is zero on loopback. gRPC's advantages only materialise with real pod-to-pod network latency.

**What gRPC wins even on localhost:**
- Server streaming: 1 connection vs 1,000 REST requests
- High concurrency (c=500): HTTP/2 multiplexing vs 500 TCP connections

**In production (pod-to-pod):** gRPC wins ~3-4× throughput, ~73% p50 latency.

## Streaming modes

```bash
# Live stream — one push per second (count=0)
grpcurl -plaintext -d '{"host":"localhost","count":0}' \
  localhost:9000 MetricsService/StreamMetrics

# Benchmark — 1000 messages as fast as possible
grpcurl -plaintext -d '{"host":"localhost","count":1000}' \
  localhost:9000 MetricsService/StreamMetrics
```

## Prerequisites

`hey`, `grpcurl`, `ghz` — see [Prerequisites guide]({{ '/docs/prerequisites/' | relative_url }}).

## Reference

- [Demo source]({{ site.repo }}/tree/main/java-optimization-demos/quarkus-demo-05-grpc)
- [Quarkus gRPC guide](https://quarkus.io/guides/grpc-getting-started)
