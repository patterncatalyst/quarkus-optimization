---
name: lgtm-quarkus
description: Scaffold a Quarkus project with full dev toolchain — SDKMAN (JDK 25, Maven 3.9, JBang, Quarkus CLI), Quarkus Agent MCP server, Micrometer observability, structured file logging for Claude, Citrus + Newman testing, and UBI 10 Containerfiles. Use whenever starting a new Quarkus project, setting up Quarkus dev prerequisites, adding MCP tooling to an existing Quarkus app, or wiring up test infrastructure. Also triggers for "new Quarkus project", "set up Quarkus", "Quarkus prerequisites", "add Quarkus MCP", "Quarkus testing setup", or any request combining Quarkus with observability, testing, or AI agent tooling.
---

# lgtm-quarkus Skill

A skill that scaffolds a Quarkus project with a complete development toolchain — from
SDKMAN-managed prerequisites through MCP server integration, structured logging for
Claude Code, and a multi-layer test framework.

The output is a project-ready setup: prerequisites verified, MCP servers configured,
logging wired for AI-assisted diagnosis, and test infrastructure scaffolded.

## When to use this skill

Use whenever the user is:

- **Starting a new Quarkus project** and needs the full toolchain from scratch.
- **Setting up prerequisites** for an existing Quarkus project (SDKMAN, JDK 25,
  Maven 3.9, JBang, Quarkus CLI).
- **Adding MCP server integration** to a Quarkus project for Claude Code or other
  AI agents.
- **Setting up test infrastructure** (Citrus integration tests, Newman/Postman
  API tests, Micrometer assertions).
- **Adding structured logging** for post-run AI-assisted diagnosis.
- **Containerizing a Quarkus app** with UBI 10 multi-stage Containerfiles.

## What the skill does NOT do

- It does not scaffold Kubernetes infrastructure — pair with `lgtm-minikube-stack`
  for that.
- It does not scaffold observability infrastructure (Grafana, Loki, Tempo, Mimir) —
  pair with `lgtm-podman-stack` or `lgtm-minikube-stack`.
- It does not produce tutorial prose or documentation sites — pair with
  `lgtm-jekyll` or `lgtm-tutorial`.
- It does not install SDKMAN, JDK, or Maven itself — it produces the commands
  and verifies they succeed. The user runs the installs.

## Workflow

When invoked, do this in order:

1. **Check prerequisites** — verify or guide installation of each tool. Use
   `references/prerequisites.md` for the full checklist and install commands.

2. **Configure MCP servers** — set up the Quarkus Agent MCP server and optionally
   the Camel MCP server. Use `references/mcp-servers.md` for configuration.

3. **Scaffold or update the project** — either create a new Quarkus project with
   the Quarkus CLI or update an existing one with extensions, logging, and test deps.

4. **Wire up logging** — add Quarkus file logging with rotation for Claude Code
   post-run diagnosis. Use `references/logging.md`.

5. **Wire up testing** — add Citrus integration test deps, Newman/Postman API test
   runner, and Micrometer assertion patterns. Use `references/testing.md`.

6. **Add Containerfile** — UBI 10 multi-stage build. Use `templates/Containerfile`.

7. **Generate CLAUDE.md** if new project — include project-specific context for
   Claude Code.

## Key principles (always apply)

- **SDKMAN is the single tool manager.** JDK 25, Maven 3.9, JBang, and Quarkus CLI
  all install through SDKMAN. Don't mix package managers for these tools.

- **JDK 25 Temurin for development and compile target.** Containerfiles use
  `ubi10/openjdk-25-runtime` (OpenJDK 25.0.3 LTS, Red Hat build). Set
  `maven.compiler.release=25` in the POM. Default GC is G1GC; Shenandoah is
  available with `-XX:+UseShenandoahGC` if lower-latency pauses are needed.

- **Quarkus Agent MCP for AI-assisted development.** The Quarkus Agent MCP handles
  project lifecycle (create, start, stop, logs, dev UI proxy, doc search) and
  provides extension-specific coding skills. Runs via JBang — no build step needed.
  See `references/mcp-servers.md`.

- **Structured file logging is non-negotiable for AI-assisted development.**
  Quarkus writes logs to rotating files that Claude Code can read after a crash
  or test failure. Console logging alone is insufficient — it scrolls away and
  can't be grep'd by an agent post-mortem.

- **Test in layers, not monolithically.** Layer 1 (route unit tests with
  MockEndpoint) runs in seconds. Layer 2 (Citrus integration with Testcontainers)
  runs in minutes. Layer 3 (Newman/Postman API tests) runs against a live stack.
  Each layer catches different classes of bugs.

- **Micrometer + OTel from day one.** Add the Micrometer and OpenTelemetry
  extensions at project creation, not retroactively. The cost of adding them
  later is much higher than including them from the start.

- **UBI 10 multi-stage Containerfiles, never Dockerfiles.** Red Hat Universal
  Base Images, `openjdk-25` builder stage, `openjdk-25-runtime` final stage.
  Name the file `Containerfile`, not `Dockerfile`. Use `podman compose`
  (built-in subcommand), not the standalone `podman-compose` Python package.

- **Pin versions in SDKMAN installs.** `sdk install java 25-tem` not
  `sdk install java`. Reproducible toolchains prevent "works on my machine."

## Reference files

Read these as needed, not preemptively:

- `references/prerequisites.md` — SDKMAN, JDK 25, Maven 3.9, JBang, Quarkus CLI,
  Podman install checklist with verification commands.
- `references/mcp-servers.md` — Quarkus Agent MCP and Camel MCP server setup,
  tools inventory, and Claude Code configuration.
- `references/logging.md` — Quarkus file logging configuration for Claude Code
  AI-assisted diagnosis.
- `references/testing.md` — Citrus integration tests, Newman/Postman API tests,
  Micrometer assertions, Maven profiles.
- `references/extensions.md` — Recommended Quarkus extension sets by project type.

## Snippets

Drop-in reusable patterns:

- `snippets/application-logging.properties` — Quarkus file logging with rotation.
- `snippets/application-test.properties` — Test profile with mock services.
- `snippets/pom-test-deps.xml` — Test dependency block (Citrus, camel-quarkus-junit5).

## Templates

- `templates/Containerfile` — UBI 10 multi-stage build.
- `templates/CLAUDE.md.template` — Project CLAUDE.md template.
- `templates/newman-run.sh.template` — Newman/Postman test runner script.

## Multi-step work → `lgtm-relay`

For non-trivial projects (multi-module, Kafka + Postgres + LLM), use `lgtm-relay`:
Opus plans the extension set and module structure, Sonnet scaffolds and wires
everything, Opus validates against a real `quarkus dev` run.
