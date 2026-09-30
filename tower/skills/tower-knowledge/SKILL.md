---
name: tower-knowledge
description: Configure or use Tower workspace MCP tools for indexed search, versioned edits, AST/LSP navigation, lint fixes, and debugging; install or develop native Tower sidecars.
---

# Tower

One shared daemon per workspace; persistent index; optional native sidecars.
The plugin supplies MCP configuration and guidance, not binaries or external dependencies.
Use installed MCP schemas; sidecar tools are optional and client prefixes may wrap `tower_*`.
Transport success can contain per-file failures or unsupported results.

Read only the reference needed:

- Connection, workspace resolution, missing indexed files: [setup](references/setup.md).
- Native file/search tools: [files and search](references/files-and-search.md).
- Version guards, byte ranges, partial writes: [safe edits](references/safe-edits.md).
- AST, LSP, rename, lint: [semantic tools](references/semantic-tools.md).
- Live sessions or one-shot probes: [debugging](references/debugging.md).
- rr replay or last-write evidence: [reverse debugging](references/reverse-debugging.md).
- Sidecar installation or development: [extensions](references/extensions.md).
