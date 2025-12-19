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
