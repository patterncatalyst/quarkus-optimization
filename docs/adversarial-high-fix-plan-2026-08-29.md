# Adversarial HIGH-fix plan — 2026-08-29

Branch `fix/adversarial-high`. Fixes the 5 HIGH findings from
`adversarial-review-2026-08-29.md` + co-located MEDIUM demo items.
User decisions: Spring→standardize on cited ~6.6s (delete fabricated 4.2→2.4);
Spring version→**4.1.0 everywhere (deck + demo)**; ZGC→reframe slides only;
Leyden canonical **834→215ms (~75%)**; slide-36 notes as drafted below.

## H1 — notesSlide36.xml: replace anti-pattern body with gRPC notes
Full replacement text (keep sldImg placeholder + ‹#› field; do NOT touch notesSlide54):

> REST vs gRPC — THE DIAGRAM — 24:00-26:00
> This diagram is the decision picture: one Quarkus service, two wire formats. Walk it left-to-right.
> THE TWO PATHS:
> - REST: HTTP/1.1 + JSON on :8080. Human-readable, browser/curl-friendly, passes every proxy. Metrics response ~200 bytes.
> - gRPC: HTTP/2 + Protobuf on :9000. Binary framing on one persistent connection; same payload ~40 bytes (~80% smaller). Contract-first: the .proto generates stubs at mvn compile.
> THE HONEST BENCHMARK: "On localhost, REST actually wins — ~26.7k rps vs ~10.2k for gRPC (demo-05, c=50). Not a typo." Why: loopback removes the network hop so gRPC's persistent HTTP/2 connection saves nothing; the payload is tiny so Protobuf's size win doesn't matter; and for simple unary calls HTTP/2 framing is heavier than HTTP/1.1.
> WHERE gRPC WINS (production projection — label it): pod-to-pod on a real network, the persistent HTTP/2 connection + binary framing compound to ~3-4x throughput / ~73% lower p50 (projection, not localhost). Streaming: server streaming is a Multi<MetricsResponse> return — no SSE glue. High concurrency: at c=500 gRPC already leads (~19.1k vs ~15.3k rps).
> DECISION RULE: public APIs / browsers → REST; internal service-to-service where you own both ends → gRPC. Same Quarkus app serves both — pick per endpoint, a trade-off not a rewrite.
> → Next: live demo — REST :8080 and gRPC :9000 from one JVM, compared with hey and ghz.

## H2 — Spring baselines (delete fabricated; standardize ~6.6s cited)
- slide16.xml face: OLD `📊  Quarkus benchmark: AppCDS ~0-5% on Quarkus (0.49s → 0.49s, within noise) vs Spring Boot: 4.2s → 2.4s. The ~75% Quarkus win is the Leyden AOT cache (JDK 25): 0.83s → 0.22s. Quarkus is ~8.5x faster than Spring Boot baseline.`
  NEW: `📊  Quarkus benchmark: AppCDS ~0-5% on Quarkus (0.49s → 0.49s, within noise). The ~75% Quarkus win is the Leyden AOT cache (JDK 25): 0.83s → 0.22s. Spring Boot baseline ~6.6s (Quarkus project benchmark, cited Cummins/quarkus.io — controlled Linux, not measured here): Quarkus JVM starts well under a second vs several seconds for Spring.`
- notesSlide16.xml: replace `~8.5x faster than Spring Boot's 4.2s baseline` sentence with the ~6.6s cited framing (~2.3x startup in the cited benchmark; laptop sub-second vs several seconds).
- notesSlide15.xml: OLD `Spring Boot 4-8s cold start vs Quarkus JVM 0.3-0.8s (10x faster!).` → NEW `Spring Boot ~6.6s vs Quarkus JVM 0.3-0.8s (2.3x faster startup in the cited Quarkus benchmark, 6.569 vs 2.919s; quote the sourced figure, not a laptop guess).` (keep the GraalVM-native aside)

## H3 — ZGC reframe (slides only; demo-06 code untouched)
- slide38.xml: `ZGC Generational — JDK 21+` → `ZGC Generational — JDK 21+ · STW-pause design target (JEP 439, JFR-verified)`; `&lt; 1 ms from GC` → `&lt; 1 ms (STW design target)` (leave the bare `< 1 ms` table cells).
- slide39.xml: `→ GC pauses &lt; 1ms` → `→ GC STW pauses &lt; 1ms (ZGC design target)`
- slide41.xml (footnote run): append to the `UBI 10 ships Shenandoah — override…explicitly` run: ` Pause figures are per-GC design targets (ZGC <1ms STW is a JEP/JFR target), not this deck's demo measurements.`
- slide42.xml (Demo 06 slide): `#  ZGC  pauses: sub-ms (design target)` → `#  ZGC  pauses: sub-ms per-pause STW (JFR, design target)`; `ZGC sub-millisecond pauses: invisible to HPA, invisible to users` → `ZGC per-pause STW is sub-ms by design (JFR); the demo's headline is a cumulative pause-delta (allocation stall on a 2-vCPU container), not per-pause STW`. (verify exact strings; grep first)

## H4 — Leyden diagrams re-render (834→215 / ~75%)
diagrams/03-aot-cache-progression.excalidraw:
- JDK25: `Baseline: ~350ms With cache: ~175ms + instant JIT warmup 🎯` → `Baseline: ~830ms With cache: ~215ms + instant JIT warmup 🎯`; `~40-55% startup +15-25% warmup 🏆` → `~75% startup +15-25% warmup 🏆`
- JDK24: baseline/cache → mark `projected` (no JDK24 measurement); `~40% startup improvement` → `~40% (projected)`
- JDK26: → `~830ms → ~215ms (projected)` / `Projected: JDK 25 result + ZGC support (JEP 516)`
- JDK21/AppCDS: `Baseline: ~350ms With cache: ~350ms Delta: ~0 (noise)` → `Baseline: ~490ms With cache: ~490ms Delta: ~0 (noise)`
diagrams/05-how-project-leyden-works.excalidraw:
- `✅ FIRST REQUEST served (~175ms)` → `(~215ms)`; `✅ FIRST REQUEST served (~350ms)` → `(~830ms)`
DIAGRAM-SPEAKER-NOTES.md: L135/236/237 `148ms`/`609ms` → `215ms`/`834ms`, keep ~75%.
Re-render image3→1065×487, image4→1100×618 (excalidraw-brute-export-cli --scale 3 → Pillow LANCZOS → in-place zip swap). rels unchanged.

## H5 — demo scripts / source / READMEs (+ folded MEDIUM + 4.1.0)
- Banners `Java 21`→`Java 25`: quarkus-demo-02/05/06/07/03 demo.sh; demo-03-appcds demo.sh. Re-pad ║…║ boxes.
- Spring hardcodes: quarkus-demo-03-appcds/demo.sh L159 `~4200ms`→`~6.6s (cited benchmark, not measured here)`, delete L160 `~2400ms (-43%)`, fix L161-162 mixed multiplier; quarkus-demo-04-leyden/demo.sh L123 drop/replace the Spring `~2700ms` row; demo-03-appcds/demo.sh L103-105/117/122-134/141 relabel fallbacks as estimate, replace hardcoded Quarkus 470/`~460ms` with measured ~485/493ms or drop block, `40-55%`→`~75%`.
- demo-04 Leyden `40-55%`→`~75%`: quarkus-demo-04-leyden/demo.sh L27, L139; append `(projected)` to non-JDK25 rows L26/138/140; optional fallback defaults 599/140→834/215.
- demo-07 README L108 `$150K–$500K/year` → `$13,455/year on this 7-service demo dataset (payback < 10 days); fleet extrapolation ~ $38K/yr at 20 services (labeled extrapolation).`
- demo-09 README L202/207 similarity → ~0.48/~0.27; recalibrate interpretation table to interpret() bands (0.65/0.50/0.40/0.30).
- appcds.enabled→aot.enabled: StartupResource.java L22, Dockerfile.baseline L22, demo-03-appcds/README.md L25, demo-03-appcds/demo.sh L28. ALSO fold: java-optimization-demos/README.md L175, QUARKUS-README.md L206, JVM-OPTIMIZATION-CHEATSHEET.md L120+L525.
- drop `-XX:+ZGenerational` (display strings only): quarkus-demo-06-latency/demo.sh L70,L291; quarkus-demo-07-rightsizing/analyze.py L302,L338.
- UBI9→UBI10 (COMMENTS only, do NOT flip functional FROM): quarkus-demo-08-panama/demo.sh L48, README.md L44.
- **Spring 4.0.5→4.1.0 EVERYWHERE (user decision):** demo-03-appcds/app/pom.xml L18 description, demo-03-appcds/README.md, demo-03-appcds/demo.sh, quarkus-demo-07-rightsizing/demo.sh L36; AND deck references — grep the pptx for `4.0.5` (slide44 "SB = Spring Boot 4.0.5", slide15, etc.) → `4.1.0`; and Java 21→25 in those same demo banner strings.

## Acceptance
No `4.2s`/`2.4s`/`~4200`/`~2400`/`~2700`/`8.5x`/`4-8s cold` Spring numbers remain; Spring = ~6.6s cited everywhere. notesSlide36 ≠ notesSlide54 (has gRPC notes). ZGC <1ms labeled design-target on 38/39/41/42; demo-06 code unchanged. image3/4 show 834→215/~75%, JDK24/26 "projected", dims 1065×487 / 1100×618. Banners Java 25; demo-07 README $13,455; demo-04 ~75%; demo-09 bands match code; aot.enabled everywhere; no +ZGenerational in display strings; UBI10 comment; Spring 4.1.0 in deck+demo. Deck opens, 56 slides. No `4.0.5` remains deck-wide.
