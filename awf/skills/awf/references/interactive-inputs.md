# Interactive Input Collection

AWF prompts for missing required inputs when running in a terminal, eliminating the need to remember all parameters upfront.

## How It Works

1. AWF checks which required inputs are missing (not provided via `--input`)
2. If stdin is a terminal (TTY): prompts interactively for each missing input
3. If non-terminal (pipes, scripts, CI/CD): returns error requiring `--input` flags
4. Once all required inputs are provided, workflow executes

## Terminal Detection

```bash
# Terminal: prompts for missing inputs
awf run deploy

# Piped: returns error
echo "" | awf run deploy
# Error: required input "env" not provided

# Script: must provide all inputs
awf run deploy --input env=prod --input version=1.2.3
```

## Required Inputs

### Basic Prompt

```yaml
inputs:
  - name: environment
    type: string
    required: true
    description: Target environment for deployment
```

```bash
$ awf run deploy

Enter value for 'environment' (string, required)
Description: Target environment for deployment
> prod
```

### Type Validation

AWF validates input types immediately:

**Integer:**
```bash
Enter value for 'count' (integer, required)
> abc
Error: invalid integer value "abc"

> 42
```

**Boolean:**
```bash
Enter value for 'dry_run' (boolean, required)
> yes
Error: invalid boolean (use: true, false, 1, 0, t, f)

> true
```

## Enum Inputs

### Numbered Selection

For inputs with enum constraints (up to 9 options), AWF displays numbered options:

```yaml
inputs:
  - name: environment
    type: string
    required: true
    validation:
      enum: [dev, staging, prod]
```

```bash
Enter value for 'environment' (string, required)
Options:
  1. dev
  2. staging
  3. prod
Select option (1-3): 2
```

### Invalid Selection

```bash
Select option (1-3): 5
Error: invalid selection "5" (valid: 1-3)

Select option (1-3): 2
```

### Large Enum Lists

For enums with >9 options, AWF shows valid values as list:

```bash
Enter value for 'option' (string, required)
Valid values: opt1, opt2, opt3, opt4, opt5, opt6, opt7, opt8, opt9, opt10
> opt5
```

## Optional Inputs

### Skipping

Press Enter without a value to skip optional inputs:

```yaml
inputs:
  - name: timeout
    type: integer
    required: false
```

```bash
Enter value for 'timeout' (integer, optional)
Press Enter to skip
>
```

### Default Values

Optional inputs with defaults show the default:

```yaml
inputs:
  - name: timeout
    type: integer
    default: 300
```

```bash
Enter value for 'timeout' (integer, optional, default: 300)
Press Enter to use default
>
Using default: 300
```

## Complete Example

```yaml
name: deploy
inputs:
  - name: env
    type: string
    required: true
    validation:
      enum: [dev, staging, prod]
  - name: version
    type: string
    required: true
  - name: dry_run
    type: boolean
    default: false
  - name: timeout
    type: integer
    default: 300
```

```bash
$ awf run deploy

env (string, required)
Options:
  1. dev
  2. staging
  3. prod
Select (1-3): 3

version (string, required)
> 1.2.3

dry_run (boolean, optional, default: false)
>
Using default: false

timeout (integer, optional, default: 300)
> 600

Workflow started...
```

## Configuration File Integration (v0.6.18)

Configuration files (`.awf/config.yaml`) pre-populate interactive inputs, reducing prompts:

### Pre-filled Inputs

```yaml
# .awf/config.yaml
inputs:
  env: "staging"
  timeout: 300
```

```yaml
# workflow with required inputs: env, version, timeout (optional)
inputs:
  - name: env
    type: string
    required: true
  - name: version
    type: string
    required: true
  - name: timeout
    type: integer
    default: 60
```

```bash
$ awf run deploy --interactive

# Only prompts for missing required input:
version (string, required)
> 1.2.3

# Uses: env=staging (config), timeout=300 (config override), version=1.2.3 (prompted)
```

Merge order: Config File → CLI Flags → Interactive Prompts (see [Configuration - Priority Order](configuration.md#priority-order))

### Complete Example

```yaml
# .awf/config.yaml
inputs:
  env: "staging"
  project: "my-app"
  timeout: 300
```

```bash
# Override config value via CLI, prompt for missing
$ awf run deploy --input env=production --interactive

project (string, required, from config: my-app)
Press Enter to use config value
>
Using config: my-app

version (string, required)
> 1.2.3

timeout (integer, optional, from config: 300)
Press Enter to use config value
> 600

# Final inputs: env=production (CLI), project=my-app (config), version=1.2.3 (prompt), timeout=600 (prompt override)
```

## When Not Available

Interactive input collection requires stdin connected to a terminal.

| Context | Behavior |
|---------|----------|
| Terminal session | Prompts for missing inputs |
| Piped input (`\|`) | Error: use `--input` flags |
| Script (`< file`) | Error: use `--input` flags |
| CI/CD pipeline | Error: use `--input` flags |
| All inputs provided | Executes immediately |

**Non-interactive workaround:**

```bash
awf run deploy --input env=prod --input version=1.2.3
```
