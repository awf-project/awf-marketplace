# Skill Updater

Update the `{{.states.resolve_skill.Output}}` skill documentation in this marketplace based on upstream PR changes.

<context>
Skills are Claude Code documentation packages — content read exclusively by LLMs.
Optimize for token efficiency, clarity, and actionability over human readability.

Skill structure:
```
{{.states.resolve_skill.Output}}/skills/{{.states.resolve_skill.Output}}/
├── SKILL.md              # Main instructions (<500 lines)
└── references/           # Detailed docs (one topic per file)
```
</context>

## Workflow

### 1. Analyze PR changes

Read the PR content below. Identify:
- New features, bugfixes, breaking changes
- Affected domain areas (CLI, workflow syntax, agents, plugins, etc.)
- Files changed in the upstream repo

### 2. Map changes to skill files

For each change, determine which skill files need updates:
- `SKILL.md` — quick reference, decision tree, common patterns
- `references/*.md` — detailed syntax, examples, configuration

Read affected skill files to understand current content and style.

### 3. Apply updates

Use `/claude-architect` skill to guide content quality. Skills are LLM-consumed:
- Imperative form, concrete examples over prose
- YAML examples for every new feature
- Cross-reference between SKILL.md and references (no duplication)
- Progressive disclosure: overview in SKILL.md, details in references/

Follow existing file patterns and style. Match surrounding content.

### 4. Validate

- All references/ files linked from SKILL.md
- No orphaned files
- SKILL.md < 500 lines
- Internal links resolve
- No content duplicated between SKILL.md and references

<constraints>
- No README.md, CHANGELOG.md, or test files
- No emojis
- English only
- Runnable code examples
- Preserve existing working content
- No version numbers in prose (versions are in marketplace.json)
</constraints>

---
## Execution Context

- **skill_name**: {{.states.resolve_skill.Output}}
- **plugin_version**: {{.states.read_and_bump_version.Output}}
- **update_type**: {{.inputs.update_type}}
- **source_pr**: {{.inputs.repository}}#{{.inputs.pull_request}}

## PR Content

{{.states.fetch_pr_content.Output}}
