#!/usr/bin/env bash
# ── Master Demo Runner ────────────────────────────────────────────────────────
# Taming the JVM — Optimizing Java Workloads on OpenShift & Kubernetes
# Runs the nine demos in sequence with section callouts, Enter-to-continue waits,
# and Grafana pointers. Each demo has its own self-contained demo.sh (builds,
# runs, and — for the observability stacks — tears itself down at the end).
#
# Runtime: Quarkus 3.33.1 LTS on JDK 25 / UBI 10, Podman (rootless).
#
# Usage:
#   ./run-all-demos.sh              # run all demos in order
#   ./run-all-demos.sh --from 5     # resume from demo 5
#   ./run-all-demos.sh --only 6     # run just demo 6
#   ./run-all-demos.sh --list       # list demos and exit
#   ./run-all-demos.sh --no-spring  # skip the Spring Boot AppCDS comparison (3b)
#   ./run-all-demos.sh --prebuild   # pull bases + build all images up front, then exit
#                                   # (run this BEFORE the talk so the live run skips builds)
# ──────────────────────────────────────────────────────────────────────────────
set -uo pipefail

DEMOS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GREEN='\033[0;32m'; CYAN='\033[0;36m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; RED='\033[0;31m'; BOLD='\033[1m'; RESET='\033[0m'

banner() {
    echo -e "\n${GREEN}════════════════════════════════════════════════════════════════${RESET}"
    echo -e "${GREEN}${BOLD}  $*${RESET}"
    echo -e "${GREEN}════════════════════════════════════════════════════════════════${RESET}"
}
info()    { echo -e "  ${CYAN}$*${RESET}"; }
warn()    { echo -e "  ${YELLOW}⚠  $*${RESET}"; }
grafana() { echo -e "  ${BLUE}📊 $*${RESET}"; }
pause()   { read -rp "$(echo -e "  ${YELLOW}▶ $*${RESET}")"; }

# ── Args ──────────────────────────────────────────────────────────────────────
FROM=1; ONLY=""; RUN_SPRING=1; PREBUILD=0
while [ $# -gt 0 ]; do
    case "$1" in
        --from)  FROM="${2:-1}"; shift 2 ;;
        --only)  ONLY="${2:-}"; shift 2 ;;
        --no-spring) RUN_SPRING=0; shift ;;
        --prebuild) PREBUILD=1; shift ;;
        --list)  LIST=1; shift ;;
        -h|--help) grep -E '^#( |$)' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "unknown arg: $1"; exit 1 ;;
    esac
done

# ── Demo registry: "num|dir|title|extra-args" ─────────────────────────────────
DEMOS=(
  "1|demo-01-heap-sizing|Container-Aware Heap Sizing — UseContainerSupport + MaxRAMPercentage|"
  "2|quarkus-demo-02-gc-monitoring|GC Monitoring — Grafana LGTM (Prometheus + Tempo)|"
  "3|quarkus-demo-03-appcds|AppCDS / AOT Cache Startup (Quarkus)|"
  "3b|demo-03-appcds|AppCDS Startup — Spring Boot comparison|"
  "4|quarkus-demo-04-leyden|Project Leyden AOT Cache (JDK 25)|"
  "5|quarkus-demo-05-grpc|REST vs gRPC — same service, two protocols|"
  "6|quarkus-demo-06-latency|Low-Latency JVM — G1GC vs ZGC pause delta|"
  "7|quarkus-demo-07-rightsizing|Right-Sizing & Cost Impact|"
  "8|quarkus-demo-08-panama|Project Panama — C++ via the FFM API (JDK 25)|"
  "9|quarkus-demo-09-onnx|AI Inference — LangChain4j + ONNX + Panama (JDK 25)|"
)

if [ -n "${LIST:-}" ]; then
    echo -e "${BOLD}Demos:${RESET}"
    for d in "${DEMOS[@]}"; do IFS='|' read -r n dir title _ <<< "$d"; printf "  %-3s %s\n" "$n" "$title"; done
    exit 0
fi

