# CLI Reference

ZPM exposes a structured command-line interface. Running the binary without arguments or with `--help` prints usage and exits 0; unknown subcommands and flags exit 1 on stderr.

## Subcommands

| Subcommand | Description |
|------------|-------------|
| `init` | Initialize a `.zpm/` project directory in the current working directory |
| `serve` | Start the MCP server (STDIO transport). Requires a discoverable `.zpm/` project. |
| `<tool-name> [args]` | Invoke any of the 22 MCP tools directly from the shell. See [Tool subcommands](#tool-subcommands). |

## Flags

| Flag | Short | Description | Exit code |
|------|-------|-------------|-----------|
| `--help` | `-h` | Print usage text and exit | 0 |
| `--version` | `-v` | Print version string and exit | 0 |
| `--format` | | Output format for tool subcommands: `text` (default) or `json` | — |

## Usage

```sh
# Initialize a project (required once per project before serving)
zpm init

# Start the MCP server (walks up from cwd to find .zpm/)
zpm serve

# Invoke a tool directly (no MCP client required)
zpm remember-fact "task_status(f017,done)"
zpm query-logic "task_status(X,done)" --format json | jq '.[0].X'

# Print version and exit
zpm --version
zpm -v

# Print help and exit (also the default when no arguments are given)
zpm --help
zpm -h
zpm
```

## Tool subcommands

All 22 MCP tools are available as first-class CLI subcommands. Tool names use kebab-case (e.g. `remember-fact`, `query-logic`). The knowledge base is loaded from the nearest `.zpm/` directory before any tool executes.

### Argument convention

- **First required field** → positional argument (no flag prefix)
- **Remaining fields** → `--kebab-case` flags

```sh
# First required field is positional; additional fields are flags
zpm remember-fact "parent(alice,bob)"
zpm query-logic "parent(alice,X)"
zpm save-snapshot --name "before-refactor"
zpm restore-snapshot "before-refactor"
zpm forget-fact "parent(alice,bob)"
zpm assume-fact "urgent(task1)" --assumption "sprint-3"
```

### `--format` flag

| Value | Behaviour |
|-------|-----------|
| `text` (default) | Human-readable output on stdout |
| `json` | Machine-readable JSON on stdout; suitable for `jq` pipelines |

```sh
zpm query-logic "task_status(X,done)" --format json | jq '.[0].X'
zpm list-snapshots --format json | jq '.[].name'
zpm get-persistence-status --format json | jq '.mode'
```

### Exit codes

| Code | Condition |
|------|-----------|
| 0 | Tool executed successfully |
| 1 | Tool error, missing required argument, or no `.zpm/` found |

Errors are written to stderr; stdout receives only the tool result.

### All 22 tool subcommands

| Subcommand | Write | Description |
|------------|-------|-------------|
| `echo` | no | Test connectivity |
| `remember-fact` | yes | Assert a Prolog fact |
| `define-rule` | yes | Assert a Prolog rule (`Head :- Body`) |
| `query-logic` | no | Execute a Prolog goal; returns variable bindings |
| `trace-dependency` | no | Traverse transitive dependencies via `path/2` |
| `verify-consistency` | no | Query `integrity_violation/N` predicates |
| `explain-why` | no | Reconstruct proof chain via `clause/2` |
| `get-knowledge-schema` | no | Introspect all user-defined predicates |
| `forget-fact` | yes | Retract the first matching fact |
| `clear-context` | yes | Retract all facts matching a category pattern |
| `update-fact` | yes | Atomic retract+assert (`old_fact` → `new_fact`) |
| `upsert-fact` | yes | Replace existing fact by functor+first arg or insert |
| `assume-fact` | yes | Assert a fact under a named assumption |
| `get-belief-status` | no | Query whether a belief is supported |
| `get-justification` | no | List facts supported by a given assumption |
| `list-assumptions` | no | Enumerate all active assumptions |
| `retract-assumption` | yes | Remove one assumption and cascade to dependent facts |
| `retract-assumptions` | yes | Bulk-remove assumptions matching a glob pattern |
| `save-snapshot` | yes | Create a named knowledge-base snapshot |
| `restore-snapshot` | yes | Restore from a named snapshot |
| `list-snapshots` | no | List available snapshots with metadata |
| `get-persistence-status` | no | Report journal size, last snapshot, and mode |

### Concurrency warning

Tool subcommands share the same WAL journal and knowledge base as a running `zpm serve` process. Do not invoke tool subcommands concurrently with a live server against the same `.zpm/` directory — concurrent writes will corrupt the journal.

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
| 0 | Normal exit: server STDIO EOF, successful `init`, `--help`, `--version`, or successful tool subcommand |
| 1 | Unknown subcommand, unrecognised flag, `init` filesystem error, `serve` with no `.zpm/` in ancestry, or tool subcommand error |

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
