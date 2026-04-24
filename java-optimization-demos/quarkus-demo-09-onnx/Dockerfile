# Demo 09 — Quarkus + LangChain4j ONNX + Panama on JDK 25
# The all-MiniLM-L6-v2 model is bundled inside the Maven dependency.
# ONNX Runtime uses Panama FFM to call native inference kernels.
# No Python sidecar. No external model download.

FROM docker.io/library/maven:3.9-eclipse-temurin-25 AS builder
WORKDIR /build
USER root
COPY app/pom.xml .
COPY app/src ./src
RUN mvn package -Dmaven.test.skip=true --no-transfer-progress

FROM registry.access.redhat.com/ubi9/openjdk-25-runtime
WORKDIR /deployments

COPY --from=builder /build/target/quarkus-app/lib/     ./lib/
COPY --from=builder /build/target/quarkus-app/*.jar    ./
COPY --from=builder /build/target/quarkus-app/app/     ./app/
COPY --from=builder /build/target/quarkus-app/quarkus/ ./quarkus/

EXPOSE 8080
USER 185
ENTRYPOINT ["java", \
  "-XX:+UseContainerSupport", \
  "-XX:MaxRAMPercentage=75.0", \
  "-jar", "quarkus-run.jar"]
