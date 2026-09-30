# Setup

`tower init` at the project root scaffolds `.towerignore` and `.tower/config.toml`.
Indexing follows `.towerignore`, independently of `.gitignore`. Without it, Tower warns
and indexes non-hidden files except `.git/`.

```json
{"mcpServers":{"tower":{"command":"tower","args":["mcp"]}}}
```

Workspace resolution: `--workspace-dir <path>` > `TOWER_WORKSPACE` > cwd.
Explicit-root args: `["--workspace-dir","/path/to/project","mcp"]`.
The required subcommand is `mcp`, not `serve` or the bare binary.

| Command | Effect |
|---|---|
| `tower mcp` | Connect/spawn daemon; relay stdio MCP |
| `tower status` | Inspect resolved workspace daemon |
| `tower daemon` | Run foreground daemon |
| `tower shutdown` | Stop daemon for all connected clients |

The shared daemon owns watcher, `.tower/db/`, and extensions. Configuration changes
require daemon restart and client reconnection; account for connected clients.
Missing indexed files: check root, ignore rules, then freshness. `tower_reindex` rebuilds
files/search; `tower_ast_reindex` separately rebuilds symbols. Index absence does not prove
disk absence. Deleting `.tower/db/` is not a routine refresh.

Sidecar discovery/install: [extensions](extensions.md).
