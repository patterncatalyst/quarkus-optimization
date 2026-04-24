#!/usr/bin/env bash
# ============================================================
# Demo 09: Quarkus + LangChain4j ONNX + Panama FFM
# JDK 25 LTS / Quarkus 3.33.1 / all-MiniLM-L6-v2
#
# Shows:
#   1. AI inference running in-process — no Python, no sidecar
#   2. 384-dimension sentence embeddings via ONNX Runtime + Panama
#   3. Semantic similarity: related vs unrelated JVM alerts
#   4. Incident classification using embedding similarity
#   5. Ranked retrieval: "find similar past incidents"
#
# Prerequisites:
#   podman   (dnf install podman)
#
# Run: ./demo.sh
# First run downloads ~300MB Maven dependencies (ONNX Runtime + model).
# ============================================================
set -e

CYAN='\033[0;36m'; GREEN='\033[0;32m'; RED='\033[0;31m'
YELLOW='\033[1;33m'; BOLD='\033[1m'; RESET='\033[0m'

hr() { printf "%0.s─" {1..65}; echo; }

# Always run from the demo directory regardless of where it's invoked from
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"
hr_thin() { printf "%0.s·" {1..65}; echo; }

echo
echo -e "${CYAN}${BOLD}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  DEMO 09: LangChain4j ONNX + Panama — AI Inference in JVM   ║"
echo "║  JDK 25 LTS  ·  Quarkus 3.33.1  ·  all-MiniLM-L6-v2        ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${RESET}"

echo -e "${YELLOW}Stack:${RESET}"
echo "  Quarkus REST → LangChain4j API → ONNX Runtime Java → Panama FFM → native .so"
echo "  Model: all-MiniLM-L6-v2  (~25MB ONNX, bundled in Maven dep)"
echo "  No Python. No subprocess. No gRPC. In-process inference."
echo

# ── Step 1: Build ──────────────────────────────────────────────────────────────
hr
echo -e "${YELLOW}Step 1: Building image${RESET}"
hr
echo "  First run downloads ONNX Runtime (~250MB) + MiniLM model (~25MB)"
echo
if ! podman build -t quarkus-onnx-demo:latest .; then
  echo -e "${RED}✗ Build failed${RESET}"; exit 1
fi
echo -e "${GREEN}✅ Image built${RESET}"
echo

# ── Step 2: Start ──────────────────────────────────────────────────────────────
hr
echo -e "${YELLOW}Step 2: Starting container${RESET}"
hr
podman stop onnx-demo 2>/dev/null || true
podman rm   onnx-demo 2>/dev/null || true

podman run -d --name onnx-demo \
  -p 8080:8080 \
  --memory=1g \
  quarkus-onnx-demo:latest > /dev/null

echo -n "  Waiting for startup (model loads on first request)"
for i in {1..40}; do
  curl -sf http://localhost:8080/q/health/live >/dev/null 2>&1 && \
    echo -e " ${GREEN}✅${RESET}" && break
  echo -n "."; sleep 2
  [ $i -eq 40 ] && echo -e " ${RED}TIMEOUT${RESET}" && exit 1
done
echo

# ── Step 3: Model info ─────────────────────────────────────────────────────────
hr
echo -e "${YELLOW}Step 3: Confirming model + Panama FFM${RESET}"
hr
echo
curl -sf http://localhost:8080/info | python3 -m json.tool
echo

# ── Step 4: Embed a sentence ───────────────────────────────────────────────────
hr
echo -e "${YELLOW}Step 4: Generate a sentence embedding${RESET}"
hr
echo
echo -e "  ${CYAN}Embedding: 'OutOfMemoryError in heap space'${RESET}"
curl -sf "http://localhost:8080/embed?text=OutOfMemoryError+in+heap+space" \
  | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(f'  Text:       {d[\"text\"]}')
print(f'  Dimensions: {d[\"dimensions\"]}')
print(f'  Model:      {d[\"model\"]}')
print(f'  Vector:     [{d[\"vector\"][0]:.4f}, {d[\"vector\"][1]:.4f}, ... {d[\"vector\"][-1]:.4f}]  ({d[\"dimensions\"]} floats)')
"
echo

