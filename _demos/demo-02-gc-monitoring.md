---
title: "Demo 02 — GC Monitoring with Prometheus"
demo_number: "02"
session: core
runtime: "Quarkus 3.33.1 / Java 21"
time: "~10 min"
demo_dir: "quarkus-demo-02-gc-monitoring"
run_command: "./demo.sh"
prev_url: "/demos/demo-01-heap-sizing/"
prev_title: "Demo 01 — Heap Sizing"
next_url: "/demos/demo-03-appcds/"
next_title: "Demo 03 — AppCDS"
---

Two Quarkus apps (G1GC on `:8080`, ZGC on `:8081`) + Grafana LGTM + standalone Prometheus scraping `/q/metrics`. Live GC pause histograms and traces simultaneously.

## Required configuration

```properties
# application.properties — without this, Grafana GC panels show no data
quarkus.micrometer.distribution.percentiles-histogram.jvm.gc.pause=true
quarkus.micrometer.distribution.percentiles.jvm.gc.pause=0.5,0.95,0.99
```

## Key PromQL queries

```promql
# GC pause P99 (ms)
histogram_quantile(0.99, rate(jvm_gc_pause_seconds_bucket[1m])) * 1000

# Heap utilisation %
jvm_memory_used_bytes{area="heap"} / jvm_memory_max_bytes{area="heap"} * 100
```

## Fedora / RHEL notes

All bind mounts require `:Z` for SELinux. Prometheus uses `tmpfs` + `user: root` to avoid rootless Podman named volume permission issues. Do **not** mount custom config into `otel-lgtm` — it breaks the internal OTel pipeline and produces blank dashboards.

## Generate load

```bash
# Allocate heap and watch the GC panels react
curl "http://localhost:8080/allocate?mb=100&iterations=10"

# Virtual threads — 500 concurrent tasks
curl "http://localhost:8080/virtual-threads?tasks=500&workMs=5"
```

## Reference

- [Demo source]({{ site.repo }}/tree/main/java-optimization-demos/quarkus-demo-02-gc-monitoring)
- Grafana JVM dashboard 4701
