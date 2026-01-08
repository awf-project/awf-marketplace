# Variable Interpolation

Go template syntax: `{{.var}}`

## Variable Categories

### Inputs

```yaml
command: echo "{{.inputs.file_path}}"
```

### State Outputs

```yaml
command: echo "{{.states.read_file.output}}"
command: echo "Exit: {{.states.step1.exit_code}}"
```

### Agent State Outputs

For `type: agent` steps, additional fields are available:

```yaml
# Raw text response
command: echo "{{.states.analyze.output}}"

# Parsed JSON response (if valid JSON returned)
command: echo "Issues: {{.states.analyze.response.issues}}"

# Token usage metadata
command: echo "Tokens: {{.states.analyze.tokens.total}}"
```

### Conversation State Outputs

For agent steps with `mode: conversation`, additional conversation state is available:

```yaml
# Total turns in conversation
command: echo "Turns: {{.states.review.conversation.total_turns}}"

# Total tokens used across all turns
command: echo "Tokens: {{.states.review.conversation.total_tokens}}"

# Exit reason: "condition", "max_turns", or "max_tokens"
command: echo "Stopped by: {{.states.review.conversation.stopped_by}}"
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
