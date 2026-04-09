#!/usr/bin/env bash
# ============================================================
# Demo 1: Container-Aware JVM Heap Sizing
# Demonstrates the difference between untuned and container-
# aware JVM configuration on Kubernetes/OpenShift.
#
# Prerequisites: Docker Desktop (or any Docker-compatible runtime)
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

echo
echo -e "${CYAN}${BOLD}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  DEMO 01: Container-Aware JVM Heap Sizing                   ║"
echo "║  Taming the JVM: Optimizing Java on OpenShift               ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${RESET}"

echo -e "${YELLOW}Step 1: Building Docker images...${RESET}"
docker build -f Dockerfile.bad  -t jvm-demo:bad  . --quiet
docker build -f Dockerfile.good -t jvm-demo:good . --quiet
echo -e "${GREEN}✅ Images built${RESET}"
echo

hr
echo -e "${BOLD}${RED}SCENARIO A — JVM without container awareness${RESET}"
echo -e "${RED}Container limit: 512m | JVM flags: NONE${RESET}"
echo -e "Expected: JVM reads HOST memory and claims a huge heap"
hr
echo

# Run without container support — limit to 512m but JVM won't respect it
docker run --rm --memory=512m jvm-demo:bad 2>/dev/null || true

echo
echo -e "${YELLOW}(Notice the heap is >> 512m — the JVM read HOST RAM instead of the container limit!)${RESET}"
echo
read -p "Press Enter to continue to SCENARIO B..."
echo

hr
echo -e "${BOLD}${GREEN}SCENARIO B — Container-aware JVM (UseContainerSupport + MaxRAMPercentage=75)${RESET}"
echo -e "${GREEN}Container limit: 512m | Max heap: ~384m (75% of 512m)${RESET}"
echo -e "Expected: JVM correctly sizes heap to 75% of the 512m container limit"
hr
echo

docker run --rm --memory=512m jvm-demo:good 2>/dev/null | grep -v "^\[" || true

echo
echo -e "${GREEN}✅ Heap is now ~384m — respects the 512m container limit!${RESET}"
echo

hr
echo -e "${BOLD}SCENARIO C — Observe different container sizes${RESET}"
echo "Running the same good image with three different memory limits:"
echo

for mem in 256m 512m 1g; do
    echo -e "${CYAN}  -- Container limit: ${mem} --${RESET}"
    docker run --rm --memory=$mem jvm-demo:good 2>/dev/null \
        | grep -E "Max Heap|Heap \/ OS|⚠|✅" | sed 's/^/  /' || true
    echo
done

hr
echo -e "${BOLD}SCENARIO D — OOMKill simulation${RESET}"
echo -e "${RED}Run bad JVM in 256m container — likely to OOMKill during allocation${RESET}"
echo

cat <<'EOF'
# What would happen in Kubernetes:
#   kubectl describe pod java-app | grep -A5 "OOMKilled"
#
# Container LIMITS=256Mi, JVM tried to allocate 2GB heap
# → Linux OOM killer terminates the container
# → Kubernetes restarts pod (CrashLoopBackOff)
# → Pod never becomes Ready → alerts fire
EOF

echo
echo -e "${YELLOW}Simulating — the container will exit with OOMKilled (exit 137):${RESET}"
docker run --rm --memory=64m jvm-demo:bad 2>&1 | head -5 || {
    echo -e "${RED}  Container killed (exit code 137 = OOMKill) — exactly what Kubernetes does!${RESET}"
}

echo
hr
echo -e "${BOLD}KEY TAKEAWAY${RESET}"
echo "  Always add these flags to EVERY Java container:"
echo
echo -e "${GREEN}  -XX:+UseContainerSupport      # Read cgroup limits, not host RAM${RESET}"
echo -e "${GREEN}  -XX:MaxRAMPercentage=75.0      # Heap = 75% of container limit${RESET}"
echo -e "${GREEN}  -XX:InitialRAMPercentage=50.0  # Start at 50% to reduce startup footprint${RESET}"
echo -e "${GREEN}  -XX:NativeMemoryTracking=summary  # Enable 'jcmd VM.native_memory'${RESET}"
echo
echo -e "${YELLOW}In OpenShift, set via JAVA_OPTS env var in your Deployment:${RESET}"
cat <<'EOF'
  env:
  - name: JAVA_OPTS
    value: "-XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0"
  resources:
    requests:
      memory: "256Mi"
    limits:
      memory: "512Mi"
EOF
echo
echo -e "${CYAN}${BOLD}Demo 01 complete! 🎉${RESET}"
echo
