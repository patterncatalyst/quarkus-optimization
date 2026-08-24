# Recommended Quarkus Extensions

Extension sets by project type. Add at project creation with `quarkus create app`
or later with `quarkus ext add`.

## Core (every project)

```bash
quarkus ext add \
    health \
    micrometer-registry-prometheus \
    opentelemetry \
    config-yaml
```

| Extension | Purpose |
|---|---|
| `health` | Liveness/readiness probes (`/q/health`) |
| `micrometer-registry-prometheus` | Metrics export (`/q/metrics`) |
| `opentelemetry` | Distributed tracing (OTLP export) |
| `config-yaml` | `application.yaml` support alongside `.properties` |

## REST API service

```bash
quarkus ext add \
    rest-jackson \
    rest-client-jackson \
    hibernate-validator \
    smallrye-openapi \
    swagger-ui
```

## Kafka messaging

```bash
quarkus ext add \
    messaging-kafka \
    avro \
    apicurio-registry-avro
```

## PostgreSQL / relational

```bash
quarkus ext add \
    jdbc-postgresql \
    agroal \
    flyway
```

## LLM / AI

```bash
quarkus ext add \
    langchain4j \
    langchain4j-anthropic
```

## Containerization

No extension needed — Quarkus CLI handles it:

```bash
quarkus image build podman
```

Or use the UBI 10 Containerfile template from `templates/Containerfile`.

## Extension discovery

```bash
quarkus ext ls -i                      # list all installable
quarkus ext ls -i -s kafka             # search by keyword
quarkus ext ls -i --concise -s rest    # concise format
```

Use the Quarkus Agent MCP `quarkus_skills` tool to get coding patterns and
pitfalls for any installed extension.
