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
│   └── workflow_test.go
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
