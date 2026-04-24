# Demo Prerequisites — Installation Guide

Tools required to run all nine demos in this repository, with install
instructions for **Fedora Linux** and **macOS**. Each tool lists which
demos need it so you can install only what you need for a given session.

---

## Quick-Install Summary

### Fedora

```bash
# Core tools (required for all demos)
sudo dnf install -y podman git python3

# podman-compose (Demo 02 only)
pip install podman-compose --user

# SDKMAN + JDK 21 and JDK 25 (local dev / Demo 04, 08, 09)
curl -s "https://get.sdkman.io" | bash
source "$HOME/.sdkman/bin/sdkman-init.sh"
sdk install java 21.0.10-tem
sdk install java 25.0.1-tem

# Load testing (Demo 05, 06)
# hey — download binary from GitHub releases
curl -fsSL https://hey-release.s3.us-east-2.amazonaws.com/hey_linux_amd64 \
  -o /usr/local/bin/hey && chmod +x /usr/local/bin/hey

# gRPC tools (Demo 05)
# grpcurl
curl -fsSL https://github.com/fullstorydev/grpcurl/releases/latest/download/grpcurl_Linux_x86_64.tar.gz \
  | tar -xz -C /usr/local/bin grpcurl

# ghz
curl -fsSL https://github.com/bojand/ghz/releases/latest/download/ghz_linux_x86_64.tar.gz \
  | tar -xz -C /usr/local/bin ghz
```

### macOS

```bash
# Install Homebrew if not already installed
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Core tools
brew install podman git python3

# Initialize Podman VM (macOS requires a Linux VM)
podman machine init --memory 8192 --cpus 4 --disk-size 60
podman machine start

# podman-compose (Demo 02 only)
pip3 install podman-compose

# SDKMAN + JDK 21 and JDK 25
curl -s "https://get.sdkman.io" | bash
source "$HOME/.sdkman/bin/sdkman-init.sh"
sdk install java 21.0.10-tem
sdk install java 25.0.1-tem

# Load testing + gRPC (Demo 05, 06)
brew install hey grpcurl ghz
```

---

## Tools by Demo

| Tool | Demo 01 | Demo 02 | Demo 03 | Demo 04 | Demo 05 | Demo 06 | Demo 07 | Demo 08 | Demo 09 |
|------|---------|---------|---------|---------|---------|---------|---------|---------|---------|
| podman | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | — | ✅ | ✅ |
| podman-compose | — | ✅ | — | — | — | ✅ | — | — | — |
| JDK 21 | local dev | local dev | local dev | — | local dev | local dev | — | — | — |
| JDK 25 | — | — | — | ✅ | — | — | — | ✅ | ✅ |
| python3 | — | — | — | — | — | — | ✅ | — | — |
| hey | — | — | — | — | ✅ | ✅ | — | — | — |
| grpcurl | — | — | — | — | ✅ | — | — | — | — |
| ghz | — | — | — | — | ✅ | — | — | — | — |
| git | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |

> **Note:** Demos 01-09 build their own JDK inside the container via UBI images —
> a local JDK is only needed if you want to run Quarkus in dev mode locally.
> Demos 04, 08, and 09 require JDK 25 images which are pulled automatically
> by Podman during the build.

---

## Detailed Installation

---

### git

**Required for:** All demos (cloning the repo)

**Fedora:**
```bash
sudo dnf install -y git
git --version
```

**macOS:**
```bash
# Included with Xcode Command Line Tools
xcode-select --install
# Or via Homebrew
brew install git
git --version
```

---

### Podman

**Required for:** Demos 01, 02, 03, 04, 05, 06, 08, 09

Podman is a daemonless container runtime. On Fedora it runs natively (rootless,
no daemon). On macOS it runs a Linux VM via `podman machine`.

#### Fedora

```bash
sudo dnf install -y podman
podman --version          # should show 4.x or 5.x

# Verify rootless works
podman run --rm docker.io/library/hello-world
```

**Fedora-specific notes:**

- Podman on Fedora/RHEL runs **rootless by default** — containers run as your
  user UID inside a user namespace. This is more secure than Docker's daemon model.
- **SELinux is enforced.** All bind-mounted config files in docker-compose must
  use the `:Z` relabel option or the container cannot read them (no error message).
  The demos already include `:Z` where needed.
- **Image names must be fully qualified.** Podman has no default registry —
  `prom/prometheus` will prompt you to choose a registry interactively (which
  hangs in scripts). Always use `docker.io/prom/prometheus`.
