# Project Configuration

## Overview

`.awf/config.yaml` pre-populates workflow inputs, reducing command-line arguments.

## Format

```yaml
inputs:
  project: "my-project-id"
  env: "staging"
  max_tokens: 4000
  debug: false
```

## Supported Types

| Type | Example |
|------|---------|
| String | `name: "value"` |
| Integer | `count: 42` |
| Float | `ratio: 3.14` |
| Boolean | `enabled: true` |

## Plugin Configuration

Configure built-in and external plugins under the `plugins:` key:

### Notification Plugin

```yaml
plugins:
  notify:
    ntfy_url: "https://ntfy.sh"
    slack_webhook_url: "https://hooks.slack.com/services/..."
    default_backend: "desktop"
```

| Key | Description |
|-----|-------------|
| `ntfy_url` | Base URL for ntfy server (required for `ntfy` backend) |
| `slack_webhook_url` | Slack incoming webhook URL (required for `slack` backend) |
| `default_backend` | Backend used when `backend` input is omitted from `notify.send` |

When both a config `default_backend` and an explicit `backend` input are set, the explicit input takes precedence.

## Priority Order

```
Config File < CLI Flags
```

CLI `--input` flags override config values.

## Example

```yaml
# .awf/config.yaml
inputs:
  env: "staging"
  project: "my-app"
```

```bash
awf run deploy --input env=production
# env=production (CLI wins), project=my-app (from config)
```

## Commands

```bash
awf init              # Create config file
awf config show       # Display config
awf config show -f json  # JSON output
```

## Environment Variables (v0.5.28)

AWF supports environment variables for configuration:

| Variable | Description |
|----------|-------------|
| `AWF_PROMPT_PATH` | Custom path for prompt file resolution |

### Prompt Path Resolution

When resolving prompt files (e.g., `prompt_file: "@prompts/review.md"`), AWF searches in this order:

1. **Environment variable** - `$AWF_PROMPT_PATH` (if set)
2. **Local directory** - `.awf/prompts/` in current project
3. **Global directory** - `$XDG_CONFIG_HOME/awf/prompts/` (typically `~/.config/awf/prompts/`)

```bash
# Set custom prompt path
export AWF_PROMPT_PATH="/path/to/shared/prompts"
awf run review  # Uses prompts from $AWF_PROMPT_PATH first
```

## Output Configuration (v0.5.29)

Control step output size and streaming behavior:

```yaml
# In workflow definition
states:
  process_large_file:
    type: step
    command: ./generate-report.sh
    output:
      max_size: 1048576  # 1MB limit
      stream_to_file: true  # Stream large outputs to temp file
    on_success: done
```

### Output Options

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `max_size` | int | unlimited | Maximum output bytes before truncation |
| `stream_to_file` | bool | false | Stream large outputs to temp file instead of memory |

### Behavior

- **Truncation**: When `max_size` is set, outputs exceeding the limit are truncated with a warning
- **Streaming**: When `stream_to_file: true`, large outputs stream to `$XDG_STATE_HOME/awf/outputs/` instead of being held in memory
- **Backward compatible**: Default (unlimited, no streaming) preserves existing behavior

## Loop Memory Management (v0.5.29)

Control memory usage in long-running loops:

```yaml
states:
  process_items:
    type: for_each
    items: "{{.inputs.large_list}}"
    memory:
      max_results: 100  # Keep only last 100 iteration results
    body:
      - process_item
    on_complete: done
```

### Memory Options

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `max_results` | int | unlimited | Rolling window size for iteration results |

### Behavior

- **Rolling window**: When `max_results` is set, only the most recent N iteration results are kept in memory
- **Early results pruned**: Oldest results are automatically pruned as new iterations complete
- **Access pattern**: Use `{{.loop.index}}` to track current position; accessing pruned results returns empty values
- **Backward compatible**: Default (unlimited) preserves existing behavior for loops with reasonable iteration counts

## Memory Monitoring

AWF monitors heap allocation and logs warnings when memory thresholds are exceeded. This is particularly useful for:

- Long-running loops with many iterations
- Steps producing large outputs
- Parallel execution with many concurrent branches

No configuration required - monitoring is automatic. Warnings appear in verbose mode (`--verbose`).

## Best Practices

1. **No secrets** - Use environment variables instead
2. **Version control** - Commit `.awf/config.yaml` for team sharing
3. **Comments** - Document settings with YAML comments
4. **Loop memory** - Set `max_results` for loops with 1000+ iterations
5. **Large outputs** - Use `stream_to_file: true` for steps producing MB+ outputs
