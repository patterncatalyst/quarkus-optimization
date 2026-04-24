# Excalidraw Diagrams — Speaker Notes & Slide Placement

These diagrams are designed as **supplementary visuals** — use them as:
- A live whiteboard moment during Q&A ("let me draw this out")
- A pre-shared handout alongside the slide deck
- A reference for deeper-dive sessions or workshop settings
- Backup slides if you want to add a "pause and explain" moment

**Deck reference:** All slide numbers refer to the 54-slide deck
`optimizing-quarkus-on-kubernetes.pptx` (30 core slides + 24 bonus slides).

---

## Diagram 01 — GC-Induced HPA Thrash Cycle

**File:** `01-gc-hpa-thrash-cycle.excalidraw`

### Where it fits in the deck
- **Primary:** After slide **10** (GC in Containers) and slide **11** (GC-Induced HPA Thrash Cycle visual)
- **Optional:** Open during live Q&A when someone asks "why can't I just use CPU-based HPA?"
- Works well as a whiteboard trace-through — point to each box as you narrate the story
- Also relevant after slide **21** (HPA with JVM-Aware Metrics) as the "why" behind the KEDA recommendation

### Speaker Notes

> "I want to show you why CPU-based HPA and the JVM are a dangerous combination. This is a loop that I have seen take a cluster from 3 pods to 20 pods with zero actual load increase."

Walk box by box:

**① Normal Operation**
> "Everything is fine. Your app is running. GC pauses are under 200ms. Requests are being served."

**② GC Pause**
> "A normal GC cycle fires. This is not a problem — this is expected JVM behaviour. But during stop-the-world, all application threads halt. The GC threads hammer the CPU. You spike to 100% CPU for 50-200ms."

**③ HPA Scales Out**
> "HPA is watching CPU utilisation on a 30-second scrape interval. It sees a spike over your threshold and adds three new pods. This is the wrong response — the spike was GC, not load."

**④ New Pods Also GC**
> "Each new pod starts cold. They all do JVM bootstrap and JIT warmup. They ALL spike CPU during their startup GC cycles. This looks to HPA like sustained high CPU."

**⑤ HPA Scales Again**
> "HPA adds three more pods. Those pods spike. And so on."

**⑥ Cost Explosion**
> "I have seen this reach 20 pods for a 3-pod workload. Your on-call engineer wakes up, sees the alerts, sees 20 pods, and has no idea why. The root cause is that HPA was given the wrong metric."

**The Fix panel**
> "Two things together solve this. First, change the HPA metric to RPS — requests per second. RPS is completely unaffected by GC CPU spikes. Second, add stabilisation windows. `stabilizationWindowSeconds: 120` on scale-up means HPA will wait 2 minutes before acting on a CPU spike. That's longer than any normal GC pause. Together these make HPA work correctly for Java."

---

## Diagram 02 — JVM Memory Regions Breakdown

**File:** `02-jvm-memory-regions.excalidraw`

### Where it fits in the deck
- **Primary:** After slide **6** (JVM Memory Regions) as a deeper visual reference
- **Use case:** Whenever audience members ask "how do I calculate my container limit?"
- Particularly effective in workshops — walk through the sizing formula live

### Speaker Notes

> "This diagram is the answer to the most common question I get after talks: 'how do I actually calculate my container memory limit?'"

**Point to the left bar first:**
> "This is your container. Let's say it's 2 GB. Most people set MaxRAMPercentage=75 and think they're done. But look at what actually lives inside that 2 GB."

**Heap (green)**
> "The heap is only one of six regions. MaxRAMPercentage=75 gives you 1.5 GB of heap. But the JVM needs memory for five other things, and most of them are completely ignored at sizing time."

**Metaspace (orange)**
> "Metaspace holds class metadata — method bytecodes, field descriptors, constant pool entries. Without `-XX:MaxMetaspaceSize`, this grows unbounded. I have seen Metaspace eat 800 MB on a framework-heavy application. Set the limit. A good starting point is 256m."

**Thread Stacks (purple)**
> "Every platform thread gets 1 MB of stack by default. If you have 200 threads — totally normal for a REST service — that is 200 MB of off-heap memory that most sizing calculations miss entirely. This is why Quarkus Virtual Threads matter for container sizing: virtual thread stacks live in the heap as tiny continuations, not 1 MB stacks."

