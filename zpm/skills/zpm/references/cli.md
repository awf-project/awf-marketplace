# CLI Reference

ZPM exposes a structured command-line interface via the `zig-cli` library. Running the binary without arguments or with `--help` prints usage and exits 0; unknown subcommands and flags exit 1 on stderr.

## Subcommands

| Subcommand | Description |
|------------|-------------|
| `serve` | Start the MCP server (STDIO transport). This is the only way to start the server. |

## Flags

| Flag | Short | Description | Exit code |
|------|-------|-------------|-----------|
| `--help` | `-h` | Print usage text and exit | 0 |
| `--version` | `-v` | Print version string and exit | 0 |

## Usage

```sh
# Start the MCP server (required for all MCP client connections)
zpm serve

# Print version and exit
zpm --version
zpm -v

# Print help and exit (also the default when no arguments are given)
zpm --help
zpm -h
zpm
```

## Exit codes

| Code | Condition |
|------|-----------|
| 0 | Normal exit: server STDIO EOF, `--help`, or `--version` |
| 1 | Unknown subcommand or unrecognised flag; error message written to stderr |

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
