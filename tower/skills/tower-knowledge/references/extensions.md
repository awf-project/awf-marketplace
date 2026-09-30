# Native sidecars

Directory = binary + `extension.toml`. Protocol: Tower JSON-RPC stdio, not client MCP.
Exposed names: `tower_<extension>_<tool>`; extension names beginning with `tower` reserved.

## Discovery/install

`--extensions-dir` > `TOWER_EXTENSIONS_DIR` > default global XDG `tower/extensions/`
then workspace `.tower/extensions/` (local wins collisions). Explicit directory replaces
search path.

`cargo build --workspace --bins` builds but does not install discovery scopes.
In Tower checkout, `make install-extensions` defaults to local scope; knobs:
`EXT_DEST`, `EXTENSIONS`, `EXT_PROFILE`. Disable via `[extensions] disabled = ["lsp"]`,
not `[plugins]`.

Event subscribers require eager activation; lazy + subscriptions is rejected.
Historical events are not replayed. Faults may skip/quarantine a sidecar without closing MCP.

## Development

Wire types: `crates/extension_protocol`; lifecycle: `initialize`, `invokeTool`,
`deliverEvent`, `shutdown`. Manifest capabilities gate host callbacks, not arbitrary OS
access: native sidecars are not sandboxed.

Semantic writers declare `request_apply_edits` and call `workspace/applyEdits` with byte
spans/resolve-time hashes. Host owns validation, CAS, writes and index refresh; see
[safe edits](safe-edits.md). Reads/index/log/format also use host callbacks.
Use `extension_sidecar_harness` to queue inbound host requests while waiting for host-call
replies. Release mutation/registry locks before mutation events to avoid reentrant deadlocks.

Engine architecture: DDD/hexagonal/microkernel; domain → ports, adapters → filesystem/
process/transport, composition root → wiring.
Merge gate: `cargo fmt --all --check`, `cargo clippy --workspace --all-targets -- -D warnings`,
`cargo build --workspace --bins`, `cargo test --workspace`, `cargo deny check`.
