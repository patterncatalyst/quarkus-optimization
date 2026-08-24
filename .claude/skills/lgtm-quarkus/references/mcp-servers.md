# Quarkus Agent MCP Server

**Source:** [quarkusio/quarkus-agent-mcp](https://github.com/quarkusio/quarkus-agent-mcp)

A standalone MCP server that runs as a separate process (survives app crashes).
Provides project lifecycle management, extension skills, dev MCP proxy, and
documentation search.

## Install via Claude Code

```bash
claude mcp add -s user quarkus-agent -- jbang quarkus-agent-mcp@quarkusio
```

Or via the plugin marketplace:

```bash
claude plugin marketplace add quarkusio/quarkus-agent-mcp
claude plugin install quarkus-agent@quarkus-tools
```

## Tools provided

| Category | Tool | Description |
|---|---|---|
| **Project** | `quarkus_create` | Create a new Quarkus app, auto-start dev mode, generate CLAUDE.md |
| **Skills** | `quarkus_skills` | Get coding patterns, testing guidelines, pitfalls for extensions |
| | `quarkus_updateSkill` | Create or update a global skill customization |
| | `quarkus_saveSkill` | Materialize a composed skill as a standalone file |
| **Lifecycle** | `quarkus_start` | Start app in dev mode |
| | `quarkus_stop` | Graceful shutdown |
| | `quarkus_restart` | Force restart |
| | `quarkus_status` | Get app state |
| | `quarkus_logs` | Get recent log output |
| | `quarkus_list` | List all managed instances |
| | `quarkus_browser` | Open app or Dev UI in browser |
| **Dev MCP** | `quarkus_searchTools` | Discover tools on the running app's Dev MCP server |
| | `quarkus_callTool` | Invoke a Dev MCP tool by name |
| **Docs** | `quarkus_searchDocs` | Semantic search over Quarkus documentation |
| **Logging** | `quarkus_agent_log` | Enable/disable/read MCP server log |
| | `quarkus_app_log` | Enable/disable/read managed app log |

## Configuration

Set in environment variables or `~/.quarkus/agent-mcp/application.properties`:

| Property | Default | Description |
|---|---|---|
| `agent-mcp.log.enabled` | `false` | Enable file logging |
| `agent-mcp.doc-search.min-score` | `0.82` | Minimum similarity for doc search |
| `agent-mcp.local-skills-dir` | `~/.quarkus/skills` | User-level skill customizations |

## Prerequisites

- Java 21+ (JDK 25 recommended)
- Docker or Podman (for documentation search — runs a pgvector container)
- JBang (for resolving the MCP server jar from Maven Central)

## Dev MCP Proxy

When a Quarkus app is running in dev mode, Quarkus exposes its own MCP tools
via the Dev UI. The Quarkus Agent MCP proxies these tools so Claude Code can
call them without a separate connection. Use `quarkus_searchTools` to discover
what the running app exposes, then `quarkus_callTool` to invoke them.
