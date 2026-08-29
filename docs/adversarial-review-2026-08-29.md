# Adversarial Review — 2026-08-29

Four independent reviewers, **all on non-Opus models** (Sonnet ×4; Fable/Haiku
were unavailable — 403 data-sharing), deliberately excluding the Opus that
authored the deck. Scopes: presentation, demos, diagrams, holistic. Each told to
distrust prior fixes and re-check with evidence. Cross-corroboration between
reviewers + inline verification (rels, diffs, log lines, JEPs) noted per item.

## FALSE POSITIVE (verified NOT real — do not act)
- **"Swapped images" (holistic #1).** Claimed slide7↔slide36 images were swapped.
  VERIFIED FALSE: slide7 ("JVM Memory Regions")→image6 (memory diagram) ✓;
  slide36 ("REST vs gRPC")→image5 (gRPC diagram) ✓ — confirmed by rels + direct
  re-view of both PNGs + Reviewer C's independent mapping. The holistic reviewer
  mislabeled which image was which.

## HIGH — fix before presenting
1. **`notesSlide36` orphaned notes** (A + holistic, verified byte-identical to
   notesSlide54). The "REST vs gRPC" slide's speaker notes are the Anti-Pattern
   Remediation talking points. → Write real gRPC notes for slide36.
2. **Spring Boot baselines fabricated & inconsistent** (A). "4.2s→2.4s" shown
   under "📊 Quarkus benchmark" but no Spring demo runs; demo-03.sh hardcodes
   ~4200ms, demo-04.sh hardcodes ~2700ms, Cummins-cited real fig is 6.569s,
   slide16 notes say "4–8s" — four different Spring baselines. Violates the
   deck's own "How We Measured" slide. → Use ONE sourced Spring number
   (Cummins 6.569s) consistently, or label all as illustrative-not-measured.
3. **ZGC "<1 ms" vs demo-06's own data** (A + holistic). Slides 38/39/40/41/43/44
   assert sub-ms; demo-06 measured 169ms cumulative pause delta (ZGC worse than
   G1 in 2/5 rounds). Reviewer A's key insight: the demo's "pause delta" metric is
   itself flawed — it measures allocation-stall on a CPU-starved 2-vCPU container,
   not true STW pause. → Two fixes: (a) caveat the slides that <1ms is ZGC's
   JEP/JFR STW design target, distinct from the demo's cumulative-delta metric;
   (b) fix or reframe the demo-06 metric.
4. **image3/image4 Leyden numbers wrong** (C, my PR#4 under-fix). Diagrams show
   "~350ms→175ms / 40–55%"; real eval is ~830ms→215ms (~75%), and
   DIAGRAM-SPEAKER-NOTES says 609→148 (75%). → Re-render 03-aot-cache-progression
   + 05-how-project-leyden-works with the real ~75% / measured numbers.
5. **Demo-script/README surface never swept** (B). demo.sh banners still "Java 21"
   (02/03/05/06/07); demo-07 README "$150K–$500K/yr" (real $13,455); demo-04.sh
   prints real ~74% then a hardcoded "40–55%" table; demo-03 Spring companion
   hardcodes a fabricated Quarkus comparison (470/"~460ms") + pom parent 4.1.0 vs
   description "4.0.5"; demo-09 README similarity "~0.80–0.90" (code recalibrated,
   real 0.477). → Sweep demo.sh banners + demo READMEs + app-source comments.

## MEDIUM
6. **Q&A note recommends "Java 21 LTS"** (holistic, notesSlide30) — contradicts the
   Java-25 talk. My version sweep kept it as "historical"; as Q&A advice it's wrong.
7. **Dual Quarkus baseline 0.49s vs 0.83s** (holistic, slide16) — both called
   "baseline," unexplained (different packaging: AppCDS demo ~485ms vs Leyden ~834ms).
8. **gRPC numbers inconsistent** (A + C): deck/image5 use 26.7k/10.2k
   (demo-05-parse.log); README + demo-05.log say 31k/12.5k; c=500 flips to parity.
   → Reconcile to one number (or a range) + note variance/c=500. Touches slide35
   text, slide37, image5.
9. **"Generational ZGC default on JDK 25" imprecise** (A, slides 13/14/42 — my
   version-sweep wording). Default since JDK 23 (JEP 474); non-gen removed JDK 24
   (JEP 490). → "generational is the only mode since JDK 24 (default since 23)".
10. **Cryostat discovery annotation wrong** (A, slide21). `cryostat.io/scrape_port:
    "9097"` isn't a real mechanism → use a `jfr-jmx`/9091 Service port or the
    Operator's `cryostat.io/name` / `callback-port` (9977) Agent labels.
11. **image6 memory math** (C): six regions sum ~2.1GB > the "2 GB limit" drawn;
    sizing formula omits the JIT-cache term.
12. **`appcds.enabled` (wrong property) still in demo source** (B):
    StartupResource.java, Dockerfile.baseline, demo-03 README/demo.sh → `aot.enabled`.
13. **`+ZGenerational` in demo-06/07 demo.sh banners** (B) — obsolete on JDK 25.
14. **demo-08 comment says "UBI9"** for a UBI10 runtime stage (B).
15. **DIAGRAM-SPEAKER-NOTES*.md still say "20–30%"** for AppCDS (C).
16. **demo-04 `./mvnw` referenced but absent; stray `app/Dockerfile` w/ invalid
    `COPY … 2>/dev/null`** (B).

## LOW
- image1 right-panel text clipping/strikethrough over box borders (C — pre-existing;
  exact fix coords provided).
- image4 app.aot arrow cramped (C).
- Performance Addon Operator stale, folded into NTO since OCP 4.11 (A, slide42).
- Shenandoah "~8%" / ZGC "10–15%" precise overhead %s unsourced (A, slide43).
- demo-05 "3–4×" uncited (B); demo-01 `head` masks OOMKill exit code (B); demo-02
  stray `{datasources,dashboards}` dir (B).
- Flow/pacing: demos bunched at end vs agenda; no consistent bonus-boundary
  divider; slide45 "$100k+" over-sells vs slide48's $13,455/7-svc (~$38k at 20) (holistic).

## Held up clean under scrutiny (verified correct)
JEP citations (483/514/515/516, 491, 401, 454/442 FFM timeline); ParallelGCThreads
formula (8+(N-8)×5/8, 43-thread example); demo-07 cost arithmetic (traces to
analyze.py); both O'Reilly book citations; `quarkus.package.jar.aot.enabled`;
cgroup v1/v2 + OCP 4.14 facts; app.aot 50-150MB; HPA remediation details;
allocateFrom; LangChain4j beta28; Grafana provisioning present.

## Meta
The review found real issues the Opus-authored passes missed or introduced:
the entire demo-script surface (never swept), the ZGC-vs-demo contradiction (+ a
flawed demo metric), Spring-baseline fabrication, the under-fixed diagram Leyden
numbers, notesSlide36's orphaned notes, the Q&A Java-21 line, and the imprecise
"default on JDK 25" wording I introduced. It also correctly ruled out one false
alarm (swapped images). Independent, non-creator eyes were worth it.
