# Migration candidates

These are investigation leads, not an unconditional replacement table. Confirm applicability in the exact target and cite the relevant tag or commit. Consult the official CLI `CHANGELOG.md` together with implementation tests. Do not assign a version from the marketplace's documentation version.

| Candidate | Evidence to inspect | Migration constraint |
|-----------|---------------------|----------------------|
| Lowercase state properties such as `.output` or `.exit_code` | Template validation and expression normalization | Distinguish Go templates from expression namespaces and user JSON keys. Do not globally capitalize keys. |
| `provider: custom` | Agent config validation; provider migration documentation | `openai_compatible` requires a matching endpoint, model, and authentication configuration. Renaming alone may be insufficient. |
| `.Tokens` or legacy token accounting | State result fields and token interpolation tests | Confirm removal versus continued support. Aggregate usage and separate input/output counts are different contracts. |
| `command:` on `type: agent` | YAML mapping and agent command-removal tests | A field may be parsed but ignored. Determine intended behavior before replacing it with a prompt or deleting it. |
| `ntfy` / `slack` notification backends | Target notification backend implementation and changelog C058 | Verify whether the target requires `webhook`; migrate URL, headers, and payload as a unit. Never expose webhook credentials. |
| Legacy notification configuration paths | Target project config types and loader | Check actual config ownership and precedence; a key documented under `plugins:` may not be consumed by the project loader. |
| `AWF_AGENTS_PATH` and old role directories | Changelog F100; role discovery implementation | Check `AWF_ROLES_PATH` and `roles/` namespace. Explain required external environment changes; do not edit global directories implicitly. |
| Plugin manifest capability `commands` | Changelog C069; target manifest validator | Check replacement by `step_types`; do not rename unrelated workflow command fields. |
| Reserved or invalid pack names | Pack manifest validator and changelog F101 | Renaming a pack affects namespaced calls, consumers, and overrides; inspect references before proposing a migration. |

For a new rule, record its source revision, affected file type and context, detection conditions, replacement, compatibility boundary when verified, and exceptions. Require evidence of obsolescence before classifying a candidate as deprecated or incompatible. Keep valid legacy syntax as an optional improvement when it remains supported.

Example of a context-sensitive correction, once confirmed for the target:

```yaml
# Before
prompt: "Review {{.states.collect.output}}"
# After
prompt: "Review {{.states.collect.Output}}"
```

This does not justify changing `{{.states.collect.Response.output}}`: `output` may be a user-defined JSON key.
