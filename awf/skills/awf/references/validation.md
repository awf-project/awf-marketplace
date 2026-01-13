# Validation

## Template Casing Validation

**Added in v0.5.12**

AWF validates that state property references use uppercase names. This catches a common mistake where lowercase properties (`.output`, `.exit_code`) would silently fail with Go templates.

### Valid Properties

| Property | Description |
|----------|-------------|
| `.Output` | Command stdout |
| `.Stderr` | Command stderr |
| `.ExitCode` | Exit code |
| `.Status` | State status |

### Validation Example

```bash
$ awf validate my-workflow
```

```
validation error: invalid state property casing
  - line 15: "states.build.output" should be "states.build.Output"
  - line 22: "states.test.exit_code" should be "states.test.ExitCode"
```

### Migration

Update all workflow files to use uppercase:

```yaml
# Before (invalid)
command: echo "{{.states.build.output}}"
when: "states.test.exit_code == 0"

# After (valid)
command: echo "{{.states.build.Output}}"
when: "states.test.ExitCode == 0"
```

## Expression Context Normalization

**Added in v0.5.20**

Expression evaluator now normalizes context namespaces to PascalCase:

| Namespace | Example Properties |
|-----------|-------------------|
| `Context` | `Context.RetryCount`, `Context.WorkflowID` |
| `Error` | `Error.Message`, `Error.Code` |
| `Loop` | `Loop.Index`, `Loop.First`, `Loop.Item` |

Lowercase references are automatically converted for backward compatibility:

```yaml
# These are equivalent (lowercase auto-normalized)
when: "context.retryCount > 0"    # Normalized to Context.RetryCount
when: "Context.RetryCount > 0"    # Preferred PascalCase
```

---

# Input Validation

## Input Definition

```yaml
inputs:
  - name: email
    type: string
    required: true
    validation:
      pattern: "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$"
```

## Supported Types

| Type | Example |
|------|---------|
| `string` | `"hello"` |
| `integer` | `42` |
| `boolean` | `true` |

## Validation Rules

### Pattern (regex)

```yaml
validation:
  pattern: "^v[0-9]+\\.[0-9]+\\.[0-9]+$"
```

### Enum (allowed values)

```yaml
validation:
  enum: [dev, staging, prod]
```

### Min/Max (numeric range)

```yaml
validation:
  min: 1
  max: 100
```

### File Exists

```yaml
validation:
  file_exists: true
```

### File Extension

```yaml
validation:
  file_extension: [".yaml", ".yml", ".json"]
```

## Combining Rules

```yaml
inputs:
  - name: config
    type: string
    required: true
    validation:
      file_exists: true
      file_extension: [".yaml", ".yml"]
```

## Error Handling

Validation errors are collected (non-fail-fast):

```bash
awf run deploy --input email=invalid --input count=999
```

```
input validation failed: 2 errors:
  - inputs.email: does not match pattern
  - inputs.count: value 999 exceeds maximum 100
```

Returns exit code 1 (User Error).

## JSON Error Output

```bash
awf run deploy --input email=invalid -f json
```

```json
{
  "success": false,
  "error": {
    "code": 1,
    "type": "validation_error",
    "details": {
      "errors": [
        {"input": "email", "rule": "pattern", "message": "does not match pattern"}
      ]
    }
  }
}
```

## Complete Example

```yaml
name: deploy
version: "1.0.0"

inputs:
  - name: env
    type: string
    required: true
    validation:
      enum: [dev, staging, prod]
  - name: version
    type: string
    required: true
    validation:
      pattern: "^v[0-9]+\\.[0-9]+\\.[0-9]+$"
  - name: config_file
    type: string
    required: true
    validation:
      file_exists: true
      file_extension: [".yaml", ".yml"]
  - name: replicas
    type: integer
    default: 2
    validation:
      min: 1
      max: 10
  - name: dry_run
    type: boolean
    default: false
```

## Best Practices

1. **Validate file inputs** - Use `file_exists`
2. **Use enums for fixed choices** - Prevents typos
3. **Set sensible defaults** - Reduce required inputs
4. **Combine rules** - Comprehensive validation
