# Demo 01 — Container-Aware JVM Heap Sizing

## What This Demo Shows

The JVM, by default, reads **host** memory — not your container limit.
On a 16 GB laptop, a Java pod with a 512 MB container limit will try to
allocate a **4 GB heap**, triggering OOMKill the moment it allocates real memory.

This demo proves the problem and fixes it live.

## Prerequisites

- Docker Desktop (or any Docker runtime)
- ~2 minutes

## Running the Demo

```bash
chmod +x demo.sh
./demo.sh
```

## What You'll See

| Scenario | Container Limit | JVM Max Heap | Result |
|----------|----------------|-------------|--------|
| A — Bad  | 512 MB         | 4+ GB       | OOMKill risk |
| B — Good | 512 MB         | ~384 MB     | ✅ Container-aware |
| C — Sizes| 256m/512m/1g   | Scales correctly | ✅ Dynamic |
| D — OOM  | 64 MB          | 4+ GB       | Exit 137 (OOMKill) |

## Key JVM Flags

```bash
-XX:+UseContainerSupport       # Read cgroup, not /proc/meminfo
-XX:MaxRAMPercentage=75.0      # Heap = 75% of container limit
-XX:InitialRAMPercentage=50.0  # Avoid over-committing on startup
-XX:NativeMemoryTracking=summary  # Enable jcmd native memory reporting
```

## Manual Exploration

```bash
# Run the good container interactively and explore JVM internals:
docker run -it --rm --memory=512m \
  --entrypoint sh jvm-demo:good

# Inside the container:
java -XX:+UseContainerSupport -XX:MaxRAMPercentage=75 \
     -XX:NativeMemoryTracking=summary \
     HeapInfo --keep-alive &

jcmd 1 VM.native_memory summary     # Full memory breakdown
jcmd 1 GC.heap_info                 # GC heap details
jcmd 1 VM.flags                     # All active JVM flags
```

## Reference

- *Optimizing Cloud Native Java* — Chapter 3: Container Memory Management
- OpenJDK UseContainerSupport: https://openjdk.org/jeps/381
- cgroup v2 support: Java 15+
