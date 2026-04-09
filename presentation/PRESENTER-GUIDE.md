# Presenter Guide — Taming the JVM: Optimizing Java on OpenShift
## Speaker Notes & Timing Cues

---

## Session Overview

**Total time:** 60 minutes  
**Format:** 50 min talk + 10 min Q&A (or 45 min + 15 min if audience is interactive)  
**Target:** Java developers and platform engineers with some Kubernetes exposure  
**Tone:** Engineering-first, data-driven, hands-on

---

## Slide-by-Slide Notes

---

### SLIDE 1 — Title (0:00–1:00)

**Say:**
> "If you've deployed Java to Kubernetes and wondered why your pods keep getting OOMKilled,
> why autoscaling fires at 3am for no apparent reason, or why your startup time is 8 seconds
> when your Golang colleagues ship in 50ms — this talk is for you.
> Everything we cover today is based on two O'Reilly books and real production incidents."

**Transition:** "Let's look at what we're covering and where the demos fit."

---

### SLIDE 2 — Agenda (1:00–2:00)

**Say:**
> "Seven topics, three live demos. Each section builds on the previous one —
> we go from 'how does the JVM even see memory in a container' all the way to
> 'here's how to show your CFO you saved money.' The demos are runnable right now
> on your laptop — all Docker, no Kubernetes cluster needed."

**Point out:** The demo bar at the bottom — demos are woven into sections 1, 3, and 4.

---

### SLIDE 3 — The Problem (2:00–4:00)

**Say:**
> "Before we tune anything, let's understand why this is hard. The JVM was designed
> in 1995 for a world where you owned the whole machine. Kubernetes is a world where
> you own 512 megabytes of a shared machine. These two worlds collide badly.
>
> The 60% figure comes from production data across Red Hat's customer base — the
> majority of Java deployments we've seen overprovision memory by 2-4x.
> That's not a developer mistake, that's a tooling gap we're going to close today."

**Anecdote option:**
> "I've seen a team running 3 Spring Boot pods on a 16GB node — each claiming a 4GB
> heap — meaning 12GB reserved for JVM processes that actually used 600MB each.
> The remaining 4GB was unusable dead space. Same application, properly tuned:
> 8 pods on the same node."

---

### SLIDE 4 — Container-Native JVM Fundamentals (4:00–8:00)

**Key point to emphasize:**
> "UseContainerSupport is ON by default in Java 21. But MaxRAMPercentage is NOT set
> to a sensible value by default — it's 25%, which is too conservative.
> The first flag you add to every Java container is MaxRAMPercentage=75."

**Live check for audience:**
> "Quick show of hands — how many of you explicitly set MaxRAMPercentage in your
> Kubernetes deployments today?" [Usually <30%]

**Explain the code block:**
- Left column: the BEFORE — hardcoded -Xmx breaks when VPA changes limits
- Right column: the AFTER — reads cgroup dynamically, scales with container

**cgroup v2 note:**
> "If you're on RHEL 9 or OCP 4.14+, you're on cgroup v2 — the unified hierarchy.
> Java 15+ handles this correctly. If you're on RHEL 8, you're on cgroup v1.
> Both work with the same JVM flags."

---

### SLIDE 5 — JVM Memory Regions (8:00–10:00)

**The key misconception to bust:**
> "People set MaxRAMPercentage=90 thinking 'more heap = better'.
> But heap is only ONE of six memory regions the JVM uses.
> Metaspace, JIT code cache, thread stacks, GC structures — they all consume
> memory OUTSIDE the heap. If your heap is 90% of the container limit,
> you've left no room for these, and you'll OOMKill during class loading."

**Virtual Threads callout:**
> "Java 21's Virtual Threads change the thread stack budget entirely.
> With platform threads, 200 threads × 1MB stack = 200MB off-heap.
> With virtual threads, those stacks live in heap as small continuations.
> We have a full slide on this — but plant the seed now."

---

### SLIDE 6 — Right-Sizing (10:00–12:00)

**Requests vs Limits framing:**
> "Think of requests as your SLA to the scheduler: 'I promise I'll use at least this much.'
> Think of limits as your circuit breaker: 'Kill me if I exceed this.'
> Most teams set them equal. That's wrong. Your limit should be 25-30% above your
> P99 usage — enough buffer for a GC surge without triggering OOMKill."

**Formula walkthrough:**
- Walk through the memory sizing formula box slowly
- Stress the `jcmd VM.native_memory summary` command — it's the ground truth

---

### SLIDE 7 — Pod Bin-Packing (12:00–14:00)

