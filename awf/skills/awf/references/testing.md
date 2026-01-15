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
│   ├── execution_helpers_test.go  # Execution helper workflow validation
│   ├── test_restructuring_functional_test.go  # Validates thematic test split (v0.5.21)
│   ├── testutil_integration_test.go  # testutil package integration (v0.5.22)
│   └── testutil_loc_reduction_test.go  # Validates LOC reduction metrics (v0.5.22)
└── fixtures/workflows/
    ├── simple.yaml
    └── parallel.yaml
```

### Execution Service Tests (v0.5.21)

As of v0.5.21, execution service tests are split by theme for better discoverability:

```
internal/application/
├── execution_service.go
├── execution_service_core_test.go       # Core execution, context, errors (1,938 lines)
├── execution_service_hooks_test.go      # Pre/post hooks, error hooks (272 lines)
├── execution_service_loop_test.go       # Iteration, break, nested loops (660 lines)
├── execution_service_parallel_test.go   # Concurrent execution (70 lines)
├── execution_service_retry_test.go      # Retry policies, backoff (534 lines)
└── execution_service_specialized_mocks_test.go  # Shared mocks (108 lines)
```

**Theme descriptions**:
- `core` - Basic workflow execution, context handling, state transitions, error scenarios
- `hooks` - Pre-execution hooks, post-execution hooks, error hook behavior
- `loop` - for_each iteration, while loops, break conditions, nested loop handling
- `parallel` - Concurrent step execution, strategy validation
- `retry` - Retry policies, exponential backoff, max attempts, failure recovery
- `specialized_mocks` - Reusable mock implementations (`retryCountingExecutor`, `errorMockExecutor`)

## Test Infrastructure (v0.5.22)

AWF provides a centralized `internal/testutil` package for test infrastructure:

```
internal/testutil/
├── assertions.go    # Custom assertions with detailed failure messages
├── builders.go      # Fluent builders for Workflow, Step, State entities
├── fixtures.go      # Reusable test fixtures and factory functions
├── mocks.go         # Thread-safe mock implementations (sync.RWMutex)
└── doc.go           # Package documentation
```

### Test Builders (Fluent API)

```go
import "github.com/vanoix/awf/internal/testutil"

// Build workflow with fluent API (2-3 lines instead of 30+)
wf := testutil.NewWorkflowBuilder("test").
    WithInput("name", "string", "default").
    WithStep("greet", "echo hello").
    Build()
```

### Thread-Safe Mocks

```go
// Thread-safe mock with sync.RWMutex for concurrent tests
mock := testutil.NewThreadSafeMock()
mock.SetResult("cmd", ports.Result{Output: "ok", ExitCode: 0})
```

### Environment Variables with t.Setenv

As of v0.5.22, all tests use `t.Setenv` for automatic cleanup:

```go
// Before (manual cleanup required)
os.Setenv("AWF_CONFIG", "/tmp/test")
defer os.Unsetenv("AWF_CONFIG")

// After (automatic cleanup via t.Setenv)
t.Setenv("AWF_CONFIG", "/tmp/test")
```

**Benefits**: 359 os.Setenv calls migrated, 196 defer cleanup calls eliminated, thread-safe test isolation.

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

Use interfaces for easy mocking. As of v0.5.22, prefer the testutil package for thread-safe mocks:

```go
import "github.com/vanoix/awf/internal/testutil"

func TestExecution(t *testing.T) {
    mock := testutil.NewMockExecutor()
    mock.SetResult("echo hello", ports.Result{Output: "hello\n", ExitCode: 0})
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

Executor helpers in `internal/application/` use table-driven tests. Key test files:

- `interactive_executor_handlers_test.go` - Step success/failure handling
- `parallel_executor_coordination_test.go` - Branch coordination, strategy validation
- `template_service_helpers_test.go` - Template expansion, parameter substitution

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

## Expression Context Normalization Tests

Expression evaluator tests in `pkg/expression/` validate PascalCase normalization (v0.5.20):

```go
// pkg/expression/evaluator_test.go
func TestContextNormalization(t *testing.T) {
    tests := []struct {
        name     string
        ctx      map[string]interface{}
        expected map[string]interface{}
    }{
        {
            name: "lowercase context normalized",
            ctx:  map[string]interface{}{"context": map[string]interface{}{"retryCount": 3}},
            expected: map[string]interface{}{"Context": map[string]interface{}{"RetryCount": 3}},
        },
        {
            name: "mixed case error normalized",
            ctx:  map[string]interface{}{"error": map[string]interface{}{"message": "timeout"}},
            expected: map[string]interface{}{"Error": map[string]interface{}{"Message": "timeout"}},
        },
        {
            name:     "PascalCase preserved",
            ctx:      map[string]interface{}{"Context": map[string]interface{}{"WorkflowID": "abc"}},
            expected: map[string]interface{}{"Context": map[string]interface{}{"WorkflowID": "abc"}},
        },
    }
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            eval := NewEvaluator()
            normalized := eval.normalizeContext(tt.ctx)
            assert.Equal(t, tt.expected, normalized)
        })
    }
}
```

Integration tests in `tests/integration/expression_context_test.go` validate end-to-end normalization with workflow fixtures.

## Coverage Goals

| Layer | Target |
|-------|--------|
| Domain | >90% |
| Application | >80% |
| Infrastructure | >70% |
| CLI | Integration tests |

## Assertions (testify)

AWF uses [testify](https://github.com/stretchr/testify) for assertions:
- `require.*` - Stops test on failure (use for preconditions)
- `assert.*` - Continues on failure (use for verifications)

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
