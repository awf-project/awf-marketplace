# HTTP REST API Reference

AWF provides an HTTP REST API server for programmatic workflow execution, monitoring, and control. Start the server with `awf serve`.

## Starting the Server

```bash
awf serve                          # localhost:2511
awf serve --port 8080              # custom port
awf serve --host 0.0.0.0           # bind all interfaces
awf serve --host 0.0.0.0 --port 8080
```

The server shuts down gracefully on SIGINT or SIGTERM.

**Interactive API docs:** `http://localhost:2511/docs` — Swagger UI with auto-generated OpenAPI 3.1 spec.

## URL Grammar — scope/name

All workflow-specific routes use a two-segment `{scope}/{name}` path. The `scope` identifies the workflow source:

| Scope | Meaning |
|-------|---------|
| `local` | Non-pack workflow (local `.awf/workflows/` or global `$XDG_CONFIG_HOME/awf/workflows/`) |
| `<vendor>` | Pack workflow — use the pack's vendor/scope name (e.g., `speckit`) |

The scope values `local`, `global`, and `env` are reserved. Pack names matching any of these are rejected at install time with `USER.INPUT.VALIDATION_FAILED`.

**Examples:**

```bash
# Local workflow named "deploy-prod"
curl -X POST http://localhost:2511/api/workflows/local/deploy-prod/run \
  -H "Content-Type: application/json" \
  -d '{"inputs": {"env": "prod"}}'

# Pack workflow "specify" from pack vendor "speckit"
curl -X POST http://localhost:2511/api/workflows/speckit/specify/run \
  -H "Content-Type: application/json" \
  -d '{"inputs": {"target": "my-api"}}'
```

## When to Use the API vs CLI

| Scenario | Use |
|----------|-----|
| Interactive terminal use | `awf run` / `awf tui` |
| CI/CD pipeline (sequential) | `awf run` |
| External system integration | API (`POST /api/workflows/{scope}/{name}/run`) |
| Long-running workflow monitoring | API (`GET /api/executions/{id}/events`) |
| Parallel execution from multiple clients | API |
| Cancelling a running workflow remotely | API (`DELETE /api/executions/{id}`) |
| Resuming a paused workflow remotely | API (`POST /api/executions/{id}/resume`) |

## Endpoints

### List Available Workflows

```
GET /api/workflows
```

Returns all discoverable workflows (local, global, and from installed packs). Each entry includes `scope` and `workflow` fields to identify the source.

```bash
curl http://localhost:2511/api/workflows
```

**Response — 200 OK:**

```json
[
  {
    "name": "local/deploy-prod",
    "scope": "local",
    "workflow": "deploy-prod"
  },
  {
    "name": "speckit/specify",
    "scope": "speckit",
    "workflow": "specify"
  }
]
```

`scope` values: `env`, `local`, `global`, or the pack vendor name.

### Get Workflow Details

```
GET /api/workflows/{scope}/{name}
```

Returns metadata for a single workflow.

```bash
# Local workflow
curl http://localhost:2511/api/workflows/local/deploy-prod

# Pack workflow
curl http://localhost:2511/api/workflows/speckit/specify
```

**Response — 200 OK:**

```json
{
  "name": "deploy-prod",
  "version": "1.0.0",
  "scope": "local"
}
```

### Validate a Workflow

```
POST /api/workflows/{scope}/{name}/validate
```

Runs `awf validate` logic against the workflow and returns any errors or warnings.

```bash
# Local workflow
curl -X POST http://localhost:2511/api/workflows/local/deploy-prod/validate

# Pack workflow
curl -X POST http://localhost:2511/api/workflows/speckit/specify/validate
```

**Response — 200 OK** when valid; structured error body when validation fails.

### Run a Workflow

```
POST /api/workflows/{scope}/{name}/run
```

Starts a workflow asynchronously. Returns immediately with an execution ID.

**Request:**

```bash
# Local workflow
curl -X POST http://localhost:2511/api/workflows/local/deploy-prod/run \
  -H "Content-Type: application/json" \
  -d '{"inputs": {"env": "prod", "version": "1.2.3"}}'

# Pack workflow
curl -X POST http://localhost:2511/api/workflows/speckit/specify/run \
  -H "Content-Type: application/json" \
  -d '{"inputs": {"target": "my-api"}}'
```

**Response — 202 Accepted:**

```json
{
  "execution_id": "550e8400-e29b-41d4-a716-446655440000"
}
```

Use the returned `execution_id` to monitor progress via SSE or poll for status.

### List Active Executions

```
GET /api/executions
```

Returns all currently running or paused executions.

```bash
curl http://localhost:2511/api/executions
```

**Response — 200 OK:**

```json
[
  {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "workflow": "deploy",
    "status": "running",
    "started_at": "2026-05-17T10:00:00Z"
  }
]
```

### Get Execution Details

```
GET /api/executions/{id}
```

```bash
curl http://localhost:2511/api/executions/550e8400-e29b-41d4-a716-446655440000
```

**Response — 200 OK:**

```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "workflow": "deploy",
  "status": "running",
  "current_step": "build",
  "started_at": "2026-05-17T10:00:00Z"
}
```

### Cancel an Execution

```
DELETE /api/executions/{id}
```

Sends a cancellation signal. The execution stops at the next safe checkpoint.

```bash
curl -X DELETE http://localhost:2511/api/executions/550e8400-e29b-41d4-a716-446655440000
```

**Response — 200 OK** on success; **404** if execution not found.

### Resume a Paused Execution

```
POST /api/executions/{id}/resume
```

Resumes a workflow paused at an interactive breakpoint or after a failure with `continue_on_error`.

```bash
curl -X POST http://localhost:2511/api/executions/550e8400-e29b-41d4-a716-446655440000/resume
```

