# Architecture

ZPM pairs a Zig MCP server with a Scryer Prolog logic engine linked in-process through a Rust FFI staticlib. Two architectural decisions shape everything else and are recorded as ADRs:

- `docs/ADR/0001-mcp-server-with-stdio-transport.md`
- `docs/ADR/0002-scryer-prolog-via-rust-ffi-staticlib.md`
- `docs/ADR/0003-knowledge-base-persistence-via-wal-and-snapshots.md`

`docs/ADR/README.md` is the authoritative index. The upstream ADR text is the source of truth; this page summarizes the load-bearing conclusions for skill consumers.

## ADR 0001: MCP server with STDIO transport

**Decision.** ZPM speaks MCP over STDIO, not HTTP/SSE or a socket.

**Consequences for skill users:**

- The server is spawned by the MCP client; there is no long-running daemon to register.
- Process lifetime equals client session lifetime. Engine state (asserted facts) does not survive a restart unless the client re-loads it.
- Multi-tenant usage requires one server process per client. Do not add shared in-process state.
- Logs must go to `stderr` only. Anything on `stdout` is MCP protocol framing and will corrupt the channel.

## ADR 0002: Scryer Prolog via Rust FFI staticlib

**Decision.** The Prolog engine is Scryer, embedded through a Rust `staticlib` crate linked into the Zig binary at build time. Rejected alternatives include spawning a Prolog subprocess, linking a C-based Prolog (SWI) directly, and reimplementing Prolog in Zig.

**Consequences for skill users:**

- A Rust toolchain is a hard build requirement. See `build.md`.
- There is one process, one address space; no IPC overhead per query.
- Scryer's capabilities are the engine's capabilities. Features absent from Scryer are absent from ZPM unless added upstream or worked around in Rust.
- The FFI surface is intentionally narrow (init/deinit, query, assert, retract, loadFile, loadString). Expanding it is an explicit FFI design change, not an incidental addition.
- Panics inside Scryer must not unwind across the C ABI. `ffi/zpm-prolog-ffi/src/lib.rs` wraps every entry point in panic suppression; this is a correctness invariant, not a stylistic choice.

## ADR 0003: Knowledge base persistence via WAL and snapshots

**Decision.** The knowledge base is made durable through a write-ahead log (WAL) plus named snapshots. Every mutation is appended to the WAL as an opaque Prolog term before the engine returns to the client; recovery replays the WAL on top of the latest snapshot. Snapshot creation and restoration are exposed as MCP tools, so AI agents drive checkpointing explicitly.

Rejected alternatives include serialising the full knowledge base on every write (too costly), relying solely on snapshots (data loss between snapshots), and embedding an external KV store (extra dependency, second source of truth).

**Consequences for skill users:**

- Facts and rules survive process restart without client re-loading. ADR 0001's "engine state does not survive a restart" is now scoped to the in-memory case only; the durable path is the default.
- If WAL or snapshot I/O fails at startup, `PersistenceManager` falls back to **degraded mode**: writes still execute against the in-memory engine, but nothing is journalled. Use `get_persistence_status` to confirm `mode == "durable"` before relying on durability.
- WAL replay is mutation-ordered and append-only. Do not edit the WAL file by hand; truncate via a `save_snapshot` followed by WAL roll-over instead.
- Snapshot restoration is destructive: `restore_snapshot` replaces the current knowledge base in full and then replays WAL entries written after that snapshot was taken.
- All write tools (`remember_fact`, `forget_fact`, `update_fact`, `upsert_fact`, `assume_fact`, `define_rule`, `clear_context`, `retract_assumption`, `retract_assumptions`) journal automatically — handlers do not need to call the persistence layer themselves.

## Layer responsibilities

```
src/main.zig                 MCP dispatch, lifecycle, logging to stderr;
                             initialises PersistenceManager and Engine
src/tools/context.zig        engine + persistence-manager singleton
src/tools/*.zig              MCP tool handlers; writes go via Engine and
                             are journalled through the persistence manager
src/persistence/manager.zig  lifecycle, degraded-mode detection, shared state
src/persistence/wal.zig      append-only journal; replay from a sequence number
src/persistence/snapshot.zig snapshot serialisation and restoration
src/tools/term_utils.zig     shared Prolog term parsing for tools + persistence
src/prolog/engine.zig        public Zig API; only layer MCP handlers may call
src/prolog/ffi.zig           extern "C" declarations; no logic
ffi/zpm-prolog-ffi/src/lib.rs  extern "C" Rust wrappers with panic suppression
  -> scryer-prolog crate     actual Prolog machine
```

Keep Prolog-specific concerns inside `engine.zig` and below. MCP handlers should not know that the engine is Scryer, nor that the bridge is Rust. The persistence layer treats Prolog terms as opaque payloads — it never inspects them.

## Engine singleton (context.zig)

`src/tools/context.zig` exposes two functions:

- `setEngine(engine: *Engine) void` — called once at server startup from `src/main.zig` after `Engine.init`.
- `getEngine() *Engine` — called by each tool handler to retrieve the shared instance.

**Invariants:**

- `setEngine` must be called before any tool handler runs. Calling `getEngine` before `setEngine` is a programming error (the implementation asserts non-null).
- There is exactly one engine per process. Do not call `setEngine` more than once; the previous engine would leak.
- Thread safety: the engine is not re-entrant. MCP over STDIO is inherently single-client, so concurrent calls do not arise in practice. If concurrency is ever introduced, add external synchronization before relaxing this invariant.

**Motivation:** Tool handlers are separate compilation units (`src/tools/*.zig`) and cannot import `src/main.zig`. The singleton in `context.zig` provides a dependency-injection point without requiring a global import cycle.

**Persistence manager handle.** `context.zig` also carries a reference to the `PersistenceManager` instance. Write-path handlers retrieve it alongside the engine to journal each mutation. The same single-process / single-instance invariants apply: set once at startup, never re-assigned, not safe for concurrent use.

## Versioning and evolution

- Changes to `extern "C"` signatures in `src/prolog/ffi.zig` or `ffi/zpm-prolog-ffi/src/lib.rs` are ABI changes. Both sides must be updated and the binary rebuilt; there is no dynamic loading.
- New Prolog operations should be added as new `Engine` methods rather than by exposing `ffi.zig` calls to MCP handlers.
- Scryer upgrades flow through `ffi/zpm-prolog-ffi/Cargo.toml`. Lock file churn in `Cargo.lock` is expected and committed.

## Further reading

- `prolog-engine.md` for the public Engine API
- `build.md` for toolchain, targets, and CI
- Upstream ADRs in `docs/ADR/` for full rationale and rejected alternatives
