# Demo 08 — Panama FFM: C++20 native library + Quarkus on JDK 25
#
# Three stages:
#   1. cpp-builder   — compile the C++20 shared library on UBI9
#   2. java-builder  — build the Quarkus app with maven + JDK 25
#   3. runtime       — UBI9 OpenJDK 25 runtime with both artifacts

# ── Stage 1: C++20 shared library ─────────────────────────────────────────────
# ubi9 base image — gcc-c++ and cmake are in the freely accessible UBI repos
# (ubi-9-appstream, ubi-9-baseos) — no subscription required
FROM registry.access.redhat.com/ubi9 AS cpp-builder

RUN dnf install -y gcc-c++ cmake make && \
    dnf clean all

WORKDIR /build
COPY native .
RUN cmake -S . -B build -DCMAKE_BUILD_TYPE=Release && \
    cmake --build build --parallel && \
    cmake --install build --prefix /install

# ── Stage 2: Quarkus Java app ──────────────────────────────────────────────────
FROM docker.io/library/maven:3.9-eclipse-temurin-25 AS java-builder
WORKDIR /build
USER root

COPY app/pom.xml .
COPY app/src ./src
RUN mvn package -Dmaven.test.skip=true --no-transfer-progress

# ── Stage 3: Runtime ───────────────────────────────────────────────────────────
FROM registry.access.redhat.com/ubi9/openjdk-25-runtime
WORKDIR /deployments

# Copy native library into a standard path
COPY --from=cpp-builder /install/lib/libjvmstats.so /usr/local/lib/libjvmstats.so

# Refresh dynamic linker cache so SymbolLookup can find libjvmstats.so
USER root
RUN echo "/usr/local/lib" > /etc/ld.so.conf.d/jvmstats.conf && ldconfig
USER 185

COPY --from=java-builder /build/target/quarkus-app/lib/     ./lib/
COPY --from=java-builder /build/target/quarkus-app/*.jar    ./
COPY --from=java-builder /build/target/quarkus-app/app/     ./app/
COPY --from=java-builder /build/target/quarkus-app/quarkus/ ./quarkus/

EXPOSE 8080
ENTRYPOINT ["java", \
  "-XX:+UseContainerSupport", \
  "-XX:MaxRAMPercentage=75.0", \
  "-jar", "quarkus-run.jar"]