**The visual is the story here:**
> "Same node, same 32GB of RAM. Before: 3 pods because each JVM claimed 8GB.
> After: 6 pods because each JVM correctly claims 1.5GB.
> That's a 2x improvement in node density — meaning you could potentially
> cut your node count in half. On a cluster costing $10k/month, that's $5k/month
> back in your budget."

> "This slide should be your 'business case' slide when talking to your manager."

---

### SLIDE 8 — GC in Containers (14:00–16:00)

**GC-induced HPA thrash is the most surprising finding:**
> "Most people have never thought about this: your GC pauses look like CPU spikes
> to Kubernetes. HPA sees CPU spike → scales out → new pods start → they also have
> GC → more CPU spikes → more scale-out. You can end up with 20 pods for a workload
> that needs 3, and the cluster is just chasing its own tail.
> The fix involves both GC tuning AND HPA configuration — we cover both."

---

### SLIDE 9 — GC Comparison Table (16:00–18:00)

**Walk through each row:**
- **G1GC:** "The safe default. Good for 99% of microservices. Start here."
- **ZGC (Generational):** "Java 21's headline GC. Sub-millisecond pauses at any heap size.
  The `-XX:+ZGenerational` flag is new in Java 21 and is the recommended mode.
  If you're on Java 21, this is your low-latency answer."
- **Shenandoah:** "OpenJDK's answer, default on RHEL/Fedora JDK. Similar to ZGC,
  excellent if you're committed to the Red Hat ecosystem."
- **Serial GC:** "Never for microservices. Only for tiny batch containers or CLIs."

**Decision rule:**
> "If your P99 GC pause from Prometheus is > 500ms consistently → switch from G1 to ZGC.
> If P99 is < 200ms, G1 is fine — don't change what's working."

---

### SLIDE 10 — GC Tuning Parameters (18:00–20:00)

**Critical for the audience:**
> "ParallelGCThreads is the most commonly missed flag.
> JVM defaults it to the number of CPUs it sees — which on a 64-core node
> with a 2-CPU limit means 64 GC threads fighting for 2 CPU slots.
> Set ParallelGCThreads equal to your CPU limit. Always."

---

### SLIDE 11 — Startup Time Challenges (20:00–22:00)

**Set up Demo 03:**
> "This timeline is what 4-6 seconds of cold start looks like broken down.
> The class loading phase is the part we can attack with AppCDS.
> The Spring context init is where you'd look at lazy initialization.
> We have a live demo that shows the improvement with real numbers."

---

### SLIDE 12 — AppCDS (22:00–25:00)

**Explain the three-stage Docker build:**
> "The key insight is that AppCDS generates a binary archive of pre-processed class metadata.
> We bake that archive INTO the Docker image during build.
> At runtime, the JVM memory-maps the archive — reads are near-instant because
> the OS page cache handles it.
> Zero runtime overhead. Pure startup savings."

**Spring Boot 4.0 point:**
> "Spring Boot 4.0 added first-class support via the Maven plugin.
> `spring.context.exit=onRefresh` tells Spring to exit after context init
> so we can capture the full class list including all Spring beans."

---

### SLIDE 13 — Java 21 Virtual Threads ⭐ (25:00–28:00)

**This is a high-energy slide — deliver it with conviction:**
> "Virtual threads are the biggest concurrency change in Java in 20 years.
> JEP 444, shipped in Java 21 as a production feature.
>
> The container sizing implication is huge:
> Platform threads cost 1MB of stack memory each.
> 200 concurrent requests = 200MB of thread stack off-heap.
> With virtual threads, that stack memory is heap-allocated as tiny continuations —
> we're talking kilobytes per virtual thread, not megabytes.
>
> For a REST service handling 200 concurrent requests,
> you could potentially drop your memory limit from 512MB to 256MB.
> Same throughput, half the memory bill."

**Spring Boot one-liner:**
> "One property: `spring.threads.virtual.enabled=true`.
> Spring Boot 4.0 automatically configures Tomcat to use virtual threads.
> If you're on Java 21 and Spring Boot 4.0, you should enable this today."

**Caveat — say this so the audience trusts you:**
> "Virtual threads don't help if your code holds synchronized locks while doing I/O —
> that 'pins' the carrier thread and you lose the benefit.
> Watch for `synchronized` blocks around database calls or HTTP client calls.
> Use `ReentrantLock` instead, or check with `-Djdk.tracePinnedThreads=full`."

---

### SLIDE 14 — Observability Stack (28:00–31:00)

**Key message:**
> "You cannot tune what you cannot see. Every tuning recommendation I've made
> in this talk needs data to validate it. If you leave with one takeaway on observability,
> it's this: get jvm_gc_pause_seconds into Prometheus before your next performance incident."

