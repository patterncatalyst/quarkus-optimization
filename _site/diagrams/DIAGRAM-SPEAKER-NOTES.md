# Excalidraw Diagrams — Speaker Notes & Slide Placement

Companion notes for all diagrams in the `diagrams/` directory. Use these as:
- A live whiteboard moment during Q&A ("let me draw this out")
- A pre-shared handout alongside the slide deck
- A reference for deeper-dive sessions or workshop settings
- Backup slides if you want to add a "pause and explain" moment

**Deck reference:** These notes use slide numbers from the 54-slide deck
`optimizing-quarkus-on-kubernetes.pptx` (30 core slides + 24 bonus slides).

---

## Diagram Index

| File | Topic | Primary slide | Section |
|------|-------|--------------|---------|
| `01-gc-hpa-thrash-cycle.excalidraw` | GC → CPU spike → HPA false scale-out | After slide 10 | Core §03 |
| `02-jvm-memory-regions.excalidraw` | Six JVM memory regions + sizing formula | After slide 6 | Core §01 |
| `03-aot-cache-progression.excalidraw` | CDS → AppCDS → Leyden JDK 21→25→26 | After slide 16 | Core §04 |
| `04-container-aware-jvm.excalidraw` | Before/after UseContainerSupport | After slide 5 | Core §01 |
| `05-how-project-leyden-works.excalidraw` | Training run → cache → production | After slide 32 | Bonus Leyden |
| `06-antipatterns-vs-fixes.excalidraw` | 16 anti-patterns with exact fixes | After slide 53 | Bonus |
| `07-grpc-vs-rest.excalidraw` | Wire format, HTTP/2, streaming model | After slide 34 | Bonus gRPC |
| `graphql-query-response.excalidraw` | GraphQL query/response shape | Reference only | — |
| `rpc-architecture.excalidraw` | Service-to-service RPC architecture | After slide 34 | Bonus gRPC |
| `rest-order-sequence.excalidraw` | REST request sequence diagram | After slide 34 | Bonus gRPC |

---

## Diagram 01 — GC-Induced HPA Thrash Cycle

**File:** `01-gc-hpa-thrash-cycle.excalidraw`

### Where it fits in the deck

- **Primary:** After slide **10** (GC in Containers) and slide **11** (GC-Induced HPA Thrash Cycle visual)
- **Secondary:** Open during Q&A when someone asks "why can't I just use CPU-based HPA?"
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

> "The third option — shown on slide 21 — is KEDA with a Prometheus query. Scale on `sum(rate(http_server_requests_seconds_count[2m]))`. This metric reflects actual user demand, is completely decoupled from JVM internals, and lets you set an exact RPS threshold rather than a percentage."

---

## Diagram 02 — JVM Memory Regions Breakdown

**File:** `02-jvm-memory-regions.excalidraw`

### Where it fits in the deck

- **Primary:** After slide **6** (JVM Memory Regions) as a deeper visual reference
- **Secondary:** After slide **5** (Container-Aware JVM Memory Before/After) when audience asks "but how much should I set?"
- Use case: Whenever audience members ask "how do I calculate my container limit?"
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
> "Every platform thread gets 1 MB of stack by default. If you have 200 threads — totally normal for a REST service — that is 200 MB of off-heap memory that most sizing calculations miss entirely. This is why Quarkus Virtual Threads matter for container sizing: virtual thread stacks live in the heap as tiny continuations, not 1 MB OS stacks."

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
- Use case: When audience asks "what's the difference between AppCDS and Leyden?" or "what changed in JDK 25?"

### Speaker Notes

> "This is the question I get most often about startup optimisation: what is the difference between AppCDS on JDK 21 and the Leyden AOT cache on JDK 25? This diagram answers it."

**The key framing line before opening:**
> "The important thing to say upfront: the Quarkus property is identical across all four columns. `quarkus.package.jar.aot.enabled=true`. The command is `mvnw verify`. You change nothing. You just upgrade your JDK and you automatically get a richer, more effective cache."

**Column 1 — JDK 21 AppCDS**
> "On JDK 21, the cache stores parsed class bytes and the class hierarchy — things the JVM would have had to compute from bytecode. This gives you 20 to 30 percent startup improvement. Not bad for one property."