**JIT Code Cache (red)**
> "HotSpot compiles hot methods to native code and stores them here. Typically 128-256 MB. Project Leyden pre-populates this cache so the JIT starts compiling hot paths immediately rather than waiting for profiling data."

**Direct ByteBuffers and GC overhead**
> "These are the ones that cause surprise OOMKills. Netty — which Quarkus uses under the hood via Vert.x — allocates direct buffers off-heap. Kafka clients do the same. GC bookkeeping structures add another 50-100 MB. None of these are bounded by your heap setting."

**Sizing formula**
> "The formula at the bottom is the one I use: container limit equals heap divided by 0.75, plus MaxMetaspaceSize, plus threads times 1 MB, plus your direct buffer budget, plus GC overhead. Measure first with `jcmd <pid> VM.native_memory summary`. Then budget. Then set limits."

---

## Diagram 03 — AOT Cache Progression: CDS → AppCDS → Leyden

**File:** `03-aot-cache-progression.excalidraw`

### Where it fits in the deck
- **Primary:** After slide **14** (The AOT Cache Progression visual) and slide **16** (AOT Caching detail)
- **Secondary:** After slide **31** (Project Leyden topic slide) as a progression summary
- **Use case:** When audience asks "what's the difference between AppCDS and Leyden?" or "what changed in JDK 25?"
- Perfect for workshop deep-dives on startup optimisation

### Speaker Notes

> "This is the question I get most often about startup optimisation: what is the difference between AppCDS on JDK 21 and the Leyden AOT cache on JDK 25? This diagram answers it."

**The key framing line before opening:**
> "The important thing to say upfront: the Quarkus property is identical across all four columns. `quarkus.package.jar.aot.enabled=true`. The command is `mvnw verify`. You change nothing. You just upgrade your JDK and you automatically get a richer, more effective cache."

**Column 1 — JDK 21 AppCDS**
> "On JDK 21, the cache stores parsed class bytes and the class hierarchy — things the JVM would have had to compute from bytecode. This gives you 20 to 30 percent startup improvement. Not bad for one property."

**Column 2 — JDK 24 (JEP 483)**
> "JDK 24 was the first Leyden feature to land in mainline OpenJDK. Now the cache stores the fully loaded and linked class state — not just the bytes, but the resolved references, the verified types, the initialisation state. Spring PetClinic dropped from 2 seconds to 1 second. Quarkus starts at a lower baseline, so the absolute improvement is smaller, but the percentage gain is similar."

**Column 3 — JDK 25 LTS (JEP 514+515) — highlight as current**
> "This is where we are now. JDK 25 is the current LTS. JEP 515 adds JIT method profiling to the cache. Your hot methods are compiled immediately from the first request — that's the warmup improvement on top of the startup gain. For a Quarkus app, Demo 04 shows 609ms baseline down to 148ms with the cache active on JDK 25 — a 75% reduction."

**Column 4 — JDK 26**
> "JDK 26 adds ZGC support. Previously the AOT cache was incompatible with ZGC — you had to choose between low-latency garbage collection and fast startup. JEP 516 removes that constraint. If you're on JDK 26 with ZGC enabled, you can also use the full AOT cache. You don't have to pick."

**The key insight banner**
> "The punchline is this: you do not need to change your Quarkus configuration to benefit from each JDK improvement. Set the property once. Upgrade the JDK at your own pace. The cache automatically becomes richer. This is intentional design — the Quarkus and OpenJDK teams are collaborating to make this progression seamless."

---

## Diagram 04 — Container-Aware JVM Memory

**File:** `04-container-aware-jvm.excalidraw`

### Where it fits in the deck
- **Primary:** As a companion to slide **4** (Container-Native JVM Fundamentals) and slide **5** (Before/After visual)
- **Use case:** Any time someone in the audience says "we had a pod OOMKill and didn't know why"
- Highly effective as the first whiteboard moment — it viscerally shows the problem

### Speaker Notes

**Open with the left side:**
> "Let me show you what happens when a JVM starts inside a Kubernetes container without the right flags. This is a real scenario I see in production."

