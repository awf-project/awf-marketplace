# ZPM Plugin for Claude Code and Codex

This directory extends Claude Code and Codex with ZPM-specific knowledge management capabilities,
powered by the Prolog inference engine exposed via MCP.

## Installation

Install the ZPM executable in `PATH` and Python 3 (`python3` in `PATH`), then
follow the [marketplace installation instructions](../README.md#installation).
The plugin bundles the MCP connection (`zpm serve`) and lifecycle hooks.

If building ZPM from source, follow the build prerequisites in the
[ZPM repository](https://github.com/awf-project/ZPM) and expose the resulting
`zig-out/bin/zpm` executable through `PATH`.

In Claude Code, verify the server with `/mcp`: its plugin name is
`plugin:zpm:zpm`. In Codex, start a new session and check the available ZPM tools.
Use the tool names exposed by the installed runtime; a manually registered
server and a plugin server have different namespaces.

A separate `claude mcp add zpm` registration is unnecessary when using the
plugin's bundled connection. If you already registered the same server manually,
choose one connection to avoid duplicate servers.

Codex requires review and trust of the bundled hooks through `/hooks`.

### Rebuilding after code changes

After modifying ZPM source code, rebuild and restart:

```bash
make build          # Rebuild binary
make test           # Run unit tests
make functional-test # Run end-to-end MCP protocol tests
```

Then reconnect the MCP server in Claude Code with `/mcp`.

## Quick Start

```
/zpm:zpm-capture git-state       # Store current git state as Prolog facts
/zpm:zpm-query what tasks are blocked?   # Query the knowledge base in natural language
/zpm:zpm-snapshot save milestone_v1      # Persist KB to a named snapshot
/zpm:zpm-cleanup stale                   # Remove stale assumptions
```

## Components

### Hooks (`hooks/hooks.json`)

The bundled command hooks run a Python script shared by Claude Code and Codex.

| Event | What it does |
|-------|-------------|
| `SessionStart` | Adds context asking the agent to check ZPM health and inspect the existing KB schema when tools become available |
| `Stop` | Requests one continuation to consider persisting useful discoveries and saving a snapshot; skips the reminder when `stop_hook_active` is true |

The script does not call MCP tools directly. The agent decides whether there is
anything worth storing; snapshot creation is not guaranteed. The continuation
guard prevents the reminder from repeatedly blocking the end of a turn.
Codex skips untrusted plugin hooks until you review them through `/hooks`.

### Commands (`commands/`)

Claude Code slash commands invoked with `/zpm:<name>` in the Claude Code prompt.

| Command | Arguments | Purpose |
|---------|-----------|---------|
| `/zpm:zpm-capture` | `<topic>` | Extract structured Prolog facts from context. Topics: `git-state`, `architecture`, `tasks`, `decisions`, or any freeform topic |
| `/zpm:zpm-query` | `<question>` | Translate a natural language question into Prolog goals and return results. Supports "why" questions via proof tracing |
| `/zpm:zpm-cleanup` | `[category\|all\|stale]` | Remove facts by predicate name, clear everything (with safety snapshot), or prune stale assumptions |
| `/zpm:zpm-snapshot` | `<save\|restore\|list> [name]` | Save/restore/list KB snapshots. Default save name: `session_YYYY_MM_DD` |

### Agents (`agents/`)

Specialized sub-agents spawned by Claude for complex tasks.

| Agent | When to use |
|-------|-------------|
| `zpm:zpm-analyst` | Bulk knowledge extraction: analyze source code, map architecture, graph dependencies, store structured facts |
| `zpm:zpm-reasoner` | Logical reasoning: "what-if" scenarios with assumptions, impact analysis, dependency tracing, proof explanations |

Agents are invoked by Claude automatically when the task matches, or manually via the Agent tool.

### Skill (`skills/zpm-knowledge/`)

Reference documentation loaded when Claude needs to decide how to use ZPM tools.

```
skills/zpm-knowledge/
├── SKILL.md                        # Decision tree, naming conventions, usage patterns
└── references/
    ├── mcp-tools.md                # Tool parameters, behavior, and pitfalls
    └── prolog-engine.md            # Prolog engine behavior
```

The skill activates when Claude encounters ZPM-related tasks and provides:
- **Decision tree** for selecting the right tool
- **Predicate naming conventions** (`snake_case`, `domain_relation(subject, object)`)
- **5 usage patterns**: structured capture, upsert for mutable state, assumption-based exploration, bulk lifecycle, snapshot safety
- **Anti-patterns** to avoid (unstructured atoms, duplicate facts, nested terms)

## Predicate Conventions

All facts stored in ZPM should follow these conventions:

```prolog
% Entity attributes — functor describes the domain
user_role(pocky, developer).
project_language(zpm, zig).
feature_status(f012, complete).

% Relationships
depends_on(module_a, module_b).
blocked_by(task_1, task_2).

% Mutable state (use upsert_fact — replaces by functor + first arg)
config(port, 8080).
task_status(t001, in_progress).
build_status(zpm, passing).

% Decisions with rationale
decision(auth_method, jwt, 'stateless sessions').

% Categorized for bulk cleanup (clear_context)
git_modified_file('src/main.zig').
session_note(finding, 'memory leak in handler').
```

## Tool Selection Cheat Sheet

| I want to... | Tool |
|---------------|------|
| Store a permanent fact | `remember_fact` |
| Store/update mutable state | `upsert_fact` |
| Store a hypothesis | `assume_fact` |
| Replace a known fact | `update_fact` |
| Remove one fact | `forget_fact` |
| Remove all facts of a kind | `clear_context` |
| Add inference logic | `define_rule` |
| Search/filter facts | `query_logic` |
| Understand a derivation | `explain_why` |
| Follow a dependency chain | `trace_dependency` |
| Check what's in the KB | `get_knowledge_schema` |
| Validate integrity | `verify_consistency` |
| Save KB state | `save_snapshot` |
| Restore KB state | `restore_snapshot` |

## Data Directory

ZPM persists data in `.zpm/data/` (project-local):
- `journal.wal` — Write-Ahead Log of all assert/retract operations
- `*.pl` — Snapshot files (raw Prolog clauses)

The WAL replays on server restart to restore the last known state.