**Column 2 — JDK 24 (JEP 483)**
> "JDK 24 was the first Leyden feature to land in mainline OpenJDK. Now the cache stores the fully loaded and linked class state — not just the bytes, but the resolved references, the verified types, the initialisation state. Spring PetClinic dropped from 2 seconds to 1 second. Quarkus starts at a lower baseline, so the absolute improvement is smaller, but the percentage gain is similar."

**Column 3 — JDK 25 LTS (JEP 514+515) — highlight as current**
> "This is where we are now. JDK 25 is the current LTS. JEP 515 adds JIT method profiling to the cache. Your hot methods are compiled immediately from the first request. That's the warmup improvement — 15 to 25 percent on top of the startup gain. For a Quarkus app on JDK 25, you're looking at around 148ms with the cache active — verified in Demo 04."

**Column 4 — JDK 26**
> "JDK 26 adds ZGC support. Previously the AOT cache was incompatible with ZGC — you had to choose between low-latency garbage collection and fast startup. JEP 516 removes that constraint."

**The key insight banner**
> "The punchline: you do not need to change your Quarkus configuration to benefit from each JDK improvement. Set the property once. Upgrade the JDK. The cache automatically becomes richer."

---

## Diagram 04 — Container-Aware JVM Memory

**File:** `04-container-aware-jvm.excalidraw`

### Where it fits in the deck

- **Primary:** After slide **4** (Container-Native JVM Fundamentals) or alongside slide **5** (Before/After visual)
- Use case: Any time someone says "we had a pod OOMKill and didn't know why"
- Highly effective as the first whiteboard moment — viscerally shows the problem

### Speaker Notes

**Open with the left side:**
> "Let me show you what happens when a JVM starts inside a Kubernetes container without the right flags. This is a real scenario I see in production."

> "You have a 64-core node with 256 GB of RAM. You deploy a pod with a container limit of 512 MB. The JVM starts up. It asks the operating system: how much memory do I have? Without container support flags, it reads `/proc/meminfo`. That file reports the host memory — 256 GB. The JVM applies its default heuristic: 25 percent of available memory for heap. That's 64 GB of heap inside a 512 MB container."

**Point to the OOMKill annotation:**
> "Kubernetes enforces that 512 MB limit at the cgroup level. The moment the JVM tries to allocate beyond 512 MB — which it does almost immediately trying to claim 64 GB — the kernel OOMKills the process. Exit code 137. Your pod restarts. It happens again. You're in a CrashLoopBackOff. And the error message tells you nothing about JVM heap sizing."

**Now move to the right side:**
> "Java 21 ships with `UseContainerSupport` turned on by default. When this is active, the JVM reads the cgroup files instead of `/proc/meminfo`. On RHEL 9 and OpenShift 4.14+, that's the cgroup v2 path at `/sys/fs/cgroup/memory.max`. The JVM correctly reads 512 MB."

> "Then you set `MaxRAMPercentage=75`. The JVM claims 75 percent of 512 MB — 384 MB for heap. The remaining 128 MB covers Metaspace, thread stacks, JIT cache, and Netty buffers. The pod runs. No OOMKill."

**The critical point:**
> "The old approach — hardcoding `-Xms512m -Xmx1024m` — is fragile. Every time your VPA changes the container limit, or you move to a different size instance, your hardcoded values are wrong. `MaxRAMPercentage=75` scales automatically."

---

## Diagram 05 — How Project Leyden Works

**File:** `05-how-project-leyden-works.excalidraw`

### Where it fits in the deck

- **Primary:** After slide **32** (How Project Leyden Works visual) and before slide **33** (Demo 04 intro)
- **Secondary:** After slide **16** (AOT Caching detail) as a deeper technical explainer
- Works well as a whiteboard walk-through — trace the three columns left to right

### Speaker Notes

#### Opening

> "Slide 31 told you what Project Leyden *is*. This diagram shows you what it *does* — specifically, what work it eliminates and how."

> "The headline: every time a JVM starts, it repeats a significant amount of computation it has already done before. Leyden's insight is simple — record that work once during a training run, save it to a file, and skip it on every subsequent startup."

#### Column 1 — Normal Startup (walk top to bottom)

> "Without Leyden, here is what happens every single time a pod starts — on every node, for every HPA scale-out event, on every deployment."

