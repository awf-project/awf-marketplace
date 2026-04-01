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
{{.states.step_name.Output}}            # Command output (raw text, or cleaned if output_format set)
{{.states.step_name.ExitCode}}          # Exit code (integer, POSIX 0-255)
{{.states.step_name.TokensUsed}}        # Tokens consumed by agent steps
{{.states.step_name.Response.field}}    # Parsed field from operation/agent structured output (heuristic)
{{.states.step_name.JSON.field}}        # Parsed field from output_format: json (explicit)
```

> **Breaking Change (v0.5.12)**: Lowercase properties (`.output`, `.exit_code`) were never functional. Use `awf validate` to detect casing issues.

### ExitCode in Transitions and Templates

The exit code from the step's command execution. Use in transitions, expressions, and templates.

**In transitions (numeric comparison):**
```yaml
transitions:
  - when: "states.test_run.ExitCode == 0"
    goto: success
  - when: "states.test_run.ExitCode != 0"
    goto: failure
```

**In templates (as string):**
```yaml
report_failure:
  type: step
  command: |
    echo "Test failed with exit code: {{.states.test_run.ExitCode}}"
```

**Numeric range expressions:**
```yaml
transitions:
  - when: "states.build.ExitCode >= 100 and states.build.ExitCode < 128"
    goto: handle_user_error
  - when: "states.build.ExitCode >= 128"
    goto: handle_signal
```

On POSIX systems, exit codes are typically 0-255. Exit code 0 indicates success; non-zero indicates failure.

**Transition priority:** Transitions are evaluated on both success and failure paths. When a matching transition is found, it takes priority over `on_success`, `on_failure`, and `continue_on_error`. If no transition matches, the legacy routing applies as fallback.

### Agent State Outputs

For `type: agent` steps, additional fields are available:

```yaml
# Raw text response (or cleaned text if output_format is set)
command: echo "{{.states.analyze.Output}}"

# Parsed JSON response - automatic heuristic (if valid JSON returned)
command: echo "Issues: {{.states.analyze.Response.issues}}"

# Parsed JSON from output_format: json - explicit
command: echo "Severity: {{.states.analyze.JSON.severity}}"

# Token usage metadata
command: echo "Tokens: {{.states.analyze.TokensUsed}}"
```

> **Note**: `TokensUsed` replaced deprecated `Tokens` field. Update workflows from `{{.states.step.Tokens}}` to `{{.states.step.TokensUsed}}`.

### JSON (Explicit Output Formatting)

When an agent step uses `output_format: json`, the parsed JSON is accessible via `JSON`:

```yaml
{{.states.step_name.JSON.field}}         # Access a JSON object field
{{.states.step_name.JSON}}               # Full parsed JSON object
```

**Key differences from `Response`:**
- `JSON` is only populated when `output_format: json` is explicitly set on the agent step
- `Response` is populated automatically for all agent outputs if valid JSON is detected (heuristic)
- `JSON` represents explicitly formatted output; `Response` is automatic best-effort parsing

Example:

```yaml
states:
  initial: analyze

  analyze:
    type: agent
    provider: claude
    prompt: "Return JSON analysis with 'issues' and 'severity' fields"
    output_format: json
    on_success: process

  process:
    type: step
    command: |
      echo "Severity: {{.states.analyze.JSON.severity}}"
      echo "Issues: {{.states.analyze.JSON.issues}}"
    on_success: done

  done:
    type: terminal
```

See [Agent Steps - Output Formatting](agent-steps.md#output-formatting) for detailed examples.

### Operation State Outputs

For `type: operation` steps (e.g., GitHub operations), outputs are structured:

```yaml
# Raw JSON response
command: echo "{{.states.get_issue.Output}}"

# Parsed field from operation result
command: echo "Title: {{.states.get_issue.Response.title}}"
command: echo "Labels: {{.states.get_issue.Response.labels}}"
```

Use `Output` for raw JSON, `Response.field` for individual parsed fields.

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

### Terminal Message Interpolation

Inline `on_failure` error terminals support `message` template interpolation at runtime. The `message` field has access to the full interpolation context:

```yaml
deploy:
  type: step
  command: ./deploy.sh
  on_success: done
  on_failure: {message: "Deploy failed (exit {{.states.deploy.ExitCode}}): {{.states.deploy.Output}}", status: 2}
```

Available in `message` templates: `{{.inputs.*}}`, `{{.states.*}}`, `{{.env.*}}`, `{{.awf.*}}`.

See [Workflow Syntax - Inline Error Shorthand](workflow-syntax.md#inline-error-shorthand) for full syntax.

### Workflow Metadata

```yaml
command: echo "{{.workflow.id}} {{.workflow.name}}"
```

### Environment Variables

```yaml
command: echo "{{.env.HOME}}"
```

### AWF Directory Context

Access system directories configured per XDG standards:

```yaml
{{.awf.config_dir}}      # ~/.config/awf (or $XDG_CONFIG_HOME/awf)
{{.awf.data_dir}}        # ~/.local/share/awf (or $XDG_DATA_HOME/awf)
{{.awf.cache_dir}}       # ~/.cache/awf (or $XDG_CACHE_HOME/awf)
{{.awf.prompts_dir}}     # Designated prompts directory within config_dir
{{.awf.scripts_dir}}     # Designated scripts directory within config_dir
{{.awf.workflows_dir}}   # Designated workflows directory within config_dir
{{.awf.plugins_dir}}     # Plugin installation directory
```

Examples:
```yaml
analyze:
  type: agent
  provider: claude
  prompt_file: "{{.awf.prompts_dir}}/code_review.md"
  on_success: done

