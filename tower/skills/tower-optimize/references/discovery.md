# Discover Tower capabilities and compatibility

## Find the source of truth

Keep the audited project and the Tower source checkout distinct. First use a checkout
supplied by the user or identified in project documentation. A nearby checkout is a
candidate: verify its remote and identity rather than assuming its name establishes that
it is Tower. The upstream repository is <https://github.com/awf-project/tower>.

Record the installed Tower version when discoverable (for example `tower --version`),
the exposed runtime schemas, and the source checkout's commit/tag and relevant local
changes. The marketplace plugin version is not the Tower executable version.
Do not switch branches, reset, pull, or modify an existing checkout merely to audit it.

If no suitable local sources exist, consult upstream through available read-only repository
or web tools. Prefer a tag/commit matching the installed executable. Avoid cloning the
full repository if targeted source access suffices. If version mapping cannot be established,
label compatibility uncertain and separate current-runtime advice from upgrade opportunities.
If upstream cannot be accessed, continue with available evidence and explicitly limit the
result; do not present the cached skill as current upstream.

## Read selectively

Use the repository's current structure; these are starting points, not guaranteed paths:

| Question | Evidence to inspect |
|---|---|
| Configuration keys, defaults, validation | `docs/user-guide/configuration.md`, `crates/core_engine/src/adapters/config/`, parser tests |
| Initialization and defaults | CLI init implementation and tests; `docs/getting-started.md` |
| Workspace visibility | `docs/towerignore.md`, scan rules, project `.towerignore` |
| Discovery, precedence, activation | `docs/extensions.md`, extension-host/discovery implementation |
| Extension tools and dependencies | Relevant `extensions/<name>/extension.toml`, implementation, tests |
| Runtime tool contracts | Installed MCP schemas first; compatible `docs/mcp-tools.md` and implementation |
| Language support and bindings | Relevant AST implementation, LSP config parser and documentation |
| Debug/rr availability | `docs/user-guide/debug-sessions.md`, debug config and platform checks |
| Installation scopes and commands | Repository `Makefile` and installation documentation |

Search relevant paths and inspect matching sections. Do not load every extension or copy a
static capability catalogue into the report. Resolve documentation conflicts with implementation
and tests at the same revision, then compare with runtime behavior. Never infer that a native
sidecar is sandboxed from its declared HostCall capabilities.

## Verify within the requested scope

Inspect existing manifests, commands, executable locations, and configuration first.
`tower status` can inspect an existing daemon; starting `tower mcp` may spawn one and
activate configured extensions. Language-server and lint probes launch external commands;
formatting and debug probes can modify files or run the application. Choose checks within
the user's scope and label deferred probes instead of executing arbitrary project commands
as a discovery shortcut.

For an addition, distinguish sidecar binary/manifest installation, discovery scope, external
dependencies (server/linter/adapter), project configuration, and client reconnection.
A build alone does not prove installation into a discovery scope. Use small representative
checks after authorized application, and inspect structured outcomes.
