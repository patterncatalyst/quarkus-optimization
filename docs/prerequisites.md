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

  <div class="callout">
    <strong>Tools by demo:</strong> Most demos only need <code>podman</code>.
    <code>podman-compose</code> for Demos 02 &amp; 06.
    <code>hey</code>, <code>grpcurl</code>, <code>ghz</code> for Demo 05.
    Demo 07 needs only <code>python3</code> — no containers at all.
  </div>

  <h2 style="color:var(--teal);margin:1.5rem 0 .75rem;">Sections</h2>
  <div class="grid grid-2" style="margin-bottom:1.5rem;">

    <a href="{{ site.repo }}/blob/main/java-optimization-demos/DEMO-PREREQUISITES.md#quick-install-summary"
       target="_blank" class="tag tag-teal" style="display:block;padding:.55rem .85rem;font-size:.82rem;text-align:center;">Quick-Install Summary</a>
    <a href="{{ site.repo }}/blob/main/java-optimization-demos/DEMO-PREREQUISITES.md#tools-by-demo"
       target="_blank" class="tag tag-teal" style="display:block;padding:.55rem .85rem;font-size:.82rem;text-align:center;">Tools by Demo</a>
    <a href="{{ site.repo }}/blob/main/java-optimization-demos/DEMO-PREREQUISITES.md#git"
       target="_blank" class="tag tag-teal" style="display:block;padding:.55rem .85rem;font-size:.82rem;text-align:center;">git</a>
    <a href="{{ site.repo }}/blob/main/java-optimization-demos/DEMO-PREREQUISITES.md#podman"
       target="_blank" class="tag tag-teal" style="display:block;padding:.55rem .85rem;font-size:.82rem;text-align:center;">Podman</a>
    <a href="{{ site.repo }}/blob/main/java-optimization-demos/DEMO-PREREQUISITES.md#podman-compose"
       target="_blank" class="tag tag-teal" style="display:block;padding:.55rem .85rem;font-size:.82rem;text-align:center;">podman-compose</a>
    <a href="{{ site.repo }}/blob/main/java-optimization-demos/DEMO-PREREQUISITES.md#sdkman-jdk-version-manager"
       target="_blank" class="tag tag-teal" style="display:block;padding:.55rem .85rem;font-size:.82rem;text-align:center;">SDKMAN + JDK 21 &amp; 25</a>
    <a href="{{ site.repo }}/blob/main/java-optimization-demos/DEMO-PREREQUISITES.md#python-3"
       target="_blank" class="tag tag-teal" style="display:block;padding:.55rem .85rem;font-size:.82rem;text-align:center;">Python 3</a>
    <a href="{{ site.repo }}/blob/main/java-optimization-demos/DEMO-PREREQUISITES.md#hey--http-load-tester"
       target="_blank" class="tag tag-teal" style="display:block;padding:.55rem .85rem;font-size:.82rem;text-align:center;">hey — HTTP load tester</a>
    <a href="{{ site.repo }}/blob/main/java-optimization-demos/DEMO-PREREQUISITES.md#grpcurl--grpc-cli-client"
       target="_blank" class="tag tag-teal" style="display:block;padding:.55rem .85rem;font-size:.82rem;text-align:center;">grpcurl — gRPC CLI</a>
    <a href="{{ site.repo }}/blob/main/java-optimization-demos/DEMO-PREREQUISITES.md#ghz--grpc-load-tester"
       target="_blank" class="tag tag-teal" style="display:block;padding:.55rem .85rem;font-size:.82rem;text-align:center;">ghz — gRPC load tester</a>
    <a href="{{ site.repo }}/blob/main/java-optimization-demos/DEMO-PREREQUISITES.md#curl-and-python3-standard-cli-tools"
       target="_blank" class="tag tag-teal" style="display:block;padding:.55rem .85rem;font-size:.82rem;text-align:center;">curl and python3</a>
    <a href="{{ site.repo }}/blob/main/java-optimization-demos/DEMO-PREREQUISITES.md#podman-image-pre-pull-optional-but-recommended"
       target="_blank" class="tag tag-teal" style="display:block;padding:.55rem .85rem;font-size:.82rem;text-align:center;">Podman Image Pre-Pull</a>
    <a href="{{ site.repo }}/blob/main/java-optimization-demos/DEMO-PREREQUISITES.md#verify-your-setup"
       target="_blank" class="tag tag-teal" style="display:block;padding:.55rem .85rem;font-size:.82rem;text-align:center;">Verify Your Setup</a>
    <a href="{{ site.repo }}/blob/main/java-optimization-demos/DEMO-PREREQUISITES.md#fedora--selinux-and-podman-rootless"
       target="_blank" class="tag tag-teal" style="display:block;padding:.55rem .85rem;font-size:.82rem;text-align:center;">Fedora — SELinux Notes</a>
    <a href="{{ site.repo }}/blob/main/java-optimization-demos/DEMO-PREREQUISITES.md#macos--podman-machine"
       target="_blank" class="tag tag-teal" style="display:block;padding:.55rem .85rem;font-size:.82rem;text-align:center;">macOS — Podman Machine</a>
    <a href="{{ site.repo }}/blob/main/java-optimization-demos/DEMO-PREREQUISITES.md#uninstall--cleanup"
       target="_blank" class="tag tag-teal" style="display:block;padding:.55rem .85rem;font-size:.82rem;text-align:center;">Uninstall / Cleanup</a>
    <a href="{{ site.repo }}/blob/main/java-optimization-demos/DEMO-PREREQUISITES.md#minimum-vs-full-install"
       target="_blank" class="tag tag-teal" style="display:block;padding:.55rem .85rem;font-size:.82rem;text-align:center;">Minimum vs Full Install</a>
    <a href="{{ site.repo }}/blob/main/java-optimization-demos/DEMO-PREREQUISITES.md#ai-assisted-development-optional"
       target="_blank" class="tag tag-teal" style="display:block;padding:.55rem .85rem;font-size:.82rem;text-align:center;">AI-Assisted Dev (Optional)</a>
    <a href="{{ site.repo }}/blob/main/java-optimization-demos/DEMO-PREREQUISITES.md#reference-links"
       target="_blank" class="tag tag-teal" style="display:block;padding:.55rem .85rem;font-size:.82rem;text-align:center;">Reference Links</a>

  </div>

  <div class="run-box">
    <div class="run-box-header">File location in repo</div>
    <pre><code>java-optimization-demos/DEMO-PREREQUISITES.md</code></pre>
  </div>
</div>
