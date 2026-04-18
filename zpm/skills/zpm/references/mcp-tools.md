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
| `forget_fact` | yes | Retract the first matching fact from the knowledge base; single-retract semantics |
| `clear_context` | yes | Retract all facts matching a category pattern; always succeeds (ISO `retractall` semantics) |
| `update_fact` | yes | Atomic retract+assert; replaces `old_fact` with `new_fact`; returns `ExecutionFailed` if old fact absent |
| `upsert_fact` | yes | Match by functor+first argument, retract all matches, assert new fact; always succeeds |
| `assume_fact` | yes | Assert a fact under a named assumption; stores justification metadata for TMS tracking |
| `get_belief_status` | no | Query whether a belief is currently supported and which assumptions justify it |
| `get_justification` | no | List all facts currently supported by a given named assumption |
| `list_assumptions` | no | Enumerate all active assumptions and the facts each one supports |
| `retract_assumption` | yes | Retract a single named assumption and propagate removal to all dependent facts |
| `retract_assumptions` | yes | Bulk-retract all assumptions matching a glob-style pattern and their dependent facts |
| `save_snapshot` | yes | Create a named point-in-time snapshot of the knowledge base |
| `restore_snapshot` | yes | Restore from a named snapshot and replay subsequent journal entries |
| `list_snapshots` | no | List all available snapshots with metadata |
| `get_persistence_status` | no | Query journal size, last snapshot name, and operational mode (durable / degraded) |

All write tools (`remember_fact`, `forget_fact`, `update_fact`, `upsert_fact`, `assume_fact`, `define_rule`, `clear_context`, `retract_assumption`, `retract_assumptions`) automatically journal mutations through the WAL. When the persistence layer fails to initialise, the server runs in degraded mode: writes still execute against the in-memory engine but are not durable. Use `get_persistence_status` to inspect operational mode at runtime.

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

## forget_fact

Retract the first fact in the knowledge base that unifies with the given pattern, using `retract/1` wrapped in `once/1` for deterministic single-retract semantics. Returns `ExecutionFailed` when no matching fact exists. Does not remove rules (clauses with a body).

**Annotations**: not read-only, not idempotent, destructive.

### Input Schema

```json
{
  "type": "object",
  "properties": {
    "fact": {
      "type": "string",
      "description": "A Prolog fact to retract, without trailing period (e.g. \"human(socrates)\")"
    }
  },
  "required": ["fact"]
}
```

- `fact` must be non-null and non-empty.
- Do not include a trailing `.`.
- Only the first matching clause is removed. Call multiple times to remove duplicates.
- Use `clear_context` for bulk removal of all facts matching a predicate pattern.

### Request

```json
{
  "jsonrpc": "2.0",
  "id": 14,
  "method": "tools/call",
  "params": {
    "name": "forget_fact",
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
  "id": 14,
  "result": {
    "content": [
      {
        "type": "text",
        "text": "Retracted: human(socrates)"
      }
    ]
  }
}
```

### Response (Error — fact not found)

