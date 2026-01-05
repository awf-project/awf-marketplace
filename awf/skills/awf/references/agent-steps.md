# Agent Steps Reference

Invoke AI agents (Claude, Codex, Gemini, OpenCode) in workflows with structured prompts and response parsing.

## Overview

Agent steps integrate AI CLI tools into AWF workflows. Define prompts as templates that get interpolated with workflow context and executed through provider-specific CLIs.

**Features:**
- Non-interactive execution for CI/CD automation
- Multi-turn conversations via state passing
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
    max_tokens: 4096
    temperature: 0.7
    allowedTools: "Read,Grep,Glob,Edit"    # Claude CLI tools to enable
    dangerouslySkipPermissions: true       # Skip permission prompts (for automation)
  timeout: 120
  on_success: next
```

**Claude Options:**
| Option | Type | Description |
|--------|------|-------------|
| `model` | string | Model alias (sonnet, opus, haiku) or full ID |
| `allowedTools` | string | Comma-separated Claude CLI tools to enable |
| `dangerouslySkipPermissions` | bool | Skip interactive permission prompts |
| `output_format` | string | Response format: `text` (default) or `json` |

### Codex (OpenAI)

```yaml
generate:
  type: agent
  provider: codex
  prompt: "Generate function: {{.inputs.requirement}}"
  options:
    max_tokens: 2048
  timeout: 60
  on_success: next
```

### Gemini (Google)

```yaml
summarize:
  type: agent
  provider: gemini
  prompt: "Summarize: {{.inputs.text}}"
  options:
    model: gemini-pro
  timeout: 60
  on_success: next
```

### OpenCode

```yaml
refactor:
  type: agent
  provider: opencode
  prompt: "Refactor: {{.inputs.code}}"
  timeout: 120
  on_success: next
```

### Custom Provider

For unsupported AI CLIs:

```yaml
my_ai:
  type: agent
  provider: custom
  command: "my-ai-tool --prompt={{prompt}} --json --timeout=30"
  prompt: "Analyze: {{.inputs.data}}"
  timeout: 60
  on_success: next
```

The `{{prompt}}` placeholder is replaced with the shell-escaped resolved prompt.

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
- `{{.states.step_name.Output}}` - Previous step raw output
- `{{.states.step_name.Response}}` - Previous step parsed JSON
- `{{.env.VAR_NAME}}` - Environment variables
- `{{.workflow.id}}` - Execution ID

## Response Handling

Agent responses are captured in state:

| Field | Type | Description |
|-------|------|-------------|
| `output` | string | Raw response text |
| `response` | object | Parsed JSON (if valid) |
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

## Multi-Turn Conversations

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

```yaml
analyze:
  type: agent
  provider: claude
  prompt: |
    Respond in JSON format:
    {"issues": [...], "severity": "high|medium|low"}

    Code: {{.inputs.code}}
  on_success: process
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

## Common Mistakes & Verification

### 1. Agent Steps Need Preparation Steps

Agent steps that use dynamic prompts from external files need a **preparation step** first:

```yaml
# ❌ WRONG: Agent step can't read external files
analyze:
  type: agent
  provider: claude
  prompt: "$(cat prompt.md)"  # Shell not executed in prompt field

# ✅ CORRECT: Prepare prompt in shell step, then use agent
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

### 4. Template Syntax: Use Capital Letters

All state/loop field names use **PascalCase** in templates:

```yaml
# ❌ WRONG: Lowercase field names
prompt: "{{.states.step.output}}"
command: echo "{{.loop.item}}"

# ✅ CORRECT: PascalCase field names
prompt: "{{.states.step.Output}}"
command: echo "{{.loop.Item}}"
```

**Correct field names:**
| Context | Fields |
|---------|--------|
| States | `.Output`, `.Response`, `.Tokens`, `.ExitCode` |
| Loop | `.Item`, `.Index`, `.Index1`, `.First`, `.Last`, `.Length` |

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

If agent needs to modify files, include both options:

```yaml
# ❌ WRONG: Missing dangerouslySkipPermissions - agent can't write
fix_code:
  type: agent
  provider: claude
  options:
    allowedTools: "Read,Edit,Write"  # Not enough!

# ✅ CORRECT: Both options for automated file changes
fix_code:
  type: agent
  provider: claude
  options:
    allowedTools: "Read,Grep,Glob,Edit,Write,Bash"
    dangerouslySkipPermissions: true
```

## Verification Checklist

Before running a workflow with agent steps:

- [ ] Each agent step has a **preparation step** that captures the prompt
- [ ] All **transitions** point to preparation steps (not directly to agents)
- [ ] **for_each/while body** lists all steps that should execute
- [ ] Template syntax uses **PascalCase** (`.Output`, `.Item`, not `.output`, `.item`)
- [ ] JSON values use **heredocs** with quoted delimiters
- [ ] File-modifying agents have **`dangerouslySkipPermissions: true`**

Run `awf validate <workflow>` to catch syntax errors before execution.
