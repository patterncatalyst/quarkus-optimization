---
title: Java Optimization Demos
layout: default
nav_order: 2
has_children: true
permalink: /demos/
---

# Java Optimization Demos
{: .no_toc }

Runnable Quarkus demos showing specific optimization techniques in isolation.
{: .fs-6 .fw-300 }

## Contents
{: .no_toc .text-delta }

1. TOC
{:toc}

---

## Overview

The [`java-optimization-demos/`](https://github.com/patterncatalyst/quarkus-optimization/tree/main/java-optimization-demos)
directory in the repository contains a set of independently runnable projects. Each
demo is designed to answer one question about Quarkus behavior under different
configurations, so you can reason about each lever before combining them.

{: .tip }
> Start with the JVM baseline for any demo before comparing to native or CDS builds.
> The baseline is what makes the optimization *visible*.

## How the demos are structured

Every demo folder follows the same layout so you can navigate quickly:

```text
demo-name/
├── README.md           # What this demo proves, and how to run it
├── pom.xml             # Quarkus project
├── src/                # Minimal application code
├── Dockerfile.jvm      # JVM container build
├── Dockerfile.native   # Native container build
└── scripts/            # Run / benchmark helpers
```

## Demo index

Replace this list with one entry per folder you've published. Example entries:

### Startup & footprint baseline

A minimal Quarkus REST service used as a reference point for every other demo in
the set. Captures startup time, first-request latency, and RSS in both JVM and
native modes.

- Source: [`java-optimization-demos/baseline`](https://github.com/patterncatalyst/quarkus-optimization/tree/main/java-optimization-demos)
- Run: `./scripts/run-jvm.sh` / `./scripts/run-native.sh`

### Class Data Sharing (CDS / AppCDS)

Demonstrates the startup improvement from generating and using a shared class
archive with a standard HotSpot Quarkus build.

- Source: [`java-optimization-demos/cds`](https://github.com/patterncatalyst/quarkus-optimization/tree/main/java-optimization-demos)

### Native image build

Native executable via GraalVM / Mandrel, with a size and startup comparison
against the JVM build.

- Source: [`java-optimization-demos/native`](https://github.com/patterncatalyst/quarkus-optimization/tree/main/java-optimization-demos)

### Container tuning

Layered JARs, right-sized base images, and resource requests/limits that
actually match the workload.

- Source: [`java-optimization-demos/container`](https://github.com/patterncatalyst/quarkus-optimization/tree/main/java-optimization-demos)

{: .note }
> Update this page as you add or rename demo folders. The section structure above
> matches the themes covered in the [Presentation](../presentation/).

## Running everything

From the repository root:

```bash
cd java-optimization-demos
# Pick a demo folder, then:
./mvnw quarkus:dev             # live-reload JVM mode
./mvnw package                 # standard build
./mvnw package -Dnative        # native build (needs GraalVM/Mandrel)
```

For container builds:

```bash
podman build -f Dockerfile.jvm    -t quarkus-demo:jvm .
podman build -f Dockerfile.native -t quarkus-demo:native .
```

## Measuring results

When comparing runs, capture at minimum:

- **Cold start time** — process launch to first successful request
- **RSS at idle** — resident memory a few seconds after startup settles
- **RSS under load** — with a simple `hey` / `wrk` / `k6` run
- **Image size** — `podman images` for each variant

A consistent measurement harness matters more than any single number — the goal
is relative comparison across demos, not a synthetic benchmark.
