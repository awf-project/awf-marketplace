# Memory Segments

Named, isolated knowledge segments backed by Prolog modules. Each segment has its own WAL journal, snapshot files, and on-disk directory under `.zpm/kb/<name>/`. Segments are mounted into the running engine and can be queried independently or jointly via module qualification.

## Concepts

| Term | Meaning |
|------|---------|
| Segment | A named Prolog module with isolated state and persistence. |
| `default` | Always-present segment, created on first boot, cannot be unmounted. |
| Scope | `project` (per-`.zpm/`) or `global` (shared across projects). |
| Mode | `rw` (read-write, default) or `ro` (read-only). |
| Mount | Loading a segment into the running engine. |
| Manifest | `.zpm/mounts.json` — mount list persisted across CLI invocations. |

## Directory layout

```
.zpm/
  kb/
    default/         # default segment (auto-created on first boot)
      knowledge.pl
      <snapshot>.snap
    <name>/          # one directory per mounted segment
      knowledge.pl
      <snapshot>.snap
  data/
    <name>.wal       # one WAL file per segment
  mounts.json        # mount manifest (auto-discovered on first boot)
```

The pre-F021 flat `.zpm/kb/` layout is no longer supported. Existing knowledge bases must be re-initialized into the per-segment layout.

## Lifecycle

```
create  → mount  → use (with --memory)  → unmount (optional)
                              ↓
                      survives restart
                      via mounts.json
```

1. **create** — provisions `.zpm/kb/<name>/knowledge.pl` and the segment directory. Does not load the segment into the engine.
2. **mount** — loads the segment, registers it in the manifest, and makes it addressable via `--memory <name>` or the `memory` MCP parameter.
3. **use** — every read/write tool accepts an optional `--memory` flag (CLI) or `memory` parameter (MCP). Omitting it targets `default`.
4. **unmount** — flushes the WAL, unloads the segment, and removes it from the manifest. Unmounting `default` is rejected.

## Auto-mount on boot

`zpm serve` and every CLI tool subcommand read `.zpm/mounts.json` at startup and mount every listed segment automatically.

- First boot: if `mounts.json` is missing, ZPM creates `default`, scans `.zpm/kb/` for existing segment directories, and writes them into the manifest.
- Subsequent boots: the manifest is the source of truth. Manual re-mounting after each invocation is not required.

## CLI usage

```sh
# Create a new project-scoped segment
zpm memory create --name design_decisions

# Mount it read-write (default mode)
zpm memory mount --name design_decisions

# Write into a specific segment
zpm remember-fact "rationale(api_v2, security)" --memory design_decisions

# Query a specific segment
zpm query-logic "rationale(X, security)" --memory design_decisions

# List mounted segments with scope and mode
zpm memory list --format json
# => [{"name":"default","scope":"project","mode":"rw"},
#     {"name":"design_decisions","scope":"project","mode":"rw"}]

# Mount read-only — writes return an error, reads succeed
zpm memory mount --name reference_corpus --mode ro
zpm remember-fact "x(1)" --memory reference_corpus
# stderr: error: memory 'reference_corpus' is read-only

# Unmount (default cannot be unmounted)
zpm memory unmount --name design_decisions
```

## Cross-memory queries

Use Prolog module qualification (`Module:Goal`) to query across mounted segments in a single goal:

```sh
zpm query-logic "design_decisions:rationale(X, Y), default:owner(X, Team)"
```

Cross-memory queries are read-only by construction (writes always target a single `--memory` target).

## MCP tools

Four new tools manage segments; all 20 existing knowledge/reasoning tools accept an optional `memory` parameter.

### `create_memory`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | yes | Segment name (Prolog atom: `[a-z][a-z0-9_]*`) |
| `scope` | string | no | `project` (default) or `global` |

Creates the on-disk directory and `knowledge.pl` header. Does not mount.

```json
{"jsonrpc":"2.0","id":1,"method":"tools/call",
 "params":{"name":"create_memory","arguments":{"name":"design_decisions"}}}
```

### `mount_memory`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | yes | Segment name (must already exist on disk) |
| `mode` | string | no | `rw` (default) or `ro` |

Mounts the segment, replays its WAL, persists to `.zpm/mounts.json`.

```json
{"jsonrpc":"2.0","id":2,"method":"tools/call",
 "params":{"name":"mount_memory","arguments":{"name":"design_decisions","mode":"ro"}}}
```

### `unmount_memory`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | yes | Segment name to unmount |

Flushes the WAL, frees resources, removes from manifest. Returns `ExecutionFailed` for `default`.

```json
{"jsonrpc":"2.0","id":3,"method":"tools/call",
 "params":{"name":"unmount_memory","arguments":{"name":"design_decisions"}}}
```

### `list_memories`

No arguments. Returns mounted segments with scope and mode.

```json
{"jsonrpc":"2.0","id":4,"method":"tools/call",
 "params":{"name":"list_memories","arguments":{}}}
```

Response:

```json
{"jsonrpc":"2.0","id":4,"result":{"content":[{"type":"text",
 "text":"[{\"name\":\"default\",\"scope\":\"project\",\"mode\":\"rw\"},{\"name\":\"design_decisions\",\"scope\":\"project\",\"mode\":\"ro\"}]"}]}}
```

## `memory` parameter on existing tools

All 20 knowledge/reasoning tools (`remember_fact`, `define_rule`, `query_logic`, `forget_fact`, `clear_context`, `update_fact`, `upsert_fact`, `assume_fact`, `get_belief_status`, `get_justification`, `list_assumptions`, `retract_assumption`, `retract_assumptions`, `save_snapshot`, `restore_snapshot`, `list_snapshots`, `trace_dependency`, `explain_why`, `get_knowledge_schema`, `verify_consistency`) accept an optional `memory` field.

- Type: string
- Required: no
- Default: `default`
- Validation: must name a currently mounted segment

Writing to a read-only segment returns `ExecutionFailed` with stderr text `memory '<name>' is read-only`. Reads against `ro` segments always succeed.

## Errors

| Condition | Tool result |
|-----------|-------------|
| Segment name not a valid Prolog atom | `InvalidArguments` |
| `create_memory` on existing name | `ExecutionFailed` |
| `mount_memory` on non-existent directory | `ExecutionFailed` |
| `unmount_memory` on `default` | `ExecutionFailed` |
| Tool targets unmounted segment | `ExecutionFailed` |
| Write tool targets `ro` segment | `ExecutionFailed` |

## Verification recipe

```sh
zpm memory create --name test_seg
zpm remember-fact "x(1)" --memory test_seg
zpm query-logic "x(X)" --memory test_seg
# => [{"X":"1"}]

# Restart the process; manifest auto-mounts test_seg
zpm query-logic "x(X)" --memory test_seg
# => [{"X":"1"}]

# Switch to read-only; writes fail
zpm memory unmount --name test_seg
zpm memory mount --name test_seg --mode ro
zpm remember-fact "y(2)" --memory test_seg
# stderr: error: memory 'test_seg' is read-only
zpm query-logic "x(X)" --memory test_seg
# => [{"X":"1"}]
```
