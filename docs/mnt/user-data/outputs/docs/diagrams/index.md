---
title: Diagrams
layout: default
nav_order: 3
has_children: false
permalink: /diagrams/
---

# Diagrams
{: .no_toc }

Architecture and flow diagrams used throughout the demos and the talk.
{: .fs-6 .fw-300 }

## Contents
{: .no_toc .text-delta }

1. TOC
{:toc}

---

## About these diagrams

The [`diagrams/`](https://github.com/patterncatalyst/quarkus-optimization/tree/main/diagrams)
directory in the repository holds the visual references for each major topic
covered in the demos and presentation. They are stored as source files (e.g.
`.drawio`, `.puml`, `.mmd`) alongside exported PNGs where available so they can
be edited and re-exported cleanly.

{: .tip }
> If you're embedding diagrams in slides or docs, always link back to the
> source file so the next person can update it without reverse-engineering the
> layout.

## Embedding diagrams on this site

There are three good options depending on the source format.

### Mermaid (inline)

If you commit a diagram as a Mermaid source block, you can render it inline on
any Jekyll page:

```markdown
```mermaid
flowchart LR
    Dev[Developer] --> Build[Container Build]
    Build --> Registry[(Registry)]
    Registry --> K8s[Kubernetes]
    K8s --> Pod[Quarkus Pod]
```
```

To enable Mermaid rendering with Just the Docs, add this to `_config.yml`:

```yaml
mermaid:
  version: "10.9.0"
```

### PNG / SVG (exported)

For diagrams authored in draw.io, Excalidraw, or PlantUML, commit both the
source and the exported image:

```markdown
![Container build flow](https://raw.githubusercontent.com/patterncatalyst/quarkus-optimization/main/diagrams/container-build.png)
```

### draw.io (.drawio) embed

Link directly to the source file on GitHub for people who want to edit:

```markdown
[Edit in draw.io](https://github.com/patterncatalyst/quarkus-optimization/blob/main/diagrams/container-build.drawio)
```

## Diagram index

Replace this list as you add diagrams. Suggested structure:

### Build pipeline

End-to-end flow from source through container build to a Kubernetes deployment,
annotated with the optimization points the demos focus on.

- Source: [`diagrams/build-pipeline.drawio`](https://github.com/patterncatalyst/quarkus-optimization/tree/main/diagrams)

### JVM vs. native startup

Side-by-side timeline of what happens during startup in each mode, with the
class-loading, JIT warmup, and AOT phases called out.

- Source: [`diagrams/startup-timeline.drawio`](https://github.com/patterncatalyst/quarkus-optimization/tree/main/diagrams)

### Container image layering

How a layered Quarkus JAR maps onto container image layers, and why that
matters for pull time and cache reuse.

- Source: [`diagrams/image-layers.drawio`](https://github.com/patterncatalyst/quarkus-optimization/tree/main/diagrams)

### Kubernetes resource sizing

Decision flow for setting requests/limits on a Quarkus workload based on the
measurements from the demos.

- Source: [`diagrams/resource-sizing.drawio`](https://github.com/patterncatalyst/quarkus-optimization/tree/main/diagrams)

{: .note }
> Keep diagrams source-controlled. Screenshots of diagrams that only exist in
> someone's local Lucidchart account tend to rot faster than the code they
> describe.
