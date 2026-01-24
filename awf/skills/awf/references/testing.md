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
│   ├── testutil_loc_reduction_test.go  # Validates LOC reduction metrics (v0.5.22)
│   ├── parallel_test.go  # Parallel execution strategies (v0.5.23, 948 lines)
│   ├── hooks_test.go  # Hook lifecycle and variable injection (v0.5.24, 514 lines)
│   ├── secret_masking_test.go  # Secret masking in logs/errors (v0.5.24, 693 lines)
│   ├── input_validation_test.go  # Input validation patterns (v0.5.24, 513 lines)
│   ├── cli_exitcodes_test.go  # CLI exit code behavior (v0.5.24, 648 lines)
│   ├── infrastructure_test_split_functional_test.go  # CLI & diagram test split validation (v0.5.28)
│   ├── memory_leak_test.go  # Goroutine cleanup and signal handler lifecycle (v0.5.29, 598 lines)
│   ├── memory_management_functional_test.go  # Memory bounds under 10,000+ iterations (v0.5.29, 679 lines)
│   └── test_helpers.go  # Shared test utilities including goroutine tracking (v0.5.29, 154 lines)
└── fixtures/workflows/
    ├── simple.yaml
    ├── parallel.yaml
    ├── hooks-lifecycle.yaml  # Hook execution order (v0.5.24)
    ├── hooks-failure.yaml  # Hook failure handling (v0.5.24)
    ├── hooks-variables.yaml  # Hook variable injection (v0.5.24)
    ├── secrets-masked.yaml  # Secret masking scenarios (v0.5.24)
    ├── secrets-in-errors.yaml  # Secrets in error messages (v0.5.24)
    ├── validation-enums.yaml  # Enum validation (v0.5.24)
    ├── validation-numeric.yaml  # Numeric validation (v0.5.24)
    ├── validation-patterns.yaml  # Pattern validation (v0.5.24)
    ├── exit-execution-error.yaml  # Execution error exit codes (v0.5.24)
    ├── exit-user-error.yaml  # User error exit codes (v0.5.24)
    └── exit-workflow-error.yaml  # Workflow error exit codes (v0.5.24)
