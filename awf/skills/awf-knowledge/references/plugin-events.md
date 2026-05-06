# Plugin Events

AWF provides an inter-plugin event system that lets plugins react to workflow lifecycle events without polling. The `EventBus` delivers `DomainEvent` objects to subscribed plugins over gRPC — plugins declare which patterns they subscribe to and may optionally emit custom events that other plugins can receive.

## Overview

The `EventBus` runs in-process inside the AWF host. It:
- Matches event types against dot-segment glob patterns
- Delivers events to each subscribed plugin via a per-plugin buffered channel (256 events)
- Detects event loops via propagation depth tracking (stops delivery at depth 3)

Plugins that do not declare the `events` capability receive no events and require no code changes — `BasePlugin` provides a no-op `HandleEvent` default.

## Manifest Declaration

Declare event subscriptions and emissions in `plugin.yaml`:

```yaml
name: awf-plugin-event-logger
version: 1.0.0
awf_version: ">=0.4.0"
capabilities:
  - events
events:
  subscribe:
    - "workflow.*"
    - "step.*"
  emit:
    - "my-plugin.custom_event"
```

| Field | Description |
|-------|-------------|
| `capabilities` | Must include `events` to activate the event system for this plugin |
| `events.subscribe` | Glob patterns of event types this plugin receives |
| `events.emit` | Event types this plugin may publish (informational, not enforced at runtime) |

## Lifecycle Events

`ExecutionService` emits these events around every workflow and step execution:

| Event | When emitted |
|-------|-------------|
| `workflow.started` | Workflow execution begins |
| `workflow.completed` | Workflow completes successfully |
| `workflow.failed` | Workflow fails |
| `step.started` | Step execution begins |
| `step.completed` | Step completes successfully |
| `step.failed` | Step fails |
| `step.retrying` | Step retry attempt begins |

Each event carries a `Payload` map with context for that event type (workflow name, step name, exit code, etc.) and a `Metadata` map for string annotations.

## Glob Pattern Matching

AWF uses dot-segment glob matching:

| Pattern | Matches |
|---------|---------|
| `workflow.*` | `workflow.started`, `workflow.completed`, `workflow.failed` |
| `step.*` | `step.started`, `step.completed`, `step.failed`, `step.retrying` |
| `step.started` | `step.started` only (exact match) |
| `my-plugin.*` | Any custom event emitted by `my-plugin` |

A subscription list may mix exact and wildcard patterns. A plugin receives the event if any pattern matches.

## SDK Implementation

Implement `EventSubscriber` in your plugin struct and register the capability in the manifest. `sdk.Serve()` automatically registers the `EventService` gRPC server when `HandleEvent` is present on the plugin.

```go
package main

import (
    "context"
    "log"

    "github.com/awf-project/cli/pkg/plugin/sdk"
)

type EventLoggerPlugin struct{ sdk.BasePlugin }

func (p *EventLoggerPlugin) Name() string    { return "awf-plugin-event-logger" }
func (p *EventLoggerPlugin) Version() string { return "1.0.0" }

func (p *EventLoggerPlugin) HandleEvent(ctx context.Context, event sdk.Event) error {
    log.Printf("[event] %s from %s (depth=%d)", event.Type, event.Source, event.PropagationDepth)
    return nil
}

func main() { sdk.Serve(&EventLoggerPlugin{}) }
```

### EventSubscriber Interface

```go
type EventSubscriber interface {
    HandleEvent(ctx context.Context, event Event) error
}
```

### Event Fields

```go
type Event struct {
    ID               string            // UUID assigned at emission
    Type             string            // e.g. "workflow.started"
    Source           string            // component that emitted the event
    Payload          map[string]any    // event-specific context
    Metadata         map[string]string // string annotations
    PropagationDepth int               // incremented on each re-delivery hop
}
```

## Cycle Detection

To prevent infinite loops between plugins that both subscribe and emit:

- Every event carries a `PropagationDepth` counter, incremented on each delivery hop.
- When `PropagationDepth` reaches 3, the `EventBus` stops delivery and logs a warning.
- This is not a hard error — the workflow continues unaffected.

## Backward Compatibility

Plugins that do not implement `HandleEvent` are unaffected. `BasePlugin` provides a no-op default:

```go
func (b *BasePlugin) HandleEvent(ctx context.Context, event Event) error { return nil }
```

Existing plugins compiled without the `events` capability continue to work without any changes. The `EventService` gRPC endpoint is only registered by `sdk.Serve()` when the concrete plugin type satisfies `EventSubscriber`.

## awf plugin list Output

Plugins with the `events` capability show `events` in the CAPABILITIES column:

```
NAME                       TYPE      VERSION  STATUS   ENABLED  CAPABILITIES  SOURCE
github                     builtin   v0.4.0   builtin  yes      operations
awf-plugin-event-logger    external  1.0.0    running  yes      events        myorg/awf-plugin-event-logger
```

## Example Plugin

See `examples/plugins/awf-plugin-event-logger/` for a complete working plugin that subscribes to all lifecycle events and writes structured log entries.
