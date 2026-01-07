# Workflow Syntax Reference

## Basic Structure

```yaml
name: my-workflow
version: "1.0.0"
description: Workflow description

inputs:
  - name: file_path
    type: string
    required: true

states:
  initial: step1

  step1:
    type: step
    command: echo "Hello"
    on_success: done
    on_failure: error

  done:
    type: terminal
    status: success

  error:
    type: terminal
    status: failure
```

## State Types

| Type | Description |
|------|-------------|
| `step` | Execute a command |
| `agent` | Invoke AI agent (Claude, Codex, Gemini, OpenCode) |
| `terminal` | End with success/failure |
| `parallel` | Run steps concurrently |
| `for_each` | Iterate over list |
| `while` | Repeat until false |
| `operation` | Invoke plugin operation |
| `call_workflow` | Execute sub-workflow |

## Step State

```yaml
my_step:
  type: step
  command: |
    echo "Processing {{.inputs.file}}"
  dir: /tmp/workdir
  timeout: 30
  on_success: next_step
  on_failure: error
  continue_on_error: false
  retry:
    max_attempts: 3
    backoff: exponential
```

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `command` | string | - | Shell command |
| `dir` | string | cwd | Working directory |
| `timeout` | int | 0 | Timeout in seconds |
| `on_success` | string | - | Next state on success |
| `on_failure` | string | - | Next state on failure |
| `continue_on_error` | bool | false | Always follow on_success |

## Parallel State

```yaml
parallel_build:
  type: parallel
  strategy: all_succeed
  max_concurrent: 3
  steps:
    - name: lint
      command: golangci-lint run
    - name: test
      command: go test ./...
  on_success: deploy
  on_failure: error
```

**Strategies:**
- `all_succeed` - All must succeed, cancel on first failure
- `any_succeed` - Succeed if at least one succeeds
- `best_effort` - Collect all results, never cancel

## For-Each Loop

```yaml
process_files:
  type: for_each
  items: '["a.txt", "b.txt", "c.txt"]'
  max_iterations: 100
  break_when: "states.process.exit_code != 0"
  body:
    - process
  on_complete: aggregate
```

**Loop Context Variables:**

| Variable | Description |
|----------|-------------|
| `{{.loop.Item}}` | Current item |
| `{{.loop.Index}}` | 0-based index |
| `{{.loop.Index1}}` | 1-based index |
| `{{.loop.First}}` | True on first |
| `{{.loop.Last}}` | True on last |
| `{{.loop.Length}}` | Total count |
| `{{.loop.Parent}}` | Parent loop (nested) |

## While Loop

```yaml
poll_status:
  type: while
  while: "states.check.output != 'ready'"
  max_iterations: 60
  body:
    - check
    - wait
  on_complete: proceed
```

### Dynamic Loop Bounds

Loop bounds support variable interpolation and arithmetic:

```yaml
process_pages:
  type: for_each
  items: "{{.inputs.files}}"
  max_iterations: "{{.inputs.pages * .inputs.retries_per_page}}"
  body:
    - process
  on_complete: done
```

**Operators:** `+`, `-`, `*`, `/`, `%`

```yaml
# Environment variable
max_iterations: "{{.env.MAX_RETRIES}}"

# Arithmetic expression
max_iterations: "{{.inputs.count + 10}}"
```

## Operation State

Invoke plugin-provided operations:

```yaml
notify:
  type: operation
  operation: slack.send_message    # plugin.operation_name
  inputs:
    channel: "#deployments"
    message: "Deploy: {{.states.deploy.output}}"
  on_success: done
  on_failure: error
```

| Option | Type | Description |
|--------|------|-------------|
| `operation` | string | `plugin_name.operation_name` |
| `inputs` | map | Parameters for the operation |
| `on_success` | string | Next state on success |
| `on_failure` | string | Next state on failure |

## Call Workflow State

Execute sub-workflows with input/output mapping:

```yaml
run_tests:
  type: call_workflow
  workflow: test-suite
  inputs:
    project: "{{.inputs.project}}"
    coverage: true
  outputs:
    test_results: result
    coverage_pct: coverage
  on_success: deploy
  on_failure: error
```

| Option | Type | Description |
|--------|------|-------------|
| `workflow` | string | Sub-workflow name |
| `inputs` | map | Input mapping (parent → child) |
| `outputs` | map | Output mapping (child → parent) |
| `on_success` | string | Next state on success |
| `on_failure` | string | Next state on failure |

**Safety:** Circular call detection prevents infinite recursion.

### Using Call Workflow in Loops

Combine `for_each` with `call_workflow` to process multiple items. Loop items (especially complex objects) are automatically serialized to JSON:

```yaml
prepare_items:
  type: step
  command: |
    echo '[
      {"file":"main.go","language":"Go"},
      {"file":"app.py","language":"Python"},
      {"file":"index.js","language":"JavaScript"}
    ]'
  capture:
    stdout: items_json
  on_success: process_files

process_files:
  type: for_each
  items: "{{.states.prepare_items.output}}"
  body:
    - analyze_file

analyze_file:
  type: call_workflow
  workflow: analyze-source-file
  inputs:
    # {{.loop.item}} is automatically JSON-serialized for complex types
    file_info: "{{.loop.item}}"
  outputs:
    analysis: file_analysis
  on_success: next

next:
  type: terminal
```

Child workflow receives properly formatted JSON input:

