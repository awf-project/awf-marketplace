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

All layers run in a single process. The Rust staticlib is linked into the Zig binary at build time; no separate daemon or IPC is involved. See `references/architecture.md` for the rationale (STDIO transport, FFI staticlib over alternatives).

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

## Engine API

The Zig `Engine` struct in `src/prolog/engine.zig` is the only supported entry point for Prolog operations. MCP tool handlers call it; direct use of `src/prolog/ffi.zig` is reserved for the engine implementation.

Operations:

- `init` / `deinit` — lifecycle
- `query` — execute a Prolog query, iterate bindings
- `assert` — add a clause to the knowledge base
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

- `references/prolog-engine.md` — Engine API reference (methods, errors, ownership)
- `references/build.md` — Build system, Rust FFI layout, CI
- `references/architecture.md` — ADR summaries: STDIO transport, Rust FFI staticlib
