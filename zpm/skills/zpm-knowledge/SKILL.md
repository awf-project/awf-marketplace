---
name: zpm
description: ZPM MCP server - Zig-based Model Context Protocol server exposing a Trealla Prolog logic engine over STDIO. Use this skill when building, configuring, or using the ZPM server to execute Prolog queries, assert or retract facts, and load knowledge bases from MCP clients.
---

# ZPM

ZPM is an MCP server written in Zig that embeds a Trealla Prolog logic engine through a C FFI git submodule. Clients speak MCP over STDIO and drive Prolog operations (query, assert, retract, load file, load string) against an in-process engine.

## When to use

- Initialize a `.zpm/` project directory for per-project knowledge bases
- Build or run the ZPM MCP server
- Execute Prolog operations from an MCP client (Claude Code, Cursor, etc.)
- Extend the Prolog engine API or its C FFI bridge
- Diagnose build, link, or runtime issues involving the Trealla submodule

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
Trealla Prolog (C git submodule)
   |  in-process call; query output captured via src/prolog/capture.zig
```

All layers run in a single process. The Trealla submodule is compiled and linked into the Zig binary at build time; no separate daemon or IPC is involved. `src/tools/context.zig` holds the engine singleton; `src/main.zig` initializes it at startup via `context.setEngine` and tool handlers retrieve it via `context.getEngine`. Project discovery (`src/project.zig`) locates `.zpm/` before engine init so persistence paths (`kb/`, `data/`) are known. See `references/architecture.md` for the rationale (STDIO transport, C FFI submodule, engine singleton, project layout).

## Prerequisites

- Zig toolchain (as required by `build.zig`)
- C compiler (`cc`) available on `PATH`
- GNU `make`

Initialize the Trealla submodule before building: `git submodule update --init`. No Rust toolchain is required.

## Build and test

| Target | Purpose |
|--------|---------|
| `make build` | Build the full binary (Trealla submodule compiled as part of this step) |
| `make test` | Run Zig unit tests (includes inline engine tests) |
| `make functional-test-engine` | End-to-end engine tests (`tests/functional_prolog_engine_test.sh`) |
| `make roundtrip` | Run `examples/roundtrip.zig` (assert + query demo) |

CI runs Zig lint/test/build after initializing the submodule. No Rust steps are present.

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

All write tools journal mutations through a write-ahead log (WAL) using two-phase commit (journal fsynced before engine mutation). WAL and snapshot files use JSON Lines format with no per-entry size limits. The knowledge base is recovered on next startup by replaying the WAL on top of the latest snapshot. Snapshot restore uses wipe-before-reload semantics to prevent duplicate facts. If the persistence layer fails to initialise, the server runs in degraded (in-memory only) mode — writes still succeed but are not durable. See `references/architecture.md` for the WAL + snapshot design.

**Upgrading from older persistence format**: delete `.zpm/data/` before starting the server if you have data written by a version using the old text-based WAL format. Old data is not compatible with JSON Lines.

Full input schemas, request/response examples, and error shapes for every tool: `references/mcp-tools.md`.

Key behavioral notes:

- **Write tools** (`remember_fact`, `define_rule`, `forget_fact`, `clear_context`, `update_fact`, `upsert_fact`, `assume_fact`, `retract_assumption`, `retract_assumptions`) journal via two-phase commit — WAL entry fsynced before engine mutation.
- **`update_fact`** returns `ExecutionFailed` without modifying state if `old_fact` is not found.
- **`restore_snapshot`** wipes the engine knowledge base before loading (wipe-before-reload) to prevent duplicate facts.
- **`get_persistence_status`** returns `mode: "durable"` or `mode: "degraded"`. Call this before relying on WAL recovery.
- **Do not include a trailing `.`** in `fact`, `goal`, or `head`/`body` arguments — tools append it internally.

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

## FFI error handling

The C FFI surface in `src/prolog/ffi.zig` maps Trealla return codes to Zig errors. Engine failures do not unwind across the C ABI — all error paths return Zig error values. When extending the FFI, preserve this pattern; errors must never propagate as undefined behavior across the language boundary.

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
- `references/build.md` — Build system, Trealla submodule, C FFI layout, CI
- `references/architecture.md` — ADR summaries: STDIO transport, Trealla C FFI submodule, engine singleton, WAL + snapshot persistence, project discovery
