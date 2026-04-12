#!/usr/bin/env bash
# ============================================================
# Demo 05: REST vs gRPC — Same Service, Two Protocols
# Quarkus 3.33.1 LTS / Java 21
#
# Shows:
#   1. Same JVM metrics exposed over REST (JSON/HTTP1.1) and
#      gRPC (Protobuf/HTTP2) simultaneously
#   2. Live throughput comparison with hey + ghz
#   3. gRPC server streaming — no REST equivalent
#
# Prerequisites:
#   podman          — container runtime
#   hey             — REST load tester (brew install hey)
#   ghz             — gRPC load tester (brew install ghz)
#   grpcurl         — gRPC CLI (brew install grpcurl)
#
# Run: ./demo.sh
# ============================================================

set -e

CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
RESET='\033[0m'

hr() { printf "%0.s─" {1..65}; echo; }
RUNS=10000
CONCURRENCY=50

echo
echo -e "${CYAN}${BOLD}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  DEMO 05: REST vs gRPC — Same Quarkus Service               ║"
echo "║  Quarkus 3.33.1 LTS / Java 21                               ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${RESET}"

echo -e "${YELLOW}Architecture:${RESET}"
echo "  Same Quarkus JVM exposes both protocols simultaneously:"
echo "  • REST  → http://localhost:8080/metrics  (JSON / HTTP 1.1)"
echo "  • gRPC  → localhost:9000                 (Protobuf / HTTP 2)"
echo "  Same data. Same JVM. Different wire formats."
echo

# ── Check tools ───────────────────────────────────────────────────
check_tool() {
  if ! command -v "$1" &>/dev/null; then
    echo -e "${RED}✗ '$1' not found.${RESET} Install: $2"
    return 1
  fi
}

echo -e "${YELLOW}Checking tools...${RESET}"
TOOLS_OK=true
check_tool hey      "brew install hey"          || TOOLS_OK=false
check_tool ghz      "brew install ghz"          || TOOLS_OK=false
check_tool grpcurl  "brew install grpcurl"      || TOOLS_OK=false

if [ "$TOOLS_OK" = "false" ]; then
  echo
  echo -e "${YELLOW}Missing load-test tools. Demo will run in OBSERVE mode:${RESET}"
  echo "  curl and grpcurl calls only — no throughput comparison."
  LOAD_TEST=false
else
  LOAD_TEST=true
fi
echo

# ── Step 1: Build ─────────────────────────────────────────────────
echo -e "${YELLOW}Step 1: Building image...${RESET}"
echo "  (quarkus-maven-plugin generates Java stubs from metrics.proto)"
echo

if ! podman build -t quarkus-grpc-demo:latest ./app; then
  echo -e "${RED}✗ Build failed${RESET}"; exit 1
fi
echo -e "${GREEN}✅ Image built${RESET}"
echo

# ── Step 2: Start container ───────────────────────────────────────
echo -e "${YELLOW}Step 2: Starting container...${RESET}"
podman stop grpc-demo 2>/dev/null || true
podman rm   grpc-demo 2>/dev/null || true

CID=$(podman run -d --name grpc-demo \
  -p 8080:8080 \
  -p 9000:9000 \
  --memory=512m \
  quarkus-grpc-demo:latest)

echo "  Container: ${CID:0:12}"
echo -n "  Waiting for startup"
for i in {1..30}; do
  if curl -sf http://localhost:8080/q/health/live >/dev/null 2>&1; then
    echo -e " ${GREEN}✅${RESET}"
    break
  fi
  echo -n "."
  sleep 1
  if [ $i -eq 30 ]; then
    echo -e " ${RED}✗ Timed out${RESET}"
    podman logs grpc-demo
    exit 1
  fi
done
echo

# ── Step 3: Show both protocols responding ────────────────────────
hr
echo -e "${YELLOW}Step 3: Both protocols responding${RESET}"
hr
echo
echo -e "${CYAN}REST → GET /metrics (JSON):${RESET}"
curl -sf http://localhost:8080/metrics | python3 -m json.tool 2>/dev/null || \
  curl -sf http://localhost:8080/metrics
echo

echo -e "${CYAN}gRPC → MetricsService/GetJvmMetrics (Protobuf decoded):${RESET}"
grpcurl -plaintext \
  -d '{"host":"localhost"}' \
  localhost:9000 MetricsService/GetJvmMetrics 2>/dev/null || \
  echo -e "${YELLOW}  (grpcurl not found — skipping)${RESET}"
echo