**Read bytecodes from disk:**
> "The JVM opens the JAR file and reads the raw bytecodes for every class the application uses. For a typical Quarkus application that's between 15,000 and 25,000 class files. This is pure I/O, and it happens every time."

**Parse + verify:**
> "Each class is parsed into the JVM's internal representation. Bytecode verification runs. This is cryptographic-level paranoia baked into the JVM spec, and it runs on every class, every startup."

**Load + link:**
> "The most expensive step. Linking resolves all references between classes. This is what Leyden JEP 483 specifically targets."

**JIT interpreter mode:**
> "Even after classes are loaded, the JVM starts in interpreter mode. It runs your bytecode slowly and counts how many times each method is called. This profiling phase is necessary before the JIT will compile a method to native code."

**JIT C1 compile:**
> "Once a method is called enough times, the JIT promotes it to C1. Eventually hot methods reach C2, the optimising compiler. But all of this takes time — typically 30 to 60 seconds after startup before P99 latency stabilises."

**The punchline:**
> "And tomorrow, when this pod restarts, it does ALL of this again. From scratch. Because the JVM has no memory between runs."

#### Column 2 — Training Run (walk top to bottom)

> "The training run is what Leyden introduces. It runs ONCE — in your CI/CD pipeline — and never again in production."

**@QuarkusIntegrationTest runs — highlight this:**
> "Here's the part that catches people off-guard: the training workload is your own test suite. The `@QuarkusIntegrationTest` tests you wrote for CI also train the JVM. Every endpoint you hit in your integration tests gets its class loading recorded, its method call patterns profiled. The better your tests represent production traffic, the more effective the cache."
>
> "This is also why there's a distinction between `@QuarkusTest` and `@QuarkusIntegrationTest`. `@QuarkusTest` runs in dev-mode JVM — it doesn't contribute to the AOT cache. `@QuarkusIntegrationTest` runs against the packaged JAR — this is the training workload."

**The three cache layers:**
> "Layer 1 is the base CDS layer — parsed bytecode, same as AppCDS on JDK 21. Layer 2, from JEP 483 on JDK 24, adds the full loaded and linked class state. Layer 3, from JEP 515 on JDK 25, adds the JIT method profiles."
>
> "The cache is self-invalidating. If your JARs change, the JVM detects the mismatch and rebuilds rather than running stale data."

#### Column 3 — Production Run with Cache (walk top to bottom)

**The SKIPPED work box — this is the key moment:**
> "Read what the JVM skips. Parse and verify — skipped. Load and link for 25,000 classes — skipped. JIT interpreter warmup phase — skipped. C1 profiling pass — skipped."
>
> "The JVM loads the pre-linked class state directly from the cache. Method profiles are pre-loaded so the JIT starts compiling hot methods immediately — at first request, not after 30 seconds of warmup."

**First request at ~148ms (Demo 04 verified result):**
> "For a Quarkus app, this brings startup from around 609ms on JDK 25 cold to 148ms with the cache — a 75% reduction. But the number I find more compelling is the warmup story: with the JIT profiles pre-loaded, your P99 latency is good from the very first request."

#### Closing

> "The summary: left column — this work repeats on every pod start. Right column — all of it is skipped. The cost was paid once during `mvn verify` in your CI pipeline."

### Suggested Slide Placement

```
Slide 31  Project Leyden (topic slide)
Slide 32  How Project Leyden Works (deck visual)
          ↓
Diagram 05  (whiteboard — deeper walk-through)
          ↓
Slide 33  Demo 04 intro
          ↓
Live demo: quarkus-demo-04-leyden/demo.sh
```

---

## Diagram 06 — JVM Anti-Patterns vs Fixes

**File:** `06-antipatterns-vs-fixes.excalidraw`

### Where it fits in the deck

- **Primary:** After slide **53** (Common JVM Anti-Patterns) and alongside slide **54** (Anti-Pattern Remediation)
- **Best use:** Printed A3 handout — one page attendees can take away with every anti-pattern and exact fix
- Works as a whiteboard where you circle patterns relevant to the audience's stack
- Workshop exercise: cover the right column, ask the room to suggest fixes

### Speaker Notes

#### Opening

> "Slides 53 and 54 showed you the anti-patterns and fixes as separate slides. This diagram puts them side-by-side. I'm going to walk the priority order — most critical at the top, diminishing returns as you go down. If you only fix the top four items in this table, you will eliminate 80 percent of the production incidents I've seen."

