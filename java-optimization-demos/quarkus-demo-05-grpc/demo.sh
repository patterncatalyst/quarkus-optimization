#!/usr/bin/env bash
# ============================================================
# Demo 05: REST vs gRPC — Same Service, Two Protocols
# Quarkus 3.33.1 LTS / Java 21
#
# KEY INSIGHT: gRPC unary is NOT faster than REST on localhost.
# The gRPC advantage appears in two scenarios this demo shows:
#
#   1. STREAMING — one connection, N messages pushed server-side
#      REST equivalent needs N separate HTTP requests
#      → gRPC wins 10-30x even on localhost
#
#   2. HIGH CONCURRENCY (500+ workers) — HTTP/2 multiplexing
#      vs HTTP/1.1 opening a new TCP connection per worker
#
# Prerequisites:
#   podman    — container runtime
#   grpcurl   — gRPC CLI           (brew install grpcurl)
#   hey       — REST load tester   (brew install hey)
#   ghz       — gRPC load tester   (brew install ghz)
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

hr()     { printf "%0.s─" {1..65}; echo; }
hr_thin(){ printf "%0.s·" {1..65}; echo; }

STREAM_MESSAGES=1000
UNARY_REQUESTS=10000
HIGH_CONCURRENCY=500
LOW_CONCURRENCY=50

echo
echo -e "${CYAN}${BOLD}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  DEMO 05: REST vs gRPC — Same Quarkus Service               ║"
echo "║  Quarkus 3.33.1 LTS / Java 21                               ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${RESET}"

echo -e "${YELLOW}Ports:${RESET}"
echo "  REST  → http://localhost:8080/metrics  (JSON / HTTP 1.1)"
echo "  gRPC  → localhost:9000                 (Protobuf / HTTP 2)"
echo
echo -e "${YELLOW}What this demo shows:${RESET}"
echo "  • On localhost, gRPC UNARY is not faster than REST (network cost = 0)"
echo "  • gRPC STREAMING wins decisively — 1 connection vs ${STREAM_MESSAGES} requests"
echo "  • At high concurrency, HTTP/2 multiplexing pulls ahead"
echo

# ── Check tools ───────────────────────────────────────────────────
echo -e "${YELLOW}Checking tools...${RESET}"
HAS_GRPCURL=true; HAS_HEY=true; HAS_GHZ=true
for tool in grpcurl hey ghz; do
  if command -v "$tool" &>/dev/null; then
    echo -e "  ${GREEN}✅ $tool${RESET}"
  else
    echo -e "  ${RED}✗  $tool  (brew install $tool)${RESET}"
    case $tool in
      grpcurl) HAS_GRPCURL=false ;;
      hey)     HAS_HEY=false ;;
      ghz)     HAS_GHZ=false ;;
    esac
  fi
done
echo

# ── Step 1: Build ─────────────────────────────────────────────────
hr
echo -e "${YELLOW}Step 1: Building image${RESET}"
hr
echo "  quarkus-maven-plugin generates Java stubs from metrics.proto"
echo
if ! podman build -t quarkus-grpc-demo:latest ./app; then
  echo -e "${RED}✗ Build failed${RESET}"; exit 1
fi
echo -e "${GREEN}✅ Image built${RESET}"
echo

# ── Step 2: Start ─────────────────────────────────────────────────
hr
echo -e "${YELLOW}Step 2: Starting container${RESET}"
hr
podman stop grpc-demo 2>/dev/null || true
podman rm   grpc-demo 2>/dev/null || true

podman run -d --name grpc-demo \
  -p 8080:8080 \
  -p 9000:9000 \
  --memory=512m \
  quarkus-grpc-demo:latest > /dev/null

echo -n "  Waiting for startup"
for i in {1..30}; do
  if curl -sf http://localhost:8080/q/health/live >/dev/null 2>&1; then
    echo -e " ${GREEN}✅${RESET}"; break
  fi
  echo -n "."; sleep 1
  if [ $i -eq 30 ]; then
    echo -e " ${RED}✗ Timed out${RESET}"
    podman logs grpc-demo; exit 1
  fi
done
echo

# ── Step 3: Both protocols responding ────────────────────────────
hr
echo -e "${YELLOW}Step 3: Both protocols — same data, different wire format${RESET}"
hr
echo
echo -e "${RED}  REST → GET /metrics  (JSON ~220 bytes):${RESET}"
curl -sf http://localhost:8080/metrics | python3 -m json.tool 2>/dev/null \
  || curl -sf http://localhost:8080/metrics
