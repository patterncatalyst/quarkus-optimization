#!/usr/bin/env bash
# Demo 02 (Quarkus): GC Monitoring with Prometheus, Grafana & Jaeger
# Quarkus 3.33.1 LTS / Java 21
# Key difference: metrics at /q/metrics, health at /q/health

set -e
CYAN='\033[0;36m'; GREEN='\033[0;32m'; RED='\033[0;31m'
YELLOW='\033[1;33m'; BOLD='\033[1m'; RESET='\033[0m'
hr() { printf "%0.s─" {1..65}; echo; }

echo
echo -e "${CYAN}${BOLD}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  DEMO 02 (Quarkus): GC Monitoring with Prometheus + Jaeger  ║"
echo "║  Quarkus 3.33.1 LTS / Java 21                               ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${RESET}"

wait_for() {
    local url=$1 label=$2 attempt=0
    echo -ne "${YELLOW}  Waiting for ${label}...${RESET}"
    until curl -sf "$url" > /dev/null 2>&1; do
        attempt=$((attempt + 1))
        [ $attempt -ge 40 ] && { echo -e " ${RED}TIMEOUT${RESET}"; return 1; }
        echo -n "."; sleep 3
    done
    echo -e " ${GREEN}✅${RESET}"
}

echo -e "${YELLOW}Step 1: Starting stack (Quarkus + Prometheus + Grafana + Jaeger)...${RESET}"
docker compose up -d --build 2>&1 | grep -E "✓|Container|Network|Volume" | head -20 || \
    docker-compose up -d --build

echo
echo -e "${YELLOW}Step 2: Waiting for services...${RESET}"
wait_for "http://localhost:8080/q/health/live" "Quarkus G1GC (port 8080) — /q/health/live"
wait_for "http://localhost:8081/q/health/live" "Quarkus ZGC  (port 8081) — /q/health/live"
wait_for "http://localhost:9090/-/ready"         "Prometheus   (port 9090)"
wait_for "http://localhost:3000/api/health"      "Grafana      (port 3000)"
wait_for "http://localhost:16686"                "Jaeger       (port 16686)"

echo
hr
echo -e "${BOLD}🎉 Stack ready!${RESET}"
echo
echo -e "  ${GREEN}Grafana:     http://localhost:3000${RESET}  (admin/admin)"
echo -e "  ${GREEN}Prometheus:  http://localhost:9090${RESET}"
echo -e "  ${GREEN}Jaeger UI:   http://localhost:16686${RESET}"
echo -e "  ${GREEN}G1GC App:    http://localhost:8080${RESET}  → metrics: /q/metrics"
echo -e "  ${GREEN}ZGC App:     http://localhost:8081${RESET}  → health:  /q/health"
echo
echo -e "${YELLOW}Quarkus Prometheus endpoint is /q/metrics (NOT /actuator/prometheus)${RESET}"
echo -e "${YELLOW}Open Grafana → 'JVM GC Monitoring' dashboard, then Jaeger UI${RESET}"
echo
read -p "Press Enter to generate GC load..."
echo

hr
echo -e "${BOLD}Step 3: Generating GC load${RESET}"
echo

for label in "G1GC:8080" "ZGC:8081"; do
    gc="${label%%:*}"; port="${label##*:}"
    echo -e "${CYAN}=== $gc (port $port) — light allocation 10MB×5 ===${RESET}"
    result=$(curl -sf "http://localhost:$port/allocate?mb=10&iterations=5" 2>/dev/null || echo '{}')
    echo "  $result" | python3 -c "import sys,json; d=json.load(sys.stdin); print(f\"  Allocated: {d.get('allocatedMB','?')} MB | GC: {d.get('gcCount','?')} collections | {d.get('gcTimeMs','?')}ms\")" 2>/dev/null || echo "  $result"
done

sleep 3
for label in "G1GC:8080" "ZGC:8081"; do
    gc="${label%%:*}"; port="${label##*:}"
    echo -e "${CYAN}=== $gc — heavy allocation 100MB×8 ===${RESET}"
    curl -sf "http://localhost:$port/allocate?mb=100&iterations=8" > /dev/null 2>&1 &
done
wait
echo -e "  ${GREEN}Done — watch Grafana GC pause P99 panel!${RESET}"

echo
echo -e "${CYAN}=== Virtual threads: 500 tasks, 5ms each ===${RESET}"
curl -sf "http://localhost:8080/virtual-threads?tasks=500&workMs=5" 2>/dev/null \
    | python3 -c "import sys,json; d=json.load(sys.stdin); print(f\"  {d.get('taskCount','?')} VTs in {d.get('durationMs','?')}ms | peak platform threads: {d.get('peakPlatformThreads','?')}\")" 2>/dev/null || echo "  (check Jaeger for trace)"
echo
echo -e "  ${YELLOW}Open Jaeger: http://localhost:16686 → service: quarkus-gc-monitoring-demo${RESET}"

echo
hr
read -p "Press Enter to tear down..."
docker compose down -v
echo -e "${GREEN}✅ Demo 02 (Quarkus) complete!${RESET}"
echo
