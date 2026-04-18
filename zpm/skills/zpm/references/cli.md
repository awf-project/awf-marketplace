# CLI Reference

ZPM exposes a structured command-line interface via the `zig-cli` library. Running the binary without arguments or with `--help` prints usage and exits 0; unknown subcommands and flags exit 1 on stderr.

## Subcommands

| Subcommand | Description |
|------------|-------------|
| `init` | Initialize a `.zpm/` project directory in the current working directory |
| `serve` | Start the MCP server (STDIO transport). Requires a discoverable `.zpm/` project. |

## Flags

| Flag | Short | Description | Exit code |
|------|-------|-------------|-----------|
| `--help` | `-h` | Print usage text and exit | 0 |
| `--version` | `-v` | Print version string and exit | 0 |

## Usage

```sh
# Initialize a project (required once per project before serving)
zpm init

# Start the MCP server (walks up from cwd to find .zpm/)
zpm serve

# Print version and exit
zpm --version
zpm -v

# Print help and exit (also the default when no arguments are given)
zpm --help
zpm -h
zpm
```

## `init` subcommand

Creates the following layout in the current working directory:

```
.zpm/
  kb/          # Versionable: Prolog sources (*.pl) and snapshots
  data/        # Ephemeral: WAL journal and locks (gitignored)
  .gitignore   # Contains `data/`
```

- Idempotent: a second `zpm init` on an existing project exits 0 without modifying files.
- Commit `.zpm/kb/` to version control so the team shares the same knowledge base. `.zpm/data/` is runtime-only and excluded.
- Exits 1 on permission / filesystem errors.

## `serve` subcommand

On startup, `zpm serve`:

1. Walks up from the current working directory until it finds a `.zpm/` directory (bounded to the same filesystem device — does not cross mount points).
2. Loads every `*.pl` file in `.zpm/kb/` into the engine via `engine.loadFile`.
3. Initializes `PersistenceManager` with dual paths: WAL journal in `.zpm/data/`, snapshots in `.zpm/kb/`.
4. Begins reading MCP JSON-RPC frames on stdin; writes responses on stdout; logs on stderr.

Failure modes:

- No `.zpm/` found in the ancestry → exits 1 with `error: no project directory found` / `hint: run 'zpm init'`.
- `.zpm/data/` exists but is not writable → server starts in **degraded mode** (in-memory only, no WAL / snapshots). Verify with `get_persistence_status` (`mode == "degraded"`).
- `.pl` files that fail to load are logged to stderr; the server continues with the remaining files.

## Exit codes

| Code | Condition |
|------|-----------|
| 0 | Normal exit: server STDIO EOF, successful `init`, `--help`, or `--version` |
| 1 | Unknown subcommand, unrecognised flag, `init` filesystem error, or `serve` with no `.zpm/` in ancestry |

## MCP client configuration

All MCP clients must pass the `serve` subcommand in their invocation. The binary alone does not start the MCP server.

**Claude Code (`~/.claude.json` or project `.mcp.json`):**

```json
{
  "mcpServers": {
    "zpm": {
      "command": "/path/to/zpm",
      "args": ["serve"]
    }
  }
}
```

**Claude Desktop (`claude_desktop_config.json`):**

```json
{
  "mcpServers": {
    "zpm": {
      "command": "/path/to/zpm",
      "args": ["serve"]
    }
  }
}
```

**Generic MCP client:**

```sh
/path/to/zpm serve
```

The process communicates exclusively over stdin/stdout. No TCP port is opened.

## Breaking change: implicit server start removed

Before this CLI was introduced, running the binary directly started the MCP server. That behaviour no longer exists. Any wrapper script, systemd unit, or MCP client config that invokes `zpm` without the `serve` subcommand must be updated to `zpm serve`.

## Breaking change: `.zpm/` project directory required

`zpm serve` now requires a `.zpm/` directory in the current directory or an ancestor. Existing setups that relied on an ambient working directory must be migrated:

1. `cd` to the project root.
2. Run `zpm init` once.
3. Move or re-create any existing `.pl` files into `.zpm/kb/` so they load automatically.
4. Update MCP client configs if they rely on the server running from a specific directory — the client's working directory at spawn time is the discovery root.
