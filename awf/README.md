# AWF Plugin for Claude Code

## What it does

This plugin gives Claude Code deep knowledge of [AWF](https://github.com/awf-project/cli), a Go CLI that orchestrates AI agents and shell commands via YAML workflow definitions.

It provides:

- **AWF Skill** — Comprehensive reference documentation for AWF workflow syntax, agent integration, variable interpolation, CLI commands, plugins, loops, validation, and architecture. Loaded automatically when working on AWF-related tasks.
- **AWF Skill Maintainer** — Agent that keeps the skill documentation in sync with AWF CLI releases. Reads PRs/changelogs, identifies affected reference files, and applies targeted updates following established patterns.
- **AWF Workflow Designer** — Agent that generates valid AWF workflow YAML files from user specifications. Knows all state types, interpolation syntax, and common patterns (parallel execution, retry, loops, conditional branching).

## Usage

### Skill (automatic)

The AWF skill activates automatically when Claude detects AWF-related context — writing workflows, debugging YAML syntax, using AWF CLI commands, or developing features for the AWF project.

### Skill Maintainer agent

Delegates to the `awf-skill-maintainer` agent when updating documentation after a CLI change:

```
Update the AWF skill docs for PR #251
```

```
Sync the marketplace skill with the latest AWF release v0.7.0
```

The agent reads the PR/diff, maps changes to the right reference files, applies updates matching the existing style, and bumps the version in `marketplace.json`.

### Workflow Designer agent

Delegates to the `awf-workflow-designer` agent when creating workflows:

```
Create an AWF workflow that fetches GitHub issues, analyzes them with Claude, and posts a summary to Slack
```

```
Design a workflow with parallel code review on 3 files then a merge step
```

The agent asks clarifying questions, designs the state machine, generates valid YAML, and validates the output.
