# Workflow Examples

## Hello World

```yaml
name: hello
version: "1.0.0"

states:
  initial: greet
  greet:
    type: step
    command: echo "Hello, World!"
    on_success: done
  done:
    type: terminal
```

## With Inputs

```yaml
name: greet-user
version: "1.0.0"

inputs:
  - name: name
    type: string
    required: true
  - name: greeting
    type: string
    default: "Hello"

states:
  initial: greet
  greet:
    type: step
    command: echo "{{.inputs.greeting}}, {{.inputs.name}}!"
    on_success: done
  done:
    type: terminal
```

```bash
awf run greet-user --input name=Alice --input greeting=Hi
```

## Parallel Execution

```yaml
name: parallel-build
version: "1.0.0"

states:
  initial: build_all
  build_all:
    type: parallel
    strategy: all_succeed
    max_concurrent: 3
    steps:
      - name: lint
        command: golangci-lint run
      - name: test
        command: go test ./...
      - name: build
        command: go build ./cmd/...
    on_success: deploy
    on_failure: error
  deploy:
    type: step
    command: echo "All passed, deploying..."
    on_success: done
  done:
    type: terminal
  error:
    type: terminal
    status: failure
```

## Loop Over Items

```yaml
name: process-files
version: "1.0.0"

states:
  initial: process_loop
  process_loop:
    type: for_each
    items: '["file1.txt", "file2.txt", "file3.txt"]'
    body:
      - process_single
    on_complete: done
  process_single:
    type: step
    command: |
      echo "Processing {{.loop.item}} ({{.loop.index1}}/{{.loop.length}})"
    on_success: process_loop
  done:
    type: terminal
```

## Conditional Branching

```yaml
name: conditional-deploy
version: "1.0.0"

inputs:
  - name: env
    type: string
    required: true
    validation:
      enum: [dev, staging, prod]

states:
  initial: check_env
  check_env:
    type: step
    command: echo "Deploying to {{.inputs.env}}"
    transitions:
      - when: "inputs.env == 'prod'"
        goto: prod_deploy
      - when: "inputs.env == 'staging'"
        goto: staging_deploy
      - goto: dev_deploy
  prod_deploy:
    type: step
    command: ./deploy.sh prod
    timeout: 300
    on_success: done
  staging_deploy:
    type: step
    command: ./deploy.sh staging
    timeout: 180
    on_success: done
  dev_deploy:
    type: step
    command: ./deploy.sh dev
    timeout: 60
    on_success: done
  done:
    type: terminal
```

## Retry with Backoff

```yaml
name: api-call
version: "1.0.0"

states:
  initial: fetch_data
  fetch_data:
    type: step
    command: curl -f https://api.example.com/data
    retry:
      max_attempts: 5
      initial_delay: 1s
      max_delay: 30s
      backoff: exponential
      multiplier: 2
      jitter: 0.1
    on_success: process
    on_failure: error
  process:
    type: step
    command: echo "Processing..."
    on_success: done
  done:
    type: terminal
  error:
    type: terminal
    status: failure
```

## Nested Loops

```yaml
name: nested-loops
version: "1.0.0"

states:
  initial: outer_loop
  outer_loop:
    type: for_each
    items: '["A", "B", "C"]'
    body:
      - inner_loop
    on_complete: done
  inner_loop:
    type: for_each
    items: '["1", "2", "3"]'
    body:
      - process
    on_complete: outer_loop
  process:
    type: step
    command: echo "outer={{.loop.parent.item}} inner={{.loop.item}}"
    on_success: inner_loop
  done:
    type: terminal
```

## Built-in Workflows

AWF includes production-ready workflows in `.awf/workflows/`:

| Workflow | Description |
|----------|-------------|
| `audit.yaml` | Code quality audit with AI |
| `commit.yaml` | Git commit with message generation |
| `feature.yaml` | Feature creation workflow |
| `implement.yaml` | TDD implementation workflow |
