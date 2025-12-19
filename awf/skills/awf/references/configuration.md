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

## Best Practices

1. **No secrets** - Use environment variables instead
2. **Version control** - Commit `.awf/config.yaml` for team sharing
3. **Comments** - Document settings with YAML comments
