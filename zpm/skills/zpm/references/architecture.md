# Architecture

ZPM pairs a Zig MCP server with a Scryer Prolog logic engine linked in-process through a Rust FFI staticlib. Two architectural decisions shape everything else and are recorded as ADRs:

- `docs/ADR/0001-mcp-server-with-stdio-transport.md`
- `docs/ADR/0002-scryer-prolog-via-rust-ffi-staticlib.md`

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

## Layer responsibilities

```
src/main.zig                 MCP dispatch, lifecycle, logging to stderr
src/prolog/engine.zig        public Zig API; only layer MCP handlers may call
src/prolog/ffi.zig           extern "C" declarations; no logic
ffi/zpm-prolog-ffi/src/lib.rs  extern "C" Rust wrappers with panic suppression
  -> scryer-prolog crate     actual Prolog machine
```

Keep Prolog-specific concerns inside `engine.zig` and below. MCP handlers should not know that the engine is Scryer, nor that the bridge is Rust.

## Versioning and evolution

- Changes to `extern "C"` signatures in `src/prolog/ffi.zig` or `ffi/zpm-prolog-ffi/src/lib.rs` are ABI changes. Both sides must be updated and the binary rebuilt; there is no dynamic loading.
- New Prolog operations should be added as new `Engine` methods rather than by exposing `ffi.zig` calls to MCP handlers.
- Scryer upgrades flow through `ffi/zpm-prolog-ffi/Cargo.toml`. Lock file churn in `Cargo.lock` is expected and committed.

## Further reading

- `prolog-engine.md` for the public Engine API
- `build.md` for toolchain, targets, and CI
- Upstream ADRs in `docs/ADR/` for full rationale and rejected alternatives
