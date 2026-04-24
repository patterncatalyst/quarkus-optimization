---
layout: default
title: Home
---

<div class="hero">
  <div class="container">
    <h1>Taming the <span>JVM</span></h1>
    <p class="subtitle">Optimizing Java Workloads on OpenShift &amp; Kubernetes — 9 live demos, 54 slides, real metrics and honest benchmark results.</p>
    <div class="tech-stack">
      <span class="pill">Quarkus 3.33.1 LTS</span>
      <span class="pill">Java 21 &amp; 25</span>
      <span class="pill">G1GC / ZGC / Shenandoah</span>
      <span class="pill">Project Leyden</span>
      <span class="pill">Panama FFM</span>
      <span class="pill">ONNX Runtime</span>
      <span class="pill">OpenShift</span>
      <span class="pill">Podman</span>
    </div>
    <div class="hero-actions">
      <a href="{{ '/demos/' | relative_url }}" class="btn btn-primary">Explore Demos →</a>
      <a href="{{ '/presentation/' | relative_url }}" class="btn btn-secondary">View Slides</a>
      <a href="{{ site.repo }}" class="btn btn-outline" target="_blank">GitHub ↗</a>
    </div>
  </div>
</div>

<div class="container">

  <div class="stats">
    <div class="stat"><div class="stat-val">9</div><div class="stat-lbl">Live Demos</div></div>
    <div class="stat"><div class="stat-val">54</div><div class="stat-lbl">Slides</div></div>
    <div class="stat"><div class="stat-val">−75%</div><div class="stat-lbl">Startup (Leyden)</div></div>
    <div class="stat"><div class="stat-val">$80k+</div><div class="stat-lbl">Annual Savings Shown</div></div>
    <div class="stat"><div class="stat-val">&lt;1ms</div><div class="stat-lbl">ZGC Pause Target</div></div>
  </div>

  <div class="section">
    <h2>Demos</h2>
    <p class="sub">All demos run with <code>./demo.sh</code> using Podman and Red Hat UBI images.</p>
    <div class="grid grid-2">
      <a href="{{ '/demos/demo-01-heap-sizing/' | relative_url }}" class="card">
        <div class="card-num">Demo 01 · Core</div>
        <h3>Container-Aware Heap Sizing</h3>
        <p>UseContainerSupport + MaxRAMPercentage vs hardcoded -Xmx. Live jcmd output and OOMKill simulation.</p>
        <div class="card-foot"><span class="tag">Java 21</span><span class="tag tag-muted">⏱ ~5 min</span></div>
      </a>
      <a href="{{ '/demos/demo-02-gc-monitoring/' | relative_url }}" class="card">
        <div class="card-num">Demo 02 · Core</div>
        <h3>GC Monitoring with Prometheus</h3>
        <p>Quarkus + Micrometer + Grafana LGTM. Live GC pause histograms. G1GC vs ZGC side-by-side.</p>
        <div class="card-foot"><span class="tag">Quarkus 3.33.1</span><span class="tag tag-muted">⏱ ~10 min</span></div>
      </a>
      <a href="{{ '/demos/demo-03-appcds/' | relative_url }}" class="card">
        <div class="card-num">Demo 03 · Core</div>
        <h3>AppCDS Startup Acceleration</h3>
        <p>Quarkus ~5% vs Spring Boot ~40% improvement. One property. The honest comparison.</p>
        <div class="card-foot"><span class="tag">Quarkus + Spring Boot</span><span class="tag tag-muted">⏱ ~8 min</span></div>
      </a>
      <a href="{{ '/demos/demo-04-leyden/' | relative_url }}" class="card">
        <div class="card-num">Demo 04 · Bonus</div>
        <h3>Project Leyden AOT Cache</h3>
        <p>609ms → 148ms (−75%) startup on JDK 25 LTS. One property, one Maven command.</p>
        <div class="card-foot"><span class="tag tag-purple">JDK 25</span><span class="tag tag-muted">⏱ ~12 min</span></div>
      </a>
      <a href="{{ '/demos/demo-05-grpc/' | relative_url }}" class="card">
        <div class="card-num">Demo 05 · Bonus</div>
        <h3>REST vs gRPC — Two Protocols</h3>
        <p>One Quarkus app, REST on :8080 and gRPC on :9000. Streaming benchmark + honest localhost caveat.</p>
        <div class="card-foot"><span class="tag">Quarkus 3.33.1</span><span class="tag tag-muted">⏱ ~10 min</span></div>
      </a>
      <a href="{{ '/demos/demo-06-latency/' | relative_url }}" class="card">
        <div class="card-num">Demo 06 · Bonus</div>
        <h3>Low-Latency JVM: G1GC vs ZGC</h3>
        <p>Same code, same heap. GC pause delta measured live under load. ZGC throughput caveat explained.</p>
        <div class="card-foot"><span class="tag">Quarkus 3.33.1</span><span class="tag tag-muted">⏱ ~10 min</span></div>
      </a>
      <a href="{{ '/demos/demo-07-rightsizing/' | relative_url }}" class="card">
        <div class="card-num">Demo 07 · Bonus</div>
        <h3>Right-Sizing &amp; Cost Analysis</h3>
        <p>Pure Python. 4 nodes → 2 nodes, $6,720/month saving, 17× ROI. No cluster needed.</p>
        <div class="card-foot"><span class="tag tag-green">No cluster needed</span><span class="tag tag-muted">⏱ ~3 min</span></div>
      </a>
      <a href="{{ '/demos/demo-08-panama/' | relative_url }}" class="card">
        <div class="card-num">Demo 08 · Bonus</div>
        <h3>Project Panama: C++20 via FFM</h3>
        <p>Foreign Function &amp; Memory API calling native C++20 library. No JNI, no wrappers, Arena safety.</p>
        <div class="card-foot"><span class="tag tag-purple">JDK 25</span><span class="tag tag-muted">⏱ ~8 min</span></div>
      </a>
      <a href="{{ '/demos/demo-09-onnx/' | relative_url }}" class="card">
        <div class="card-num">Demo 09 · Bonus</div>
        <h3>AI Inference: LangChain4j + ONNX</h3>
        <p>MiniLM-L6-v2 in-process via Panama. Semantic search + incident classification. No Python sidecar.</p>
        <div class="card-foot"><span class="tag tag-purple">JDK 25</span><span class="tag tag-muted">⏱ ~10 min</span></div>
      </a>
    </div>
  </div>

  <div class="section">
    <h2>Reference Docs</h2>
    <p class="sub">Cheat sheets, configuration references, and presenter guides.</p>
    <div class="grid grid-3">
      <a href="{{ '/docs/quarkus-reference/' | relative_url }}" class="doc-card">
        <div class="doc-card-icon">📋</div>
        <h3>Quarkus Configuration Reference</h3>
        <p>Container images, GC flags, AppCDS, Leyden, Micrometer, gRPC, Panama FFM — full config reference.</p>
      </a>
      <a href="{{ site.repo }}/blob/main/java-optimization-demos/JVM-OPTIMIZATION-CHEATSHEET.md"
         target="_blank" class="doc-card">
        <div class="doc-card-icon">⚡</div>
        <h3>JVM Optimization Cheat Sheet</h3>
        <p>Heap flags, GC decision tree, thread counts, right-sizing formula, startup ladder, Podman gotchas — quick reference.</p>
      </a>
      <a href="{{ '/docs/shenandoah-guide/' | relative_url }}" class="doc-card">
        <div class="doc-card-icon">♻️</div>
        <h3>Shenandoah GC Guide</h3>
        <p>Why UBI9 defaults to Shenandoah, how Brooks pointers work, three-way comparison with G1GC and ZGC.</p>
      </a>
      <a href="{{ '/docs/presenter-guide/' | relative_url }}" class="doc-card">
        <div class="doc-card-icon">🎤</div>
        <h3>Presenter Guide</h3>
        <p>Slide-by-slide notes for all 54 slides, timing reference, demo troubleshooting, prep checklist.</p>
      </a>
      <a href="{{ '/docs/prerequisites/' | relative_url }}" class="doc-card">
        <div class="doc-card-icon">🔧</div>
        <h3>Prerequisites — Fedora &amp; macOS</h3>
        <p>Podman, SDKMAN, JDK 21 &amp; 25, hey, grpcurl, ghz — complete install guide for both platforms.</p>
      </a>
      <a href="{{ '/diagrams/' | relative_url }}" class="doc-card">
        <div class="doc-card-icon">📐</div>
        <h3>Excalidraw Diagrams</h3>
        <p>10 architecture and flow diagrams — interactive viewer, speaker notes, and download links.</p>
      </a>
    </div>
  </div>

</div>
