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
│   └── graph_algorithm_refactoring_test.go  # Cycle detection and execution order
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
