---
name: zpm
description: ZPM MCP server - Zig-based Model Context Protocol server exposing a Scryer Prolog logic engine over STDIO. Use this skill when building, configuring, or using the ZPM server to execute Prolog queries, assert or retract facts, and load knowledge bases from MCP clients.
---

# ZPM

ZPM is an MCP server written in Zig that embeds a Scryer Prolog logic engine through a Rust FFI staticlib. Clients speak MCP over STDIO and drive Prolog operations (query, assert, retract, load file, load string) against an in-process engine.

## When to use

- Initialize a `.zpm/` project directory for per-project knowledge bases
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
   |  + WAL journal (src/persistence/*.zig) on writes
   v
C-ABI bindings (src/prolog/ffi.zig)
   |  extern "C"
   v
Rust staticlib (ffi/zpm-prolog-ffi)
   |  in-process call
   v
Scryer Prolog
```

All layers run in a single process. The Rust staticlib is linked into the Zig binary at build time; no separate daemon or IPC is involved. `src/tools/context.zig` holds the engine singleton; `src/main.zig` initializes it at startup via `context.setEngine` and tool handlers retrieve it via `context.getEngine`. Project discovery (`src/project.zig`) locates `.zpm/` before engine init so persistence paths (`kb/`, `data/`) are known. See `references/architecture.md` for the rationale (STDIO transport, FFI staticlib, engine singleton, project layout).

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

## Running the server

The MCP server is started with the `serve` subcommand. Running the binary without arguments does not start the server — it prints help and exits.

**`zpm serve` requires a `.zpm/` project directory.** Initialize one once per project:

```sh
cd /path/to/project
zpm init       # creates .zpm/kb/, .zpm/data/, .zpm/.gitignore
zpm serve      # discovers .zpm/ by walking up from cwd
```

On startup, `zpm serve` auto-loads every `*.pl` file from `.zpm/kb/` into the engine and initialises persistence with dual paths: WAL journal in `.zpm/data/`, snapshots in `.zpm/kb/`. `.zpm/kb/` is intended for version control (share Prolog source with the team); `.zpm/data/` is ephemeral and gitignored.

If no `.zpm/` is found in the directory ancestry the server exits 1 with `error: no project directory found`. If `.zpm/data/` is not writable the server enters **degraded mode** (in-memory only); verify with `get_persistence_status`.

MCP client configuration must pass `serve` as the argument; the client's working directory at spawn time is the discovery root:

```json
{
  "mcpServers": {
    "zpm": {
      "command": "/path/to/zpm",
      "args": ["serve"]
    }
  }
}
```

Other flags: `--help`/`-h` (exits 0), `--version`/`-v` (exits 0). Unknown subcommands exit 1 on stderr. Full CLI reference: `references/cli.md`.

## MCP Tools

| Tool | Write | Description |
|------|-------|-------------|
| `mcp__zpm__echo` | no | Echoes a message; use to test connectivity |
| `mcp__zpm__remember_fact` | yes | Assert a Prolog fact into the knowledge base |
| `mcp__zpm__define_rule` | yes | Assert a Prolog rule (`Head :- Body`) into the knowledge base |
| `mcp__zpm__mcp__zpm__query_logic` | no | Execute a Prolog goal; returns all variable bindings as a JSON array |
| `mcp__zpm__trace_dependency` | no | Traverse transitive dependencies via `path/2` rules; returns reachable node names |
| `mcp__zpm__verify_consistency` | no | Query `integrity_violation/N` predicates; returns all violations as JSON |
| `mcp__zpm__explain_why` | no | Reconstruct proof chain for a fact via `clause/2`; returns a nested proof tree |
| `mcp__zpm__get_knowledge_schema` | no | Introspect the knowledge base; returns all user-defined predicates with arity and clause type |
| `mcp__zpm__forget_fact` | yes | Retract the first matching fact via `retract/1`; single-retract deterministic semantics |
| `mcp__zpm__clear_context` | yes | Retract all facts matching a category pattern via `retractall/1`; always succeeds |
| `mcp__zpm__update_fact` | yes | Atomic retract+assert; replaces `old_fact` with `new_fact`; returns `ExecutionFailed` if old fact not found |
| `mcp__zpm__upsert_fact` | yes | Match by functor+first argument; replace existing fact or insert if absent |
| `mcp__zpm__assume_fact` | yes | Assert a fact under a named assumption; stores justification metadata in the knowledge base |
| `mcp__zpm__get_belief_status` | no | Query whether a belief is supported and list the assumptions that justify it |
| `mcp__zpm__get_justification` | no | List all facts currently supported by a given named assumption |
| `mcp__zpm__list_assumptions` | no | Enumerate all active assumptions and their associated facts |
| `mcp__zpm__retract_assumption` | yes | Retract a single named assumption and cascade removal to all dependent facts |
| `mcp__zpm__retract_assumptions` | yes | Bulk-retract all assumptions matching a glob-style pattern and their dependent facts |
| `mcp__zpm__save_snapshot` | yes | Create a named point-in-time snapshot of the knowledge base |
| `mcp__zpm__restore_snapshot` | yes | Restore from a named snapshot and replay subsequent journal entries |
| `mcp__zpm__list_snapshots` | no | List all available snapshots with metadata |
| `mcp__zpm__get_persistence_status` | no | Query journal size, last snapshot name, and operational mode (durable / degraded) |

All write tools journal mutations through a write-ahead log (WAL); the knowledge base is recovered on next startup by replaying the WAL on top of the latest snapshot. If the persistence layer fails to initialise, the server runs in degraded (in-memory only) mode — writes still succeed but are not durable. See `references/architecture.md` for the WAL + snapshot design.

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

### get_knowledge_schema

Introspects the knowledge base by querying `current_predicate/1` and classifying each predicate via `clause/2`. Returns all user-defined predicates with their arity and clause type (`fact`, `rule`, or `both`). Built-ins and unsafe atom names are filtered out.

```json
{
  "jsonrpc": "2.0",
  "id": 9,
  "method": "tools/call",
  "params": {
    "name": "get_knowledge_schema",
    "arguments": {}
  }
}
```

Success response: `"{\"predicates\":[{\"name\":\"human\",\"arity\":1,\"type\":\"fact\"},{\"name\":\"mortal\",\"arity\":1,\"type\":\"rule\"}],\"total\":2}"`.

- Pass `"domain": "string"` to scope results to a specific predicate name prefix.
- Returns `{"predicates":[],"total":0}` when the knowledge base is empty.
- Read-only and idempotent.

Full protocol docs, all input schemas, and error response shapes: `references/mcp-tools.md`.

### forget_fact

Retracts the first matching fact from the knowledge base using `retract/1` wrapped in `once/1` for deterministic single-retract semantics. Returns `ExecutionFailed` when no matching fact exists.

```json
{
  "jsonrpc": "2.0",
  "id": 10,
  "method": "tools/call",
  "params": {
    "name": "forget_fact",
    "arguments": { "fact": "human(socrates)" }
  }
}
```

Success response: `"Retracted: human(socrates)"`.

- Do not include a trailing `.` in `fact`
- Only the first matching clause is removed; duplicate facts require multiple calls
- Returns `ExecutionFailed` when no matching fact exists

### clear_context

Retracts all facts matching a category pattern via `retractall/1`. Always succeeds per ISO Prolog semantics, even when no facts match the pattern.

```json
{
  "jsonrpc": "2.0",
  "id": 11,
  "method": "tools/call",
  "params": {
    "name": "clear_context",
    "arguments": { "category": "human(_)" }
  }
}
```

Success response: `"Cleared: human(_)"`.

- `category` is a Prolog term pattern (e.g. `human(_)` removes all `human/1` facts)
- Never returns an error for non-existent predicates
- Use `forget_fact` when single-retract semantics are required

### update_fact

Atomically retracts `old_fact` and asserts `new_fact` in a single operation. Returns `ExecutionFailed` if `old_fact` is not found — the knowledge base is not modified.

```json
{
  "jsonrpc": "2.0",
  "id": 12,
  "method": "tools/call",
  "params": {
    "name": "update_fact",
    "arguments": { "old_fact": "human(socrates)", "new_fact": "human(plato)" }
  }
}
```

Success response: `"Updated: human(socrates) -> human(plato)"`.

- Do not include a trailing `.` in either argument
- Returns `ExecutionFailed` without modifying the knowledge base when `old_fact` is absent
- Use `upsert_fact` when insert-or-replace semantics are required

### upsert_fact

Matches by functor and first argument, retracts all matching facts via `retractall/1`, then asserts the new fact. Always succeeds — inserts if no match exists.

```json
{
  "jsonrpc": "2.0",
  "id": 13,
  "method": "tools/call",
  "params": {
    "name": "upsert_fact",
    "arguments": { "fact": "age(socrates, 70)" }
  }
}
```

Success response: `"Upserted: age(socrates, 70)"`.

- Do not include a trailing `.` in `fact`
- Matches on functor + first argument; calling twice with same functor+first-arg leaves exactly one fact
- Use `update_fact` when atomic replace with existence check is required

### assume_fact

Asserts a fact under a named assumption and records justification metadata in the knowledge base. Use to make defeasible assertions that can be retracted as a unit.

```json
{
  "jsonrpc": "2.0",
  "id": 14,
  "method": "tools/call",
  "params": {
    "name": "assume_fact",
    "arguments": { "assumption": "hypothesis_1", "fact": "flies(tweety)" }
  }
}
```

Success response: `"Assumed: flies(tweety) under hypothesis_1"`.

- Both `assumption` and `fact` are required; omitting either returns `InvalidArguments`
- Do not include a trailing `.` in `fact`

### get_belief_status

Queries whether a belief is currently supported and returns the set of assumptions that justify it.

```json
{
  "jsonrpc": "2.0",
  "id": 15,
  "method": "tools/call",
  "params": {
    "name": "get_belief_status",
    "arguments": { "belief": "flies(tweety)" }
  }
}
```

Success response: JSON object with `supported` boolean and `assumptions` array.

- `belief` is required; omitting returns `InvalidArguments`
- Returns `{"supported": false, "assumptions": []}` when no assumption justifies the belief

### get_justification

Lists all facts currently supported by a given named assumption.

```json
{
  "jsonrpc": "2.0",
  "id": 16,
  "method": "tools/call",
  "params": {
    "name": "get_justification",
    "arguments": { "assumption": "hypothesis_1" }
  }
}
```

Success response: JSON array of fact strings supported by the assumption.

- `assumption` is required; omitting returns `InvalidArguments`
- Returns an empty array when no facts are under that assumption

### list_assumptions

Enumerates all active assumptions and the facts each one supports.

```json
{
  "jsonrpc": "2.0",
  "id": 17,
  "method": "tools/call",
  "params": {
    "name": "list_assumptions",
    "arguments": {}
  }
}
```

Success response: JSON array of objects, each with `assumption` (string) and `facts` (array of strings).

- No arguments required; pass an empty object
- Returns an empty array when no assumptions are active

### retract_assumption

Retracts a single named assumption and propagates removal to all facts asserted under it.

```json
{
  "jsonrpc": "2.0",
  "id": 18,
  "method": "tools/call",
  "params": {
    "name": "retract_assumption",
    "arguments": { "assumption": "hypothesis_1" }
  }
}
```

Success response: `"Retracted assumption: hypothesis_1"`.

- `assumption` is required; omitting returns `InvalidArguments`
- Returns `ExecutionFailed` if the named assumption does not exist

### retract_assumptions

Bulk-retracts all assumptions whose names match a glob-style pattern and removes all dependent facts.

```json
{
  "jsonrpc": "2.0",
  "id": 19,
  "method": "tools/call",
  "params": {
    "name": "retract_assumptions",
    "arguments": { "pattern": "hypothesis_*" }
  }
}
```

Success response: `"Retracted N assumptions matching: hypothesis_*"`.

- `pattern` is required; omitting returns `InvalidArguments`
- `*` matches any sequence of characters within an assumption name; succeeds with count 0 when none match

### save_snapshot

Creates a named point-in-time snapshot of the knowledge base by serialising every clause via Prolog introspection. The snapshot becomes the new replay base; subsequent WAL entries layer on top of it during recovery.

```json
{
  "jsonrpc": "2.0",
  "id": 20,
  "method": "tools/call",
  "params": {
    "name": "save_snapshot",
    "arguments": { "name": "before_migration" }
  }
}
```

Success response: `"Saved snapshot: before_migration"`.

- `name` is required; omitting returns `InvalidArguments`
- Overwrites any existing snapshot with the same name
- Returns `ExecutionFailed` when running in degraded mode (persistence unavailable)

### restore_snapshot

Restores the knowledge base from a named snapshot, then replays any WAL entries written after the snapshot was taken. Use to roll back to a known checkpoint or recover from a corrupted state.

```json
{
  "jsonrpc": "2.0",
  "id": 21,
  "method": "tools/call",
  "params": {
    "name": "restore_snapshot",
    "arguments": { "name": "before_migration" }
  }
}
```

Success response: `"Restored snapshot: before_migration"`.

- `name` is required; omitting returns `InvalidArguments`
- Returns `ExecutionFailed` when the named snapshot does not exist
- Replaces current knowledge base entirely; non-snapshotted state is lost

### list_snapshots

Enumerates all available snapshots with their metadata (name, sequence number at which the snapshot was taken, creation timestamp).

```json
{
  "jsonrpc": "2.0",
  "id": 22,
  "method": "tools/call",
  "params": {
    "name": "list_snapshots",
    "arguments": {}
  }
}
```

Success response: JSON array of objects, each with `name`, `sequence`, and `created_at`.

- No arguments required; pass an empty object
- Returns an empty array when no snapshots exist
- Read-only and idempotent

### get_persistence_status

Reports the operational state of the persistence layer: durable mode versus degraded (in-memory only) mode, current journal size, and the name of the most recent snapshot.

```json
{
  "jsonrpc": "2.0",
  "id": 23,
  "method": "tools/call",
  "params": {
    "name": "get_persistence_status",
    "arguments": {}
  }
}
```

Success response: JSON object with `mode` (`"durable"` or `"degraded"`), `journal_entries`, `last_snapshot`, and `last_sequence`.

- No arguments required; pass an empty object
- Read-only and idempotent
- Use to verify durability before relying on WAL recovery

Full protocol docs, all input schemas, and error response shapes: `references/mcp-tools.md`.

## Engine API

The Zig `Engine` struct in `src/prolog/engine.zig` is the only supported entry point for Prolog operations. MCP tool handlers call it; direct use of `src/prolog/ffi.zig` is reserved for the engine implementation.

Operations:

- `init` / `deinit` — lifecycle
- `query` — execute a Prolog query, iterate bindings
- `assert` / `assertFact` — add a clause or fact to the knowledge base
- `retractFact` — remove the first matching clause (single-retract via `once/1`)
- `retractAllFacts` — remove all matching clauses (bulk retract, always succeeds)
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

## Project layout (`.zpm/`)

Each ZPM project has its own `.zpm/` directory, created by `zpm init`:

```
.zpm/
  kb/          # Versionable: *.pl sources + snapshots (auto-loaded on serve)
  data/        # Ephemeral: WAL journal, locks (gitignored)
  .gitignore   # Contains `data/`
```

- Drop `*.pl` files into `.zpm/kb/` to have them loaded automatically on every `zpm serve`.
- Snapshots written by `save_snapshot` land in `.zpm/kb/` and replay alongside the WAL in `.zpm/data/` on the next start.
- Each project is isolated: different `.zpm/` directories hold independent knowledge bases, so multiple `zpm serve` processes can run in parallel without cross-contamination.
- Discovery walks up from cwd and stops at the filesystem boundary (does not cross mount points).

## References

- `references/cli.md` — CLI subcommands (`init`, `serve`), flags, exit codes, `.zpm/` discovery, MCP client configuration
- `references/mcp-tools.md` — MCP tool protocol: input schemas, request/response examples, error shapes
- `references/prolog-engine.md` — Engine API reference (methods, errors, ownership)
- `references/build.md` — Build system, Rust FFI layout, CI
- `references/architecture.md` — ADR summaries: STDIO transport, Rust FFI staticlib, engine singleton, WAL + snapshot persistence, project discovery
