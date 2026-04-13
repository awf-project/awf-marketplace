# Validation

## Model Validation

AWF validates model identifiers for Gemini and Codex providers at workflow validation time, before execution.

### Gemini Model Rules

| Rule | Pattern | Examples |
|------|---------|---------|
| Required prefix | `gemini-` | `gemini-2.0-flash`, `gemini-pro`, `gemini-1.5-pro` |
| Rejected | anything else | `gpt-4`, `flash`, `claude-sonnet` |

```bash
$ awf validate workflow.yaml
validation error: invalid Gemini model "flash": must start with "gemini-"
```

### Codex Model Rules

| Pattern | Examples |
|---------|---------|
| `gpt-` prefix | `gpt-4o`, `gpt-4o-mini` |
| `codex-` prefix | `codex-mini` |
| o-series (`o` + digit) | `o3`, `o1`, `o1-mini` |

Legacy names (e.g., `code-davinci`) are rejected:

```bash
$ awf validate workflow.yaml
validation error: invalid Codex model "code-davinci": use gpt-*, codex-*, or o-series (e.g. o3, o1-mini)
```

> Claude model validation is handled by the Claude CLI. AWF does not validate Claude model names.

For provider configuration, see [Agent Steps - Model Validation](agent-steps.md#model-validation).

---

## Template Casing Validation

**Added in v0.5.12**

AWF validates that state property references use uppercase names. This catches a common mistake where lowercase properties (`.output`, `.exit_code`) would silently fail with Go templates.

### Valid Properties

| Property | Description |
|----------|-------------|
| `.Output` | Command stdout (or cleaned text if `output_format` is set) |
| `.Stderr` | Command stderr |
| `.ExitCode` | Exit code |
| `.Status` | State status |
| `.Response` | Parsed JSON response (automatic heuristic) |
| `.JSON` | Parsed JSON from `output_format: json` (explicit) |
| `.TokensUsed` | Token usage metadata |

### Validation Example

```bash
$ awf validate my-workflow
```

```
validation error: invalid state property casing
  - line 15: "states.build.output" should be "states.build.Output"
  - line 22: "states.test.exit_code" should be "states.test.ExitCode"
  - line 30: "states.analyze.json" should be "states.analyze.JSON"
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

## Expression Syntax Validation

**Added in v0.5.33**

AWF validates expression syntax at workflow load time. This catches malformed expressions before execution, providing immediate feedback during `awf validate` or workflow loading.

### Validated Expressions

| Location | Example |
|----------|---------|
| Transition `when` | `when: "states.build.ExitCode == 0"` |
| Conversation `stop_condition` | `stop_condition: "inputs.response contains 'DONE'"` |
| While loop `condition` | `condition: "loop.index < 10"` |

### Validation Example

```bash
$ awf validate my-workflow
```

```
validation error: invalid expression syntax
  - states.check.transitions[0].when: unexpected token "=="
  - states.review.conversation.stop_condition: undefined function "conatins"
```

### Architecture Note

Expression validation uses the `ExpressionValidator` port (v0.5.33), which isolates the expr-lang dependency to the infrastructure layer. This maintains domain purity - the domain layer defines only a function type for validation injection. See [Architecture](architecture.md) for details.

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

### URL (v0.5.38)

```yaml
validation:
  url: true
```

Validates that the input is a properly formatted URL.

### Email (v0.5.38)

```yaml
validation:
  email: true
```

Validates that the input is a properly formatted email address.

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
