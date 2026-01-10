# Plugins

## Overview

Plugins extend AWF with custom operations via RPC (HashiCorp go-plugin).

- Process isolation
- Cross-platform support
- Safe updates without recompiling
- Graceful failure handling

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
| `name` | Yes | Plugin identifier |
| `version` | Yes | Semantic version |
| `awf_version` | Yes | AWF version constraint |
| `capabilities` | Yes | `operations`, `commands`, `validators` |
| `config` | No | Configuration schema |

## Managing Plugins

```bash
awf plugin list                    # List plugins
awf plugin enable awf-plugin-slack # Enable
awf plugin disable awf-plugin-slack # Disable
```

## Using in Workflows

```yaml
notify:
  type: step
  operation: slack.send_message    # plugin.operation
  inputs:
    channel: "#deployments"
    message: "Deploy completed: {{.states.deploy.Output}}"
  on_success: done
```

## Plugin SDK

```go
package main

import "github.com/vanoix/awf/pkg/plugin/sdk"

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

## Troubleshooting

| Error | Solution |
|-------|----------|
| Plugin not found | Check directory name matches plugin name |
| Exec format error | Rebuild binary for your platform |
| Version mismatch | Update AWF or use compatible plugin version |
