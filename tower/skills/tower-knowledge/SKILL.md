---
name: tower-knowledge
description: Configure or use Tower workspace MCP tools for indexed search, versioned edits, AST/LSP navigation, lint fixes, and debugging; install or develop native Tower sidecars.
---

# Tower

One shared daemon per workspace; persistent index; optional native sidecars.
The plugin supplies MCP configuration and guidance, not binaries or external dependencies.
Use installed MCP schemas; sidecar tools are optional and client prefixes may wrap `tower_*`.
Transport success can contain per-file failures or unsupported results.
LSP tools route by file extension to configured language servers; inspect `supported`/`outcome`
before assuming navigation, diagnostics, or rename succeeded.

When a concrete task would benefit from an unavailable or unconfigured Tower capability,
briefly explain the benefit and prerequisite. For project setup reviews or a broader
capability assessment, use [tower-optimize](../tower-optimize/SKILL.md). Keep suggestions
relevant to the task; do not repeat suggestions already explained or declined in the
conversation unless new evidence changes them. Continue useful work with available tools.

Read only the reference needed:

- Connection, workspace resolution, missing indexed files: [setup](references/setup.md).
- Native file/search tools: [files and search](references/files-and-search.md).
- Version guards, byte ranges, partial writes: [safe edits](references/safe-edits.md).
- AST, LSP, rename, lint: [semantic tools](references/semantic-tools.md).
- Live sessions or one-shot probes: [debugging](references/debugging.md).
- rr replay or last-write evidence: [reverse debugging](references/reverse-debugging.md).
- Sidecar installation or development: [extensions](references/extensions.md).
