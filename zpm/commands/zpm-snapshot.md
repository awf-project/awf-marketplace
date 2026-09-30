---
description: Manage ZPM knowledge base snapshots — save, restore, or list
allowed-tools:
  - mcp__plugin_zpm_zpm__save_snapshot
  - mcp__plugin_zpm_zpm__restore_snapshot
  - mcp__plugin_zpm_zpm__list_snapshots
  - mcp__plugin_zpm_zpm__get_persistence_status
  - mcp__plugin_zpm_zpm__get_knowledge_schema
argument-hint: "<save|restore|list> [name]"
---

Manage ZPM snapshots based on "$ARGUMENTS".

## Actions

- **save [name]**: Save current KB state. Default name: `session_YYYY_MM_DD`
- **restore [name]**: List available snapshots, restore the named one, show what was loaded via `mcp__plugin_zpm_zpm__get_knowledge_schema`
- **list**: Show all available snapshots with `mcp__plugin_zpm_zpm__list_snapshots`
- **no argument**: Show `mcp__plugin_zpm_zpm__get_persistence_status` and `mcp__plugin_zpm_zpm__list_snapshots`
