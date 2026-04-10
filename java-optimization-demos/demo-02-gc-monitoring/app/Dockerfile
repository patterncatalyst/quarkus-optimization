# ============================================================
# Demo 02 — Quarkus 3.33.1 LTS / Java 21 — JVM mode
#
# Quarkus produces a layered JAR structure in target/quarkus-app/
#   quarkus-app/quarkus-run.jar   ← entrypoint
#   quarkus-app/lib/              ← dependency JARs
#   quarkus-app/app/              ← application classes
#   quarkus-app/quarkus/          ← generated Quarkus bootstrap
# ============================================================

# ── Stage 1: Build ─────────────────────────────────────────
FROM docker.io/library/maven:3.9-eclipse-temurin-21 AS builder
WORKDIR /build

COPY pom.xml .

COPY src ./src
RUN     mvn package -Dmaven.test.skip=true --no-transfer-progress

# ── Stage 2: Runtime ───────────────────────────────────────
FROM registry.access.redhat.com/ubi9/openjdk-21-runtime
WORKDIR /deployments

# Quarkus layered structure — copy each layer separately for optimal
# Docker layer caching (lib changes less often than app/)
COPY --from=builder /build/target/quarkus-app/lib/     ./lib/
COPY --from=builder /build/target/quarkus-app/*.jar    ./
COPY --from=builder /build/target/quarkus-app/app/     ./app/
COPY --from=builder /build/target/quarkus-app/quarkus/ ./quarkus/

# GC type selection (g1gc | zgc | shenandoah)
ENV GC_TYPE=g1gc

# Container-aware heap settings — UseContainerSupport is ON by default in Java 21
ENV HEAP_OPTS="-XX:+UseContainerSupport \
               -XX:MaxRAMPercentage=75.0 \
               -XX:InitialRAMPercentage=50.0"

ENV JAVA_OPTS=""

EXPOSE 8080

ENTRYPOINT ["sh", "-c", "\
  if [ \"$GC_TYPE\" = 'zgc' ]; then \
    GC_FLAG='-XX:+UseZGC -XX:+ZGenerational'; \
  elif [ \"$GC_TYPE\" = 'shenandoah' ]; then \
    GC_FLAG='-XX:+UseShenandoahGC -XX:ShenandoahGCMode=adaptive'; \
  else \
    GC_FLAG='-XX:+UseG1GC -XX:MaxGCPauseMillis=200 -XX:G1HeapRegionSize=4m \
             -XX:ParallelGCThreads=2 -XX:InitiatingHeapOccupancyPercent=45'; \
  fi; \
  exec java $HEAP_OPTS $GC_FLAG $JAVA_OPTS -jar quarkus-run.jar"]