# ── Pre-build / warm mode ─────────────────────────────────────────────────────
# Front-loads the slow work (base-image pulls + all demo image builds) so the
# live run hits cache and skips builds. Run it before the talk.
prebuild() {
    banner "Pre-build / warm — pull base images + build all demo images"
    warn "Run this BEFORE the talk; the live run then skips builds."
    warn "Demo 04 (Leyden) rebuilds at runtime by design (--no-cache); demo 07 needs no build."
    echo ""
    info "Pulling shared base images (parallel)..."
    local bases=(
        docker.io/library/maven:3.9-eclipse-temurin-25
        docker.io/library/eclipse-temurin:25-jdk
        docker.io/library/eclipse-temurin:25-jre
        registry.access.redhat.com/ubi10/openjdk-25-runtime
        registry.access.redhat.com/ubi10/openjdk-25
        registry.access.redhat.com/ubi9
        docker.io/grafana/otel-lgtm:0.29.0
        docker.io/prom/prometheus:v3.13.2
    )
    for img in "${bases[@]}"; do
        ( podman pull -q "$img" >/dev/null 2>&1 && info "  ✓ $img" || warn "  ✗ pull $img" ) &
    done
    wait
    echo ""
    info "Building demo images (each demo.sh will then hit cache)..."
    local rc=0
    _b() { # $1=label  then a subshell command via remaining args
        local label="$1"; shift
        if ( "$@" ) >/dev/null 2>&1; then info "  ✓ ${label}"; else warn "  ✗ ${label} (build failed — check by running its demo.sh)"; rc=1; fi
    }
    _b "demo-01 heap-sizing"      bash -c "cd '$DEMOS_DIR/demo-01-heap-sizing' && docker build -q -f Dockerfile.bad -t jvm-demo:bad . && docker build -q -f Dockerfile.good -t jvm-demo:good ."
    _b "demo-02 gc-monitoring"    bash -c "cd '$DEMOS_DIR/quarkus-demo-02-gc-monitoring' && podman-compose build"
    _b "demo-03 appcds (Quarkus)" bash -c "cd '$DEMOS_DIR/quarkus-demo-03-appcds' && podman build -f app/Dockerfile.baseline -t quarkus-startup:baseline ./app && podman build -f app/Dockerfile.appcds -t quarkus-startup:appcds ./app"
    [ "$RUN_SPRING" -eq 1 ] && _b "demo-03b appcds (Spring)" bash -c "cd '$DEMOS_DIR/demo-03-appcds' && podman build -f app/Dockerfile.baseline -t startup-demo:baseline ./app && podman build -f app/Dockerfile.appcds -t startup-demo:appcds ./app"
    warn "demo-04 leyden: skipped (builds with --no-cache at runtime); base images pre-pulled above."
    _b "demo-05 grpc"             bash -c "cd '$DEMOS_DIR/quarkus-demo-05-grpc' && podman build -t quarkus-grpc-demo:latest ./app"
    _b "demo-06 latency"          bash -c "cd '$DEMOS_DIR/quarkus-demo-06-latency' && podman-compose build"
    info "demo-07 rightsizing: no build (pure Python)."
    _b "demo-08 panama"           bash -c "cd '$DEMOS_DIR/quarkus-demo-08-panama' && podman build -t quarkus-panama-demo:latest ."
    _b "demo-09 onnx"             bash -c "cd '$DEMOS_DIR/quarkus-demo-09-onnx' && podman build -t quarkus-onnx-demo:latest ."
    echo ""
    banner "Pre-build complete"
    info "Now run:  ./run-all-demos.sh   — builds are cached, so demos start fast (demo 04 still rebuilds)."
    return $rc
}
if [ "$PREBUILD" -eq 1 ]; then prebuild; exit $?; fi

# ── Prerequisites (warn, don't hard-fail) ─────────────────────────────────────
banner "Taming the JVM — Master Demo Runner"
info "Quarkus 3.33.1 LTS · JDK 25 · UBI 10 · Podman (rootless)"
command -v podman >/dev/null 2>&1 && info "podman:  $(podman --version 2>/dev/null)" || warn "podman not found (demos 01–06/08/09 need a container runtime)"
command -v podman-compose >/dev/null 2>&1 && info "podman-compose: present (demos 02, 06)" || warn "podman-compose not found — demos 02 & 06 need it (pip3 install podman-compose)"
command -v java >/dev/null 2>&1 && info "java:    $(java -version 2>&1 | head -1)" || warn "java not found on host (containers bring their own JDK)"
command -v hey  >/dev/null 2>&1 && command -v ghz >/dev/null 2>&1 && info "hey + ghz: present (demo 05)" || warn "hey/ghz not found — demo 05 load tests need them"
command -v python3 >/dev/null 2>&1 && info "python3: present (demo 07)" || warn "python3 not found — demo 07 needs it"
echo ""
warn "Each demo builds container images on first run and self-tears-down its stack."
warn "Demos 02 & 06 expose Grafana on http://localhost:3000 (admin/admin)."
[ -z "$ONLY" ] && pause "Press Enter to begin${FROM:+ from demo $FROM}..."

