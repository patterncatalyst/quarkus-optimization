# Excalidraw Diagrams — Speaker Notes & Slide Placement

These four diagrams are designed as **supplementary visuals** — use them as:
- A live whiteboard moment during Q&A ("let me draw this out")
- A pre-shared handout alongside the slide deck
- A reference for deeper-dive sessions or workshop settings
- Backup slides if you want to add a "pause and explain" moment

---

## Diagram 01 — GC-Induced HPA Thrash Cycle

**File:** `01-gc-hpa-thrash-cycle.excalidraw`

### Where it fits in the deck
- **Primary:** Between slides **8** (GC in Containers) and **17** (HPA with JVM Metrics)
- **Optional:** Open during live Q&A when someone asks "why can't I just use CPU-based HPA?"
- Works well as a whiteboard trace-through — point to each box as you narrate the story

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
- **Primary:** After slide **5** (JVM Memory Regions) as a deeper visual reference
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
- **Primary:** Between slides **12** (AppCDS / AOT Cache) and **27** (Project Leyden)
- **Use case:** When audience asks "what's the difference between AppCDS and Leyden?" or "what changed in JDK 25?"
- Perfect for workshop deep-dives on startup optimisation

### Speaker Notes

> "This is the question I get most often about startup optimisation: what is the difference between AppCDS on JDK 21 and the Leyden AOT cache on JDK 25? This diagram answers it."

**The key framing line before opening:**
> "The important thing to say upfront: the Quarkus property is identical across all four columns. `quarkus.package.jar.aot.enabled=true`. The command is `mvnw verify`. You change nothing. You just upgrade your JDK and you automatically get a richer, more effective cache."

**Column 1 — JDK 21 AppCDS**
> "On JDK 21, the cache stores parsed class bytes and the class hierarchy — things the JVM would have had to compute from bytecode. This gives you 20 to 30 percent startup improvement. Not bad for one property."

**Column 2 — JDK 24 (JEP 483)**
> "JDK 24 was the first Leyden feature to land in mainline OpenJDK. Now the cache stores the fully loaded and linked class state — not just the bytes, but the resolved references, the verified types, the initialisation state. Spring PetClinic dropped from 2 seconds to 1 second. That's the same 40 percent you see in all the benchmarks. Quarkus starts at a lower baseline, so the absolute improvement is smaller, but the percentage gain is similar."

**Column 3 — JDK 25 LTS (JEP 514+515) — highlight as current**
> "This is where we are now. JDK 25 is the current LTS. JEP 515 adds JIT method profiling to the cache. This means that on startup, the JVM doesn't just skip class loading — it also skips the profiling phase that normally precedes JIT compilation. Your hot methods are compiled immediately from the first request. That's the warmup improvement — 15 to 25 percent on top of the startup gain. For a Quarkus app, you're looking at around 175ms with the cache on JDK 25."

**Column 4 — JDK 26**
> "JDK 26 adds ZGC support. Previously the AOT cache was incompatible with ZGC — you had to choose between low-latency garbage collection and fast startup. JEP 516 removes that constraint. If you're on JDK 26 with ZGC enabled, you can also use the full AOT cache. You don't have to pick."

**The key insight banner**
> "The punchline is this: you do not need to change your Quarkus configuration to benefit from each JDK improvement. Set the property once. Upgrade the JDK at your own pace. The cache automatically becomes richer. This is intentional design — the Quarkus and OpenJDK teams are collaborating to make this progression seamless."

---

## Diagram 04 — Container-Aware JVM Memory

**File:** `04-container-aware-jvm.excalidraw`

### Where it fits in the deck
- **Primary:** As a companion to slide **4** (Container-Native JVM Fundamentals)
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
Export each diagram to PNG from Excalidraw (`Export image`) and include in a PDF handout alongside the slides. Especially valuable for the sizing formula (Diagram 02) which people want to take away.

### As backup slides
If you have a technically engaged audience or a longer timeslot, add these directly into the deck as extra slides at the relevant positions. Excalidraw export to SVG or PNG works cleanly at any resolution.

### Suggested flow with existing slides

