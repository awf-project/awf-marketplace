# Exit Codes

| Code | Type | Description |
|------|------|-------------|
| 0 | Success | Workflow completed successfully |
| 1 | User Error | Bad input, missing file |
| 2 | Workflow Error | Invalid workflow definition |
| 3 | Execution Error | Command failed, timeout |
| 4 | System Error | IO error, permission denied |

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

```bash
awf run deploy
# Error: step 'build' failed with exit code 1
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
