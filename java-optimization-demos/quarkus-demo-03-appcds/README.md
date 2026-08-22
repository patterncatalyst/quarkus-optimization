# Quarkus Demo 03 — AppCDS Startup Acceleration

## Framework
**Quarkus 3.33.1 LTS** / JDK 25 (released March 25, 2026)

## The Story

Quarkus is already **5-10x faster** to start than Spring Boot thanks to
build-time processing. Because Quarkus has *already* moved class-loading and
metadata work to build time, **AppCDS adds essentially nothing on Quarkus** —
measured startup is flat, within measurement noise (baseline ~485 ms vs
AppCDS ~493 ms on JDK 25). **That is the point of this demo:** the AppCDS
technique that meaningfully speeds up Spring Boot (~40% faster) has very
little left to optimize once Quarkus has done its build-time work.

Real startup gains on Quarkus come from the full **Leyden AOT cache on JDK 25**
(JEP 483 + JEP 515), which also caches linked class state and JIT method
profiles — see Demo 04 (~75% faster).

| Mode | Typical Startup | Notes |
|------|----------------|-------|
| Spring Boot 4.0.5 (baseline) | ~4000-8000 ms | Framework scanning at runtime |
| Spring Boot 4.0.5 + AppCDS | ~40% faster | AppCDS caches the runtime scanning work |
| Quarkus 3.33.1 (JVM, no AppCDS) | ~485 ms | Build-time processing |
| Quarkus 3.33.1 + AppCDS (JDK 25) | ~493 ms | **~flat — within measurement noise** |
| Quarkus 3.33.1 + Leyden AOT (JDK 25) | ~75% faster | JEP 483 + 515 — Demo 04 |
| Quarkus 3.33.1 Native (GraalVM) | ~10-50 ms | Static binary, no JVM |

**Why is AppCDS ~flat on Quarkus?** AppCDS caches parsed class bytes so the
JVM can skip re-parsing them at startup. But Quarkus already does its heavy
lifting at build time, so there is little class-loading work left for AppCDS
to remove. The full Leyden AOT cache (JDK 25, JEP 483+515) also caches
linked class state and JIT method profiles — *that* is where Quarkus's real
startup gains come from. Quarkus uses the same single property for both; the
JDK version determines which tier of cache is generated.

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

Or pass it at build time without touching application.properties:

```bash
mvn package -DskipTests -Dquarkus.package.jar.aot.enabled=true
```

The `quarkus-maven-plugin` automatically:
1. Runs the application for a training pass
2. Captures the loaded class list
3. Generates the AppCDS archive (`app-cds.jsa`)
4. Bundles it with `quarkus-run.jar`

No `-Xshare:off`, no `-Xshare:dump`, no manual archive management.

## Prerequisites

- **Podman** 4.x+ (`dnf install podman` / `brew install podman`)
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
podman build -f Dockerfile.baseline -t quarkus-startup:baseline .
podman build -f Dockerfile.appcds   -t quarkus-startup:appcds   .
# Note: Dockerfile.appcds generates the AppCDS archive in a dedicated build
# stage using -XX:ArchiveClassesAtExit=app-cds.jsa (a training run), then the
# runtime stage consumes it with -XX:SharedArchiveFile=app-cds.jsa.

# Measure startup — use detached + poll approach (podman run hangs on Linux
# because the Quarkus server runs indefinitely)
for image in quarkus-startup:baseline quarkus-startup:appcds; do
  cid=$(podman run -d --memory=512m $image)
  sleep 1
  echo "$image:"
  podman logs $cid 2>&1 | grep "started in"
  podman stop $cid && podman rm $cid
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
└── app-cds.jsa        ← AppCDS archive (when quarkus.package.jar.aot.enabled=true)
```

This layering is **container-image-layer cache-friendly**: only `app/` changes
on most rebuilds, so `lib/` and `quarkus/` layers are reused from cache.

## AOT Cache Progression (same property, better JDK = better cache)

*The improvement column reflects the honest picture on **Quarkus**: base
AppCDS (JDK 21 tier) is ~flat because Quarkus already front-loads class work
at build time; the gains appear only once the Leyden AOT tiers (JEP 483/515)
cache linked class state and JIT profiles.*

| JDK | What `app-cds.jsa` contains | Startup improvement on Quarkus |
|-----|----------------------|-------------------|
| JDK 21 | Parsed class bytes (base CDS) | ~flat — within measurement noise |
| JDK 24 | + Loaded & linked class state (JEP 483) | gains begin |
| JDK 25 LTS | + JIT method profiles (JEP 515) | ~75% faster — full Leyden AOT (Demo 04) |
| JDK 26 | + ZGC support (JEP 516) | Leyden AOT + low-latency GC |

## Reference

- Quarkus AppCDS guide: https://quarkus.io/guides/appcds
- Quarkus 3.33.1 release: https://quarkus.io/blog/quarkus-3-33-released/
- Project Leyden / Demo 04: see `../quarkus-demo-04-leyden/`