- **Named volumes** are created owned by root in rootless Podman. Non-root
  container processes (like Prometheus uid 65534) cannot write to them.
  Demo 02 uses `tmpfs` + `user: root` for Prometheus storage to avoid this.

#### macOS

```bash
brew install podman

# Podman on macOS requires a Linux VM
# 8GB RAM and 4 CPUs recommended for running multiple demo containers
podman machine init --memory 8192 --cpus 4 --disk-size 60
podman machine start

# Verify
podman run --rm docker.io/library/hello-world
podman machine list
```

**macOS-specific notes:**

- The Podman VM runs a stripped Fedora CoreOS image. Start it once after reboot:
  `podman machine start`
- To auto-start the VM at login:
  `podman machine set --rootful`  (optional, some tools work better with rootful VM)
- If you have Docker Desktop installed, set Podman as the default socket:
  `export DOCKER_HOST=unix://$HOME/.local/share/containers/podman/machine/qemu/podman.sock`
- Volumes on macOS are bind-mounted through the VM — performance is slower than
  on Linux but acceptable for demos.

**Verify Podman works:**
```bash
podman info | grep -E "version|os|arch"
podman run --rm docker.io/library/alpine echo "Podman is working"
```

---

### podman-compose

**Required for:** Demo 02 (GC monitoring stack), Demo 06 (latency stack)

podman-compose is a Python implementation of docker-compose that uses Podman
as the container backend.

#### Fedora

```bash
# Option 1: DNF (recommended — gets OS-packaged version)
sudo dnf install -y podman-compose
podman-compose --version

# Option 2: pip (gets latest PyPI version)
pip install podman-compose --user
# Add ~/.local/bin to PATH if not already there:
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

#### macOS

```bash
pip3 install podman-compose

# Verify
podman-compose --version
```

**Known issue — Python 3.14 async compatibility:** If you see a `SyntaxError`
or async-related traceback with newer Python versions, downgrade or pin
podman-compose to a compatible version:
```bash
pip install "podman-compose==1.2.0"
```

**Verify podman-compose works:**
```bash
cd quarkus-demo-02-gc-monitoring
podman-compose --version
# Should print version without error
```

---

### SDKMAN (JDK version manager)

**Required for:** Local JDK 21 (dev mode) + JDK 25 (Demos 04, 08, 09)

SDKMAN manages multiple JDK versions and switches between them seamlessly.
The repo includes a `.sdkmanrc` file that pins `java=21.0.10-tem` automatically.

#### Fedora

```bash
# Install SDKMAN
curl -s "https://get.sdkman.io" | bash

# Activate in current shell
source "$HOME/.sdkman/bin/sdkman-init.sh"

# Add to shell profile (pick your shell)
echo 'source "$HOME/.sdkman/bin/sdkman-init.sh"' >> ~/.bashrc    # bash
echo 'source "$HOME/.sdkman/bin/sdkman-init.sh"' >> ~/.zshrc     # zsh

# Install JDK 21 (Eclipse Temurin — matches .sdkmanrc)
sdk install java 21.0.10-tem
sdk default java 21.0.10-tem

# Install JDK 25 (for Demos 04, 08, 09)
sdk install java 25.0.1-tem

# Verify
java -version          # should show 21.x.x with Temurin
sdk list java | grep installed
```

#### macOS

```bash
# Install SDKMAN
curl -s "https://get.sdkman.io" | bash
source "$HOME/.sdkman/bin/sdkman-init.sh"

# Install JDKs
sdk install java 21.0.10-tem
sdk default java 21.0.10-tem
sdk install java 25.0.1-tem

# Verify
java -version
```

**Using .sdkmanrc (automatic version switching):**
```bash
# From the repo root — activates the pinned JDK automatically
cd quarkus-optimization
sdk env          # reads .sdkmanrc, switches to java=21.0.10-tem

# For demos requiring JDK 25
sdk use java 25.0.1-tem
```

**Switch between versions:**
```bash
sdk use java 21.0.10-tem     # switch to JDK 21 for current shell
sdk use java 25.0.1-tem      # switch to JDK 25
sdk current java              # show active version
```

**Alternative — direct download (without SDKMAN):**

Eclipse Temurin builds: https://adoptium.net/temurin/releases/

---

### Python 3

**Required for:** Demo 07 (right-sizing analysis — stdlib only, no pip installs)

#### Fedora

```bash
# Python 3 is usually pre-installed on Fedora
python3 --version

