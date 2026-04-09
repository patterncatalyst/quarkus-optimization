# ============================================================
# Demo 02 — GC Monitoring with Prometheus (Spring Boot 4.0.5)
# Multi-stage build: Maven build → slim JRE runtime image
# ============================================================

# Stage 1: Build with Maven
FROM eclipse-temurin:21-jdk AS builder
WORKDIR /build

# Copy pom first to cache Maven dependencies layer
COPY pom.xml .
RUN --mount=type=cache,target=/root/.m2 \
    mvn dependency:go-offline -q 2>/dev/null || \
    mvn dependency:resolve -q 2>/dev/null || true

COPY src ./src
RUN mvn package -DskipTests -q

# Stage 2: Minimal runtime image
FROM eclipse-temurin:21-jre
WORKDIR /app

COPY --from=builder /build/target/gc-monitoring-*.jar app.jar

# ── GC Configuration (switchable via environment variable) ──
# Default: G1GC (change GC_TYPE=zgc or GC_TYPE=shenandoah to switch)
ENV GC_TYPE=g1gc
ENV JAVA_OPTS=""

# Container-aware heap settings
ENV HEAP_OPTS="-XX:+UseContainerSupport \
               -XX:MaxRAMPercentage=75.0 \
               -XX:InitialRAMPercentage=50.0"

# GC logging for visibility
ENV GC_LOG_OPTS="-Xlog:gc*:file=/tmp/gc.log:time,uptime,level,tags:filecount=3,filesize=10m"

EXPOSE 8080

ENTRYPOINT ["sh", "-c", "\
  if [ \"$GC_TYPE\" = 'zgc' ]; then \
    GC_FLAG='-XX:+UseZGC -XX:+ZGenerational'; \
  elif [ \"$GC_TYPE\" = 'shenandoah' ]; then \
    GC_FLAG='-XX:+UseShenandoahGC -XX:ShenandoahGCMode=adaptive'; \
  else \
    GC_FLAG='-XX:+UseG1GC -XX:MaxGCPauseMillis=200 -XX:G1HeapRegionSize=4m'; \
  fi; \
  exec java $HEAP_OPTS $GC_FLAG $GC_LOG_OPTS $JAVA_OPTS -jar app.jar"]