| Existing slide | Insert diagram after | Reason |
|----------------|---------------------|--------|
| Slide 4 — Container-Native JVM | Diagram 04 | Visual confirms the before/after story |
| Slide 5 — JVM Memory Regions | Diagram 02 | Expands on each region with flags + sizing |
| Slide 8 — GC in Containers | Diagram 01 | Draws the full HPA thrash domino chain |
| Slide 12 — AOT Caching | Diagram 03 | Clarifies the JDK 21→24→25→26 progression |
| Slide 17 — HPA with JVM Metrics | Diagram 01 | Second reference — the fix is on this slide |
| Slide 27 — Project Leyden | Diagram 03 | Deep-dive companion for Leyden section |

---

## Diagram 05 — How Project Leyden Works

**File:** `05-how-project-leyden-works.excalidraw`

### Where it fits in the deck
- **Primary:** Between slides **27** (Project Leyden topic) and **28** (Demo 04 intro)
- **Ideal use:** Open this when the audience asks "but what is the AOT cache actually doing?" — it answers the mechanism question that the topic slide raises
- Also effective right after slide **12** (AOT Caching) as a deeper technical explainer
- Works well as a **whiteboard walk-through** — trace the three columns left to right while narrating

---

### Speaker Notes

#### Opening

> "Slide 27 told you what Project Leyden *is*. This diagram shows you what it *does* — specifically, what work it eliminates and how."

> "The headline is this: every time a JVM starts, it repeats a significant amount of computation that it has already done before. Leyden's insight is simple — record that work once during a training run, save it to a file, and skip it on every subsequent startup."

---

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

---

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

---

#### Column 3 — Production Run with Cache (walk top to bottom)

> "Now let's follow a production startup with the cache present."

**Detects and memory-maps app.aot:**
> "The JVM finds `app.aot` alongside `quarkus-run.jar`. With Quarkus, this happens automatically — the plugin sets `-XX:AOTCache=app.aot` when packaging, so you don't add it to your Dockerfile. The JVM memory-maps the cache file — this is an OS-level operation that's extremely fast and also allows the file to be shared across multiple JVM processes on the same node."

**The SKIPPED work box — this is the key moment:**
> "Now read what the JVM skips. Parse and verify — skipped. Load and link for 25,000 classes — skipped. JIT interpreter warmup phase — skipped. C1 profiling pass — skipped."
>
> "The JVM loads the pre-linked class state directly from the cache. Classes appear already-resolved. Method profiles are pre-loaded so the JIT can start compiling hot methods immediately — at first request, not after 30 seconds of warmup."

**First request at ~175ms:**
> "For a Quarkus app, this brings startup from around 350ms to around 175ms. That's a 50 percent reduction on top of Quarkus's already-fast baseline. But the number I find more compelling is the warmup story — with the JIT profiles pre-loaded, your P99 latency is good from the very first request. Without Leyden, request number one hits interpreted bytecode. With Leyden, it hits code that's already been JIT-compiled."

**Cache shared across pods:**
> "One detail worth mentioning in a Kubernetes context: because the cache is memory-mapped, multiple pods on the same node can share the underlying physical memory pages for the read-only cache regions. It's not quite as dramatic as Native Image's single binary, but it does mean the cache file is not multiplied per pod at the RAM level."

---

#### Closing the Diagram

> "The summary is at the bottom. Left column: this work repeats on every pod start, every HPA scale-out, every deployment rollout. Right column: all of it is skipped. The cost was paid once during `mvn verify` in your CI pipeline."

> "And the Quarkus integration means you configure this with one property and one Maven command. The three columns you're looking at — that entire lifecycle — is fully automated."

---

### Suggested Slide Placement

```
Slide 27  Project Leyden (topic slide)
          ↓
Diagram 05  How Leyden Works (this diagram — whiteboard or extra slide)
          ↓
Slide 28  Demo 04 intro
          ↓
Live demo: quarkus-demo-04-leyden/demo.sh
```

The diagram bridges the "what is it" slide and the "watch it run" demo. After walking the three columns, opening the demo feels like a natural demonstration of column 2 followed by column 3.
