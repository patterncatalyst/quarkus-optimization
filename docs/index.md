---
title: Home
layout: default
nav_order: 1
description: "Demos for optimizing Quarkus applications in containers and on Kubernetes."
permalink: /
---

# Quarkus Optimization
{: .fs-9 }

Hands-on demos, diagrams, and slides for tuning Quarkus apps to run lean, start fast, and scale predictably on containers and Kubernetes.
{: .fs-6 .fw-300 }

[Get started](#getting-started){: .btn .btn-primary .fs-5 .mb-4 .mb-md-0 .mr-2 }
[View on GitHub](https://github.com/patterncatalyst/quarkus-optimization){: .btn .fs-5 .mb-4 .mb-md-0 }

---

## What's in this project

This repository collects the material behind a working session on Quarkus optimization. Everything is organized into three streams:

| Section | What it covers |
|---|---|
| [Java Optimization Demos](./demos/) | Runnable Quarkus demos — JVM vs. native, container tuning, CDS, profiling. |
| [Diagrams](./diagrams/) | Architecture and flow diagrams referenced throughout the demos and talk. |
| [Presentation](./presentation/) | Slides and speaker material used in conference sessions and internal briefings. |

## Getting started

Clone the repository and pick the demo you want to run:

```bash
git clone https://github.com/patterncatalyst/quarkus-optimization.git
cd quarkus-optimization/java-optimization-demos
```

Each demo directory is self-contained with its own README, build scripts, and container definitions.

### Prerequisites

- JDK 21+ (the repo includes a `.sdkmanrc` — run `sdk env` if you use SDKMAN)
- Maven or the Quarkus CLI
- Podman or Docker for the container demos
- Optional: a local Kubernetes cluster (kind, minikube, or CRC) for the deployment demos

## Themes explored

{: .note }
> The demos are intentionally small and focused. Each one isolates a single optimization lever so you can see its effect independently before combining techniques.

- **Startup time** — JVM tuning, Class Data Sharing (CDS/AppCDS), AOT, native image
- **Memory footprint** — heap sizing, metaspace, native vs. JVM baselines
- **Container efficiency** — base image selection, layered JARs, resource requests/limits
- **Runtime observability** — what to measure when you're measuring "optimization"

## License & contributions

See the repository for license terms. Issues and pull requests welcome at
[github.com/patterncatalyst/quarkus-optimization](https://github.com/patterncatalyst/quarkus-optimization).
