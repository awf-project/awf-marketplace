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
| `query_logic` | no | Execute a Prolog goal; returns all variable bindings as a JSON array |
| `trace_dependency` | no | Traverse transitive dependencies via `path/2` rules; returns reachable node names |
| `verify_consistency` | no | Query all `integrity_violation/N` predicates; returns constraint breaches as JSON |
| `explain_why` | no | Reconstruct the proof chain for a fact via `clause/2`; returns a nested proof tree |
| `get_knowledge_schema` | no | Introspect the knowledge base; returns all user-defined predicates with arity and clause type |

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

## query_logic

Execute an arbitrary Prolog goal against the in-process engine. Returns all solutions as a JSON array of variable-binding objects. Read-only and idempotent; does not modify the knowledge base.

**Annotations**: read-only, idempotent, non-destructive.

### Input Schema

```json
{
  "type": "object",
  "properties": {
    "goal": {
      "type": "string",
      "description": "A Prolog goal to execute, without trailing period (e.g. \"mortal(X)\")"
    }
  },
  "required": ["goal"]
}
```

- `goal` must be non-null and non-empty.
- Do not include a trailing `.`.
- The goal is executed against the current knowledge base state.

### Request

```json
{
  "jsonrpc": "2.0",
  "id": 5,
  "method": "tools/call",
  "params": {
    "name": "query_logic",
    "arguments": {
      "goal": "mortal(X)"
    }
  }
}
```

### Response (Success — solutions found)

Each object in the array maps variable names to their bound values.

```json
{
  "jsonrpc": "2.0",
  "id": 5,
  "result": {
    "content": [
      {
        "type": "text",
        "text": "[{\"X\":\"socrates\"}]"
      }
    ]
  }
}
```

### Response (Success — no solutions)

```json
{
  "jsonrpc": "2.0",
  "id": 5,
  "result": {
    "content": [
      {
        "type": "text",
        "text": "[]"
      }
    ]
  }
}
```

### Response (Error — missing argument)

