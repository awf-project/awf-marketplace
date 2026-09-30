# rr replay and origins

Requires [debug setup](debugging.md) plus:

```toml
[debug.record]
backend = "rr"
trace_dir = ".tower/traces"
record_timeout_secs = 60
max_traces = 20
ttl_secs = 86400
```

Trace directory stays inside workspace; retention/timeouts positive; omit TTL for no expiry.
rr tools are absent without this config. Host support is checked at recording: rr, Linux,
CPU, perf. `recordable:false` with `rr_unsupported` ends the replay workflow;
configuration does not prove host support. Kernel/perf changes are outside this workflow.

## Workflows

| Tool (`tower_debug_` prefix) | Contract |
|---|---|
| `record` | `language`, built `program`; optional `args`, `cwd`, `env`, `timeout_ms` → `recordable`, `trace_id`, `exit_code`, `output`, `output_truncated` |
| `replay` | `trace_id`, `language`, `timeout_secs?` → `session_id`, `supportsStepBack` |
| `find_origin` | Trace + target + watch → last-write evidence; replay session auto-cleaned |
| `record_and_find_origin` | Nested `record`, `origin`; result `origin:null` if recording unsupported |

Origin request:

```json
{"trace_id":"trace-1","language":"rust","at":{"kind":"crash"},"watch":"x","timeout_secs":15,"max_depth":2,"max_children":50}
```

Other `at` targets: `{"kind":"end"}` or
`{"kind":"source","path":"src/main.rs","line":42,"column":1}`.
`found:true` returns `write_frame`, stack, value, locals/args, output, truncation.
`found:false,reason:"no_prior_write_reached"` means beginning reached without a prior write.

## Interactive replay

Use ordinary stopped-session inspection. `tower_debug_step_back`: `session_id`, optional
`thread_id`, `granularity` (`line`, `instruction`, `over`), `timeout_secs`.
`tower_debug_watchpoint`: expression/address, `kind:"write"`, `enabled:true`;
`tower_debug_reverse_continue` runs backward to a stop. Live sessions → `reverse_unsupported`.
Session timeout/cleanup rules: [debugging](debugging.md).

## Traces

`tower_debug_traces` lists metadata; new recordings prune expired/oldest traces beyond
`max_traces`. Saved ids can expire. `tower_debug_delete_trace` deletes by `trace_id`.
Process cleanup does not imply trace deletion. Handle payload `record_timeout`,
`record_failed`, missing/expired trace errors before replay.
