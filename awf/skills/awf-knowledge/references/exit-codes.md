# Exit Codes

| Code | Type | Description |
|------|------|-------------|
| 0 | Success | Workflow completed successfully |
| 1 | User Error | Bad input, missing file |
| 2 | Workflow Error | Invalid workflow definition |
| 3 | Execution Error | Command failed, timeout |
| 4 | System Error | IO error, permission denied |

> Error codes are consistent across all AWF interfaces — the same exit code semantics apply whether running via awf run, awf serve, awf tui, or awf acp-serve (ACP uses JSON-RPC error objects but maps to the same categories).

## Exit Code 0: Success

Workflow reached terminal state with `status: success`.

## Exit Code 1: User Error

- Invalid command-line flag
- Missing required input
- Workflow file not found
- Input validation failed

```bash
awf run deploy
# Error: missing required input: env

awf run my-workflow
# Error [USER.INPUT.MISSING_SKILL]: skill "code-review" not found in any skills directory

awf run my-workflow
# Error [USER.INPUT.MISSING_ROLE]: role "go-senior" not found
```

## Exit Code 2: Workflow Error

- Invalid state reference
- Cycle detected
- Missing terminal state
- Invalid template reference

```bash
awf validate my-workflow
# Error: state 'missing' not defined
```

## Exit Code 3: Execution Error

- Command returned non-zero
- Command timed out
- Retry attempts exhausted
- Operation from disabled plugin invoked at run time
- Plugin binary checksum mismatch (`EXECUTION.PLUGIN.CHECKSUM_MISMATCH`)

```bash
awf run deploy
# Error: step 'build' failed with exit code 1

awf run my-workflow
# Error: step 'notify_team' uses plugin 'notify' which is disabled
# Run 'awf plugin enable notify' to enable it

awf run my-workflow
# Error: plugin 'awf-plugin-slack' binary checksum mismatch (EXECUTION.PLUGIN.CHECKSUM_MISMATCH)
```

## Exit Code 4: System Error

- Permission denied
- Disk full
- Database error

## Script Usage

```bash
awf run deploy --input env=prod
case $? in
  0) echo "Success" ;;
  1) echo "Invalid input" ;;
  2) echo "Workflow error" ;;
  3) echo "Execution failed" ;;
  4) echo "System error" ;;
esac
```

## JSON Output

```bash
awf run deploy -f json
```

```json
{
  "success": false,
  "error": {
    "code": 3,
    "type": "execution_error",
    "message": "step 'build' failed with exit code 1",
    "step": "build"
  }
}
```

> **Output Routing**: JSON error responses are always written to **stderr**, not stdout. This preserves stdout cleanliness for script piping contracts. Check `stderr` when consuming JSON errors programmatically.

## ACP Error Codes

The `awf acp-serve` server returns JSON-RPC error objects instead of process exit codes. These are not process-level exit codes — they appear in JSON-RPC error responses.

| Code | Meaning |
|------|---------|
| `ACP.SESSION_NOT_FOUND` | Session ID does not exist or has expired |
| `ACP.WORKFLOW_NOT_FOUND` | Named slash command targets a workflow not in the catalog |
| `ACP.INVALID_COMMAND` | Slash command name failed name-encoding validation |

```json
{
  "jsonrpc": "2.0",
  "id": 2,
  "error": {
    "code": -32602,
    "message": "ACP.WORKFLOW_NOT_FOUND",
    "data": {"command": "/unknown__workflow"}
  }
}
```
