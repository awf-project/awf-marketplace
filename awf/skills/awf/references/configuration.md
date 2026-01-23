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

## Best Practices

1. **No secrets** - Use environment variables instead
2. **Version control** - Commit `.awf/config.yaml` for team sharing
3. **Comments** - Document settings with YAML comments
