# Agent Conversation Mode

Enable multi-turn agent execution with automatic stop conditions and token tracking.

## Overview

While [agent steps](agent-steps.md) invoke agents once per step, **conversation mode** executes the same prompt repeatedly until a stop condition is met. This is useful for:

- **Iterative generation** - Agent refines output over multiple turns
- **Autonomous reasoning** - Chain-of-thought across turns until completion signal
- **Controlled execution** - Stop after N turns or when specific output detected

> **Important**: Conversation mode does NOT support interactive back-and-forth with user input between turns. Each turn executes the same prompt. For interactive workflows, use multiple separate agent steps.

## Basic Syntax

```yaml
name: autonomous-review
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
      You are a code reviewer. Iterate on improvements.
      Say "APPROVED" when the code meets quality standards.
    prompt: |
      Review this code:
      {{.inputs.code}}
    options:
      model: claude-sonnet-4-20250514
    conversation:
      max_turns: 10
      max_context_tokens: 100000
      strategy: sliding_window
      stop_condition: "inputs.response contains 'APPROVED'"
    on_success: done

  done:
    type: terminal
```

## Configuration

### Step-Level Options

| Option | Type | Required | Default | Description |
|--------|------|----------|---------|-------------|
| `type` | string | Yes | - | Must be `agent` |
| `mode` | string | No | `single` | Set to `conversation` for multi-turn |
| `provider` | string | Yes | - | Agent provider: `claude`, `codex`, `gemini`, `opencode`, `openai_compatible` |
| `system_prompt` | string | No | - | System message preserved across turns |
| `prompt` | string | Yes | - | User message (executed each turn) |
| `options` | map | No | - | Provider-specific options (see [Agent Steps](agent-steps.md#providers)) |
| `timeout` | int/string | No | `300` | Timeout per turn — seconds (`120`) or Go duration (`"2m"`, `"1m30s"`) |
| `on_success` | string | Yes | - | Next state on completion |
| `on_failure` | string | No | - | Next state on error |

### Conversation Configuration

```yaml
conversation:
  max_turns: 10                    # Maximum turns (default: 10)
  max_context_tokens: 100000       # Token budget (default: unlimited)
  strategy: sliding_window         # Only supported strategy
  stop_condition: "expression"     # Exit condition (optional)
  continue_from: previous_step     # Resume session from another step (optional)
  inject_context: |                # Append context on turns 2+ (optional)
    Latest: {{.states.check.Output}}
```

#### max_turns

Maximum conversation turns before automatic termination. Default is 10.

```yaml
conversation:
  max_turns: 5  # Stop after 5 turns regardless of stop_condition
```

#### max_context_tokens

Token budget for the conversation. When exceeded, oldest turns are dropped (sliding window).

```yaml
conversation:
  max_context_tokens: 50000
```

#### strategy

Context window strategy when token limit is reached:

- **`sliding_window`** (only implemented) - Drop oldest turns, preserve system prompt

```yaml
strategy: sliding_window
```

> `summarize` and `truncate_middle` are **rejected at validation** with "not yet implemented" errors. Only `sliding_window` is accepted.

#### continue_from

Resume the session state (SessionID or Turns) from a previously executed conversation step. The target step must exist in the same workflow and must have completed with a non-empty session.

```yaml
conversation:
  continue_from: initial_review   # Resume from initial_review's session
  max_turns: 5
```

- Static step-name validation at `awf validate` time
- CLI providers resume via SessionID; `openai_compatible` uses Turns
- Missing step, nil state, or empty session produces a clear error

#### inject_context

Append interpolated context to agent prompts on turns 2+. Template variables are re-resolved each turn against the current interpolation context, so `{{.states.*}}` and `{{.inputs.*}}` reflect the latest step outputs.

```yaml
conversation:
  inject_context: |
    Current test results: {{.states.test_run.Output}}
    Iteration: {{.states.counter.Output}}
  max_turns: 10
```

- First turn: only `prompt` is sent (no injection)
- Turns 2+: `inject_context` is appended with `\n\n` separator
- Empty/whitespace values are treated as no-ops
- Requires `mode: conversation` — rejected on `mode: single`
- Interpolation errors are wrapped with `inject_context: <error>` for attribution

#### stop_condition

Expression evaluated after each turn. When true, conversation exits early.

```yaml
stop_condition: "inputs.response contains 'APPROVED'"
```

**Compile-time validation (v0.5.30)**: Stop condition expressions are validated during workflow loading using expr-lang. Syntax errors are reported immediately rather than at runtime:

```bash
$ awf validate my-workflow
validation error: invalid stop_condition expression
  - syntax error: unexpected token '&&' (use 'and' instead)
```

## Stop Condition Expressions

Stop conditions use the expression evaluator with these variables:

| Variable | Type | Description |
|----------|------|-------------|
| `inputs.response` | string | Last assistant response |
| `inputs.turn_count` | int | Number of completed turns |

### Examples

```yaml
# Exit when response contains keyword
stop_condition: "inputs.response contains 'DONE'"

# Exit after N turns
stop_condition: "inputs.turn_count >= 5"

# Complex: exit on keyword OR turn limit
stop_condition: "inputs.response contains 'APPROVED' || inputs.turn_count >= 10"

# Multiple keywords
stop_condition: "inputs.response contains 'COMPLETE' || inputs.response contains 'FINISHED'"
```

> **Important**: Variables must be prefixed with `inputs.` (e.g., `inputs.response`, not just `response`).

## Accessing Conversation State

After execution, conversation state is available in step state:

```yaml
show_result:
  type: step
  command: |
    echo "Final response: {{.states.review.Output}}"
    echo "Turns: {{.states.review.Conversation.TotalTurns}}"
    echo "Tokens: {{.states.review.TokensUsed}}"
  on_success: done
```

### State Structure

```yaml
states:
  review:
    Output: "Final response text..."
    Status: completed
    Conversation:
      SessionID: "sess_abc123"     # Provider-native session ID for resume
      Turns:
        - Role: system
          Content: "You are a code reviewer..."
          Tokens: 50
        - Role: user
          Content: "Review this code..."
          Tokens: 500
        - Role: assistant
          Content: "I found issues... APPROVED"
          Tokens: 800
      TotalTurns: 3
      TotalTokens: 1350
      StoppedBy: condition  # or "max_turns", "max_tokens"
    TokensUsed: 1350
```

## How It Works

```
+-------------------------------------------------------------+
|                    Conversation Loop                         |
+-------------------------------------------------------------+
|                                                              |
|  Turn 1: Execute prompt -> Response A                        |
|          Check stop_condition -> false                       |
|                                                              |
|  Turn 2: Execute prompt -> Response B                        |
|          Check stop_condition -> false                       |
|                                                              |
|  Turn 3: Execute prompt -> Response C (contains "APPROVED")  |
|          Check stop_condition -> true -> EXIT                |
|                                                              |
+-------------------------------------------------------------+
```

**Key points**:
- The same `prompt` is sent each turn. The provider CLI is invoked with the same prompt repeatedly.
- **Session resume**: All 4 CLI providers persist sessions across turns via native flags (Claude `-r`, Codex `--resume`, Gemini `--resume`, OpenCode `-s`). `SessionID` is extracted from command output after each turn and passed back on subsequent turns.
- CLI providers (`claude`, `codex`, `gemini`, `opencode`) execute each turn independently — only `openai_compatible` maintains true HTTP-level multi-turn history continuity.

## Examples

### Autonomous Code Review

```yaml
name: code-review
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
      You are a code reviewer. Analyze the code and suggest improvements.
      After each review iteration, either:
      - Suggest another improvement
      - Say "APPROVED" if the code is good
    prompt: |
      Review this code:
      {{.inputs.code}}
    options:
      model: claude-sonnet-4-20250514
    conversation:
      max_turns: 5
      stop_condition: "inputs.response contains 'APPROVED'"
    on_success: done

  done:
    type: terminal
```

### Cross-Step Resume with continue_from

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
    mode: conversation
    system_prompt: "You are a code reviewer."
    prompt: "Review: {{.inputs.code}}"
    conversation:
      max_turns: 3
    on_success: deep_review

  deep_review:
    type: agent
    provider: claude
    mode: conversation
    prompt: "Now focus on security issues."
    conversation:
      continue_from: initial_review    # Resumes initial_review's session
      max_turns: 3
      stop_condition: "inputs.response contains 'SECURE'"
    on_success: done

  done:
    type: terminal
```

### Turn-Limited Generation

```yaml
name: brainstorm
version: "1.0.0"

inputs:
  - name: topic
    type: string
    required: true

states:
  initial: generate

  generate:
    type: agent
    provider: claude
    mode: conversation
    system_prompt: "Generate creative ideas. One idea per turn."
    prompt: "Generate ideas about: {{.inputs.topic}}"
    conversation:
      max_turns: 5
      stop_condition: "inputs.turn_count >= 3"
    on_success: done

  done:
    type: terminal
```

## Limitations

### Current Implementation

- **Single prompt per conversation** - Same prompt executed each turn (use `inject_context` to vary context on turns 2+)
- **No interactive input** - Cannot inject user messages between turns
- **Only `sliding_window` strategy** - `summarize` and `truncate_middle` rejected at validation
- **No branching** - Single linear path only

### Not Yet Implemented

| Feature | Status | Description |
|---------|--------|-------------|
| `summarize` strategy | Rejected at validation | LLM-based compression of old turns |
| `truncate_middle` strategy | Rejected at validation | Keep first and last turns |
| `on_error` mapping | Not implemented | Route to specific states by error type |
| Interactive input | Not implemented | User input between turns |

## Best Practices

### 1. Always Set Turn Limits

Prevent runaway conversations:

```yaml
conversation:
  max_turns: 10  # Hard limit
  stop_condition: "inputs.response contains 'DONE'"
```

### 2. Use Specific Stop Keywords

Make stop conditions unambiguous:

```yaml
# Good: Specific signal
stop_condition: "inputs.response contains 'TASK_COMPLETE'"

# Bad: Could match unintended text
stop_condition: "inputs.response contains 'done'"
```

### 3. Instruct Agent About Completion

Include completion signal in system prompt:

```yaml
system_prompt: |
  Complete the task step by step.
  Say "FINISHED" when you're done.
```

### 4. Use Fallback Turn Limits

Combine keyword and turn limit:

```yaml
stop_condition: "inputs.response contains 'DONE' || inputs.turn_count >= 10"
```

## Troubleshooting

### Stop Condition Not Triggering

**Problem**: Conversation runs to max_turns

**Check**:
1. Expression syntax uses `inputs.` prefix
2. Keyword matches exactly (case-sensitive)
3. Agent system prompt instructs completion signal

```yaml
# Wrong
stop_condition: "response contains 'DONE'"

# Correct
stop_condition: "inputs.response contains 'DONE'"
```

### Same Response Each Turn

**Expected behavior**: Conversation mode executes the same prompt each turn. The response may vary due to model non-determinism, but input is identical.

For different inputs each turn, use multiple agent steps instead.

### Context Window Exceeded

**Problem**: Old turns dropped, losing context

**Solutions**:
- Increase `max_context_tokens`
- Reduce `max_turns`
- Use shorter system prompt

## See Also

- [Agent Steps Guide](agent-steps.md) - Single-turn agent execution
- [Workflow Syntax Reference](workflow-syntax.md#agent-state) - Complete options
- [Interpolation Reference](interpolation.md) - Variable interpolation
