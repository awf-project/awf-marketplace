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
1. `awf validate <name>` to check syntax
2. Run with `--verbose` for details
3. Check `storage/logs/` for logs

**Developing AWF?**
1. See [Architecture](references/architecture.md)
2. Follow hexagonal architecture
3. Domain layer has no dependencies

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

# Previous outputs
command: echo "{{.states.prev.output}}"

# Environment
command: echo "{{.env.HOME}}"

# Loop context
command: echo "{{.loop.index1}}/{{.loop.length}}"
```

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
    - when: "states.check.exit_code == 0 and inputs.env == 'prod'"
      goto: deploy_prod
    - when: "states.check.exit_code == 0"
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
  command: echo "Result: {{.states.analyze.output}}"
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
- [references/testing.md](references/testing.md) - Testing conventions
