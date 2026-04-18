---
name: zpm
description: ZPM MCP server - Zig-based Model Context Protocol server exposing a Scryer Prolog logic engine over STDIO. Use this skill when building, configuring, or using the ZPM server to execute Prolog queries, assert or retract facts, and load knowledge bases from MCP clients.
---

# ZPM

ZPM is an MCP server written in Zig that embeds a Scryer Prolog logic engine through a Rust FFI staticlib. Clients speak MCP over STDIO and drive Prolog operations (query, assert, retract, load file, load string) against an in-process engine.

## When to use

- Build or run the ZPM MCP server
- Execute Prolog operations from an MCP client (Claude Code, Cursor, etc.)
- Extend the Prolog engine API or its Rust FFI bridge
- Diagnose build, link, or runtime issues involving the Rust staticlib

## Architecture at a glance

```
MCP client
   |  STDIO (JSON-RPC)
   v
Zig MCP server (src/main.zig)
   |  context.getEngine() -- shared engine singleton
   v
MCP tool handlers (src/tools/*.zig)
   |  Zig Engine API (src/prolog/engine.zig)
   v
C-ABI bindings (src/prolog/ffi.zig)
   |  extern "C"
   v
Rust staticlib (ffi/zpm-prolog-ffi)
   |  in-process call
   v
Scryer Prolog
```

All layers run in a single process. The Rust staticlib is linked into the Zig binary at build time; no separate daemon or IPC is involved. `src/tools/context.zig` holds the engine singleton; `src/main.zig` initializes it at startup via `context.setEngine` and tool handlers retrieve it via `context.getEngine`. See `references/architecture.md` for the rationale (STDIO transport, FFI staticlib, engine singleton).

## Prerequisites

- Zig toolchain (as required by `build.zig`)
- Rust stable (`dtolnay/rust-toolchain@stable`) with `cargo` on `PATH`
- GNU `make`

The Rust toolchain is mandatory: `make build` invokes `ffi-build`, which compiles the Rust staticlib before linking the Zig binary.

## Build and test

| Target | Purpose |
|--------|---------|
| `make ffi-build` | Compile the Rust FFI staticlib (`ffi/zpm-prolog-ffi`) |
| `make build` | Build the full binary (depends on `ffi-build`) |
| `make test` | Run Zig unit tests (includes inline engine tests) |
| `make ffi-test` | Smoke-test that the Rust staticlib compiles (`tests/build_ffi_test.sh`) |
| `make functional-test-engine` | End-to-end engine tests (`tests/functional_prolog_engine_test.sh`) |
| `make roundtrip` | Run `examples/roundtrip.zig` (assert + query demo) |

CI runs `cargo fmt --check` and `cargo clippy` in addition to Zig lint/test/build jobs.

See `references/build.md` for layout, linking, and troubleshooting.

## MCP Tools

| Tool | Write | Description |
|------|-------|-------------|
| `echo` | no | Echoes a message; use to test connectivity |
| `remember_fact` | yes | Assert a Prolog fact into the knowledge base |
| `define_rule` | yes | Assert a Prolog rule (`Head :- Body`) into the knowledge base |
| `query_logic` | no | Execute a Prolog goal; returns all variable bindings as a JSON array |
| `trace_dependency` | no | Traverse transitive dependencies via `path/2` rules; returns reachable node names |
| `verify_consistency` | no | Query `integrity_violation/N` predicates; returns all violations as JSON |
| `explain_why` | no | Reconstruct proof chain for a fact via `clause/2`; returns a nested proof tree |

### remember_fact

