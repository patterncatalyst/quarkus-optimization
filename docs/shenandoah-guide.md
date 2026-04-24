---
layout: default
title: Shenandoah GC Guide
description: Red Hat's default GC for UBI9 OpenJDK images — comparison with G1GC and ZGC.
---

<div class="container">
  <nav class="breadcrumb">
    <a href="{{ '/' | relative_url }}">Home</a> /
    <a href="{{ '/docs/' | relative_url }}">Docs</a> /
    <span>Shenandoah GC Guide</span>
  </nav>

  <div style="display:flex;justify-content:space-between;align-items:flex-start;margin:1.5rem 0;flex-wrap:wrap;gap:1rem;">
    <div>
      <h1>Shenandoah GC Guide</h1>
      <p style="color:var(--muted);margin-top:.4rem;">
        Red Hat's concurrent low-latency GC — the default on every
        <code>ubi9/openjdk-21-runtime</code> and <code>ubi9/openjdk-25-runtime</code> image.
      </p>
    </div>
    <a href="{{ site.repo }}/blob/main/java-optimization-demos/SHENANDOAH-GC-GUIDE.md"
       target="_blank" class="btn btn-outline btn-sm">View on GitHub ↗</a>
  </div>

  <div class="callout">
    <strong>If you're on OpenShift using UBI9:</strong> you're already running Shenandoah (1–20ms
    pauses) without any configuration. Demos 02 and 06 explicitly override it with
    <code>-XX:+UseG1GC</code> and <code>-XX:+UseZGC</code> for a clean comparison.
  </div>

  <h2 style="color:var(--teal);margin:1.5rem 0 .75rem;">Sections</h2>
  <div class="grid grid-2" style="margin-bottom:1.5rem;">

    <a href="{{ site.repo }}/blob/main/java-optimization-demos/SHENANDOAH-GC-GUIDE.md#what-is-shenandoah"
       target="_blank" class="tag tag-teal" style="display:block;padding:.55rem .85rem;font-size:.82rem;text-align:center;">
      What Is Shenandoah?
    </a>
    <a href="{{ site.repo }}/blob/main/java-optimization-demos/SHENANDOAH-GC-GUIDE.md#gc-defaults-by-container-image"
       target="_blank" class="tag tag-teal" style="display:block;padding:.55rem .85rem;font-size:.82rem;text-align:center;">
      GC Defaults by Container Image
    </a>
    <a href="{{ site.repo }}/blob/main/java-optimization-demos/SHENANDOAH-GC-GUIDE.md#how-shenandoah-works"
       target="_blank" class="tag tag-teal" style="display:block;padding:.55rem .85rem;font-size:.82rem;text-align:center;">
      How Shenandoah Works
    </a>
    <a href="{{ site.repo }}/blob/main/java-optimization-demos/SHENANDOAH-GC-GUIDE.md#shenandoah-vs-g1gc-vs-zgc-full-comparison"
       target="_blank" class="tag tag-teal" style="display:block;padding:.55rem .85rem;font-size:.82rem;text-align:center;">
      Shenandoah vs G1GC vs ZGC
    </a>
    <a href="{{ site.repo }}/blob/main/java-optimization-demos/SHENANDOAH-GC-GUIDE.md#shenandoah-vs-g1gc-when-each-wins"
       target="_blank" class="tag tag-teal" style="display:block;padding:.55rem .85rem;font-size:.82rem;text-align:center;">
      When Each GC Wins
    </a>
    <a href="{{ site.repo }}/blob/main/java-optimization-demos/SHENANDOAH-GC-GUIDE.md#the-barrier-type-distinction-why-it-matters"
       target="_blank" class="tag tag-teal" style="display:block;padding:.55rem .85rem;font-size:.82rem;text-align:center;">
      The Barrier Type Distinction
    </a>
    <a href="{{ site.repo }}/blob/main/java-optimization-demos/SHENANDOAH-GC-GUIDE.md#configuration-reference"
       target="_blank" class="tag tag-teal" style="display:block;padding:.55rem .85rem;font-size:.82rem;text-align:center;">
      Configuration Reference
    </a>
    <a href="{{ site.repo }}/blob/main/java-optimization-demos/SHENANDOAH-GC-GUIDE.md#monitoring-shenandoah"
       target="_blank" class="tag tag-teal" style="display:block;padding:.55rem .85rem;font-size:.82rem;text-align:center;">
      Monitoring Shenandoah
    </a>
    <a href="{{ site.repo }}/blob/main/java-optimization-demos/SHENANDOAH-GC-GUIDE.md#degeneratedgc-what-it-means"
       target="_blank" class="tag tag-teal" style="display:block;padding:.55rem .85rem;font-size:.82rem;text-align:center;">
      DegeneratedGC — What It Means
    </a>
    <a href="{{ site.repo }}/blob/main/java-optimization-demos/SHENANDOAH-GC-GUIDE.md#the-on-stage-framing"
       target="_blank" class="tag tag-teal" style="display:block;padding:.55rem .85rem;font-size:.82rem;text-align:center;">
      The On-Stage Framing
    </a>

  </div>

  <div class="grid grid-2" style="margin-bottom:1.5rem;">
    <div class="card" style="pointer-events:none;">
      <h3 style="color:var(--teal);">Choose Shenandoah when…</h3>
      <ul style="color:var(--muted);font-size:.875rem;line-height:1.8;margin-left:1.2rem;">
        <li>Deploying on OpenShift / UBI9 — already your default</li>
        <li>p99 SLA between 20ms and 100ms</li>
        <li>Medium to large heaps (4GB–100GB)</li>
        <li>JDK 8+ support needed (Red Hat builds)</li>
      </ul>
    </div>
    <div class="card" style="pointer-events:none;">
      <h3 style="color:var(--teal);">Choose ZGC when…</h3>
      <ul style="color:var(--muted);font-size:.875rem;line-height:1.8;margin-left:1.2rem;">
        <li>p99 SLA tighter than 10ms</li>
        <li>Heap exceeds 32GB</li>
        <li>HPA stability is critical (flat CPU profile)</li>
        <li>JDK 21+ available</li>
      </ul>
    </div>
  </div>

  <div class="run-box">
    <div class="run-box-header">File location in repo</div>
    <pre><code>java-optimization-demos/SHENANDOAH-GC-GUIDE.md</code></pre>
  </div>
</div>