```json
{
  "jsonrpc": "2.0",
  "id": 14,
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

### Response (Error — missing argument)

```json
{
  "jsonrpc": "2.0",
  "id": 14,
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

## clear_context

Retract all facts in the knowledge base that unify with the given category pattern, using `retractall/1`. Always succeeds per ISO Prolog semantics, even when the pattern matches no clauses.

**Annotations**: not read-only, not idempotent, destructive.

### Input Schema

```json
{
  "type": "object",
  "properties": {
    "category": {
      "type": "string",
      "description": "A Prolog term pattern for bulk retraction (e.g. \"human(_)\" removes all human/1 facts)"
    }
  },
  "required": ["category"]
}
```

- `category` must be non-null and non-empty.
- Use wildcard arguments (`_`) to match any term: `human(_)` retracts all `human/1` facts.
- Never fails — returns success even when no facts match the pattern.
- Use `forget_fact` when single-retract (first-match, deterministic) semantics are required.

### Request

```json
{
  "jsonrpc": "2.0",
  "id": 15,
  "method": "tools/call",
  "params": {
    "name": "clear_context",
    "arguments": {
      "category": "human(_)"
    }
  }
}
```

### Response (Success — facts cleared)

```json
{
  "jsonrpc": "2.0",
  "id": 15,
  "result": {
    "content": [
      {
        "type": "text",
        "text": "Cleared: human(_)"
      }
    ]
  }
}
```

### Response (Success — no matching facts)

Always returns success per ISO `retractall/1` semantics:

```json
{
  "jsonrpc": "2.0",
  "id": 15,
  "result": {
    "content": [
      {
        "type": "text",
        "text": "Cleared: unknown_predicate(_)"
      }
    ]
  }
}
```

### Response (Error — missing argument)

```json
{
  "jsonrpc": "2.0",
  "id": 15,
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

## update_fact

Atomically retracts `old_fact` and asserts `new_fact`. Returns `ExecutionFailed` without modifying the knowledge base when `old_fact` is not found.

### Input Schema

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `old_fact` | string | yes | Prolog fact to retract (no trailing `.`) |
| `new_fact` | string | yes | Prolog fact to assert in its place (no trailing `.`) |

- Both arguments must be non-null and non-empty.
- Functor and arity of `old_fact` and `new_fact` may differ.
- The operation is atomic: either both retract and assert succeed, or neither takes effect.

### Request

```json
{
  "jsonrpc": "2.0",
  "id": 16,
  "method": "tools/call",
  "params": {
    "name": "update_fact",
    "arguments": {
      "old_fact": "human(socrates)",
      "new_fact": "human(plato)"
    }
  }
}
```

### Response (Success)

```json
{
  "jsonrpc": "2.0",
  "id": 16,
  "result": {
    "content": [
      {
        "type": "text",
        "text": "Updated: human(socrates) -> human(plato)"
      }
    ]
  }
}
```

### Response (Error — old fact not found)

```json
{
  "jsonrpc": "2.0",
  "id": 16,
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

### Response (Error — missing argument)

```json
{
  "jsonrpc": "2.0",
  "id": 16,
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

## upsert_fact

Matches by functor and first argument via `retractall/1`, then asserts the new fact via `assertz/1`. Always succeeds — inserts if no match exists, replaces if one or more matches exist.

### Input Schema

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `fact` | string | yes | Prolog fact to upsert (no trailing `.`) |

- Argument must be non-null and non-empty.
- The match key is functor + first argument; all facts sharing that key are removed before assertion.
- Calling twice with the same functor+first-arg leaves exactly one fact in the knowledge base.

### Request

```json
{
  "jsonrpc": "2.0",
  "id": 17,
  "method": "tools/call",
  "params": {
    "name": "upsert_fact",
    "arguments": {
      "fact": "age(socrates, 70)"
    }
  }
}
```

### Response (Success — replaced)

```json
{
  "jsonrpc": "2.0",
  "id": 17,
  "result": {
    "content": [
      {
        "type": "text",
        "text": "Upserted: age(socrates, 70)"
      }
    ]
  }
}
```

### Response (Success — inserted, no prior match)

Same shape as the replace response; the tool does not distinguish insert from replace in the success text:

```json
{
  "jsonrpc": "2.0",
  "id": 17,
  "result": {
    "content": [
      {
        "type": "text",
        "text": "Upserted: age(socrates, 70)"
      }
    ]
  }
}
```

### Response (Error — missing argument)

```json
{
  "jsonrpc": "2.0",
  "id": 17,
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

## assume_fact

Assert a fact under a named assumption with justification tracking. The assumption name and the asserted fact are stored as Prolog metadata, enabling belief propagation and grouped retraction.

### Input Schema

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `assumption` | string | yes | Name of the assumption group (e.g. `"hypothesis_1"`) |
| `fact` | string | yes | Prolog fact to assert (no trailing `.`) |

- Both arguments must be non-null and non-empty.
- `assumption` is a user-defined label; it need not be a valid Prolog term.
- Asserting the same fact under two different assumptions creates two justification records.

### Request

```json
{
  "jsonrpc": "2.0",
  "id": 18,
  "method": "tools/call",
  "params": {
    "name": "assume_fact",
    "arguments": { "assumption": "hypothesis_1", "fact": "flies(tweety)" }
  }
}
```

### Response (Success)

```json
{
  "jsonrpc": "2.0",
  "id": 18,
  "result": {
    "content": [
      {
        "type": "text",
        "text": "Assumed: flies(tweety) under hypothesis_1"
      }
    ]
  }
}
```

### Response (Error — missing argument)

```json
{
  "jsonrpc": "2.0",
  "id": 18,
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

## get_belief_status

Query whether a belief is currently supported and which assumptions justify it.

### Input Schema

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `belief` | string | yes | Prolog fact to query (no trailing `.`) |

- `belief` must be non-null and non-empty.
- Returns supported state based on current justification records; retracting an assumption may change the result.

### Request

```json
{
  "jsonrpc": "2.0",
  "id": 19,
  "method": "tools/call",
  "params": {
    "name": "get_belief_status",
    "arguments": { "belief": "flies(tweety)" }
  }
}
```

### Response (Success — belief supported)

```json
{
  "jsonrpc": "2.0",
  "id": 19,
  "result": {
    "content": [
      {
        "type": "text",
        "text": "{\"supported\":true,\"assumptions\":[\"hypothesis_1\"]}"
      }
    ]
  }
}
```

### Response (Success — belief not supported)

```json
{
  "jsonrpc": "2.0",
  "id": 19,
  "result": {
    "content": [
      {
        "type": "text",
        "text": "{\"supported\":false,\"assumptions\":[]}"
      }
    ]
  }
}
```

### Response (Error — missing argument)

```json
{
  "jsonrpc": "2.0",
  "id": 19,
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

## get_justification

List all facts currently supported by a given named assumption.

### Input Schema

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `assumption` | string | yes | Name of the assumption to query |

- `assumption` must be non-null and non-empty.
- Returns an empty array when no facts are currently under the named assumption.

### Request

```json
{
  "jsonrpc": "2.0",
  "id": 20,
  "method": "tools/call",
  "params": {
    "name": "get_justification",
    "arguments": { "assumption": "hypothesis_1" }
  }
}
```

### Response (Success — facts found)

```json
{
  "jsonrpc": "2.0",
  "id": 20,
  "result": {
    "content": [
      {
        "type": "text",
        "text": "[\"flies(tweety)\",\"mortal(tweety)\"]"
      }
    ]
  }
}
```

### Response (Success — no facts under assumption)

```json
{
  "jsonrpc": "2.0",
  "id": 20,
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
  "id": 20,
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

## list_assumptions

Enumerate all active assumptions and the facts each one supports.

### Input Schema

No required arguments. Pass an empty arguments object.

### Request

```json
{
  "jsonrpc": "2.0",
  "id": 21,
  "method": "tools/call",
  "params": {
    "name": "list_assumptions",
    "arguments": {}
  }
}
```

### Response (Success — assumptions found)

```json
{
  "jsonrpc": "2.0",
  "id": 21,
  "result": {
    "content": [
      {
        "type": "text",
        "text": "[{\"assumption\":\"hypothesis_1\",\"facts\":[\"flies(tweety)\"]},{\"assumption\":\"default_rules\",\"facts\":[\"mortal(X)\"]}]"
      }
    ]
  }
}
```

### Response (Success — no active assumptions)

```json
{
  "jsonrpc": "2.0",
  "id": 21,
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

## retract_assumption

Retract a single named assumption and propagate removal to all facts that were asserted under it.

### Input Schema

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `assumption` | string | yes | Name of the assumption to retract |

- `assumption` must be non-null and non-empty.
- Returns `ExecutionFailed` when the named assumption does not exist.
- All dependent facts are removed atomically.

### Request

```json
{
  "jsonrpc": "2.0",
  "id": 22,
  "method": "tools/call",
  "params": {
    "name": "retract_assumption",
    "arguments": { "assumption": "hypothesis_1" }
  }
}
```

### Response (Success)

```json
{
  "jsonrpc": "2.0",
  "id": 22,
  "result": {
    "content": [
      {
        "type": "text",
        "text": "Retracted assumption: hypothesis_1"
      }
    ]
  }
}
```

### Response (Error — assumption not found)

```json
{
  "jsonrpc": "2.0",
  "id": 22,
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

### Response (Error — missing argument)

```json
{
  "jsonrpc": "2.0",
  "id": 22,
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

## retract_assumptions

Bulk-retract all assumptions whose names match a glob-style pattern and remove all their dependent facts.

### Input Schema

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `pattern` | string | yes | Glob pattern to match assumption names (e.g. `"hypothesis_*"`) |

- `pattern` must be non-null and non-empty.
- `*` matches any sequence of characters within an assumption name.
- Succeeds with count 0 when no assumptions match; never errors on empty matches.

### Request

```json
{
  "jsonrpc": "2.0",
  "id": 23,
  "method": "tools/call",
  "params": {
    "name": "retract_assumptions",
    "arguments": { "pattern": "hypothesis_*" }
  }
}
```

### Response (Success — assumptions matched)

```json
{
  "jsonrpc": "2.0",
  "id": 23,
  "result": {
    "content": [
      {
        "type": "text",
        "text": "Retracted 2 assumptions matching: hypothesis_*"
      }
    ]
  }
}
```

### Response (Success — no assumptions matched)

```json
{
  "jsonrpc": "2.0",
  "id": 23,
  "result": {
    "content": [
      {
        "type": "text",
        "text": "Retracted 0 assumptions matching: hypothesis_*"
      }
    ]
  }
}
```

### Response (Error — missing argument)

```json
{
  "jsonrpc": "2.0",
  "id": 23,
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

## save_snapshot

Create a named point-in-time snapshot of the entire knowledge base. The snapshot becomes the new replay base on the next process startup; subsequent WAL entries are layered on top of it during recovery.

### Input Schema

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | yes | Snapshot identifier (must be unique or will overwrite an existing snapshot of the same name) |

- `name` must be non-null and non-empty.
- Returns `ExecutionFailed` when the persistence layer is in degraded mode.
- Overwrites any existing snapshot with the same name without warning.

### Request

```json
{
  "jsonrpc": "2.0",
  "id": 24,
  "method": "tools/call",
  "params": {
    "name": "save_snapshot",
    "arguments": { "name": "before_migration" }
  }
}
```

### Response (Success)

```json
{
  "jsonrpc": "2.0",
  "id": 24,
  "result": {
    "content": [
      {
        "type": "text",
        "text": "Saved snapshot: before_migration"
      }
    ]
  }
}
```

### Response (Error — degraded mode)

```json
{
  "jsonrpc": "2.0",
  "id": 24,
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

### Response (Error — missing argument)

```json
{
  "jsonrpc": "2.0",
  "id": 24,
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

## restore_snapshot

Restore the knowledge base from a named snapshot and replay any WAL entries written after that snapshot. Destructive: the current knowledge base is replaced in full.

### Input Schema

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | yes | Name of the snapshot to restore |

- `name` must be non-null and non-empty.
- Returns `ExecutionFailed` when the named snapshot does not exist.
- Replaces the in-memory knowledge base entirely; non-snapshotted, non-journalled state is lost.
- WAL replay continues from the snapshot's sequence number, so post-snapshot writes are preserved.

### Request

```json
{
  "jsonrpc": "2.0",
  "id": 25,
  "method": "tools/call",
  "params": {
    "name": "restore_snapshot",
    "arguments": { "name": "before_migration" }
  }
}
```

### Response (Success)

```json
{
  "jsonrpc": "2.0",
  "id": 25,
  "result": {
    "content": [
      {
        "type": "text",
        "text": "Restored snapshot: before_migration"
      }
    ]
  }
}
```

### Response (Error — snapshot not found)

```json
{
  "jsonrpc": "2.0",
  "id": 25,
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

### Response (Error — missing argument)

```json
{
  "jsonrpc": "2.0",
  "id": 25,
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

## list_snapshots

Enumerate all snapshots known to the persistence layer with their metadata. Read-only.

### Input Schema

No arguments. Pass an empty object `{}`.

### Request

```json
{
  "jsonrpc": "2.0",
  "id": 26,
  "method": "tools/call",
  "params": {
    "name": "list_snapshots",
    "arguments": {}
  }
}
```

### Response (Success — snapshots found)

```json
{
  "jsonrpc": "2.0",
  "id": 26,
  "result": {
    "content": [
      {
        "type": "text",
        "text": "[{\"name\":\"before_migration\",\"sequence\":42,\"created_at\":\"2026-04-18T10:14:22Z\"}]"
      }
    ]
  }
}
```

### Response (Success — no snapshots)

```json
{
  "jsonrpc": "2.0",
  "id": 26,
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

## get_persistence_status

Report the operational state of the persistence layer. Use to confirm durability before relying on WAL recovery, or to diagnose why a `save_snapshot` returned `ExecutionFailed`.

### Input Schema

No arguments. Pass an empty object `{}`.

### Request

```json
{
  "jsonrpc": "2.0",
  "id": 27,
  "method": "tools/call",
  "params": {
    "name": "get_persistence_status",
    "arguments": {}
  }
}
```

### Response (Success — durable)

```json
{
  "jsonrpc": "2.0",
  "id": 27,
  "result": {
    "content": [
      {
        "type": "text",
        "text": "{\"mode\":\"durable\",\"journal_entries\":128,\"last_snapshot\":\"before_migration\",\"last_sequence\":170}"
      }
    ]
  }
}
```

### Response (Success — degraded)

```json
{
  "jsonrpc": "2.0",
  "id": 27,
  "result": {
    "content": [
      {
        "type": "text",
        "text": "{\"mode\":\"degraded\",\"journal_entries\":0,\"last_snapshot\":null,\"last_sequence\":0}"
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