> "You have a 64-core node with 256 GB of RAM. You deploy a pod with a container limit of 512 MB. The JVM starts up. It asks the operating system: how much memory do I have? Without container support flags, it reads `/proc/meminfo`. That file reports the host memory — 256 GB. The JVM applies its default heuristic: 25 percent of available memory for heap. That's 64 GB of heap inside a 512 MB container."

**Point to the OOMKill annotation:**
> "Kubernetes enforces that 512 MB limit at the cgroup level. The moment the JVM tries to allocate beyond 512 MB — which it does almost immediately trying to claim 64 GB — the kernel OOMKills the process. Exit code 137. Your pod restarts. It happens again. You're in a CrashLoopBackOff. And the error message tells you nothing about JVM heap sizing."

**Now move to the right side:**
> "Java 21 — and actually Java 15 onward — ships with `UseContainerSupport` turned on by default. When this is active, the JVM reads the cgroup files instead of `/proc/meminfo`. On RHEL 9 and OpenShift 4.14 and later, that's the cgroup v2 path at `/sys/fs/cgroup/memory.max`. On older systems, the v1 path. Either way, the JVM correctly reads 512 MB."

> "Then you set `MaxRAMPercentage=75`. The JVM claims 75 percent of 512 MB — 384 MB for heap. The remaining 128 MB covers Metaspace, thread stacks, JIT cache, and Netty buffers. The pod runs. No OOMKill."

**The critical point:**
> "The old approach — hardcoding `-Xms512m -Xmx1024m` — is fragile. Every time your VPA changes the container limit, or you move to a different size instance, your hardcoded values are wrong. The percentage-based approach scales automatically. Set `MaxRAMPercentage=75` once. It's correct on a 256 MB container and on a 32 GB container. The JVM calculates the right heap size at runtime."

**For Q&A follow-up:**
> "The most common follow-up question is: what about JDK 8 and 11? `UseContainerSupport` was backported to JDK 8u191 and JDK 11.0.1. If you're on a patch release older than those, you're running unsupported software and also have broken container memory detection. That's two good reasons to upgrade."

---

## Using These Diagrams in Your Presentation

### As whiteboard moments (recommended)
Keep excalidraw.com open in a browser tab. Switch to it at the relevant slide and trace through the diagram live. This creates an interactive moment that breaks up slide-deck monotony and signals to the audience that you understand the material well enough to draw it.

### As a handout
Export each diagram to PNG from Excalidraw (`Export image`) and include in a PDF handout alongside the slides. Especially valuable for the sizing formula (Diagram 02) and the anti-patterns table (Diagram 06) which people want to take away.

### As backup slides
If you have a technically engaged audience or a longer timeslot, add these directly into the deck as extra slides at the relevant positions. Excalidraw export to SVG or PNG works cleanly at any resolution.

### Suggested flow with the 54-slide deck

| Deck slide | Insert diagram after | Reason |
|------------|---------------------|--------|
| Slide 4 — Container-Native JVM | Diagram 04 | Visual confirms the before/after story |
| Slide 6 — JVM Memory Regions | Diagram 02 | Expands on each region with flags + sizing |
| Slide 10 — GC in Containers | Diagram 01 | Draws the full HPA thrash domino chain |
| Slide 14 — AOT Cache Progression | Diagram 03 | Clarifies the JDK 21→24→25→26 progression |
| Slide 16 — AOT Caching detail | Diagram 03 | Second reference — deep-dive on the cache layers |
| Slide 21 — HPA with JVM Metrics | Diagram 01 | Second reference — the fix is on this slide |
| Slide 31 — Project Leyden | Diagram 03 | Deep-dive companion for Leyden section |
| Slide 32 — How Leyden Works | Diagram 05 | Deeper three-column walk-through |
| Slide 53 — Anti-Patterns | Diagram 06 | Side-by-side reference for all 16 patterns |

---

## Diagram 05 — How Project Leyden Works

**File:** `05-how-project-leyden-works.excalidraw`

