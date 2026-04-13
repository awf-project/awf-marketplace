# Agent Steps Reference

Invoke AI agents (Claude, Codex, Gemini, OpenCode, OpenAI-Compatible) in workflows with structured prompts and response parsing.

## Overview

Agent steps integrate AI tools into AWF workflows. Define prompts as templates that get interpolated with workflow context and executed through provider-specific CLIs or direct HTTP APIs.

**Features:**
- Non-interactive execution for CI/CD automation
- **Output formatting** — strip markdown code fences and validate JSON with `output_format`
- **External prompt files** — load prompts from `.md` files with template interpolation
- **Conversation mode** for multi-turn interactions with automatic context management
- Multi-turn conversations via state passing (legacy)
- Automatic JSON response parsing
- Token usage tracking

## Basic Usage

```yaml
states:
  initial: analyze

  analyze:
    type: agent
    provider: claude
    prompt: "Analyze this code: {{.inputs.code}}"
    on_success: done

  done:
    type: terminal
```

```bash
awf run workflow --input code="$(cat main.py)"
```

## Providers

### Claude (Anthropic)

```yaml
analyze:
  type: agent
  provider: claude
  prompt: "Code review: {{.inputs.file_content}}"
  options:
    model: sonnet                          # sonnet, opus, haiku, or full model ID
    allowed_tools: "Read,Grep,Glob,Edit"   # Claude CLI tools to enable
    dangerously_skip_permissions: true     # Skip permission prompts (for automation)
  timeout: 120
  on_success: next
```

**Claude Options:**
| Option | Type | Description |
|--------|------|-------------|
| `model` | string | Model alias (sonnet, opus, haiku) or full ID |
| `allowed_tools` | string | Comma-separated Claude CLI tools to enable |
| `dangerously_skip_permissions` | bool | Skip interactive permission prompts |

> **Breaking Change**: All provider option keys use snake_case. camelCase keys (e.g., `allowedTools`, `dangerouslySkipPermissions`) are silently ignored — they will not produce an error but will have no effect.

> `temperature` and `max_tokens` are **not forwarded** to the Claude CLI.

> AWF always passes `--output-format stream-json --verbose` to the Claude CLI. The NDJSON stream is parsed internally: when `output_format` is set, the extracted text goes through the format pipeline (fence stripping, JSON validation); when `output_format` is omitted, clean text is extracted transparently before storing in `states.X.output`. Malformed or absent NDJSON gracefully results in a nil `Response` (no error returned).

### Codex (OpenAI)

```yaml
generate:
  type: agent
  provider: codex
  prompt: "Generate function: {{.inputs.requirement}}"
  options:
    model: codex-mini                      # Model flag (--model)
    dangerously_skip_permissions: true     # Maps to --yolo flag
  timeout: 60
  on_success: next
```

**Codex Options:**
| Option | Type | Description |
|--------|------|-------------|
| `model` | string | Model to use (passed as `--model` flag) |
| `dangerously_skip_permissions` | bool | Skip permission prompts (maps to `--yolo`) |

> `temperature` and `max_tokens` are **not forwarded** to the Codex CLI.

> **Breaking Change**: AWF now invokes Codex using the `exec --json <prompt>` subcommand (previously `--prompt <prompt> --quiet`). The `quiet` option has been removed from the Codex provider. Conversation resume uses `codex resume <id> --json` (previously `--prompt`). These are CLI-level implementation details — workflow YAML is unchanged.

### Gemini (Google)

```yaml
summarize:
  type: agent
  provider: gemini
  prompt: "Summarize: {{.inputs.text}}"
  options:
    model: gemini-pro
    dangerously_skip_permissions: true     # Maps to --approval-mode=yolo
  timeout: 60
  on_success: next
```

**Gemini Options:**
| Option | Type | Description |
|--------|------|-------------|
| `model` | string | Model identifier |
| `dangerously_skip_permissions` | bool | Skip permission prompts (maps to `--approval-mode=yolo`) |

