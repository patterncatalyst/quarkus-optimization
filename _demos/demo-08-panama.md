---
title: "Demo 08 — Project Panama: C++20 via FFM"
demo_number: "08"
session: bonus
runtime: "Quarkus 3.33.1 / JDK 25 LTS"
time: "~8 min"
demo_dir: "quarkus-demo-08-panama"
run_command: "./demo.sh"
jdk25: true
prev_url: "/demos/demo-07-rightsizing/"
prev_title: "Demo 07 — Right-Sizing"
next_url: "/demos/demo-09-onnx/"
next_title: "Demo 09 — ONNX"
---

The Foreign Function & Memory API (JEP 454, finalized JDK 22) calls a native C++20 shared library from pure Java. No JNI wrapper code, no platform-specific compilation pipeline.

## What the native library does

Three C++20 functions using `std::span`, `std::ranges`, and structured bindings:
- `jvmstats_recommend_gc()` — analyse GC pause times, recommend G1/Shenandoah/ZGC
- `jvmstats_cpu_profile()` — detect GC-dominated CPU spike patterns
- `jvmstats_recommend_memory_mb()` — compute right-sized memory request from RSS samples

## The Panama pattern

```java
try (Arena arena = Arena.ofConfined()) {
    // allocateFrom() — JDK 22+ final API (not allocateArray())
    MemorySegment data  = arena.allocateFrom(JAVA_DOUBLE, myArray);
    MemorySegment outP99 = arena.allocate(JAVA_DOUBLE);

    int gcCode = (int) recommendGc.invoke(data, myArray.length, outP99);
    double p99 = outP99.get(JAVA_DOUBLE, 0);
} // all native memory freed here — zero leaks possible
```

## Three-stage Dockerfile

| Stage | Image | Purpose |
|-------|-------|---------|
| cpp-builder | `ubi9` | `dnf install gcc-c++ cmake make` → compile `.so` |
| java-builder | `maven:3.9-eclipse-temurin-25` | Build Quarkus JAR |
| runtime | `ubi9/openjdk-25-runtime` | Copy `.so` + JAR, `ldconfig` |

No subscription required — `gcc-c++` is in UBI9's freely accessible appstream repo.

## Try the endpoints

```bash
curl -s http://localhost:8080/demo | python3 -m json.tool

# Analyse custom GC pause data
curl -s -X POST http://localhost:8080/gc-recommend \
  -H "Content-Type: application/json" \
  -d '[10,12,180,11,175,14]' | python3 -m json.tool
```

## Reference

- [Demo source]({{ site.repo }}/tree/main/java-optimization-demos/quarkus-demo-08-panama)
- [JEP 454 — Foreign Function & Memory API](https://openjdk.org/jeps/454)
- [Project Panama](https://openjdk.org/projects/panama/)