### Where it fits in the deck
- **Primary:** After slide **32** (How Project Leyden Works visual) and before slide **33** (Demo 04 intro)
- **Ideal use:** Open this when the audience asks "but what is the AOT cache actually doing?" — it answers the mechanism question that the topic slide raises
- Also effective right after slide **16** (AOT Caching) as a deeper technical explainer
- Works well as a **whiteboard walk-through** — trace the three columns left to right while narrating

### Speaker Notes

#### Opening

> "Slide 31 told you what Project Leyden *is*. This diagram shows you what it *does* — specifically, what work it eliminates and how."

> "The headline is this: every time a JVM starts, it repeats a significant amount of computation that it has already done before. Leyden's insight is simple — record that work once during a training run, save it to a file, and skip it on every subsequent startup."

#### Column 1 — Normal Startup (walk top to bottom)

> "Without Leyden, here is what happens every single time a pod starts — on every node, for every HPA scale-out event, on every deployment."

**Read bytecodes from disk:**
> "The JVM opens the JAR file and reads the raw bytecodes for every class the application uses. For a typical Quarkus application that's between 15,000 and 25,000 class files. For Spring Boot it's more. This is pure I/O, and it happens every time."

**Parse + verify:**
> "Each class is parsed into the JVM's internal representation. Bytecode verification runs — the JVM checks that the code is safe to execute. This is cryptographic-level paranoia baked into the JVM spec, and it runs on every class, every startup."

**Load + link:**
> "This is the most expensive step. Linking resolves all the references between classes — when class A calls a method on class B, the JVM has to find B's method table and bind the call. It lays out memory for fields. It resolves constant pool entries. This is what Leyden JEP 483 specifically targets."

**JIT interpreter mode:**
> "Even after the classes are loaded, the JVM starts in interpreter mode. It runs your bytecode slowly and counts how many times each method is called. This profiling phase is necessary before the JIT will bother compiling a method to native code."

**JIT C1 compile:**
> "Once a method is called enough times, the JIT promotes it to C1 — a quick native compile. Eventually hot methods reach C2, the optimising compiler. But all of this observation and compilation takes time — typically 30 to 60 seconds after startup before P99 latency stabilises."

**The punchline:**
> "And tomorrow, when this pod restarts, it does ALL of this again. From scratch. Because the JVM has no memory between runs."

#### Column 2 — Training Run (walk top to bottom)

> "The training run is what Leyden introduces. It runs ONCE — in your CI/CD pipeline — and never again in production. That's the key framing."

**mvn verify:**
> "In Quarkus, the training run is triggered by `quarkus.package.jar.aot.enabled=true` in application.properties and running `mvn verify`. That's the only change to your build."

**Plugin starts packaged app with observation mode:**
> "The Quarkus Maven plugin starts the fully packaged `quarkus-run.jar` with the JVM's observation hooks active. The JVM is watching everything — which classes are loaded, in what order, how they link to each other."

**@QuarkusIntegrationTest runs — highlight this:**
> "Here's the part that catches people off-guard: the training workload is your own test suite. The `@QuarkusIntegrationTest` tests you wrote for CI also train the JVM. Every endpoint you hit in your integration tests gets its class loading recorded, its method call patterns profiled. This is by design. The better your tests represent production traffic, the more effective the cache."
>
> "This is also why there's a distinction between `@QuarkusTest` and `@QuarkusIntegrationTest`. `@QuarkusTest` runs in dev-mode JVM — it doesn't contribute to the AOT cache. `@QuarkusIntegrationTest` runs against the packaged JAR — this is the training workload."

**The three cache layers — point to each:**
> "What gets written to `app.aot` is stratified. Layer 1 is the base CDS layer — parsed bytecode representation, same as AppCDS on JDK 21. Layer 2, from JEP 483 on JDK 24, adds the full loaded and linked class state — the resolved references, the memory layouts, the verified types. Layer 3, from JEP 515 on JDK 25, adds the JIT method profiles — which methods got called, how many times, what data shapes the JIT observed."
>
> "The cache is self-invalidating. If your JARs change — different version, different classes — the JVM detects the mismatch at startup and rebuilds the cache rather than running stale data. You don't need to manage invalidation manually."

#### Column 3 — Production Run with Cache (walk top to bottom)

> "Now let's follow a production startup with the cache present."

