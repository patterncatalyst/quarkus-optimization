#!/usr/bin/env bash
# ============================================================
# Demo 02: GC Monitoring with Prometheus + Grafana
#
# Starts a full observability stack and drives GC pressure
# so you can watch live GC metrics in Grafana.
#
# Prerequisites: Docker Desktop with Compose plugin
# Run:  ./demo.sh
# ============================================================

set -e

CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
RESET='\033[0m'

hr() { printf "%0.s─" {1..65}; echo; }

echo
echo -e "${CYAN}${BOLD}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  DEMO 02: GC Monitoring with Prometheus & Grafana           ║"
echo "║  Taming the JVM: Optimizing Java on OpenShift               ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${RESET}"

# ── Stack URLs ────────────────────────────────────────────────────
#   Grafana:    http://localhost:3000  (JVM GC dashboard)
#   Prometheus: http://localhost:9090  (metrics + alerts)
#   Jaeger:     http://localhost:16686 (distributed traces — Spring Boot 4.0 OTel)

# ── Functions ──────────────────────────────────────────────────────

wait_for_health() {
    local url=$1
    local label=$2
    local max_attempts=40
    local attempt=0
    echo -ne "${YELLOW}  Waiting for ${label}...${RESET}"
    until curl -sf "$url" > /dev/null 2>&1; do
        attempt=$((attempt + 1))
        if [ $attempt -ge $max_attempts ]; then
            echo -e " ${RED}TIMEOUT${RESET}"
            return 1
        fi
        echo -n "."
        sleep 3
    done
    echo -e " ${GREEN}✅${RESET}"
}

generate_gc_load() {
    local app_port=$1
    local label=$2
    local mb=${3:-30}
    local iters=${4:-8}
    echo -e "${CYAN}  → Generating GC pressure on ${label} (${mb}MB × ${iters} iterations)...${RESET}"
    response=$(curl -sf "http://localhost:${app_port}/allocate?mb=${mb}&iterations=${iters}" 2>/dev/null || echo '{"error":"app not ready"}')
    echo "    $(echo $response | python3 -c "import sys,json; d=json.load(sys.stdin); print(f\"Allocated: {d.get('allocatedMB','?')} MB | GC count: {d.get('gcCount','?')} | GC time: {d.get('gcTimeMs','?')}ms | Duration: {d.get('totalDurationMs','?')}ms\")" 2>/dev/null || echo "$response")"
}

# ── Step 1: Start the stack ────────────────────────────────────────
echo -e "${YELLOW}Step 1: Starting full observability stack...${RESET}"
echo "  (First run may take 2-5 minutes to download images and build the app)"
echo
docker compose up -d --build 2>&1 | grep -E "^(#|✓|=>|\s*(Container|Network|Volume))" | head -30 || docker-compose up -d --build

echo
echo -e "${YELLOW}Step 2: Waiting for services to become healthy...${RESET}"
wait_for_health "http://localhost:8080/actuator/health" "Java G1GC app  (port 8080)"
wait_for_health "http://localhost:8081/actuator/health" "Java ZGC app   (port 8081)"
wait_for_health "http://localhost:9090/-/ready"          "Prometheus     (port 9090)"
wait_for_health "http://localhost:3000/api/health"       "Grafana        (port 3000)"
wait_for_health "http://localhost:16686"                   "Jaeger         (port 16686)"

echo
hr
echo -e "${BOLD}🎉 Stack is running!${RESET}"
echo
echo -e "  ${GREEN}Grafana:    http://localhost:3000${RESET}  (admin / admin)"
echo -e "  ${GREEN}Prometheus: http://localhost:9090${RESET}"
echo -e "  ${GREEN}G1GC App:   http://localhost:8080${RESET}"
echo -e "  ${GREEN}ZGC App:    http://localhost:8081${RESET}"
echo
echo -e "${YELLOW}📊 Open Grafana:    http://localhost:3000  → Dashboards → 'JVM GC Monitoring — Demo 02'${RESET}"
  echo -e "${YELLOW}🔍 Open Jaeger UI:  http://localhost:16686 → Service: gc-monitoring-demo → Find Traces${RESET}"
echo
read -p "Press Enter when Grafana is open to start generating GC load..."
echo

# ── Step 3: Generate baseline load ─────────────────────────────────
hr
echo -e "${BOLD}Step 3: Generating GC load — watch Grafana in real time!${RESET}"
echo

echo -e "${CYAN}=== ROUND 1: Light allocation (10 MB × 5 iterations) ===${RESET}"
generate_gc_load 8080 "G1GC" 10 5
generate_gc_load 8081 "ZGC"  10 5
echo
sleep 5

