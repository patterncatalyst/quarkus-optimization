# Adversarial MEDIUM/LOW fix plan — 2026-08-29

Branch `fix/adversarial-medlow`. Fixes MED/LOW from `adversarial-review-2026-08-29.md`.
Display-pos↔file: reviewer "slide21"→slide19.xml, "slide42"→slide40.xml,
"slide43"→slide41.xml, "slide45"→slide43.xml.
Decisions: M5 canonicalize on parse-log (26.7k/10.2k) → fix README only (deck already
consistent; no image5 re-render). M3 image6 → 2.5GB limit + heap ~1.9GB + JIT in formula.
DEFER L4 (image4 nit) + L9 (pacing).

## Deck XML (unzip/edit/rezip)
**M1 notesSlide30.xml:** `  Java 21 LTS. First with production Virtual Threads, Generational ZGC, mature AppCDS. If on 17, upgrade.` → `  Java 25 LTS. Java 21 introduced production Virtual Threads and Generational ZGC; Java 25 adds the Leyden AOT cache, JEP 491 (virtual threads no longer pin), and generational-only ZGC. If on 17 or 21, upgrade to 25.`
**M2 slide19.xml (Cryostat):**
- `# 2. Annotate your pod for auto-discovery:` → `# 2. Name a Service port &quot;jfr-jmx&quot; for auto-discovery:`
- `metadata:` → `spec:  # Service`
- `  annotations:` → `  ports:`
- `    cryostat.io/scrape_port: &quot;9097&quot;` → `    - name: jfr-jmx   # Operator discovers by this name (or port 9091)`
**M4 slide16.xml:** after `…0.83s → 0.22s.` insert ` (The two baselines are different demo apps: the AppCDS demo's minimal service starts ~0.49s; the Leyden demo's heavier app baselines ~0.83s.)` (keep rest). notesSlide16.xml: append `(baselines are different demo apps — AppCDS demo ~0.49s, Leyden demo ~0.83s).` to the BENCHMARK line before the Spring clause.
**M6 "default on JDK 25" → "only mode since JDK 24 (default since 23)":**
- slide12.xml: `Generational ZGC is the default on JDK 25 and preferred — any heap size` → `Generational ZGC is the only mode since JDK 24 (default since 23), preferred — any heap size`; `# generational: default on JDK 25` → `# generational: only mode since JDK 24`
- slide13.xml: `# === ZGC Container Settings (JDK 25 — generational is the default) ===` → `# === ZGC Container Settings (JDK 24+ — generational is the only mode) ===`; `-XX:+UseZGC   # generational is the default on JDK 25` → `-XX:+UseZGC   # generational: only mode since JDK 24`
- slide40.xml + slide41.xml: `# generational: default on JDK 25` → `# generational: only mode since JDK 24`
- notesSlide12.xml: `Generational is the default on JDK 25 — the old -XX:+ZGenerational flag is obsolete.` → `Generational is the only mode since JDK 24 (default since 23) — the old -XX:+ZGenerational flag is obsolete.`
- notesSlide13.xml: `ZGC block — generational is the default on JDK 25 (the old -XX:+ZGenerational flag is obsolete)` → `ZGC block — generational is the only mode since JDK 24, default since 23 (the old -XX:+ZGenerational flag is obsolete)`
- DO NOT touch: slide27, slide38 "JDK 21+", slide39, notesSlide42.
**L2 slide40.xml:** `PerformanceProfile requires Node Tuning Operator (OpenShift) or Performance Addon Operator` → `PerformanceProfile requires the Node Tuning Operator (OpenShift 4.11+; formerly the Performance Addon Operator)`
**L3 slide41.xml:** `~8% (LRB, since JDK 13)` → `~0–15%, workload-dependent (LRB)`; `~10–15% (reads)` → `~10–15%, workload-dependent (load barriers)`
**L8 slide43.xml:** `$100k+` → `~$38k`; `extrapolated to a 20-service cluster` → `20 services extrapolated from the 7-service demo ($13,455)`

## Diagrams (edit excalidraw + re-render + swap)
**M3 diagrams/02-jvm-memory-regions.excalidraw** (image6, 918×537):
- container-lbl `Container limit: 2 GB` → `Container limit: 2.5 GB`
- heap-bar-lbl `Heap\n~1.5 GB (75%)` → `Heap\n~1.9 GB (75%)`
- formula-txt: RHS `(Heap/0.75) + MaxMetaspaceSize + (threads × 1MB) + DirectBuffers + GC_overhead` → `Heap + MaxMetaspaceSize + JITCodeCache + (threads × 1MB) + DirectBuffers + GC_overhead`
**L1 diagrams/04-container-aware-jvm.excalidraw** (image1, 1924×980; post-render VISUAL CHECK, fallback DEFER if clipping):
- reads-cgroup text → x=620, width=320, y=452
- flags-after text → x=620, width=320, y=508
- node-after rect height 380→420; node-before rect height 380→420
- cgroup-note text y 510→548
Re-render both (excalidraw-brute-export-cli --scale 3 → Pillow LANCZOS to exact dims → in-place zip swap ppt/media/image1.png + image6.png). image5/image4: NO re-render.

## Demo files
**M5 quarkus-demo-05-grpc/README.md:** L77 `~31,000 rps | ~12,500 rps` → `~26,700 rps | ~10,200 rps`; L78 `~parity | ~parity | tie` → `gap narrows | ~parity to gRPC-ahead (varies run-to-run) | ~tie`; L86 `~31k vs ~12.5k rps at c=50` → `~26.7k vs ~10.2k rps at c=50`.
**L5 quarkus-demo-05-grpc/demo.sh (~L256):** `("Production pod-to-pod",       "baseline",          "✅ ~3-4× faster",   "gRPC"),` → `("Production pod-to-pod (proj.)","baseline",          "✅ ~3-4× (projection)","gRPC"),`
**L6 demo-01-heap-sizing/demo.sh (~L94):** replace the `docker run … | head -5 || { … }` with `| head -5` then `if [ "${PIPESTATUS[0]}" -ne 0 ]; then echo … exit code ${PIPESTATUS[0]} = OOMKill …; fi`.
**L7 delete** empty untracked dir `quarkus-demo-02-gc-monitoring/grafana/provisioning/{datasources,dashboards}` (rmdir).

## Acceptance
notesSlide30 recommends Java 25; slide19 uses jfr-jmx/9091 (no scrape_port); image6 regions sum ≤ drawn limit + formula has JIT term; slide16 explains 0.49 vs 0.83; deck gRPC unchanged (26.7k/10.2k), README aligned (no 31k/12.5k); no `default on JDK 25` in ppt/; slide40 PAO reworded; slide41 %s are ranges; slide43 ~$38k; image1 right panel clear of borders (visual check); demo-05 row labeled projection; demo-01 uses PIPESTATUS; stray dir gone. Deck opens, 56 slides.
