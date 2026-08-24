# Structured File Logging for Claude Code

Quarkus file logging with rotation enables Claude Code to read logs after a crash,
test failure, or unexpected behavior — essential for AI-assisted diagnosis.

## Why file logging matters for AI agents

Console output scrolls away and can't be retrieved after a process exits. File
logging gives Claude Code a persistent, grep-able record of what happened. The
Quarkus Agent MCP's `quarkus_app_log` tool can read these files directly.

## Configuration

Add to `src/main/resources/application.properties`:

```properties
# ── File logging ────────────────────────────────────────────
quarkus.log.file.enable=true
quarkus.log.file.path=logs/${quarkus.application.name}.log
quarkus.log.file.rotation.max-file-size=10M
quarkus.log.file.rotation.max-backup-index=5
quarkus.log.file.rotation.file-suffix=.yyyy-MM-dd
quarkus.log.file.format=%d{yyyy-MM-dd HH:mm:ss.SSS} %-5p [%c{3.}] (%t) %s%e%n

# ── Structured JSON for machine parsing (optional) ─────────
# quarkus.log.file.json=true
# quarkus.log.file.json.pretty-print=false
```

## Dev profile override

In dev mode, keep console as primary but still write files:

```properties
%dev.quarkus.log.file.enable=true
%dev.quarkus.log.file.path=logs/dev.log
%dev.quarkus.log.console.level=INFO
%dev.quarkus.log.file.level=DEBUG
```

## Log directory convention

```
project-root/
├── logs/
│   ├── my-service.log              ← current
│   ├── my-service.log.2026-08-16   ← rotated
│   └── my-service.log.2026-08-15
├── src/
└── pom.xml
```

Add `logs/` to `.gitignore`.

## Per-category tuning

Reduce noise from frameworks, keep application logs verbose:

```properties
quarkus.log.category."org.apache.kafka".level=WARN
quarkus.log.category."io.quarkus".level=INFO
quarkus.log.category."com.mycompany".level=DEBUG
```

## Reading logs with Claude Code

After a failure, Claude Code can:
1. Use `quarkus_app_log` MCP tool to read recent output
2. Read the log file directly: `Read logs/my-service.log`
3. Grep for errors: `grep -n 'ERROR\|WARN\|Exception' logs/my-service.log`

The structured format with timestamps, log levels, and short class names makes
it straightforward for an AI agent to identify the failure chain.
