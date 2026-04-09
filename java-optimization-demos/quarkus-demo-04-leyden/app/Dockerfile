# ============================================================
# Demo 04: Quarkus 3.33.1 LTS + Project Leyden AOT Cache
# JDK 25 LTS — JEP 483 + JEP 514 + JEP 515
#
# HOW IT WORKS:
#   application.properties:  quarkus.package.jar.aot.enabled=true
#
#   Stage 1 — build + train:
#     ./mvnw verify
#       → builds quarkus-run.jar
#       → starts the app, runs @QuarkusIntegrationTest suite
#       → JVM records class loading + JIT profiles
#       → writes target/quarkus-app/app.aot on shutdown
#
#   Stage 2 — runtime:
#     java -XX:AOTCache=app.aot -jar quarkus-run.jar
#     Quarkus activates -XX:AOTCache automatically when app.aot
#     is present alongside quarkus-run.jar.
#
# NO MANUAL -XX:AOTCacheOutput steps in this Dockerfile.
# The quarkus-maven-plugin handles the entire training lifecycle.
# ============================================================

# ── Stage 1: Build and train ──────────────────────────────────
FROM eclipse-temurin:25-jdk AS builder
WORKDIR /build

# Cache Maven dependencies first
COPY pom.xml .
RUN --mount=type=cache,target=/root/.m2 \
    mvn dependency:go-offline -q 2>/dev/null || true

# Copy source (including the @QuarkusIntegrationTest training suite)
COPY src ./src

# Run mvn verify — this does three things:
#   1. Compiles and packages quarkus-run.jar
#   2. Starts the packaged app and runs @QuarkusIntegrationTest tests
#      (these tests ARE the AOT training workload)
#   3. Writes target/quarkus-app/app.aot and shuts down
RUN mvn verify -q && \
    echo "✅ Build + AOT training complete" && \
    ls -lh target/quarkus-app/app.aot 2>/dev/null || \
    echo "ℹ️  app.aot not found — JDK 25 required for AOT cache generation"

# ── Stage 2: Runtime image ────────────────────────────────────
FROM eclipse-temurin:25-jre
WORKDIR /deployments

# Quarkus layered output — Docker layer-cache-friendly
# lib/ changes rarely, app/ changes often
COPY --from=builder /build/target/quarkus-app/lib/     ./lib/
COPY --from=builder /build/target/quarkus-app/*.jar    ./
COPY --from=builder /build/target/quarkus-app/app/     ./app/
COPY --from=builder /build/target/quarkus-app/quarkus/ ./quarkus/

# Copy the AOT cache file (absent if JDK < 25 — Quarkus handles gracefully)
COPY --from=builder /build/target/quarkus-app/app.aot  ./app.aot 2>/dev/null || true

ENV JAVA_OPTS="-XX:+UseContainerSupport \
               -XX:MaxRAMPercentage=75.0 \
               -XX:+UseG1GC \
               -XX:MaxGCPauseMillis=200"

# Note: On JDK 26, add -XX:+UseZGC -XX:+ZGenerational (JEP 516)
# for low-latency GC AND full AOT cache support simultaneously.

EXPOSE 8080
# Quarkus detects app.aot alongside quarkus-run.jar and activates
# -XX:AOTCache=app.aot automatically. No flag needed here.
ENTRYPOINT ["sh", "-c", "exec java $JAVA_OPTS -jar quarkus-run.jar"]
