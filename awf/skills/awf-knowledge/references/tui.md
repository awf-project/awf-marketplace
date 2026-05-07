# TUI Reference

`awf tui` opens a full-screen Bubble Tea terminal dashboard with five tabs for interactive workflow management and real-time execution visibility.

## Launch

```bash
awf tui
```

Requires an interactive terminal. Not usable in non-interactive environments (pipes, CI/CD).

## Tabs

| Tab | Key | Description |
|-----|-----|-------------|
| Workflows | `1` | Browse, filter, launch, and validate workflows |
| Monitoring | `2` | Live execution tree with step status and log viewport |
| History | `3` | Past executions filterable by name, status, or date |
| Agent Conversations | `4` | Agent turn-by-turn conversation view |
| External Logs | `5` | Live tail of Claude Code JSONL session files |

## Keyboard Reference

### Global

| Key | Action |
|-----|--------|
| `1`–`5` | Switch to tab |
| `q` / `ctrl+c` | Quit (terminal state restored on exit, panic, and signal) |
| `/` | Focus filter input |
| `esc` | Clear filter / cancel |
| `tab` | Move between panels |
| `↑` / `↓` | Navigate list |
| `k` / `j` | Navigate list (vi keys) |
| `pgup` / `pgdn` | Scroll viewport |

### Workflows Tab

| Key | Action |
|-----|--------|
| `enter` | Launch selected workflow — collects missing inputs interactively |
| `v` | Validate selected workflow |

Workflows list shows local workflows and all installed pack workflows (listed as `pack/workflow`). Use `/` to filter by name.

Launching a workflow collects required inputs via inline prompts, then starts execution and auto-switches to the Monitoring tab.

### Monitoring Tab

Switches to this tab automatically when a workflow launches from the Workflows tab.

**Execution tree status icons:**

| Icon | Meaning |
|------|---------|
| `⏳` | pending |
| `▶` | running |
| `✓` | success |
| `✗` | failed |
| `⊘` | skipped |

Failed steps are auto-selected in the execution tree. The log viewport auto-scrolls while a step is running and locks on manual scroll.

The tree refreshes every 200 ms via `tea.Tick`-based polling.

### History Tab

| Key | Action |
|-----|--------|
| `enter` | Open detail view with full execution tree for the selected run |
| `/` | Filter by workflow name, status (`success`, `failed`, `interrupted`), or date |

History is read from the SQLite store (`$XDG_STATE_HOME/awf/`). The same data is shown by `awf history`.

### External Logs Tab

Live tails Claude Code JSONL session files discovered via XDG paths. Uses `fsnotify` for file-system events; falls back gracefully when no session files are present. New lines append as they are written.

## Architecture Notes

The TUI uses the Bridge pattern: `internal/interfaces/tui/bridge.go` wraps `WorkflowService`, `ExecutionService`, and `HistoryService` as async `tea.Cmd` factories. Secret masking is applied in the bridge layer before display. Zero infrastructure imports in the bridge implementation.

`ExecutionService.RunWorkflowAsync` returns an `ExecutionContext` and a `<-chan error` immediately, letting the TUI observe live state without blocking the UI event loop.

## Requirements

- Terminal supporting 256 colors (basic ANSI fallback available automatically)
- Interactive stdin (not usable with pipes or `CI=true` environments)

## See Also

- [CLI Commands Reference](cli-commands.md#awf-tui) — `awf tui` command entry
- [Interactive Inputs](interactive-inputs.md) — how input collection works when launching from TUI
- [Audit Trail](audit-trail.md) — execution history stored in SQLite (same data as History tab)