```json
{
  "jsonrpc": "2.0",
  "id": 5,
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

### Response (Error — engine unavailable)

```json
{
  "jsonrpc": "2.0",
  "id": 5,
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

## trace_dependency

Traverse all nodes reachable from a start node using `path/2` rules already asserted in the knowledge base. Returns a JSON array of dependency names (strings). Read-only and idempotent.

**Annotations**: read-only, idempotent, non-destructive.

`path/2` rules must be present in the knowledge base before calling this tool. Assert them with `define_rule` (e.g. `path(a, b)`, `path(b, c)`) or load them from a file via the engine API. The tool queries `path(Start, X)` and collects all solutions for `X`.

### Input Schema

```json
{
  "type": "object",
  "properties": {
    "start": {
      "type": "string",
      "description": "The start node atom (e.g. \"a\")"
    }
  },
  "required": ["start"]
}
```

- `start` must be non-null and non-empty.
- `path/2` rules must be loaded before calling; an empty graph returns `[]`, not an error.

### Request

```json
{
  "jsonrpc": "2.0",
  "id": 6,
  "method": "tools/call",
  "params": {
    "name": "trace_dependency",
    "arguments": {
      "start": "a"
    }
  }
}
```

### Response (Success — dependencies found)

```json
{
  "jsonrpc": "2.0",
  "id": 6,
  "result": {
    "content": [
      {
        "type": "text",
        "text": "[\"b\",\"c\"]"
      }
    ]
  }
}
```

### Response (Success — no dependencies / empty graph)

```json
{
  "jsonrpc": "2.0",
  "id": 6,
  "result": {
    "content": [
      {
        "type": "text",
        "text": "[]"
      }
    ]
  }
}
```

### Response (Error — missing argument)

```json
{
  "jsonrpc": "2.0",
  "id": 6,
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

## verify_consistency

Queries all `integrity_violation/N` predicates loaded in the knowledge base and returns every constraint breach as a structured JSON object. An empty violations array means no constraints are violated; this is not an error.

Accepts an optional `domain` argument to scope the check. If omitted, all integrity violations in the knowledge base are checked. Handles null args and engine-unavailable paths explicitly.

### Input Schema

```json
{
  "type": "object",
  "properties": {
    "domain": {
      "type": "string",
      "description": "Optional domain to scope the consistency check."
    }
  },
  "required": []
}
```

### Request

```json
{
  "jsonrpc": "2.0",
  "id": 7,
  "method": "tools/call",
  "params": {
    "name": "verify_consistency",
    "arguments": {}
  }
}
```

### Response (Success — no violations)

```json
{
  "jsonrpc": "2.0",
  "id": 7,
  "result": {
    "content": [
      {
        "type": "text",
        "text": "{\"violations\":[]}"
      }
    ]
  }
}
```

### Response (Success — violations found)

```json
{
  "jsonrpc": "2.0",
  "id": 8,
  "result": {
    "content": [
      {
        "type": "text",
        "text": "{\"violations\":[{\"predicate\":\"integrity_violation\",\"args\":[\"duplicate_id\"]}]}"
      }
    ]
  }
}
```

### Response (Error — engine unavailable)

```json
{
  "jsonrpc": "2.0",
  "id": 9,
  "result": {
    "content": [
      {
        "type": "text",
        "text": "EngineUnavailable",
        "isError": true
      }
    ]
  }
}
```

## explain_why

Reconstructs the deduction chain for any Prolog fact by recursively querying `clause/2`. Returns a structured proof tree as nested JSON. Accepts an optional `max_depth` argument to truncate deeply recursive proofs.

Returns an empty `proof` array when the fact cannot be proven (no matching clauses). Returns `isError: true` when the required `fact` argument is missing.

### Input Schema

```json
{
  "type": "object",
  "properties": {
    "fact": {
      "type": "string",
      "description": "The Prolog fact or goal to explain (no trailing period)."
    },
    "max_depth": {
      "type": "integer",
      "description": "Optional maximum recursion depth for proof tree traversal."
    }
  },
  "required": ["fact"]
}
```

### Request

```json
{
  "jsonrpc": "2.0",
  "id": 10,
  "method": "tools/call",
  "params": {
    "name": "explain_why",
    "arguments": { "fact": "mortal(socrates)" }
  }
}
```

### Response (Success — proven)

```json
{
  "jsonrpc": "2.0",
  "id": 10,
  "result": {
    "content": [
      {
        "type": "text",
        "text": "{\"fact\":\"mortal(socrates)\",\"proof\":[{\"via\":\"mortal(X) :- human(X)\",\"premises\":[{\"fact\":\"human(socrates)\",\"proof\":[]}]}]}"
      }
    ]
  }
}
```

### Response (Success — not provable)

```json
{
  "jsonrpc": "2.0",
  "id": 11,
  "result": {
    "content": [
      {
        "type": "text",
        "text": "{\"fact\":\"mortal(plato)\",\"proof\":[]}"
      }
    ]
  }
}
```

### Response (Error — missing argument)

```json
{
  "jsonrpc": "2.0",
  "id": 12,
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

## get_knowledge_schema

Introspects the knowledge base by querying `current_predicate/1`. For each predicate, counts fact and rule clauses via `clause/2` to determine whether the predicate is defined by facts only, rules only, or both. Scryer-Prolog built-ins and predicates with unsafe atom names are filtered from results.

### Input Schema

```json
{
  "type": "object",
  "properties": {
    "domain": {
      "type": ["string", "null"],
      "description": "Optional prefix to filter predicate names. Null returns all user-defined predicates."
    }
  },
  "required": []
}
```

### Request

```json
{
  "jsonrpc": "2.0",
  "id": 13,
  "method": "tools/call",
  "params": {
    "name": "get_knowledge_schema",
    "arguments": {}
  }
}
```

### Response (Success — predicates found)

```json
{
  "jsonrpc": "2.0",
  "id": 13,
  "result": {
    "content": [
      {
        "type": "text",
        "text": "{\"predicates\":[{\"name\":\"human\",\"arity\":1,\"type\":\"fact\"},{\"name\":\"mortal\",\"arity\":1,\"type\":\"rule\"},{\"name\":\"path\",\"arity\":2,\"type\":\"both\"}],\"total\":3}"
      }
    ]
  }
}
```

### Response (Success — empty knowledge base)

```json
{
  "jsonrpc": "2.0",
  "id": 13,
  "result": {
    "content": [
      {
        "type": "text",
        "text": "{\"predicates\":[],\"total\":0}"
      }
    ]
  }
}
```

### Response (Error — engine unavailable)

```json
{
  "jsonrpc": "2.0",
  "id": 13,
  "result": {
    "content": [
      {
        "type": "text",
        "text": "EngineUnavailable",
        "isError": true
      }
    ]
  }
}
```

## End-to-End Example

Assert facts and rules, then query and trace dependencies:

```bash
# 1. Initialize session (client handles this automatically)

# 2. Assert facts
echo '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"remember_fact","arguments":{"fact":"human(socrates)"}}}' \
  | ./zpm-server

# 3. Define a rule
echo '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"define_rule","arguments":{"head":"mortal(X)","body":"human(X)"}}}' \
  | ./zpm-server

# 4. Query — returns all bindings for mortal(X)
echo '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"query_logic","arguments":{"goal":"mortal(X)"}}}' \
  | ./zpm-server
# => [{"X":"socrates"}]

# 5. Assert path/2 facts for dependency tracing
echo '{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"remember_fact","arguments":{"fact":"path(a,b)"}}}' \
  | ./zpm-server
echo '{"jsonrpc":"2.0","id":5,"method":"tools/call","params":{"name":"remember_fact","arguments":{"fact":"path(b,c)"}}}' \
  | ./zpm-server

# 6. Trace dependencies from "a"
echo '{"jsonrpc":"2.0","id":6,"method":"tools/call","params":{"name":"trace_dependency","arguments":{"start":"a"}}}' \
  | ./zpm-server
# => ["b","c"]
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
