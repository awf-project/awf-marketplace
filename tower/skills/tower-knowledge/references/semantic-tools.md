# AST, LSP, lint

## AST

Supports Rust, Go, PHP; unsupported languages return in-band results.
Spans use bytes and zero-based rows/columns.

| Tool (`tower_ast_` prefix) | Arguments |
|---|---|
| `get_outline` | `path` |
| `find_symbols` | `path`, `symbol_name`, `kind` |
| `read_symbol` | `path`, `symbol_name`, `kind?` |
| `search_symbols` | `name`, `kind?` |
| `reindex` | none; rebuild cold/incomplete cross-file symbol cache |

Anchored writes: `replace_symbol_body`, `insert_before_symbol`, `insert_after_symbol`,
`delete_symbol`, all under `tower_ast_`. Selector: `path`, `symbol_name`, optional `kind`;
`replacement` required except for delete. Preview with `dry_run:true`.

Exactly one symbol must resolve. `ambiguous_symbol` returns candidates; filter by `kind`.
If ambiguity remains, use candidate spans and a version-guarded range edit.
Body replacement preserves signature; for brace-delimited functions supply the interior,
without braces. Bodyless declarations cannot use it. Delete removes only the declaration,
not references. Signature changes require range edits, not a dedicated semantic tool.
Apply/CAS/partial-write rules: [safe edits](safe-edits.md).

## LSP

`.tower/config.toml`:

```toml
[lsp.rust]
command = "rust-analyzer"
args = []
extensions = ["rs"]
```

`tower_lsp_diagnostics`, `definition`, `references`, `hover`, `implementations`
(the latter names also prefixed `tower_lsp_`). Positions: zero-based `line`,
UTF-16 code-unit `character`. `supported:false` allows AST/text fallback.

`tower_lsp_rename`: `path`, `line`, `character`, `new_name`, optional `dry_run`.
Preview affected files before applying. `prepareRename` runs internally when supported;
no separate MCP tool. `not_renameable` is a resolution failure.
Accepts text edits in `changes`/`documentChanges`; rejects file create/rename/delete
resource operations before writes. Text replacement is not reference-aware rename.

## Lint

```toml
[lint.rust]
command = "cargo"
args = ["clippy", "--message-format=json"]
extensions = ["rs"]
format = "rustc-json"
target = "none"
```

`tower_lint_check` reports diagnostics. `tower_lint_fix` previews with
`{"path":"src/lib.rs","dry_run":true}`; omit dry-run to apply. Omit `path` to process
all matching indexed files. `unsafe:true` opts into non-safe suggestions.
Fix extraction: `rustc-json`, `eslint-json`; `generic-regex` supports diagnostics only.

Inspect `files_changed`, `fixes_skipped` (unsafe, unsupported, overlap, CAS, invalid range),
`remaining_diagnostics` (one follow-up pass after writes). Dry-run `fixes_applied` counts
previewed fixes while `files_changed` stays zero.
Formatting uses host `workspace/requestFormat`; no `tower_fmt_format` MCP tool.