echo

if $HAS_GRPCURL; then
  echo -e "${CYAN}  gRPC → MetricsService/GetJvmMetrics  (Protobuf ~40 bytes):${RESET}"
  grpcurl -plaintext -d '{"host":"localhost"}' \
    localhost:9000 MetricsService/GetJvmMetrics 2>/dev/null || true
  echo
fi

# ── Step 4: THE KEY DEMO — Streaming vs repeated REST ────────────
hr
echo -e "${YELLOW}Step 4: THE REAL COMPARISON — Streaming vs repeated REST requests${RESET}"
hr
echo
echo -e "  ${BOLD}Scenario: receive ${STREAM_MESSAGES} JVM metric snapshots as fast as possible${RESET}"
echo
echo "  gRPC streaming : 1 connection opened, server pushes all ${STREAM_MESSAGES} messages"
echo "  REST equivalent: ${STREAM_MESSAGES} separate requests, ${STREAM_MESSAGES} TCP round-trips"
echo

if $HAS_GRPCURL; then
  echo -e "${CYAN}  Timing gRPC streaming (${STREAM_MESSAGES} messages, 1 connection)...${RESET}"
  GRPC_START=$(python3 -c "import time; print(time.time())")

  timeout 60 grpcurl -plaintext \
    -d "{\"host\":\"localhost\",\"count\":${STREAM_MESSAGES}}" \
    localhost:9000 MetricsService/StreamMetrics 2>/dev/null \
    | grep -c '"heapUsedMb"' > /tmp/grpc_msg_count.txt 2>/dev/null || true

  GRPC_END=$(python3 -c "import time; print(time.time())")
  GRPC_MSG=$(cat /tmp/grpc_msg_count.txt 2>/dev/null || echo "?")
  GRPC_ELAPSED=$(python3 -c "print(f'{${GRPC_END} - ${GRPC_START}:.2f}')")

  echo -e "  ${GREEN}✅ gRPC: ${GRPC_MSG} messages in ${GRPC_ELAPSED}s  (1 TCP connection)${RESET}"
  echo
fi