**Cryostat pitch (OpenShift specific):**
> "If you're on OpenShift, Cryostat is a game-changer. JFR has always been the gold standard
> for JVM profiling but it's been a pain to manage in Kubernetes. Cryostat wraps it in
> a Kubernetes-native operator — you can start recordings from the UI or CI pipeline."

---

### SLIDE 15 — Cryostat + JFR (31:00–33:00)

**Architecture walkthrough:**
> "The agent runs inside your pod as a javaagent — zero code changes.
> It registers with the Cryostat server which runs as a separate pod.
> Recordings are stored in Kubernetes-native storage.
> You get flame graphs, allocation profiles, and GC event timelines
> all without SSH-ing into pods."

---

### SLIDE 16 — Prometheus + Micrometer (33:00–36:00)

**Walk through the PrometheusRule:**
> "This alert is the exact rule I recommend for every Java team.
> If your P99 GC pause is over 500ms for more than 30 seconds,
> you have a GC problem that needs addressing — not a scaling problem.
> The distinction matters: scaling won't fix a GC tuning issue,
> it'll just give you more pods with the same GC problem."

---

### SLIDE 17 — HPA with JVM Metrics (36:00–39:00)

**The key insight:**
> "Standard HPA on CPU is the wrong signal for Java.
> GC pauses create CPU spikes that HPA misreads as load.
> Scale on request rate instead — it's a leading indicator of actual load,
> not a lagging artifact of GC behavior."

**stabilizationWindowSeconds:**
> "This is the tuning knob most people don't know about.
> Default is 0 seconds for scale-up — meaning HPA acts the instant it sees
> a metric breach. With Java, a GC pause that lasts 300ms can trigger scale-out.
> Set stabilizationWindowSeconds: 120 to ignore transient spikes."

---

### SLIDE 18 — VPA (39:00–41:00)

**Practical workflow:**
> "Run VPA in Off mode for 72 hours first. Just let it observe.
> Then compare its recommendations to your actual memory budget calculation.
> If VPA recommends 400MB and your JVM math says 'need at least 350MB',
> you have alignment. If VPA says 800MB and you sized for 400MB,
> someone's math is wrong — investigate before applying."

---

### SLIDE 19 — Autoscaling Thrash Prevention (41:00–43:00)

**Quick pace — these are operational best practices:**
> "Six rules. Three most important:
> One — scale on RPS not CPU.
> Two — keep minReplicas at 2 or more.
> Three — set memory limit 25% above your P99 peak so GC surges don't kill the pod."

---

### SLIDE 20 — Systematic Tuning Workflow (43:00–46:00)

**This is the meta-lesson:**
> "Every recommendation in this talk follows the same loop:
> Instrument → Baseline → Diagnose → Tune → Validate.
> The number one mistake I see is teams skipping Baseline and Validate.
> They apply JVM flags they read on Stack Overflow and never measure the effect.
> Change one thing. Measure. Commit or revert. Move to the next thing."

**Document everything:**
> "Keep a tuning log. When you change MaxGCPauseMillis from 200 to 100,
> write down why, what you expected, and what actually happened.
> This becomes your runbook for the next incident."

---

### SLIDE 21 — Cost Optimization (46:00–48:00)

**Close the business case:**
> "Engineering work that reduces cloud spend is increasingly strategic.
> These numbers — 40-60% memory reduction, 2-3x pod density — translate directly
> to node savings. If your cluster is 20 nodes at $500/month each,
> improving density by 2x means you could run the same workload on 10 nodes.
> That's $5,000/month, $60,000/year — from JVM flags.
>
> Use OpenShift Cost Management to track before/after.
> Screenshot it. Put it in your quarterly review."

---

### SLIDES 22–24 — Demos (48:00–58:00)

#### Demo 01 — Heap Sizing (~4 min)
- Open terminal, `cd demo-01-heap-sizing`
- `./demo.sh` — it walks through all four scenarios automatically
- **Pause** at Scenario A output: "See that? 4GB heap in a 512MB container."
- **Pause** at Scenario B output: "Now 384MB — exactly 75% of 512MB."
- **Pause** at OOMKill: "Exit code 137. That's what your pods look like in CrashLoopBackOff."

#### Demo 02 — GC Monitoring (~4 min)
- Stack should already be running (start it before the talk)
- Open Grafana at http://localhost:3000 on the projector
- `./demo.sh` or manually run curl commands from another terminal
- **Point at** the GC pause P99 panel during heavy allocation
- **Point at** the heap utilization gauges and the G1GC vs ZGC comparison
- "Watch the G1GC P99 spike to 300ms during 100MB allocation. ZGC stays flat."