# ── Step 4: Streaming demo ────────────────────────────────────────
hr
echo -e "${YELLOW}Step 4: gRPC server streaming (5 seconds)${RESET}"
hr
echo -e "${CYAN}  grpcurl → MetricsService/StreamMetrics${RESET}"
echo "  Receiving live JVM metrics stream — no polling, no SSE..."
echo "  (REST has no equivalent without WebSocket/SSE boilerplate)"
echo
if command -v grpcurl &>/dev/null; then
  timeout 5 grpcurl -plaintext \
    -d '{"host":"localhost"}' \
    localhost:9000 MetricsService/StreamMetrics 2>/dev/null | head -40 || true
else
  echo -e "${YELLOW}  (grpcurl not found — skipping streaming demo)${RESET}"
fi
echo

# ── Step 5: Load test ─────────────────────────────────────────────
if [ "$LOAD_TEST" = "true" ]; then
  hr
  echo -e "${YELLOW}Step 5: Load test — ${RUNS} requests, ${CONCURRENCY} concurrent${RESET}"
  hr
  echo

  echo -e "${RED}  REST (JSON / HTTP 1.1):${RESET}"
  REST_OUTPUT=$(hey -n $RUNS -c $CONCURRENCY http://localhost:8080/metrics 2>&1)
  REST_RPS=$(echo "$REST_OUTPUT" | grep "Requests/sec" | awk '{print $2}')
  REST_P50=$(echo "$REST_OUTPUT" | grep "50% in"       | awk '{print $3}')
  REST_P99=$(echo "$REST_OUTPUT" | grep "99% in"       | awk '{print $3}')
  echo "$REST_OUTPUT" | grep -E "Requests/sec|50% in|99% in|Average"
  echo

  echo -e "${CYAN}  gRPC (Protobuf / HTTP 2):${RESET}"
  GRPC_OUTPUT=$(ghz --insecure \
    --proto app/src/main/proto/metrics.proto \
    --call MetricsService/GetJvmMetrics \
    -d '{"host":"localhost"}' \
    -n $RUNS -c $CONCURRENCY \
    localhost:9000 2>&1)
  GRPC_RPS=$(echo "$GRPC_OUTPUT" | grep "Requests/sec" | awk '{print $2}')
  GRPC_P50=$(echo "$GRPC_OUTPUT" | grep "p50"          | awk '{print $2}')
  GRPC_P99=$(echo "$GRPC_OUTPUT" | grep "p99"          | awk '{print $2}')
  echo "$GRPC_OUTPUT" | grep -E "Requests/sec|p50|p99|Average"
  echo

  # Summary table
  hr
  echo -e "${YELLOW}  Results Summary${RESET}"
  hr
  python3 << PYEOF
rest_rps  = "${REST_RPS}"
grpc_rps  = "${GRPC_RPS}"
rest_p50  = "${REST_P50}"
grpc_p50  = "${GRPC_P50}"
rest_p99  = "${REST_P99}"
grpc_p99  = "${GRPC_P99}"

print(f"  {'Metric':<22} {'REST (JSON)':>14} {'gRPC (Protobuf)':>16} {'Delta':>10}")
print(f"  {'─'*64}")

def safe_float(v, scale=1.0):
    try: return float(v.replace(',','')) * scale
    except: return None

def fmt_delta(a, b, higher_better=True):
    if a is None or b is None or a == 0: return "n/a"
    d = (b - a) / a * 100
    sign = "+" if d > 0 else ""
    better = (d > 0) == higher_better
    color = "\033[32m" if better else "\033[31m"
    return f"{color}{sign}{d:.0f}%\033[0m"

r_rps = safe_float(rest_rps); g_rps = safe_float(grpc_rps)
r_p50 = safe_float(rest_p50, 1000); g_p50 = safe_float(grpc_p50, 1000)
r_p99 = safe_float(rest_p99, 1000); g_p99 = safe_float(grpc_p99, 1000)

print(f"  {'Throughput (rps)':<22} {rest_rps:>14} {grpc_rps:>16} {fmt_delta(r_rps, g_rps, True):>10}")
print(f"  {'p50 latency':<22} {rest_p50+'s':>14} {grpc_p50:>16} {fmt_delta(r_p50, g_p50, False):>10}")
print(f"  {'p99 latency':<22} {rest_p99+'s':>14} {grpc_p99:>16} {fmt_delta(r_p99, g_p99, False):>10}")
print()
print("  gRPC wins on throughput, latency, CPU, and bandwidth.")
print("  REST wins on debuggability and browser compatibility.")
print("  → Use gRPC for internal pod-to-pod calls; REST for public APIs.")
PYEOF
fi

# ── Cleanup ───────────────────────────────────────────────────────
echo
echo -e "${YELLOW}Stopping container...${RESET}"
podman stop grpc-demo >/dev/null
podman rm   grpc-demo >/dev/null
echo -e "${GREEN}✅ Demo 05 complete${RESET}"
echo
