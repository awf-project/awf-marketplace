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

## Emitting Events from Plugins

Plugins have two ways to emit events back to the host:

### 1. Return from HandleEvent

Return an `sdk.Event` slice as an additional return value from `HandleEvent`. The host delivers each returned event to the `EventBus` after `HandleEvent` completes.

```go
func (p *MyPlugin) HandleEvent(ctx context.Context, event sdk.Event) error {
    // React to an incoming event and emit a custom one synchronously
    out := sdk.Event{
        Type:    "my-plugin.processed",
        Source:  "my-plugin",
        Payload: map[string]any{"original": event.Type},
    }
    return p.EmitEvent(out) // BasePlugin helper — queues for return
}
```

### 2. HostClient.Emit() — runtime emission

`HostClient.Emit()` sends an event to the host at any point during plugin execution, not only inside `HandleEvent`. Use this from operation handlers, step type handlers, or background goroutines.

```go
type MyPlugin struct {
    sdk.BasePlugin
    host *sdk.HostClient
}

// Wire the host client during plugin initialization
func (p *MyPlugin) SetHostClient(client *sdk.HostClient) {
    p.host = client
}

func (p *MyPlugin) ExecuteOperation(ctx context.Context, op string, inputs map[string]any) (map[string]any, error) {
    result, err := doWork(inputs)
    if err != nil {
        _ = p.host.Emit(sdk.Event{
            Type:    "my-plugin.operation_failed",
            Source:  "my-plugin",
            Payload: map[string]any{"operation": op, "error": err.Error()},
        })
        return nil, err
    }
    _ = p.host.Emit(sdk.Event{
        Type:    "my-plugin.operation_completed",
        Source:  "my-plugin",
        Payload: map[string]any{"operation": op},
    })
    return result, nil
}

func main() { sdk.Serve(&MyPlugin{}) }
```

`SetHostClient` is called by `sdk.Serve()` automatically when the plugin implements it. No additional wiring is required in `main()`.

### HostEventServiceID Constant

The SDK exports `HostEventServiceID` — the service identifier used when registering the reverse channel. SDK consumers that need to reference the service name directly (for custom gRPC interceptors or testing) should use this constant instead of a string literal:

```go
import "github.com/awf-project/cli/pkg/plugin/sdk"

// Use in custom interceptors or test doubles
fmt.Println(sdk.HostEventServiceID) // "awf.plugin.v1.HostEventService"
```

## Streaming Delivery

The host delivers events to plugins using a persistent `StreamEvents` gRPC stream (one stream per plugin, kept alive for the duration of the run). This replaces the earlier per-event unary RPC approach and reduces connection overhead on high-frequency event workloads.

This is entirely host-managed and transparent to plugin developers — no SDK changes are required to benefit from streaming delivery.

**Fallback behavior**: If a plugin's gRPC endpoint does not support the `StreamEvents` RPC (e.g., an older plugin binary), the host falls back to unary RPC delivery automatically. The plugin receives events identically in both modes.

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