deploy:
  type: step
  script_file: "{{.awf.scripts_dir}}/deploy.sh"
  on_success: done
```

#### Local-Before-Global Resolution

When using `{{.awf.prompts_dir}}` or `{{.awf.scripts_dir}}`, AWF implements **local-before-global resolution**. This enables per-project overrides of shared global files:

1. **Local override preferred** — If a file exists in the workflow's local directory (`<workflow_dir>/prompts/` or `<workflow_dir>/scripts/`), it is used
2. **Global fallback** — If no local file exists, the global XDG directory is used
3. **Example**: `script_file: "{{.awf.scripts_dir}}/deploy.sh"` checks for:
   - `<workflow_dir>/scripts/deploy.sh` (local override)
   - Then `~/.config/awf/scripts/deploy.sh` (global fallback)

**Applies to all field types:** Local-before-global resolution works in `command:`, `dir:`, `script_file:`, and `prompt_file:` fields. Any occurrence of `{{.awf.scripts_dir}}` or `{{.awf.prompts_dir}}` in these fields resolves local paths first.

```yaml
# command: field — local-before-global resolution applies
deploy:
  type: step
  command: "{{.awf.scripts_dir}}/deploy.sh --env {{.inputs.env}}"
  on_success: done

# dir: field — local-before-global resolution applies
build:
  type: step
  command: make build
  dir: "{{.awf.scripts_dir}}/build"
  on_success: done
```

This applies only to `prompts_dir` and `scripts_dir`. Other AWF directory variables (`config_dir`, `data_dir`, etc.) resolve directly to their XDG paths.

#### 3-Tier Resolution Inside Pack Workflows

When a workflow is executed via `awf run <pack>/<workflow>`, the resolution for `{{.awf.prompts_dir}}` and `{{.awf.scripts_dir}}` extends to **3 tiers**:

1. **User override** — `.awf/prompts/<pack-name>/` in the current project directory (highest priority)
2. **Pack embedded** — the pack's own `prompts/` directory (installed with the pack)
3. **Global XDG** — `$XDG_CONFIG_HOME/awf/prompts/` (lowest priority fallback)

No new template variables are introduced — `{{.awf.prompts_dir}}` and `{{.awf.scripts_dir}}` automatically use 3-tier resolution when a pack name is in context.

```
.awf/
└── prompts/
    └── speckit/               # User override directory for "speckit" pack
        └── specify.md         # Overrides pack-embedded prompts/specify.md
```

**Example**: A pack workflow using `prompt_file: "{{.awf.prompts_dir}}/specify.md"` resolves:
1. `.awf/prompts/speckit/specify.md` (user override, project-level)
2. `~/.local/share/awf/workflow-packs/speckit/prompts/specify.md` (pack embedded)
3. `~/.config/awf/prompts/specify.md` (global fallback)

### Loop Context (PascalCase)

```yaml
{{.loop.Item}}      # Current item
{{.loop.Index}}     # 0-based index
{{.loop.Index1}}    # 1-based index
{{.loop.First}}     # True on first iteration
{{.loop.Last}}      # True on last iteration
{{.loop.Length}}     # Total items
{{.loop.Parent}}    # Parent loop context (nested, recursive chain)
```

### Loop Item JSON Serialization

When `{{.loop.Item}}` contains complex types (objects, arrays), it is automatically serialized to JSON:

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
    review: "{{.loop.Item}}"  # Passed as valid JSON object to child

# Child workflow receives: {"file":"main.go","type":"fix"}
```

**Note**: Primitive values remain unchanged. `{{.loop.Item}}` with `"main.go"` stays as `main.go`.

### Nested Loop Example

```yaml
command: echo "outer={{.loop.Parent.Item}} inner={{.loop.Item}}"
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

## Template Helper Functions

Available in template interpolation (prompts, prompt files, commands):

### `split`

Split a string into an array by delimiter:

```yaml
{{split "apple,banana,orange" ","}}
```

Use with `range` to iterate:
```markdown
{{range split .states.select.Output ","}}
- {{trimSpace .}}
{{end}}
```

### `join`

Join an array into a string with separator:

```yaml
{{join (split .states.agents.Output ",") " | "}}
```

### `readFile`

Read and inline file contents (1MB size limit):

```markdown
## Specification

{{readFile .states.spec_path.Output}}
```

File path is relative to the workflow directory. Fails if file doesn't exist, exceeds 1MB, or is not readable.

### `trimSpace`

Remove leading and trailing whitespace:

```yaml
Result: {{trimSpace .states.process.Output}}
```

### Example: Combined Usage

```markdown
# Analysis Report

## Available Agents
{{range split .states.list_agents.Output ","}}
- {{trimSpace .}}
{{end}}

## Research Summary
{{readFile .states.research_summary_path.Output}}

## Status
{{trimSpace .states.final_status.Output}}
```

## Security

### Secret Masking

Variables with these prefixes are masked in logs:
- `SECRET_`
- `API_KEY`
- `PASSWORD`
- `TOKEN`

### Shell Escaping

```go
import "github.com/awf-project/cli/pkg/interpolation"
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