**Detects and memory-maps app.aot:**
> "The JVM finds `app.aot` alongside `quarkus-run.jar`. With Quarkus, this happens automatically — the plugin sets `-XX:AOTCache=app.aot` when packaging, so you don't add it to your Dockerfile. The JVM memory-maps the cache file — this is an OS-level operation that's extremely fast and also allows the file to be shared across multiple JVM processes on the same node."

**The SKIPPED work box — this is the key moment:**
> "Now read what the JVM skips. Parse and verify — skipped. Load and link for 25,000 classes — skipped. JIT interpreter warmup phase — skipped. C1 profiling pass — skipped."
>
> "The JVM loads the pre-linked class state directly from the cache. Classes appear already-resolved. Method profiles are pre-loaded so the JIT can start compiling hot methods immediately — at first request, not after 30 seconds of warmup."

**First request at ~148ms (Demo 04 verified result):**
> "For a Quarkus app, this brings startup from 609ms on JDK 25 cold down to 148ms with the cache active — a 75% reduction. But the number I find more compelling is the warmup story — with the JIT profiles pre-loaded, your P99 latency is good from the very first request. Without Leyden, request number one hits interpreted bytecode. With Leyden, it hits code that's already been JIT-compiled."

**Cache shared across pods:**
> "One detail worth mentioning in a Kubernetes context: because the cache is memory-mapped, multiple pods on the same node can share the underlying physical memory pages for the read-only cache regions. It's not quite as dramatic as Native Image's single binary, but it does mean the cache file is not multiplied per pod at the RAM level."

#### Closing the Diagram

> "The summary is at the bottom. Left column: this work repeats on every pod start, every HPA scale-out, every deployment rollout. Right column: all of it is skipped. The cost was paid once during `mvn verify` in your CI pipeline."

> "And the Quarkus integration means you configure this with one property and one Maven command. The three columns you're looking at — that entire lifecycle — is fully automated."

### Suggested Slide Placement

```
Slide 31  Project Leyden (topic slide)
Slide 32  How Project Leyden Works (deck visual)
          ↓
Diagram 05  How Leyden Works (whiteboard — deeper three-column walk-through)
          ↓
Slide 33  Demo 04 intro
          ↓
Live demo: quarkus-demo-04-leyden/demo.sh
```

The diagram bridges the "what is it" slide and the "watch it run" demo. After walking the three columns, opening the demo feels like a natural demonstration of column 2 followed by column 3.

---

## Diagram 06 — JVM Anti-Patterns vs Fixes

**File:** `06-antipatterns-vs-fixes.excalidraw`

### Where it fits in the deck
- **Primary:** After slide **53** (Anti-Patterns — 16 items) and alongside slide **54** (Remediation)
- **Use case:** Q&A reference — when someone asks "what's the most important thing I can do today?" point to the priority bar at the bottom
- Works well as a **printed A3 handout** — the three-column table is legible at full page width
- Pin it to your conference chat or workshop Slack as a reference card

### Slide Placement

```
Slide 53  Common JVM Anti-Patterns on Kubernetes (16 items, 4 categories)
    ↓
Diagram 06  (whiteboard or handout — shows all 16 rows at a glance)
    ↓
Slide 54  Anti-Pattern Remediation — The Correct Approach
```

---

### Speaker Notes

#### Opening

> "This diagram is the at-a-glance reference. Every row is one mistake I have seen in a real production system, and the fix column is what to replace it with. I'll walk the most important ones — you can take the diagram as a reference for the rest."

---

#### Memory section (rows 1–3)

**Row 1 — Hardcoded -Xmx**
> "The fix for this is the single highest-leverage change in the whole talk. Delete the `-Xmx` flag. Add `-XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0`. If you do nothing else from today, do this. It makes your heap sizing correct regardless of container limit, VPA changes, or cluster migrations."

**Row 2 — MaxRAMPercentage=90**
> "This looks reasonable — 90% for the heap, 10% for everything else. But 10% of a 2 GB container is 200 MB. Metaspace alone can need 256 MB on a framework-heavy app. Thread stacks at 200 threads is another 200 MB. Netty buffers another 100 MB. You're already over. Set 75 and add an explicit MaxMetaspaceSize cap."

