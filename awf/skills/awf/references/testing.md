# Testing

## Running Tests

```bash
make test            # All tests
make test-unit       # Unit tests (internal/, pkg/)
make test-integration # Integration tests (tests/integration/)
make test-race       # With race detector
make test-coverage   # With coverage report
```

## Test Structure

### Unit Tests

Located alongside code:

```
internal/domain/workflow/
├── workflow.go
└── workflow_test.go
```

### Integration Tests

Located in `tests/integration/`:

```
tests/
├── integration/
│   ├── cli_test.go
│   ├── workflow_test.go
│   ├── validation_providers_test.go  # Agent provider behavior validation
│   ├── graph_algorithm_refactoring_test.go  # Cycle detection and execution order
│   ├── cognitive_complexity_refactoring_test.go  # Executor helper refactoring
│   └── execution_helpers_test.go  # Execution helper workflow validation
└── fixtures/workflows/
    ├── simple.yaml
    └── parallel.yaml
```

## Table-Driven Tests

```go
func TestWorkflowValidation(t *testing.T) {
    tests := []struct {
        name    string
        workflow *workflow.Workflow
        wantErr bool
        errMsg  string
    }{
        {
            name: "valid workflow",
            workflow: &workflow.Workflow{...},
            wantErr: false,
        },
        {
            name: "missing initial state",
            workflow: &workflow.Workflow{...},
            wantErr: true,
            errMsg: "initial state not found",
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            err := tt.workflow.Validate()
            if tt.wantErr {
                require.Error(t, err)
                assert.Contains(t, err.Error(), tt.errMsg)
            } else {
                require.NoError(t, err)
            }
        })
    }
}
```

## Mocking

Use interfaces for easy mocking:

```go
type mockExecutor struct {
    results map[string]ports.Result
}

func (m *mockExecutor) Execute(ctx context.Context, cmd ports.Command) (ports.Result, error) {
    return m.results[cmd.Command], nil
}

func TestExecution(t *testing.T) {
    mock := &mockExecutor{
        results: map[string]ports.Result{
            "echo hello": {Output: "hello\n", ExitCode: 0},
        },
    }
    service := application.NewExecutionService(repo, store, mock)
    // ... test
}
```

## Domain Algorithm Tests

Graph algorithms in `internal/domain/workflow/graph.go` use extracted helpers for testability:

```go
func TestVisitState_Enum(t *testing.T) {
    assert.Equal(t, VisitState(0), Unvisited)
    assert.Equal(t, VisitState(1), Visiting)
    assert.Equal(t, VisitState(2), Visited)
}

func TestProcessTransition_CycleDetection(t *testing.T) {
    visited := map[string]VisitState{"a": Visiting}
    err := ProcessTransition("a", visited, ...)
    require.Error(t, err)
    assert.Contains(t, err.Error(), "cycle detected")
}

func TestEnqueueIfNotVisited(t *testing.T) {
    queue := []string{}
    visited := map[string]bool{}

    EnqueueIfNotVisited("a", &queue, visited)
    assert.Equal(t, []string{"a"}, queue)
    assert.True(t, visited["a"])

    // Already visited - no duplicate
    EnqueueIfNotVisited("a", &queue, visited)
    assert.Len(t, queue, 1)
}
```

## CLI Helper Tests

UI helpers in `internal/interfaces/cli/` and `internal/interfaces/cli/ui/` are tested with table-driven unit tests:

```go
// internal/interfaces/cli/list_helpers_test.go
func TestBuildPromptInfo(t *testing.T) {
    tests := []struct {
        name     string
        entry    WorkflowEntry
        expected PromptInfo
    }{
        {
            name:  "workflow with inputs",
            entry: WorkflowEntry{Name: "test", Inputs: []Input{{Name: "foo"}}},
            expected: PromptInfo{HasInputs: true, InputCount: 1},
        },
    }
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            result := buildPromptInfo(tt.entry)
            assert.Equal(t, tt.expected, result)
        })
    }
}

func TestShouldProcessEntry(t *testing.T) {
    tests := []struct {
        name     string
        entry    WorkflowEntry
        filter   Filter
        expected bool
    }{
        {"matches filter", WorkflowEntry{Name: "test"}, Filter{Name: "test"}, true},
        {"no match", WorkflowEntry{Name: "other"}, Filter{Name: "test"}, false},
    }
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            assert.Equal(t, tt.expected, shouldProcessEntry(tt.entry, tt.filter))
        })
    }
}
```

