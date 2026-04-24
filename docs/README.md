# docs/ — Jekyll site source

This folder is the source for the GitHub Pages site at
<https://patterncatalyst.github.io/quarkus-optimization/>.

It's built with Jekyll using the [Just the Docs](https://just-the-docs.com/)
remote theme — no theme gem needs to be installed in the repo itself.

## Structure

```
docs/
├── _config.yml            # Site + theme config
├── index.md               # Landing page  (nav_order: 1)
├── demos/
│   └── index.md           # Demos section (nav_order: 2)
├── diagrams/
│   └── index.md           # Diagrams      (nav_order: 3)
├── presentation/
│   └── index.md           # Talk material (nav_order: 4)
├── Gemfile                # For local preview
└── .gitignore             # Ignore _site/ and bundler artifacts
```

## Local preview

```bash
cd docs
bundle install
bundle exec jekyll serve
```

Then open <http://localhost:4000/quarkus-optimization/>.

## Publishing

Already configured via GitHub Pages:

- **Settings → Pages → Source:** Deploy from a branch
- **Branch:** `main` — **Folder:** `/docs`

Pushes to `main` that touch this folder trigger a rebuild automatically.

## Updating

- Add a new top-level section by creating `docs/<name>/index.md` with
  `nav_order: N` in the front matter.
- Add child pages by putting `parent: <Section Title>` in their front matter
  and setting `has_children: true` on the section index.
- Keep page titles in front matter in sync with the `title:` you want shown in
  the left nav.

See the [Just the Docs navigation docs](https://just-the-docs.com/docs/navigation-structure/)
for more options.
