# Distributed Tracing

## Overview

AWF emits OpenTelemetry spans for workflow executions, exportable to any OTLP-compatible backend (Jaeger, Grafana Tempo, Honeycomb, Datadog). Tracing is completely opt-in: when no exporter is configured, there is zero overhead and no network connections are attempted.

## Quick Start

```bash
# Start a local Jaeger instance (requires Docker)
docker compose up -d

# Run a workflow with tracing enabled
awf run my-workflow --otel-exporter=localhost:4317 --otel-service-name=my-service

# Open the Jaeger UI
open http://localhost:16686
```

## Configuration

### Project-level (`telemetry:` in `.awf/config.yaml`)

```yaml
# .awf/config.yaml
telemetry:
  exporter: "localhost:4317"   # OTLP gRPC endpoint
  service_name: "my-service"   # defaults to project name when omitted
```

| Key | Type | Required | Description |
|-----|------|----------|-------------|
| `exporter` | string | no | OTLP gRPC endpoint (`host:port`). Tracing is disabled when absent. |
| `service_name` | string | no | Service name in traces. Defaults to the AWF project name. |

### CLI flags (per-run override)

```bash
awf run <workflow> \
  --otel-exporter localhost:4317 \
  --otel-service-name my-service
```

| Flag | Description |
|------|-------------|
| `--otel-exporter` | OTLP gRPC endpoint. Overrides `telemetry.exporter` in config. |
| `--otel-service-name` | Service name for traces. Overrides `telemetry.service_name` in config. |

### Priority order

```
--otel-exporter / --otel-service-name (CLI flags)
    > telemetry: block in .awf/config.yaml
        > no-op (tracing disabled)
```

## Span Hierarchy

Every workflow run produces a root `workflow.run` span. Child spans are created for each execution phase:

```
workflow.run
  step.<name>
    agent.call   (attributes: provider, model, input_tokens, output_tokens)
  parallel.<id>
    step.<name>
  loop.<id>
    step.<name>  (one span per iteration)
```

### Span names and attributes

| Span | Attributes |
|------|------------|
| `workflow.run` | workflow name |
| `step.<name>` | step name |
| `agent.call` | `provider`, `model`, `input_tokens`, `output_tokens` |
| `parallel.<id>` | parallel block identifier |
| `loop.<id>` | loop block identifier |

## Backend Examples

### Jaeger (local development)

A `compose.yaml` is included in the AWF CLI repository for local development:

```yaml
# compose.yaml (from AWF CLI repo root)
services:
  jaeger:
    image: jaegertracing/all-in-one:latest
    ports:
      - "4317:4317"    # OTLP gRPC
      - "16686:16686"  # Jaeger UI
```

```bash
docker compose up -d
awf run my-workflow --otel-exporter=localhost:4317
# UI: http://localhost:16686
```

### Grafana Tempo

```yaml
# .awf/config.yaml
telemetry:
  exporter: "tempo.example.com:4317"
  service_name: "awf-workflows"
```

### Honeycomb

```yaml
# .awf/config.yaml
telemetry:
  exporter: "api.honeycomb.io:443"
  service_name: "awf-workflows"
```

Set `HONEYCOMB_API_KEY` as required by Honeycomb's OTLP endpoint.

### Datadog

```yaml
# .awf/config.yaml
telemetry:
  exporter: "localhost:4317"   # Datadog Agent OTLP receiver
  service_name: "awf-workflows"
```

Requires the Datadog Agent with `otlp_config.receiver.protocols.grpc` enabled.

## Architecture Note

The `Tracer` port is defined in `internal/domain/ports/tracer.go` and wired through the application layer following hexagonal architecture. The `NoopTracer` default implements the port with zero overhead. The OTLP gRPC exporter is an infrastructure adapter in `internal/infrastructure/otel/`. Providers (agent implementations) remain decoupled from the tracing SDK.

**Details**: [Architecture](architecture.md) | [Configuration](configuration.md) | [CLI Commands](cli-commands.md)
