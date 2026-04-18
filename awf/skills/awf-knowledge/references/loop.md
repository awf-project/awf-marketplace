# Loop Reference

Loop control flow in AWF workflows: while loops, for-each loops, and transitions within loop bodies.

## Table of Contents

- [Overview](#overview)
- [While Loops](#while-loops)
- [For-Each Loops](#for-each-loops)
- [Transitions Within Loop Bodies](#transitions-within-loop-bodies)
- [Loop Context Variables](#loop-context-variables)
- [Nested Loops](#nested-loops)
- [Memory Management](#memory-management)
- [Error Handling](#error-handling)
- [Examples](#examples)

## Overview

AWF supports two loop types:

| Type | Description |
|------|-------------|
| `while` | Repeat until condition becomes false |
| `for_each` | Iterate over a list of items |

Loops support transitions within body steps:
- **Intra-body transitions** - Skip steps within current iteration
- **Early exit** - Break out of loop before completion
- **Error handling** - Retry patterns with `on_failure`

## While Loops

Repeat execution until `break_when` is true or `max_iterations` reached.

### Syntax

```yaml
my_loop:
  type: while
  while: 'true'
  break_when: 'states.check.Output contains "DONE"'
  max_iterations: 10
  body:
    - step1
    - step2
  on_complete: next_state
  on_failure: error_handler
```

### Options

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `while` | string | No | `true` | Loop condition |
| `break_when` | string | Yes | - | Exit condition |
| `max_iterations` | int | No | unlimited | Maximum iterations |
| `body` | array | Yes | - | Step names to execute |
| `on_complete` | string | No | - | Next state after loop |
| `on_failure` | string | No | - | Next state on failure |

### Execution Flow

1. Evaluate `while` - if false, skip loop
2. Each iteration:
   - Execute body steps in order
   - Evaluate transitions after each step
   - Check `break_when` after body completes
   - Exit if true or `max_iterations` reached
3. Transition to `on_complete`

### Example: Retry Until Success

```yaml
retry_deploy:
  type: while
  while: 'true'
  break_when: 'states.check.Output contains "SUCCESS"'
  max_iterations: 5
  body:
    - deploy_app
    - check
  on_complete: notify

deploy_app:
  type: step
  command: ./deploy.sh
  on_success: retry_deploy

check:
  type: step
  command: curl -f https://app.example.com/health
  on_success: retry_deploy
```

## For-Each Loops

Iterate over a list, executing body once per item.

### Syntax

```yaml
process_files:
  type: for_each
  items: ["file1.txt", "file2.txt"]
  body:
    - validate
    - process
  on_complete: summarize
  on_failure: cleanup
```

### Options

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `items` | array | Yes | List to iterate |
| `body` | array | Yes | Steps per item |
| `on_complete` | string | No | Next state after all items |
| `on_failure` | string | No | Next state on failure |

### Item Access

Access current item with `{{.loop.Item}}`:

```yaml
process:
  type: step
  command: |
    echo "Processing {{.loop.Item}}"
    cat "{{.loop.Item}}" | process.sh
  on_success: process_files
```

### Example: Deploy to Environments

```yaml
deploy_all:
  type: for_each
  items: ["dev", "staging", "prod"]
  body:
    - validate_env
    - deploy_to_env
  on_complete: done

deploy_to_env:
  type: step
  command: ./deploy.sh --env={{.loop.Item}}
  on_success: deploy_all
```

## Transitions Within Loop Bodies

Body steps can define transitions to control execution flow.

### Transition Actions

| Action | Condition | Result |
|--------|-----------|--------|
| Intra-body jump | Target in body array | Skip to that step |
| Early exit | Target outside body | Break loop, goto target |
| Sequential | No match | Continue to next step |
| Invalid target | Target not found | Warning, continue |

### Target Resolution

1. Check if target exists in `body` array - jump within iteration
2. Check if target exists in workflow states - exit loop
3. Target not found - log warning, continue sequentially

### Intra-Body Transitions (Skip Steps)

Jump to later steps, skipping intermediate ones:

```yaml
test_loop:
  type: while
  while: 'true'
  break_when: 'states.run_tests.Output contains "PASSED"'
  max_iterations: 3
  body:
    - run_tests
    - check_results
    - fix_code      # Skipped when tests pass
    - run_tests
  on_complete: deploy

check_results:
  type: step
  command: |
    if grep -q "PASSED" test-output.txt; then
      echo "PASSED"
    else
      echo "FAILED"
    fi
  transitions:
    - when: 'states.check_results.Output contains "PASSED"'
      goto: run_tests  # Skip fix_code
    - goto: fix_code

fix_code:
  type: step
  command: ./auto-fix.sh
  on_success: test_loop

run_tests:
  type: step
  command: make test > test-output.txt
  on_success: test_loop
```

### Early Exit from Loops

Target outside body causes immediate loop exit:

```yaml
green_loop:
  type: while
  while: 'true'
  break_when: 'states.verify.Output contains "COMPLETE"'
  max_iterations: 10
  body:
    - implement
    - test
    - verify
  on_complete: done

test:
  type: step
  command: ./run-tests.sh
  transitions:
    - when: 'states.test.ExitCode == 0'
      goto: cleanup  # Exit loop - target outside body
    - goto: implement

cleanup:
  type: step
  command: ./cleanup.sh
  on_success: done
```

### Sequential Execution Fallback

No match or invalid target - continue sequentially:

```yaml
# Invalid target logs warning but continues
buggy_step:
  type: step
  command: echo "Processing"
  transitions:
    - when: 'states.buggy_step.Output contains "ERROR"'
      goto: nonexistent_step  # Warning logged, continues
```

## Loop Context Variables

| Variable | Type | Availability | Description |
|----------|------|--------------|-------------|
| `{{.loop.Index}}` | int | All loops | 0-based iteration index |
| `{{.loop.Index1}}` | int | All loops | 1-based iteration index |
| `{{.loop.Item}}` | any | for_each | Current item value |
| `{{.loop.First}}` | bool | All loops | True on first iteration |
| `{{.loop.Last}}` | bool | All loops | True on last iteration |
| `{{.loop.Length}}` | int | for_each | Total item count |
| `{{.loop.Parent.*}}` | any | Nested | Parent loop context (recursive chain) |

### Exponential Backoff Example

```yaml
retry_with_backoff:
  type: while
  while: 'true'
  break_when: 'states.check.Output contains "SUCCESS"'
  max_iterations: 5
  body:
    - wait_backoff
    - attempt
    - check

wait_backoff:
  type: step
  command: |
    # Exponential backoff: 2^Index seconds
    sleep $((2 ** {{.loop.Index}}))
  on_success: retry_with_backoff
```

## Nested Loops

Loops can nest. Inner loop context isolated from outer.

### Parent Context Access

| Variable | Description |
|----------|-------------|
| `{{.loop.Parent.Index}}` | Parent iteration index |
| `{{.loop.Parent.Item}}` | Parent current item |
| `{{.loop.Parent.Parent.*}}` | Grandparent loop (recursive chain) |

### Example: Test Matrix

```yaml
env_loop:
  type: for_each
  items: ["dev", "staging", "prod"]
  body:
    - setup_env
    - browser_loop
    - teardown_env
  on_complete: done

browser_loop:
  type: for_each
  items: ["chrome", "firefox", "safari"]
  body:
    - run_browser_tests
  on_complete: env_loop

run_browser_tests:
  type: step
  command: |
    echo "Testing {{.loop.Parent.Item}} with {{.loop.Item}}"
    ./test.sh --env={{.loop.Parent.Item}} --browser={{.loop.Item}}
  transitions:
    - when: 'states.run_browser_tests.ExitCode != 0'
      goto: test_failed
  on_success: browser_loop

test_failed:
  type: terminal
  status: failure
```

Inner loop transitions only affect inner loop - cannot jump to parent body steps.

## Memory Management

### Rolling Window (v0.5.29)

Long-running loops can accumulate significant memory from iteration results. Configure a rolling window to keep only recent results:

```yaml
process_large_dataset:
  type: for_each
  items: "{{.inputs.records}}"  # Could be 10,000+ items
  memory:
    max_results: 100  # Keep only last 100 iteration results
  body:
    - process_record
  on_complete: summarize
```

### Memory Options

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `memory.max_results` | int | unlimited | Rolling window size for iteration results |

### How It Works

1. **Normal operation**: Each iteration's result is stored in memory for later reference
2. **With `max_results`**: Only the most recent N results are retained
3. **Pruning**: When iteration N+1 completes, iteration 1's result is automatically pruned
4. **Access pattern**: Accessing pruned results returns empty values

### When to Use

| Scenario | Recommendation |
|----------|----------------|
| < 100 iterations | No configuration needed |
| 100-1,000 iterations | Consider `max_results: 50-100` if not accessing old results |
| 1,000+ iterations | Strongly recommend `max_results` to prevent memory growth |
| Infinite loops | Always set `max_results` |

### Example: High-Volume Processing

```yaml
name: process-events
version: "1.0.0"

inputs:
  - name: event_count
    type: integer
    default: 10000

states:
  initial: generate_events

  generate_events:
    type: step
    command: seq 1 {{.inputs.event_count}}
    on_success: process_loop

  process_loop:
    type: for_each
    items: "{{.states.generate_events.Output | splitLines}}"
    memory:
      max_results: 10  # Only need recent results for progress tracking
    body:
      - process_event
      - log_progress
    on_complete: done

  process_event:
    type: step
    command: ./process.sh --event={{.loop.Item}}
    on_success: process_loop

  log_progress:
    type: step
    command: |
      echo "Processed {{.loop.Index1}}/{{.loop.Length}}"
    on_success: process_loop

  done:
    type: terminal
    status: success
```

### Memory Monitoring

AWF automatically monitors heap allocation during loop execution. In verbose mode (`--verbose`), warnings appear when memory thresholds are exceeded. No configuration required.

## Error Handling

### On-Failure Transitions

```yaml
resilient_loop:
  type: while
  while: 'true'
  break_when: 'states.process.Output contains "DONE"'
  max_iterations: 10
  body:
    - fetch_data
    - process
  on_complete: done
  on_failure: cleanup

fetch_data:
  type: step
  command: curl -f https://api.example.com/data
  on_success: resilient_loop
  on_failure: resilient_loop  # Retry same iteration
```

### Retry Pattern

`on_failure` pointing to loop state retries the iteration:

```yaml
flaky_operation:
  type: step
  command: ./flaky-script.sh
  retry:
    max_attempts: 3
    backoff: exponential
  on_success: my_loop
  on_failure: my_loop  # Retry entire iteration
```

## Examples

### TDD Loop with Skip Steps

Skip implementation when tests pass:

```yaml
name: tdd-workflow
version: "1.0.0"

states:
  initial: green_loop

  green_loop:
    type: while
    while: 'true'
    break_when: 'states.check.Output contains "PASSED"'
    max_iterations: 10
    body:
      - run_tests
      - check
      - prepare_prompt
      - implement
      - run_fmt
    on_complete: done

  run_tests:
    type: step
    command: make test > test-output.txt
    on_success: green_loop

  check:
    type: step
    command: |
      if grep -q "PASS" test-output.txt; then
        echo "PASSED"
      else
        echo "FAILED"
      fi
    transitions:
      - when: 'states.check.Output contains "PASSED"'
        goto: run_fmt  # Skip prepare_prompt and implement
      - goto: prepare_prompt

  prepare_prompt:
    type: step
    command: ./prepare-prompt.sh
    on_success: green_loop

  implement:
    type: agent
    provider: claude
    prompt: "Implement failing test..."
    on_success: green_loop

  run_fmt:
    type: step
    command: make fmt
    on_success: green_loop

  done:
    type: terminal
    status: success
```

### Early Exit on Critical Error

```yaml
name: validate-services
version: "1.0.0"

states:
  initial: validate_loop

  validate_loop:
    type: for_each
    items: ["auth", "api", "database", "cache"]
    body:
      - check_service
      - validate_config
    on_complete: all_healthy
    on_failure: cleanup

  check_service:
    type: step
    command: systemctl is-active "{{.loop.Item}}"
    transitions:
      - when: 'states.check_service.ExitCode != 0'
        goto: critical_error  # Exit loop immediately
    on_success: validate_loop

  validate_config:
    type: step
    command: validate-config --service={{.loop.Item}}
    on_success: validate_loop

  critical_error:
    type: terminal
    status: failure
    message: "Critical service validation failed"

  all_healthy:
    type: terminal
    status: success
```

## See Also

- [Workflow Syntax](workflow-syntax.md) - State types overview
- [Interpolation](interpolation.md) - Loop variable syntax
- [Validation](validation.md) - Loop validation rules
