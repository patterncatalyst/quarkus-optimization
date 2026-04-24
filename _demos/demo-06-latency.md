---
title: "Demo 06 — Low-Latency JVM: G1GC vs ZGC"
demo_number: "06"
session: bonus
runtime: "Quarkus 3.33.1 / Java 21"
time: "~10 min"
demo_dir: "quarkus-demo-06-latency"
run_command: "./demo.sh"
prev_url: "/demos/demo-05-grpc/"
prev_title: "Demo 05 — gRPC"
next_url: "/demos/demo-07-rightsizing/"
next_title: "Demo 07 — Right-Sizing"
---

Two identical Quarkus apps, same heap, same load. One G1GC, one ZGC. The **GC pause delta** (not throughput) is the metric that matters for SLAs.

## UBI9 default GC

`ubi9/openjdk-21-runtime` ships **Shenandoah** by default. This demo overrides it explicitly:

```yaml
JAVA_OPTS: "-XX:+UseG1GC"        # container 1
JAVA_OPTS: "-XX:+UseZGC -XX:+ZGenerational"  # container 2
```

## ZGC throughput caveat

ZGC uses a load barrier — fires on every object read — adding ~5-15% constant overhead. In the `hey` load test, ZGC shows lower throughput than G1GC. This is **expected and correct**. The meaningful metric is the GC pause delta in Steps 4-5.

## GC decision guide

| Collector | Pause | Choose when |
|-----------|-------|-------------|
| Shenandoah | 1–20ms | UBI9 default — already this without any config |
| ZGC | < 1ms | p99 SLA tighter than 10ms, or heap > 32GB |
| G1GC | 50–300ms | Throughput-oriented, non-latency-sensitive |

## Reference

- [Demo source]({{ site.repo }}/tree/main/java-optimization-demos/quarkus-demo-06-latency)
- [Shenandoah GC Guide]({{ '/docs/shenandoah-guide/' | relative_url }})
- [ZGC wiki](https://wiki.openjdk.org/display/zgc)
