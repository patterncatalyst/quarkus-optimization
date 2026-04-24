---
layout: default
title: Demos
---
<div class="container">
  <div style="margin-top:2rem">
    <h1>Demos</h1>
    <p class="sub">All demos run with <code>chmod +x demo.sh && ./demo.sh</code> using Podman and Red Hat UBI images.</p>
  </div>

  <div class="callout">
    <strong>Note on GC defaults:</strong> <code>ubi9/openjdk-21-runtime</code> ships <strong>Shenandoah</strong> as the default GC — Red Hat's concurrent collector giving 1–20ms pauses. Demos that compare GC algorithms explicitly override it with <code>-XX:+UseG1GC</code> or <code>-XX:+UseZGC</code>.
  </div>

  <h2 style="color:var(--teal);margin:2rem 0 1rem">Core Session — 60 min</h2>
  <div class="grid grid-2">
    {% assign core_demos = site.demos | where: "session","core" | sort: "demo_number" %}
    {% for d in core_demos %}
    <a href="{{ d.url | relative_url }}" class="card">
      <div class="card-num">Demo {{ d.demo_number }}</div>
      <h3>{{ d.title | remove: "Demo 0" | remove: "Demo " | split: "—" | last | strip }}</h3>
      <p>{{ d.content | strip_html | truncate: 120 }}</p>
      <div class="card-foot">
        <span class="tag">{{ d.runtime }}</span>
        <span class="tag tag-muted">⏱ {{ d.time }}</span>
      </div>
    </a>
    {% endfor %}
  </div>

  <h2 style="color:var(--teal);margin:2.5rem 0 1rem">Extended / Bonus — 90 min</h2>
  <div class="grid grid-2">
    {% assign bonus_demos = site.demos | where: "session","bonus" | sort: "demo_number" %}
    {% for d in bonus_demos %}
    <a href="{{ d.url | relative_url }}" class="card">
      <div class="card-num">Demo {{ d.demo_number }} · Bonus</div>
      <h3>{{ d.title | split: "—" | last | strip }}</h3>
      <p>{{ d.content | strip_html | truncate: 120 }}</p>
      <div class="card-foot">
        {% if d.jdk25 %}<span class="tag tag-purple">JDK 25</span>{% endif %}
        {% if d.cluster_required == false %}<span class="tag tag-green">No cluster</span>{% endif %}
        {% unless d.jdk25 or d.cluster_required == false %}
          <span class="tag">{{ d.runtime }}</span>
        {% endunless %}
        <span class="tag tag-muted">⏱ {{ d.time }}</span>
      </div>
    </a>
    {% endfor %}
  </div>
</div>
