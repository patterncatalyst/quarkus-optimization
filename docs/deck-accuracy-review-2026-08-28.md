# Deck Accuracy Review — optimizing-quarkus-on-kubernetes.pptx

**Date:** 2026-08-28
**Scope:** Full deck (slides 1–54), both slide faces AND speaker notes. Three
dimensions: claim accuracy (vs the repo's own `eval-2026-08-19/logs/` and demo
READMEs), technical correctness (JEPs/JDK milestones/GC facts, web-verified), and
face↔notes consistency.
**Method:** 4 parallel Opus reviewers by slide range + consolidation.
**Excluded:** slides 4–5 (container-memory) — fixed separately in commit
`103ee00` on branch `fix/container-memory-slide-accuracy`.

> **Meta-finding:** The `eval-2026-08-19` logs are newer than much of the deck.
> Several benchmark/cost numbers predate the current tooling, and the `_demos/*.md`
> READMEs carry the *same* stale numbers — so fixes must propagate to the READMEs
> too, not just the slides.

---

## Themes (highest impact first)

### T1 — Container/CPU awareness misconception (same class as the slide 4/5 fix)
The `/proc/meminfo` / `/proc/cpuinfo` "no flags → grabs host resources" framing
recurs. `UseContainerSupport` is default-on since JDK 10 / 8u191; the host-resource
fallback happens on *no limit set / cgroup unreadable / support disabled*.

### T2 — AppCDS overstated & conflated with Leyden
The deck repeatedly credits **AppCDS** with 30–50% / 50% / 55% Quarkus startup
cuts and "0.6s→0.3s / 14×". The deck's **own eval** shows AppCDS on Quarkus is
within noise (−8ms, ~0–5%). The real ~75% win is the **Leyden AOT cache (JDK 25,
demo-04)**, which the slides conflate with AppCDS.

### T3 — Right-sizing cost math is internally broken AND stale
`$80,640/year` contradicts its own formula/breakdown ($6,720) and the eval
($13,455). `$6,720/month` appears where `$6,720` is the *annual* figure. The whole
per-service + bin-packing dataset (slides 44–46) predates the current `analyze.py`.

### T4 — gRPC benchmark numbers fabricated / unsourced
Slide 35's REST-vs-gRPC table (2,200 vs 8,500 rps, −79% p99) matches no source and
contradicts the eval (REST *wins* localhost unary ~31k vs ~12.5k). Localhost caveat
missing from the face; notes contradict themselves.

### T5 — GC facts outdated
Shenandoah "sub-millisecond" + "OpenJDK default" (both wrong); Shenandoah
"write-barrier / Brooks ptr" (wrong since JDK 13 LRB); `-XX:+ZGenerational`
obsolete on JDK 25.

### T6 — Valhalla timeline wrong
JEP 401 value classes are **not** previewable on JDK 25 — first preview is JDK 28;
"stable ~JDK 27–29" impossible.

### T7 — Version drift (already catalogued separately)
JDK 21 / UBI9 labels vs the JDK 25 / UBI10 the demos actually build on; plus
LangChain4j "0.36+" (actual 1.18.1) and Vector API "JEP 460" (JDK 25 = JEP 508).