> `temperature` and `max_tokens` are **not forwarded** to the Gemini CLI.

> When `output_format: json` is set, AWF passes `--output-format stream-json` to the Gemini CLI to enable streaming JSON output capture.

### OpenCode

```yaml
refactor:
  type: agent
  provider: opencode
  prompt: "Refactor: {{.inputs.code}}"
  options:
    model: anthropic/claude-sonnet-4-5    # Optional: model identifier
  timeout: 120
  on_success: next
```

**OpenCode Options:**
| Option | Type | Description |
|--------|------|-------------|
| `model` | string | Model identifier (passed as `--model` flag) |

> OpenCode format mapping: `output_format: text` or `default` maps to `--format default`; all other values (including when `output_format` is omitted) map to `--format json`. `temperature` and `max_tokens` are not forwarded.

### OpenAI-Compatible Provider

For any backend that speaks the Chat Completions API (OpenAI, Ollama, vLLM, Groq, LM Studio):

```yaml
my_ai:
  type: agent
  provider: openai_compatible
  prompt: "Analyze: {{.inputs.data}}"
  options:
    base_url: "http://localhost:11434/v1"   # Required: API endpoint
    model: "llama3"                          # Required: model name
    api_key: "sk-..."                        # Optional: falls back to OPENAI_API_KEY env var
    max_completion_tokens: 2048              # max_tokens accepted as legacy fallback
    temperature: 0.7
  timeout: 60
  on_success: next
```

**OpenAI-Compatible Options:**
| Option | Type | Required | Description |
|--------|------|----------|-------------|
| `base_url` | string | Yes | Chat Completions API endpoint URL |
| `model` | string | Yes | Model identifier |
| `api_key` | string | No | API key (falls back to `OPENAI_API_KEY` env var) |
| `max_completion_tokens` | int | No | Maximum response tokens (`max_tokens` accepted as legacy fallback) |
| `temperature` | float | No | Sampling temperature |

**Features:**
- Native multi-turn conversation support via `mode: conversation`
- Accurate token tracking from API `usage` response fields
- Structured HTTP error mapping: 401 (auth), 429 (rate limit), 5xx (server), timeout (deadline)
- Response body limited to 10MB
- API keys never logged or exposed in error messages

> **Breaking Change (v0.6.6)**: `provider: custom` has been removed. Workflows using `provider: custom` will fail validation with migration guidance to use `provider: openai_compatible` instead. The `command` field on agent steps has also been removed.

## Model Validation

AWF validates model names at workflow validation time for Gemini and Codex providers.

### Gemini

Model must start with `gemini-`:

```yaml
# Valid
options:
  model: gemini-2.0-flash
  model: gemini-pro
  model: gemini-1.5-pro

# Invalid — rejected at validation
options:
  model: gpt-4       # error: invalid Gemini model "gpt-4": must start with "gemini-"
  model: flash       # error: invalid Gemini model "flash": must start with "gemini-"
```

### Codex

Accepted patterns: `gpt-` prefix, `codex-` prefix, or o-series (`o` followed by a digit). Legacy names like `code-davinci` are rejected:

```yaml
# Valid
options:
  model: gpt-4o
  model: codex-mini
  model: o3
  model: o1-mini

# Invalid — rejected at validation
options:
  model: code-davinci  # error: invalid Codex model "code-davinci": use gpt-*, codex-*, or o-series (e.g. o3, o1-mini)
  model: gpt-4         # error: invalid Codex model "gpt-4": use gpt-*, codex-*, or o-series (e.g. o3, o1-mini)
```

> **Note**: Claude model validation is handled by the Claude CLI, not AWF. Passing an unknown alias or full model ID to the Claude provider is not validated at `awf validate` time.

