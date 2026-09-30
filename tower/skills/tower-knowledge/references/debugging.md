# Debug sessions and probes

Tools require valid `[debug.<language>]` config and enabled debug sidecar; malformed config
fails startup. A discovered sidecar overrides the bundled fallback binary beside `tower`.
Example `.tower/config.toml`:

```toml
[debug.rust]
extensions = ["rs"]
command = "lldb-dap"
args = ["--stdio"]
adapter_type = "lldb"
launch = { request = "launch", program = "target/debug/app" }
default_timeout_secs = 15
idle_ttl_secs = 300
```

## Interactive

Build program, then `tower_debug_launch` (`language`, `program`) → `session_id`.
Use it for `tower_debug_set_breakpoints`, continue/step, threads, stack, variables, evaluate.
Debugger positions follow their schemas, not LSP coordinates.
Stack/variables/evaluate require stopped state (`not-stopped` otherwise).
Continue timeout may return `state:"running",timed_out:true` without terminating.
Clean up task-created sessions with `tower_debug_terminate` or `tower_debug_disconnect`.
Sessions disappear on sidecar restart; stale ids → `session-not-found`.
`tower_debug_sessions` lists live sessions.

## One-shot

`tower_debug_eval_at` uses **`lang`**, unlike launch's `language`:

```json
{"lang":"rust","program":"target/debug/app","breakpoint":{"path":"src/main.rs","line":42},"expressions":["answer"],"timeout_ms":5000}
```

Built program required. Internal session always torn down; no returned `session_id`.
Capture bounds: `max_depth`, `max_children`; `capture` selects stack/locals/args.
Default `on_hit:"first"`; multiple hits require `on_hit:"all"` and positive `max_hits`.
Results: `hit`, `hits`, `output`, `finished` (`stopped`, `exited`, `timeout`, `terminated`,
`adapter_exited`). Expression failures are per expression.
`condition_unsupported:true` means the requested condition was not honored.

Runtime errors are in-band `ok:false,error.code`; malformed arguments are protocol errors.
rr recording/replay and trace retention: [reverse debugging](reverse-debugging.md).
