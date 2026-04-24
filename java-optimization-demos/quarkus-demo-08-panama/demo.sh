#!/usr/bin/env bash
# ============================================================
# Demo 08: Project Panama — C++20 → Quarkus via FFM
# JDK 25 LTS / Quarkus 3.33.1
#
# Shows:
#   1. C++20 library compiled to .so (cmake + g++)
#   2. Quarkus calls into it via Panama FFM — no JNI, no wrappers
#   3. Arena memory management — deterministic native memory lifetime
#   4. Three C++ functions called: GC recommendation, CPU profiling,
#      memory right-sizing
#
# Prerequisites:
#   podman   (dnf install podman)
#
# Run: ./demo.sh
# ============================================================
set -e

CYAN='\033[0;36m'; GREEN='\033[0;32m'; RED='\033[0;31m'
YELLOW='\033[1;33m'; BOLD='\033[1m'; RESET='\033[0m'

hr() { printf "%0.s─" {1..65}; echo; }

echo
echo -e "${CYAN}${BOLD}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  DEMO 08: Project Panama — C++20 → Quarkus via FFM          ║"
echo "║  JDK 25 LTS  ·  Quarkus 3.33.1  ·  C++20  ·  No JNI        ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${RESET}"

echo -e "${YELLOW}What Panama replaces:${RESET}"
echo "  JNI: Java + C header + C wrapper code + per-platform compile"
echo "  FFM: Pure Java — SymbolLookup + MethodHandle + Arena"
echo

# ── Step 1: Build ─────────────────────────────────────────────────────────────
hr
echo -e "${YELLOW}Step 1: Building C++20 library + Quarkus app${RESET}"
hr
echo "  Stage 1: g++ compiles jvmstats.cpp → libjvmstats.so"
echo "  Stage 2: maven builds Quarkus fast-jar"
echo "  Stage 3: UBI9 openjdk-25-runtime + ldconfig for library path"
echo
if ! podman build -t quarkus-panama-demo:latest .; then
  echo -e "${RED}✗ Build failed${RESET}"; exit 1
fi
echo -e "${GREEN}✅ Image built${RESET}"
echo

# ── Step 2: Start ─────────────────────────────────────────────────────────────
hr
echo -e "${YELLOW}Step 2: Starting container${RESET}"
hr
podman stop panama-demo 2>/dev/null || true
podman rm   panama-demo 2>/dev/null || true

podman run -d --name panama-demo \
  -p 8080:8080 \
  --memory=512m \
  quarkus-panama-demo:latest > /dev/null

echo -n "  Waiting for startup"
for i in {1..30}; do
  curl -sf http://localhost:8080/q/health/live >/dev/null 2>&1 && \
    echo -e " ${GREEN}✅${RESET}" && break
  echo -n "."; sleep 2
  [ $i -eq 30 ] && echo -e " ${RED}TIMEOUT${RESET}" && exit 1
done
echo

# ── Step 3: JVM info ───────────────────────────────────────────────────────────
hr
echo -e "${YELLOW}Step 3: Confirming JDK 25 + Panama FFM${RESET}"
hr
echo
curl -sf http://localhost:8080/info | python3 -m json.tool 2>/dev/null \
  || curl -sf http://localhost:8080/info
echo

# ── Step 4: The Panama demo ────────────────────────────────────────────────────
hr
echo -e "${YELLOW}Step 4: Calling C++20 from Java via Panama FFM${RESET}"
hr
echo
echo "  Three C++ functions called in one Arena scope:"
echo "    jvmstats_recommend_gc()    — analyse 500 GC pause samples"
echo "    jvmstats_cpu_profile()     — detect GC-dominated CPU spikes"
echo "    jvmstats_recommend_memory() — compute right-sized request"
echo "  All native memory allocated via Arena — freed on scope exit."
echo
echo -e "${CYAN}  GET /demo:${RESET}"
curl -sf http://localhost:8080/demo | python3 -m json.tool 2>/dev/null \
  || curl -sf http://localhost:8080/demo
echo

# ── Step 5: Custom GC analysis ────────────────────────────────────────────────
hr
echo -e "${YELLOW}Step 5: Custom GC pause data — POST your own array${RESET}"
hr
echo
echo "  Sending G1GC-shaped data (p99 ~180ms → expect G1GC recommendation):"
curl -sf -X POST http://localhost:8080/gc-recommend \
  -H "Content-Type: application/json" \
  -d '[10,12,15,11,14,180,12,9,13,11,175,10,14,12,190,11,13]' \
  | python3 -m json.tool
echo

echo "  Sending ZGC-shaped data (p99 ~0.3ms → expect ZGC recommendation):"
curl -sf -X POST http://localhost:8080/gc-recommend \
  -H "Content-Type: application/json" \
  -d '[0.1,0.2,0.15,0.3,0.12,0.18,0.25,0.09,0.14,0.3,0.11,0.2]' \
  | python3 -m json.tool
echo

# ── Step 6: What FFM looks like vs JNI ────────────────────────────────────────
hr
echo -e "${YELLOW}Step 6: FFM vs JNI — what we didn't have to write${RESET}"
hr
echo
cat << 'COMPARE'
  JNI approach (what we avoided):
  ─────────────────────────────────────────────────────────────────
  1. Write jvmstats.h                         ← done
  2. Write jvmstats.cpp                       ← done
  3. Write JNI wrapper jvmstats_jni.cpp       ← SKIPPED with Panama
     (JNIEXPORT, JNICALL, GetDoubleArrayElements, ReleaseDoubleArrayElements...)
  4. Compile wrapper per platform             ← SKIPPED with Panama
  5. Load with System.loadLibrary()           ← replaced by SymbolLookup
  6. Write Java native method declarations    ← replaced by MethodHandle
  7. Hope nothing segfaults                   ← Arena makes this safe

  Panama approach (what we actually wrote):
  ─────────────────────────────────────────────────────────────────
  SymbolLookup.libraryLookup("jvmstats", Arena.global())
  Linker.nativeLinker().downcallHandle(symbol, FunctionDescriptor.of(...))
  try (Arena arena = Arena.ofConfined()) {
      MemorySegment seg = arena.allocateArray(JAVA_DOUBLE, data);
      int result = (int) methodHandle.invoke(seg, data.length, ...);
  }
  // That's it.
COMPARE
echo

# ── Cleanup ────────────────────────────────────────────────────────────────────
hr
echo -e "${YELLOW}Stopping container...${RESET}"
podman stop panama-demo >/dev/null
podman rm   panama-demo >/dev/null
echo -e "${GREEN}✅ Demo 08 complete${RESET}"
echo
