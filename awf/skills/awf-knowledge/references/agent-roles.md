# Agent Roles Reference

Roles define *who* an agent is — its persona, communication style, and behavioral constraints. They complement skills (which define *what* an agent knows) as an orthogonal injection channel: roles set the system prompt, skills prepend knowledge blocks before the user prompt.

## Declaring a Role on an Agent Step

```yaml
review:
  type: agent
  provider: claude
  role: go-senior           # loads AGENTS.md from discovery path
  prompt: "Review: {{.inputs.code}}"
  on_success: done
```

The `role:` field accepts either:

- **Name** — a bare identifier (e.g., `go-senior`) resolved through discovery directories
- **Explicit path** — an absolute or `~/`-prefixed directory path containing `AGENTS.md`

## Role Discovery

AWF searches for named roles in the following directories, from highest to lowest priority:

| Priority | Directory | Notes |
|----------|-----------|-------|
| 1 | `$AWF_ROLES_PATH` | Exclusive override; replaces the entire discovery chain |
| 2 | `.awf/roles/` | Project-local (highest path-based priority) |
| 3 | `.agents/roles/` | Cross-client project convention (Cursor/Cline compatible) |
| 4 | `$XDG_CONFIG_HOME/awf/roles/` | Global XDG user config |
| 5 | `~/.agents/roles/` | Home-dir fallback (cross-client global, Cursor/Cline compatible) |

When `AWF_ROLES_PATH` is set, AWF searches only that directory — all other discovery paths are skipped. Use this for CI/sandbox isolation.

### Explicit Paths

Path-based references bypass discovery entirely:

```yaml
role: /shared/team-agents/go-senior   # must contain AGENTS.md
role: ~/personal-agents/reviewer
```

### Dynamic Selection

The `role:` field supports template expressions:

```yaml
role: "{{.inputs.agent_persona}}"
```

```bash
awf run workflow --input agent_persona=go-senior
```

## AGENTS.md Format

Each role directory contains a single `AGENTS.md` file:

```
.awf/roles/
└── go-senior/
    └── AGENTS.md        # required; body injected as system prompt
```

The `AGENTS.md` file:
- Body is injected verbatim as the agent's system prompt
- May contain YAML frontmatter (fenced with `---`); frontmatter is stripped before injection
- Size limit: `awf validate` warns when the file exceeds 500KB
- Must be non-empty after frontmatter stripping (empty content triggers a warning, not a hard error)

**Example `AGENTS.md`:**

```markdown
You are a senior Go engineer specializing in production systems.

Communication style:
- Direct and precise — cite file:line when identifying issues
- Propose alternatives with trade-offs, never a single option
- Challenge assumptions; ask when uncertain

Code review focus:
- Error handling: every error must be checked and wrapped with context
- Concurrency: goroutine leaks, missing cancellation, data races
- Performance: avoid N+1, use context for cancellation
- Security: no hardcoded secrets, validate all external inputs
```

## Injection Behavior

The role body is injected as the agent's system prompt before execution:

- All three execution paths (single-turn, resumable, conversation mode) apply role injection
- For CLI providers (Claude, Codex, Gemini, OpenCode), the system prompt is passed via the provider's system prompt flag
- For `openai_compatible`, the system prompt is sent as a `system` role message in the conversation

## Composition with `system_prompt:`

When both `role:` and `system_prompt:` are set, AWF composes them:

```
<role AGENTS.md body>

<system_prompt value>
```

A blank line separates the two. AWF logs a warning when `system_prompt:` is overridden this way. This is intentional — roles take precedence over inline system prompts.

```yaml
review:
  type: agent
  provider: claude
  role: go-senior
  system_prompt: "Focus on the authentication module."   # appended after role
  prompt: "Review: {{.inputs.code}}"
  on_success: done
```

> When combined, `awf validate` warns if the composed prompt exceeds 10KB.

## `awf validate` Role Checks

`awf validate` reports errors and warnings for role references:

| Severity | Condition | Message |
|----------|-----------|---------|
| Error | Role directory not found in any discovery path | `role "go-senior" not found` |
| Error | Role directory exists but contains no `AGENTS.md` | `role "go-senior" directory found but missing AGENTS.md` |
| Error | Path traversal detected in role name | `role name contains path traversal pattern` |
| Warning | `AGENTS.md` exists but is empty after stripping | `role "go-senior" AGENTS.md is empty` |
| Warning | `AGENTS.md` exceeds 500KB | `role "go-senior" AGENTS.md exceeds 500KB` |
| Warning | Composed system prompt (role + `system_prompt`) exceeds 10KB | `composed system prompt exceeds 10KB` |

```bash
$ awf validate workflow.yaml

validation error: USER.INPUT.MISSING_ROLE
  step "review": role "go-senior" not found
```

Fix role resolution errors by:
1. Creating the role directory in `.awf/roles/<name>/`
2. Adding a non-empty `AGENTS.md` to the directory
3. Or setting `AWF_ROLES_PATH` to the directory containing the role

## Error Code

Missing roles report `USER.INPUT.MISSING_ROLE` (exit code 1):

```bash
$ awf run my-workflow
Error [USER.INPUT.MISSING_ROLE]: role "go-senior" not found
```

## Conversation Mode

Roles are applied in conversation mode. AWF resolves the role before session initialization and injects it as the composed system prompt for the entire session:

```yaml
chat:
  type: agent
  provider: claude
  mode: conversation
  role: go-senior
  prompt: "What would you like to review?"
  on_success: done
```

## Complete Example

**Directory layout:**

```
.awf/
├── workflows/
│   └── review.yaml
└── roles/
    └── go-senior/
        └── AGENTS.md
```

**`review.yaml`:**

```yaml
name: review
version: "1.0.0"

inputs:
  - name: code
    type: string
    required: true

states:
  initial: analyze

  analyze:
    type: agent
    provider: claude
    role: go-senior
    skills:
      - code-review          # knowledge injection (orthogonal to role)
    prompt: |
      Review this code:
      {{.inputs.code}}
    on_success: done

  done:
    type: terminal
    status: success
```

```bash
awf run review --input code="$(cat main.go)"
```

The agent receives the `go-senior` AGENTS.md body as its system prompt and the `code-review` skill content prepended before the prompt.

## Environment Variable

| Variable | Description |
|----------|-------------|
| `AWF_ROLES_PATH` | Exclusive override; replaces the entire discovery chain. Single directory path. |

```bash
export AWF_ROLES_PATH=/opt/shared/awf-roles
awf run review --input code="$(cat main.go)"
# AWF looks for /opt/shared/awf-roles/go-senior/AGENTS.md only
```
