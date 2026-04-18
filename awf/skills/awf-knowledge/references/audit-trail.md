# Audit Trail

## Overview

AWF records a structured JSONL audit trail with paired `workflow.started` / `workflow.completed` entries per execution. The audit log enables compliance logging and execution history without requiring a database.

- Paired events per execution (start + end), joined by `execution_id`
- Secret inputs masked at the application layer before reaching the writer
- Atomic `O_APPEND` writes bounded to 4 KB (POSIX PIPE_BUF) for concurrent safety
- Audit failures never block workflow execution

## Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `AWF_AUDIT_LOG` | `$XDG_DATA_HOME/awf/audit.jsonl` | Custom audit file path |
| `AWF_AUDIT_LOG=off` | (disabled) | Disable audit trail entirely (case-insensitive) |

```bash
# Custom path
export AWF_AUDIT_LOG=/var/log/awf/audit.jsonl

# Disable
export AWF_AUDIT_LOG=off

# Default (no env var needed)
# Writes to ~/.local/share/awf/audit.jsonl
```

## JSONL Schema (v1)

Each line is a self-contained JSON object. Two event types exist:

### workflow.started

```json
{
  "event": "workflow.started",
  "execution_id": "550e8400-e29b-41d4-a716-446655440000",
  "timestamp": "2026-02-22T14:30:00.123Z",
  "user": "pocky",
  "workflow_name": "deploy",
  "schema_version": 1,
  "inputs": {"env": "prod", "api_key": "***"},
  "inputs_truncated": false
}
```

### workflow.completed

```json
{
  "event": "workflow.completed",
  "execution_id": "550e8400-e29b-41d4-a716-446655440000",
  "timestamp": "2026-02-22T14:30:45.789Z",
  "user": "pocky",
  "workflow_name": "deploy",
  "schema_version": 1,
  "status": "success",
  "exit_code": 0,
  "duration_ms": 45666,
  "error": ""
}
```

### Field Reference

| Field | Type | Description |
|-------|------|-------------|
| `event` | string | `workflow.started` or `workflow.completed` |
| `execution_id` | string | UUID v4, shared between paired events |
| `timestamp` | string | ISO 8601 with millisecond precision |
| `user` | string | Resolved from `$USER`, `$LOGNAME`, or `os/user` |
| `workflow_name` | string | Name of the executed workflow |
| `schema_version` | int | Always `1` (current) |
| `inputs` | object | (started only) Workflow inputs with secrets masked |
| `inputs_truncated` | bool | (started only) `true` if inputs were truncated for 4 KB limit |
| `status` | string | (completed only) `success` or `failure` derived from exit code |
| `exit_code` | int | (completed only) Workflow exit code |
| `duration_ms` | int | (completed only) Execution duration in milliseconds |
| `error` | string | (completed only) Error message if failed, empty otherwise |

## Secret Masking

Inputs with keys matching these patterns are replaced with `***` before being written to the audit log:

- `SECRET_*`
- `API_KEY*`
- `PASSWORD*`
- `TOKEN*`

Masking happens in the application layer (`ExecutionService`) before the `AuditEvent` is constructed. The `AuditTrailWriter` port receives pre-sanitized data.

## Querying with jq

```bash
# All events for a workflow
jq 'select(.workflow_name == "deploy")' ~/.local/share/awf/audit.jsonl

# Failed executions
jq 'select(.event == "workflow.completed" and .status == "failure")' ~/.local/share/awf/audit.jsonl

# Execution duration stats
jq 'select(.event == "workflow.completed") | .duration_ms' ~/.local/share/awf/audit.jsonl

# Find incomplete executions (started but not completed)
jq -s '
  group_by(.execution_id) |
  map(select(length == 1 and .[0].event == "workflow.started")) |
  .[][0]
' ~/.local/share/awf/audit.jsonl

# Live tail
tail -f ~/.local/share/awf/audit.jsonl | jq .
```

## Size Constraints

- Each JSONL entry is bounded to 4 KB (POSIX PIPE_BUF guarantee for atomic writes)
- When inputs exceed the limit, values are progressively truncated (longest first)
- The `inputs_truncated` field is set to `true` when truncation occurs

## Architecture

The audit trail follows hexagonal architecture:

- **Domain**: `AuditEvent` model with constructors (`NewStartedEvent`, `NewCompletedEvent`)
- **Port**: `AuditTrailWriter` interface (`Write`, `Close`)
- **Infrastructure**: `FileAuditTrailWriter` with POSIX atomic append, mutex for in-process safety, 0o600 file permissions
- **Wiring**: CLI layer (`run.go`, `resume.go`) constructs the writer and injects via `SetAuditTrailWriter()`

Design decisions documented in:
- ADR-0010: Paired JSONL audit trail with atomic append
- ADR-0011: Application-layer secret masking for audit events
