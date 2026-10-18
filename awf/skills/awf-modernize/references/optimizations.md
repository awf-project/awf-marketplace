# Optimization criteria

Suggest a feature only when it solves a concrete problem in the inspected workflow and is available in the target version. Preserve behavior or state the exact change that requires a user decision.

## Reference routing

Read relevant files from `../../awf-knowledge/references/` relative to this reference directory. When the sibling skill is absent, use official target documentation and source directly.

| Topic | AWF knowledge references |
|-------|--------------------------|
| Routing, inline failures, child workflows | `workflow-syntax.md`, `interpolation.md` |
| Agent commands, prompts, output contracts | `agent-steps.md`, `conversation-steps.md` |
| Reusable instructions and personas | `skills.md`, `agent-roles.md` |
| Duplication and reusable state patterns | `templates.md` |
| Iteration, output retention, concurrency | `loop.md`, `configuration.md` |
| Plugin operations and custom state types | `plugins.md`, `plugin-events.md`, `mcp-proxy.md` |
| Config precedence, validation, CLI options | `configuration.md`, `validation.md`, `cli-commands.md`, `upgrade.md` |

## Simplifications and prerequisites

- **External prompts/scripts**: propose `prompt_file` or `script_file` for substantial repeated content or an unnecessary file-loading step. Preserve preprocessing, working directory, interpreter, interpolation, and resolution from local overrides or packs. A preparation step that transforms data cannot simply be removed. `prompt`/`prompt_file` and `command`/`script_file` are mutually exclusive where supported.
- **Roles and skills**: consider extracting repeated personas to `role:` and reusable knowledge to `skills:`. Preserve injection channel, composition, order, and resource discovery. Check the target's environment overrides and discovery chain rather than assuming role and skill discovery are identical.
- **Templates and child workflows**: use templates for repeated state patterns and child workflows for coherent reusable flows when supported. Preserve input/output mapping, state visibility, caller routing, and pack namespacing. Template parameters resolved during loading are not interchangeable with runtime values.
- **Inline failures**: simplify a dedicated terminal referenced by one failure edge only after checking message, status/exit semantics, hooks, and external references. Named `on_failure` remains valid when supported. Do not delete a shared terminal or convert a recovery path into termination.
- **Conditional routing**: preserve ordering and first-match behavior. Matching transitions can override `on_success`, `on_failure`, and `continue_on_error`, including on timeout/error paths. A catch-all transition is not equivalent to a success fallback.
- **Native agent steps**: a shell invocation of an agent CLI may benefit from `type: agent`, but compare custom flags, prompts, output processing, sessions, and permissions. Do not automatically introduce permission bypass options or broaden tool access.
- **Structured outputs**: `Response` heuristic parsing and `output_format: json` with `JSON` access have different failure contracts. Enforcing JSON can make previously successful states fail. Preserve downstream consumers and distinguish terminal display from stored output.
- **Conversations**: `conversation.continue_from` changes session context relative to passing a previous state's output. Treat it as a behavior decision, not a mechanical reduction in prompt length.
- **Loops and parallelism**: inspect body membership, intra-body routing, completion/failure behavior, dependencies, and shared writes before restructuring. References may disagree about loop transitions; verify target executors/tests. Parallelizing shell/agent steps changes ordering, load, and potentially cost.
- **Output and memory limits**: suggest bounded retention or streaming only for a demonstrated need. Truncation and result pruning can break later references. Preserve retry policy and timeout intent; shorter YAML alone does not justify changing them.
- **Configuration defaults**: moving repeated inputs into config changes sharing and precedence. Keep workflow-specific values local unless a shared project default is intended. Do not add telemetry or external services solely as modernization.

## Example recommendation

Given an agent whose prompt is a long, unchanged inline document, propose moving it to a project prompt file:

```yaml
review:
  type: agent
  provider: claude
  prompt_file: prompts/review.md
  on_success: done
```

Include the new file content in the proposed patch. Verify the target resolves that path from the intended workflow context and preserves template interpolation. Describe this as maintainability, without claiming reduced token usage: the same prompt content is still sent to the agent.
