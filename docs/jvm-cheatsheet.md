---
layout: default
permalink: /docs/jvm-cheatsheet/
title: JVM Optimization Cheat Sheet
description: Quick-reference card for JVM tuning on container platforms.
---

<div class="container">
  <nav class="breadcrumb">
    <a href="{{ '/' | relative_url }}">Home</a> /
    <a href="{{ '/docs/' | relative_url }}">Docs</a> /
    <span>JVM Optimization Cheat Sheet</span>
  </nav>

  <div style="display:flex;justify-content:space-between;align-items:flex-start;margin:1.5rem 0;flex-wrap:wrap;gap:1rem;">
    <div>
      <h1>JVM Optimization Cheat Sheet</h1>
      <p style="color:var(--muted);margin-top:.4rem;">Quick-reference card for JVM tuning on OpenShift &amp; Kubernetes. All flags verified on Red Hat UBI9 with Podman.</p>
    </div>
    <a href="{{ site.repo }}/blob/main/java-optimization-demos/JVM-OPTIMIZATION-CHEATSHEET.md"
       target="_blank" class="btn btn-outline btn-sm">View on GitHub ↗</a>
  </div>

  <div class="grid grid-2" style="margin-bottom:2rem;">
    {% assign sections = "Container Heap Sizing,GC Quick-Select,GC Defaults by Image,Thread Count Tuning,Startup Optimization,Right-Sizing Quick Reference,HPA Configuration,Prometheus Metrics,Low-Latency Ladder,Panama FFM,gRPC vs REST,Podman Gotchas,JVM Flags Cookbook,Key Flags Reference,AppCDS vs Leyden vs Native,Health Check Endpoints" | split: "," %}
    {% for section in sections %}
    <a href="{{ site.repo }}/blob/main/java-optimization-demos/JVM-OPTIMIZATION-CHEATSHEET.md#{{ section | downcase | replace: ' ', '-' | replace: '/', '' | replace: '&', '' | replace: '(', '' | replace: ')', '' | replace: ',', '' }}"
       target="_blank" class="tag tag-teal"
       style="display:block;padding:.55rem .85rem;font-size:.82rem;text-align:center;">
      {{ section }}
    </a>
    {% endfor %}
  </div>

  <div class="run-box">
    <div class="run-box-header">File location in repo</div>
    <pre><code>java-optimization-demos/JVM-OPTIMIZATION-CHEATSHEET.md</code></pre>
  </div>

  <div class="callout" style="margin-top:1.5rem;">
    <strong>Quick start:</strong> The most impactful flags for any container deployment —
    <code>-XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0 -XX:ParallelGCThreads=N</code>
    where N equals your CPU request. That's 80% of the value in three flags.
  </div>
</div>
