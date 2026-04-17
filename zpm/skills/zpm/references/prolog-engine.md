# Prolog Engine API

The `Engine` type in `src/prolog/engine.zig` is the public interface for all Prolog operations. It wraps the low-level C-ABI bindings in `src/prolog/ffi.zig`, which in turn call into the Rust staticlib (`ffi/zpm-prolog-ffi`). Consumers (MCP tool handlers, examples, tests) must go through `Engine` — never call `ffi.zig` directly from handler code.

Full signatures, parameter types, and exact error sets live in the source. This file describes the contract and the ownership rules that are not obvious from signatures alone.

## Lifecycle

- `Engine.init(allocator)` — construct a new engine instance. Each engine owns an independent Scryer machine; instances do not share knowledge bases.
- `engine.deinit()` — release the engine and any Rust-side resources. Required; skipping `deinit` leaks the underlying Scryer machine.

Typical pattern:

```zig
var engine = try prolog.Engine.init(allocator);
defer engine.deinit();
```

Do not call engine methods after `deinit`. Do not share a single `Engine` across threads unless you add external synchronization — the Scryer machine is not re-entrant.

## Operations

### `query(goal)`

Execute a Prolog query and return an iterator over solutions.

- Input: goal as a Prolog source string (e.g. `"parent(alice, X)."`).
- Output: a result handle that yields variable bindings per solution.
- Semantics: equivalent to posing the goal at the Scryer top-level. Failure (no solutions) is not an error.

Always consume or release the result handle. Leaking it leaves Scryer state pinned.

### `assert(clause)`

Add a clause to the knowledge base.

- Input: a single Prolog clause as a source string ending in `.`.
- Effect: equivalent to `assertz/1` — the clause is appended.
- Use `loadString` for multi-clause batches; calling `assert` in a loop is slower and less atomic.

### `retract(clause)`

Remove a clause matching the given pattern.

- Semantics: equivalent to Prolog `retract/1` — removes the first clause that unifies with the argument.
- Not an error if no clause matches; the caller must check via `query` if "was it there?" matters.

### `loadFile(path)`

Load a Prolog source file into the knowledge base.

- Input: filesystem path to a `.pl` file.
- Use for fixture-heavy scenarios (see `tests/fixtures/family.pl`).
- Relative paths resolve against the engine process's working directory, not the file that called `loadFile`.

### `loadString(source)`

Load Prolog source from an in-memory buffer.

- Input: a Prolog source string that may contain multiple clauses and directives.
- Prefer over chained `assert` calls when initializing a knowledge base.

## Error handling

All methods return Zig error unions. Callers must either handle or propagate them — there is no panic fallback at the Zig layer. On the Rust side, every FFI entry point is wrapped in panic suppression: a Scryer panic is translated into an error return rather than unwinding across the C ABI. See `ffi/zpm-prolog-ffi/src/lib.rs`.

When extending the FFI, preserve this pattern. An uncaught Rust panic that escapes into Zig is undefined behavior.

## Ownership and allocator rules

- Strings passed into `Engine` methods (goals, clauses, paths, sources) are borrowed for the duration of the call. The caller owns the backing storage.
- Result handles returned by `query` own Rust-side state and must be explicitly released (`deinit` on the result type).
- The allocator passed to `Engine.init` is used for Zig-side bookkeeping; the Rust staticlib manages its own allocations internally.

## Testing patterns

- Inline unit tests live alongside `src/prolog/engine.zig` and run under `make test`.
- End-to-end scenarios (query, assert, retract, load file) live in `tests/functional_prolog_engine_test.sh` and run under `make functional-test-engine`.
- Use `tests/fixtures/family.pl` as the reference knowledge base for new tests instead of inlining clauses.

## Worked example

`examples/roundtrip.zig` demonstrates the full path: init engine, assert a fact, query with a free variable, print the binding. Run it with `make roundtrip`. Expected output contains a line of the form `X = bob`.
