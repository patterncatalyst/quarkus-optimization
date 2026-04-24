---
title: "Demo 01 — Container-Aware Heap Sizing"
demo_number: "01"
session: core
runtime: "Java 21"
time: "~5 min"
demo_dir: "demo-01-heap-sizing"
run_command: "./demo.sh"
next_url: "/demos/demo-02-gc-monitoring/"
next_title: "Demo 02 — GC Monitoring"
---

Without `UseContainerSupport`, the JVM reads host RAM from `/proc/meminfo` and claims 25% of the node's full memory — inside a container with a 512MB limit. Kubernetes OOMKills the pod within seconds.

## What you'll see

1. JVM without `UseContainerSupport` → reads host RAM → OOMKill simulation
2. `UseContainerSupport` + `MaxRAMPercentage=75.0` → JVM respects the container limit
3. Live `jcmd` output comparing configured heap sizes

## The fix

```bash
# ❌ Hardcoded — breaks when VPA or cluster admin resizes
-Xms512m -Xmx2048m

# ✅ Container-aware — scales automatically with the limit
-XX:+UseContainerSupport
-XX:MaxRAMPercentage=75.0
-XX:InitialRAMPercentage=50.0
```

## Why 75%?

`MaxRAMPercentage=75` leaves 25% for five other JVM memory regions that most teams forget:

| Region | Typical size |
|--------|-------------|
| Metaspace | 50–200MB |
| Platform Thread Stacks | 1MB × thread count |
| JIT Code Cache | 128–256MB |
| Direct ByteBuffers (Netty) | Varies |
| GC bookkeeping | 50–100MB |

## Verify at runtime

```bash
jcmd <pid> VM.flags | grep -E "MaxHeap|RAMPercentage"
```

## Reference

- [Demo source]({{ site.repo }}/tree/main/java-optimization-demos/demo-01-heap-sizing)
- [Quarkus Configuration Reference]({{ '/docs/quarkus-reference/' | relative_url }})