#### Memory section (rows 1–3)

**Row 1 — Hardcoded -Xmx:**
> "Every single production OOMKill investigation I've been involved in eventually traces back to this. Someone hardcoded -Xmx2g in 2018. The container limit was changed to 1.5g in 2021. Nobody noticed until a Friday at 5pm. The fix is two flags: UseContainerSupport — which ships ON by default since Java 15 — and MaxRAMPercentage=75. You never touch it again when the limit changes."

**Row 2 — MaxRAMPercentage=90:**
> "This leaves 10% for everything else. A Quarkus app with Vert.x, Netty, and a few framework extensions routinely needs 300-400 MB off-heap. At 90% in a 1 GB container, that's 100 MB remaining — not enough. 75 percent is the safe default. Go to 80 percent only after measuring."

**Row 3 — No MaxMetaspaceSize:**
> "Metaspace grows as new classes are loaded — framework scanning, proxies, dynamic code generation. Without a cap, it grows until the OS decides you've had enough. Set 256m. It's enough for most Quarkus apps."

#### GC & CPU section (rows 4–6)

**Row 4 — Default ParallelGCThreads:**
> "Write this down. ParallelGCThreads defaults to the host CPU count — not your container limit. On a 64-core node with a 2-core container, you get 64 GC threads sharing 2 CPUs. GC pauses can be 10 times longer than necessary. `-XX:ParallelGCThreads=2` — whatever your CPU request is."

**Row 5 — CPU-based HPA:**
> "GC pauses create CPU spikes. CPU-based HPA treats those spikes as load and scales out. The new pods also do GC. You get a feedback loop. Scale on RPS instead — it measures actual request load, unaffected by GC."

**Row 6 — minReplicas: 1:**
> "One extra pod. That's it. The cost of running two pods instead of one is trivial compared to the cost of a 100% error rate during a GC stop-the-world event."

#### AOT / Startup section (rows 7–8)

**Row 7 — @QuarkusTest for AOT training:**
> "`@QuarkusTest` runs in the development-mode JVM — it doesn't exercise the packaged JAR. `@QuarkusIntegrationTest` runs against the real packaged artifact. That's what contributes to the AOT cache. If your test suite is all `@QuarkusTest`, your `app.aot` will be tiny or empty. Check with: `ls -lh target/quarkus-app/app.aot`. If it's under 10 MB, training coverage is poor."

**Row 8 — Manual -XX flags in Dockerfile:**
> "Quarkus sets `-XX:AOTCache=app.aot` automatically from its generated launch scripts. If you also set it in your Dockerfile ENTRYPOINT, the JVM sees the flag twice and fails. Trust Quarkus. Set the property in application.properties, run `mvn verify`, don't touch the launch flags."

#### Observability section (rows 9–10)

**Row 9 — No GC pause histogram:**
> "Without the histogram, you have counts and sums for GC pause time, but you can't compute a P99. `jvm.gc.pause` counter tells you 'GC happened 40 times'. The histogram tells you 'GC P99 was 800ms for the last minute — fire an alert'. The Quarkus property is one line. Set it before your next deployment."

**Row 10 — Tuning without a baseline:**
> "I have seen engineers spend two days tuning GC flags based on intuition, with no measurement, and ship a change that made things worse. The workflow is: measure P99 startup time and P99 latency under load, change exactly one flag, measure again. If it improved — commit. If not — revert."

#### Priority bar (bottom of diagram)

> "The footer shows my recommended priority order if you're starting from scratch: memory flags first — they prevent OOMKills. Then `minReplicas: 2` — free reliability. Then ParallelGCThreads — immediately improves GC. Then fix the HPA metric. Then AOT cache setup. Then observability."

---

## Diagram 07 — REST vs gRPC Protocol Comparison

**File:** `07-grpc-vs-rest.excalidraw`

### Where it fits in the deck

- **Primary:** After slide **34** (REST vs gRPC comparison table) and before slide **35** (gRPC benchmarks)
- **Secondary:** Open during Demo 05 Q&A when someone asks "but why is gRPC faster in production?"
- Works well as a whiteboard — draw the wire format difference live, then show the streaming model

### Speaker Notes

#### Opening