```go
// internal/interfaces/cli/ui/field_formatters_test.go
func TestFormatIntFieldIfPositive(t *testing.T) {
    tests := []struct {
        value    int
        expected string
    }{
        {5, "5"},
        {0, ""},
        {-1, ""},
    }
    for _, tt := range tests {
        t.Run(fmt.Sprintf("value_%d", tt.value), func(t *testing.T) {
            assert.Equal(t, tt.expected, FormatIntFieldIfPositive(tt.value))
        })
    }
}
```

```go
// internal/interfaces/cli/ui/row_builders_test.go
func TestBuildValidationRow(t *testing.T) {
    result := ValidationResult{Field: "name", Status: "ok", Count: 3}
    row := BuildValidationRow(result)
    assert.Equal(t, []string{"name", "ok", "3"}, row)
}
```

## Application Helper Tests

Executor helpers in `internal/application/` are tested with comprehensive table-driven tests:

```go
// internal/application/interactive_executor_handlers_test.go
func TestHandleStepSuccess(t *testing.T) {
    tests := []struct {
        name     string
        result   StepResult
        expected error
    }{
        {
            name:     "successful step transitions",
            result:   StepResult{ExitCode: 0, Output: "done"},
            expected: nil,
        },
        {
            name:     "step with warnings",
            result:   StepResult{ExitCode: 0, Warnings: []string{"deprecated"}},
            expected: nil,
        },
    }
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            executor := NewInteractiveExecutor(mockRepo, mockStore)
            err := executor.handleStepSuccess(context.Background(), tt.result)
            assert.Equal(t, tt.expected, err)
        })
    }
}
```

```go
// internal/application/parallel_executor_coordination_test.go
func TestCoordinateBranches(t *testing.T) {
    tests := []struct {
        name     string
        branches []Branch
        wantErr  bool
    }{
        {
            name:     "all branches succeed",
            branches: []Branch{{Name: "a"}, {Name: "b"}},
            wantErr:  false,
        },
        {
            name:     "one branch fails with any_succeed",
            branches: []Branch{{Name: "a", Fail: true}, {Name: "b"}},
            wantErr:  false, // any_succeed tolerates failures
        },
    }
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            executor := NewParallelExecutor(mockCtx)
            err := executor.coordinateBranches(context.Background(), tt.branches)
            if tt.wantErr {
                require.Error(t, err)
            } else {
                require.NoError(t, err)
            }
        })
    }
}
```

```go
// internal/application/template_service_helpers_test.go
func TestExpandParameters(t *testing.T) {
    tests := []struct {
        name     string
        params   map[string]interface{}
        ctx      Context
        expected map[string]interface{}
        wantErr  bool
    }{
        {
            name:     "simple substitution",
            params:   map[string]interface{}{"file": "{{.inputs.path}}"},
            ctx:      Context{Inputs: map[string]interface{}{"path": "/tmp/test"}},
            expected: map[string]interface{}{"file": "/tmp/test"},
        },
        {
            name:     "nested template",
            params:   map[string]interface{}{"cmd": "echo {{.states.prev.Output}}"},
            ctx:      Context{States: map[string]StateResult{"prev": {Output: "hello"}}},
            expected: map[string]interface{}{"cmd": "echo hello"},
        },
    }
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            svc := NewTemplateService()
            result, err := svc.expandParameters(tt.params, tt.ctx)
            if tt.wantErr {
                require.Error(t, err)
            } else {
                require.NoError(t, err)
                assert.Equal(t, tt.expected, result)
            }
        })
    }
}
```

## Conversation Manager Helper Tests

Conversation manager helpers in `internal/application/` are tested with comprehensive table-driven tests:

```go
// internal/application/conversation_manager_helpers_test.go
func TestShouldContinueConversation(t *testing.T) {
    tests := []struct {
        name     string
        state    ConversationState
        expected bool
    }{
        {
            name:     "continue when under max turns",
            state:    ConversationState{Turn: 3, MaxTurns: 10},
            expected: true,
        },
        {
            name:     "stop when stop condition met",
            state:    ConversationState{Turn: 2, StopConditionMet: true},
            expected: false,
        },
        {
            name:     "stop when max turns reached",
            state:    ConversationState{Turn: 10, MaxTurns: 10},
            expected: false,
        },
    }
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            manager := NewConversationManager()
            assert.Equal(t, tt.expected, manager.shouldContinueConversation(tt.state))
        })
    }
}
```

