# Tower Plugin

Workspace MCP integration for Claude Code and Codex.

The [tower-knowledge skill](skills/tower-knowledge/SKILL.md) guides agents through:

- Indexed file search and directory listing.
- Version-guarded edits and concurrent-change handling.
- AST symbol navigation and editing, LSP reference-aware rename, and lint fixes.
- Live debugging, one-shot probes, and rr replay for last-write evidence.
- Workspace resolution and native sidecar development.

The skill routes each task to its relevant reference. AST, LSP, lint, and debug tools
are conditional on available sidecars and workspace configuration.

[.mcp.json](.mcp.json) declares the Tower MCP server. Runtime tool schemas determine
the installed contracts; the skill documents selection criteria and Tower-specific pitfalls.

## Installation

Install the Tower executable in `PATH` first, then follow the
[marketplace installation instructions](../README.md#installation). The plugin
starts `tower mcp`; it does not install the binary or optional sidecars.
Verify the connection with `/mcp` in Claude Code or the MCP tools in a new Codex session.