### T8 — Observability / misc technical errors
LGTM "M = Prometheus" (it's Mimir); virtual threads "appear in jvm.threads.live"
(they don't); face↔notes disagree on the Micrometer extension.

---

## HIGH severity (fix before presenting)

| Slide | Loc | Theme | Claim | Correct |
|-------|-----|-------|-------|---------|
| 3 | face | T1 | "Default JVM reads host RAM — 25% of 256 GB node = 64 GB heap" | With a limit set, container support (JDK 10+) caps heap at % of the *limit*; host-grab only with no limit |
| 3 | notes | T1 | "Root cause: nobody added UseContainerSupport" | It's default-on; real cause is MaxRAMPercentage too high / no limit headroom |
| 39 | notes | T1 | "JVM reads /proc/cpuinfo, 64 GC threads for 2-CPU limit" | With a CPU *limit*, JVM sizes to it; over-provision only with request/no-limit |
| 12 | face | T5 | Shenandoah "sub-millisecond" + "OpenJDK default" | 1–20ms; Red Hat UBI default (G1 is upstream default) |
| 14/15/16/25 | both | T2 | AppCDS gives Quarkus 30–55% / "0.6→0.3s" / "14×" | AppCDS on Quarkus ~0–5% (noise); ~75% win is Leyden (JDK 25) |
| 16 | face | T2 | "Quarkus+AppCDS 14× faster than Spring Boot" | ~8.5× (eval), and independent of AppCDS |
| 35 | face | T4 | gRPC table 2,200 vs 8,500 rps, −79% p99 | Unsourced; eval shows REST wins localhost; use production ~3–4× / ~73% p50, label as projection |
| 44 | face | T3 | Per-service cuts (fraud −81%, report-gen "keep large" 3640m) | Stale; eval: fraud 500m/−67%, report-gen 900m/−78% |
| 45 | face | T3 | "2 nodes eliminated / $6,720/month / 15,000m→5,455m" | Eval: 6→2 (4 elim), $1,121/mo, 33,000m→10,800m |
| 46 | face+notes | T3 | "$80,640 annual saving" | Own formula = $6,720; eval = $13,455 |
| 47 | face+notes | T3 | "$6,720/month, 17× ROI" | $6,720 is *annual* (17× = annual/$400) |
| 41 | face+notes | T5 | Shenandoah "write barrier / Brooks ptr (~8%)"; ZGC "load barrier, higher overhead" | JDK 13+: Shenandoah uses LRB, no Brooks ptr; both use load barriers |
| 49 | face | T7/code | `arena.allocateArray(JAVA_DOUBLE, data)` | Final FFM API is `allocateFrom(...)`; `allocateArray` won't compile (JDK 22+) |
| 50 | face | T7 | "LangChain4j 0.36+" | Demo pins 1.18.1 |
| 51/52 | face+notes | T6 | "Value classes preview on JDK 25" / "stable JDK 27–29" | JEP 401 first preview JDK 28; stable JDK 30+ realistic |

## MEDIUM severity

| Slide | Loc | Theme | Issue |
|-------|-----|-------|-------|
| 12/13 | face | T5/T7 | `-XX:+ZGenerational` obsolete on JDK 25 (generational default since JDK 23, flag removed JDK 24) |
| 10 | face+notes | T1 | `ParallelGCThreads = host CPU` oversimplifies (formula caps >8 cores; container reads quota) |
| 8 | face | T1 | `ActiveProcessorCount` "prevents 0 GC threads" — JVM floors at 1; real purpose is override |
| 14 | notes | T2 | PetClinic "2s→1s = 40%" — JEP 483 is 4.5s→2.6s (~42%); 2→1 is 50% |
| 17 | face | T8 | "virtual threads appear in jvm.threads.live" — they don't (ThreadMXBean = platform only) |
| 18 | face | T8 | "LGTM = … + Prometheus" — the M is **Mimir** |
| 20 | notes | T8 | Notes use legacy `quarkus-micrometer-registry-prometheus`; face uses unified `quarkus-micrometer-opentelemetry` |
| 29 | notes | consistency | "14× faster than Spring Boot" vs "5–10×" everywhere else |
| 42 | face | T4 | "ZGC p99 <1ms measured live" — eval has no p99; deltas were 4–76ms |
| 44 | notes | T3 | "546m rounded to 560m" — analyze.py rounds to 550m |
| 48 | face | T7 | "Vector API JEP 460" — JDK 25 = JEP 508 |
| 49 | face | tech | "C++21" — no such standard (span/ranges are C++20; slide's own flag is `-std=c++20`) |
| 51 | face | T6 | "Stable ~JDK 27–29" impossible given JDK 28 first preview |
| 54 | face | tech | "MaxMetaspaceSize=256m" contradicts slide 53's "leaks to 800MB+"; would OOM |

## LOW severity (polish / consistency)

| Slide | Loc | Issue |
|-------|-----|-------|
| 1 | face | "Java 21" title vs JDK 25 runtime (T7) |
| 3 | face | "4–8s typical cold start" vs repo's ~600ms Quarkus / ~2.7s Spring |
| 3 | face/notes | "2–3×" vs "2–4×" overprovisioning; unsourced "60% Red Hat data" |
| 6 | face/notes | "six regions" but slide lists five; Leyden "pre-fills JIT code cache" imprecise |
| 9 | face | "-Xmx8192m (default)" — no such default; effective 25% of 32GB node |
| 10 | face | "100ms→400ms under throttle" illustrative, not measured |
| 16 | face | "CDS enabled by default (Java 21)" — actually since JDK 12 (JEP 341) |
| 31 | face | JEP 516 "previously G1GC only" — was ZGC-incompatible; other GCs worked |
| 34 | face | JSON "~400 bytes" vs demo's ~220 bytes |
| 37 | notes | "38% less CPU" unsourced (not measured in demo-05) |
| 41/42 | face/notes | UBI9 / Java 21 labels (T7) |
| 43 | notes | "real Prometheus data on 7-service cluster" — actually bundled synthetic sample data; 7 vs 20-service inconsistency |
| 44 | face | "+30% headroom" headline — memory is 25%; p95 basis when GC-dominated |
| 47 | notes | GC-spike threshold "4×" vs code/face "3×" |
| 49 | face | jextract `$MH()` — modern jextract emits `$handle()`; demo hand-writes downcall (no jextract) |
| 50 | face | GraalVM native "17ms / 60MB RSS" not built/measured; 60MB implausibly low |
| 51 | face | "int[] 8 bytes × N" — int is 4 bytes |
| 53/54 | face | Footer numbering "29/26", "30/26" exceeds total |

---

## Notes
- All benchmark cross-checks are against `eval-2026-08-19/logs/*.log` and
  `_demos/*.md` / `java-optimization-demos/**/README.md`.
- JEP/JDK/GC facts web-verified against openjdk.org, Red Hat Developer, inside.java.
- The right-sizing numbers (T3) and several benchmarks are stale in BOTH the deck
  and the `_demos` READMEs → regenerate from `analyze.py` / re-run the demos.
