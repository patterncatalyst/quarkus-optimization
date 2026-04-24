---
layout: default
title: Quarkus Configuration Reference
description: Full configuration reference for Quarkus 3.33.1 LTS on OpenShift and Kubernetes.
---

<div class="container">
  <nav class="breadcrumb">
    <a href="{{ '/' | relative_url }}">Home</a><span>/</span>
    <a href="{{ '/docs/' | relative_url }}">Docs</a><span>/</span>
    <span>Quarkus Reference</span>
  </nav>

  <div style="display:flex;justify-content:space-between;align-items:center;margin:1.5rem 0;">
    <h1>Quarkus Configuration Reference</h1>
    <a href="{{ site.repo }}/blob/main/java-optimization-demos/QUARKUS-README.md"
       target="_blank" class="btn btn--outline btn--sm">View on GitHub ↗</a>
  </div>

  <p style="color:#90A4AE;margin-bottom:2rem;">
    Comprehensive configuration reference for Quarkus 3.33.1 LTS workloads running on OpenShift and Kubernetes.
    Covers container images, GC selection, AppCDS, Leyden, Micrometer, gRPC, HPA, Panama FFM, and LangChain4j ONNX.
  </p>

  <!-- The actual content is maintained in QUARKUS-README.md in the repo. -->
  <!-- This page links to it and can be extended with rendered content. -->

  <div class="section-links" style="display:grid;grid-template-columns:repeat(auto-fit,minmax(200px,1fr));gap:0.75rem;margin-bottom:2rem;">
    {% assign sections = "Container Images,JVM Heap Sizing,GC Selection,AppCDS,Project Leyden,Observability,gRPC,HPA,Panama FFM,LangChain4j ONNX,Common Pitfalls" | split: "," %}
    {% for section in sections %}
    <a href="{{ site.repo }}/blob/main/java-optimization-demos/QUARKUS-README.md#{{ section | downcase | replace: ' ', '-' | replace: '/', '' }}"
       target="_blank" class="tag tag--teal" style="display:block;text-align:center;padding:0.5rem;">
      {{ section }}
    </a>
    {% endfor %}
  </div>

  <div class="run-box" style="margin-bottom:2rem;">
    <div class="run-box__header">View full document</div>
    <div class="run-box__body">
      <pre><code># In the repo:
java-optimization-demos/QUARKUS-README.md

# Online:
{{ site.repo }}/blob/main/java-optimization-demos/QUARKUS-README.md</code></pre>
    </div>
  </div>

</div>
