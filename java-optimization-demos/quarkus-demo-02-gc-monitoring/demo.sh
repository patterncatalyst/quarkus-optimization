#!/usr/bin/env bash
# Demo 02 (Quarkus): GC Monitoring — Grafana LGTM Stack
# Quarkus 3.33.1 LTS / Java 21
# Observability: Prometheus + Grafana Tempo (OTLP traces) + Grafana dashboards

set -e
set -o pipefail
CYAN='\033[0;36m'; GREEN='\033[0;32m'; RED='\033[0;31m'
YELLOW='\033[1;33m'; BOLD='\033[1m'; RESET='\033[0m'
hr() { printf "%0.s─" {1..65}; echo; }

echo
echo -e "${CYAN}${BOLD}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  DEMO 02 (Quarkus): GC Monitoring — Grafana LGTM Stack      ║"
echo "║  Quarkus 3.33.1 LTS / Java 21                               ║"
echo "║  Traces → Grafana Tempo (OTLP)  |  Metrics → Prometheus     ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${RESET}"

wait_for() {
    local url=$1 label=$2 attempt=0
    echo -ne "${YELLOW}  Waiting for ${label}...${RESET}"
    until curl -sf "$url" > /dev/null 2>&1; do
        attempt=$((attempt + 1))
        [ $attempt -ge 60 ] && { echo -e " ${RED}TIMEOUT${RESET}"; return 1; }
        echo -n "."; sleep 3
    done
    echo -e " ${GREEN}✅${RESET}"
}

echo -e "${YELLOW}Step 1: Starting stack (Quarkus G1GC + ZGC + Prometheus + Tempo + Grafana)...${RESET}"
export DOCKER_BUILDKIT=1
docker compose up -d --build 2>&1 | grep -E "✓|Container|Network|Volume" | head -20 || \
    docker-compose up -d --build

echo
echo -e "${YELLOW}Step 2: Waiting for services...${RESET}"
wait_for "http://localhost:8080/q/health/live" "Quarkus G1GC (port 8080) — /q/health/live"
wait_for "http://localhost:8081/q/health/live" "Quarkus ZGC  (port 8081) — /q/health/live"
wait_for "http://localhost:9090/-/ready"        "Prometheus   (port 9090)"
# Tempo starts asynchronously — traces appear in Grafana ~30s after stack is up
echo -e "    Tempo starting async — traces visible in Grafana within ~30s"
wait_for "http://localhost:3000/api/health"     "Grafana LGTM (port 3000)"

echo
hr
echo -e "${BOLD}🎉 Stack ready!${RESET}"

echo -e "${YELLOW}Registering external Prometheus datasource in Grafana...${RESET}"
DS_PAYLOAD='{"name":"JVM Metrics (Prometheus)","type":"prometheus","url":"http://prometheus:9090","access":"proxy","uid":"ext-prometheus","isDefault":false,"jsonData":{"timeInterval":"5s"}}'
DS_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
    -X POST http://localhost:3000/api/datasources \
    -H "Content-Type: application/json" \
    -u admin:admin \
    -d "$DS_PAYLOAD")
# 200 = created, 409 = already exists (both are fine)
if [ "$DS_STATUS" = "200" ] || [ "$DS_STATUS" = "409" ]; then
    echo -e "  ${GREEN}✅ Datasource registered (HTTP $DS_STATUS)${RESET}"
else
    echo -e "  ${RED}⚠  Datasource registration returned HTTP $DS_STATUS${RESET}"
fi

echo -e "${YELLOW}Importing JVM GC dashboard into Grafana...${RESET}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DASH_FILE="$SCRIPT_DIR/grafana/dashboards/jvm-gc-dashboard.json"
if [ -f "$DASH_FILE" ]; then
    PAYLOAD=$(printf '{"dashboard":%s,"overwrite":true,"folderId":0}' "$(cat "$DASH_FILE")")
    STATUS=$(curl -s -o /tmp/gf_import.json -w "%{http_code}" \
        -X POST http://localhost:3000/api/dashboards/db \
        -H "Content-Type: application/json" \
        -u admin:admin \
        --data-binary "$PAYLOAD")
    if [ "$STATUS" = "200" ]; then
        URL=$(python3 -c "import json; d=json.load(open('/tmp/gf_import.json')); print(d.get('url',''))" 2>/dev/null)
        echo -e "  ${GREEN}✅ Dashboard ready: http://localhost:3000${URL}${RESET}"
    else
        echo -e "  ${YELLOW}⚠  Import returned HTTP $STATUS — use Grafana UI to import manually${RESET}"
        echo -e "  ${YELLOW}   File: grafana/dashboards/jvm-gc-dashboard.json${RESET}"
    fi
fi
echo
echo -e "  ${GREEN}Grafana:     http://localhost:3000${RESET}  (admin/admin)"
echo -e "  ${GREEN}Prometheus:  http://localhost:9090${RESET}"
echo -e "  ${GREEN}Tempo API:   http://localhost:3200${RESET}  (traces via Grafana Explore → Tempo)"
echo -e "  ${GREEN}G1GC App:    http://localhost:8080${RESET}  → metrics: /q/metrics"
echo -e "  ${GREEN}ZGC App:     http://localhost:8081${RESET}  → health:  /q/health/live"
echo
echo -e "${YELLOW}Traces: Grafana → Explore → Tempo datasource (pre-configured in otel-lgtm)${RESET}"
echo -e "${YELLOW}Open Grafana → 'JVM GC Monitoring' dashboard to compare G1GC vs ZGC${RESET}"
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
echo -e "${CYAN}=== Diagnosing available histogram metrics in Prometheus ===${RESET}"
sleep 5  # let Prometheus scrape the new GC data
echo "  GC pause buckets found:"
curl -sG "http://localhost:9090/api/v1/label/__name__/values" \
  | python3 -c "import json,sys; names=json.load(sys.stdin)['data']; [print('  '+n) for n in names if 'gc' in n.lower() and 'bucket' in n]" 2>/dev/null || echo "  (could not query Prometheus)"
echo "  HTTP request buckets found:"
curl -sG "http://localhost:9090/api/v1/label/__name__/values" \
  | python3 -c "import json,sys; names=json.load(sys.stdin)['data']; [print('  '+n) for n in names if 'http' in n.lower() and 'bucket' in n]" 2>/dev/null
echo "  All jvm_ metrics found:"
curl -sG "http://localhost:9090/api/v1/label/__name__/values" \
  | python3 -c "import json,sys; names=json.load(sys.stdin)['data']; [print('  '+n) for n in sorted(names) if n.startswith('jvm_')]" 2>/dev/null


echo
echo -e "${CYAN}=== Virtual threads: 500 tasks, 5ms each ===${RESET}"
curl -sf "http://localhost:8080/virtual-threads?tasks=500&workMs=5" 2>/dev/null \
    | python3 -c "import sys,json; d=json.load(sys.stdin); print(f\"  {d.get('taskCount','?')} VTs in {d.get('durationMs','?')}ms | peak platform threads: {d.get('peakPlatformThreads','?')}\")" 2>/dev/null || echo "  (check Grafana Explore → Tempo for the trace)"
echo
echo -e "  ${YELLOW}Grafana Explore → Tempo → search service: quarkus-gc-monitoring-demo${RESET}"

echo
hr
read -p "Press Enter to tear down..."
docker compose down -v
echo -e "${GREEN}✅ Demo 02 (Quarkus) complete!${RESET}"
echo