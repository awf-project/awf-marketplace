---
name: awf-modernize
description: Audit AWF YAML workflows and project configuration for version compatibility, obsolete or ineffective settings, and useful syntax improvements. Use when reviewing outdated AWF configuration, preparing an AWF upgrade, or modernizing existing workflows while preserving their behavior.
---

# Modernize AWF workflows

Produce an evidence-based audit against a specific AWF CLI version. Separate required migrations from optional improvements. Audit by default; apply changes when requested. This skill covers AWF files, not unrelated YAML formats or dependency upgrades.

## Establish scope and version

- Identify the requested workflows, project configuration, templates, and pack manifests. Follow referenced prompts, scripts, roles, skills, and child workflows only as needed to assess a finding. Distinguish file types before validating them; configuration and pack manifests are not standalone workflows.
- Run `awf --version` when available. Record the exact version, including development suffix and commit. The workflow's `version:` is not the CLI version; marketplace plugin versions are independent too.
- Default to the installed CLI as the target. For an upgrade audit, use the requested target release. Resolve an explicitly requested latest release from official release information, recording the exact tag. Do not infer released behavior from an untagged checkout.
- If no binary or target is available, report a provisional audit and identify the missing compatibility evidence. Do not install or upgrade AWF as part of an audit.

## Gather authoritative evidence

Use [AWF reference routing](references/optimizations.md#reference-routing) to read relevant `awf-knowledge` references from the bundled sibling skill when available. Do not load its entire documentation or require it to be installed separately.

Verify version-sensitive findings against the target's official documentation, release notes, and, when ambiguous, parser, validator, executor, and tests. Official upstream: https://github.com/awf-project/cli. Prefer tagged or commit-pinned evidence over moving branch URLs. A local checkout is useful only when its revision is known.

Bundled knowledge is a discovery aid, not proof of compatibility. References may disagree or lag the implementation. Resolve conflicts against the relevant target source and tests; otherwise mark the finding uncertain. Never invent an introduction or removal version. See [migration candidates](references/migrations.md).

## Audit

Classify findings as:

- **Incompatible**: rejected or unavailable in the target, or an established change in behavior requires migration.
- **Ineffective**: accepted configuration that the target ignores in this context.
- **Deprecated**: explicitly deprecated by an authoritative target source. Age alone is insufficient.
- **Improvement**: an optional simplification or maintainability improvement, with its prerequisites and behavioral tradeoffs.

Check nested agent/parallel/loop bodies and referenced templates as applicable, not just top-level states. Treat interpolated names and paths as unresolved when required inputs are unavailable. Do not flag plugin-owned fields as obsolete using only the core schema.

For each finding give: file and line or YAML path; classification and priority; observed syntax; target version and evidence; proposed replacement or minimal diff; behavioral impact; and verification status. Redact credentials from examples and reports. Group repeated occurrences without hiding locations. Report a clean audit when no justified improvement exists.

Use [optimization criteria](references/optimizations.md) to assess simplifications. Do not promise reduced cost, memory, or runtime without evidence. Distinguish a binary bug fixed by upgrading from a YAML change the user actually needs.

## Apply and verify

When asked to apply changes, preserve existing user edits, comments, state names referenced elsewhere, routing, output contracts, and path resolution. Keep the patch scoped to the requested migrations or improvements. If a material behavior decision is unresolved, apply independent changes and present that decision separately.

Validate affected workflow files before and after changes when possible; inspect `awf validate --help` if the available flags are uncertain. Use explicit file paths to avoid validating a similarly named installed workflow. Validate callers affected by template, role, or child-workflow changes too. Plugin validators may launch external plugin processes. If using `--skip-plugins`, disclose the incomplete plugin coverage.

Validation with the installed version does not prove compatibility with a different target. Report which binary was used, baseline failures, new failures, and checks unavailable. Static validation does not prove behavioral equivalence. Do not execute workflows as an audit check; actual runs require task authorization because shell steps, agents, and operations can have effects and costs.

If no findings are supported by evidence, report that result without rewriting the YAML.
