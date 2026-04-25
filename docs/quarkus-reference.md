---
layout: default
permalink: /docs/quarkus-reference/
title: Quarkus Configuration Reference
description: "Full configuration reference for Quarkus 3.33.1 LTS on OpenShift and Kubernetes"
---

<div class="container">
  <nav class="breadcrumb">
    <a href="{{ '/' | relative_url }}">Home</a> /
    <a href="{{ '/docs/' | relative_url }}">Docs</a> /
    <span>Quarkus Configuration Reference</span>
  </nav>

  <div style="display:flex;justify-content:space-between;align-items:flex-start;margin:1.5rem 0;flex-wrap:wrap;gap:1rem;">
    <div>
      <h1>Quarkus Configuration Reference</h1>
      <p style="color:var(--muted);margin-top:.4rem;">
        Comprehensive configuration reference for Quarkus 3.33.1 LTS workloads running on
        OpenShift and Kubernetes. Covers all 9 demos from container images through Panama FFM.
      </p>
    </div>
    <a href="{{ site.repo }}/blob/main/java-optimization-demos/QUARKUS-README.md"
       target="_blank" class="btn btn-outline btn-sm">View on GitHub ↗</a>
  </div>

  <div class="grid grid-2" style="margin-bottom:1.5rem;">
    <div class="card" style="pointer-events:none;">
      <h3 style="color:var(--teal);">UBI9 Default GC — Shenandoah</h3>
      <p style="color:var(--muted);font-size:.875rem;line-height:1.6;">
        <code>ubi9/openjdk-21-runtime</code> ships <strong style="color:var(--text);">Shenandoah</strong>
        as the default GC — not G1GC. Temurin, Corretto, and Microsoft all default to G1GC.
        Demos that compare GC algorithms override explicitly.
      </p>
    </div>
    <div class="card" style="pointer-events:none;">
      <h3 style="color:var(--teal);">Multi-Stage Dockerfile Pattern</h3>
      <pre style="font-size:.75rem;margin-top:.5rem;"><code>FROM maven:3.9-eclipse-temurin-21 AS builder
# USER root required in builder stage
FROM ubi9/openjdk-21-runtime
# USER 185 before ENTRYPOINT
ENTRYPOINT ["java",
  "-XX:+UseContainerSupport",
  "-XX:MaxRAMPercentage=75.0",
  "-jar", "quarkus-run.jar"]</code></pre>
    </div>
  </div>

  <h2 style="color:var(--teal);margin:1.5rem 0 .75rem;">Sections</h2>
  <div class="grid grid-2" style="margin-bottom:1.5rem;">

    <a href="{{ site.repo }}/blob/main/java-optimization-demos/QUARKUS-README.md#container-images"
       target="_blank" class="tag tag-teal" style="display:block;padding:.55rem .85rem;font-size:.82rem;text-align:center;">
      Container Images
    </a>
    <a href="{{ site.repo }}/blob/main/java-optimization-demos/QUARKUS-README.md#jvm-heap-sizing"
       target="_blank" class="tag tag-teal" style="display:block;padding:.55rem .85rem;font-size:.82rem;text-align:center;">
      JVM Heap Sizing
    </a>
    <a href="{{ site.repo }}/blob/main/java-optimization-demos/QUARKUS-README.md#garbage-collector-selection"
       target="_blank" class="tag tag-teal" style="display:block;padding:.55rem .85rem;font-size:.82rem;text-align:center;">
      Garbage Collector Selection
    </a>
    <a href="{{ site.repo }}/blob/main/java-optimization-demos/QUARKUS-README.md#startup-optimization"
       target="_blank" class="tag tag-teal" style="display:block;padding:.55rem .85rem;font-size:.82rem;text-align:center;">
      Startup Optimization
    </a>
    <a href="{{ site.repo }}/blob/main/java-optimization-demos/QUARKUS-README.md#project-leyden-aot-cache"
       target="_blank" class="tag tag-teal" style="display:block;padding:.55rem .85rem;font-size:.82rem;text-align:center;">
      Project Leyden AOT Cache
    </a>
    <a href="{{ site.repo }}/blob/main/java-optimization-demos/QUARKUS-README.md#observability--metrics"
       target="_blank" class="tag tag-teal" style="display:block;padding:.55rem .85rem;font-size:.82rem;text-align:center;">
      Observability — Metrics
    </a>
    <a href="{{ site.repo }}/blob/main/java-optimization-demos/QUARKUS-README.md#observability--tracing"
       target="_blank" class="tag tag-teal" style="display:block;padding:.55rem .85rem;font-size:.82rem;text-align:center;">
      Observability — Tracing
    </a>
    <a href="{{ site.repo }}/blob/main/java-optimization-demos/QUARKUS-README.md#grpc-configuration"
       target="_blank" class="tag tag-teal" style="display:block;padding:.55rem .85rem;font-size:.82rem;text-align:center;">
      gRPC Configuration
    </a>
    <a href="{{ site.repo }}/blob/main/java-optimization-demos/QUARKUS-README.md#kubernetes-resource-configuration"
       target="_blank" class="tag tag-teal" style="display:block;padding:.55rem .85rem;font-size:.82rem;text-align:center;">
      Kubernetes Resource Configuration
    </a>
    <a href="{{ site.repo }}/blob/main/java-optimization-demos/QUARKUS-README.md#hpa-configuration-for-jvm-workloads"
       target="_blank" class="tag tag-teal" style="display:block;padding:.55rem .85rem;font-size:.82rem;text-align:center;">
      HPA Configuration
    </a>
    <a href="{{ site.repo }}/blob/main/java-optimization-demos/QUARKUS-README.md#panama-ffm-jdk-22"
       target="_blank" class="tag tag-teal" style="display:block;padding:.55rem .85rem;font-size:.82rem;text-align:center;">
      Panama FFM (JDK 22+)
    </a>
    <a href="{{ site.repo }}/blob/main/java-optimization-demos/QUARKUS-README.md#langchain4j-onnx-embeddings"
       target="_blank" class="tag tag-teal" style="display:block;padding:.55rem .85rem;font-size:.82rem;text-align:center;">
      LangChain4j ONNX Embeddings
    </a>
    <a href="{{ site.repo }}/blob/main/java-optimization-demos/QUARKUS-README.md#native-image"
       target="_blank" class="tag tag-teal" style="display:block;padding:.55rem .85rem;font-size:.82rem;text-align:center;">
      Native Image
    </a>
    <a href="{{ site.repo }}/blob/main/java-optimization-demos/QUARKUS-README.md#development-mode"
       target="_blank" class="tag tag-teal" style="display:block;padding:.55rem .85rem;font-size:.82rem;text-align:center;">
      Development Mode
    </a>
    <a href="{{ site.repo }}/blob/main/java-optimization-demos/QUARKUS-README.md#common-pitfalls"
       target="_blank" class="tag tag-teal" style="display:block;padding:.55rem .85rem;font-size:.82rem;text-align:center;">
      Common Pitfalls
    </a>

  </div>

  <div class="callout">
    <strong>Common pitfalls covered:</strong> Unqualified image names in Podman, SELinux bind mounts
    (<code>:Z</code>), named volume permissions, <code>dependency:go-offline</code> hangs in UBI,
    mounting config into otel-lgtm, AppCDS JVM fingerprint mismatch, <code>allocateFrom()</code>
    vs <code>allocateArray()</code>, JAX-RS annotations on record declarations.
  </div>

  <div class="run-box" style="margin-top:1.5rem;">
    <div class="run-box-header">File location in repo</div>
    <pre><code>java-optimization-demos/QUARKUS-README.md</code></pre>
  </div>
</div>
