---
name: awf-knowledge
description: |
  AWF (AI Workflow CLI) - Go CLI for orchestrating AI agents via YAML workflows.
  Use when: (1) Creating workflows, (2) Understanding AWF syntax,
  (3) Debugging workflow issues, (4) Using AWF CLI commands,
  (5) Developing features for AWF project.
argument-hint: "[topic]"
---

# AWF - AI Workflow CLI

## Workflow Decision Tree

**Creating a workflow?**
1. `awf init` to initialize project
2. Create YAML file in `.awf/workflows/`
3. See [Workflow Syntax](references/workflow-syntax.md)

**Running a workflow?**
1. `awf run <name> --input key=value`
2. To run a workflow from an installed pack: `awf run <pack>/<workflow> --input key=value`
3. Missing inputs? AWF prompts in terminal - see [Interactive Inputs](references/interactive-inputs.md)
4. Use `--dry-run` to preview (config values pre-populate)
5. Use `--interactive` for step-by-step (config values reduce prompts)
6. See [CLI Commands](references/cli-commands.md)

**Debugging issues?**
1. `awf validate <name>` to check syntax (validates expressions since v0.5.33; warns on disabled plugin references)
2. Run with `--verbose` for details
3. Check `$XDG_STATE_HOME/awf/` for logs (~/.local/state/awf/)
4. Review audit trail at `$XDG_DATA_HOME/awf/audit.jsonl` for execution history (v0.6.7)
5. `awf plugin list` to verify built-in providers (github, http, notify) are enabled

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
| `awf init` | Initialize AWF in directory (workflows, prompts, scripts) |
| `awf run <workflow>` | Execute workflow (`<pack>/<workflow>` for packs; `--help` for inputs) |
| `awf validate <workflow>` | Check syntax |
| `awf diagram <workflow>` | Generate visualization |
| `awf list` | List workflows (local + pack workflows with `pack/workflow` prefix) |
| `awf resume [id] [--from current\|previous\|<step>]` | Resume interrupted (see below) |
| `awf history` | Show history |
| `awf config show` | Display project config |
| `awf plugin list` | List plugins (built-in + external, with TYPE and SOURCE columns) |
| `awf plugin list --operations` | List operations per plugin (triggers gRPC init for external plugins) |
| `awf plugin verify [name]` | Verify plugin binary integrity (checksum) |
| `awf plugin install <owner/repo>` | Install plugin from GitHub Releases |
| `awf plugin update <name>` | Update installed plugin to latest release |
| `awf plugin remove <name>` | Remove installed plugin |
| `awf plugin search <query>` | Search GitHub for AWF plugins |
| `awf workflow install <owner/repo>` | Install workflow pack from GitHub Releases into XDG data dir |
| `awf workflow list` | List installed workflow packs with name, version, source, and workflows |
| `awf workflow info <name>` | Show pack manifest details, plugin status, and embedded README |
| `awf workflow update [--all] <name>` | Update workflow pack(s) to latest release |
| `awf workflow search <query>` | Search GitHub for AWF workflow packs |
| `awf workflow remove <name>` | Remove installed workflow pack |
| `awf upgrade` | Self-update the AWF binary from GitHub Releases |
| `awf upgrade --check` | Check for a newer version without installing |
| `awf tui` | Launch interactive full-screen terminal dashboard |

**Details**: [CLI Commands Reference](references/cli-commands.md)

## State Types

| Type | Use |
|------|-----|
| `step` | Execute command (inline or from script file) |
| `agent` | Invoke AI agent (Claude, Codex, Gemini, OpenCode, OpenAI-Compatible, GitHub Copilot) |
| `parallel` | Run concurrent steps |
| `terminal` | End workflow |
| `for_each` | Iterate over list (supports transitions) |
| `while` | Repeat until false (supports transitions) |
| `operation` | Invoke plugin operation (`{plugin-id}.{operation}`) |
| `call_workflow` | Execute sub-workflow |
| `{plugin-id}.{step-type}` | Execute custom plugin-defined step type with `config:` block |

**Details**: [Workflow Syntax Reference](references/workflow-syntax.md)

## Variable Interpolation

```yaml
# Inputs
command: echo "{{.inputs.file}}"

# Previous outputs (uppercase property names required)
command: echo "{{.states.prev.Output}}"
command: echo "Exit: {{.states.prev.ExitCode}}"
command: echo "{{.states.prev.TokensInput}} in / {{.states.prev.TokensOutput}} out (estimated: {{.states.prev.TokensEstimated}})"

# Operation outputs (structured data from plugins)
command: echo "{{.states.get_issue.Response.title}}"

# Explicit JSON output (from output_format: json)
command: echo "{{.states.analyze.JSON.severity}}"

# Environment
command: echo "{{.env.HOME}}"

# AWF system directories (XDG-compliant, local-before-global resolution)
command: echo "{{.awf.config_dir}}"    # ~/.config/awf
command: echo "{{.awf.skills_dir}}"   # first active skills directory (.awf/skills/ preferred)
prompt_file: "{{.awf.prompts_dir}}/analyze.md"   # checks <workflow_dir>/prompts/ first
script_file: "{{.awf.scripts_dir}}/deploy.sh"    # checks <workflow_dir>/scripts/ first

# Loop context (PascalCase)
command: echo "{{.loop.Index1}}/{{.loop.Length}}"
```