Run `awf validate <workflow>` to catch model name errors before execution. See [Validation Reference](validation.md#model-validation) for full details.

## Dynamic Provider Selection

The `provider` field supports template expressions, enabling runtime provider selection via workflow inputs:

```yaml
name: flexible-analysis
version: "1.0.0"

inputs:
  - name: agent
    type: string
    required: true

states:
  initial: analyze

  analyze:
    type: agent
    provider: "{{.inputs.agent}}"
    prompt: "Analyze: {{.inputs.code}}"
    on_success: done

  done:
    type: terminal
```

```bash
awf run flexible-analysis --input agent=claude --input code="$(cat main.go)"
awf run flexible-analysis --input agent=gemini --input code="$(cat main.go)"
```

**Behavior:**
- The expression is resolved before the provider registry lookup
- An unresolvable template expression fails with a resolution error that includes the step name
- A resolved value not found in the registry fails with a "provider not found" error that includes both the step name and the resolved value
- Literal provider names (e.g., `provider: claude`) continue to work unchanged

## Prompt Templates

Access workflow context in prompts:

```yaml
review:
  type: agent
  provider: claude
  prompt: |
    Review this code file:
    Path: {{.inputs.file_path}}
    Language: {{.inputs.language}}

    Content:
    {{.inputs.file_content}}

    Focus on:
    - Performance issues
    - Security vulnerabilities
  on_success: report
```

**Available Variables:**
- `{{.inputs.*}}` - Workflow inputs
- `{{.states.step_name.Output}}` - Previous step raw output (or cleaned text if `output_format` is set)
- `{{.states.step_name.Response}}` - Previous step parsed JSON (automatic heuristic)
- `{{.states.step_name.JSON}}` - Parsed JSON from `output_format: json` (explicit)
- `{{.env.VAR_NAME}}` - Environment variables
- `{{.workflow.id}}` - Execution ID

## External Prompt Files

Instead of inlining prompts in YAML, load prompts from external Markdown files using `prompt_file`:

```yaml
analyze:
  type: agent
  provider: claude
  prompt_file: prompts/code_review.md
  timeout: 120
  on_success: done
```

**File:** `prompts/code_review.md`
```markdown
# Code Review Instructions

Analyze the following file for:
- Performance issues
- Security vulnerabilities

## File Path
{{.inputs.file_path}}

## File Content
{{.inputs.file_content}}
```

### Features

- **Full Template Interpolation** — Same variable access as inline prompts (`{{.inputs.*}}`, `{{.states.*}}`, `{{.env.*}}`)
- **Helper Functions** — `split`, `join`, `readFile`, `trimSpace` available in templates
- **Path Resolution** — Relative paths resolve to workflow directory
- **XDG Directory Support** — Access system directories via `{{.awf.*}}`

### Mutual Exclusivity

`prompt` and `prompt_file` cannot both be set on the same agent step:

```yaml
# Invalid: both prompt and prompt_file
step:
  type: agent
  provider: claude
  prompt: "Do this"
  prompt_file: "prompts/template.md"  # ERROR: only one allowed

# Valid: prompt_file only
step:
  type: agent
  provider: claude
  prompt_file: "prompts/template.md"
```

### Path Resolution

1. **Relative to workflow directory:**
   ```yaml
   prompt_file: prompts/analyze.md           # <workflow_dir>/prompts/analyze.md
   ```

2. **Absolute paths:**
   ```yaml
   prompt_file: /home/user/my-prompts/template.md
   ```

3. **Home directory expansion:**
   ```yaml
   prompt_file: ~/my-prompts/template.md
   ```

4. **XDG prompts directory with local override** — via template interpolation with local-before-global resolution:
   ```yaml
   prompt_file: "{{.awf.prompts_dir}}/analyze.md"
   # Checks in order:
   # 1. <workflow_dir>/prompts/analyze.md (local override)
   # 2. ~/.config/awf/prompts/analyze.md (global fallback)
   ```

### Template Helper Functions

Four helper functions are available in prompt templates:

#### `split`

Split a string into an array:

```markdown
## Selected Agents

{{range split .states.select_agents.Output ","}}
- {{trimSpace .}}
{{end}}
```

#### `join`

Join an array into a string:

```markdown
Skills to use: {{join .states.available_skills.Output ", "}}
```

#### `readFile`

Inline file contents (1MB size limit):

```markdown
## Specification

{{readFile .states.get_spec.Output}}
```

#### `trimSpace`

Remove leading/trailing whitespace:

```markdown
Result: {{trimSpace .states.process.Output}}
```

### Example: Multi-File Workflow

**Workflow:** `code-review.yaml`
```yaml
name: code-review
version: "1.0.0"

inputs:
  - name: file_path
    type: string
    required: true
    validation:
      file_exists: true
  - name: focus_areas
    type: string

states:
  initial: read_file

  read_file:
    type: step
    command: cat "{{.inputs.file_path}}"
    on_success: analyze

  analyze:
    type: agent
    provider: claude
    prompt_file: prompts/code_review.md
    timeout: 120
    on_success: done

  done:
    type: terminal
```

**Template:** `prompts/code_review.md`
```markdown
# Code Review

File: `{{.inputs.file_path}}`

Focus on:
{{.inputs.focus_areas}}

## Code to Review

{{.states.read_file.Output}}

Provide:
1. Issues found
2. Suggested fixes
3. Overall assessment
```

```bash
awf run code-review --input file_path=main.py --input focus_areas="Performance and security"
```

## Response Handling

Agent responses are captured in state:

| Field | Type | Description |
|-------|------|-------------|
| `output` | string | Raw response text (or cleaned text if `output_format` is set) |
| `response` | object | Parsed JSON response (automatic heuristic) |
| `json` | object | Parsed JSON from `output_format: json` (explicit, see [Output Formatting](#output-formatting)) |
| `tokens` | object | Token usage metadata |
| `exit_code` | int | 0 for success |

### Raw Output

```yaml
report:
  type: step
  command: echo "Agent said: {{.states.analyze.Output}}"
  on_success: done
```

### JSON Parsing

If agent returns valid JSON, it's automatically parsed:

```yaml
# Agent returns: {"issues": ["bug1"], "severity": "high"}

process:
  type: step
  command: echo "Found {{.states.analyze.Response.issues}} issues"
  on_success: done
```

## Output Formatting

When an agent wraps its output in markdown code fences (common with many LLMs), use `output_format` to automatically strip the fences and optionally validate the content:

```yaml
analyze:
  type: agent
  provider: claude
  prompt: "Return JSON analysis"
  output_format: json
  on_success: process
```

### Available Formats

#### `json` Format

Strips markdown code fences and validates the output as valid JSON. Parsed JSON is accessible via `{{.states.step_name.JSON}}`:

```yaml
analyze:
  type: agent
  provider: claude
  prompt: |
    Analyze the code and return results as JSON:
    {
      "issues": [<list of issues>],
      "severity": "high|medium|low"
    }
  output_format: json
  on_success: process_results

process_results:
  type: step
  command: echo "Severity: {{.states.analyze.JSON.severity}}"
  on_success: done
```

**Behavior:**
- Strips outermost markdown code fences (e.g., `` ```json ... ``` ``)
- Validates stripped content as valid JSON
- Stores parsed JSON in `{{.states.step_name.JSON}}`
- If validation fails, step fails with a descriptive error
- Works with both objects and arrays

**Example agent output:**
```
```json
{"issues": ["buffer overflow", "memory leak"], "severity": "high"}
```
```

**After processing:**
- `{{.states.analyze.Output}}` = `{"issues": ["buffer overflow", "memory leak"], "severity": "high"}`
- `{{.states.analyze.JSON.issues}}` = `["buffer overflow", "memory leak"]`
- `{{.states.analyze.JSON.severity}}` = `"high"`

#### `text` Format

Strips markdown code fences without JSON validation. Useful for code or plain text output:

```yaml
generate_code:
  type: agent
  provider: claude
  prompt: "Generate a Python function to..."
  output_format: text
  on_success: save_code

save_code:
  type: step
  command: echo "{{.states.generate_code.Output}}" > generated.py
  on_success: done
```

**Behavior:**
- Strips outermost markdown code fences (e.g., `` ```python ... ``` ``)
- Returns clean text in `{{.states.step_name.Output}}`
- Does not populate `{{.states.step_name.JSON}}`

#### No Format (Default)

Omit `output_format` for backward compatibility. Raw agent output is stored unchanged.

### Error Handling

When `output_format: json` is specified but the output is invalid JSON:

```yaml
analyze:
  type: agent
  provider: claude
  prompt: "Return valid JSON"
  output_format: json
  timeout: 60
  on_failure: handle_json_error

handle_json_error:
  type: step
  command: echo "JSON parsing failed"
  on_success: done
```

**Error message includes:**
- Clear indication of JSON validation failure
- First 200 characters of the malformed output (for debugging)

## Streaming Output Display

When running with `--output streaming` or `--output buffered`, AWF filters agent NDJSON responses to human-readable text instead of displaying raw wire format. The `output_format` field controls both post-processing behavior and terminal display routing.

### Display Matrix

| `output_format` | `--output streaming` / `buffered` | `--output silent` |
|-----------------|-----------------------------------|-------------------|
| `text` or omitted | Filters NDJSON to plain text | No terminal output |
| `json` | Passes raw NDJSON through | No terminal output |

### Behavior Details

- **`text` or omitted** — AWF extracts readable text from the NDJSON stream and writes it to the terminal as the agent responds. `cloneAndInjectOutputFormat` normalizes `output_format` omitted → `text` internally so the display pipeline always receives an explicit format.
- **`json`** — Raw NDJSON is forwarded directly to the terminal. Use this when you need to inspect the wire format or pipe agent output to another tool.
- **`silent` mode** — No terminal display regardless of `output_format`. Post-processing still runs, and `{{.states.step.Output}}` is still populated.

### Template Interpolation Is Unchanged

`DisplayOutput` is an internal field populated in `AgentResult` for terminal display. It is **not accessible as a template variable**:

```yaml
# WRONG — does not resolve
command: echo "{{.states.analyze.DisplayOutput}}"

# CORRECT — use Output for template interpolation (retains raw NDJSON-derived text)
command: echo "{{.states.analyze.Output}}"
```

`state.Output` always retains the raw NDJSON-derived content for use in subsequent step templates, independent of what was displayed on the terminal.

### Example: Streaming a JSON Agent Response

```yaml
analyze:
  type: agent
  provider: claude
  prompt: "Return JSON analysis with 'issues' and 'severity' fields"
  output_format: json   # raw NDJSON shown on terminal; JSON parsed for templates
  on_success: report

report:
  type: step
  command: echo "Severity: {{.states.analyze.JSON.severity}}"
  on_success: done
```

```bash
# Shows raw NDJSON stream on terminal
awf run workflow --output streaming

# Shows filtered plain text on terminal
awf run workflow --output streaming   # with output_format: text or omitted

# No terminal output, post-processing still runs
awf run workflow --output silent
```

## Multi-Turn Conversations

### Conversation Mode

Use conversation mode for autonomous multi-turn execution:

```yaml
review:
  type: agent
  provider: claude
  mode: conversation
  system_prompt: "You are a code reviewer. Say APPROVED when done."
  prompt: "Review: {{.inputs.code}}"
  conversation:
    max_turns: 10
    stop_condition: "inputs.response contains 'APPROVED'"
  on_success: done
```

**Key points:**
- Same prompt executed each turn (not interactive back-and-forth)
- Use `inputs.` prefix in stop conditions (`inputs.response`, `inputs.turn_count`)
- Only `sliding_window` strategy implemented

**Details:** [Conversation Mode Reference](conversation-steps.md)

### State Passing (Legacy)

Chain agent steps with state passing:

```yaml
states:
  initial: initial_review

  initial_review:
    type: agent
    provider: claude
    prompt: "Review this code: {{.inputs.code}}"
    on_success: ask_details

  ask_details:
    type: agent
    provider: claude
    prompt: |
      Based on your analysis:
      {{.states.initial_review.Output}}

      Elaborate on performance concerns.
    on_success: suggest

  suggest:
    type: agent
    provider: claude
    prompt: "Suggest 3 improvements to: {{.inputs.code}}"
    on_success: done

  done:
    type: terminal
```

## Error Handling

```yaml
analyze:
  type: agent
  provider: claude
  prompt: "Review: {{.inputs.code}}"
  timeout: 120
  on_success: success
  on_failure: error
  retry:
    max_attempts: 3
    backoff: exponential
    initial_delay: 2s
```

| Error | Cause | Solution |
|-------|-------|----------|
| Provider not found | CLI not installed | Install required CLI |
| Timeout | Response too slow | Increase timeout |
| Invalid provider | Unsupported | Use valid provider name |
| Command failed | CLI error | Check provider logs |

## Parallel Execution

Run multiple agents concurrently:

```yaml
parallel_analysis:
  type: parallel
  strategy: all_succeed
  steps:
    - name: security
      type: agent
      provider: claude
      prompt: "Security analysis: {{.inputs.code}}"
    - name: performance
      type: agent
      provider: codex
      prompt: "Performance optimization: {{.inputs.code}}"
  on_success: aggregate

aggregate:
  type: step
  command: |
    echo "Security: {{.states.security.Output}}"
    echo "Performance: {{.states.performance.Output}}"
  on_success: done
```

## Debugging

Preview prompts without execution:

```bash
awf run workflow --dry-run --input file=/path/to/file
# Shows: [DRY RUN] Agent: claude
# Prompt: <resolved prompt text>
```

## Best Practices

### 1. Keep Prompts Focused

Break complex tasks into multiple steps:

```yaml
# Better: focused steps
security_review:
  type: agent
  provider: claude
  prompt: "Security review: {{.inputs.code}}"
  on_success: performance_review

performance_review:
  type: agent
  provider: claude
  prompt: |
    After security review:
    {{.states.security_review.Output}}

    Now analyze performance.
  on_success: done
```

### 2. Request Structured Output

Use `output_format: json` to strip markdown fences and validate JSON:

```yaml
analyze:
  type: agent
  provider: claude
  prompt: |
    Respond in JSON format:
    {"issues": [...], "severity": "high|medium|low"}

    Code: {{.inputs.code}}
  output_format: json
  on_success: process

process:
  type: step
  command: echo "Severity: {{.states.analyze.JSON.severity}}"
  on_success: done
```

### 3. Set Timeouts

```yaml
analyze:
  type: agent
  provider: claude
  prompt: "Review: {{.inputs.code}}"
  timeout: 120
  on_success: next
```

### 4. Handle Missing Providers

```yaml
check_claude:
  type: step
  command: which claude
  on_success: analyze
  on_failure: missing_provider

analyze:
  type: agent
  provider: claude
  prompt: "Review: {{.inputs.code}}"
  on_success: done

missing_provider:
  type: terminal
  status: failure
```

### 5. Inline Error Shorthand

Use inline `on_failure` objects to avoid defining separate terminal states:

```yaml
analyze:
  type: agent
  provider: claude
  prompt: "Review: {{.inputs.code}}"
  timeout: 120
  on_success: done
  on_failure: {message: "Agent analysis failed", status: 3}

done:
  type: terminal
```

See [Workflow Syntax - Inline Error Shorthand](workflow-syntax.md#inline-error-shorthand) for full details.

## Common Mistakes & Verification

### 1. Use `prompt_file` for External Prompts

Agent steps can load prompts from external files directly using `prompt_file` (no preparation step needed):

```yaml
# ❌ WRONG: Shell not executed in prompt field
analyze:
  type: agent
  provider: claude
  prompt: "$(cat prompt.md)"

# ✅ CORRECT: Use prompt_file to load external prompts
analyze:
  type: agent
  provider: claude
  prompt_file: prompts/analyze.md  # Full template interpolation supported
  on_success: next

# ✅ ALSO CORRECT: Prepare prompt in shell step (legacy approach)
prepare_prompt:
  type: step
  command: |
    export CONTEXT="some data"
    envsubst < prompts/analyze.md
  capture:
    stdout: analysis_prompt
  on_success: analyze

analyze:
  type: agent
  provider: claude
  prompt: "{{.states.prepare_prompt.Output}}"
  on_success: next
```

### 2. Transitions Must Target Preparation Steps

When converting shell commands to agent steps, update **all transitions** to target the preparation step:

```yaml
# ❌ WRONG: Transition skips preparation step
check_result:
  transitions:
    - goto: analyze_errors  # Agent step - will fail!

# ✅ CORRECT: Transition targets preparation step
check_result:
  transitions:
    - goto: prepare_analyze_prompt  # Shell step first
```

### 3. For-Each Body Must List All Steps

Loop executors only run steps **explicitly listed** in `body`. They do NOT follow `on_success` transitions:

```yaml
# ❌ WRONG: Only prepare_prompt runs, agent step never executes
process_items:
  type: for_each
  body:
    - prepare_prompt  # on_success: do_work is IGNORED

# ✅ CORRECT: Both steps listed in body
process_items:
  type: for_each
  body:
    - prepare_prompt
    - do_work  # Must be explicitly listed
  on_complete: verify
```

### 4. Template Syntax: Use Uppercase for State Properties

State property names must use **uppercase** (Go template convention):

```yaml
# ❌ WRONG: Lowercase state properties
prompt: "{{.states.step.output}}"
when: "states.step.exit_code == 0"

# ✅ CORRECT: Uppercase state properties
prompt: "{{.states.step.Output}}"
when: "states.step.ExitCode == 0"
```

**State properties (uppercase):** `.Output`, `.Stderr`, `.ExitCode`, `.Status`, `.Response`, `.JSON`, `.Tokens`

**Loop context (PascalCase):** `.Item`, `.Index`, `.Index1`, `.First`, `.Last`, `.Length`, `.Parent`

> Use `awf validate` to detect casing issues.

### 5. JSON in Shell Commands: Use Heredocs

When passing JSON (like loop items) to shell commands, use **quoted heredocs**:

```yaml
# ❌ WRONG: Breaks if JSON contains quotes
command: |
  export DATA='{{.loop.Item}}'

# ✅ CORRECT: Heredoc with quoted delimiter
command: |
  DATA=$(cat << 'DATAEOF'
  {{.loop.Item}}
  DATAEOF
  )
```

### 6. Claude Agent Steps: Required Options for File Modifications

If agent needs to modify files, include both options (use snake_case keys):

```yaml
# ❌ WRONG: Missing dangerously_skip_permissions - agent can't write
fix_code:
  type: agent
  provider: claude
  options:
    allowed_tools: "Read,Edit,Write"  # Not enough!

# ✅ CORRECT: Both options for automated file changes
fix_code:
  type: agent
  provider: claude
  options:
    allowed_tools: "Read,Grep,Glob,Edit,Write,Bash"
    dangerously_skip_permissions: true
```

## Verification Checklist

Before running a workflow with agent steps:

- [ ] Agent prompts use either `prompt_file` (preferred) or a **preparation step** (legacy)
- [ ] `prompt` and `prompt_file` are **never both set** on the same agent step
- [ ] All **transitions** point to preparation steps (not directly to agents) when using legacy approach
- [ ] **for_each/while body** lists all steps that should execute
- [ ] Template syntax uses **PascalCase** (`.Output`, `.Item`, not `.output`, `.item`)
- [ ] JSON values use **heredocs** with quoted delimiters
- [ ] File-modifying agents have **`dangerously_skip_permissions: true`**

Run `awf validate <workflow>` to catch syntax errors before execution.
