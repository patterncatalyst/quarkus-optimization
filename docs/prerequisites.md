---
layout: default
permalink: /docs/prerequisites/
title: "Prerequisites - Fedora and macOS"
description: Complete install guide for all tools required to run the demos.
---

<div class="container">
  <nav class="breadcrumb">
    <a href="{{ '/' | relative_url }}">Home</a> /
    <a href="{{ '/docs/' | relative_url }}">Docs</a> /
    <span>Prerequisites</span>
  </nav>

  <div style="display:flex;justify-content:space-between;align-items:flex-start;margin:1.5rem 0;flex-wrap:wrap;gap:1rem;">
    <div>
      <h1>Prerequisites — Fedora &amp; macOS</h1>
      <p style="color:var(--muted);margin-top:.4rem;">
        Complete install guide for all tools required to run the nine demos,
        with instructions for both Fedora Linux and macOS.
      </p>
    </div>
    <a href="{{ site.repo }}/blob/main/java-optimization-demos/DEMO-PREREQUISITES.md"
       target="_blank" class="btn btn-outline btn-sm">View on GitHub ↗</a>
  </div>

  <div class="grid grid-2" style="margin-bottom:1.5rem;">
    <div class="card" style="pointer-events:none;">
      <h3 style="color:var(--teal);">Fedora — Quick Install</h3>
      <pre style="font-size:.78rem;margin-top:.75rem;"><code>sudo dnf install -y podman git python3
pip install podman-compose --user
curl -s "https://get.sdkman.io" | bash
sdk install java 21.0.10-tem
sdk install java 25.0.1-tem
# hey, grpcurl, ghz — see full guide</code></pre>
    </div>
    <div class="card" style="pointer-events:none;">
      <h3 style="color:var(--teal);">macOS — Quick Install</h3>
      <pre style="font-size:.78rem;margin-top:.75rem;"><code>brew install podman git python3 hey grpcurl ghz
podman machine init --memory 8192 --cpus 4
podman machine start
pip3 install podman-compose
sdk install java 21.0.10-tem
sdk install java 25.0.1-tem</code></pre>
    </div>
  </div>

  <div class="grid grid-2" style="margin-bottom:1.5rem;">
    {% assign tools = "git,podman,podman-compose,SDKMAN + JDK 21,SDKMAN + JDK 25,Python 3,hey (HTTP load tester),grpcurl (gRPC CLI),ghz (gRPC load tester),Podman Image Pre-Pull,Verify Your Setup,Fedora SELinux Notes,macOS Podman Machine,Minimum vs Full Install" | split: "," %}
    {% for tool in tools %}
    <a href="{{ site.repo }}/blob/main/java-optimization-demos/DEMO-PREREQUISITES.md#{{ tool | downcase | replace: ' ', '-' | replace: '(', '' | replace: ')', '' | replace: '+', '' | replace: '/', '' | replace: '.', '' | replace: '&', '' | strip | replace: '  ', '-' }}"
       target="_blank" class="tag tag-teal"
       style="display:block;padding:.55rem .85rem;font-size:.82rem;text-align:center;">
      {{ tool }}
    </a>
    {% endfor %}
  </div>

  <div class="callout">
    <strong>Tools by demo:</strong> Most demos only need <code>podman</code>.
    <code>podman-compose</code> is needed for Demo 02 and 06.
    <code>hey</code>, <code>grpcurl</code>, and <code>ghz</code> are only needed for Demo 05.
    Demo 07 needs only <code>python3</code> — no containers at all.
  </div>

  <div class="run-box" style="margin-top:1.5rem;">
    <div class="run-box-header">File location in repo</div>
    <pre><code>java-optimization-demos/DEMO-PREREQUISITES.md</code></pre>
  </div>
</div>