> "The slide showed you the numbers. This diagram shows you why. I want to walk the three differences that together account for gRPC's production performance advantage."

#### Wire format comparison (left panel)

> "First, the payload. A REST JSON response for a simple JVM metrics object is around 220 bytes. The equivalent Protobuf response is around 40 bytes. That's 5× smaller on the wire. At 10,000 requests per second, that's roughly 1.8 GB per hour of bandwidth that REST is paying and gRPC is not."

> "More importantly than size — Protobuf is binary. The server doesn't need to serialise to JSON string. The client doesn't need to parse JSON. The CPU cost per request is lower on both sides."

#### HTTP/2 connection model (middle panel)

> "Second — and this is the bigger win in Kubernetes — connection persistence. REST over HTTP/1.1 opens a new TCP connection per request by default. Even with keep-alive, you're paying TLS handshake amortisation and connection pool management on both sides."

> "gRPC uses HTTP/2, which multiplexes multiple streams over a single persistent connection. For a service making 10,000 calls per second to a downstream dependency, that's 10,000 TCP handshakes per second you're not paying. On a real pod-to-pod network with 2-5ms latency, this is where the 3-4× throughput difference comes from."

> "This is also why the localhost benchmark in Demo 05 shows REST winning — on loopback, TCP handshake cost is zero. The gRPC advantage is network-dependent."

#### Streaming model (right panel)

> "Third — streaming. gRPC has four streaming modes baked into the protocol: unary, server streaming, client streaming, and bidirectional. REST requires WebSocket or SSE boilerplate for any push-based pattern."

> "In Demo 05, the server streaming endpoint returns 1,000 metric snapshots over a single connection. The REST equivalent requires 1,000 separate HTTP requests. Even on localhost, this difference is visible — the streaming demo shows gRPC winning because serialisation and framing overhead is paid once, not per message."

#### Honest caveat

> "One thing this diagram doesn't show: the localhost unary result. On loopback, REST wins unary. You will see this in Demo 05. I include the honest result because if I showed you only the production numbers, someone in this room would run the same benchmark at home and think I fabricated it. The localhost result is expected — gRPC's advantages are network-dependent."

### Suggested Slide Placement

```
Slide 34  REST vs gRPC comparison table
          ↓
Diagram 07  (whiteboard — wire format + HTTP/2 + streaming)
          ↓
Slide 35  gRPC in Quarkus 3.33.1 — benchmarks
          ↓
Slide 36  REST vs gRPC visual
          ↓
Slide 37  Demo 05 intro
          ↓
Live demo: quarkus-demo-05-grpc/demo.sh
```

---

## Diagram — RPC Architecture

**File:** `rpc-architecture.excalidraw`

### Where it fits in the deck

- **Primary:** After slide **34** (REST vs gRPC) as an architectural context-setter
- **Use case:** When the audience asks "when would I actually choose gRPC over REST?"
- Complements `07-grpc-vs-rest.excalidraw` — use this for the architecture picture, the other for the wire format detail

### Speaker Notes

#### Opening

> "This diagram answers the architectural question rather than the protocol question. When does your service mesh look like the left side versus the right side?"

**Public API boundary (left)**
> "Your public-facing API — the one browsers and mobile apps and partner integrations call — should be REST. Browsers speak HTTP/1.1 natively. Partners expect JSON. You can't ask your bank's external partner to generate Protobuf stubs. REST at the boundary is not a performance choice; it's an ecosystem reality."

**Internal service mesh (right)**
> "Everything inside the cluster boundary — service to service — is a candidate for gRPC. These are calls you control on both sides. You can generate stubs. You control the versioning. The network latency between pods is real — 2-5ms — and this is where gRPC's persistent connections and binary encoding pay off."

**The hybrid pattern:**
> "The common pattern is a gateway that terminates REST from the outside and speaks gRPC to internal services. Quarkus supports both protocols simultaneously on the same instance — the Demo 05 service exposes REST on port 8080 and gRPC on port 9000 from the same Quarkus application."

---

## Diagram — REST Order Sequence

**File:** `rest-order-sequence.excalidraw`

### Where it fits in the deck

- **Primary:** After slide **34** (REST vs gRPC) as a detailed sequence view
- **Use case:** When the audience wants to understand the per-request overhead REST pays vs gRPC streaming

