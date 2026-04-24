---
title: "GC-Induced HPA Thrash Cycle"
description: "Why CPU-based HPA and JVM GC are a dangerous combination. The feedback loop that takes 3 pods to 20 with zero real load."
excalidraw_file: "01-gc-hpa-thrash-cycle.excalidraw"
order: 1
slide_ref: "10–11, 21"
slide_placement: "After slide 10 (GC in Containers) — also use after slide 21 (HPA with JVM Metrics)"
---

The most important diagram in the talk for platform engineers. Shows the six-step
domino chain: GC pause → CPU spike → HPA scales out → new pods also GC → HPA scales
again → cost explosion.

## When to use this diagram

- After slide 10 (GC in Containers) to draw the full thrash chain
- As a Q&A answer when someone asks "why can't I just use CPU-based HPA?"
- After slide 21 (HPA with JVM-Aware Metrics) — the fix is on that slide, the diagram shows the "why"

## Opening line

> "I want to show you why CPU-based HPA and the JVM are a dangerous combination.
> This is a loop that I have seen take a cluster from 3 pods to 20 pods with zero actual load increase."

## Walk box by box

**① Normal Operation** — App running, GC under 200ms, requests being served.

**② GC Pause** — GC fires. Stop-the-world halts application threads. GC threads spike CPU to 100% for 50–200ms.

**③ HPA Scales Out** — HPA scrapes CPU at 30s intervals, sees the spike, adds three pods. Wrong response — the spike was GC, not load.

**④ New Pods Also GC** — Cold pods do JVM bootstrap + JIT warmup. All spike CPU during startup GC. HPA sees sustained high CPU.

**⑤ HPA Scales Again** — More pods. More GC. More spikes.

**⑥ Cost Explosion** — 20 pods for a 3-pod workload. On-call engineer has no idea why.

## The fix

> "Two things together solve this. Change the HPA metric to RPS — completely unaffected by
> GC CPU spikes. Add `stabilizationWindowSeconds: 120` on scaleUp — longer than any normal
> GC pause. Together these make HPA work correctly for Java."
