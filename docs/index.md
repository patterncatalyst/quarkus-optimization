---
layout: default
title: Documentation
---
<div class="container">
  <div style="margin-top:2rem">
    <h1>Documentation</h1>
    <p class="sub">Reference guides, cheat sheets, and presenter notes. All files are also in the <a href="{{ site.repo }}/tree/main/java-optimization-demos" target="_blank">GitHub repository</a>.</p>
  </div>

  <div class="grid grid-3">

    <a href="{{ '/docs/quarkus-reference/' | relative_url }}" class="doc-card">
      <div class="doc-card-icon">📋</div>
      <h3>Quarkus Configuration Reference</h3>
      <p>Container images, GC selection, AppCDS, Leyden, Micrometer, gRPC, Panama FFM, LangChain4j ONNX, common pitfalls.</p>
      <span class="tag tag-teal">QUARKUS-README.md</span>
    </a>

    <a href="{{ '/docs/jvm-cheatsheet/' | relative_url }}" class="doc-card">
      <div class="doc-card-icon">⚡</div>
      <h3>JVM Optimization Cheat Sheet</h3>
      <p>Heap flags, GC decision tree, thread counts, right-sizing formula, startup ladder, Podman gotchas, flag reference table.</p>
      <span class="tag tag-teal">JVM-OPTIMIZATION-CHEATSHEET.md</span>
    </a>

    <a href="{{ '/docs/shenandoah-guide/' | relative_url }}" class="doc-card">
      <div class="doc-card-icon">♻️</div>
      <h3>Shenandoah GC Guide</h3>
      <p>Why UBI9 defaults to Shenandoah, Brooks pointers, three-way comparison with G1GC and ZGC, DegeneratedGC explained.</p>
      <span class="tag tag-teal">SHENANDOAH-GC-GUIDE.md</span>
    </a>

    <a href="{{ '/docs/presenter-guide/' | relative_url }}" class="doc-card">
      <div class="doc-card-icon">🎤</div>
      <h3>Presenter Guide</h3>
      <p>Slide-by-slide speaker notes for all 54 slides, timing reference, day-before checklist, demo troubleshooting.</p>
      <span class="tag tag-teal">PRESENTER-GUIDE.md</span>
    </a>

    <a href="{{ '/docs/prerequisites/' | relative_url }}" class="doc-card">
      <div class="doc-card-icon">🔧</div>
      <h3>Prerequisites — Fedora &amp; macOS</h3>
      <p>Podman, SDKMAN, JDK 21 &amp; 25, hey, grpcurl, ghz — complete install guide with verify script.</p>
      <span class="tag tag-teal">DEMO-PREREQUISITES.md</span>
    </a>

    <a href="{{ site.repo }}/blob/main/diagrams/DIAGRAM-SPEAKER-NOTES.md"
       target="_blank" class="doc-card">
      <div class="doc-card-icon">📐</div>
      <h3>Diagram Speaker Notes</h3>
      <p>Speaker notes and slide placement for all 10 Excalidraw diagrams. Walk-through timing, whiteboard guidance.</p>
      <span class="tag tag-teal">DIAGRAM-SPEAKER-NOTES.md</span>
    </a>

    <a href="{{ site.repo }}/blob/main/diagrams/DIAGRAM-SPEAKER-NOTES-ANTI-PATTERNS.md"
       target="_blank" class="doc-card">
      <div class="doc-card-icon">🚫</div>
      <h3>Anti-Patterns Diagram Notes</h3>
      <p>Extended speaker notes for the 16-pattern anti-patterns diagram. Row-by-row walk-through with priority ordering.</p>
      <span class="tag tag-teal">DIAGRAM-SPEAKER-NOTES-ANTI-PATTERNS.md</span>
    </a>

    <a href="{{ '/diagrams/' | relative_url }}" class="doc-card">
      <div class="doc-card-icon">🖼</div>
      <h3>Interactive Diagram Viewer</h3>
      <p>Browse and view all 10 Excalidraw diagrams in-browser. Download files or open directly in excalidraw.com.</p>
      <span class="tag tag-green">Interactive →</span>
    </a>

    <a href="{{ '/presentation/' | relative_url }}" class="doc-card">
      <div class="doc-card-icon">📊</div>
      <h3>Reveal.js Slides</h3>
      <p>All 54 slides in browser-native Reveal.js. Press S for speaker notes, press O for overview mode.</p>
      <span class="tag tag-green">Interactive →</span>
    </a>

  </div>
</div>