### Speaker Notes

> "This sequence diagram shows the full lifecycle of a single REST request from client to server and back. I want you to count the number of steps — then compare them to what gRPC streaming eliminates."

**Walk the sequence:**
> "DNS lookup — TCP SYN/SYN-ACK/ACK — TLS ClientHello/ServerHello/Finished — HTTP request headers — server processing — HTTP response headers — response body — connection close or keep-alive negotiation. That's 8-12 round trips for a single request, even before your application code runs."

> "Now consider a gRPC server streaming call. You pay steps 1-7 ONCE when the connection is established. Then 1,000 metric snapshots come back as binary Protobuf frames on that single connection. There is no per-message overhead beyond the frame header. This is the Demo 05 streaming comparison — 1 connection vs 1,000 requests."

---

## Diagram — GraphQL Query Response

**File:** `graphql-query-response.excalidraw`

### Where it fits in the deck

- This diagram is a **reference visual** rather than a core talk diagram
- Use if your audience includes teams currently evaluating REST vs GraphQL vs gRPC
- Not part of the core 60-minute session — use in extended Q&A or workshop settings

### Speaker Notes

> "GraphQL is sometimes raised as an alternative to both REST and gRPC for internal services. The short answer for this talk's use case: GraphQL optimises the query expressiveness problem — clients ask for exactly what they need. It does not optimise the connection model or payload encoding problem. Over HTTP/1.1 with JSON, GraphQL has the same per-request overhead as REST. Over HTTP/2, it improves, but it still can't match Protobuf binary encoding. GraphQL is the right choice for public APIs where clients have heterogeneous data needs. gRPC is the right choice for internal microservice communication where both sides are under your control."

---

## Using These Diagrams in Your Presentation

### As whiteboard moments (recommended)

Keep excalidraw.com open in a browser tab. Switch to it at the relevant slide and trace through the diagram live. This creates an interactive moment that breaks up slide-deck monotony and signals to the audience that you understand the material well enough to draw it. Diagrams 01, 04, and 07 work especially well this way.

### As a handout

Export each diagram to PNG from Excalidraw (`Export image → PNG`) and include in a PDF handout alongside the slides. Diagram 06 (anti-patterns) is the most valuable handout — people want to take it away and check their own deployments.

### As backup slides

If you have a technically engaged audience or a longer timeslot, add these directly into the deck as extra slides at the relevant positions. Excalidraw export to SVG or PNG works cleanly at any resolution.

### Suggested flow with the 54-slide deck

| Deck slide | Insert diagram | Reason |
|------------|----------------|--------|
| After slide 5 — Container-Aware Before/After | Diagram 04 | Visual confirms the cgroup story |
| After slide 6 — JVM Memory Regions | Diagram 02 | Expands each region with flags + sizing formula |
| After slide 10 — GC in Containers | Diagram 01 | Draws the full HPA thrash domino chain |
| After slide 14 — AOT Cache Progression | Diagram 03 | Clarifies JDK 21→24→25→26 cache evolution |
| After slide 21 — HPA with JVM Metrics | Diagram 01 | Second reference — the fix is now on screen |
| After slide 32 — How Leyden Works | Diagram 05 | Deeper walk-through before Demo 04 |
| After slide 34 — REST vs gRPC | Diagram 07 | Wire format + HTTP/2 + streaming model |
| After slide 34 — REST vs gRPC | `rpc-architecture` | Architecture: where REST vs gRPC at boundary |
| After slide 53 — Anti-Patterns | Diagram 06 | Side-by-side reference for all 16 patterns |

---

## Diagram Timing Reference

| Diagram | Walk-through time | Whiteboard time |
|---------|-----------------|-----------------|
| 01 — HPA Thrash Cycle | 3 min | 4 min |
| 02 — JVM Memory Regions | 4 min | 5 min |
| 03 — AOT Cache Progression | 3 min | 4 min |
| 04 — Container-Aware JVM | 3 min | 3 min |
| 05 — How Leyden Works | 6 min | 8 min |
| 06 — Anti-Patterns vs Fixes | 5 min | 7 min |
| 07 — REST vs gRPC | 4 min | 5 min |
| rpc-architecture | 2 min | 3 min |
| rest-order-sequence | 2 min | 3 min |
| graphql-query-response | 1 min | Reference only |
