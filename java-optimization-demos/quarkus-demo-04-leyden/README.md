# Demo 04 — Quarkus + Project Leyden AOT Cache

**Quarkus 3.33.1 LTS / JDK 25 LTS**

> Requires JDK 25+ for the Leyden AOT cache (JEP 483+514+515).
> Quarkus 3.33.1 supports Java 21+, so JDK 25 works fine.

---

## The One-Property Story

```properties
# application.properties
quarkus.package.jar.aot.enabled=true
```

```bash
# Build + train in one command
./mvnw verify
```

That's it. The Quarkus Maven plugin:
1. Packages `quarkus-run.jar` as normal
2. Starts the packaged app
3. Runs your `@QuarkusIntegrationTest` suite against it (this IS the training workload)
4. JVM records class loading, linking, and JIT method profiles
5. Writes `target/quarkus-app/app.aot` on shutdown

At runtime, Quarkus detects `app.aot` alongside `quarkus-run.jar` and activates
`-XX:AOTCache=app.aot` automatically.

**No manual `-XX:AOTCacheOutput` steps. No manual `-XX:AOTCacheOutput` in your Dockerfile.**

---

## Running the Demo

```bash
chmod +x demo.sh
./demo.sh
```

Or manually:

```bash
cd app

# Baseline — no AOT cache
./mvnw package -DskipTests -q -Dquarkus.package.jar.aot.enabled=false
time java -jar target/quarkus-app/quarkus-run.jar 2>&1 | grep "started in"

# Build with AOT cache (trains on @QuarkusIntegrationTest)
./mvnw verify
ls -lh target/quarkus-app/app.aot   # ~50-150MB

# Run with cache — Quarkus activates it automatically
time java -jar target/quarkus-app/quarkus-run.jar 2>&1 | grep "started in"
```

---

## Demo Files

| File | Purpose |
|------|---------|
| `pom.xml` | Quarkus 3.33.1 BOM, quarkus-junit5 + rest-assured for integration tests |
| `LeydenResource.java` | REST endpoints: `/startup` shows timing + AOT cache status, `/jvm/flags` shows active flags |
| `LeydenResourceIT.java` | `@QuarkusIntegrationTest` — **this is the training workload** |
| `application.properties` | `quarkus.package.jar.aot.enabled=true` |
| `Dockerfile` | 2-stage: `mvn verify` (builds + trains) then runtime image |
| `demo.sh` | Full live demo script with timing comparison |

---

## Training Quality

The better your `@QuarkusIntegrationTest` suite represents production traffic,
the more effective the AOT cache:

- Tests hit more code paths → more classes pre-linked
- JVM observes more method call patterns → better JIT profiles (JEP 515)
- Tests that exercise your hot REST endpoints are most valuable

```java
// LeydenResourceIT.java — hits the key endpoints
@QuarkusIntegrationTest   // ← NOT @QuarkusTest
class LeydenResourceIT {
    @Test void testStartupMetrics() { ... }   // trains /startup hot path
    @Test void testHealthEndpoint() { ... }   // trains health check path
}
```

---

## The AOT Cache Progression

| JDK | What you get | Cache contains |
|-----|-------------|----------------|
| JDK 21 (LTS) | AppCDS only | Parsed classes |
| JDK 24 | JEP 483 | + Loaded & linked classes |
| **JDK 25 LTS** | **JEP 514+515** | **+ JIT method profiles (warmup gone!)** |
| JDK 26 | JEP 516 | + ZGC support — low latency AND fast startup |

Same `quarkus.package.jar.aot.enabled=true` property throughout.
Better JDK = richer cache. Zero code changes.

---

## Reference

- Quarkus AOT guide: https://quarkus.io/guides/aot
- Project Leyden: https://openjdk.org/projects/leyden/
- Quarkus + Leyden: https://quarkus.io/blog/quarkus-and-leyden/
- JEP 515 (method profiling): https://openjdk.org/jeps/515