# If not installed:
sudo dnf install -y python3
```

#### macOS

```bash
# macOS ships Python 3 (Xcode CLT) — verify version
python3 --version

# Or install a newer version via Homebrew
brew install python3
python3 --version
```

**Demo 07 uses stdlib only** — no `pip install` needed. Just `python3 analyze.py`.

---

### hey — HTTP load tester

**Required for:** Demo 05 (REST vs gRPC load comparison), Demo 06 (latency comparison)

hey is a fast HTTP load generator written in Go. Used to benchmark REST endpoints
and compare throughput with `ghz` for gRPC.

#### Fedora

```bash
# Download binary (no Fedora package available)
curl -fsSL \
  https://hey-release.s3.us-east-2.amazonaws.com/hey_linux_amd64 \
  -o /tmp/hey && chmod +x /tmp/hey && sudo mv /tmp/hey /usr/local/bin/hey

# Verify
hey --version
# or
hey -n 1 -c 1 http://httpbin.org/get 2>&1 | head -5
```

**ARM64 (Fedora on Apple Silicon VM or ARM server):**
```bash
curl -fsSL \
  https://hey-release.s3.us-east-2.amazonaws.com/hey_linux_arm64 \
  -o /tmp/hey && chmod +x /tmp/hey && sudo mv /tmp/hey /usr/local/bin/hey
```

#### macOS

```bash
brew install hey
hey --version
```

**Basic usage reference:**
```bash
# 10,000 requests, 50 concurrent workers
hey -n 10000 -c 50 http://localhost:8080/metrics

# Duration-based (30 seconds, 10 workers)
hey -z 30s -c 10 http://localhost:8080/metrics

# Output includes: requests/sec, average, P50, P95, P99
```

---

### grpcurl — gRPC CLI client

**Required for:** Demo 05 (gRPC endpoint testing and streaming demo)

grpcurl is the `curl` for gRPC — calls gRPC endpoints from the command line
without generating stubs.

#### Fedora

```bash
# Download binary from GitHub releases
GRPCURL_VERSION=$(curl -s https://api.github.com/repos/fullstorydev/grpcurl/releases/latest \
  | grep '"tag_name"' | sed -E 's/.*"v([^"]+)".*/\1/')

curl -fsSL \
  "https://github.com/fullstorydev/grpcurl/releases/latest/download/grpcurl_${GRPCURL_VERSION}_linux_x86_64.tar.gz" \
  | tar -xz -C /tmp grpcurl && sudo mv /tmp/grpcurl /usr/local/bin/

# Verify
grpcurl --version
```

**ARM64:**
```bash
curl -fsSL \
  "https://github.com/fullstorydev/grpcurl/releases/latest/download/grpcurl_${GRPCURL_VERSION}_linux_arm64.tar.gz" \
  | tar -xz -C /tmp grpcurl && sudo mv /tmp/grpcurl /usr/local/bin/
```

#### macOS

```bash
brew install grpcurl
grpcurl --version
```

**Basic usage reference:**
```bash
# List services (requires reflection enabled on server)
grpcurl -plaintext localhost:9000 list

# Call a unary method
grpcurl -plaintext -d '{"host":"localhost"}' \
  localhost:9000 MetricsService/GetJvmMetrics

# Server streaming (receives until Ctrl+C)
grpcurl -plaintext -d '{"host":"localhost","count":0}' \
  localhost:9000 MetricsService/StreamMetrics

# Benchmark mode (receive N messages then stop)
grpcurl -plaintext -d '{"host":"localhost","count":1000}' \
  localhost:9000 MetricsService/StreamMetrics
```

---

### ghz — gRPC load tester

**Required for:** Demo 05 (gRPC throughput benchmarking vs REST `hey`)

ghz is the gRPC equivalent of `hey` — runs load tests against gRPC endpoints
and reports throughput, latency percentiles, and error rates.

#### Fedora

```bash
# Download binary from GitHub releases
curl -fsSL \
  https://github.com/bojand/ghz/releases/latest/download/ghz_linux_x86_64.tar.gz \
  | tar -xz -C /tmp && sudo mv /tmp/ghz /usr/local/bin/

# Verify
ghz --version
```

**ARM64:**
```bash
curl -fsSL \
  https://github.com/bojand/ghz/releases/latest/download/ghz_linux_arm64.tar.gz \
  | tar -xz -C /tmp && sudo mv /tmp/ghz /usr/local/bin/