**Row 3 — Requests equal limits for memory**
> "This is the Kubernetes-specific version of the same mistake. Your memory limit should be 25-30% above your measured P99 peak RSS. The request is your scheduling guarantee — set it to your P50 steady state. The gap between them is your GC headroom. Without that gap, a GC surge at peak load will OOMKill the pod."

---

#### GC & CPU section (rows 4–7)

**Row 4 — Default ParallelGCThreads**
> "Write this down. ParallelGCThreads defaults to the number of CPUs the JVM sees — which on a shared Kubernetes node is the host CPU count, not your container limit. On a 64-core node with a 2-core container, you get 64 GC threads sharing 2 CPUs. GC pauses can be 10 times longer than necessary. `-XX:ParallelGCThreads=2` — whatever your CPU request is."

**Row 5 — CPU-based HPA**
> "I covered this in the GC thrash cycle diagram. The short version: GC pauses create CPU spikes. CPU-based HPA treats those spikes as load and scales out. The new pods also do GC. You get a feedback loop. Scale on RPS instead — it measures actual request load, which is unaffected by GC."

**Row 6 — minReplicas: 1**
> "This one is cheap to fix. One extra pod. That's it. The cost of running two pods instead of one is trivial compared to the cost of a 100% error rate during a GC stop-the-world event. Make this the default in your org's Kubernetes templates."

**Row 7 — No HPA stabilizationWindowSeconds**
> "GC CPU spikes last milliseconds to hundreds of milliseconds. Default HPA scale-up window is zero seconds — it acts on the very next scrape. Add `stabilizationWindowSeconds: 120` on scaleUp. That 2-minute window is longer than any normal GC pause and makes HPA invisible to GC transients."

---

#### AOT / Startup section (rows 8–11)

**Row 8 — Using @QuarkusTest for AOT training**
> "This catches people because the annotation names look similar. `@QuarkusTest` runs in the development-mode JVM — it's fast but it doesn't exercise the packaged JAR, so the JVM's observation hooks never fire. `@QuarkusIntegrationTest` runs against the real packaged artifact. That's what contributes to the AOT cache. If your test suite is all `@QuarkusTest`, your `app.aot` will be tiny or empty."

**Row 9 — Manual -XX flags in Dockerfile**
> "Quarkus puts `app.aot` alongside `quarkus-run.jar`. When the JAR is launched, Quarkus detects the cache file and sets `-XX:AOTCache=app.aot` automatically via its generated launch scripts. If you also set it in your Dockerfile ENTRYPOINT, the JVM sees the flag twice and either ignores one or fails. Trust Quarkus. Set the property in application.properties, run `mvn verify`, and don't touch the launch flags."

**Row 10 — mvn package instead of mvn verify**
> "If you fix the annotation but still run `mvn package`, you skip the failsafe plugin entirely — no integration tests, no training run, minimal cache. `mvn verify` is the one command that does all three: package the JAR, run `@QuarkusIntegrationTest`, write `app.aot`. Package alone gets you nothing."

**Row 11 — Ignoring JDK version on cache rebuild**
> "The AOT cache is tied to the exact JDK that created it. If you pin `eclipse-temurin:25-jdk` and the next build pulls a newer patch version, the JVM detects the fingerprint mismatch at startup and silently rebuilds the cache from scratch — giving you none of the benefit until the second restart. Pin the minor version in your Dockerfile FROM line."

---

#### Observability section (rows 12–15 — now 4 rows, not 2)

**Row 12 — No GC pause histogram**
> "Without the histogram, you have counts and sums for GC pause time, but you can't compute a P99. The `jvm.gc.pause` counter tells you 'GC happened 40 times'. The histogram tells you 'GC P99 was 800ms for the last minute — fire an alert'. Those are completely different operational signals. The Quarkus property is one line. Set it before your next deployment."

```properties
quarkus.micrometer.distribution.percentiles-histogram.jvm.gc.pause=true
```

**Row 13 — quarkus-micrometer-registry-prometheus alone**
> "If you're running `quarkus-micrometer-registry-prometheus` and `quarkus-opentelemetry` as separate extensions, consolidate to `quarkus-micrometer-opentelemetry`. One dependency, unified OTLP pipeline — metrics and traces can be correlated by trace ID. The separate extensions create two independent telemetry paths that can't be joined at query time."