```yaml
name: analyze-source-file

inputs:
  - name: file_info
    type: string  # Receives JSON string

states:
  initial: parse
  parse:
    type: step
    command: |
      # Parse JSON input safely
      echo '{{.inputs.file_info}}' | jq -r '.file'
    on_success: done
  done:
    type: terminal

outputs:
  - name: file_analysis
    from: states.parse.output
```

## Agent State

Invoke AI agents (Claude, Codex, Gemini, OpenCode) with prompt templates.

### Basic Agent Step

```yaml
analyze:
  type: agent
  provider: claude
  prompt: |
    Analyze this code for issues:
    {{.inputs.code}}
  options:
    model: claude-sonnet-4-20250514
    max_tokens: 2048
  timeout: 120
  on_success: review
  on_failure: error
```

### Conversation Mode

Enable multi-turn conversations with automatic context management:

```yaml
refine_code:
  type: agent
  provider: claude
  mode: conversation
  system_prompt: |
    You are a code reviewer. Iterate until code is approved.
    Say "APPROVED" when done.
  initial_prompt: |
    Review this code:
    {{.inputs.code}}
  options:
    model: claude-sonnet-4-20250514
    max_tokens: 4096
  conversation:
    max_turns: 10
    max_context_tokens: 100000
    strategy: sliding_window
    stop_condition: "response contains 'APPROVED'"
  on_success: deploy
  on_failure: error
```

### Agent Options

| Option | Type | Required | Description |
|--------|------|----------|-------------|
| `provider` | string | Yes | `claude`, `codex`, `gemini`, `opencode`, `custom` |
| `mode` | string | No | Set to `conversation` for multi-turn mode |
| `prompt` | string | Yes* | Prompt template (supports interpolation) |
| `system_prompt` | string | No | System message (for conversation mode, preserved across turns) |
| `initial_prompt` | string | No* | First user message (for conversation mode) |
| `conversation` | object | No | Conversation configuration (required if mode=conversation) |
| `options` | map | No | Provider options (model, temperature, max_tokens) |
| `timeout` | int | No | Timeout in seconds |
| `on_success` | string | No | Next state on success |
| `on_failure` | string | No | Next state on failure |

\* Use `prompt` for single-turn mode, `initial_prompt` for conversation mode.

### Conversation Configuration

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `max_turns` | int | 10 | Maximum conversation turns |
| `max_context_tokens` | int | model limit | Token budget for conversation |
| `strategy` | string | `sliding_window` | Context window strategy |
| `stop_condition` | string | - | Expression to exit early |

### Agent Output

| Field | Type | Description |
|-------|------|-------------|
| `{{.states.step.Output}}` | string | Raw response text |
| `{{.states.step.Response}}` | object | Parsed JSON (if valid) |
| `{{.states.step.Tokens}}` | object | Token usage metadata |
| `{{.states.step.conversation}}` | object | Conversation state (if mode=conversation) |

### Custom Provider

```yaml
my_ai:
  type: agent
  provider: custom
  command: "my-ai-tool --prompt={{prompt}} --json"
  prompt: "Analyze: {{.inputs.data}}"
  on_success: next
```

**Details:** [Agent Steps Reference](agent-steps.md) | [Conversation Mode](conversation-steps.md)

## Retry Configuration

```yaml
retry:
  max_attempts: 5
  initial_delay: 1s
  max_delay: 30s
  backoff: exponential
  multiplier: 2
  jitter: 0.1
  retryable_exit_codes: [1, 22]
```

**Backoff Strategies:**
- `constant` - Always initial_delay
- `linear` - initial_delay * attempt
- `exponential` - initial_delay * multiplier^(attempt-1)

## Conditional Transitions

```yaml
process:
  type: step
  command: analyze.sh
  transitions:
    - when: "states.process.exit_code == 0 and inputs.mode == 'full'"
      goto: full_report
    - when: "states.process.exit_code == 0"
      goto: summary_report
    - goto: error  # default
```

**Operators:** `==`, `!=`, `<`, `>`, `<=`, `>=`, `and`, `or`, `not`

## Input Definitions

```yaml
inputs:
  - name: file_path
    type: string
    required: true
    validation:
      file_exists: true
      file_extension: [".go", ".py"]

  - name: count
    type: integer
    default: 10
    validation:
      min: 1
      max: 100

  - name: env
    type: string
    validation:
      enum: [dev, staging, prod]

  - name: debug
    type: boolean
    default: false
```

**Validation Rules:**
- `pattern` - Regex match
- `enum` - Allowed values (interactive mode shows numbered selection for <=9 options)
- `min`/`max` - Integer bounds
- `file_exists` - Must exist
- `file_extension` - Allowed extensions

**Interactive Input Collection:**

When required inputs are missing in terminal, AWF prompts automatically. Enum inputs show numbered options:

```bash
$ awf run deploy
env (string, required)
Options:
  1. dev
  2. staging
  3. prod
Select (1-3): 2
```

See [Interactive Inputs](interactive-inputs.md) for details.

## Variable Interpolation

```yaml
# Inputs
command: echo "{{.inputs.variable_name}}"

# Previous outputs
command: echo "{{.states.step_name.Output}}"

# Workflow metadata
command: echo "ID: {{.workflow.id}}"

# Environment
command: echo "{{.env.HOME}}"

# Loop context
command: echo "{{.loop.Item}} ({{.loop.Index1}}/{{.loop.Length}})"
```

## Hooks

```yaml
my_step:
  type: step
  command: main-command
  pre_hook:
    command: echo "Before"
  post_hook:
    command: echo "After"
```
