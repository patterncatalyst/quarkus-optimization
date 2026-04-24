---
layout: default
title: Presenter Guide
description: Slide-by-slide speaker notes, demo timing, troubleshooting, and day-before checklist for all 54 slides.
permalink: /presentation/PRESENTER-GUIDE/
---

<div class="container">
  <nav class="breadcrumb">
    <a href="{{ '/' | relative_url }}">Home</a> /
    <a href="{{ '/docs/' | relative_url }}">Docs</a> /
    <span>Presenter Guide</span>
  </nav>

  <div style="display:flex;justify-content:space-between;align-items:flex-start;margin:1.5rem 0;flex-wrap:wrap;gap:1rem;">
    <div>
      <h1>Presenter Guide</h1>
      <p style="color:var(--muted);margin-top:.4rem;">
        Slide-by-slide speaker notes for all 54 slides, demo timing reference,
        day-before checklist, and troubleshooting for every known failure mode.
      </p>
    </div>
    <div style="display:flex;gap:.5rem;flex-wrap:wrap;">
      <a href="{{ '/presentation/' | relative_url }}" class="btn btn-primary btn-sm">Open Slides →</a>
      <a href="{{ site.repo }}/blob/main/presentation/PRESENTER-GUIDE.md"
         target="_blank" class="btn btn-outline btn-sm">View on GitHub ↗</a>
    </div>
  </div>

  <div class="callout">
    <strong>Talk structure:</strong>
    30 core slides for a 60-minute session · 24 bonus slides for a 90-minute extended session ·
    3 live demos in the core · 6 additional demos in the bonus content.
  </div>

  <div class="grid grid-2" style="margin:1.5rem 0;">
    <div class="card" style="pointer-events:none;">
      <h3 style="color:var(--teal);">Before You Present</h3>
      <ul style="color:var(--muted);font-size:.875rem;line-height:1.8;margin-left:1.2rem;">
        <li>Pull latest demo images (Grafana LGTM, Prometheus)</li>
        <li>Run Demo 01, 02, 03 end-to-end</li>
        <li>Verify Grafana loads at localhost:3000</li>
        <li>Confirm histogram config in Demo 02</li>
        <li>Set terminal font to 18pt minimum</li>
        <li>Disable notifications, close non-essential apps</li>
      </ul>
    </div>
    <div class="card" style="pointer-events:none;">
      <h3 style="color:var(--teal);">60-Minute Core Timing</h3>
      <table style="font-size:.8rem;width:100%;margin-top:.5rem;">
        <tr><td style="color:var(--muted);">Opening + Agenda</td><td style="color:var(--teal);text-align:right;">3 min</td></tr>
        <tr><td style="color:var(--muted);">§01 Heap (+ Demo 01)</td><td style="color:var(--teal);text-align:right;">8 min</td></tr>
        <tr><td style="color:var(--muted);">§02 Right-Sizing</td><td style="color:var(--teal);text-align:right;">5 min</td></tr>
        <tr><td style="color:var(--muted);">§03 GC (+ Demo 02)</td><td style="color:var(--teal);text-align:right;">8 min</td></tr>
        <tr><td style="color:var(--muted);">§04 Startup (+ Demo 03)</td><td style="color:var(--teal);text-align:right;">7 min</td></tr>
        <tr><td style="color:var(--muted);">§05–07 + Takeaways + Q&amp;A</td><td style="color:var(--teal);text-align:right;">22 min</td></tr>
      </table>
    </div>
  </div>

  <h2 style="color:var(--teal);margin:1.5rem 0 .75rem;">Section Navigation</h2>
  <div class="grid grid-2" style="margin-bottom:1.5rem;">

    <a href="{{ site.repo }}/blob/main/presentation/PRESENTER-GUIDE.md#before-you-present"
       target="_blank" class="tag tag-teal" style="display:block;padding:.55rem .85rem;font-size:.82rem;text-align:center;">
      Before You Present
    </a>
    <a href="{{ site.repo }}/blob/main/presentation/PRESENTER-GUIDE.md#talk-structure-60-minute-core"
       target="_blank" class="tag tag-teal" style="display:block;padding:.55rem .85rem;font-size:.82rem;text-align:center;">
      Talk Structure — 60-Minute Core
    </a>
    <a href="{{ site.repo }}/blob/main/presentation/PRESENTER-GUIDE.md#slide-by-slide-presenter-notes"
       target="_blank" class="tag tag-teal" style="display:block;padding:.55rem .85rem;font-size:.82rem;text-align:center;">
      Slide-by-Slide Notes
    </a>
    <a href="{{ site.repo }}/blob/main/presentation/PRESENTER-GUIDE.md#demo-01-container-aware-heap-sizing-slide-26"
       target="_blank" class="tag tag-teal" style="display:block;padding:.55rem .85rem;font-size:.82rem;text-align:center;">
      Demo 01 — Heap Sizing
    </a>
    <a href="{{ site.repo }}/blob/main/presentation/PRESENTER-GUIDE.md#demo-02-gc-monitoring-with-prometheus-slide-27"
       target="_blank" class="tag tag-teal" style="display:block;padding:.55rem .85rem;font-size:.82rem;text-align:center;">
      Demo 02 — GC Monitoring
    </a>
    <a href="{{ site.repo }}/blob/main/presentation/PRESENTER-GUIDE.md#demo-03-appcds-startup-acceleration-slide-28"
       target="_blank" class="tag tag-teal" style="display:block;padding:.55rem .85rem;font-size:.82rem;text-align:center;">
      Demo 03 — AppCDS
    </a>
    <a href="{{ site.repo }}/blob/main/presentation/PRESENTER-GUIDE.md#bonus-slides-extended-session-90-minutes"
       target="_blank" class="tag tag-teal" style="display:block;padding:.55rem .85rem;font-size:.82rem;text-align:center;">
      Bonus Slides (90 min)
    </a>
    <a href="{{ site.repo }}/blob/main/presentation/PRESENTER-GUIDE.md#slides-31-33-project-leyden-demo-04"
       target="_blank" class="tag tag-teal" style="display:block;padding:.55rem .85rem;font-size:.82rem;text-align:center;">
      Demo 04 — Project Leyden
    </a>
    <a href="{{ site.repo }}/blob/main/presentation/PRESENTER-GUIDE.md#slides-34-37-rest-vs-grpc-demo-05"
       target="_blank" class="tag tag-teal" style="display:block;padding:.55rem .85rem;font-size:.82rem;text-align:center;">
      Demo 05 — gRPC
    </a>
    <a href="{{ site.repo }}/blob/main/presentation/PRESENTER-GUIDE.md#slides-38-42-low-latency-jvm-demo-06"
       target="_blank" class="tag tag-teal" style="display:block;padding:.55rem .85rem;font-size:.82rem;text-align:center;">
      Demo 06 — Low Latency
    </a>
    <a href="{{ site.repo }}/blob/main/presentation/PRESENTER-GUIDE.md#slides-43-47-right-sizing-demo-07"
       target="_blank" class="tag tag-teal" style="display:block;padding:.55rem .85rem;font-size:.82rem;text-align:center;">
      Demo 07 — Right-Sizing
    </a>
    <a href="{{ site.repo }}/blob/main/presentation/PRESENTER-GUIDE.md#slides-48-50-panama-demo-0809"
       target="_blank" class="tag tag-teal" style="display:block;padding:.55rem .85rem;font-size:.82rem;text-align:center;">
      Demo 08/09 — Panama &amp; ONNX
    </a>
    <a href="{{ site.repo }}/blob/main/presentation/PRESENTER-GUIDE.md#slides-51-52-project-valhalla"
       target="_blank" class="tag tag-teal" style="display:block;padding:.55rem .85rem;font-size:.82rem;text-align:center;">
      Project Valhalla
    </a>
    <a href="{{ site.repo }}/blob/main/presentation/PRESENTER-GUIDE.md#slides-53-54-jvm-anti-patterns-remediation"
       target="_blank" class="tag tag-teal" style="display:block;padding:.55rem .85rem;font-size:.82rem;text-align:center;">
      Anti-Patterns
    </a>
    <a href="{{ site.repo }}/blob/main/presentation/PRESENTER-GUIDE.md#timing-reference-card"
       target="_blank" class="tag tag-teal" style="display:block;padding:.55rem .85rem;font-size:.82rem;text-align:center;">
      Timing Reference Card
    </a>
    <a href="{{ site.repo }}/blob/main/presentation/PRESENTER-GUIDE.md#demo-troubleshooting"
       target="_blank" class="tag tag-teal" style="display:block;padding:.55rem .85rem;font-size:.82rem;text-align:center;">
      Demo Troubleshooting
    </a>

  </div>

  <div class="run-box">
    <div class="run-box-header">File location in repo</div>
    <pre><code>presentation/PRESENTER-GUIDE.md</code></pre>
  </div>
</div>
