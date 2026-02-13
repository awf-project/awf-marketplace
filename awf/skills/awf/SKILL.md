---
name: awf
description: |
  AWF (AI Workflow CLI) - Go CLI for orchestrating AI agents via YAML workflows.
  Use when: (1) Creating workflows, (2) Understanding AWF syntax,
  (3) Debugging workflow issues, (4) Using AWF CLI commands,
  (5) Developing features for AWF project.
---

# AWF - AI Workflow CLI

## Workflow Decision Tree

**Creating a workflow?**
1. `awf init` to initialize project
2. Create YAML file in `.awf/workflows/`
3. See [Workflow Syntax](references/workflow-syntax.md)

**Running a workflow?**
1. `awf run <name> --input key=value`
2. Missing inputs? AWF prompts in terminal - see [Interactive Inputs](references/interactive-inputs.md)
3. Use `--dry-run` to preview
4. Use `--interactive` for step-by-step
5. See [CLI Commands](references/cli-commands.md)

**Debugging issues?**
1. `awf validate <name>` to check syntax (validates expressions since v0.5.33)
2. Run with `--verbose` for details
3. Check `$XDG_STATE_HOME/awf/` for logs (~/.local/state/awf/)

**Developing AWF?**
1. See [Architecture](references/architecture.md)
2. Follow hexagonal architecture (ports pattern for external deps)
3. Domain layer has no dependencies - use function types for validator injection
4. Application layer depends on ports interfaces only (DIP-compliant, v0.5.34)

## Quick Start

```yaml
# .awf/workflows/hello.yaml
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

```bash
awf run hello --input name=Claude
```

## CLI Commands

| Command | Description |
|---------|-------------|
| `awf init` | Initialize AWF in directory |
| `awf run <workflow>` | Execute workflow |
| `awf run <workflow> --help` | Show workflow inputs |
| `awf validate <workflow>` | Check syntax |
| `awf diagram <workflow>` | Generate visualization |
| `awf list` | List workflows |
| `awf resume` | Resume interrupted |
| `awf history` | Show history |
| `awf config show` | Display project config |
| `awf plugin list` | List plugins |

**Details**: [CLI Commands Reference](references/cli-commands.md)

## State Types

| Type | Use |
|------|-----|
| `step` | Execute command |
| `agent` | Invoke AI agent (Claude, Codex, Gemini, OpenCode) |
| `parallel` | Run concurrent steps |
| `terminal` | End workflow |
| `for_each` | Iterate over list (supports transitions) |
| `while` | Repeat until false (supports transitions) |
| `operation` | Invoke plugin operation |
| `call_workflow` | Execute sub-workflow |

**Details**: [Workflow Syntax Reference](references/workflow-syntax.md)

## Variable Interpolation

```yaml
# Inputs
command: echo "{{.inputs.file}}"

# Previous outputs (uppercase property names required)
command: echo "{{.states.prev.Output}}"
command: echo "Exit: {{.states.prev.ExitCode}}"

# Operation outputs (structured data from plugins)
command: echo "{{.states.get_issue.Response.title}}"

# Environment
command: echo "{{.env.HOME}}"

# Loop context
command: echo "{{.loop.index1}}/{{.loop.length}}"
```

> **Breaking Change (v0.5.12)**: State property names must be uppercase: `.Output`, `.ExitCode`, `.Status`, `.Stderr`. Lowercase was never functional with Go templates. Use `awf validate` to detect casing issues.

> **Architecture (v0.5.34)**: ExecutionService now uses `ports.AgentRegistry` interface instead of concrete type. Custom agent registries can implement the interface for test isolation or alternative providers.

## Common Patterns

### Retry with Backoff

```yaml
api_call:
  type: step
  command: curl -f https://api.example.com
  retry:
    max_attempts: 3
    backoff: exponential
    initial_delay: 1s
  on_success: process
  on_failure: error
```

### Parallel Execution

```yaml
build_all:
  type: parallel
  strategy: all_succeed
  max_concurrent: 3
  steps:
    - name: lint
      command: make lint
    - name: test
      command: make test
  on_success: deploy
```

### Conditional Branching

```yaml
check:
  type: step
  command: ./check.sh
  transitions:
    - when: "states.check.ExitCode == 0 and inputs.env == 'prod'"
      goto: deploy_prod
    - when: "states.check.ExitCode == 0"
      goto: deploy_staging
    - goto: error
```

### AI Agent Execution

```yaml
analyze:
  type: agent
  provider: claude
  prompt: |
    Review this code for issues:
    {{.inputs.code}}
  options:
    model: claude-sonnet-4-20250514
  timeout: 120
  on_success: process

process:
  type: step
  command: echo "Result: {{.states.analyze.Output}}"
  on_success: done
```

### Multi-Turn Conversation

```yaml
review:
  type: agent
  provider: claude
  mode: conversation
  system_prompt: "You are a code reviewer. Say APPROVED when done."
  prompt: "Review: {{.inputs.code}}"
  conversation:
    max_turns: 10
    stop_condition: "inputs.response contains 'APPROVED'"
  on_success: done
```

> **Note**: Conversation mode executes the same prompt each turn. Use `inputs.` prefix for stop condition variables.

### GitHub Operations

```yaml
get_issue:
  type: operation
  operation: github.get_issue
  inputs:
    number: "{{.inputs.issue_number}}"
  on_success: process

process:
  type: step
  command: echo "Issue: {{.states.get_issue.Response.title}}"
  on_success: done
```

9 built-in operations: `get_issue`, `get_pr`, `create_issue`, `create_pr`, `add_labels`, `add_comment`, `list_comments`, `set_project_status`, `batch`. Auth via `gh` CLI or `GITHUB_TOKEN`. Repo auto-detected from git remote.

### Notification Operations

```yaml
notify_team:
  type: operation
  operation: notify.send
  inputs:
    backend: desktop
    title: "Build Complete"
    message: "{{.states.summary.Output}}"
  on_success: done
  on_failure: done
  continue_on_error: true
```

4 backends: `desktop` (OS-native), `ntfy` (push notifications), `slack` (webhook), `webhook` (generic HTTP). Configure in `.awf/config.yaml` under `plugins.notify`.

**Details**: [Plugins Reference](references/plugins.md) | [Workflow Syntax - Operation State](references/workflow-syntax.md)

## Resources

**Getting Started**
- [references/installation.md](references/installation.md) - Prerequisites & setup

**User Guide**
- [references/workflow-syntax.md](references/workflow-syntax.md) - Complete YAML syntax
- [references/cli-commands.md](references/cli-commands.md) - All CLI commands and flags
- [references/configuration.md](references/configuration.md) - Project configuration
- [references/plugins.md](references/plugins.md) - Plugin system & SDK
- [references/templates.md](references/templates.md) - Workflow templates
- [references/examples.md](references/examples.md) - Real-world examples

**Reference**
- [references/interpolation.md](references/interpolation.md) - Variable substitution
- [references/interactive-inputs.md](references/interactive-inputs.md) - Auto-prompting for missing inputs
- [references/agent-steps.md](references/agent-steps.md) - AI agent integration
- [references/conversation-steps.md](references/conversation-steps.md) - Multi-turn agent conversations
- [references/loop.md](references/loop.md) - Loop control flow and transitions
- [references/exit-codes.md](references/exit-codes.md) - Error codes
- [references/validation.md](references/validation.md) - Input validation

**Development**
- [references/architecture.md](references/architecture.md) - Architecture & project structure
- [references/code-quality.md](references/code-quality.md) - Linting, formatting, CI quality gates
- [references/testing.md](references/testing.md) - Testing conventions