```

#### macOS

```bash
brew install ghz
ghz --version
```

**Basic usage reference:**
```bash
# 10,000 requests, 50 concurrent workers, proto file required
ghz --insecure \
    --proto app/src/main/proto/metrics.proto \
    --call MetricsService/GetJvmMetrics \
    -d '{"host":"localhost"}' \
    -n 10000 -c 50 \
    localhost:9000

# Output includes: requests/sec, p50, p99, status code distribution
```

---

### curl and python3 (standard CLI tools)

**Required for:** All demos (health checks, generating load, parsing JSON output)

Both are pre-installed on Fedora and macOS. Verify they're available:

```bash
curl --version | head -1
python3 --version
```

If `python3 -m json.tool` is unavailable (rare), install:
```bash
# Fedora
sudo dnf install -y python3

# macOS — already included, or:
brew install python3
```

---

## Podman Image Pre-Pull (Optional but Recommended)

Pre-pulling large images before the demo avoids network delays on stage:

```bash
# Core images used across all demos
podman pull docker.io/library/maven:3.9-eclipse-temurin-21
podman pull docker.io/library/maven:3.9-eclipse-temurin-25
podman pull registry.access.redhat.com/ubi9/openjdk-21-runtime
podman pull registry.access.redhat.com/ubi9/openjdk-25-runtime

# Demo 02 observability stack
podman pull docker.io/grafana/otel-lgtm:0.8.1
podman pull docker.io/prom/prometheus:v3.2.1

# Demo 09 (large — ONNX Runtime + model ~300MB Maven download during build)
# Pre-build the image instead of pre-pulling
cd quarkus-demo-09-onnx && podman build -t quarkus-onnx-demo:latest .

# Verify pulled images
podman images | grep -E "maven|openjdk|grafana|prometheus"
```

---

## Verify Your Setup

Run this script to check all tools are installed and at the correct versions:

```bash
#!/usr/bin/env bash
# Save as check-setup.sh and run: bash check-setup.sh

PASS=0; FAIL=0
check() {
  local name=$1 cmd=$2 min=$3
  if result=$(eval "$cmd" 2>&1 | head -1); then
    echo "✅ $name: $result"
    ((PASS++))
  else
    echo "❌ $name: not found"
    ((FAIL++))
  fi
}

echo "=== Demo Prerequisites Check ==="
echo

check "git"           "git --version"
check "podman"        "podman --version"
check "podman-compose" "podman-compose --version"
check "python3"       "python3 --version"
check "java (active)" "java -version 2>&1 | head -1"
check "hey"           "hey --version 2>&1 || echo 'not installed (Demo 05/06 only)'"
check "grpcurl"       "grpcurl --version 2>&1 | head -1 || echo 'not installed (Demo 05 only)'"
check "ghz"           "ghz --version 2>&1 | head -1 || echo 'not installed (Demo 05 only)'"
check "curl"          "curl --version | head -1"

echo
echo "=== JDK Versions (SDKMAN) ==="
if command -v sdk &>/dev/null; then
  sdk list java | grep " installed" | grep -E "21|25"
else
  echo "SDKMAN not found — install from https://sdkman.io"
fi

echo
echo "=== Podman Machine (macOS only) ==="
if [[ "$OSTYPE" == "darwin"* ]]; then
  podman machine list 2>/dev/null || echo "No Podman machine found — run: podman machine init && podman machine start"
fi

echo
echo "=== Result: $PASS passed, $FAIL failed ==="
```

---

## Platform-Specific Notes

### Fedora — SELinux and Podman Rootless

Fedora enforces SELinux by default. Two rules to remember for all demos:

**Rule 1 — Bind mounts need `:Z`:**
```yaml
# Without :Z — SELinux silently blocks read access (no error in logs)
volumes:
  - ./prometheus.yml:/etc/prometheus/prometheus.yml:ro    # ❌

# With :Z — SELinux relabels the file for the container's context
volumes:
  - ./prometheus.yml:/etc/prometheus/prometheus.yml:Z     # ✅
```

All demo `docker-compose.yml` files already include `:Z` where needed.

**Rule 2 — Named volumes are root-owned:**

In rootless Podman, named volumes are created owned by root. Processes running
as non-root inside the container (Prometheus uid 65534, Grafana uid 472) cannot
write to them. Demo 02 uses `tmpfs` + `user: root` for Prometheus storage.

**Verify SELinux mode:**
```bash
getenforce        # should show Enforcing
sestatus          # full status
```

**If demos fail with permission errors, check:**
```bash
# Check if SELinux is denying access
sudo ausearch -m avc -ts recent | tail -20
# Or check journal
journalctl -t setroubleshoot --since "10 minutes ago"
```

---

### macOS — Podman Machine

macOS uses a Linux VM to run containers. The VM must be running before any
demo that uses Podman:

```bash
# Start VM (required after every reboot)
podman machine start

