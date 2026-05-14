# Agent Skills Reference

Skills inject reusable knowledge into agent steps. Declare them by name or path on any `type: agent` step; AWF resolves their `SKILL.md` files and prepends the content to the agent prompt as structured `<skill_content>` XML blocks.

## Declaring Skills on an Agent Step

```yaml
analyze:
  type: agent
  provider: claude
  prompt: "Review this code: {{.inputs.code}}"
  skills:
    - code-review          # resolved by name from discovery directories
    - security-hardening   # resolved by name
    - /absolute/path/to/my-skill   # resolved by path (directory containing SKILL.md)
  on_success: done
```

The `skills:` field accepts a list of entries. Each entry is either:

- **Name** — a bare identifier (e.g., `code-review`) searched in the priority-ordered discovery directories
- **Path** — an absolute or `~/`-prefixed directory path that must contain a `SKILL.md`

## Skill Discovery

AWF searches for named skills in the following directories, from highest to lowest priority:

| Priority | Directory | Notes |
|----------|-----------|-------|
| 1 | `$AWF_SKILLS_PATH` | Env var override; a single directory path |
| 2 | `.awf/skills/` | Project-local (highest path-based priority) |
| 3 | `.agents/skills/` | Cross-client project convention |
| 4 | `.claude/skills/` | Claude Code compatibility, project-level |
| 5 | `$XDG_CONFIG_HOME/awf/skills/` | Global XDG equivalent of `.awf/skills/` |
| 6 | `$XDG_CONFIG_HOME/agents/skills/` | Global XDG equivalent of `.agents/skills/` |
| 7 | `$XDG_CONFIG_HOME/claude/skills/` | Global XDG equivalent of `.claude/skills/` |
| 8 | `~/.awf/skills/` | Home-dir fallback |
| 9 | `~/.agents/skills/` | Home-dir fallback |
| 10 | `~/.claude/skills/` | Home-dir fallback |

AWF stops at the first directory where a subdirectory with the skill name exists. If `AWF_SKILLS_PATH` is set, that directory is searched before all others.

### Path-Based References

When a skill entry is an absolute or home-expanded path, AWF uses that directory directly — no discovery search occurs:

```yaml
skills:
  - /shared/team-skills/api-conventions  # must contain SKILL.md
  - ~/personal-skills/code-style
```

### `{{.awf.skills_dir}}` Interpolation Variable

The `{{.awf.skills_dir}}` variable resolves to the first active skills directory (`.awf/skills/` if it exists, otherwise the first non-empty discovery directory). Use it to reference skills relative to the project:

```yaml
skills:
  - "{{.awf.skills_dir}}/code-review"
```

## SKILL.md Format Requirements

Each skill directory must contain a `SKILL.md` file:

```
.awf/skills/
└── code-review/
    └── SKILL.md        # required
```

The `SKILL.md` file:
- May contain YAML frontmatter (fenced with `---`); frontmatter is stripped before injection
- Must have a non-empty body after frontmatter stripping
- Has no size limit beyond what the agent provider supports
- Can reference bundled resources (images, data files in the same directory) — AWF lists bundled resources in the `<skill_content>` block

## Injection Format

AWF injects each skill's content as a `<skill_content>` XML block, prepended before the user prompt. The injection is agentskills.io-compliant.

**Example injection for a skill named `code-review`:**

```xml
<skill_content name="code-review">
## Code Review Guidelines

Focus on:
- Security vulnerabilities
- Performance bottlenecks
- Error handling gaps

Resources: guidelines.md, checklist.yaml
</skill_content>
```

Multiple skills are injected in declaration order, each as a separate `<skill_content>` block, followed by the user prompt.

## `awf validate` Skill Checks

`awf validate` checks skill references before runtime. Three error codes are reported:

| Error code | Condition | Example message |
|------------|-----------|-----------------|
| `skill_not_found` | Named skill not found in any discovery directory | `skill "code-review" not found in any skills directory` |
| `skill_missing_skillmd` | Directory found but contains no `SKILL.md` | `skill "code-review" directory found but missing SKILL.md` |
| `skill_empty_content` | `SKILL.md` exists but is empty after frontmatter stripping | `skill "code-review" SKILL.md is empty` |

```bash
$ awf validate my-workflow
validation error: skill_not_found
  step "analyze": skill "code-review" not found in any skills directory
  searched: .awf/skills/, .agents/skills/, .claude/skills/, ...
```

Fix skill resolution errors by:
1. Creating the skill directory in `.awf/skills/<name>/`
2. Adding a non-empty `SKILL.md` to the directory
3. Or setting `AWF_SKILLS_PATH` to point to the containing directory

## Error Code

The user-facing error code for missing skills is `USER.INPUT.MISSING_SKILL` (exit code 1).

```bash
$ awf run my-workflow
Error [USER.INPUT.MISSING_SKILL]: skill "code-review" not found in any skills directory
```

This is a user error — the skill name or path is wrong, or the skill has not been installed.

## Complete Example

**Directory layout:**

```
.awf/
├── workflows/
│   └── review.yaml
└── skills/
    └── code-review/
        ├── SKILL.md
        └── checklist.yaml
```

**`SKILL.md`:**

```markdown
---
name: code-review
description: Code review guidelines for Go projects
---

## Code Review Focus Areas

- Error handling: every error must be checked
- Security: no hardcoded secrets, validate all inputs
- Performance: avoid N+1 queries, use context for cancellation
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
    skills:
      - code-review
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

The agent receives the `code-review` SKILL.md content injected before the prompt.

## Environment Variable

| Variable | Description |
|----------|-------------|
| `AWF_SKILLS_PATH` | Single directory searched before all other discovery directories for named skill resolution |

```bash
export AWF_SKILLS_PATH=/opt/shared/awf-skills
awf run review --input code="$(cat main.go)"
# AWF looks for /opt/shared/awf-skills/code-review/SKILL.md first
```
