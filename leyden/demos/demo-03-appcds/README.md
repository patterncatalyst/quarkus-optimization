# Demo 03 — AppCDS Startup Time Acceleration

## What This Demo Shows

**Class Data Sharing (AppCDS)** pre-processes and memory-maps class metadata
at *image build time*, so every container start reuses it instead of
re-loading thousands of classes from scratch.

Typical result: **35–55% faster startup** — from ~4 seconds to ~2 seconds
for a standard Spring Boot application.

## Why It Matters for Kubernetes

During an HPA scale-out event, every pod that starts slowly is a pod that
cannot serve traffic yet. With 10 pods scaling simultaneously:

| Scenario | Per-pod startup | 10 pods ready in |
|----------|----------------|-----------------|
| Baseline | ~4.0 s         | ~4.0 s (parallel) |
| AppCDS   | ~2.0 s         | ~2.0 s (parallel) |
| **Saved** | **~2.0 s**    | **2 fewer seconds of degraded service** |

Under traffic spikes, those 2 seconds mean fewer failed requests and SLO breaches.

## Prerequisites

- Docker Desktop
- 4 GB RAM available
- Ports 18080 free (only used transiently during timing)

## Running

```bash
chmod +x demo.sh
./demo.sh
```

## Manual Step-by-Step (what the demo does under the hood)

```bash
cd app

# Build baseline (no AppCDS)
docker build -f Dockerfile.baseline -t startup-demo:baseline .

# Build with AppCDS (3-stage: build → CDS training → runtime)
docker build -f Dockerfile.appcds -t startup-demo:appcds .

# Compare manually
time docker run --rm --memory=512m startup-demo:baseline 2>&1 | grep "Started"
time docker run --rm --memory=512m startup-demo:appcds   2>&1 | grep "Started"
```

## How the AppCDS Dockerfile Works

```
Stage 1: mvn package → app.jar
Stage 2: java -Xshare:off -XX:DumpLoadedClassList=app.lst -jar app.jar
         java -Xshare:dump -XX:SharedArchiveFile=app.jsa -jar app.jar
Stage 3: COPY app.jar + app.jsa → runtime image
         CMD: java -Xshare:on -XX:SharedArchiveFile=/app/app.jsa -jar app.jar
```

## AppCDS Flags Reference

| Flag | Purpose |
|------|---------|
| `-Xshare:off` | Disable sharing (training pass) |
| `-XX:DumpLoadedClassList=file` | Record all loaded classes |
| `-Xshare:dump` | Generate the archive |
| `-XX:SharedClassListFile=file` | Input for archive generation |
| `-XX:SharedArchiveFile=file` | Path to write/read archive |
| `-Xshare:on` | Use archive (fails if missing — use `auto` to be safe) |

## Extending to Your Application

1. Add the training stage to your Dockerfile (copy Stage 2 from `Dockerfile.appcds`)
2. Adjust the `-Dspring.context.exit=onRefresh` to match your framework
3. For Quarkus: uses its own AOT — AppCDS less needed
4. For Micronaut: similar approach, or use `-Dmicronaut.server.netty.worker-threads=0`

## Reference

- *Optimizing Cloud Native Java* — Chapter 6: Startup Optimization
- OpenJDK AppCDS guide: https://openjdk.org/jeps/350
- Spring Boot AppCDS: https://docs.spring.io/spring-boot/docs/current/reference/html/deployment.html
