# Agent Conversation Mode

Two approaches to multi-turn agent conversations: interactive user-driven loops and cross-step session tracking.

## Overview

### Interactive Conversation (mode: conversation)

`mode: conversation` starts a live, interactive session in the terminal:

1. AWF sends `prompt` as the first user message
2. Agent responds
3. AWF prints `> ` and reads user input from stdin
4. Repeat until user sends an empty line (or EOF)

```yaml
chat:
  type: agent
  provider: claude
  mode: conversation
  system_prompt: "You are a helpful assistant."
  prompt: "Hello! How can I help you today?"
  on_success: done
```

> **Requires a terminal.** Interactive conversation is not suitable for CI/CD pipelines or non-interactive scripts. Use sequential agent steps with `continue_from` for automation.

### Cross-Step Session Tracking

Any agent step can enable session tracking by adding `conversation: {}`. This records the session so a downstream step can resume it with `continue_from`.

```yaml
initial_review:
  type: agent
  provider: claude
  prompt: "Review this code: {{.inputs.code}}"
  conversation: {}         # enables session tracking
  on_success: deep_review

deep_review:
  type: agent
  provider: claude
  prompt: "Now focus on security issues."
  conversation:
    continue_from: initial_review   # resumes initial_review's session
  on_success: done
```

## Basic Syntax

### Interactive Mode

```yaml
name: interactive-chat
version: "1.0.0"

states:
  initial: chat

  chat:
    type: agent
    provider: claude
    mode: conversation
    system_prompt: |
      You are a code reviewer. Answer questions about the codebase.
    prompt: |
      I'm ready to review. What would you like to discuss?
    options:
      model: claude-sonnet-4-20250514
    on_success: done

  done:
    type: terminal
```

```bash
awf run interactive-chat
# Agent responds to the prompt
# > [user types message]
# > [empty line exits]
```

### Session Tracking and Resume

```yaml
name: two-phase-review
version: "1.0.0"

inputs:
  - name: code
    type: string
    required: true

states:
  initial: initial_review

  initial_review:
    type: agent
    provider: claude
    system_prompt: "You are a code reviewer."
    prompt: "Review: {{.inputs.code}}"
    conversation: {}         # track session for downstream resume
    on_success: deep_review

  deep_review:
    type: agent
    provider: claude
    prompt: "Focus on security issues in depth."
    conversation:
      continue_from: initial_review
    on_success: done

  done:
    type: terminal
```

## Configuration

### Step-Level Options

| Option | Type | Required | Default | Description |
|--------|------|----------|---------|-------------|
| `type` | string | Yes | - | Must be `agent` |
| `mode` | string | No | `single` | Set to `conversation` for interactive terminal session |
| `provider` | string | Yes | - | Agent provider: `claude`, `codex`, `gemini`, `opencode`, `openai_compatible`, `github_copilot` |
| `system_prompt` | string | No | - | System message preserved across turns |
| `prompt` | string | Yes | - | First user message sent to agent |
| `options` | map | No | - | Provider-specific options |
| `timeout` | int/string | No | `300` | Timeout per turn — seconds (`120`) or Go duration (`"2m"`) |
| `on_success` | string | Yes | - | Next state on conversation exit |
| `on_failure` | string | No | - | Next state on error |

### Conversation Configuration

```yaml
conversation:
  continue_from: previous_step     # Resume session from another step (optional)
```

| Option | Type | Description |
|--------|------|-------------|
| `continue_from` | string | Step name to resume session from. Validated at `awf validate` time. |

#### continue_from

Resume the session (SessionID or Turns) from a previously executed agent step. The target step must exist in the same workflow and must have completed with a non-empty session.

```yaml
conversation:
  continue_from: initial_review
```

- Static step-name validation at `awf validate` time
- CLI providers resume via SessionID; `openai_compatible` resumes via Turns list
- Missing step, nil state, or empty session produces a clear error
- Any agent step is a valid resume source when it has `conversation: {}` or `mode: conversation`

## How It Works

### Interactive Mode

```
+--------------------------------------------------+
|          Interactive Conversation Loop            |
+--------------------------------------------------+
|                                                  |
|  AWF sends `prompt` as first user message        |
|  Agent responds                                  |
|                                                  |
|  Loop:                                           |
|    AWF prints "> " and reads stdin               |
|    Empty line or EOF -> exit (StopReasonUserExit)|
|    AWF sends user input to agent                 |
|    Agent responds                                |
|    Repeat                                        |
|                                                  |
+--------------------------------------------------+
```