> **Breaking Change (v0.5.12)**: State property names must be uppercase: `.Output`, `.ExitCode`, `.Status`, `.Stderr`. Use `awf validate` to detect casing issues.
> **Breaking Change (v0.6.6)**: `provider: custom` removed. Use `provider: openai_compatible` with `base_url` and `model`.

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

### Conditional Branching (Exit Code Routing)

```yaml
test_runner:
  type: step
  command: pytest
  transitions:
    - when: "states.test_runner.ExitCode == 0"
      goto: deploy
    - when: "states.test_runner.ExitCode > 1"
      goto: critical_failure
    - when: "states.test_runner.ExitCode != 0"
      goto: report_warnings
    - goto: unknown_error  # default fallback
```

> **Transition evaluation (v0.6.3)**: Transitions are evaluated on **both success and failure paths**, including execution errors and timeouts. When a transition matches, it takes priority over `on_success`, `on_failure`, and `continue_on_error`. If no transition matches, legacy routing applies as fallback.

### Mixed Exit Code + Output Routing

```yaml
build:
  type: step
  command: make build
  transitions:
    - when: "states.build.ExitCode == 0 and states.build.Output contains 'OPTIMIZED'"
      goto: fast_deploy
    - when: "states.build.ExitCode == 0"
      goto: standard_deploy
    - goto: fix_errors
```

### Inline Error Shorthand

```yaml
deploy:
  type: step
  command: ./deploy.sh
  on_success: done
  on_failure: {message: "Deploy failed: {{.states.deploy.Output}}", status: 2}

done:
  type: terminal
  status: success
```

- `on_failure` accepts an inline object `{message: "...", status: N}` as shorthand for a named terminal state
- Synthesized into an anonymous terminal step at parse time — no changes to execution engine
- `message` supports full template interpolation (`{{.inputs.*}}`, `{{.states.*}}`, `{{.env.*}}`)
- `status` defaults to exit code `1` when omitted
- `awf validate` reports clear errors for missing or empty `message`
- String form `on_failure: step_name` remains unchanged