```

### Domain Workflow Tests (v0.5.26)

As of v0.5.26, domain workflow tests are split by concern for improved maintainability:

```
internal/domain/workflow/
├── workflow.go
├── agent_config_config_test.go       # Agent configuration parsing (from agent_config_test.go)
├── agent_config_conversation_test.go # Multi-turn conversation config (from agent_config_test.go)
├── agent_config_result_test.go       # Agent result parsing (from agent_config_test.go)
├── domain_test_helpers_test.go       # Shared test utilities (212 lines)
├── step_command_test.go              # Shell command execution tests (405 lines)
├── step_loop_test.go                 # Loop validation and execution (320 lines)
├── step_agent_test.go                # Agent step functionality and hooks (730 lines)
├── step_parallel_test.go             # Parallel execution strategies (renamed)
├── template_validation_inputs_test.go   # Input template validation (165 lines)
├── template_validation_states_test.go   # State reference validation (555 lines)
├── template_validation_workflow_test.go # Workflow context templates (192 lines)
└── template_validation_error_test.go    # Error and hook constraints (1,039 lines)
```

**Split summary** (3 monolithic files → 11 focused modules):
- `agent_config_test.go` (1,615 lines) → 4 files by operation type
- `step_*_test.go` (1,819 lines) → 3 files by concern
- `template_validation_test.go` → 4 files by template namespace

**Integration test validation**: `tests/integration/domain_test_splitting_test.go` verifies file organization and test preservation.

### Loop Executor Tests (v0.5.27)

As of v0.5.27, loop executor tests are split by functional concern for improved maintainability:

```
internal/application/
├── loop_executor.go
├── loop_executor_core_test.go       # Core execution logic (246 lines)
├── loop_executor_mocks_test.go      # Shared test doubles (119 lines)
├── loop_foreach_test.go             # Foreach loop behavior (988 lines)
├── loop_iterations_test.go          # Iteration count and limit (609 lines)
├── loop_while_test.go               # While loop conditions (1,383 lines)
├── loop_transitions_earlyexit_test.go    # Early exit/break/continue (955 lines)
├── loop_transitions_foreach_test.go      # Foreach transition scenarios (1,477 lines)
├── loop_transitions_intrabody_test.go    # Intra-body loop transitions (2,639 lines)
└── loop_executor_transitions_test.go     # General transition scenarios
```

**Split summary** (1 monolithic file → 9 focused modules):
- `loop_executor_test.go` (4,155 lines) → 9 files by loop type and transition category
- Loop types: `foreach`, `while`, `iterations`
- Transition categories: `earlyexit`, `foreach`, `intrabody`
- Shared infrastructure: `core`, `mocks`

**Test preservation**: All 179 tests maintained with 100% coverage (78.6% ±0.5% of baseline 79.2%)

**Integration test validation**: `tests/integration/application_test_split_functional_test.go` verifies:
- Zero test duplication
- Proper package organization
- Race condition absence

### CLI Tests (v0.5.28)

As of v0.5.28, CLI tests are split by concern for improved maintainability:

```
internal/interfaces/cli/
├── run.go                       # Main run command implementation
├── cli_test_helpers_test.go     # Shared test helpers and utilities
├── run_agent_test.go            # Agent execution logic (14 tests)
├── run_execution_test.go        # Execution flow control (9 tests)
├── run_flags_test.go            # CLI flag parsing and validation (27 tests)
└── run_interactive_test.go      # Interactive mode (2 tests)
```

**Split summary** (1 monolithic file -> 4 focused modules):
- `run_test.go` (2,439 lines, 51 tests) -> 4 files by functional concern
- Test categories: `agent`, `execution`, `flags`, `interactive`
- Shared infrastructure: `cli_test_helpers`

**Test preservation**: All 51 tests maintained with strict concurrency safety (`go test -race ./...`)

**Integration test validation**: `tests/integration/infrastructure_test_split_functional_test.go` verifies:
- Zero test duplication
- Proper package organization
- Race condition absence

### Diagram Tests (v0.5.28)

As of v0.5.28, diagram generator tests are split by concern:

```
internal/infrastructure/diagram/
├── dot_generator.go                  # Main DOT generation
├── diagram_test_helpers_test.go      # Shared test helpers
├── dot_generator_core_test.go        # Core DOT generation (33 tests)
├── generator_edges_test.go           # Edge generation (24 tests)
├── generator_header_test.go          # Header formatting (16 tests)
├── generator_highlight_test.go       # Syntax highlighting (15 tests)
├── generator_nodes_test.go           # Node creation (18 tests)
└── generator_parallel_test.go        # Parallel diagram generation (24 tests)
```

**Split summary** (1 monolithic file -> 6 focused modules):
- `dot_generator_test.go` (4,499 lines, 130 tests) -> 6 files by concern
- Test categories: `core`, `edges`, `header`, `highlight`, `nodes`, `parallel`
- Shared infrastructure: `diagram_test_helpers`

**Test preservation**: All 130 tests maintained (181 total across both splits + 1 integration = 182)

### Store Layer Tests (v0.5.30)

As of v0.5.30, comprehensive tests validate store validation and persistence:

```
internal/infrastructure/store/
├── sqlite_history_store.go           # SQLite history storage (WAL mode)
├── sqlite_history_store_test.go      # Comprehensive SQLite tests (2,082 lines, 43 tests)
├── json_store.go                     # JSON state store
└── json_store_test.go                # Enhanced JSON tests (+384 lines, 13 tests)
```

**SQLite History Store Tests** (2,082 lines):
- CRUD operations: create, read, update, delete workflow records
- Error paths: invalid IDs, missing records, database corruption
- Nil handling: nil record validation preventing segmentation faults
- Concurrent stress tests: 20 goroutines racing on read/write operations
- Edge cases: empty strings, unicode content, very large outputs

**JSON Store Tests** (+384 lines):
- Concurrent access: multiple goroutines reading/writing same state file
- Corruption recovery: handling malformed JSON, partial writes
- Atomic operations: temp file + rename pattern verification

**Coverage**: 80.7% for store package (exceeds 70% infrastructure target)

### Functional Integration Tests (v0.5.30)

New functional tests validate end-to-end behavior for validation and persistence:

```
tests/integration/
├── input_validation_functional_test.go    # Pattern, enum, min/max validation (438 lines)
└── state_persistence_functional_test.go   # JSON and SQLite persistence (206 lines)
```

### Package Test Coverage (v0.5.31)

As of v0.5.31, comprehensive tests validate pkg/ interpolation and retry functionality:

```
pkg/interpolation/
├── resolver.go
├── resolver_test.go                # Expanded tests (+1,020 lines, 188+ test cases)
└── template_resolver.go            # Expression namespace accessors

