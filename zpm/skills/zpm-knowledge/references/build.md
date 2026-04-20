# Build System

ZPM is a Zig binary that embeds Trealla Prolog through a C FFI git submodule. The build is orchestrated by `make`, which runs `git submodule update --init` then `zig build`.

## Required toolchains

| Tool | Source | Notes |
|------|--------|-------|
| Zig | as pinned by `build.zig` | standard Zig workflow |
| C compiler (cc) | system package | required to compile the Trealla submodule |
| GNU make | system package | drives the end-to-end build |

No Rust toolchain is required. Installing Zig and a C compiler is sufficient.

## Repository layout

```
src/
  main.zig              # MCP server entry point; engine init, tool registration
  prolog/
    engine.zig          # Public Engine API (Zig)
    ffi.zig             # extern "C" declarations matching Trealla exports
    capture.zig         # stdout redirection and JSON output parsing for queries
  tools/
    context.zig         # engine singleton (setEngine/getEngine)
    echo.zig            # echo tool handler
    remember_fact.zig   # remember_fact tool handler
    define_rule.zig     # define_rule tool handler
ffi/
  trealla/              # Trealla Prolog git submodule (C library)
tests/
  functional_prolog_engine_test.sh  # end-to-end engine scenarios
  functional_mcp_server_test.sh     # end-to-end MCP tool scenarios
  fixtures/
    family.pl           # canonical Prolog KB fixture
examples/
  roundtrip.zig         # full-stack demo (init -> assert -> query)
build.zig               # Zig build script
Makefile                # top-level targets
```

`ffi/trealla/` must be initialized before building. Run `git submodule update --init` once after cloning. Build artifacts are gitignored.

## Make targets

| Target | Invokes | Purpose |
|--------|---------|---------|
| `build` | `zig build` | full binary (submodule must be initialized first) |
| `test` | `zig build test` | Zig unit tests, including inline engine tests |
| `functional-test-engine` | `tests/functional_prolog_engine_test.sh` | run engine scenarios end-to-end |
| `functional-test` | `tests/functional_mcp_server_test.sh` | run MCP tool scenarios end-to-end (invokes `zpm serve`) |
| `roundtrip` | `examples/roundtrip.zig` | execute the full-stack demo |

The Trealla submodule is compiled as part of `zig build` via the C build step in `build.zig`. No separate make target is needed to build the C library.

## Continuous integration

`.github/workflows/ci.yaml` jobs (lint, test, build) each:

1. Run `git submodule update --init`
2. Install the Zig toolchain

No Rust installation step is required. Zig-side lint and test steps cover the full codebase.

## Troubleshooting

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| `ffi/trealla/` is empty | submodule not initialized | `git submodule update --init` |
| Link errors referencing `trealla_*` symbols | submodule out of date or not built | `git submodule update --init` then `make build` |
| Functional test hangs | Trealla stuck on a non-terminating query | check fixture and goal; kill process, fix query |

## Extending the FFI

When adding a new Trealla export:

1. Declare the matching `extern` in `src/prolog/ffi.zig`.
2. Expose it through an `Engine` method in `src/prolog/engine.zig` (keep MCP handlers off `ffi.zig` directly).
3. Add an inline Zig test and a functional-test scenario.
4. Run `zig build test` and `make functional-test-engine` locally before opening a PR.