# Check VM status
podman machine list

# If VM is out of resources, increase allocation
podman machine stop
podman machine set --memory 8192 --cpus 4
podman machine start
```

**Memory allocation for demos:**

| Demo | RAM needed | Why |
|------|-----------|-----|
| Demo 01 | 256MB | Single container |
| Demo 02 | 3GB | Grafana LGTM + 2 Quarkus apps + Prometheus |
| Demo 03 | 512MB | Build + run |
| Demo 04 | 1GB | JDK 25 + Maven build |
| Demo 05 | 512MB | Single gRPC + REST app |
| Demo 06 | 1.5GB | Two Quarkus apps + Prometheus |
| Demo 07 | 0 | Python only — no containers |
| Demo 08 | 1GB | C++ build + Quarkus on JDK 25 |
| Demo 09 | 2GB | ONNX Runtime + MiniLM model |

Recommended Podman machine: `--memory 8192 --cpus 4` covers all demos simultaneously.

**Socket path for Docker-compatible tools:**
```bash
# If any tool expects DOCKER_HOST:
export DOCKER_HOST="unix://$HOME/.local/share/containers/podman/machine/qemu/podman.sock"
# Or on newer Podman:
export DOCKER_HOST=$(podman machine inspect --format '{{.ConnectionInfo.PodmanSocket.Path}}')
```

---

## Uninstall / Cleanup

```bash
# Remove pulled images (Fedora and macOS)
podman rmi docker.io/library/maven:3.9-eclipse-temurin-21
podman rmi docker.io/library/maven:3.9-eclipse-temurin-25
podman rmi registry.access.redhat.com/ubi9/openjdk-21-runtime
podman rmi registry.access.redhat.com/ubi9/openjdk-25-runtime
podman rmi docker.io/grafana/otel-lgtm:0.8.1
podman rmi docker.io/prom/prometheus:v3.2.1

# Remove all demo images at once
podman rmi $(podman images --filter "label=demo" -q) 2>/dev/null

# Stop and remove Podman machine (macOS)
podman machine stop
podman machine rm

# Remove demo-created volumes
podman volume prune

# Uninstall SDKMAN JDK versions
sdk uninstall java 21.0.10-tem
sdk uninstall java 25.0.1-tem
```

---

## Minimum vs Full Install

### Minimum (Demo 01, 02, 03 only — 60-minute core talk)

```bash
# Fedora
sudo dnf install -y podman git python3
pip install podman-compose --user
sdk install java 21.0.10-tem   # optional — containers bring their own JDK

# macOS
brew install podman && podman machine init --memory 6144 --cpus 2 && podman machine start
brew install git python3
pip3 install podman-compose
sdk install java 21.0.10-tem   # optional
```

### Full (All 9 demos — extended / 90-minute session)

```bash
# Fedora
sudo dnf install -y podman git python3
pip install podman-compose --user
sdk install java 21.0.10-tem
sdk install java 25.0.1-tem
curl -fsSL https://hey-release.s3.us-east-2.amazonaws.com/hey_linux_amd64 \
  -o /usr/local/bin/hey && chmod +x /usr/local/bin/hey
curl -fsSL https://github.com/fullstorydev/grpcurl/releases/latest/download/grpcurl_Linux_x86_64.tar.gz \
  | tar -xz -C /usr/local/bin grpcurl
curl -fsSL https://github.com/bojand/ghz/releases/latest/download/ghz_linux_x86_64.tar.gz \
  | tar -xz -C /tmp && sudo mv /tmp/ghz /usr/local/bin/

# macOS
brew install podman git python3 hey grpcurl ghz
podman machine init --memory 8192 --cpus 4 --disk-size 60
podman machine start
pip3 install podman-compose
sdk install java 21.0.10-tem
sdk install java 25.0.1-tem
```

---

## Reference Links

| Tool | Official Source |
|------|----------------|
| Podman | https://podman.io/docs/installation |
| podman-compose | https://github.com/containers/podman-compose |
| SDKMAN | https://sdkman.io |
| Eclipse Temurin JDK | https://adoptium.net/temurin/releases/ |
| hey | https://github.com/rakyll/hey |
| grpcurl | https://github.com/fullstorydev/grpcurl |
| ghz | https://ghz.sh |
| Homebrew | https://brew.sh |
