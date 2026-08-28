# Deck Augmentation & Currency Synthesis

**Date:** 2026-08-28
**Inputs:** the 4-reviewer accuracy sweep (`deck-accuracy-review-2026-08-28.md`),
the pasted "JVM-mode best practices" fact-check, a deck-vs-best-practices gap
analysis, and three authoritative-source comparisons — Evans' *Optimizing Cloud
Native Java* (O'Reilly 2024), Holly Cummins' Quarkus performance/sustainability
material, and Jack Shirazi's javaperformancetuning.com.

---

## The one theme every source converges on: **measurement integrity**

Three independent authorities land on the *same* weak spot, and it's the deck's
biggest credibility risk — not a cosmetic bug:

- **Evans** — his book's spine is "performance is an experimental science"; he
  literally names the **"Tuning by Folklore"** antipattern. The deck cites this
  book as its basis, yet ships fabricated/unsourced numbers (accuracy review T4
  gRPC, T2 AppCDS, T3 cost, "ZGC p99 <1ms measured live," GraalVM "17ms/60MB").
- **Shirazi (javaperformancetuning #308, 2026-07-27)** — don't trust laptop
  benchmarks (thermal throttling); pin the governor, disable Turbo Boost. The
  demos run on laptops (Fedora 41 / macOS) with no stated controls.
- **Cummins (quarkus.io/blog/new-benchmarks, Mar 2026)** — reproducible,
  transparent, controlled-Linux benchmarks with public scripts.

**Implication:** the HIGH-severity accuracy fixes (T2/T3/T4) are not just
correctness — they're what makes the deck consistent with its own cited sources.
And we can *replace* the fabricated numbers with real, cited, reproducible ones
(Cummins/Quarkus), rather than just deleting them.

---

## Decision buckets

### A. CHANGE / CORRECT (accuracy — already scoped as the HIGH-severity relay)
Covered by `deck-accuracy-review-2026-08-28.md`. Sources reinforce:
- **Purge/replace fabricated numbers (T2/T3/T4)** — Evans "Tuning by Folklore."
- **GC defaults** — "G1 = OpenJDK/HotSpot default; Shenandoah = Red Hat UBI
  default" (Evans ch05). Reinforces T5.
- **Startup attribution (T2)** — credit build-time processing + Leyden AOT, NOT
  AppCDS (Cummins build-time-work thesis + Evans AOT ch06; demo-03 prose already
  says this correctly — only the slides misattribute).

### B. AUGMENT (new content) — prioritized

| # | Add | Why / source | Effort |
|---|-----|--------------|--------|
| B1 | **"How we measured" methodology slide** (warmup, run counts, JMH for micro, localhost≠prod, thermal/laptop caveat) | Evans JMH ch + Shirazi #308. Highest leverage — inoculates the deck against its own T2/T4 weaknesses. | S |
| B2 | **Replace fabricated benchmarks with sourced figures** — Quarkus/Cummins: 2.7× tps, 2.3× startup, ~half memory; cite quarkus.io/blog/new-benchmarks, labelled as project benchmarks (not localhost) | Cummins. Directly fixes T4/T2 credibility. | M |
| B3 | **Execution-model decision slide** after slide 17 — blocking-worker (Quarkus REST + Hibernate ORM) / `@RunOnVirtualThread` / reactive (Mutiny + Hibernate Reactive), framed as a trade-off, NOT "rewrite to reactive for speed" | Gap analysis (K) + fact-check. Gives demo-05 Mutiny code a conceptual home; links VT↔streaming↔demo-06. | S (new slide) |
| B4 | **Native-image throughput caveat** wherever GraalVM native appears (slide 50, demo-09): "native ~halves throughput" | Cummins verified. Mirrors the honest gRPC caveat the deck already uses; also fixes slide 50's unmeasured "17ms/60MB" (accuracy review). | S |
| B5 | **Allocation-reduction beat in the low-latency section** — reduce garbage first (preallocation, primitive collections/no-boxing, buffers) *then* pick a low-pause GC; tie Valhalla (slides 51–52) in as the no-boxing future | Shirazi #306. Deck's low-latency story is "pick ZGC" only; it has the Valhalla tech but never connects the principle. | S–M |
| B6 | **Carbon/energy framing on right-sizing** (demo-07 / slides 43–47) — convert node savings to kWh/CO2 (~2–3× carbon cut); "green = cheaper" | Cummins green-java + cloud-footprint. Differentiated, on-source; strengthens the section once T3 math is fixed. | M |
| B7 | **Extend slide 17** to place `@RunOnVirtualThread` on the execution-model spectrum; fold in the T8 `jvm.threads.live` correction | Gap analysis. | S |
| B8 | **JFR/async-profiler beat** in observability — "monitor (Grafana) → diagnose (JFR)" loop | Evans profiling ch + Shirazi methodology. Deck monitors but never diagnoses. | M |
| B9 | *(optional/low)* Cloud-zombies / scale-to-zero mention; Java-25-as-free-upgrade line; "remove unused extensions" anti-pattern bullet | Cummins; fact-check | S each |

### C. CITE / ATTRIBUTION (README + slides)
- **Complete the Evans citation** (README ~L212): "Evans, B. J., & Gough, J.
  *Optimizing Cloud Native Java*, 2nd ed., O'Reilly, 2024 (ISBN 9781098149345)."
- **Verify SRE book** (README): Schneider, J., *SRE with Java Microservices*,
  O'Reilly 2020 (ISBN 9781492073925) — confirmed correct as cited.
- **Add javaperformancetuning.com** to companion reading — scope to the *living
  newsletters* (#308 methodology, #306 low-latency, #307 LLM), NOT the dated
  late-J2EE tips taxonomy.
- **Fix any "Evans / Red Hat"** → Evans is at **New Relic** (Cummins is Red Hat).
- **Attribution nuance:** the new-benchmarks figures are Quarkus *project*
  benchmarks Cummins popularizes — cite as "Quarkus project benchmarks, cited by
  Cummins," not as her personal measurements.

### D. LEAVE OUT (dubious as JVM-mode "best practices")
From the pasted text — fact-check + gap analysis agree these are weak or
misleading additions to a JVM/container talk:
- **Reflection / Jandex / @RegisterForReflection** — a *native-image* concern
  mislabeled as JVM-mode (nothing strips reflection in JVM mode).
- **ArC constructor-vs-field injection** — resolved at build time; ~zero runtime
  perf; design-quality point, not an optimization lever.
- **Agroal pool sizing** — no datasource in any of the 9 demos; adding numbers
  with no backing demo would repeat the fabricated-benchmark problem.
- **"Rewrite to reactive for speed"** — workload-dependent; virtual threads give
  most of the scalability with imperative code. Keep the decision framed as a
  trade-off (B3), not a mandate.
- **The pasted text's invented rationales** — VT "gives C2 CPU to warm up,"
  reactive "worker threads yield CPU," "native JVM metadata compression" — do
  not reproduce; they're wrong.

---

## Currency deltas to weave in (from the fact-check)
- **RESTEasy Reactive → "Quarkus REST"** (renamed Quarkus 3.9). *Deck already uses
  the current name* — no rename work; just use it in the B3 slide.
- **JEP 491 (JDK 24, in 25 LTS)** — `synchronized` no longer pins carrier
  threads; the classic "avoid synchronized on virtual threads" advice is obsolete;
  the Agroal pool becomes the real concurrency bound. Relevant to B3.
- **JEP 519 compact object headers (JDK 25, opt-in, ~33% smaller, NOT with ZGC)**
  — the real feature behind the pasted text's "metadata compression"; optional
  mention in memory section.
- **Generational Shenandoah productized JDK 25 (JEP 521); generational ZGC default
  since JDK 23 (JEP 474)** — reinforces T5 (`+ZGenerational` obsolete on JDK 25).

---

## Bottom line
- **Verdict: AUGMENT, don't restructure.** The deck owns the JVM/container core;
  the gaps are (1) measurement discipline, (2) allocation reduction, (3) the
  execution-model decision, (4) native/sustainability honesty.
- **Sequence:** land the HIGH-severity accuracy fixes first (they're the
  credibility floor and are prerequisite to B2/B4), then the B-bucket additions.
- **Highest-leverage single addition: B1 "How we measured"** — it's what turns
  the deck's biggest liability (folklore numbers) into a strength, and it's
  squarely on-source with the book the talk is based on.
