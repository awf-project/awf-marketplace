# Build System

ZPM is a Zig binary that statically links a Rust-compiled Prolog bridge. The build is orchestrated by `make`, which sequences `cargo` (Rust) and `zig build` (Zig).

## Required toolchains

| Tool | Source | Notes |
|------|--------|-------|
| Zig | as pinned by `build.zig` | standard Zig workflow |
| Rust (stable) | `dtolnay/rust-toolchain@stable` in CI, `rustup` locally | `cargo` must be on `PATH` |
| GNU make | system package | drives the end-to-end build |

`make build` fails fast if `cargo` is missing. Installing only Zig is not sufficient.

## Repository layout

```
src/
  main.zig              # MCP server entry point; engine init, tool registration
  prolog/
    engine.zig          # Public Engine API (Zig)
    ffi.zig             # extern "C" declarations matching Rust exports
  tools/
    context.zig         # engine singleton (setEngine/getEngine)
    echo.zig            # echo tool handler
    remember_fact.zig   # remember_fact tool handler
    define_rule.zig     # define_rule tool handler
ffi/
  zpm-prolog-ffi/
    Cargo.toml          # staticlib crate, depends on scryer-prolog
    Cargo.lock          # pinned dependency tree
    src/lib.rs          # extern "C" Rust functions with panic suppression
tests/
  build_ffi_test.sh                 # smoke test: staticlib compiles
  functional_prolog_engine_test.sh  # end-to-end engine scenarios
  functional_mcp_server_test.sh     # end-to-end MCP tool scenarios
  fixtures/
    family.pl           # canonical Prolog KB fixture
examples/
  roundtrip.zig         # full-stack demo (init -> assert -> query)
build.zig               # Zig build script with ffi-build step
Makefile                # top-level targets
```

`ffi/zpm-prolog-ffi/target/` and `engine.o` are gitignored build artifacts.

## Make targets

| Target | Invokes | Purpose |
|--------|---------|---------|
| `ffi-build` | `cargo build` on `ffi/zpm-prolog-ffi` | produce the Rust staticlib |
| `build` | `ffi-build` then `zig build` | full binary (default dependency chain) |
| `test` | `zig build test` | Zig unit tests, including inline engine tests |
| `ffi-test` | `tests/build_ffi_test.sh` | smoke-test that the staticlib compiles |
| `functional-test-engine` | `tests/functional_prolog_engine_test.sh` | run engine scenarios end-to-end |
| `functional-test` | `tests/functional_mcp_server_test.sh` | run MCP tool scenarios end-to-end (invokes `zpm serve`) |
| `roundtrip` | `examples/roundtrip.zig` | execute the full-stack demo |

The `ffi-build` step in `build.zig` links the staticlib into the final Zig binary. The staticlib produces an `engine.o` (or equivalent archive) that Zig consumes during linking; do not commit these artifacts.

## Continuous integration

`.github/workflows/ci.yaml` jobs (lint, test, build) each install:

1. Zig toolchain
2. Rust stable via `dtolnay/rust-toolchain@stable`

The lint job additionally runs:

- `cargo fmt --check` — Rust formatting
- `cargo clippy` — Rust lints

Any PR touching `ffi/zpm-prolog-ffi/` must pass both. Zig-side lint and test steps are unchanged from the pre-FFI baseline.

## Troubleshooting

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| `cargo: command not found` during `make build` | Rust not installed | `rustup toolchain install stable` |
| Link errors referencing `scryer_*` symbols | `ffi-build` did not run, or staticlib out of date | `make ffi-build` then rebuild |
| `engine.o` checked into git | accidentally staged artifact | `git rm --cached engine.o`, confirm `.gitignore` |
| CI fails at `cargo clippy` on a passing local build | stale Rust toolchain locally | `rustup update stable` |
| Functional test hangs | Scryer stuck on a non-terminating query | check fixture and goal; kill process, fix query |

## Extending the FFI

When adding a new Rust export:

1. Define the `extern "C"` function in `ffi/zpm-prolog-ffi/src/lib.rs`, wrapped in panic suppression.
2. Declare the matching `extern` in `src/prolog/ffi.zig`.
3. Expose it through an `Engine` method in `src/prolog/engine.zig` (keep MCP handlers off `ffi.zig` directly).
4. Add an inline Zig test and a functional-test scenario.
5. Run `cargo fmt`, `cargo clippy`, `zig build test`, and `make functional-test-engine` locally before opening a PR.