echo -e "${CYAN}=== ROUND 2: Medium allocation (50 MB × 5 iterations) ===${RESET}"
echo "  Watch for GC pause P99 rising in the top-left panel!"
generate_gc_load 8080 "G1GC" 50 5
generate_gc_load 8081 "ZGC"  50 5
echo
sleep 5

echo -e "${CYAN}=== ROUND 3: Heavy allocation — trigger alert threshold (100 MB × 8) ===${RESET}"
echo -e "  ${RED}Watch for the HighGCPauseP99 alert to fire!${RESET}"
generate_gc_load 8080 "G1GC" 100 8
generate_gc_load 8081 "ZGC"  100 8
echo
sleep 3

echo -e "${CYAN}=== ROUND 4: Sustained load (20 MB per round, 15 rounds) ===${RESET}"
echo "  Simulating sustained traffic — watch heap utilization gauge"
curl -sf "http://localhost:8080/load?mb=20&delayMs=300&rounds=15" > /dev/null &
curl -sf "http://localhost:8081/load?mb=20&delayMs=300&rounds=15" > /dev/null &
wait
echo -e "  ${GREEN}Done!${RESET}"
echo

# ── Step 4: Show raw Prometheus data ───────────────────────────────
hr
echo -e "${BOLD}Step 4: Query Prometheus directly (PromQL examples)${RESET}"
echo
echo "  GC pause P99 for G1GC (last 5 min):"
curl -sG "http://localhost:9090/api/v1/query" \
  --data-urlencode 'query=histogram_quantile(0.99, rate(jvm_gc_pause_seconds_bucket{job="java-g1gc"}[5m])) * 1000' \
  | python3 -c "
import sys, json
data = json.load(sys.stdin)
results = data.get('data', {}).get('result', [])
for r in results:
    val = float(r['value'][1])
    print(f'    G1GC P99 pause: {val:.1f} ms')
" 2>/dev/null || echo "    (Prometheus query unavailable — check http://localhost:9090)"

echo
echo "  Heap utilization % for both GCs:"
for job in java-g1gc java-zgc; do
    label="${job/java-/}"
    result=$(curl -sG "http://localhost:9090/api/v1/query" \
        --data-urlencode "query=jvm_memory_used_bytes{area='heap',job='${job}'} / jvm_memory_max_bytes{area='heap',job='${job}'}" \
        | python3 -c "
import sys, json
data = json.load(sys.stdin)
results = data.get('data', {}).get('result', [])
for r in results:
    val = float(r['value'][1]) * 100
    print(f'{val:.1f}%')
" 2>/dev/null || echo "N/A")
    echo "    ${label^^} heap utilization: $result"
done

echo

# ── Step 5: Show key PrometheusRule alerts ─────────────────────────
hr
echo -e "${BOLD}Step 5: Check configured alerts${RESET}"
echo
curl -sf "http://localhost:9090/api/v1/rules" \
  | python3 -c "
import sys, json
data = json.load(sys.stdin)
for group in data.get('data', {}).get('groups', []):
    for rule in group.get('rules', []):
        if rule.get('type') == 'alerting':
            state = rule.get('state', 'inactive')
            name  = rule.get('name', '')
            color = '\033[0;31m' if state == 'firing' else '\033[0;32m' if state == 'inactive' else '\033[1;33m'
            reset = '\033[0m'
            print(f'  {color}[{state:10s}]{reset} {name}')
" 2>/dev/null || echo "  (Check alerts at http://localhost:9090/alerts)"

echo
hr
echo -e "${BOLD}KEY OBSERVATIONS${RESET}"
echo "  Compare the G1GC vs ZGC panels:"
echo "  • G1GC shows higher P99 pause spikes during heavy allocation"
echo "  • ZGC shows near-zero pauses but higher concurrent CPU usage"
echo "  • Under light load both perform similarly — GC selection matters at scale"
echo
echo -e "${YELLOW}When to use each:${RESET}"
echo "  G1GC  — General microservices, modest latency SLOs (< 200ms)"
echo "  ZGC   — Low-latency APIs, large heaps, latency SLO < 10ms"
echo

hr
echo -e "${YELLOW}Press Enter to tear down the stack, or Ctrl+C to leave it running...${RESET}"
read -p ""
echo
echo -e "${YELLOW}Stopping stack...${RESET}"
docker compose down -v
echo -e "${GREEN}✅ Demo 02 complete!${RESET}"
echo
