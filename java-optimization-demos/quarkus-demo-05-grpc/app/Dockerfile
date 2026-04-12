# Demo 05 — Quarkus gRPC + REST comparison
# Exposes both protocols from the same JVM:
#   REST: port 8080  (GET /metrics → JSON)
#   gRPC: port 9000  (MetricsService/GetJvmMetrics + StreamMetrics → Protobuf)

FROM docker.io/library/maven:3.9-eclipse-temurin-21 AS builder
WORKDIR /build
COPY pom.xml .
COPY src ./src
# generate-code goal runs protoc and generates Java stubs from metrics.proto
RUN mvn package -Dmaven.test.skip=true --no-transfer-progress

FROM registry.access.redhat.com/ubi9/openjdk-21-runtime
WORKDIR /deployments

COPY --from=builder /build/target/quarkus-app/lib/     ./lib/
COPY --from=builder /build/target/quarkus-app/*.jar    ./
COPY --from=builder /build/target/quarkus-app/app/     ./app/
COPY --from=builder /build/target/quarkus-app/quarkus/ ./quarkus/

ENV JAVA_OPTS="-XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0 -XX:+UseG1GC"
EXPOSE 8080 9000
USER 185
ENTRYPOINT ["sh", "-c", "exec java $JAVA_OPTS -jar quarkus-run.jar"]