Asserts a single Prolog fact via `assertz/1`. The `fact` argument must not include a trailing period.

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "tools/call",
  "params": {
    "name": "remember_fact",
    "arguments": { "fact": "human(socrates)" }
  }
}
```

Success response: `"Asserted: human(socrates)"`.

### define_rule

Asserts a Prolog rule constructed from `head` and `body` arguments. The FFI layer automatically wraps the rule in extra parentheses (`assertz((Head :- Body)).`) as required by scryer-prolog's parser.

```json
{
  "jsonrpc": "2.0",
  "id": 2,
  "method": "tools/call",
  "params": {
    "name": "define_rule",
    "arguments": { "head": "mortal(X)", "body": "human(X)" }
  }
}
```

Success response: `"Asserted rule: mortal(X) :- human(X)"`.

The tool validates parenthesis balance in `head` and `body` before calling the engine. Invalid syntax returns `isError: true` with a detail string.

### query_logic

Executes an arbitrary Prolog goal against the current knowledge base and returns all solutions as a JSON array of variable-binding objects. An empty array means the goal has no solutions; this is not an error.

```json
{
  "jsonrpc": "2.0",
  "id": 5,
  "method": "tools/call",
  "params": {
    "name": "query_logic",
    "arguments": { "goal": "mortal(X)" }
  }
}
```

Success response: `"[{\"X\":\"socrates\"}]"` (JSON array). Empty result: `"[]"`.

- Do not include a trailing `.` in `goal`.
- Read-only and idempotent — does not modify the knowledge base.

### trace_dependency

Traverses all nodes reachable from a start node by querying `path(Start, X)` against rules in the knowledge base. Returns a JSON array of dependency name strings.

```json
{
  "jsonrpc": "2.0",
  "id": 6,
  "method": "tools/call",
  "params": {
    "name": "trace_dependency",
    "arguments": { "start": "a" }
  }
}
```

Success response: `"[\"b\",\"c\"]"`. Empty graph: `"[]"`.

- `path/2` facts or rules must be asserted before calling this tool (e.g. via `remember_fact` with `"fact": "path(a,b)"`).
- Read-only and idempotent.

### verify_consistency

Queries all `integrity_violation/N` predicates and returns every breach as a JSON object. Returns `{"violations":[]}` when no violations exist (not an error). Accepts an optional `domain` argument to scope the check.

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

Success response: `"{\"violations\":[]}"` (no violations) or `"{\"violations\":[{...}]}"` (breaches found).

- Read-only and idempotent.
- Pass `"domain": "my_domain"` to restrict to violations in a specific domain scope.

### explain_why

Reconstructs the deduction chain for any Prolog fact by recursively querying `clause/2`. Returns a structured proof tree as nested JSON. An empty `proof` array means the fact cannot be proven.

```json
{
  "jsonrpc": "2.0",
  "id": 8,
  "method": "tools/call",
  "params": {
    "name": "explain_why",
    "arguments": { "fact": "mortal(socrates)" }
  }
}
```

Success response: `"{\"fact\":\"mortal(socrates)\",\"proof\":[{\"via\":\"mortal(X) :- human(X)\",\"premises\":[...]}]}"`.

- Do not include a trailing `.` in `fact`.
- Pass `"max_depth": N` to limit recursion depth for deep proof trees.
- Read-only and idempotent.

Full protocol docs, all input schemas, and error response shapes: `references/mcp-tools.md`.

## Engine API

The Zig `Engine` struct in `src/prolog/engine.zig` is the only supported entry point for Prolog operations. MCP tool handlers call it; direct use of `src/prolog/ffi.zig` is reserved for the engine implementation.

Operations:

- `init` / `deinit` — lifecycle
- `query` — execute a Prolog query, iterate bindings
- `assert` / `assertFact` — add a clause or fact to the knowledge base
- `retract` — remove a matching clause
- `loadFile` — load a `.pl` file from disk
- `loadString` — load Prolog source from memory

Full signatures, ownership rules, and error semantics: `references/prolog-engine.md`.

## Minimal usage pattern

```zig
const std = @import("std");
const prolog = @import("prolog");

pub fn main() !void {
    var engine = try prolog.Engine.init(std.heap.page_allocator);
    defer engine.deinit();

    try engine.assert("parent(alice, bob).");
    var results = try engine.query("parent(alice, X).");
    defer results.deinit();
    // iterate bindings (e.g. X = bob)
}
```

The `examples/roundtrip.zig` program demonstrates the full stack end-to-end and is runnable via `make roundtrip`.

## Panic isolation

Every Rust FFI entry point wraps its body in panic suppression so a Scryer panic cannot unwind across the C ABI into Zig. Do not remove this suppression when extending `ffi/zpm-prolog-ffi/src/lib.rs`; it is a correctness requirement, not a convenience.

## Knowledge base fixtures

`tests/fixtures/family.pl` is the canonical fixture for engine tests. Reuse it when adding scenarios instead of inlining ad-hoc clauses.

## References

- `references/mcp-tools.md` — MCP tool protocol: input schemas, request/response examples, error shapes
- `references/prolog-engine.md` — Engine API reference (methods, errors, ownership)
- `references/build.md` — Build system, Rust FFI layout, CI
- `references/architecture.md` — ADR summaries: STDIO transport, Rust FFI staticlib, engine singleton
