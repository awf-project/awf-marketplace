# Variable Interpolation

Go template syntax: `{{.var}}`

## Variable Categories

### Inputs

```yaml
command: echo "{{.inputs.file_path}}"
```

### State Outputs

State property names must be uppercase (Go template convention):

```yaml
command: echo "{{.states.read_file.Output}}"
command: echo "Exit: {{.states.step1.ExitCode}}"
command: echo "Error: {{.states.step1.Stderr}}"
command: echo "Status: {{.states.step1.Status}}"
```

> **Breaking Change (v0.5.12)**: Lowercase properties (`.output`, `.exit_code`) were never functional. Use `awf validate` to detect casing issues.

### Agent State Outputs

For `type: agent` steps, additional fields are available:

```yaml
# Raw text response
command: echo "{{.states.analyze.Output}}"

# Parsed JSON response (if valid JSON returned)
command: echo "Issues: {{.states.analyze.Response.issues}}"

# Token usage metadata
command: echo "Tokens: {{.states.analyze.Tokens.total}}"
```

### Conversation State Outputs

For agent steps with `mode: conversation`, conversation state uses Go-style field names:

```yaml
# Final response output
command: echo "{{.states.review.Output}}"

# Total turns in conversation
command: echo "Turns: {{.states.review.Conversation.TotalTurns}}"

# Total tokens used across all turns
command: echo "Tokens: {{.states.review.TokensUsed}}"

# Exit reason: "condition", "max_turns", or "max_tokens"
command: echo "Stopped by: {{.states.review.Conversation.StoppedBy}}"
```

See [Conversation Mode](conversation-steps.md) for details.

### Workflow Metadata

```yaml
command: echo "{{.workflow.id}} {{.workflow.name}}"
```

### Environment Variables

```yaml
command: echo "{{.env.HOME}}"
```

### Loop Context

```yaml
{{.loop.item}}      # Current item
{{.loop.index}}     # 0-based index
{{.loop.index1}}    # 1-based index
{{.loop.first}}     # True on first iteration
{{.loop.last}}      # True on last iteration
{{.loop.length}}    # Total items
{{.loop.parent}}    # Parent loop context (nested)
```

### Loop Item JSON Serialization

When `{{.loop.item}}` contains complex types (objects, arrays), it is automatically serialized to JSON:

- **Objects** → JSON object: `{"name":"value","nested":{"key":"data"}}`
- **Arrays** → JSON array: `[1,2,3]` or `["a","b","c"]`
- **Primitives** → Pass through unchanged: strings, numbers, booleans

This is useful when passing loop items to `call_workflow`:

```yaml
# Parent workflow with objects
process_reviews:
  type: step
  command: |
    echo '[{"file":"main.go","type":"fix"},{"file":"test.go","type":"chore"}]'
  capture:
    stdout: reviews_json
  on_success: loop_reviews

loop_reviews:
  type: for_each
  items: "{{.states.process_reviews.Output}}"
  body:
    - call_child_workflow

call_child_workflow:
  type: call_workflow
  workflow: review-file
  inputs:
    review: "{{.loop.item}}"  # Passed as valid JSON object to child

# Child workflow receives: {"file":"main.go","type":"fix"}
```

**Note**: Primitive values remain unchanged. `{{.loop.item}}` with `"main.go"` stays as `main.go`.

### Nested Loop Example

```yaml
command: echo "outer={{.loop.parent.item}} inner={{.loop.item}}"
```

## Arithmetic Expressions

Loop bounds (`max_iterations`, `while`, `until`) support arithmetic:

```yaml
# Variable interpolation
max_iterations: "{{.inputs.pages}}"

# Environment variable
max_iterations: "{{.env.MAX_RETRIES}}"

# Arithmetic expressions
max_iterations: "{{.inputs.pages * .inputs.retries_per_page}}"
max_iterations: "{{.inputs.count + 10}}"
```

**Operators:** `+`, `-`, `*`, `/`, `%`

Values resolved at loop initialization. `awf validate` warns about undefined variables.

## Interpolation Contexts

| Context | Example |
|---------|---------|
| Commands | `command: "{{.inputs.msg}}"` |
| Directory | `dir: "{{.inputs.project_path}}"` |
| Timeout | `timeout: "{{.inputs.timeout}}"` |
| Conditions | `when: "inputs.mode == 'full'"` |
| Loop items | `items: "{{.inputs.files}}"` |

**Note:** In `when` expressions, use variable names without `{{}}`.

## Expression Context (PascalCase)

In `when` expressions and `break_when` conditions, namespace properties use PascalCase:

```yaml
# State properties
when: "states.step.ExitCode == 0"
when: "states.build.Output contains 'success'"

# Context namespace (v0.5.20+)
when: "Context.RetryCount > 0"
when: "Context.WorkflowID != ''"

# Error namespace (v0.5.20+)
when: "Error.Message contains 'timeout'"
when: "Error.Code == 'VALIDATION_FAILED'"

# Loop namespace
break_when: "Loop.Index >= 10"
when: "Loop.First"
```

**Backward Compatibility:** Lowercase properties (e.g., `context.retryCount`, `error.message`) are automatically normalized to PascalCase. New workflows should use PascalCase directly.

> **Change (v0.5.20)**: Expression evaluator now normalizes context to PascalCase for consistent property access. Lowercase references continue to work but emit deprecation warnings.

### Expression Namespace Accessors (v0.5.31)

For more intuitive template syntax, namespace accessors provide lowercase aliases:

```yaml
# Loop namespace accessor
command: echo "Index: {{loop.index}}, Item: {{loop.item}}"
break_when: "loop.index >= 10"

# Context namespace accessor
when: "context.retry_count > 0"
when: "context.working_dir != ''"

# Error namespace accessor
when: "error.message contains 'timeout'"
when: "error.code == 'VALIDATION_FAILED'"
```

These accessors are syntactic sugar over the PascalCase properties, automatically mapping:
- `{{loop.*}}` → `{{.loop.*}}`
- `{{context.*}}` → `{{Context.*}}`
- `{{error.*}}` → `{{Error.*}}`

Both syntaxes are valid. Use whichever style is more readable for your workflow.

## Security

### Secret Masking

Variables with these prefixes are masked in logs:
- `SECRET_`
- `API_KEY`
- `PASSWORD`
- `TOKEN`

### Shell Escaping

```go
import "github.com/vanoix/awf/pkg/interpolation"
escaped := interpolation.ShellEscape(userInput)
```

## Template Functions

### Shell Escape

```yaml
command: echo "{{escape .inputs.user_input}}"
```

Escapes shell metacharacters to prevent injection.

### JSON Serialization

```yaml
command: echo '{{json .inputs.data}}'
```

Explicitly serialize any value to JSON. Useful when you need JSON output for non-loop variables or want explicit control over serialization.

## Template Parameters

In templates, use `{{parameters.name}}`:

```yaml
command: "{{parameters.model}} -c '{{parameters.prompt}}'"
```

## Common Patterns

### Multi-line Commands

```yaml
command: |
  echo "Processing {{.inputs.file}}"
  process-file "{{.inputs.file}}"
```

### JSON in Commands

```yaml
command: |
  curl -X POST -d '{"file": "{{.inputs.file}}"}' https://api.example.com
```

## Debugging

```bash
awf run my-workflow --dry-run --input file=test.txt
```

Shows interpolated commands without execution.
