# MCP Tools Reference

## Protocol

- **Transport**: STDIO (stdin/stdout)
- **Protocol version**: `2025-11-25`
- **Server name**: `zpm`

## Server Capabilities

After initialization, the server advertises:

| Capability | Supported | Details |
|------------|-----------|---------|
| Tools | yes | `listChanged: true` |
| Resources | no | — |
| Prompts | no | — |

## Lifecycle

1. Client sends `initialize` with protocol version and client info
2. Server responds with `InitializeResult` (server info + capabilities)
3. Client sends `notifications/initialized`
4. Server accepts `tools/list` and `tools/call` requests
5. On STDIO EOF, server exits with code 0

## Tool Discovery

Send `tools/list` after the initialize handshake:

```json
{"jsonrpc":"2.0","id":2,"method":"tools/list"}
```

The response lists all registered tools with their input schemas.

## Registered Tools

| Tool | Write | Description |
|------|-------|-------------|
| `echo` | no | Connectivity test; echoes a message |
| `remember_fact` | yes | Assert a Prolog fact into the knowledge base |
| `define_rule` | yes | Assert a Prolog rule (`Head :- Body`) into the knowledge base |

## Echo

Assert-free connectivity probe. Useful for verifying the server is reachable before issuing write operations.

**Annotations**: read-only, idempotent, non-destructive.

### Input Schema

```json
{
  "type": "object",
  "properties": {
    "message": {
      "type": "string",
      "description": "The message to echo"
    }
  },
  "required": ["message"]
}
```

### Request

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "tools/call",
  "params": {
    "name": "echo",
    "arguments": {
      "message": "Hello, world!"
    }
  }
}
```

### Response (Success)

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "content": [
      {
        "type": "text",
        "text": "Hello, world!"
      }
    ]
  }
}
```

### Response (Error — missing argument)

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "content": [
      {
        "type": "text",
        "text": "InvalidArguments",
        "isError": true
      }
    ]
  }
}
```

## remember_fact

Assert a Prolog fact into the in-memory knowledge base via `assertz/1`. Facts persist for the duration of the engine session (process lifetime). Calling `remember_fact` multiple times with the same fact appends duplicate clauses; use with care.

**Annotations**: not read-only, not idempotent, not non-destructive.

### Input Schema

```json
{
  "type": "object",
  "properties": {
    "fact": {
      "type": "string",
      "description": "A Prolog fact to assert, without trailing period (e.g. \"human(socrates)\")"
    }
  },
  "required": ["fact"]
}
```

- `fact` must be non-null and non-empty.
- Do not include a trailing `.` — the tool appends it before calling `assertz`.
- The fact must be a valid Prolog term. Invalid syntax causes an engine error returned as `isError: true`.

### Request

```json
{
  "jsonrpc": "2.0",
  "id": 3,
  "method": "tools/call",
  "params": {
    "name": "remember_fact",
    "arguments": {
      "fact": "human(socrates)"
    }
  }
}
```

### Response (Success)

```json
{
  "jsonrpc": "2.0",
  "id": 3,
  "result": {
    "content": [
      {
        "type": "text",
        "text": "Asserted: human(socrates)"
      }
    ]
  }
}
```

### Response (Error — missing or empty argument)

```json
{
  "jsonrpc": "2.0",
  "id": 3,
  "result": {
    "content": [
      {
        "type": "text",
        "text": "InvalidArguments",
        "isError": true
      }
    ]
  }
}
```

### Response (Error — engine failure)

If the Prolog engine rejects the term (syntax error, etc.):

```json
{
  "jsonrpc": "2.0",
  "id": 3,
  "result": {
    "content": [
      {
        "type": "text",
        "text": "ExecutionFailed",
        "isError": true
      }
    ]
  }
}
```

## define_rule

Assert a Prolog rule (`Head :- Body`) into the knowledge base via `assertz/1`. The tool constructs the rule from the two arguments and handles the scryer-prolog `assertz` parenthesization requirement automatically.

**Annotations**: not read-only, not idempotent, not non-destructive.

**FFI note**: scryer-prolog requires that a rule passed to `assertz/1` be wrapped in an extra set of parentheses: `assertz((Head :- Body)).`. The Rust FFI layer (`ffi/zpm-prolog-ffi/src/lib.rs`) detects `:-` in the clause string and performs this wrapping automatically. Callers do not need to add extra parentheses.

### Input Schema

```json
{
  "type": "object",
  "properties": {
    "head": {
      "type": "string",
      "description": "The rule head (e.g. \"mortal(X)\")"
    },
    "body": {
      "type": "string",
      "description": "The rule body (e.g. \"human(X)\")"
    }
  },
  "required": ["head", "body"]
}
```

- Both `head` and `body` must be non-null and non-empty.
- The tool validates that parentheses in `head` and `body` are balanced before calling the engine.
- `head` must not contain `:-`; the tool constructs `Head :- Body` itself.

### Request

```json
{
  "jsonrpc": "2.0",
  "id": 4,
  "method": "tools/call",
  "params": {
    "name": "define_rule",
    "arguments": {
      "head": "mortal(X)",
      "body": "human(X)"
    }
  }
}
```

### Response (Success)

```json
{
  "jsonrpc": "2.0",
  "id": 4,
  "result": {
    "content": [
      {
        "type": "text",
        "text": "Asserted rule: mortal(X) :- human(X)"
      }
    ]
  }
}
```

### Response (Error — missing or empty argument)

```json
{
  "jsonrpc": "2.0",
  "id": 4,
  "result": {
    "content": [
      {
        "type": "text",
        "text": "InvalidArguments",
        "isError": true
      }
    ]
  }
}
```

### Response (Error — invalid Prolog syntax)

```json
{
  "jsonrpc": "2.0",
  "id": 4,
  "result": {
    "content": [
      {
        "type": "text",
        "text": "Invalid Prolog syntax in rule: unbalanced parentheses",
        "isError": true
      }
    ]
  }
}
```

## End-to-End Example

Assert a fact and a rule, then query via the Prolog engine:

```bash
# 1. Initialize session (client handles this automatically)

# 2. Assert a fact
echo '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"remember_fact","arguments":{"fact":"human(socrates)"}}}' \
  | ./zpm-server

# 3. Define a rule
echo '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"define_rule","arguments":{"head":"mortal(X)","body":"human(X)"}}}' \
  | ./zpm-server

# 4. Query (via engine.query, not yet exposed as a tool in this release)
# mortal(socrates) is now provable
```

## Error Response Shape

All errors use the same shape: an `isError: true` field on the content item, not a JSON-RPC `error` object. This follows the MCP content-level error convention.

```json
{
  "jsonrpc": "2.0",
  "id": N,
  "result": {
    "content": [
      {
        "type": "text",
        "text": "<error string>",
        "isError": true
      }
    ]
  }
}
```

Error strings returned by the tools:

| String | Meaning |
|--------|---------|
| `InvalidArguments` | Required argument missing, null, or empty |
| `ExecutionFailed` | Engine rejected the operation (syntax error, Prolog failure) |
| `Invalid Prolog syntax in rule: <detail>` | `define_rule` pre-validation caught unbalanced parentheses |
