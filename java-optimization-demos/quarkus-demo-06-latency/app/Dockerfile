# Demo 06 — Low-Latency JVM: G1GC vs ZGC
# This same Dockerfile is used for both images.
# The GC algorithm is set via JAVA_OPTS at runtime (in docker-compose.yml).
#
# G1GC image:  JAVA_OPTS="-XX:+UseG1GC ..."
# ZGC image:   JAVA_OPTS="-XX:+UseZGC -XX:+ZGenerational ..."

FROM docker.io/library/maven:3.9-eclipse-temurin-21 AS builder
WORKDIR /build
COPY pom.xml .
COPY src ./src
RUN mvn package -Dmaven.test.skip=true --no-transfer-progress

FROM registry.access.redhat.com/ubi9/openjdk-21-runtime
WORKDIR /deployments

COPY --from=builder /build/target/quarkus-app/lib/     ./lib/
COPY --from=builder /build/target/quarkus-app/*.jar    ./
COPY --from=builder /build/target/quarkus-app/app/     ./app/
COPY --from=builder /build/target/quarkus-app/quarkus/ ./quarkus/

# JAVA_OPTS is set per-container in docker-compose.yml
# Shared flags: container support, explicit thread counts, pre-touch heap
ENV JAVA_OPTS_SHARED="-XX:+UseContainerSupport \
  -XX:MaxRAMPercentage=75.0 \
  -XX:ActiveProcessorCount=2 \
  -XX:ParallelGCThreads=2 \
  -XX:ConcGCThreads=1 \
  -XX:CICompilerCount=2 \
  -XX:+AlwaysPreTouch"

EXPOSE 8080
USER 185
ENTRYPOINT ["sh", "-c", "exec java $JAVA_OPTS_SHARED $JAVA_OPTS -jar quarkus-run.jar"]
