# ZPM Claude Code Integration

This directory extends Claude Code with ZPM-specific knowledge management capabilities,
powered by the Prolog inference engine exposed via MCP.

## Prerequisites

- **Zig >= 0.15.2** — [ziglang.org/download](https://ziglang.org/download/)
- **Rust stable** — `curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh`
- **Claude Code** — `npm install -g @anthropic-ai/claude-code` (or native install)

## Installation

### 1. Build the ZPM server

```bash
cd /path/to/zpm
make build
```

This compiles the Rust FFI staticlib (scryer-prolog) then the Zig binary.
Output: `zig-out/bin/zpm`

### 2. Register the MCP server in Claude Code

```bash
claude mcp add zpm --scope project -- /path/to/zpm/zig-out/bin/zpm serve
```

This adds the following to `~/.claude.json` under the project key:

```json
"zpm": {
  "type": "stdio",
  "command": "/path/to/zpm/zig-out/bin/zpm",
  "args": ["serve"],
  "env": {}
}
```

### 3. Enable the server for the project

In `.claude/settings.local.json`, ensure ZPM is enabled:

```json
{
  "enableAllProjectMcpServers": true,
  "enabledMcpjsonServers": ["zpm"]
}
```

### 4. Verify the connection

Start a new Claude Code session in the project directory and run:

```
/mcp
```

ZPM should appear in the list of connected servers. You can also test with:

```
Tell Claude: "Use the echo tool to say hello"
```

### 5. (Optional) Enable session hooks

The project ships with two hooks in `settings.local.json` that make Claude use ZPM proactively:

- **SessionStart**: Checks KB health and loads existing facts at the start of each session
- **Stop**: Prompts Claude to persist important discoveries before ending

These are already configured if you use the project's `settings.local.json`. To add them manually:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "prompt",
            "prompt": "The ZPM Prolog MCP server is available. Run get_persistence_status to check health, then get_knowledge_schema to see what's already in the knowledge base..."
          }
        ]
      }
    ],
    "TaskCompleted": [
      {
        "hooks": [
          {
            "type": "prompt",
            "prompt": "Before ending, consider if any important discoveries should be persisted in the ZPM knowledge base..."
          }
        ]
      }
    ]
  }
}
```

### 6. (Optional) Auto-approve ZPM tools

To avoid permission prompts for every ZPM tool call, add them to the allow list
in `.claude/settings.local.json`:

```json
{
  "permissions": {
    "allow": [
      "mcp__zpm__echo",
      "mcp__zpm__remember_fact",
      "mcp__zpm__forget_fact",
      "mcp__zpm__update_fact",
      "mcp__zpm__upsert_fact",
      "mcp__zpm__clear_context",
      "mcp__zpm__define_rule",
      "mcp__zpm__query_logic",
      "mcp__zpm__explain_why",
      "mcp__zpm__trace_dependency",
      "mcp__zpm__assume_fact",
      "mcp__zpm__retract_assumption",
      "mcp__zpm__retract_assumptions",
      "mcp__zpm__list_assumptions",
      "mcp__zpm__get_belief_status",
      "mcp__zpm__get_justification",
      "mcp__zpm__verify_consistency",
      "mcp__zpm__get_knowledge_schema",
      "mcp__zpm__save_snapshot",
      "mcp__zpm__restore_snapshot",
      "mcp__zpm__list_snapshots",
      "mcp__zpm__get_persistence_status"
    ]
  }
}
```

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
/zpm-capture git-state       # Store current git state as Prolog facts
/zpm-query what tasks are blocked?   # Query the knowledge base in natural language
/zpm-snapshot save milestone_v1      # Persist KB to a named snapshot
/zpm-cleanup stale                   # Remove stale assumptions
```

## Components

### Hooks (`settings.local.json` > `hooks`)

Automatic behaviors triggered by Claude Code lifecycle events, configured in `settings.local.json`.

| Event | What it does |
|-------|-------------|
| `SessionStart` | Checks ZPM health (`get_persistence_status`), loads current KB schema (`get_knowledge_schema`), reminds Claude to use ZPM proactively |
| `Stop` | Prompts Claude to persist important session discoveries before ending, auto-saves a dated snapshot if the KB has content |

Hooks run automatically — no user action needed.

### Commands (`commands/`)

Slash commands invoked with `/<name>` in the Claude Code prompt.

| Command | Arguments | Purpose |
|---------|-----------|---------|
| `/zpm-capture` | `<topic>` | Extract structured Prolog facts from context. Topics: `git-state`, `architecture`, `tasks`, `decisions`, or any freeform topic |
| `/zpm-query` | `<question>` | Translate a natural language question into Prolog goals and return results. Supports "why" questions via proof tracing |
| `/zpm-cleanup` | `[category\|all\|stale]` | Remove facts by predicate name, clear everything (with safety snapshot), or prune stale assumptions |
| `/zpm-snapshot` | `<save\|restore\|list> [name]` | Save/restore/list KB snapshots. Default save name: `session_YYYY_MM_DD` |

### Agents (`agents/`)

Specialized sub-agents spawned by Claude for complex tasks.

| Agent | When to use |
|-------|-------------|
| `zpm-analyst` | Bulk knowledge extraction: analyze source code, map architecture, graph dependencies, store structured facts |
| `zpm-reasoner` | Logical reasoning: "what-if" scenarios with assumptions, impact analysis, dependency tracing, proof explanations |

Agents are invoked by Claude automatically when the task matches, or manually via the Agent tool.

### Skill (`skills/zpm-knowledge/`)

Reference documentation loaded when Claude needs to decide how to use ZPM tools.

```
skills/zpm-knowledge/
├── SKILL.md                        # Decision tree, naming conventions, usage patterns
└── references/
    ├── tool-catalog.md             # All 22 tools: parameters, behavior, pitfalls
    └── query-patterns.md           # Prolog query recipes: joins, negation, aggregation
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