# ── Step 5: Semantic similarity ────────────────────────────────────────────────
hr
echo -e "${YELLOW}Step 5: Semantic similarity — related vs unrelated JVM alerts${RESET}"
hr
echo
echo -e "  ${BOLD}Related alerts (should be HIGH similarity):${RESET}"
echo -e "  a: 'OutOfMemoryError heap space'"
echo -e "  b: 'JVM ran out of memory GC overhead limit exceeded'"
curl -sf "http://localhost:8080/similarity?a=OutOfMemoryError+heap+space&b=JVM+ran+out+of+memory+GC+overhead+limit+exceeded" \
  | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(f'  Similarity: {d[\"similarity\"]:.3f}  →  {d[\"interpretation\"]}')
"
echo

echo -e "  ${BOLD}Unrelated alerts (should be LOW similarity):${RESET}"
echo -e "  a: 'OutOfMemoryError heap space'"
echo -e "  b: 'database connection pool exhausted'"
curl -sf "http://localhost:8080/similarity?a=OutOfMemoryError+heap+space&b=database+connection+pool+exhausted" \
  | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(f'  Similarity: {d[\"similarity\"]:.3f}  →  {d[\"interpretation\"]}')
"
echo

# ── Step 6: Incident classification ───────────────────────────────────────────
hr
echo -e "${YELLOW}Step 6: Classify an alert into an operations category${RESET}"
hr
echo
ALERT="Pod OOMKilled exit code 137 memory limit exceeded"
echo -e "  ${CYAN}Alert: '${ALERT}'${RESET}"
echo
curl -sf "http://localhost:8080/classify?alert=$(python3 -c "import urllib.parse; print(urllib.parse.quote('${ALERT}}'))")" \
  | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(f'  Category:   {d[\"category\"]}  (confidence: {d[\"confidence\"]:.3f})')
print()
print('  All scores:')
for k, v in sorted(d['allScores'].items(), key=lambda x: -x[1]):
    bar = '█' * int(v * 30)
    print(f'    {k:<25} {v:.3f}  {bar}')
" 2>/dev/null || \
  curl -sf "http://localhost:8080/classify?alert=Pod+OOMKilled+exit+code+137+memory+limit+exceeded" \
  | python3 -m json.tool
echo

# ── Step 7: Ranked incident retrieval ─────────────────────────────────────────
hr
echo -e "${YELLOW}Step 7: Find similar past incidents — ranked retrieval${RESET}"
hr
echo
echo "  Reference: 'Quarkus service restarted with OOMKilled status'"
echo "  Candidates: 5 past incident descriptions, ranked by semantic similarity"
echo
curl -sf -X POST http://localhost:8080/rank \
  -H "Content-Type: application/json" \
  -d '{
    "reference": "Quarkus service restarted with OOMKilled status",
    "candidates": [
      "Pod terminated due to memory limit exceeded in payment namespace",
      "JVM heap exhausted during peak load causing restart",
      "Database connection pool at maximum capacity",
      "CPU throttling detected on order-processor containers",
      "Kubernetes node ran out of memory evicted several pods"
    ]
  }' | python3 -c "
import sys, json
results = json.load(sys.stdin)
print('  Rank  Score   Incident')
print('  ────────────────────────────────────────────────────────')
for i, r in enumerate(results, 1):
    bar = '█' * int(r['similarity'] * 20)
    print(f'   {i}    {r[\"similarity\"]:.3f}  {r[\"text\"][:55]}')
    print(f'          {bar}  {r[\"interpretation\"]}')
    print()
"
echo

echo -e "  ${BOLD}This is the foundation of incident-aware RAG:${RESET}"
echo "  Embed alert descriptions → find semantically similar past incidents"
echo "  → retrieve their runbooks → feed into an LLM for remediation steps"
echo "  All running in your Quarkus pod, no Python, no external AI service."
echo

# ── Cleanup ────────────────────────────────────────────────────────────────────
hr
echo -e "${YELLOW}Stopping container...${RESET}"
podman stop onnx-demo >/dev/null
podman rm   onnx-demo >/dev/null
echo -e "${GREEN}✅ Demo 09 complete${RESET}"
echo
