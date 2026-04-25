# Jekyll Site — Local Development Guide

The `docs/` directory contains the source for the GitHub Pages site at
[patterncatalyst.github.io/quarkus-optimization](https://patterncatalyst.github.io/quarkus-optimization).

Built with [Jekyll](https://jekyllrb.com/) and deployed automatically via GitHub Actions on every push to `main`.

---

## Prerequisites

Jekyll is a Ruby application. You need Ruby, Bundler, and the project gems installed before you can build or serve the site locally.

---

## Fedora

### 1. Install Ruby and build dependencies

```bash
sudo dnf install -y ruby ruby-devel gcc make redhat-rpm-config libffi-devel zlib-devel
```

### 2. Install Bundler

```bash
gem install bundler
```

If the `bundle` executable is not found after installation, add the gem bin directory to your PATH:

```bash
echo 'export PATH="$HOME/.local/share/gem/ruby/$(ruby -e "puts RbConfig::CONFIG[\"ruby_version\"]")/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

### 3. Install project gems

From the repo root (where `Gemfile` lives):

```bash
bundle install
```

> **Ruby 3.4+ note:** If you see a `cannot load such file -- csv` error, the `Gemfile`
> already includes `gem "csv"` and `gem "base64"` to fix this. If you see other missing
> gem errors, add them the same way and re-run `bundle install`.

### 4. Serve the site locally

```bash
bundle exec jekyll serve
```

The site is available at **http://localhost:4000/quarkus-optimization/**

---

## macOS

### 1. Install Homebrew (if not already installed)

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### 2. Install rbenv and a modern Ruby

macOS ships with an old system Ruby that should not be used for Jekyll. Install a current version via `rbenv`:

```bash
brew install rbenv ruby-build

# Add rbenv to your shell
echo 'eval "$(rbenv init -)"' >> ~/.zshrc
source ~/.zshrc

# Install Ruby 3.2.x (matches GitHub Pages)
rbenv install 3.2.3
rbenv global 3.2.3

# Verify
ruby --version   # should show 3.2.3
```

### 3. Install Bundler

```bash
gem install bundler
```

### 4. Install project gems

From the repo root:

```bash
bundle install
```

### 5. Serve the site locally

```bash
bundle exec jekyll serve
```

The site is available at **http://localhost:4000/quarkus-optimization/**

---

## Common Commands

```bash
# Serve with live reload (rebuilds on file save)
bundle exec jekyll serve --livereload

# Build to _site/ without serving
bundle exec jekyll build

# Build for production (sets JEKYLL_ENV=production)
JEKYLL_ENV=production bundle exec jekyll build

# Serve with drafts visible
bundle exec jekyll serve --drafts

# Clear the build cache and rebuild
bundle exec jekyll clean && bundle exec jekyll serve

# Check for broken links (requires html-proofer)
bundle exec htmlproofer ./_site --disable-external
```

---

## Site Structure

```
quarkus-optimization/         ← repo root, also Jekyll root
│
├── _config.yml               ← site config: title, baseurl, collections, nav
├── Gemfile                   ← Ruby gem dependencies (github-pages, csv, base64)
│
├── index.md                  ← Home page
│
├── _layouts/                 ← Page templates
│   ├── default.html          ← Site shell: header, nav, footer
│   ├── demo.html             ← Demo pages with run-box and prev/next nav
│   ├── diagram.html          ← Excalidraw viewer + speaker notes
│   └── reveal.html           ← Reveal.js presentation shell
│
├── _demos/                   ← Jekyll collection — one .md per demo (Demos 01-09)
├── _diagrams/                ← Jekyll collection — one .md per diagram (01-10)
│
├── demos/
│   └── index.md              ← Demo catalog (core vs bonus)
│
├── diagrams/
│   └── index.md              ← Diagram gallery with Excalidraw viewer
│
├── docs/
│   ├── index.md              ← Documentation hub
│   ├── jvm-cheatsheet.md     ← JVM Optimization Cheat Sheet page
│   ├── shenandoah-guide.md   ← Shenandoah GC Guide page
│   ├── prerequisites.md      ← Fedora & macOS prerequisites page
│   └── README.md             ← This file
│
├── presentation/
│   ├── index.html            ← Reveal.js slides (all 54 slides)
│   └── PRESENTER-GUIDE.md    ← Presenter guide with section navigation
│
├── assets/
│   ├── css/main.css          ← Dark navy theme
│   ├── css/reveal-custom.css ← Reveal.js overrides
│   └── js/main.js            ← Copy-to-clipboard for code blocks
│
└── .github/
    └── workflows/
        └── jekyll.yml        ← GitHub Actions — builds and deploys on push to main
```

---

## Collections

The site uses two Jekyll collections defined in `_config.yml`:

**`_demos/`** — one Markdown file per demo. Each file has front matter:

```yaml
---
title: "Demo 01 — Container-Aware Heap Sizing"
demo_number: "01"
session: core          # core | bonus
runtime: "Java 21"
time: "~5 min"
demo_dir: "demo-01-heap-sizing"
run_command: "./demo.sh"
prev_url: ""           # relative URL of previous demo
prev_title: ""
next_url: "/demos/demo-02-gc-monitoring/"
next_title: "Demo 02 — GC Monitoring"
---
```

**`_diagrams/`** — one Markdown file per Excalidraw diagram. Each file has front matter:

```yaml
---
title: "GC-Induced HPA Thrash Cycle"
excalidraw_file: "01-gc-hpa-thrash-cycle.excalidraw"
order: 1               # integer, 1-10 — controls display order
slide_ref: "10–11, 21" # which slides this diagram accompanies
description: "One-sentence description shown on the gallery page"
prev_url: ""
prev_title: ""
next_url: "/diagrams/diagram-02/"
next_title: "Diagram 02"
---
Speaker notes content goes here in Markdown.
```

> **Important:** Use plain integers for `order:` (no leading zeros). `order: 01` is
> parsed as octal in YAML and causes inconsistent sort behaviour.

---

## Adding a New Demo Page

1. Create `_demos/demo-NN-name.md` with the front matter above
2. Add the demo card to `index.md` and `demos/index.md`
3. Update `prev_url`/`next_url` on the adjacent demo pages

---

## Adding a New Diagram Page

1. Commit the `.excalidraw` file to `diagrams/` in the repo root
2. Create `_diagrams/diagram-NN.md` with `excalidraw_file:` pointing to it
3. The viewer fetches the file from `raw.githubusercontent.com` at page load

---

## Excalidraw Viewer

The diagram layout (`_layouts/diagram.html`) uses the `@excalidraw/excalidraw`
React component loaded from unpkg CDN. It fetches the `.excalidraw` JSON from:

```
https://raw.githubusercontent.com/patterncatalyst/quarkus-optimization/main/diagrams/<filename>
```

This means the `.excalidraw` files must be committed to the repo's `diagrams/`
folder for the viewer to work — they cannot be served from a local path.

To test diagram pages locally with real content, the easiest approach is to
point `repo_raw` in `_config.yml` temporarily at a branch that has the files:

```yaml
repo_raw: "https://raw.githubusercontent.com/patterncatalyst/quarkus-optimization/your-branch"
```

---

## Reveal.js Slides

The presentation at `/presentation/` loads Reveal.js from cdnjs CDN. All 54 slides
are inline in `presentation/index.html`. Speaker notes are in `<aside class="notes">`
blocks and appear in presenter mode.

```
Press S  → open speaker notes window
Press O  → slide overview
Press F  → fullscreen
Press ?  → keyboard shortcuts
```

---

## Deployment

GitHub Actions handles deployment automatically:

```
Push to main → .github/workflows/jekyll.yml → bundle exec jekyll build → deploy to GitHub Pages
```

To enable: **Settings → Pages → Build and deployment → Source → GitHub Actions**

The workflow uses Ruby 3.2 to match the development environment.

---

## Troubleshooting

**`cannot load such file -- csv` (Ruby 3.4+)**

```bash
echo 'gem "csv"' >> Gemfile
bundle install
```

**`bundler: command not found: jekyll`**

```bash
bundle install   # installs the jekyll executable
bundle exec jekyll serve
```

**`bundle: command not found`**

```bash
gem install bundler
# Then add gem bin path to PATH — see Fedora step 2 above
```

**Diagram viewer shows "Could not load diagram"**

The `.excalidraw` file is not yet committed to `diagrams/` in the repo. Commit it and push.

**Site builds but CSS/links are broken**

Check `baseurl` in `_config.yml`. It must match the repo name:
```yaml
baseurl: "/quarkus-optimization"
```

When running locally, Jekyll applies `baseurl` so links resolve to
`http://localhost:4000/quarkus-optimization/`.

**Collection pages not generating**

Verify `_demos/` and `_diagrams/` directories exist at the repo root.
Jekyll only processes collection files from directories prefixed with `_`.

---

## Reference

- [Jekyll documentation](https://jekyllrb.com/docs/)
- [GitHub Pages documentation](https://docs.github.com/en/pages)
- [github-pages gem versions](https://pages.github.com/versions/)
- [Excalidraw embed API](https://docs.excalidraw.com/docs/@excalidraw/excalidraw/api/)
- [Reveal.js documentation](https://revealjs.com/)