pkg/retry/
├── retry.go
├── retry_test.go                   # Completed logging assertions

tests/integration/
└── pkg_test_coverage_functional_test.go  # End-to-end pkg validation (633 lines, 5 tests)
```

**Interpolation Tests** (+1,020 lines):
- `StepStateData.Response` - Nested objects, multiple fields, JSON access patterns
- `StepStateData.Tokens` - Formatter behavior, edge cases, nil handling
- `LoopData.Parent` - Nested loop access, serialization, parent context propagation
- Expression namespace syntax - Lowercase property access via accessors (`{{loop.*}}`, `{{context.*}}`, `{{error.*}}`)

**Retry Tests** (completed):
- `TestRetryer_LogsAttempts` - Comprehensive logging assertions verifying debug calls with attempt number and delay fields

**Functional Integration Tests** (633 lines, 5 functions):
- Validates `LoopData.Parent` works in nested loop workflows
- Validates `StepStateData.Response` and `Tokens` fields in agent execution
- Validates expression namespace accessors work end-to-end

**Input Validation Functional Tests** (438 lines):
- Pattern validation through full execution pipeline
- Enum validation with valid/invalid values
- Numeric min/max validation boundaries

**State Persistence Functional Tests** (206 lines):
- JSON store behavior under concurrent workflow execution
- SQLite store behavior under concurrent and corruption conditions
- Resume capability after partial execution

### Memory and Resource Management Tests (v0.5.29)

As of v0.5.29, comprehensive tests validate memory bounds and goroutine lifecycle:

```
internal/application/
├── memory_monitor.go              # Heap allocation monitoring
├── memory_monitor_test.go         # Threshold alerting tests (466 lines)
├── output_limiter.go              # Output size limits
├── output_limiter_test.go         # Truncation and streaming tests (506 lines)
├── output_streamer.go             # Temp file streaming
├── output_streamer_test.go        # File streaming lifecycle tests (574 lines)
├── loop_executor_memory_test.go   # Rolling window and pruning tests (522 lines)
└── execution_service_helpers_test.go  # Step output handling tests (430 lines)

internal/interfaces/cli/
├── signal_handler.go              # Shared signal handler
└── signal_handler_test.go         # Goroutine cleanup tests (410 lines)

tests/integration/
├── memory_leak_test.go            # Goroutine cleanup validation (598 lines)
├── memory_management_functional_test.go  # Memory bounds under load (679 lines)
└── test_helpers.go                # Goroutine count tracking utilities (154 lines)
```

**Test coverage** (1,799 new lines):
- Memory monitoring: threshold alerting, periodic checking
- Output limiting: truncation strategies, streaming to temp files
- Loop memory: rolling window pruning, bounded iteration results
- Signal handler: goroutine cleanup, race detection, behavioral consistency

**Key assertions**:
- Zero goroutine leaks after signal handler cleanup
- Bounded memory growth under 10,000+ loop iterations
- Output streaming lifecycle (create, write, cleanup)
- Race-free signal handling (`go test -race`)

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

## ServiceTestHarness (v0.5.25)

Application-layer tests use `ServiceTestHarness` for fluent test setup:

```
internal/application/
├── testutil_harness.go       # ServiceTestHarness fluent builder (249 lines)
├── testutil_harness_test.go  # Harness unit tests (490 lines)
├── testutil_harness_functional_test.go  # Core functional tests (649 lines)
└── testutil_harness_advanced_functional_test.go  # Advanced tests (388 lines)
```

### Fluent Builder API

```go
import "github.com/vanoix/awf/internal/application"

// Before (10-15 lines per test)
mockRepo := testutil.NewMockRepository()
mockStore := testutil.NewMockStateStore()
mockExecutor := testutil.NewMockExecutor()
mockExecutor.SetResult("echo hello", ports.Result{Output: "hello", ExitCode: 0})
service := application.NewExecutionService(mockRepo, mockStore, mockExecutor)

// After (3-line fluent chain)
service, mocks := application.NewServiceTestHarness().
    WithMockResult("echo hello", "hello", 0).
    Build()
