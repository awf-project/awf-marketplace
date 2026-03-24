# Plugins

AWF supports plugins to extend functionality with custom operations. AWF ships with a **built-in GitHub plugin** for common GitHub operations, and supports **external RPC plugins** for additional integrations.

## Built-in GitHub Plugin

AWF includes a built-in GitHub operation provider with 8 declarative operations for issues, PRs, labels, and comments. Runs in-process with zero IPC overhead.

**Key features:**
- 8 operations: `get_issue`, `get_pr`, `create_issue`, `create_pr`, `add_labels`, `add_comment`, `list_comments`, `batch`
- Automatic auth via `gh` CLI or `GITHUB_TOKEN` environment variable
- Repository auto-detection from git remote
- Batch execution with configurable concurrency and failure strategies

```yaml
get_issue:
  type: operation
  operation: github.get_issue
  inputs:
    number: 42
  on_success: process
  on_failure: error
```

See [Workflow Syntax](workflow-syntax.md) Operation State section for complete reference.

---

## Built-in Notification Plugin

AWF includes a built-in notification provider that sends alerts when workflows complete. It exposes a single `notify.send` operation that dispatches to four backends: desktop notifications, [ntfy](https://ntfy.sh), Slack, and generic webhooks.

**Key features:**
- 1 operation: `notify.send` with backend dispatch
- 4 backends: `desktop`, `ntfy`, `slack`, `webhook`
- 10-second HTTP timeout for network backends (prevents workflow stalls)
- Platform detection for desktop notifications (`notify-send` on Linux, `osascript` on macOS)
- All inputs support AWF template interpolation

```yaml
notify_team:
  type: operation
  operation: notify.send
  inputs:
    backend: slack
    title: "Build Complete"
    message: "{{.states.summary.Output}}"
  on_success: done
  on_failure: error
```

### Notification Backends

| Backend | Transport | Required Config | Required Inputs |
|---------|-----------|-----------------|-----------------|
| `desktop` | OS-native (`notify-send` / `osascript`) | None | `message` |
| `ntfy` | HTTP POST to ntfy server | `ntfy_url` in config | `message`, `topic` |
| `slack` | HTTP POST to Slack webhook | `slack_webhook_url` in config | `message` |
| `webhook` | HTTP POST to arbitrary URL | None | `message`, `webhook_url` |

### Operation Inputs

| Input | Type | Required | Description |
|-------|------|----------|-------------|
| `backend` | string | Yes | Notification backend: `desktop`, `ntfy`, `slack`, `webhook` |
| `message` | string | Yes | Notification message body |
| `title` | string | No | Notification title (defaults to "AWF Workflow") |
| `priority` | string | No | Priority: `low`, `default`, `high` |
| `topic` | string | No | ntfy topic name (required for `ntfy` backend) |
| `webhook_url` | string | No | Webhook URL (required for `webhook` backend) |
| `channel` | string | No | Slack channel override |

### Operation Outputs

| Output | Type | Description |
|--------|------|-------------|
| `backend` | string | Which backend handled the notification |
| `status` | string | HTTP status code (network backends) or confirmation |
| `response` | string | Response body or confirmation message |

### Configuration

Configure notification backends in `.awf/config.yaml`:

```yaml
plugins:
  notify:
    ntfy_url: "https://ntfy.sh"
    slack_webhook_url: "https://hooks.slack.com/services/..."
    default_backend: "desktop"
```

| Config Key | Description |
|------------|-------------|
| `ntfy_url` | Base URL for ntfy server (required for `ntfy` backend) |
| `slack_webhook_url` | Slack incoming webhook URL (required for `slack` backend) |
| `default_backend` | Backend to use when `backend` input is omitted |

### Backend Details

**Desktop** - Uses `notify-send` on Linux and `osascript` on macOS. Fails gracefully on unsupported platforms.

**ntfy** - Posts to `<ntfy_url>/<topic>` with the notification payload. Supports priority mapping.

**Slack** - Posts a formatted message block to the configured Slack incoming webhook URL.

**Webhook** - Sends a generic JSON POST to any URL. Payload includes `workflow`, `status`, `duration`, `message`, and `outputs` fields.

---

## External RPC Plugins

Plugins extend AWF with custom operations via gRPC (HashiCorp go-plugin). Each plugin runs as an isolated subprocess; the host connects via a Unix socket negotiated at startup.

- Process isolation — plugin crashes do not affect AWF
- gRPC transport with protobuf serialization (`proto/plugin/v1/`)
- 5-second connection timeout during init
- Cross-platform support
- Safe updates without recompiling
- Graceful failure handling via `Shutdown`/`ShutdownAll`

### Operation Namespacing

External plugin operations are prefixed with the plugin ID to avoid collisions with built-in providers:

```
{plugin-id}.{operation}       # e.g., awf-plugin-echo.echo
```

Use the namespaced form in workflow steps:

```yaml
echo_step:
  type: operation
  operation: awf-plugin-echo.echo
  inputs:
    message: "hello"
  on_success: done
```

## Plugin Directory

```
$XDG_DATA_HOME/awf/plugins/     # ~/.local/share/awf/plugins/
└── awf-plugin-slack/
    ├── plugin.yaml             # Manifest
    └── awf-plugin-slack        # Binary
```

## Manifest

```yaml
name: awf-plugin-slack
version: 1.0.0
description: Slack notifications for AWF
awf_version: ">=0.4.0"
capabilities:
  - operations
config:
  webhook_url:
    type: string
    required: true
```

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Plugin identifier (see naming rules below) |
| `version` | Yes | Non-empty version string |
| `awf_version` | Yes | AWF version constraint |
| `capabilities` | Yes | `operations`, `commands`, `validators` |
| `config` | No | Configuration schema |

## Manifest Validation (v0.5.40)

AWF validates plugin manifests at load time. Invalid manifests are rejected immediately.

### Name Validation

Plugin names must follow the `^[a-z][a-z0-9-]*$` pattern:
- Start with lowercase letter
- Contain only lowercase letters, digits, and hyphens
- No uppercase, underscores, or special characters

```
my-plugin       # Valid
awf-plugin-slack # Valid
MyPlugin        # Invalid: uppercase
my_plugin       # Invalid: underscore
123-plugin      # Invalid: starts with digit
```

### Capabilities Validation

Only these capabilities are allowed:
- `operations` - Custom workflow operations
- `commands` - CLI command extensions
- `validators` - Custom validation rules

Unknown capabilities are rejected.

### Config Field Validation

Config fields are validated for:

| Check | Description |
|-------|-------------|
| Type | Must be `string`, `integer`, or `boolean` |
| Enum | Only allowed for `string` type |
| Default | Must match declared type |

```yaml
# Valid config
config:
  timeout:
    type: integer
    default: 30
  mode:
    type: string
    enum: [fast, slow]
    default: fast

# Invalid: enum on integer
config:
  count:
    type: integer
    enum: [1, 2, 3]    # Error: enum only for strings

# Invalid: type mismatch
config:
  enabled:
    type: boolean
    default: "true"    # Error: string, not boolean
```

### Validation Behavior

- **Fail-fast**: First error stops validation
- **Load-time**: Manifests validated when plugins are loaded
- **Breaking change (v0.5.40)**: `Validate()` returns `nil` for valid manifests instead of `ErrNotImplemented`

## Managing Plugins

Built-in providers (`github`, `http`, `notify`) appear in `awf plugin list` alongside external plugins with `TYPE=builtin`. They can be enabled and disabled like external plugins — disabling gates all operations from that provider at both validation and execution time.

```bash
awf plugin list                      # List all plugins (built-in + external) with TYPE column
awf plugin list --operations         # List operations (triggers full gRPC init for external plugins)
awf plugin enable notify             # Enable built-in provider
awf plugin disable notify            # Disable built-in provider (blocks notify.send at run time)
awf plugin enable awf-plugin-slack   # Enable external plugin
awf plugin disable awf-plugin-slack  # Disable external plugin
```

**Example output:**

```
NAME               TYPE      VERSION  STATUS   ENABLED  CAPABILITIES
github             builtin   v0.4.0   builtin  yes      operations
http               builtin   v0.4.0   builtin  yes      operations
notify             builtin   v0.4.0   builtin  yes      operations
awf-plugin-slack   external  1.0.0    running  yes      operations
```

**Disabled-plugin warnings:** `awf validate <workflow>` emits a warning for each step that references an operation from a disabled plugin. This catches mismatches before execution rather than failing at run time.

```bash
awf plugin disable notify
awf validate my-workflow
# Warning: step 'notify_team' references operation 'notify.send' from disabled plugin 'notify'
# Run 'awf plugin enable notify' to enable it
```

## Using in Workflows

Operation names follow the format `{plugin-id}.{operation}`. Built-in providers use short names (`github`, `notify`, `http`); external plugins use their full plugin ID as prefix:

```yaml
# Built-in provider
notify:
  type: operation
  operation: notify.send
  inputs:
    backend: slack
    message: "Deploy completed"
  on_success: done

# External plugin (namespaced with plugin ID)
echo_step:
  type: operation
  operation: awf-plugin-echo.echo   # plugin-id.operation
  inputs:
    message: "{{.states.build.Output}}"
  on_success: done
```

## Plugin SDK

The SDK (`pkg/plugin/sdk/`) provides `sdk.Serve()` as the single entry point. Plugin authors implement the `AWFPlugin` interface and call `sdk.Serve()` — gRPC internals are handled by the SDK.

```go
package main

import "github.com/awf-project/cli/pkg/plugin/sdk"

type MyPlugin struct{}

func (p *MyPlugin) Name() string    { return "awf-plugin-example" }
func (p *MyPlugin) Version() string { return "1.0.0" }

func (p *MyPlugin) Init(config map[string]interface{}) error { return nil }
func (p *MyPlugin) Shutdown() error { return nil }

func (p *MyPlugin) Operations() []sdk.Operation {
    return []sdk.Operation{
        {
            Name:        "greet",
            Description: "Say hello",
            Execute: func(ctx sdk.Context, inputs map[string]interface{}) (sdk.Result, error) {
                return sdk.Result{Output: "Hello, " + inputs["name"].(string)}, nil
            },
        },
    }
}

func main() { sdk.Serve(&MyPlugin{}) }
```

The `Handshake` config is exported from `sdk` as the single source of truth shared by both the host and all plugins — do not define your own handshake.

See `examples/plugins/awf-plugin-echo/` for a minimal working plugin with `echo` and `reverse` operations.

## Schema Validation (v0.5.38)

AWF validates plugin operation schemas at load time. Four validation methods ensure schema correctness:

| Method | Purpose |
|--------|---------|
| `ValidateOperationSchema` | Validates operation/plugin names, delegates to input schemas, checks for duplicate outputs |
| `RequiredInputs` | Returns list of required input parameter names |
| `ValidateInputSchema` | Validates input type, validation rules, and default value type matching |
| `IsValidType` | Checks if input type is one of: `string`, `integer`, `boolean` |

### Supported Validation Rules

Plugin inputs can use these validation rules:

| Rule | Type | Example |
|------|------|---------|
| `url` | string | Validates URL format |
| `email` | string | Validates email format |
| `pattern` | string | Custom regex pattern |
| `enum` | any | Allowed values list |
| `min`/`max` | integer | Numeric range |

### Schema Example

```yaml
operations:
  - name: send_notification
    inputs:
      - name: webhook
        type: string
        required: true
        validation:
          url: true
      - name: recipient
        type: string
        required: true
        validation:
          email: true
      - name: priority
        type: integer
        default: 1
        validation:
          min: 1
          max: 5
    outputs:
      - name: message_id
        type: string
```

### Validation Errors

Schema validation errors are collected (non-fail-fast):

```bash
awf plugin validate awf-plugin-example
```

```
schema validation failed: 3 errors:
  - operations.send_notification.inputs.webhook: invalid validation rule "urll"
  - operations.send_notification.inputs.priority: default value type "string" does not match declared type "integer"
  - operations.send_notification.outputs: duplicate output name "message_id"
```

## Troubleshooting

| Error | Solution |
|-------|----------|
| Plugin not found | Check directory name matches plugin name |
| Exec format error | Rebuild binary for your platform |
| Version mismatch | Update AWF or use compatible plugin version |
| Connection timeout (5s) | Plugin binary failed to start; check binary path and permissions |
| Operation not found | Use namespaced form `{plugin-id}.{operation}` in workflow step |
| Handshake mismatch | Rebuild plugin with same SDK version as AWF host |
