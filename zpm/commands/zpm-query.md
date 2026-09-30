---
description: Query the ZPM knowledge base with natural language, translated to Prolog goals
allowed-tools:
  - mcp__plugin_zpm_zpm__query_logic
  - mcp__plugin_zpm_zpm__explain_why
  - mcp__plugin_zpm_zpm__trace_dependency
  - mcp__plugin_zpm_zpm__get_knowledge_schema
  - mcp__plugin_zpm_zpm__get_belief_status
  - mcp__plugin_zpm_zpm__list_assumptions
  - mcp__plugin_zpm_zpm__get_justification
argument-hint: "<question> e.g., 'what tasks are blocked?', 'show all dependencies'"
---

Answer the question "$ARGUMENTS" by querying the ZPM Prolog knowledge base.

## Steps

1. Run `mcp__plugin_zpm_zpm__get_knowledge_schema` to see available predicates
2. Translate the natural language question into one or more Prolog goals
3. Run `mcp__plugin_zpm_zpm__query_logic` with the appropriate goal(s)
4. If the user asks "why" or "how", use `mcp__plugin_zpm_zpm__explain_why` to trace the proof
5. If the question involves chains/paths, use `mcp__plugin_zpm_zpm__trace_dependency`
6. If about assumptions, use `mcp__plugin_zpm_zpm__list_assumptions` + `mcp__plugin_zpm_zpm__get_belief_status` + `mcp__plugin_zpm_zpm__get_justification`
7. Present results in a clear, human-readable format
