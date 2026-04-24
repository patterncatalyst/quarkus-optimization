---
title: "Demo 03 — AppCDS Startup Acceleration"
demo_number: "03"
session: core
runtime: "Quarkus 3.33.1 + Spring Boot 4.0.5 / Java 21"
time: "~8 min"
demo_dir: "quarkus-demo-03-appcds"
run_command: "./demo.sh"
prev_url: "/demos/demo-02-gc-monitoring/"
prev_title: "Demo 02 — GC Monitoring"
next_url: "/demos/demo-04-leyden/"
next_title: "Demo 04 — Project Leyden"
---

AppCDS caches parsed + verified bytecode. Quarkus gets ~5% improvement. Spring Boot gets ~40%. The small Quarkus number **proves the point** — Quarkus already moved class-loading work to build time.

## Configuration

```properties
# application.properties
quarkus.package.jar.aot.enabled=true
```

## Honest benchmark

| Framework | Baseline | + AppCDS | Delta |
|-----------|----------|----------|-------|
| Spring Boot 4.0.5 | ~4–8s | ~2.4s | −40% |
| Quarkus 3.33.1 | ~0.6s | ~0.57s | −5% |

Quarkus + AppCDS is **14× faster** than Spring Boot baseline even with only 5% improvement.

## Spring Boot comparison

```bash
cd demo-03-appcds   # Spring Boot version in java-optimization-demos/
chmod +x demo.sh
./demo.sh
```

## Reference

- [Quarkus demo source]({{ site.repo }}/tree/main/java-optimization-demos/quarkus-demo-03-appcds)
- [Spring Boot demo source]({{ site.repo }}/tree/main/java-optimization-demos/demo-03-appcds)
- [Red Hat AppCDS article](https://developers.redhat.com/articles/2024/01/23/speed-java-application-startup-time-appcds)
