---
title: Presentation
layout: default
nav_order: 4
has_children: false
permalink: /presentation/
---

# Presentation
{: .no_toc }

Slides and speaker material for the Quarkus Optimization session.
{: .fs-6 .fw-300 }

## Contents
{: .no_toc .text-delta }

1. TOC
{:toc}

---

## Overview

The [`presentation/`](https://github.com/patterncatalyst/quarkus-optimization/tree/main/presentation)
directory contains the deck and supporting material for delivering this content
as a conference talk or internal session. The slides mirror the structure of
the [demos](../demos/), so you can present, pause, and run a demo inline.

## Session abstract

**Title:** Optimizing Quarkus in Containers and on Kubernetes

**Abstract:**
Quarkus gives you fast startup and low footprint out of the box — but there's a
meaningful gap between "works on my laptop" and "runs well in a production
Kubernetes cluster." This session walks through the levers that actually move
the needle: JVM tuning, Class Data Sharing, native image, container layering,
and right-sizing resource requests. Each technique is shown as an isolated,
runnable demo with before/after measurements, so you leave with a mental model
of which optimization to reach for and when.

**Audience:** Java developers and platform engineers running Quarkus (or
considering it) on Kubernetes or OpenShift.

**Takeaways:**
- A repeatable measurement harness for comparing Quarkus builds
- Clear guidance on when native image is worth the build-time cost
- A checklist for container and Kubernetes settings that affect startup and
  memory behavior
- Links to every demo so you can replay them after the session

## Viewing the slides

### Option 1 — PDF export

If you commit a `presentation/slides.pdf`, link to it directly:

```markdown
[Download slides (PDF)](https://github.com/patterncatalyst/quarkus-optimization/raw/main/presentation/slides.pdf)
```

### Option 2 — Reveal.js hosted on this site

If the slides are reveal.js (HTML/JS), they can be served directly from GitHub
Pages. Put the reveal.js build under `docs/presentation/slides/` and link to
`./slides/` — Jekyll will pass through the static assets untouched.

### Option 3 — Speaker Deck / SlideShare embed

If the deck lives on Speaker Deck, embed it with the provided iframe snippet.

## Running the talk

Suggested flow for a 45-minute slot:

1. **Framing (5 min)** — Why optimization beyond "it starts fast" matters in a
   shared cluster.
2. **Baseline demo (5 min)** — Measure a default Quarkus service. Capture the
   numbers you'll compare everything against.
3. **JVM tuning & CDS (10 min)** — Show the startup and memory impact.
4. **Native image (10 min)** — Build, measure, discuss the trade-offs (build
   time, reflection config, debuggability).
5. **Container & Kubernetes (10 min)** — Image layering, requests/limits,
   probes tuned for real startup behavior.
6. **Wrap-up (5 min)** — Decision matrix: which lever, when.

## Speaker notes & resources

- [Demo index](../demos/) — every running example referenced in the deck
- [Diagrams](../diagrams/) — source files for every slide diagram
- [Quarkus performance guide](https://quarkus.io/guides/performance-measure)
- [Mandrel (Red Hat build of GraalVM)](https://developers.redhat.com/products/mandrel/overview)

{: .note }
> If you're re-using this session, consider recording the measurement numbers
> live during rehearsal on the same hardware you'll present on — cluster
> behavior and laptop behavior diverge enough that stale numbers are worse
> than no numbers.