#### Demo 03 — AppCDS (~4 min)
- Run `./demo.sh` from demo-03-appcds
- While it builds (~30s): talk about what the three-stage Dockerfile does
- Show the timing table output: "We went from 4.2 seconds to 2.4 seconds. 43% faster."
- "Every HPA scale-out event benefits from this. 10 pods × 2 seconds saved = 20 seconds
  less degraded service during a traffic spike."

---

### SLIDE 25 — Key Takeaways (58:00–59:30)

**Read each one slowly — they should be memorable:**
1. "UseContainerSupport is default on. MaxRAMPercentage=75 is not. Set it."
2. "Measure RSS and off-heap before sizing. Math beats guesswork."
3. "G1GC for general use. ZGC Generational for latency-sensitive. Don't guess — measure P99."
4. "AppCDS saves 35-55% startup time. Spring Boot 4.0 makes it one command."
5. "Observe first, tune second. JFR + Cryostat + Prometheus is your foundation."
6. "Autoscale on RPS not CPU. GC pauses lie to HPA."
7. "Quantify the savings. $60k/year from JVM flags is a defensible engineering investment."

---

### SLIDE 26 — Q&A (59:30–60:00 + Q&A)

**Common questions and suggested answers:**

**Q: "Does this work with Quarkus/Micronaut?"**
> "Mostly yes — UseContainerSupport and MaxRAMPercentage are JVM flags,
> not framework flags. GC selection applies to any JVM workload.
> Quarkus Native (GraalVM) bypasses the JVM entirely — different tradeoffs.
> AppCDS is less relevant for Quarkus since startup is already sub-second."

**Q: "What about GraalVM Native Image?"**
> "Native Image is compelling for startup time — sub-100ms vs 2-4s with AppCDS.
> But it trades runtime performance for startup speed, and the build time is long.
> For most teams, AppCDS + Virtual Threads gets you 80% of the benefit
> with much lower operational complexity."

**Q: "What Java version should we target?"**
> "Java 21 LTS, full stop. It's the first LTS with Virtual Threads, Generational ZGC,
> and mature AppCDS support. If you're on Java 17 LTS, upgrade — the container
> optimization story is meaningfully better on 21."

**Q: "How often should we retune?"**
> "After any significant: traffic pattern change, application refactor,
> dependency major version upgrade, or infrastructure change.
> Run your JFR recording monthly in production as a baseline check."

**Q: "Is it safe to run ZGC in production?"**
> "Yes. Generational ZGC (Java 21) is production-ready. Netflix, LinkedIn,
> and many others run it at scale. The higher CPU overhead is real —
> benchmark your specific workload before switching."

---

## Timing Checkpoints

| Time   | Slide / Activity              | Action if Running Late        |
|--------|-------------------------------|-------------------------------|
| 5 min  | End slide 5                   | On track ✅                    |
| 14 min | End slide 8 (start GC)        | Skip bin-packing anecdote     |
| 22 min | End slide 11 (startup)        | Shorten AppCDS code walkthrough |
| 30 min | End slide 15 (Cryostat)       | Skip architecture detail on 15 |
| 43 min | End slide 19 (autoscaling)    | Merge slides 18 & 19 verbally |
| 48 min | Demos begin                   | Cut Demo 02 to 2 min if needed |
| 58 min | Demos complete, slide 25      | Speed-read takeaways          |
| 60 min | Q&A start                     |                               |

---

## Pre-Talk Checklist

- [ ] Demo 02 stack started 5 min before talk (`docker compose up -d` from demo-02-gc-monitoring)
- [ ] Grafana dashboard open in browser tab at localhost:3000
- [ ] Terminal window open in each demo directory
- [ ] Presenter notes hidden (use presenter view in PowerPoint/Keynote)
- [ ] Backup: screenshots of demo output in case Docker fails
- [ ] Backup: Record demo runs locally as a GIF with `asciinema` or `vhs`

---

## Backup Slides / Talking Points

If a demo fails, pivot to these talking points:

**Demo 01 fails:** Show slide 7 (bin-packing before/after visual) and walk through
the jcmd commands verbally: "This is what you'd see in your container."

**Demo 02 fails:** Walk through the Prometheus PromQL examples on slide 16.
"You'd run this exact query. Here's what the output looks like — I have it on my phone."

**Demo 03 fails:** Show the timing data in the slide and reference the Spring Boot
documentation for `spring-boot:build-image` with CDS support.