## Loop Pattern Helper Tests

Loop pattern detection helpers in `internal/application/` use table-driven tests:

```go
// internal/application/loop_pattern_helpers_test.go
func TestDetectLoopPattern(t *testing.T) {
    tests := []struct {
        name     string
        state    State
        expected LoopPattern
    }{
        {
            name:     "for_each loop",
            state:    State{Type: "for_each", Items: []string{"a", "b"}},
            expected: LoopPattern{Type: ForEach, Items: []string{"a", "b"}},
        },
        {
            name:     "while loop",
            state:    State{Type: "while", Condition: "inputs.count > 0"},
            expected: LoopPattern{Type: While, Condition: "inputs.count > 0"},
        },
        {
            name:     "non-loop state",
            state:    State{Type: "step"},
            expected: LoopPattern{Type: NoLoop},
        },
    }
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            svc := NewExecutionService(mockRepo, mockStore, mockExecutor)
            assert.Equal(t, tt.expected, svc.detectLoopPattern(tt.state))
        })
    }
}

func TestShouldTerminateLoop(t *testing.T) {
    tests := []struct {
        name      string
        pattern   LoopPattern
        iteration int
        expected  bool
    }{
        {
            name:      "for_each completes all items",
            pattern:   LoopPattern{Type: ForEach, Items: []string{"a", "b"}},
            iteration: 2,
            expected:  true,
        },
        {
            name:      "while condition becomes false",
            pattern:   LoopPattern{Type: While, ConditionResult: false},
            iteration: 1,
            expected:  true,
        },
    }
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            svc := NewExecutionService(mockRepo, mockStore, mockExecutor)
            assert.Equal(t, tt.expected, svc.shouldTerminateLoop(tt.pattern, tt.iteration))
        })
    }
}
```

## Infrastructure Helper Tests

Agent providers share utility functions in `internal/infrastructure/agents/helpers.go`. Test these helpers directly:

```go
func TestCloneState(t *testing.T) {
    original := map[string]interface{}{
        "key": "value",
        "nested": map[string]interface{}{"a": 1},
    }
    cloned := CloneState(original)

    // Verify deep copy (modifications don't affect original)
    cloned["key"] = "modified"
    assert.Equal(t, "value", original["key"])
}

func TestEstimateTokens(t *testing.T) {
    tests := []struct {
        text     string
        expected int
    }{
        {"hello world", 2},
        {"", 0},
    }
    for _, tt := range tests {
        t.Run(tt.text, func(t *testing.T) {
            assert.Equal(t, tt.expected, EstimateTokens(tt.text))
        })
    }
}
```

## Coverage Goals

| Layer | Target |
|-------|--------|
| Domain | >90% |
| Application | >80% |
| Infrastructure | >70% |
| CLI | Integration tests |

## Assertions (testify)

AWF uses the [testify](https://github.com/stretchr/testify) library for all test assertions. As of v0.5.13, manual `if` checks have been migrated to testify assertions.

```go
import (
    "github.com/stretchr/testify/assert"
    "github.com/stretchr/testify/require"
)

func TestExample(t *testing.T) {
    // require.* stops test on failure (use for preconditions)
    require.NoError(t, err)
    require.NotNil(t, result)

    // assert.* continues test on failure (use for verifications)
    assert.Equal(t, expected, actual)
    assert.Contains(t, haystack, needle)
    assert.True(t, condition)
    assert.Len(t, slice, 3)
}
```

**Migration from manual checks**:

```go
// Before (manual check)
if result != expected {
    t.Errorf("got %v, want %v", result, expected)
}

// After (testify)
assert.Equal(t, expected, result)
```

**When to use require vs assert**:
- `require.*` - Preconditions that must pass for test to continue
- `assert.*` - Verifications where multiple failures are informative

## Test Naming

```go
// Unit: Test<Function>_<Scenario>
func TestValidate_MissingInitialState(t *testing.T)

// Integration: Test<Component>_<Action>_Integration
func TestCLI_Run_FailingCommand_Integration(t *testing.T)

// Benchmark: Benchmark<Function>
func BenchmarkInterpolate(b *testing.B)
```

## CI Integration

```yaml
# .github/workflows/ci.yaml
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v5
        with:
          go-version: '1.21'
      - run: make test
      - run: make test-race
```
