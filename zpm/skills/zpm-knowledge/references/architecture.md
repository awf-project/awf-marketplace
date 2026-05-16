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

- Persistence is **project-scoped and per-segment**. Each `.zpm/` directory is a self-contained set of knowledge bases; switching projects switches state. Within a project, each mounted segment has its own WAL and snapshot files (see "Segmented memory" below).
- `PersistenceManager.init` takes **two paths per segment**: a WAL path (`.zpm/data/<name>.wal`) and a snapshot directory (`.zpm/kb/<name>/`, which also holds auto-loaded `*.pl`). The separation lets `kb/` be committed to version control while `data/` stays ephemeral.
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
- `initProject(cwd)` creates `.zpm/`, `.zpm/kb/default/`, `.zpm/data/`, `.zpm/mounts.json` (initial contents: `[{"name":"default","scope":"project","mode":"rw"}]`), and `.zpm/.gitignore` (contents: `data/`). It returns `ProjectError.AlreadyInitialized` if `.zpm/` already exists — the CLI treats this as a soft success (exit 0, idempotent).
- `kbDirFor(name)` resolves the per-segment KB directory `.zpm/kb/<name>/`. `loadKnowledgeBase(allocator, kb_dir, engine, module)` iterates that directory, loading every `*.pl` into the named Prolog module. Individual load failures are logged to stderr; the server keeps loading the remaining files.

**Ordering at startup:** discover → `bootstrap.loadManifest(.zpm/mounts.json)` (auto-creates `default` on first boot) → `Engine.init` → `MemoryRegistry.init(engine)` → for each segment in the manifest: `PersistenceManager.init(data_path, kb_dir)` + `loadKnowledgeBase(kb_dir, module)` + `PersistenceManager.restore(engine, module)` (snapshot + WAL replay) → MCP dispatch loop.

## Segmented memory (F021 + F022)

The engine hosts one or more **named segments**, each implemented as a Prolog module with its own persistence:

- `src/memory/registry.zig` owns the mount table. Each entry records the segment name, mode (`rw`/`ro`), scope (`project`/`global`), the `PersistenceManager` handle, and the Prolog module identifier. Lookup by name returns the segment context; missing names produce `ExecutionFailed` at the tool layer.
- `src/mounts/manifest.zig` serialises the mount table to `.zpm/mounts.json` and reads it on bootstrap. The manifest is the source of truth across CLI process boundaries — mounts survive restart without re-issuing `mount_memory`.
- **Routing.** Tool handlers read the optional `memory` parameter (or `--memory` flag on CLI). The registry resolves the name to a segment context, the handler then targets that segment's module on the engine and journals through that segment's `PersistenceManager`. Omitting the parameter routes to `default`.
- **Read-only enforcement.** When a write tool targets a `ro`-mounted segment, the registry returns an error before the engine mutation runs. The WAL is not touched.
- **Cross-segment queries.** `Engine.query` accepts Prolog module qualification (`Module:Goal`) so a single goal can reference clauses from any mounted segment. Module names must match mounted segments; unknown modules produce a Prolog existence error captured as `ExecutionFailed`.
- **`default` is always mounted.** It is created on first boot, cannot be unmounted, and is the implicit target for tools that omit `memory`.

## Layer responsibilities

```
src/main.zig                 MCP dispatch, lifecycle, logging to stderr;
                             runs project discovery, initialises
                             MemoryRegistry, Engine, per-segment persistence
src/cli/bootstrap.zig        reads .zpm/mounts.json on boot, auto-mounts every
                             listed segment, creates `default` on first boot
src/cli/memory.zig           `memory create|mount|unmount|list` subcommand group
src/project.zig              .zpm/ discovery, init, per-segment kb dir resolution,
                             *.pl auto-load into a named Prolog module
src/memory/registry.zig      named-segment mount table; routes tool calls to the
                             correct module + PersistenceManager; enforces ro mode
src/mounts/manifest.zig      .zpm/mounts.json serialisation; survives process exit
src/tools/context.zig        engine + memory-registry singleton
src/tools/*.zig              MCP tool handlers; read optional `memory` arg, route
                             writes via Engine + per-segment persistence manager
src/tools/{create,mount,    memory-management tool handlers
  unmount,list}_memory.zig
src/persistence/manager.zig  lifecycle, degraded-mode detection, per-segment
                             paths (data/<name>.wal for WAL, kb/<name>/ for snapshots)
src/persistence/wal.zig      append-only journal (JSON Lines, fsync per write);
                             replay from a sequence number
src/persistence/snapshot.zig snapshot serialisation and restoration (JSON Lines);
                             restore uses resetUserKnowledge (wipe-before-reload)
src/tools/term_utils.zig     shared Prolog term parsing for tools + persistence
src/prolog/engine.zig        public Zig API; module-qualified queries for cross-
                             memory reads; only layer MCP handlers may call
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

**Memory registry handle.** `context.zig` also carries a reference to the `MemoryRegistry` instance. Write-path handlers resolve the optional `memory` argument through the registry to obtain the target segment's module name and `PersistenceManager`, then journal each mutation against that segment. The registry is set once at startup, never re-assigned, and not safe for concurrent use.

## Versioning and evolution

- Changes to `extern "C"` signatures in `src/prolog/ffi.zig` are ABI changes. Both the Zig declarations and the Trealla submodule bindings must be updated and the binary rebuilt; there is no dynamic loading.
- New Prolog operations should be added as new `Engine` methods rather than by exposing `ffi.zig` calls to MCP handlers.
- Trealla upgrades flow through the git submodule reference. Run `git submodule update --init` after pulling to synchronize.

## Further reading

- `prolog-engine.md` for the public Engine API
- `build.md` for toolchain, targets, and CI
- Upstream ADRs in `docs/ADR/` for full rationale and rejected alternatives
