# Agent Exchange Transcript

## Overview

AWF records a canonical, append-only JSONL transcript of every agent step execution. Each run produces a single file containing all user messages, assistant responses, tool calls, and tool results in chronological order.

- Automatic — no configuration required; enabled for all `awf run` executions
- Provider-agnostic — normalises Claude, Gemini, Codex, Copilot, and OpenAI-compatible output into a unified schema
- Replayable — one file per run ID; reader replays events in order
- Nested — `call_workflow` sub-executions append to the same transcript file

## File Location

```
storage/transcripts/<run-id>.jsonl
```

- `<run-id>` is a unique identifier generated per `awf run` invocation
- Path is relative to the working directory where AWF was invoked
- Each line is a self-contained JSON object (an `Event`)

## JSONL Schema

### Event envelope

Each line in the file is an `Event`:

```json
{
  "role": "assistant",
  "content": [...],
  "run_id": "abc123",
  "metadata": {
    "step": "analyze",
    "provider": "claude"
  }
}
```

| Field | Type | Description |
|-------|------|-------------|
| `role` | string | `user`, `assistant`, or `tool` |
| `content` | array | Ordered list of `ContentBlock` objects |
| `run_id` | string | Unique run identifier; same value across all events in one file |
| `metadata` | object | Step name, provider, and other execution context |

### ContentBlock types

Each element of `content` is one of:

| `type` | Role | Fields | Description |
|---------|------|--------|-------------|
| `text` | any | `text` string | Plain text output |
| `tool_use` | assistant | `tool_use_id`, `name`, `input` object | Tool invocation by the agent |
| `tool_result` | tool | `tool_use_id`, `content` string | Result returned by the tool |
| `thinking` | assistant | `thinking` string | Extended thinking block (Claude) |
| `error` | any | `message` string | Execution error captured in-band |

#### text block

```json
{"type": "text", "text": "The analysis is complete."}
```

#### tool_use block

```json
{
  "type": "tool_use",
  "tool_use_id": "toolu_01",
  "name": "bash",
  "input": {"command": "make test"}
}
```

#### tool_result block

```json
{
  "type": "tool_result",
  "tool_use_id": "toolu_01",
  "content": "All 42 tests passed."
}
```

#### thinking block

```json
{"type": "thinking", "thinking": "I need to check the dependencies first..."}
```

#### error block

```json
{"type": "error", "message": "provider timeout after 120s"}
```

## Querying with jq

```bash
# All assistant text blocks from a run
jq 'select(.role == "assistant") | .content[] | select(.type == "text") | .text' \
  storage/transcripts/<run-id>.jsonl

# All tool calls
jq 'select(.role == "assistant") | .content[] | select(.type == "tool_use") | {name, input}' \
  storage/transcripts/<run-id>.jsonl

# Tool results
jq 'select(.role == "tool") | .content[] | select(.type == "tool_result") | .content' \
  storage/transcripts/<run-id>.jsonl

# Errors in a run
jq 'select(.content[].type == "error") | .content[] | select(.type == "error") | .message' \
  storage/transcripts/<run-id>.jsonl

# Step-by-step summary
jq '{role, step: .metadata.step, provider: .metadata.provider}' \
  storage/transcripts/<run-id>.jsonl
```

## Architecture

The transcript system follows hexagonal architecture:

- **Domain**: `ContentBlock` union type (`internal/domain/transcript/content.go`); `Event` envelope (`internal/domain/transcript/event.go`)
- **Port**: `Recorder` interface (`Emit` / `Close`); `AgentOutputNormalizer` for provider translation
- **Infrastructure**: `JSONLRecorder` writes atomic-append JSONL per run; `FanoutRecorder` multiplexes to N backends; `Reader` replays events
- **Wiring**: CLI `run.go` constructs recorder via `BuildTranscriptRecorder`; injected into `ExecutionService`, tool proxy, and sub-workflow executor

Provider normalisers translate raw CLI output (Claude, Gemini, Codex, Copilot, OpenAI-compatible JSONL envelopes) into `ContentBlock` slices before writing.

## Relation to Audit Trail

The transcript and audit trail serve different purposes:

| | Audit Trail | Transcript |
|-|-------------|------------|
| Location | `$XDG_DATA_HOME/awf/audit.jsonl` | `storage/transcripts/<run-id>.jsonl` |
| Granularity | Workflow-level (started/completed) | Step-level (every message and tool call) |
| Content | Timing, exit code, masked inputs | Full agent exchange content |
| Configurable | Yes (`AWF_AUDIT_LOG`) | No (always on) |

See [Audit Trail Reference](audit-trail.md) for workflow-level execution history.
