---
layout: default
title: Diagrams
---
<div class="container">
  <div style="margin-top:2rem">
    <h1>Architecture Diagrams</h1>
    <p class="sub">All diagrams are in <a href="https://excalidraw.com" target="_blank">Excalidraw</a> format. Click any diagram to open the interactive viewer — view in-browser, download the <code>.excalidraw</code> file, or open directly in excalidraw.com to edit.</p>
  </div>

  <div class="callout">
    <strong>Presenting live?</strong> Keep <a href="https://excalidraw.com" target="_blank">excalidraw.com</a> open in a browser tab. Click "Open in Excalidraw" on any diagram page to load it with one click. Use these as whiteboard moments to break up slide-deck monotony.
  </div>

  <div class="grid grid-2" style="margin-top:1.5rem">
    {% assign diagrams = site.diagrams | sort: "order" %}
    {% for d in diagrams %}
    <a href="{{ d.url | relative_url }}" class="card">
      <div class="card-num">{{ d.order | prepend: '00' | slice: -2, 2 }}</div>
      <h3>{{ d.title }}</h3>
      <p>{{ d.description }}</p>
      <div class="card-foot">
        <span class="tag" style="font-family:monospace;font-size:.7rem">{{ d.excalidraw_file }}</span>
        {% if d.slide_ref %}<span class="tag tag-teal">Slide {{ d.slide_ref }}</span>{% endif %}
      </div>
    </a>
    {% endfor %}
  </div>
</div>
