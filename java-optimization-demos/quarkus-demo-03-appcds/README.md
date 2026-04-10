# Quarkus Demo 03 — AppCDS Startup Acceleration

## Framework
**Quarkus 3.33.1 LTS** / Java 21 (released March 25, 2026)

## The Story

Quarkus is already **5-10x faster** to start than Spring Boot thanks to
build-time processing. AppCDS adds another 15-30% on top of that on JDK 21.
On JDK 25 with the full Leyden AOT cache, the improvement reaches 40-55% —
see Demo 04.

| Mode | Typical Startup | Notes |
|------|----------------|-------|
| Spring Boot 4.0.5 (baseline) | ~4000-8000 ms | Framework scanning at runtime |
| Quarkus 3.33.1 (JVM, no AppCDS) | ~300-800 ms | Build-time processing |
| Quarkus 3.33.1 + AppCDS (JDK 21) | ~220-600 ms | 15-30% improvement |
| Quarkus 3.33.1 + Leyden AOT (JDK 25) | ~150-400 ms | 40-55% improvement — Demo 04 |
| Quarkus 3.33.1 Native (GraalVM) | ~10-50 ms | Static binary, no JVM |

**Why the modest gain on JDK 21?** AppCDS on JDK 21 caches parsed class
bytes only. The full Leyden AOT cache (JDK 25, JEP 483+515) also caches
linked class state and JIT method profiles — that's where the larger gains
come from. Quarkus uses the same single property for both; the JDK version
determines which tier of cache is generated.

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
quarkus.package.jar.appcds.enabled=true
```

Or pass it at build time without touching application.properties:

```bash
mvn package -DskipTests -Dquarkus.package.jar.appcds.enabled=true
```

The `quarkus-maven-plugin` automatically:
1. Runs the application for a training pass
2. Captures the loaded class list
3. Generates the AppCDS archive (`app-cds.jsa`)
4. Bundles it with `quarkus-run.jar`

No `-Xshare:off`, no `-Xshare:dump`, no manual archive management.

## Prerequisites

- Docker (Linux / Docker Desktop on Mac or Windows)
- `python3` on PATH (used for the results table)

## Running

```bash
chmod +x demo.sh
./demo.sh
```

## Manual Steps

```bash
cd app

# Build both images
docker build -f Dockerfile.baseline -t quarkus-startup:baseline .
docker build -f Dockerfile.appcds   -t quarkus-startup:appcds   .
# Note: quarkus.package.jar.appcds.use-container=false is set in application.properties
# to prevent Docker-in-Docker during archive generation inside the build layer

# Measure startup — use detached + poll approach (docker run hangs on Linux
# because the Quarkus server runs indefinitely)
for image in quarkus-startup:baseline quarkus-startup:appcds; do
  cid=$(docker run -d --memory=512m $image)
  sleep 1
  echo "$image:"
  docker logs $cid 2>&1 | grep "started in"
  docker stop $cid && docker rm $cid
done
```

## Quarkus Layered Artifact Structure

Unlike Spring Boot's fat JAR, Quarkus produces a layered structure:

```
target/quarkus-app/
├── quarkus-run.jar    ← entrypoint (tiny, just launches the app)
├── lib/               ← all dependency JARs (changes rarely)
├── app/               ← your application classes (changes often)
├── quarkus/           ← generated Quarkus bootstrap code
└── app.aot            ← AOT cache (when quarkus.package.jar.appcds.enabled=true)
```

This layering is **Docker cache-friendly**: only `app/` changes on most
rebuilds, so `lib/` and `quarkus/` layers are reused from cache.

## AOT Cache Progression (same property, better JDK = better cache)

| JDK | What app-cds.jsa / app.aot contains | Startup improvement |
|-----|----------------------|-------------------|
| JDK 21 | Parsed class bytes (base CDS) | 15-30% |
| JDK 24 | + Loaded & linked class state (JEP 483) | 30-40% |
| JDK 25 LTS | + JIT method profiles (JEP 515) | 40-55% |
| JDK 26 | + ZGC support (JEP 516) | 40-55% + low-latency GC |

## Reference

- Quarkus AppCDS guide: https://quarkus.io/guides/appcds
- Quarkus 3.33.1 release: https://quarkus.io/blog/quarkus-3-33-released/
- Project Leyden / Demo 04: see `../quarkus-demo-04-leyden/`