**Response — 200 OK** on success; **404** if execution not found.

### Stream Execution Events (SSE)

```
GET /api/executions/{id}/events
```

Returns a Server-Sent Events stream for real-time execution progress. The connection stays open until the workflow completes or fails.

```bash
curl -N http://localhost:2511/api/executions/550e8400-e29b-41d4-a716-446655440000/events
```

**Event stream format:**

```
data: {"type":"step.started","step":"build","timestamp":"2026-05-17T10:00:01Z"}

data: {"type":"output.line","step":"build","line":"Compiling...","timestamp":"2026-05-17T10:00:02Z"}

data: {"type":"step.done","step":"build","status":"success","timestamp":"2026-05-17T10:00:05Z"}

data: {"type":"terminal","status":"success","timestamp":"2026-05-17T10:00:12Z"}
```

#### SSE Event Types

| Type | Emitted when |
|------|-------------|
| `step.started` | A step begins executing |
| `step.done` | A step finishes (replaces `step.completed` in facade path; check `status` field) |
| `step.completed` | A step finishes (check `exit_code` for outcome) |
| `output.line` | A streaming output line from a running step |
| `workflow.completed` | Workflow reaches a terminal success state |
| `workflow.failed` | Workflow reaches a terminal failure state |
| `input.required` | Workflow is paused waiting for user input |

The facade event types (`step.done`, `output.line`, `terminal`) are the canonical events. Legacy types remain for backward compatibility.

Each event is a JSON object with at minimum `type` and `timestamp` fields. Step events include `step` (state name). `step.completed` includes `exit_code`. `input.required` includes `prompt` with the text shown to the user.

**`input.required` example:**

```
data: {"type":"input.required","prompt":"Enter the deployment target:","timestamp":"2026-05-17T10:00:08Z"}
```

Clients receiving `input.required` should display the `prompt` to the user and submit the response via `POST /api/executions/{id}/resume`.

### Get Synchronous Terminal Result

```
POST /api/executions/{id}/respond
```

Blocks until the execution reaches a terminal state, then returns the final `terminal` event as a JSON response. Use this for clients that cannot consume SSE.

```bash
curl -X POST http://localhost:2511/api/executions/550e8400-e29b-41d4-a716-446655440000/respond
```

**Response — 200 OK** (workflow succeeded):

```json
{"type":"terminal","status":"success","timestamp":"2026-05-17T10:00:12Z"}
```

**Response — 200 OK** (workflow failed — check `status` field):

```json
{"type":"terminal","status":"failed","timestamp":"2026-05-17T10:00:12Z"}
```

**Response — 404** if execution not found.

### List Execution History

```
GET /api/history
```

Lists past (completed) executions. Supports filtering.

| Query parameter | Description |
|----------------|-------------|
| `workflow` | Filter by workflow name |
| `status` | Filter by status (`success`, `failed`, `interrupted`) |
| `since` | Start date filter (ISO 8601, e.g. `2026-05-01T00:00:00Z`) |
| `until` | End date filter (ISO 8601) |

```bash
# All history
curl http://localhost:2511/api/history

# Filter by workflow and status
curl "http://localhost:2511/api/history?workflow=deploy&status=failed"

# Date range
curl "http://localhost:2511/api/history?since=2026-05-01T00:00:00Z&until=2026-05-17T23:59:59Z"
```

**Response — 200 OK:**

```json
[
  {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "workflow": "deploy",
    "status": "success",
    "started_at": "2026-05-17T10:00:00Z",
    "completed_at": "2026-05-17T10:00:12Z",
    "duration_ms": 12000
  }
]
```

### Execution Statistics

```
GET /api/history/stats
```

Returns aggregate execution statistics.

```bash
curl http://localhost:2511/api/history/stats
```

**Response — 200 OK:**

```json
{
  "total": 42,
  "success": 38,
  "failed": 3,
  "interrupted": 1
}
```

## Error Responses

Errors follow RFC 7807 (Problem Details). All error responses include `status`, `title`, and `detail` fields.

```json
{
  "status": 404,
  "title": "Not Found",
  "detail": "execution 550e8400 not found"
}
```

## Common Patterns

### Fire and Monitor

Start a workflow and stream its events until completion:

```bash
# Start a local workflow
EXEC_ID=$(curl -s -X POST http://localhost:2511/api/workflows/local/deploy/run \
  -H "Content-Type: application/json" \
  -d '{"inputs": {"env": "prod"}}' | jq -r .execution_id)

# Stream events
curl -N "http://localhost:2511/api/executions/$EXEC_ID/events"
```

### Poll for Completion

For clients without SSE support, poll execution status:

```bash
EXEC_ID="550e8400-e29b-41d4-a716-446655440000"

while true; do
  STATUS=$(curl -s "http://localhost:2511/api/executions/$EXEC_ID" | jq -r .status)
  echo "Status: $STATUS"
  [ "$STATUS" = "success" ] || [ "$STATUS" = "failed" ] && break
  sleep 2
done
```

## Architecture Notes

The API adapter lives at `internal/interfaces/api/` and imports nothing from `internal/infrastructure/`. All four interface entry points (CLI, TUI, HTTP, ACP) call `WorkflowFacade` methods (`Run`, `Validate`, `List`, `History`) instead of calling application services directly. The SSE handler and `respond` handler consume the `WorkflowFacade.Run` event channel and emit typed facade events, replacing the previous polling model. Built with Huma v2 (OpenAPI 3.1 generation) and chi v5 (routing). The default port 2511 is fixed; use `--port` to override.

**Details**: [CLI Commands - awf serve](cli-commands.md#awf-serve) | [Architecture](architecture.md)
