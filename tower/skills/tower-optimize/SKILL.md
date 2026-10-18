---
name: tower-optimize
description: Analyze a project's Tower setup against its workflows and compatible Tower sources to recommend useful tools, extensions, and configuration improvements. Use for Tower setup reviews, adoption, or missing capabilities; ordinary tool usage belongs to tower-knowledge.
---

# Tower Optimize

Find improvements that help this project use Tower effectively. Default to a read-only
audit with concrete proposed changes; apply changes when the user's request includes them.
Optimize for useful capabilities, not the number of installed extensions.

## Establish the project and runtime

Read project instructions, manifests, representative source files, and existing lint,
formatting, language-server, and debugging configuration. Identify languages, workspace
boundaries, generated/vendor directories, and the workflow the user wants to improve.
Use targeted inspection rather than reading the entire repository.

Inspect `.tower/config.toml`, `.towerignore`, relevant MCP configuration, and the actual
Tower tools exposed in this session. Prefer Tower for indexed project exploration when
available; use filesystem reads for excluded configuration or an unavailable connection.
Index absence does not prove disk absence. Never use one project's MCP connection to
inspect a different checkout by passing out-of-workspace paths.

Separate extension installation, discovery, configuration, tool exposure, and successful
operation. Classify findings as verified working, available but unverified, missing,
disabled, misconfigured, unsupported, or unknown, based on the evidence available.
Do not infer missing installation from an absent tool alone.

## Match needs to compatible capabilities

Read [discovery](references/discovery.md) to locate the Tower repository, establish
version compatibility, and inspect authoritative configuration and extension contracts.
Search the repository for capabilities relevant to the observed project, including
features beyond the examples below. Record the source revision and unresolved differences
from the installed runtime. Do not recommend unreleased behavior as currently usable.

Consider:

- Indexed search and versioned edits: workspace resolution, exclusions, freshness.
- AST: supported languages and repeated structural exploration or symbol editing.
- LSP: definitions, references, diagnostics, rename, and supported semantic queries.
- Lint: reuse project commands and supported structured output for checks/fixes.
- Formatting: reuse project conventions and check automatic formatting side effects.
- Debugging: DAP for runtime evidence; record/replay only for a relevant problem and
  a compatible host with the necessary dependencies.

Use the sibling [tower-knowledge](../tower-knowledge/SKILL.md) and only its relevant
references for operational details. Confirm exact fields and tools against installed
schemas and compatible sources; examples are not a compatibility guarantee.
Reuse existing project tools and versions instead of introducing a parallel toolchain.
Respect intentionally disabled extensions and explain any reason to reconsider them.

## Deliver actionable recommendations

Lead with the most useful changes and distinguish configuration repairs, better use of
existing tools, optional additions, and upgrades required for newer capabilities.
For each recommendation include:

- Project evidence and the task it would improve.
- Capability, compatibility evidence, and missing prerequisites.
- A precise configuration patch or usage example, preserving unrelated settings.
- A focused verification step and relevant operational impact.

Show proposed configuration as proposals, not as already installed or validated.
Do not invent a configuration-validation command. Parsing TOML alone does not validate
Tower's schema. An exposed tool or successful transport response does not establish
functional support: inspect `supported`, `outcome`, and per-file errors where applicable.
State what was not verified and why. If no useful changes are justified, say so.

An audit does not authorize installing dependencies, running project programs, enabling
automatic formatting, or stopping the shared daemon. When application is requested,
follow its scope, inspect the diff, and verify with bounded checks. Configuration changes
can require restarting the shared daemon and reconnecting clients; coordinate disruption
to other clients rather than silently shutting it down. Do not delete the index as repair.

## Contextual suggestions

For a narrow question or a capability gap encountered during another task, inspect only
what supports a relevant suggestion. Explain the benefit and prerequisite briefly; offer
the full audit only if useful. Do not repeat a declined or already explained suggestion
in the same conversation unless new evidence changes the recommendation. This skill
does not install a background monitor or persistent reminder mechanism.
