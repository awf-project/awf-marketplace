---
description: Capture structured knowledge into ZPM from the current context (git state, project decisions, task status)
allowed-tools:
  - mcp__zpm__remember_fact
  - mcp__zpm__upsert_fact
  - mcp__zpm__assume_fact
  - mcp__zpm__define_rule
  - mcp__zpm__get_knowledge_schema
  - mcp__zpm__verify_consistency
  - Bash(git:*)
argument-hint: "<topic> e.g., git-state, architecture, tasks, decisions"
---

Analyze the current context for the topic "$ARGUMENTS" and store structured Prolog facts in ZPM.

## Guidelines

- Use snake_case predicate names: `domain_relation(subject, object)`
- Use `mcp__zpm__upsert_fact` for mutable state (statuses, configs), `mcp__zpm__remember_fact` for immutable facts
- Use `mcp__zpm__mcp__zpm__assume_fact` with a named assumption for hypothetical or temporary context
- After storing, run `get_knowledge_schema` to show what was added
- Run `mcp__zpm__verify_consistency` if integrity rules exist

## Topic-specific behavior

- **git-state**: Read git status/log/branch, store as `git_branch/2`, `git_modified_file/1`, `git_new_file/1`, `git_file_count/2`
- **architecture**: Store module relationships as `depends_on/2`, `module_role/2`, component facts
- **tasks**: Store task statuses as `task_status/2`, blockers as `blocked_by/2`
- **decisions**: Store as `decision(topic, choice, rationale)`
- If topic is unrecognized, analyze the conversation context and store the most relevant structured facts
