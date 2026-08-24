# Prerequisites

Complete toolchain for Quarkus development. Install in this order.

## 1. SDKMAN

Manages JDK, Maven, JBang, and Quarkus CLI.

```bash
curl -s "https://get.sdkman.io" | bash
source "$HOME/.sdkman/bin/sdkman-init.sh"
sdk version
```

## 2. JDK 25 (Temurin)

JDK 25 Temurin for both development and compile target (`maven.compiler.release=25`).
Container images use `ubi10/openjdk-25-runtime` (OpenJDK 25.0.3 LTS, Red Hat build).

```bash
sdk install java 25-tem
java -version   # should show Temurin 25.x
```

### JVM garbage collector

The UBI 10 runtime image defaults to **G1GC**. Shenandoah is available if
lower-latency GC pauses are needed:

```bash
# Default (G1GC) — no flag needed
java -jar app.jar

# Shenandoah — lower pause times, slightly higher throughput cost
java -XX:+UseShenandoahGC -jar app.jar
```

Set in Containerfile via `JAVA_OPTS_APPEND` or in `application.properties`:

```properties
quarkus.jvm.args=-XX:+UseShenandoahGC
```

## 3. Maven 3.9

```bash
sdk install maven 3.9.9
mvn -version    # should show 3.9.9
```

## 4. JBang

Required for the Quarkus Agent MCP server and the Camel MCP server.

```bash
sdk install jbang
jbang version
```

## 5. Quarkus CLI

Installed via SDKMAN (uses JBang internally):

```bash
sdk install quarkus
quarkus version
```

### Key commands

```bash
quarkus create app com.example:my-service    # scaffold a project
quarkus ext add health opentelemetry         # add extensions
quarkus ext ls -i -s kafka                   # search available extensions
quarkus dev                                  # live coding mode
quarkus build                                # production build
quarkus image build podman                   # container image via podman
```

## 6. Podman

Container runtime for local dev infrastructure and image builds.

```bash
# Fedora / RHEL
sudo dnf install podman podman-compose

podman --version          # 4.x+
podman-compose version
```

## 7. Git

```bash
sudo dnf install git
git --version
```

## 8. Newman (optional — API testing)

Newman is the CLI runner for Postman collections.

```bash
# Requires Node.js
sudo dnf install nodejs
npm install -g newman newman-reporter-htmlextra
newman --version
```

## Verify everything

```bash
echo "=== JDK ===" && java -version 2>&1 | head -1
echo "=== Maven ===" && mvn -version 2>&1 | head -1
echo "=== JBang ===" && jbang version 2>&1 | head -1
echo "=== Quarkus ===" && quarkus version
echo "=== Podman ===" && podman --version
echo "=== Git ===" && git --version
echo "=== Newman ===" && newman --version 2>/dev/null || echo "(not installed — optional)"
```
