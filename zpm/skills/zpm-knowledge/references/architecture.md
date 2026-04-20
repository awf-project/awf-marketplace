# Architecture

ZPM pairs a Zig MCP server with a Trealla Prolog logic engine linked in-process through a C FFI git submodule. Three architectural decisions shape everything else and are recorded as ADRs:

- `docs/ADR/0001-mcp-server-with-stdio-transport.md`
- `docs/ADR/0002-scryer-prolog-via-rust-ffi-staticlib.md` (superseded by ADR 0004)
- `docs/ADR/0003-knowledge-base-persistence-via-wal-and-snapshots.md`
- `docs/ADR/0004-trealla-prolog-via-c-ffi-replacing-scryer.md`

`docs/ADR/README.md` is the authoritative index. The upstream ADR text is the source of truth; this page summarizes the load-bearing conclusions for skill consumers.

## ADR 0001: MCP server with STDIO transport

**Decision.** ZPM speaks MCP over STDIO, not HTTP/SSE or a socket.

**Consequences for skill users:**

- The server is spawned by the MCP client; there is no long-running daemon to register.
- Process lifetime equals client session lifetime. Engine state (asserted facts) does not survive a restart unless the client re-loads it.
- Multi-tenant usage requires one server process per client. Do not add shared in-process state.
- Logs must go to `stderr` only. Anything on `stdout` is MCP protocol framing and will corrupt the channel.

## ADR 0004: Trealla Prolog via C FFI (supersedes ADR 0002)

**Decision.** The Prolog engine is Trealla Prolog, embedded through a C FFI git submodule compiled alongside the Zig binary. ADR 0002 (Scryer via Rust staticlib) is superseded. Rejected alternatives include keeping Scryer (Rust toolchain overhead), spawning a subprocess, and SWI-Prolog.

**Consequences for skill users:**

- No Rust toolchain required. A pure Zig + C build is sufficient. See `build.md`.
- There is one process, one address space; no IPC overhead per query.
- Trealla's capabilities are the engine's capabilities. Features absent from Trealla are absent from ZPM unless worked around at the Zig layer.
- The FFI surface is intentionally narrow (init/deinit, query, assert, retract, loadFile, loadString). Expanding it is an explicit FFI design change, not an incidental addition.
- Query results are captured via stdout redirection and parsed as JSON (`src/prolog/capture.zig`). This is an implementation detail; it does not change the MCP tool interface.

## ADR 0003: Knowledge base persistence via WAL and snapshots

**Decision.** The knowledge base is made durable through a write-ahead log (WAL) plus named snapshots, scoped to a per-project `.zpm/` directory. Every mutation is appended to the WAL as an opaque Prolog term before the engine returns to the client; recovery replays the WAL on top of the latest snapshot. Snapshot creation and restoration are exposed as MCP tools, so AI agents drive checkpointing explicitly.

Rejected alternatives include serialising the full knowledge base on every write (too costly), relying solely on snapshots (data loss between snapshots), embedding an external KV store (extra dependency, second source of truth), and a global per-user knowledge base (forces isolation bugs and blocks team-shared knowledge).

**Consequences for skill users:**

- Persistence is **project-scoped**. Each `.zpm/` directory is a self-contained knowledge base; switching projects switches state.
- `PersistenceManager.init` takes **two paths**: `data_dir` (WAL) and `snapshot_dir_path` (snapshots + auto-loaded `*.pl`). They map to `.zpm/data/` and `.zpm/kb/` respectively. The separation lets `kb/` be committed to version control while `data/` stays ephemeral.
- Facts and rules survive process restart without client re-loading. ADR 0001's "engine state does not survive a restart" is now scoped to the in-memory case only; the durable path is the default.
- If WAL or snapshot I/O fails at startup (missing or non-writable `.zpm/data/`), `PersistenceManager` falls back to **degraded mode**: writes still execute against the in-memory engine, but nothing is journalled. Use `get_persistence_status` to confirm `mode == "durable"` before relying on durability.
- **WAL and snapshot format**: both use JSON Lines. Each write is fsynced to disk. There are no size limits per clause or per journal file.
- WAL replay is mutation-ordered and append-only. Do not edit the WAL file by hand; truncate via a `save_snapshot` followed by WAL roll-over instead.
- **Snapshot restoration** uses wipe-before-reload semantics: `restore_snapshot` calls `resetUserKnowledge` to clear the engine before loading the snapshot, then replays WAL entries written after that snapshot was taken. This prevents duplicate facts from accumulating during restore.
- **Breaking persistence format**: if upgrading from a version that used the previous text-based WAL/snapshot format, delete `.zpm/data/` before starting the server. Old data is not compatible with the JSON Lines format.
- All write tools (`remember_fact`, `forget_fact`, `update_fact`, `upsert_fact`, `assume_fact`, `define_rule`, `clear_context`, `retract_assumption`, `retract_assumptions`) journal automatically — handlers do not need to call the persistence layer themselves.
- All mutation tools use two-phase commit: the WAL entry is written and fsynced before the engine mutation executes.

