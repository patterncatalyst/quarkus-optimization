# Quarkus Demo 03 — AppCDS Startup Acceleration

## Framework
**Quarkus 3.33.1 LTS** / Java 21 (released March 25, 2026)

## The Story

Quarkus is already **5-10x faster** to start than Spring Boot thanks to
build-time processing. AppCDS adds another 30-50% on top. And for the
truly startup-obsessed: Quarkus Native brings it to ~20ms.

| Mode | Typical Startup | Notes |
|------|----------------|-------|
| Spring Boot 4.0.5 (baseline) | ~4000-8000 ms | Framework scanning at runtime |
| Quarkus 3.33.1 (JVM, no AppCDS) | ~300-800 ms | Build-time processing |
| Quarkus 3.33.1 + AppCDS | ~150-400 ms | One property, auto-handled |
| Quarkus 3.33.1 Native (GraalVM) | ~10-50 ms | Static binary, no JVM |

## Why Quarkus Is Already Fast

Unlike Spring Boot which scans classpath and resolves dependencies at
runtime, Quarkus does most of this **at build time**:

- CDI bean resolution at compile time (Arc container)
- Extension build steps replace runtime initialization
- No classpath scanning on startup — all metadata pre-computed
- Reactive Vert.x core avoids thread-per-request overhead from startup

## Quarkus AppCDS: One Property

Spring Boot requires a 3-step manual process. Quarkus needs one line:

```properties
# application.properties
quarkus.package.jar.aot.enabled=true
```

The `quarkus-maven-plugin` automatically:
1. Runs the application for a training pass
2. Captures the loaded class list
3. Generates the CDS archive
4. Bundles it with `quarkus-run.jar`

No `-Xshare:off`, no `-Xshare:dump`, no manual archive management.

## Prerequisites

- Docker Desktop
- Ports 18080 free transiently during timing

## Running

```bash
chmod +x demo.sh
./demo.sh
```

## Manual Steps

```bash
cd app

# Baseline (no AppCDS)
docker build -f Dockerfile.baseline -t quarkus-startup:baseline .
time docker run --rm quarkus-startup:baseline 2>&1 | grep "started in"

# With AppCDS (one Maven property activates it)
docker build -f Dockerfile.appcds -t quarkus-startup:appcds .
time docker run --rm quarkus-startup:appcds 2>&1 | grep "started in"
```

## Going Native (optional, requires GraalVM / Mandrel)

```bash
# Install GraalVM 21+ or Red Hat Mandrel
sdk install java 21.0.3-graalce   # via SDKMAN

# Build native binary
cd app
./mvnw package -Pnative -DskipTests

# Run it
./target/quarkus-startup-1.0.0-runner

# Expected startup: ~0.01-0.05s
```

The native Dockerfile (Quarkus-generated) produces a ~50-80 MB static
binary — no JVM required in the container image.

## Quarkus Layered Artifact Structure

Unlike Spring Boot's fat JAR, Quarkus produces a layered structure:

```
target/quarkus-app/
├── quarkus-run.jar    ← entrypoint (tiny, just launches the app)
├── lib/               ← all dependency JARs (changes rarely)
├── app/               ← your application classes (changes often)
├── quarkus/           ← generated Quarkus bootstrap code
└── app.cds            ← AppCDS archive (when enabled)
```

This layering is **Docker cache-friendly**: only `app/` changes on most
rebuilds, so `lib/` and `quarkus/` layers are reused from cache.

## Reference

- Quarkus AppCDS guide: https://quarkus.io/guides/appcds
- Quarkus 3.33.1 release: https://quarkus.io/blog/quarkus-3-33-released/
- GraalVM native image: https://quarkus.io/guides/building-native-image