**Details**: [Workflow Syntax - Inline Error Shorthand](references/workflow-syntax.md#inline-error-shorthand)

### AI Agent Execution

```yaml
analyze:
  type: agent
  provider: claude
  prompt: "Review this code for issues: {{.inputs.code}}"
  options:
    model: claude-sonnet-4-20250514
  timeout: 120                        # seconds or Go duration: "2m", "1m30s"
  on_success: process

process:
  type: step
  command: echo "Result: {{.states.analyze.Output}}"
  on_success: done
```

### Agent Skills

Inject reusable knowledge into agent steps by declaring skill names or paths:

```yaml
analyze:
  type: agent
  provider: claude
  skills:
    - code-review          # resolved by name from .awf/skills/, .agents/skills/, etc.
    - /path/to/my-skill    # resolved by explicit path (directory containing SKILL.md)
  prompt: "Review: {{.inputs.code}}"
  on_success: done
```

- SKILL.md frontmatter is stripped; body injected as `<skill_content>` XML before the prompt
- `awf validate` checks: `skill_not_found`, `skill_missing_skillmd`, `skill_empty_content`
- Override discovery with `AWF_SKILLS_PATH` env var; use `{{.awf.skills_dir}}` in paths

**Details**: [Skills Reference](references/skills.md)

### OpenAI-Compatible Agent (Ollama, vLLM, Groq)

```yaml
analyze:
  type: agent
  provider: openai_compatible
  prompt: "Review this code: {{.inputs.code}}"
  options:
    base_url: "http://localhost:11434/v1"
    model: "llama3"
    api_key: "sk-..."                   # optional, falls back to OPENAI_API_KEY
    max_completion_tokens: 2048         # max_tokens accepted as legacy fallback
    temperature: 0.7
  timeout: 120
  on_success: process
```

- Supports multi-turn (`mode: conversation`), token tracking, HTTP error mapping (401/429/5xx)
- `temperature` and `max_completion_tokens` not forwarded to CLI providers

**Details**: [Agent Steps - OpenAI-Compatible Provider](references/agent-steps.md#openai-compatible-provider)

### GitHub Copilot Agent

```yaml
analyze:
  type: agent
  provider: github_copilot
  prompt: "Review: {{.inputs.code}}"
  options:
    mode: autopilot    # interactive | plan | autopilot
    effort: high       # low | medium | high
  on_success: process
```

**Details**: [Agent Steps - GitHub Copilot](references/agent-steps.md#github-copilot)

### Output Formatting for Agent Steps

```yaml
analyze:
  type: agent
  provider: claude
  prompt: "Return JSON analysis with 'issues' and 'severity' fields"
  output_format: json                   # json or text
  on_success: process

process:
  type: step
  command: echo "Severity: {{.states.analyze.JSON.severity}}"
  on_success: done
```

- `output_format: json` — strips markdown fences, validates JSON, stores in `{{.states.step.JSON.field}}`
- `output_format: text` — strips fences only, stores cleaned text in `{{.states.step.Output}}`; omitted behaves like `text`
- Invalid JSON fails the step with a descriptive error; unknown values rejected at `awf validate` time
- With `--output streaming --verbose`, adds `[tool: Name(Arg)]` markers; `json` bypasses filtering

**Details**: [Agent Steps - Output Formatting](references/agent-steps.md) | [Agent Steps - Streaming Output Display](references/agent-steps.md#streaming-output-display)

### External Prompt Files

```yaml
analyze:
  type: agent
  provider: claude
  prompt_file: prompts/code_review.md   # Mutually exclusive with prompt
  timeout: 120
  on_success: done
```

- `prompt_file` loads prompt from external `.md` file with full template interpolation; 1MB size limit; mutually exclusive with `prompt`
- **Local-before-global**: `{{.awf.prompts_dir}}/file.md` checks `<workflow_dir>/prompts/` first, then global XDG fallback
- Template helpers: `split`, `join`, `readFile`, `trimSpace`

**Details**: [Agent Steps - External Prompt Files](references/agent-steps.md)

### External Script Files

```yaml
deploy:
  type: step
  script_file: scripts/deploy.sh   # Mutually exclusive with command
  timeout: 60
  on_success: verify
```

- `script_file` loads script from external file with full template interpolation; 1MB size limit; mutually exclusive with `command`
- **Shebang support**: shebang scripts execute via kernel interpreter; no-shebang scripts fall back to `$SHELL -c`
- **Local-before-global**: `{{.awf.scripts_dir}}/deploy.sh` checks `<workflow_dir>/scripts/` first, then global XDG fallback

**Details**: [Workflow Syntax - External Script Files](references/workflow-syntax.md#external-script-files)

### Multi-Turn Conversation

```yaml
# Interactive session (mode: conversation) — live user input via terminal
review:
  type: agent
  provider: claude
  mode: conversation
  system_prompt: "You are a code reviewer."
  prompt: "What would you like to review?"
  on_success: done

# Cross-step session tracking — resume a previous step's session
deep_review:
  type: agent
  provider: claude
  prompt: "Focus on security issues."
  conversation:
    continue_from: initial_review   # validated at awf validate time
  on_success: done
```

**Details**: [Conversation Mode](references/conversation-steps.md)

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

8 built-in operations: `get_issue`, `get_pr`, `create_issue`, `create_pr`, `add_labels`, `add_comment`, `list_comments`, `batch`. Auth via `gh` CLI or `GITHUB_TOKEN`. Repo auto-detected from git remote.

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

### Plugin Custom Step Types

Plugins can define new step types referenced as `{plugin-id}.{step-type}` with a `config:` block:

```yaml
query_db:
  type: awf-plugin-database.sql_query
  config:
    query: "SELECT * FROM users WHERE id = {{.inputs.user_id}}"
    connection: postgres
  on_success: process
  on_failure: error
```

Use `--skip-plugins` during development to bypass plugin validation and execution:

```bash
awf validate my-workflow --skip-plugins
awf run my-workflow --skip-plugins
awf run my-workflow --validator-timeout 30s   # control validator plugin timeout
```

Plugins declaring `validators` capability run at `awf validate` and `awf run` time to enforce custom rules (e.g. block hardcoded secrets).

**Details**: [Plugins Reference](references/plugins.md)

### Distributed Tracing

```yaml
# .awf/config.yaml
telemetry:
  exporter: "localhost:4317"   # OTLP gRPC endpoint
  service_name: "my-service"
```

Opt-in OpenTelemetry tracing — exports spans to Jaeger, Grafana Tempo, Honeycomb, or Datadog. Zero overhead when not configured. Each run emits a `workflow.run` root span with child spans per step, agent call, parallel block, and loop. Override per-run with `--otel-exporter` and `--otel-service-name`.

**Details**: [Distributed Tracing Reference](references/tracing.md)

## Resources

**Getting Started**
- [references/installation.md](references/installation.md) - Prerequisites & setup
- [references/upgrade.md](references/upgrade.md) - Self-update the AWF binary

**User Guide**
- [references/workflow-syntax.md](references/workflow-syntax.md) - Complete YAML syntax
- [references/cli-commands.md](references/cli-commands.md) - All CLI commands and flags
- [references/tui.md](references/tui.md) - Terminal dashboard (five-tab interactive UI)
- [references/configuration.md](references/configuration.md) - Project configuration
- [references/plugins.md](references/plugins.md) - Plugin system & SDK
- [references/plugin-events.md](references/plugin-events.md) - Inter-plugin event system
- [references/skills.md](references/skills.md) - Agent skills injection
- [references/templates.md](references/templates.md) - Workflow templates
- [references/examples.md](references/examples.md) - Real-world examples

**Reference**
- [references/audit-trail.md](references/audit-trail.md) - Structured JSONL audit trail
- [references/tracing.md](references/tracing.md) - Distributed tracing (OpenTelemetry)
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