**Row 14 — No PrometheusRule on jvm_gc_pause**
> "GC degradation is invisible until it breaches your SLO if you have no alert. Add this rule — it's two minutes of work and it will page you before your users notice:
>
> `histogram_quantile(0.99, rate(jvm_gc_pause_seconds_bucket[5m])) > 0.5`
>
> P99 GC pause over 500ms for 2 minutes means you need to act — switch GC algorithm, resize the heap, or investigate allocation rate."

**Row 15 — Tuning without a baseline**
> "This is the most important professional discipline in the whole talk. I have seen engineers spend two days tuning GC flags based on intuition, with no measurement, and ship a change that made things worse. The workflow is: measure P99 startup time, measure P99 latency under load, change exactly one flag, measure again, compare. If it improved — commit. If it didn't — revert. Everything else is guesswork."

---

#### Priority bar (bottom of diagram)

> "The footer shows my recommended priority order if you're starting from scratch. Memory flags first — they prevent OOMKills. Then `minReplicas: 2` — it's free reliability. Then ParallelGCThreads — it makes every GC faster immediately. Then fix the HPA metric and add stabilisation windows. Then the AOT cache setup. Then observability. That order will get you 80% of the value in the first day."

---

### Using this diagram in a workshop

Project this diagram and ask the audience to vote on which row most matches their current production setup. Usually at least half the hands go up for rows 1-3. That creates an immediate personal connection to the content — the people in the room have seen these failures firsthand, and the fixes are right there in the green column.

---

## Diagram 06 — JVM Anti-Patterns and Fixes (Reference Table)

**File:** `06-antipatterns-vs-fixes.excalidraw`

### Where it fits in the deck
- **Primary:** After slide **53** (Anti-Patterns) and alongside slide **54** (Fixes) as a combined quick-reference
- **Best use:** Printed A3 handout — one page attendees can take away with every anti-pattern and its exact fix
- Also effective as a projected reference during extended Q&A — keep it on screen so the audience can read the flags themselves
- Works as a whiteboard where you circle the specific patterns relevant to the audience's stack

---

### Speaker Notes

#### Opening (if projecting)

> "Slides 53 and 54 showed you the anti-patterns and fixes as separate slides. This diagram puts them side-by-side so you can see each pair directly. I'm going to walk the priority order — most critical at the top, diminishing returns as you go down. If you only fix the top four items in this table, you will eliminate 80 percent of the production incidents I've seen."

---

#### Memory row (top 3 — walk these carefully)

**Row 1 — Hardcoded -Xmx/-Xms:**
> "Every single production OOMKill investigation I've been involved in eventually traces back to this. Someone hardcoded -Xmx2g in 2018. The container limit was changed to 1.5g in 2021. Nobody noticed until a Friday at 5pm. The fix is two flags: UseContainerSupport — which ships ON by default since Java 15 — and MaxRAMPercentage=75. You never touch it again when the limit changes."

**Row 2 — MaxRAMPercentage=90:**
> "People Google 'how to give Java more heap' and find MaxRAMPercentage. They set it to 90. This leaves 10% for everything else. A Quarkus app with Vert.x, Netty, and a few framework extensions routinely needs 300-400 MB off-heap. At 90% in a 1 GB container, that's 100 MB remaining for off-heap — not enough. 75 percent is the safe default. Go to 80 percent only after measuring."

**Row 3 — No MaxMetaspaceSize:**
> "This one is subtle. Metaspace grows as new classes are loaded — framework scanning, proxies, dynamic code generation. Without a cap, it grows until the OS decides you've had enough. Set 256m. It's enough for most Quarkus apps. If you hit ClassNotFoundException at startup, bump to 512m."

---

#### GC & CPU row (rows 4–7)

**Row 4 — ParallelGCThreads:**
> "This one requires measuring to confirm, but on any cluster where pods run on large nodes, check your GC thread count. Run: `jcmd <pid> VM.flags | grep GCThreads`. If it says 32 or 64 inside a 2-CPU container, that's the bug. The threads aren't executing in parallel — they're time-sliced, which makes GC take longer, not shorter."

