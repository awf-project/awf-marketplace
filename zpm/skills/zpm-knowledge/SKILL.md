---
name: zpm
description: ZPM MCP server - Zig-based Model Context Protocol server exposing a Trealla Prolog logic engine over STDIO. Use this skill when building, configuring, or using the ZPM server to execute Prolog queries, assert or retract facts, and load knowledge bases from MCP clients.
---

# ZPM

ZPM embeds Trealla Prolog in a Zig MCP server over STDIO. Use the runtime's installed tool names and schemas; client prefixes vary. Names below identify tool suffixes, not a required namespace.

## Query or persist knowledge

1. Check `get_persistence_status` before relying on durability. In `degraded` mode writes can succeed in memory without surviving restart.
2. Inspect `get_knowledge_schema` and query the relevant existing predicates before introducing facts or rules. Reuse the project's schema when it fits.
3. Select the mounted segment with the optional `memory` parameter; omission targets `default`. Read-only segments reject writes. See [memory segments](references/memory-segments.md) for mounting and cross-segment reads.

Operational distinctions:

- Omit the trailing period in MCP `fact`, `goal`, and `head`/`body` arguments; tools append it. This convention does not apply to raw Prolog source files or Engine API examples.
- `remember_fact` asserts; `upsert_fact` matches by functor and first argument. Choose the key deliberately to avoid replacing unrelated knowledge.
- `forget_fact` retracts one match; `clear_context` retracts all matches. `update_fact` fails without mutation when the old fact is absent.
- `restore_snapshot` wipes the current knowledge base before reload and journal replay. Inspect the intended snapshot and scope before restoration.

Read [MCP tools](references/mcp-tools.md) for exact schemas, error shapes, assumptions, proof explanations, consistency checks, and snapshots.

## Set up or diagnose the server

`zpm serve` starts MCP; invoking `zpm` alone prints help. The server discovers `.zpm/` upward from its working directory. Use `zpm init` when the project needs a new knowledge store, not merely to test connectivity.

MCP configuration must pass `args: ["serve"]`. The client working directory determines project discovery. A missing project directory prevents startup; an unwritable data directory can cause degraded persistence.

Prolog source belongs in `.zpm/kb/<segment>/*.pl`; WAL files live in `.zpm/data/`; `.zpm/mounts.json` tracks mounts. The old flat `.zpm/kb/*.pl` layout needs migration into segment directories. Preserve existing data when diagnosing format incompatibilities; inspect [architecture](references/architecture.md) before planning recovery.

For CLI use without MCP, command arguments and output formats, see [CLI](references/cli.md). For segment scope, read-only mounts, and manifest behavior, see [memory segments](references/memory-segments.md).

## Develop ZPM

- Build/link/submodule failures: [build](references/build.md). Requires Zig, a C compiler, and make; initialize the Trealla git submodule before building.
- Prolog operations or ownership: [Engine API](references/prolog-engine.md). Tool handlers use `Engine`; direct FFI calls belong inside the engine implementation.
- Persistence, project discovery, or layer changes: [architecture](references/architecture.md).

Run checks in the ZPM source checkout, not in a project that merely consumes the plugin: `make test` for Zig tests, `make functional-test-engine` for engine integration, and `make functional-test` for CLI/MCP integration. Reuse `tests/fixtures/family.pl` for existing family-engine scenarios. Keep C ABI errors mapped to Zig errors rather than unwinding across the boundary.
