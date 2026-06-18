# MCP Proxy Reference

AWF's MCP proxy layer intercepts and controls tool calls between agents and MCP servers. It exposes a set of builtin tools and plugin-provided tools through the standard MCP stdio protocol, enabling workflow-level filtering, routing, and auditing.

## Overview

Two related features:

1. **`mcp_proxy` step field** — per-step configuration declaring which tools an agent may call during that step
2. **`awf mcp serve`** — standalone command that starts a stdio MCP server wrapping AWF plugins, usable by any MCP-capable agent outside of AWF

## `mcp_proxy` in Agent Steps

Add `mcp_proxy:` to any `type: agent` step to control which tools the agent can invoke:

```yaml
analyze:
  type: agent
  provider: claude
  prompt: "Review this file: {{.inputs.path}}"
  mcp_proxy:
    enabled: true
    allowed_tools:
      - read
      - grep
      - glob
  on_success: done
```

### Builtin Tools

AWF ships six builtin tools exposed through the proxy layer:

| Tool | Description |
|------|-------------|
| `bash` | Execute shell commands |
| `glob` | File pattern matching |
| `grep` | Content search (ripgrep-backed) |
| `read` | Read file contents |
| `write` | Write file contents |
| `edit` | Exact-string file edits |

### `mcp_proxy` Configuration Fields

```yaml
mcp_proxy:
  enabled: true                  # Required: activate proxy for this step
  allowed_tools:                 # Whitelist of tool names (builtins + plugin tools)
    - read
    - grep
    - glob
  plugin_bindings:               # Expose plugin-provided tools via proxy
    - plugin: awf-plugin-database
      tools:
        - sql_query
```

| Field | Type | Description |
|-------|------|-------------|
| `enabled` | bool | Activate MCP proxy for this step |
| `allowed_tools` | list of strings | Tool names the agent may invoke; empty list allows none |
| `plugin_bindings` | list | Plugin tool bindings to expose through the proxy |
| `plugin_bindings[].plugin` | string | Plugin ID (must be installed and enabled) |
| `plugin_bindings[].tools` | list of strings | Tool names from that plugin to expose |

### Provider Support

| Provider | MCP Proxy Support |
|----------|------------------|
| `claude` | Full support via `--mcp-config` flag |
| `gemini` | Full support via MCP config |
| `github_copilot` | Full support via MCP config |
| `mistral_vibe` | Full support via isolated `VIBE_HOME/config.toml`; tool names exposed as `awf-proxy_<tool>` |
| `opencode` | Full support via workspace config |
| `openai_compatible` | Full support via API-level tool injection |
| `codex` | Warning emitted; stdio MCP not supported |

### Validation

`awf validate` checks `mcp_proxy` configuration:
- Unknown plugin in `plugin_bindings` → error
- Plugin disabled → error
- Tool name not found in plugin → error
- `enabled: false` with non-empty config → warning

```bash
awf validate my-workflow
# Validates mcp_proxy stanzas in all steps
```

Test fixtures available in `tests/fixtures/mcp_proxy/` for valid and invalid configurations.

### Example: Read-Only File Analysis

Restrict the agent to read-only tools to prevent unintended writes:

```yaml
audit:
  type: agent
  provider: claude
  prompt: "Audit all Go files for security issues: {{.inputs.dir}}"
  options:
    dangerously_skip_permissions: true
  mcp_proxy:
    enabled: true
    allowed_tools:
      - read
      - glob
      - grep
  on_success: report
```

### Example: Plugin Tool Exposure

Expose a database plugin's tools to the agent:

```yaml
query_and_analyze:
  type: agent
  provider: claude
  prompt: "Query the users table and summarize the results"
  mcp_proxy:
    enabled: true
    allowed_tools:
      - read
    plugin_bindings:
      - plugin: awf-plugin-database
        tools:
          - sql_query
  on_success: done
```

### Example: Mistral Vibe Tool Names

Configure workflow allowlists with normal AWF tool names. AWF injects them into Vibe as `awf-proxy_<tool>` names inside a temporary `VIBE_HOME/config.toml`:

```yaml
vibe_audit:
  type: agent
  provider: mistral_vibe
  prompt: "Audit scripts under {{.inputs.path}}."
  mcp_proxy:
    enabled: true
    allowed_tools:
      - read
      - grep
  on_success: done
```

Inside Vibe, the visible MCP tools are `awf-proxy_read` and `awf-proxy_grep`.

**Config handling:**
- AWF creates a temporary `VIBE_HOME` for the step and runs the `vibe` subprocess with that environment override.
- User credentials are copied into the temporary home.
- Existing user `[[mcp_servers]]` entries are stripped before AWF writes the proxy server entry, preventing stale MCP servers from leaking into the step.
- Temporary config is scoped to the step lifecycle.

## `awf mcp serve`

Starts a stdio JSON-RPC 2.0 MCP server that wraps AWF plugins. Any MCP-capable agent (Claude Code, Gemini, Mistral Vibe, Codex, Copilot, OpenAI-compatible) can connect to it and invoke AWF tools directly.

```bash
awf mcp serve [flags]
```

| Flag | Description |
|------|-------------|
| `--plugins` | Comma-separated plugin IDs to expose (default: all enabled plugins) |

**Usage with Claude Code:**

Add to Claude Code's MCP configuration:
```json
{
  "mcpServers": {
    "awf": {
      "command": "awf",
      "args": ["mcp", "serve"]
    }
  }
}
```

Once configured, Claude Code can invoke AWF builtin tools (`bash`, `read`, `grep`, `glob`, `write`, `edit`) and any tools exposed by installed AWF plugins, through the standard MCP tool-call protocol.

**Lifecycle:**
- Reads requests from stdin, writes responses to stdout (JSON-RPC 2.0 framing)
- Graceful shutdown on SIGINT or SIGTERM
- Terminates with a system error if the working directory cannot be determined (required for sandbox isolation)
- Plugin RPC connections are established on first tool call (lazy init)
- Stale proxy config files are cleaned up automatically after shutdown

## Plugin Tool Provider SDK

Plugins can advertise their own tool schemas over gRPC so AWF can expose them through the MCP proxy. Implement the `ToolProvider` interface in your plugin:

```go
// In your AWF plugin (Go SDK)
func (p *MyPlugin) Tools() []sdk.ToolSchema {
    return []sdk.ToolSchema{
        {
            Name:        "my_tool",
            Description: "Does something useful",
            InputSchema: json.RawMessage(`{
                "type": "object",
                "properties": {
                    "query": {"type": "string"}
                },
                "required": ["query"]
            }`),
        },
    }
}
```

**ToolProvider call contract:**
- Nil args and empty args are treated as equivalent (no arguments).
- A successful invocation must return a non-nil result.
- Errors can be reported via the returned `error` value or as an error field within the result (dual error-reporting contract).

When `awf plugin list` shows a plugin with the `tools` capability flag, its tools are available for `plugin_bindings` in `mcp_proxy` configuration.

## Architecture

```
Agent CLI
    │
    │  JSON-RPC 2.0 (stdio)
    ▼
AWF MCP Proxy Server (internal/infrastructure/mcp)
    │
    ├── Builtin tools (bash, glob, grep, read, write, edit)
    │
    └── Plugin adapter → Plugin gRPC RPC
            │
            └── External plugin binary
```

The proxy spawns as a subprocess during agent step execution and terminates when the step completes. Each step that enables `mcp_proxy` gets its own isolated proxy instance with its own allowed-tool allowlist.