**Row 5 — CPU-based HPA:**
> "If you take nothing else from this diagram, take this: do not use CPU to autoscale Java services. CPU is a JVM internal metric. GC raises it. JIT compilation raises it. Startup raises it. None of these are load signals. RPS is a load signal. Use RPS."

**Rows 6 and 7 — minReplicas and stabilisation:**
> "These two go together. minReplicas: 2 is the defensive posture — you never have a single point of failure during GC. The stabilisation window is the guard against HPA itself becoming the problem — it prevents the GC→HPA thrash cycle we drew in diagram 01. Fix row 6 first — add a second replica. Then fix row 7. In that order."

---

#### AOT / Startup row (rows 8–11)

> "These four are specifically Quarkus AOT patterns. The most common mistake is row 8 — using @QuarkusTest. If your AOT cache builds are producing zero improvement, this is almost certainly why. Check with: `ls -lh target/quarkus-app/app.aot`. If it's under 10 MB, your training coverage is poor."

> "Rows 9 and 10 are build pipeline hygiene. Row 9: never add `-XX:AOTCache` to your Dockerfile manually — Quarkus sets it during packaging. Two conflicting flags = startup failure. Row 10: `mvn verify` not `mvn package` — the failsafe plugin that runs your `@QuarkusIntegrationTest` suite only fires in the verify phase."

> "Row 11 is the sneaky one. If you don't pin the JDK minor version in your Dockerfile FROM line, a JDK patch release will silently invalidate the cache. The JVM detects the fingerprint mismatch and rebuilds from scratch — your pods get no benefit until the second restart after the build. Pin it."

---

#### Observability row (rows 12–15)

> "These four rows are the difference between having visibility into your JVM and flying blind."

> "Row 12 is one line in application.properties. Add it right now before you leave this room. It's the difference between 'our app is slow' and 'our app is slow because GC P99 is 800ms, which is a heap sizing issue.'"

> "Row 13 is an architecture cleanup. If you're running `quarkus-micrometer-registry-prometheus` and `quarkus-opentelemetry` as separate extensions, consolidate to `quarkus-micrometer-opentelemetry`. One dependency, unified OTLP pipeline, metrics and traces correlated by trace ID."

> "Row 14 is the proactive alert that wakes you up before your users notice. Add a PrometheusRule on `histogram_quantile(0.99, rate(jvm_gc_pause_seconds_bucket[5m])) > 0.5`. Two minutes of work. It pages you when GC P99 exceeds 500ms — which is actionable, not catastrophic."

> "Row 15 — the baseline row — is the most important discipline in the whole table. I've seen teams spend three weeks tuning GC flags and end up with worse performance than they started because they had no baseline to compare against. Measure first. Change one thing. Measure again. This is not negotiable if you want to make claims about what you've improved."

---

#### Closing

> "The golden rule at the bottom applies to every row in this table. One change at a time. Measure before and after. Commit or revert based on data."

> "If there's one thing I want you to take away from this diagram specifically, it's row 4. Set ParallelGCThreads today. It costs nothing except adding one JVM flag to your Dockerfile. It will immediately improve GC pause duration on any node with more CPUs than your container limit."

---

### Print/Handout Notes

The diagram is designed to be readable at A3 or letter landscape. The three-column layout (anti-pattern → why it fails → fix) means attendees can use it as a quick-reference checklist against their own deployment configuration. The coloured section headers (Memory, GC & CPU, AOT/Startup, Observability) make it easy to scan for the relevant category.

The golden rule box at the bottom is intentionally prominent — it's the meta-fix that validates all the specific fixes.

---

### Suggested Slide Placement

```
Slide 53  Common JVM Anti-Patterns on Kubernetes (16 items in 4 red cards)
          ↓
Diagram 06  Anti-Patterns vs Fixes side-by-side (this diagram)
          ↓
Slide 54  Anti-Pattern Remediation (16 fixes in 4 colour-coded cards)
```

The diagram works best as a **whiteboard handout moment** — give the audience 60 seconds to scan both columns before you start narrating. People will immediately start mapping the left column to their own infrastructure.