# ── Runner ────────────────────────────────────────────────────────────────────
run_one() {
    local dir="$1"; local script="${DEMOS_DIR}/${dir}/demo.sh"
    if [ ! -f "$script" ]; then warn "missing: $script — skipping"; return 1; fi
    ( cd "${DEMOS_DIR}/${dir}" && bash "./demo.sh" ) \
        || warn "demo '${dir}' exited non-zero — continuing to the next."
}

should_run() { # $1 = demo num (e.g. 3, 3b)
    local n="$1"
    [ "$n" = "3b" ] && { [ "$RUN_SPRING" -eq 1 ] || return 1; }
    if [ -n "$ONLY" ]; then [ "$n" = "$ONLY" ]; return; fi
    # numeric-from comparison (treat 3b as 3 for --from)
    local base="${n%b}"; [ "$base" -ge "$FROM" ] 2>/dev/null
}

for d in "${DEMOS[@]}"; do
    IFS='|' read -r num dir title extra <<< "$d"
    should_run "$num" || continue

    banner "Demo ${num} — ${title}"
    case "$num" in
      1)  info "JVM defaults heap to 25% of the container limit (UseContainerSupport, JDK 10+)."
          info "Shows a hardcoded -Xmx vs MaxRAMPercentage=75 and an OOMKill (exit 137)." ;;
      2)  info "Two Quarkus apps (G1GC + ZGC) + Prometheus + Grafana Tempo, wired via OTLP."
          grafana "Grafana:    http://localhost:3000  (admin/admin) → 'JVM GC Monitoring' dashboard"
          grafana "Prometheus: http://localhost:9090   ·   Tempo traces via Grafana → Explore"
          info "Watch the GC-pause P99 panel while load runs; the demo tears the stack down at the end." ;;
      3)  info "AppCDS/AOT cache via one property (quarkus.package.jar.aot.enabled=true)."
          info "On Quarkus the startup gain is ~0–5% (class loading already moved to build time)." ;;
      3b) info "Spring Boot AppCDS comparison — where AppCDS gives a larger startup win."
          warn "Companion demo. Skip with --no-spring." ;;
      4)  info "Project Leyden AOT cache on JDK 25 — trains on @QuarkusIntegrationTest."
          info "Measured ~830ms → ~215ms (~75% faster) on the eval hardware; live numbers vary." ;;
      5)  info "One Quarkus service on REST (:8080) and gRPC (:9000); load with hey + ghz."
          warn "On localhost REST usually wins (tiny payload, no network); gRPC's edge is a production projection." ;;
      6)  info "Two Quarkus apps — G1GC vs ZGC — under identical load; compares GC-pause delta."
          grafana "Grafana:    http://localhost:3000   ·   Prometheus: http://localhost:9090"
          info "ZGC's sub-ms pauses are a per-pause STW design target (JFR); the demo reports a cumulative delta." ;;
      7)  info "Analyzes bundled sample Prometheus data (7 workloads) → right-sized requests/limits."
          info "Pure Python (stdlib); no containers. Add --live to point at a real Prometheus." ;;
      8)  info "Calls a C++20 shared library from Quarkus via the Foreign Function & Memory API."
          info "UBI9 cpp-builder stage compiles the lib; UBI10 openjdk-25 runtime runs the app." ;;
      9)  info "In-process AI inference: LangChain4j + ONNX Runtime + MiniLM, no Python sidecar."
          info "First build pulls the model (~25MB) + ONNX Runtime — allow extra time." ;;
    esac
    echo ""
    pause "Press Enter to start Demo ${num}..."
    run_one "$dir"
    echo ""
    [ -n "$ONLY" ] || pause "Demo ${num} complete. Press Enter to continue..."
done

banner "All demos complete."
info "Slides + speaker notes: presentation/optimizing-quarkus-on-kubernetes.pptx"
info "Re-run a single demo any time:  ./run-all-demos.sh --only <N>"
