---
description: Clean up the ZPM knowledge base — remove stale facts, retract assumptions, verify integrity
allowed-tools:
  - mcp__zpm__get_knowledge_schema
  - mcp__zpm__query_logic
  - mcp__zpm__forget_fact
  - mcp__zpm__clear_context
  - mcp__zpm__retract_assumptions
  - mcp__zpm__list_assumptions
  - mcp__zpm__verify_consistency
  - mcp__zpm__save_snapshot
  - mcp__zpm__get_persistence_status
argument-hint: "[category|all|stale] e.g., 'git_modified_file', 'all', 'stale assumptions'"
---

Clean up the ZPM knowledge base based on "$ARGUMENTS".

## Behavior

- **specific category**: `mcp__zpm__clear_context` for that predicate
- **all**: Save a safety snapshot first, then clear all predicates found via `mcp__zpm__mcp__zpm__get_knowledge_schema`
- **stale assumptions**: `mcp__zpm__list_assumptions`, review each with `get_justification`, retract those no longer relevant
- **no argument**: Show current KB state with `mcp__zpm__get_knowledge_schema` and ask what to clean

Always run `mcp__zpm__verify_consistency` after cleanup. Report what was removed.
