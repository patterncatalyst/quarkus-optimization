# HIGH-severity accuracy fix plan — optimizing-quarkus-on-kubernetes.pptx

**Date:** 2026-08-28 · **Branch:** fix/container-memory-slide-accuracy
**Scope:** HIGH-severity rows of `deck-accuracy-review-2026-08-28.md` + slide 16 "14×"
+ slide 12 "OpenJDK default". Slides 4–5 (commit 103ee00) and all MEDIUM/LOW items
untouched. 26 pptx entries + `_demos/demo-07-rightsizing.md`.

## Critical decision — T3 cost source of truth
**Chosen: `eval-2026-08-19/logs/demo-07.log`** (live `analyze.py` output — what the
audience sees when the demo runs; newest artifact; reproducible). Headline changes
**$80,640/yr → $13,455/yr**, nodes **4→2** becomes **6→2 (4 eliminated)**, density
**+67% → +225%**, monthly saving **$560 → $1,121**.
Rejected: deck's internal $6,720 formula (stale); keeping $80,640 (unsupported).

## Verified source-of-truth numbers
- **T3 (demo-07.log):** per-service — payment 2000→550m/−72%, 4096→2304Mi; fraud
  1500→500m/−67%, 2048→896Mi/−56%; order 1000→400m/−60%, 3072→2688Mi/−12%;
  inventory 500→300m/−40%, 1024→576Mi/−44%; email 500→200m/−60%; report-gen
  4000→900m/−78%, 8192→7808Mi/−5%; token 1000→400m/−60%, 1536→704Mi/−54%.
  Bin-pack: CPU 33,000→10,800m, Mem 70,656→50,624Mi, pods/node 4→13 (+225%),
  nodes 6→2. Cost: 4 eliminated; $1,682→$561/mo, saving $1,121/mo / $13,455/yr;
  ROI $13,455 for ~$269 ≈ 50×.
- **T2 (demo-03-fixed.log / demo-04-r25b.log):** AppCDS on Quarkus 485→493ms
  (−8ms, within noise ~0–5%); Leyden AOT 834→215ms (74%); Quarkus+AppCDS ~8.5×
  Spring Boot baseline (not 14×). Big win = Leyden (JDK 25), not AppCDS.
- **T4 (demo-05-parse.log):** localhost unary REST 26,667 vs gRPC 10,178 rps (REST
  wins); production projection gRPC ~3–4× throughput / ~73% p50.
- **T7:** PanamaResource.java:123 uses `allocateFrom` (not `allocateArray`);
  pom.xml:15 LangChain4j 1.18.1.
- **T6:** JEP 401 value classes first preview JDK 28, stable JDK 30+.
- **T5:** Shenandoah pauses 1–20ms (not sub-ms); G1 = upstream default, Shenandoah
  = Red Hat build default; LRB since JDK 13 (JEP 189), no Brooks pointer.

## Edit map (exact old→new strings)
The full run-by-run edit list is preserved in the planning agent transcript and is
reproduced to the executor. Groups:
- **A** T1 container/CPU: notesSlide3 (root cause), notesSlide39 (/proc/cpuinfo).
- **B** T5 GC facts: slide12 (Shenandoah "Sub-millisecond"→"1 – 20 ms" [2nd occ],
  "OpenJDK/RHEL default"→"Red Hat build default (G1 is upstream default)"); slide41
  ("Write barrier"→"Load-ref barrier" [1st occ], "Brooks ptr"→"LRB, since JDK 13");
  notesSlide41 (barrier narrative).
- **C** T2 AppCDS↔Leyden: slide16 (0.15–0.4s→Leyden; benchmark line→8.5×/Leyden),
  notesSlide15, notesSlide16, slide25 (55%→~75%, "with AppCDS"→"with Leyden AOT").
- **D** T4 gRPC: slide35 face (relabel table as production projection; localhost
  REST-wins 26.7k/10.2k), notesSlide35.
- **E** T3 right-sizing: slide44, notesSlide44, slide45 (recomputed util %),
  notesSlide45, slide46, notesSlide46, slide47, notesSlide47, + `_demos/demo-07-rightsizing.md`.
- **F** T7: slide49 (allocateFrom), slide50 (LangChain4j 1.18.1).
- **G** T6 Valhalla: slide51, notesSlide51, notesSlide52 (JDK 28 / JDK 30+).

## Mechanics
In-place zip entry update (same as the slide 4/5 fix): copy pptx → unzip the 26
entries → edit (occurrence-aware for duplicate strings) → `zip <copy> <26 entries>`
in one call → copy back. Edit the README directly. Do NOT full-re-zip.

## Duplicate-string hazards (occurrence-aware replace)
- slide12 `Sub-millisecond` ×2 → change 2nd (Shenandoah); keep 1st (ZGC).
- slide41 `Write barrier` ×2 → change 1st (Shenandoah); keep 2nd (G1).
- slide45 `of 27,200m usable` / `of 27,136Mi usable` ×2 each → before vs after.

## Acceptance criteria (grep + integrity)
- Absent anywhere: `$80,640`, `$6,720`, `2000m→560m`, `1500m→280m`, `4000m→3640m`,
  `14x/14× faster`, `Brooks ptr`, `allocateArray`, `LangChain4j 0.36`, `preview JDK 25+`,
  `~JDK 27-29`, `2,200 rps`, `8,500 rps`.
- Present: exactly one `Sub-millisecond` and one `Write barrier` remain deck-wide;
  slide16 `~8.5x`+`Leyden AOT cache (JDK 25)`; slide46 `$13,455`+`$1,121/month`;
  slide45 `33,000m`/`10,800m`/`+225% density`/`4 nodes eliminated`; slide49
  `allocateFrom`; slide50 `1.18.1`; Valhalla `JDK 28`/`JDK 30+`.
- README ↔ slides 44–47 agree (6→2 nodes, +225%, $1,121/mo, $13,455/yr).
- `unzip -t` clean; opens without repair; every changed entry well-formed (xmllint).

## Top risks
Duplicate over-replace (mitigated: occurrence-aware); slide45 recomputed
percentages (validator re-checks each ratio); $1 rounding on slide46 ($1,682 vs
6×$280) accepted/documented; entity/Unicode (−, →, ×, ·) preserved byte-for-byte;
scope leakage outside the 26 entries + README.