if $HAS_HEY; then
  echo -e "${RED}  Timing REST polling (${STREAM_MESSAGES} sequential requests)...${RESET}"
  REST_STREAM=$(hey -n $STREAM_MESSAGES -c 1 \
    http://localhost:8080/metrics 2>&1)
  REST_TOTAL=$(echo "$REST_STREAM" | grep "Total:" | awk '{print $2, $3}')
  echo -e "  ${RED}REST:  ${REST_TOTAL} for ${STREAM_MESSAGES} requests  (${STREAM_MESSAGES} TCP connections)${RESET}"
  echo
fi

if $HAS_GRPCURL && $HAS_HEY; then
  hr_thin
  echo -e "  ${BOLD}Why streaming wins even on localhost:${RESET}"
  echo "  REST pays per-message: HTTP framing + JSON serialisation + header parsing"
  echo "  gRPC pays all of that ONCE on connect, then pushes raw Protobuf frames."
  echo "  No network needed — the serialisation overhead alone is the difference."
  echo
fi

# ── Step 5: Live stream ───────────────────────────────────────────
if $HAS_GRPCURL; then
  hr
  echo -e "${YELLOW}Step 5: Watch the live stream (5 seconds)${RESET}"
  hr
  echo -e "${CYAN}  One connection. Server pushes a new JVM snapshot every second.${RESET}"
  echo
  timeout 5 grpcurl -plaintext \
    -d '{"host":"localhost","count":0}' \
    localhost:9000 MetricsService/StreamMetrics 2>/dev/null || true
  echo
fi

# ── Step 6: Unary — honest result + high concurrency ─────────────
if $HAS_HEY && $HAS_GHZ; then
  hr
  echo -e "${YELLOW}Step 6: Unary load test — the honest result${RESET}"
  hr
  echo
  echo -e "  ${BOLD}Low concurrency (c=${LOW_CONCURRENCY}) — REST wins on localhost:${RESET}"
  echo "  No real network = no TCP overhead for gRPC to eliminate."
  echo

  REST_LO=$(hey -n $UNARY_REQUESTS -c $LOW_CONCURRENCY \
    http://localhost:8080/metrics 2>&1)
  REST_LO_RPS=$(echo "$REST_LO" | grep "Requests/sec:" | awk '{print $2}')
  REST_LO_P99=$(echo "$REST_LO" | grep "99% in"        | awk '{print $3}')

  GRPC_LO=$(ghz --insecure \
    --proto app/src/main/proto/metrics.proto \
    --call MetricsService/GetJvmMetrics \
    -d '{"host":"localhost"}' \
    -n $UNARY_REQUESTS -c $LOW_CONCURRENCY \
    localhost:9000 2>&1)
  GRPC_LO_RPS=$(echo "$GRPC_LO" | grep "Requests/sec:" | awk '{print $2}')
  GRPC_LO_P99=$(echo "$GRPC_LO" | grep "p99:"          | awk '{print $2}')

  echo -e "  ${RED}REST  c=${LOW_CONCURRENCY}:  ${REST_LO_RPS} rps  p99=${REST_LO_P99}${RESET}"
  echo -e "  ${CYAN}gRPC  c=${LOW_CONCURRENCY}:  ${GRPC_LO_RPS} rps  p99=${GRPC_LO_P99}${RESET}"
  echo -e "  ${YELLOW}⚠  REST wins — expected on localhost with small payload${RESET}"
  echo

  hr_thin
  echo -e "  ${BOLD}High concurrency (c=${HIGH_CONCURRENCY}) — HTTP/2 multiplexing kicks in:${RESET}"
  echo "  REST opens ${HIGH_CONCURRENCY} TCP connections."
  echo "  gRPC multiplexes ${HIGH_CONCURRENCY} streams over a few HTTP/2 connections."
  echo

  REST_HI=$(hey -n $UNARY_REQUESTS -c $HIGH_CONCURRENCY \
    http://localhost:8080/metrics 2>&1)
  REST_HI_RPS=$(echo "$REST_HI" | grep "Requests/sec:" | awk '{print $2}')
  REST_HI_P99=$(echo "$REST_HI" | grep "99% in"        | awk '{print $3}')

  GRPC_HI=$(ghz --insecure \
    --proto app/src/main/proto/metrics.proto \
    --call MetricsService/GetJvmMetrics \
    -d '{"host":"localhost"}' \
    -n $UNARY_REQUESTS -c $HIGH_CONCURRENCY \
    localhost:9000 2>&1)
  GRPC_HI_RPS=$(echo "$GRPC_HI" | grep "Requests/sec:" | awk '{print $2}')
  GRPC_HI_P99=$(echo "$GRPC_HI" | grep "p99:"          | awk '{print $2}')

  echo -e "  ${RED}REST  c=${HIGH_CONCURRENCY}:  ${REST_HI_RPS} rps  p99=${REST_HI_P99}${RESET}"
  echo -e "  ${CYAN}gRPC  c=${HIGH_CONCURRENCY}:  ${GRPC_HI_RPS} rps  p99=${GRPC_HI_P99}${RESET}"
  echo "  The gap closes or flips as HTTP/2 multiplexing absorbs connection overhead."
  echo
fi

# ── Summary ───────────────────────────────────────────────────────
hr
echo -e "${YELLOW}Summary${RESET}"
hr
echo
python3 << 'PYEOF'
rows = [
    ("Scenario",                    "REST",              "gRPC",              "Winner"),
    ("─"*30,                        "─"*18,              "─"*18,              "─"*8),
    ("Localhost unary (this demo)", "✅ faster",         "slower",            "REST"),
    ("Production pod-to-pod",       "baseline",          "✅ ~3-4× faster",   "gRPC"),
    ("Streaming (this demo)",       "❌ 1000 requests",  "✅ 1 connection",    "gRPC"),
    ("High concurrency (500+)",     "500 TCP conns",     "✅ multiplexed",     "gRPC"),
    ("Large payloads (>5KB)",       "verbose JSON",      "✅ 10× smaller",     "gRPC"),
    ("Public API / browser",        "✅ native",         "needs proxy",        "REST"),
    ("curl / Postman debug",        "✅ trivial",        "needs grpcurl",      "REST"),
]
for r in rows:
    print(f"  {r[0]:<32} {r[1]:<20} {r[2]:<20} {r[3]}")
print()
print("  → Use gRPC for: internal pod-to-pod, streaming, high-frequency, large payloads")
print("  → Use REST for: public APIs, browser clients, external partners")
PYEOF

# ── Cleanup ───────────────────────────────────────────────────────
echo
echo -e "${YELLOW}Stopping container...${RESET}"
podman stop grpc-demo >/dev/null
podman rm   grpc-demo >/dev/null
echo -e "${GREEN}✅ Demo 05 complete${RESET}"
echo