## Project discovery (`src/project.zig`)

`zpm serve` resolves its project root before touching the engine:

- `discover(allocator, cwd)` walks up from `cwd`, stopping at a directory that contains `.zpm/`. The walk is bounded to the starting filesystem device; it will not cross mount points into a sibling project.
- Missing `.zpm/` → `ProjectError.NotFound` → the server exits 1 with a hint to run `zpm init`.
- `initProject(cwd)` creates `.zpm/`, `.zpm/kb/`, `.zpm/data/`, and `.zpm/.gitignore` (contents: `data/`). It returns `ProjectError.AlreadyInitialized` if `.zpm/` already exists — the CLI treats this as a soft success (exit 0, idempotent).
- `loadKnowledgeBase(allocator, kb_dir, engine)` iterates `.zpm/kb/`, loading every file ending in `.pl` via `engine.loadFile`. Individual load failures are logged to stderr; the server keeps loading the remaining files.

**Ordering at startup:** discover → `PersistenceManager.init(data_dir, kb_dir)` → `Engine.init` → `loadKnowledgeBase(kb_dir)` → `PersistenceManager.restore(engine)` (snapshot + WAL replay) → MCP dispatch loop.

## Layer responsibilities

```
src/main.zig                 MCP dispatch, lifecycle, logging to stderr;
                             runs project discovery, initialises
                             PersistenceManager and Engine
src/project.zig              .zpm/ discovery, init, *.pl auto-load
src/tools/context.zig        engine + persistence-manager singleton
src/tools/*.zig              MCP tool handlers; writes go via Engine and
                             are journalled through the persistence manager
src/persistence/manager.zig  lifecycle, degraded-mode detection, dual-path
                             (data_dir for WAL, snapshot_dir_path for snapshots)
src/persistence/wal.zig      append-only journal (JSON Lines, fsync per write);
                             replay from a sequence number
src/persistence/snapshot.zig snapshot serialisation and restoration (JSON Lines);
                             restore uses resetUserKnowledge (wipe-before-reload)
src/tools/term_utils.zig     shared Prolog term parsing for tools + persistence
src/prolog/engine.zig        public Zig API; only layer MCP handlers may call
src/prolog/ffi.zig           extern "C" declarations matching Trealla exports
src/prolog/capture.zig       stdout redirection and JSON output parsing for queries
  -> trealla-prolog submodule  actual Prolog machine (C library)
```

Keep Prolog-specific concerns inside `engine.zig` and below. MCP handlers should not know which Prolog implementation backs the engine. The persistence layer treats Prolog terms as opaque payloads — it never inspects them.

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

- Changes to `extern "C"` signatures in `src/prolog/ffi.zig` are ABI changes. Both the Zig declarations and the Trealla submodule bindings must be updated and the binary rebuilt; there is no dynamic loading.
- New Prolog operations should be added as new `Engine` methods rather than by exposing `ffi.zig` calls to MCP handlers.
- Trealla upgrades flow through the git submodule reference. Run `git submodule update --init` after pulling to synchronize.

## Further reading

- `prolog-engine.md` for the public Engine API
- `build.md` for toolchain, targets, and CI
- Upstream ADRs in `docs/ADR/` for full rationale and rejected alternatives
