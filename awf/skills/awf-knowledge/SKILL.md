---
name: awf-knowledge
description: |
  AWF (AI Workflow CLI) - Go CLI for orchestrating AI agents via YAML workflows.
  Use when: (1) Creating workflows, (2) Understanding AWF syntax,
  (3) Debugging workflow issues, (4) Using AWF CLI commands,
  (5) Developing features for AWF project.
---

# AWF CLI

Use AWF to orchestrate agents, shell commands, and plugin operations as YAML state machines. Read the reference matching the task; the tables below route to details rather than prescribing a full setup sequence.

## Choose the task

| Task | References / action |
|------|---------------------|
| Create or edit a workflow | [Workflow syntax](references/workflow-syntax.md), then the relevant state type below |
| Audit outdated configuration or prepare an upgrade | [awf-modernize](../awf-modernize/SKILL.md) |
| Diagnose validation or execution failures | `awf validate <file>`; [validation](references/validation.md), [exit codes](references/exit-codes.md) |
| Run, resume, install, or inspect workflows | [CLI commands](references/cli-commands.md), [interactive inputs](references/interactive-inputs.md), [upgrade](references/upgrade.md) |
| Configure project defaults | [Configuration](references/configuration.md) |
| Develop AWF itself | [Architecture](references/architecture.md), [code quality](references/code-quality.md), [testing](references/testing.md) |

For version-sensitive syntax, inspect `awf --version` and the available command's `--help`. If bundled references conflict, resolve against the target release's source/tests at https://github.com/awf-project/cli. Marketplace versions and workflow `version:` fields are independent of the CLI version.

## Minimal workflow

```yaml
name: hello
version: "1.0.0"
inputs:
  - name: name
    type: string
    default: World
states:
  initial: greet
  greet:
    type: step
    command: echo "Hello, {{.inputs.name}}!"
    on_success: done
  done:
    type: terminal
    status: success
```

Store project workflows in `.awf/workflows/`. Initialize with `awf init` only when project scaffolding is needed. Validate the explicit file path before running; validation does not execute workflow steps. Actual execution may invoke shell commands, agents, or external operations.

## Syntax that affects correctness

- Templates: `{{.inputs.name}}`, `{{.states.build.Output}}`, `{{.env.HOME}}`. State properties use PascalCase; user JSON keys under `Response` or `JSON` retain their original casing.
- Expressions differ from Go templates: `when: "states.build.ExitCode == 0"`. Ordered transitions use the first match and can override success/failure routing, including execution errors. Preserve the fallback.
- Agent prompts accept `prompt` or `prompt_file`; shell states accept `command` or `script_file`. Use one form per pair. Inline prompts are valid; preprocessing steps are needed only when the prompt actually requires preprocessing.
- `Response` is heuristic JSON parsing; `output_format: json` with `JSON` access adds explicit validation and can fail the state.
- Named workflow resolution differs from paths: an existing local file can be passed directly; `<pack>/<workflow>` identifies an installed pack. Use explicit paths when validating edits.

## Read by feature

| Feature | Reference |
|---------|-----------|
| Agent providers, options, output formatting | [Agent steps](references/agent-steps.md) |
| Roles / reusable knowledge | [Agent roles](references/agent-roles.md), [skills](references/skills.md) |
| Session continuity / conversation mode | [Conversations](references/conversation-steps.md) |
| Variables, path overrides, template helpers | [Interpolation](references/interpolation.md) |
| Iteration and intra-body transitions | [Loops](references/loop.md) |
| Reusable state definitions | [Templates](references/templates.md) |
| Operations, custom state types, plugin scaffolding | [Plugins](references/plugins.md), [plugin events](references/plugin-events.md) |
| Per-step MCP tool access | [MCP proxy](references/mcp-proxy.md) |
| HTTP / ACP / terminal UI | [API](references/api.md), [ACP server](references/acp-server.md), [TUI](references/tui.md) |
| Execution evidence / agent exchange | [Audit trail](references/audit-trail.md), [transcript](references/transcript.md) |
| Distributed tracing | [Tracing](references/tracing.md) |
| Installation / complete examples | [Installation](references/installation.md), [examples](references/examples.md) |