```

### Harness Methods

| Method | Purpose |
|--------|---------|
| `WithWorkflow(wf)` | Configure workflow for test |
| `WithMockResult(cmd, output, exitCode)` | Set mock executor response |
| `WithState(name, state)` | Pre-populate execution state |
| `WithInput(key, value)` | Set input parameter |
| `Build()` | Returns `(service, mocks)` tuple |

### Impact Metrics (v0.5.25)

| Metric | Value |
|--------|-------|
| Setup boilerplate reduction | 71% |
| Overall test code reduction | 29% (13,676 → 9,753 lines) |
| Files refactored | 8 application test files |
| Functional tests added | 18 (12 core + 6 advanced) |

### ADR Compliance

- **ADR-001**: Harness lives in `application` package (package-local pattern)
- **ADR-002**: Wraps `testutil` infrastructure (wrapper pattern, not duplication)
- **ADR-003**: `Build()` returns `(service, mocks)` tuple for assertion access

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

## Parallel Execution Tests (v0.5.23)

Integration tests for parallel execution cover all strategies at CLI level (`tests/integration/parallel_test.go`):

| Strategy | Behavior | Test Scenarios |
|----------|----------|----------------|
| `all_succeed` | Fails if ANY branch fails | All pass, one fail, all fail |
| `any_succeed` | Succeeds if ANY branch succeeds | One pass, all pass, all fail |
| `best_effort` | All branches complete regardless | Mixed results, failure isolation |

### max_concurrent Testing

Tests validate concurrency limits with timing assertions:

```go
// Validates max_concurrent=2 with 3 branches serializes execution
// Uses 3x timing margin for CI variability (per ADR-004)
t.Run("max_concurrent limit enforced", func(t *testing.T) {
    // 3 branches with 100ms each, max_concurrent=2
    // Expected: ~200ms (2 rounds), not ~100ms (full parallel)
    // Assertion: duration > 150ms (1.5x single branch)
})
```

### Thread-Safe ExecutionContext

PR #111 added RWMutex protection for concurrent map access:

```go
// internal/domain/workflow/context.go
type ExecutionContext struct {
    mu           sync.RWMutex // protects concurrent map access
    States       map[string]StepState
    // ...
}

// Thread-safe state access
func (c *ExecutionContext) GetAllStepStates() map[string]StepState {
    c.mu.RLock()
    defer c.mu.RUnlock()
    // Returns defensive copy
}
```

Tests use inline YAML fixtures for visibility and testutil builders for 93% setup reduction.

## Hooks and Secret Masking Tests (v0.5.24)

Integration tests for workflow hooks and secret masking (`tests/integration/`):

### Hook Tests

| Test File | Coverage | Lines |
|-----------|----------|-------|
| `hooks_test.go` | Hook lifecycle, failure handling, variable injection | 514 |

**Hook lifecycle tests**:
- Pre-execution hooks run before step execution
- Post-execution hooks run after step completion
- Error hooks run on step failure
- Hooks receive context variables (workflow name, step name, inputs)

### Secret Masking Tests

| Test File | Coverage | Lines |
|-----------|----------|-------|
| `secret_masking_test.go` | Log masking, error masking, nested secrets | 693 |

**Secret masking implementation** (`internal/infrastructure/logger/masker.go`):
- Masks secrets in log output
- Masks secrets in error messages
- Handles nested secret values
- Preserves masked placeholder format (`***`)

### Input Validation Tests

| Test File | Coverage | Lines |
|-----------|----------|-------|
| `input_validation_test.go` | Enum, numeric, pattern validation | 513 |

**Validation fixtures**:
- `validation-enums.yaml` - Enum type validation
- `validation-numeric.yaml` - Numeric range validation
- `validation-patterns.yaml` - Regex pattern validation

### CLI Exit Code Tests

| Test File | Coverage | Lines |
|-----------|----------|-------|
| `cli_exitcodes_test.go` | Exit code semantics for error types | 648 |

**Exit code fixtures**:
- `exit-execution-error.yaml` - Exit code 1 for execution errors
- `exit-user-error.yaml` - Exit code 2 for user input errors
- `exit-workflow-error.yaml` - Exit code 3 for workflow definition errors

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

UI helpers in `internal/interfaces/cli/` and `internal/interfaces/cli/ui/` use table-driven tests:

- `list_helpers_test.go` - `buildPromptInfo`, `shouldProcessEntry`
- `ui/field_formatters_test.go` - `FormatIntFieldIfPositive`
- `ui/row_builders_test.go` - `BuildValidationRow`

## Application Helper Tests

Executor helpers in `internal/application/` use table-driven tests:

- `interactive_executor_handlers_test.go` - Step success/failure handling
- `parallel_executor_coordination_test.go` - Branch coordination, strategy validation
- `template_service_helpers_test.go` - Template expansion, parameter substitution
- `conversation_manager_helpers_test.go` - Turn management, stop conditions

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
