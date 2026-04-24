---
title: "Demo 04 — Project Leyden AOT Cache"
demo_number: "04"
session: bonus
runtime: "Quarkus 3.33.1 / JDK 25 LTS"
time: "~12 min"
demo_dir: "quarkus-demo-04-leyden"
run_command: "./demo.sh"
jdk25: true
prev_url: "/demos/demo-03-appcds/"
prev_title: "Demo 03 — AppCDS"
next_url: "/demos/demo-05-grpc/"
next_title: "Demo 05 — gRPC"
---

**Verified result: 609ms → 148ms (−75%)** startup on JDK 25 LTS. Caches parsed + linked classes AND JIT method profiles. First requests after startup get near-peak JIT performance.

## Configuration

```properties
# application.properties
quarkus.package.jar.aot.enabled=true
# Quarkus automatically switches to aot-jar packaging
```

```bash
mvn verify   # runs @QuarkusIntegrationTest → writes app.aot
```

## Three-stage Dockerfile

| Stage | Image | Purpose |
|-------|-------|---------|
| compiler | `maven:3.9-eclipse-temurin-25` | Build JAR |
| trainer | `ubi9/openjdk-25` | Run integration tests → create app.aot |
| runtime | `ubi9/openjdk-25-runtime` | Copy JAR + app.aot |

JVM fingerprint must match between trainer and runtime.

## Common pitfalls

- `@QuarkusIntegrationTest` not `@QuarkusTest` — only integration tests train the cache
- `mvn verify` not `mvn package` — failsafe plugin only fires in verify phase
- Don't add `-XX:AOTCache` to Dockerfile — Quarkus sets it automatically

## Reference

- [Demo source]({{ site.repo }}/tree/main/java-optimization-demos/quarkus-demo-04-leyden)
- [JEP 483](https://openjdk.org/jeps/483) / [JEP 514](https://openjdk.org/jeps/514) / [JEP 515](https://openjdk.org/jeps/515)
- [Quarkus + Leyden blog](https://quarkus.io/blog/leyden-2/)