**Key points:**
- `prompt` is the first user message, not repeated each turn
- Subsequent turns are driven by user input
- Empty line exits cleanly with `StopReasonUserExit`

### Session Resume

CLI providers persist sessions across turns. `SessionID` is extracted from provider NDJSON output and passed back via native resume flags:

- **Claude**: `-r <session_id>` flag; session ID from NDJSON stream
- **Codex**: `resume <thread_id>` subcommand; `thread_id` from `type: "thread.started"` NDJSON event
- **Gemini**: `--resume <session_id>` flag; `session_id` from `type: "init"` NDJSON event
- **OpenCode**: `-s <sessionID>` flag; `sessionID` from `type: "step_start"` NDJSON event; falls back to `-c` when extraction fails but prior turns exist
- **openai_compatible**: Resumes via Turns list (HTTP-level multi-turn history)
- **github_copilot**: `--resume=<session-id>` flag; session ID from JSONL stream

## Accessing Conversation State

After execution, conversation state is available in step state:

```yaml
show_result:
  type: step
  command: |
    echo "Final response: {{.states.review.Output}}"
  on_success: done
```

### State Structure

```yaml
states:
  review:
    Output: "Final response text..."
    Status: completed
    Conversation:
      SessionID: "sess_abc123"
      Turns:
        - Role: system
          Content: "You are a code reviewer..."
          Tokens: 50
        - Role: user
          Content: "Review this code..."
          Tokens: 500
        - Role: assistant
          Content: "Here are my findings..."
          Tokens: 800
    TokensUsed: 1350
```

## Examples

### Interactive Code Review

```yaml
name: code-review-session
version: "1.0.0"

inputs:
  - name: code
    type: string
    required: true

states:
  initial: review

  review:
    type: agent
    provider: claude
    mode: conversation
    system_prompt: |
      You are a code reviewer. Answer questions about the code.
      Be concise and point to specific line numbers.
    prompt: |
      Here is the code to review:
      {{.inputs.code}}

      What issues do you see?
    options:
      model: claude-sonnet-4-20250514
    on_success: done

  done:
    type: terminal
```

### Automated Two-Phase Analysis

```yaml
name: two-phase-analysis
version: "1.0.0"

inputs:
  - name: code
    type: string
    required: true

states:
  initial: initial_review

  initial_review:
    type: agent
    provider: claude
    system_prompt: "You are a code reviewer."
    prompt: "Review: {{.inputs.code}}"
    conversation: {}
    on_success: security_review

  security_review:
    type: agent
    provider: claude
    prompt: "Based on the previous review, identify all security vulnerabilities."
    conversation:
      continue_from: initial_review
    on_success: done

  done:
    type: terminal
```

## Breaking Changes from Automated Loop Model

The following fields were removed. YAML parsing rejects them with actionable errors:

| Removed Field | Replacement |
|---------------|-------------|
| `max_turns` | Remove — interactive mode exits on empty line |
| `max_context_tokens` | Remove — context window management is gone |
| `strategy` | Remove — `sliding_window` no longer exists |
| `stop_condition` | Remove — user drives exit interactively |
| `inject_context` | Remove — interactive mode takes user input each turn |

Also removed: `initial_prompt` on agent steps. Use `prompt` for the first user message.

**Migration for automated pipelines**: Replace automated-loop workflows with sequential agent steps using `conversation: {}` on the first step and `continue_from` on subsequent steps.

## Troubleshooting

### "unknown field" errors for removed fields

**Problem**: YAML parsing fails with errors about `max_turns`, `strategy`, `stop_condition`, etc.

**Fix**: Remove those fields. See [Breaking Changes](#breaking-changes-from-automated-loop-model) for the full list.

### Session not found with continue_from

**Problem**: `continue_from` fails with "missing step" or "empty session"

**Check**:
1. Source step name matches exactly — validated at `awf validate`
2. Source step has `conversation: {}` or `mode: conversation`
3. Source step completed successfully before the resume step ran

### Interactive mode hangs in CI

**Problem**: Workflow blocks waiting for user input

**Cause**: `mode: conversation` reads from stdin and requires a terminal.

**Fix**: Use sequential agent steps with `continue_from` for automated pipelines.

## See Also

- [Agent Steps Guide](agent-steps.md) - Single-turn and multi-step agent execution
- [Workflow Syntax Reference](workflow-syntax.md#agent-state) - Complete agent options
- [Interpolation Reference](interpolation.md) - Variable interpolation
