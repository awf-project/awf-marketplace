# Workflow Templates

Reusable step patterns with parameters. Define once, use everywhere.

## Template Definition

```yaml
# .awf/templates/ai-analyze.yaml
name: ai-analyze
parameters:
  - name: prompt
    required: true
  - name: model
    default: claude
  - name: timeout
    default: 120
states:
  ai-analyze:
    type: step
    command: "{{parameters.model}} -c '{{parameters.prompt}}'"
    timeout: "{{parameters.timeout}}"
```

| Option | Description |
|--------|-------------|
| `name` | Parameter identifier |
| `required` | Must be provided |
| `default` | Default value |

## Template Usage

```yaml
code_analysis:
  use_template: ai-analyze
  parameters:
    prompt: "Analyze: {{.states.extract.Output}}"
    model: gemini
  on_success: format
  on_failure: error
```

## Parameter Interpolation

Template parameters use `{{parameters.name}}`:

```yaml
command: "{{parameters.model}} -c '{{parameters.prompt}}'"
```

Parameters are resolved at load time, not runtime.

## Template Discovery

1. `.awf/templates/` (local project)
2. `$AWF_STORAGE/templates/` (global)

Local templates override global with same name.

## Validation

```bash
awf validate my-workflow
```

Errors detected:
- Missing required parameters
- Circular template references
- Template not found

## Complete Example

```yaml
# .awf/templates/http-request.yaml
name: http-request
parameters:
  - name: url
    required: true
  - name: method
    default: GET
  - name: timeout
    default: 30
states:
  http-request:
    type: step
    command: |
      curl -s -X {{parameters.method}} \
        --max-time {{parameters.timeout}} \
        "{{parameters.url}}"
```

```yaml
# Workflow using template
health_check:
  use_template: http-request
  parameters:
    url: "{{.inputs.api_url}}/health"
    timeout: 10
  on_success: fetch_data
```

## Best Practices

1. **Single responsibility** - One template, one purpose
2. **Sensible defaults** - Common cases should be easy
3. **Document parameters** - Add comments
4. **Validate early** - Run `awf validate` after changes
