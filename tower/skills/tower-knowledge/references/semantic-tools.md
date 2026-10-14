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
[lsp]
idle_timeout_secs = 300

[lsp.rust]
command = "rust-analyzer"
args = []
extensions = ["rs"]

[lsp.typescript]
command = "typescript-language-server"
args = ["--stdio"]
extensions = ["ts", "tsx"]

[lsp.python]
command = "pyright-langserver"
args = ["--stdio"]
extensions = ["py"]
```

Each `[lsp.<language>]` binds one server to extensions without dots. `command` may be a
PATH lookup or explicit path; relative explicit paths resolve from the workspace root.
`args` defaults to `[]`. Omit `idle_timeout_secs` to keep spawned sessions resident.
Malformed config is fatal at startup; absent `[lsp]` means no LSP servers.

The LSP sidecar lazily spawns one session per configured language and discovered project
root, reuses it, evicts dead/idle sessions, and respawns on next request. Project roots
are discovered per language; monorepos may have multiple sessions for one language.

`tower_lsp_diagnostics`, `tower_lsp_definition`, `tower_lsp_references`,
`tower_lsp_hover`, `tower_lsp_implementations`, `tower_lsp_rename`.
Positions: zero-based `line`, UTF-16 code-unit `character`.

Read-only result shapes:

```json
{"path":"src/main.rs"}
```

```json
{"path":"src/main.rs","line":12,"character":8}
```

Unsupported read-only operations return normal tool results with `supported:false`,
empty/null payload, and optional `outcome`; fall back to AST/text tools. Runtime backend
failures may surface as tool errors or as structured `outcome` on rename.

`outcome` fields: `status` (`unsupported` or `error`), `code`, `language`, `command`,
`operation`, `path`, `phase` (`startup` or `runtime`), `message`. Stable codes:
`language_not_configured`, `capability_unavailable`, `server_missing`, `invalid_command`,
`server_not_executable`, `server_launch_failed`, `server_crashed`, `server_timeout`,
`server_transport_error`, `server_malformed_response`, `server_error`.

Diagnostics resources: one `lsp://<language>/diagnostics` URI per configured language.
`tower_lsp_diagnostics` remains the direct pull path; resource-updated notifications signal
new published diagnostics when the client subscribes.

`tower_lsp_rename`: `path`, `line`, `character`, `new_name`, optional `dry_run`.
Preview affected files before applying. `prepareRename` runs internally when supported;
no separate MCP tool. `not_renameable` is a resolution failure.
Accepts text edits in `changes`/`documentChanges`; rejects file create/rename/delete
resource operations before writes. Rename returns:

```json
{"path":"src/lib.rs","line":10,"character":7,"new_name":"renamed","dry_run":true}
```

Dry-run result: `spans`, combined `preview`, `per_file`. Applied result: `applied`,
`files_changed`, `spans`, optional `preview`, `per_file`. Structured error result:
`code`, `message`, optional `path`, optional `outcome`. Stable rename error codes:
`not_renameable`, `unsupported_workspace_edit`, `unsupported_language`, `invalid_range`,
`backend_error`. Host apply failures stay in `per_file[*].error`.

Text replacement is not reference-aware rename.

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
