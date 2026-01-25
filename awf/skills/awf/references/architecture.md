# AWF Architecture

## Overview

AWF follows Hexagonal (Ports and Adapters) / Clean Architecture.

```
┌─────────────────────────────────────────────────────────────┐
│                     INTERFACES LAYER                        │
│      CLI (current)  │  API (future)  │  MQ (future)        │
└───────────────────────────┬─────────────────────────────────┘
                            │
┌───────────────────────────┴─────────────────────────────────┐
│                   APPLICATION LAYER                         │
│   WorkflowService │ ExecutionService │ StateManager         │
└───────────────────────────┬─────────────────────────────────┘
                            │
┌───────────────────────────┴─────────────────────────────────┐
│                      DOMAIN LAYER                           │
│   Workflow │ Step │ ExecutionContext │ Ports (Interfaces)   │
└───────────────────────────┬─────────────────────────────────┘
                            │
┌───────────────────────────┴─────────────────────────────────┐
│                  INFRASTRUCTURE LAYER                       │
│   YAMLRepository │ JSONStateStore │ ShellExecutor          │
└─────────────────────────────────────────────────────────────┘
```

## Dependency Rule

**Domain layer depends on nothing. All other layers depend inward.**

```
Interfaces → Application → Domain ← Infrastructure
```

## Project Structure

```
awf/
├── cmd/awf/main.go              # CLI entry point
├── internal/
│   ├── domain/
│   │   ├── workflow/            # Workflow, Step, State entities
│   │   │   ├── workflow.go      # Workflow struct
│   │   │   ├── state.go         # State types
│   │   │   ├── step.go          # Step execution
│   │   │   ├── context.go       # Execution context
│   │   │   ├── validation.go    # Input validation
│   │   │   ├── graph.go         # Graph algorithms (cycle detection, execution order)
│   │   │   ├── template_validation.go  # Template validation with BFS helpers
│   │   │   ├── domain_test_helpers_test.go  # Shared test utilities (v0.5.26)
│   │   │   ├── agent_config_*_test.go       # Agent config tests (split, v0.5.26)
│   │   │   ├── step_*_test.go               # Step tests by type (v0.5.26)
│   │   │   └── template_validation_*_test.go  # Template tests by namespace (v0.5.26)
│   │   ├── operation/           # Operation interface
│   │   └── ports/               # Repository, StateStore, Executor
│   ├── application/             # Services
│   │   ├── workflow_service.go  # Loading/validation
│   │   ├── execution_service.go # Execution engine with loop pattern helpers
│   │   ├── execution_service_*_test.go  # Thematic test files (v0.5.21)
│   │   ├── execution_service_helpers_test.go  # Step output handling tests (v0.5.29)
│   │   ├── loop_executor.go     # Loop execution engine with memory pruning
│   │   ├── loop_executor_core_test.go   # Core logic tests (v0.5.27)
│   │   ├── loop_executor_mocks_test.go  # Shared test doubles (v0.5.27)
│   │   ├── loop_executor_memory_test.go # Memory pruning and rolling window (v0.5.29)
│   │   ├── loop_foreach_test.go         # Foreach behavior (v0.5.27)
│   │   ├── loop_iterations_test.go      # Iteration limits (v0.5.27)
│   │   ├── loop_while_test.go           # While conditions (v0.5.27)
│   │   ├── loop_transitions_*_test.go   # Transition scenarios (v0.5.27)
│   │   ├── loop_pattern_helpers_test.go # Loop pattern detection tests (v0.5.29)
│   │   ├── memory_monitor.go    # Heap allocation monitoring (v0.5.29)
│   │   ├── memory_monitor_test.go  # Memory monitoring tests (v0.5.29)
│   │   ├── output_limiter.go    # Output size limits and truncation (v0.5.29)
│   │   ├── output_limiter_test.go  # Output limiter tests (v0.5.29)
│   │   ├── output_streamer.go   # Temp file streaming for large outputs (v0.5.29)
│   │   ├── output_streamer_test.go  # Output streamer tests (v0.5.29)
│   │   ├── testutil_harness.go  # ServiceTestHarness fluent builder (v0.5.25)
│   │   ├── testutil_harness_*_test.go  # Harness unit and functional tests
│   │   ├── conversation_manager.go  # Multi-turn conversation coordination
│   │   ├── interactive_executor.go  # Step execution with result handlers
│   │   ├── parallel_executor.go     # Parallel step coordination
│   │   ├── state_manager.go     # State persistence
│   │   └── template_service.go  # Template resolution with param helpers
│   ├── testutil/                # Test infrastructure (v0.5.22, updated v0.5.32)
│   │   ├── builders.go          # Fluent builders for Workflow, Step, State
│   │   ├── fixtures.go          # Reusable test fixtures and factories
│   │   ├── mocks.go             # Thread-safe mocks with sync.RWMutex
│   │   ├── cli_fixtures.go      # CLI-specific test fixtures
│   │   └── doc.go               # Package documentation and examples
│   ├── infrastructure/          # Adapters
│   │   ├── repository/yaml.go   # YAML file loader
│   │   ├── state/json.go        # JSON state store
│   │   ├── executor/shell.go    # Shell executor
│   │   ├── store/                # Persistence stores (v0.5.30)
│   │   │   ├── sqlite_history_store.go       # SQLite history (WAL mode)
│   │   │   ├── sqlite_history_store_test.go  # SQLite tests (2,082 lines, 43 tests)
│   │   │   ├── json_store.go                 # JSON state store
│   │   │   └── json_store_test.go            # JSON tests (+384 lines, 13 tests)
│   │   ├── logger/              # Logging utilities (v0.5.24)
│   │   │   └── masker.go        # Secret masking in logs/errors
│   │   ├── diagram/             # Workflow visualization (v0.5.28)
│   │   │   ├── dot_generator.go              # DOT format generation
│   │   │   ├── diagram_test_helpers_test.go  # Shared test utilities
│   │   │   ├── dot_generator_core_test.go    # Core DOT generation (33 tests)
│   │   │   ├── generator_edges_test.go       # Edge generation (24 tests)
│   │   │   ├── generator_header_test.go      # Header formatting (16 tests)
│   │   │   ├── generator_highlight_test.go   # Syntax highlighting (15 tests)
│   │   │   ├── generator_nodes_test.go       # Node creation (18 tests)
│   │   │   └── generator_parallel_test.go    # Parallel diagram gen (24 tests)
│   │   └── agents/              # AI provider adapters
│   │       ├── helpers.go       # Shared utilities (cloneState, estimateTokens)
│   │       ├── claude_provider.go
│   │       ├── codex_provider.go
│   │       └── gemini_provider.go
│   └── interfaces/cli/          # Cobra commands
│       ├── ui/                  # UI formatting helpers
│       │   ├── output.go        # Table output, row builders
│       │   ├── dry_run_formatter.go  # Dry-run display formatting
│       │   └── field_formatters_test.go  # Field formatter tests
│       ├── config.go            # Config loading with AWF_PROMPT_PATH support (v0.5.28)
│       ├── list.go              # List command with prompt helpers
│       ├── list_helpers_test.go # List helper unit tests
│       ├── cli_test_helpers_test.go  # Shared CLI test utilities (v0.5.28)
│       ├── run.go               # Main run command implementation
│       ├── run_agent_test.go         # Agent execution tests (14 tests, v0.5.28)
│       ├── run_execution_test.go     # Execution flow tests (9 tests, v0.5.28)
│       ├── run_flags_test.go         # Flag parsing tests (27 tests, v0.5.28)
│       ├── run_interactive_test.go   # Interactive mode tests (2 tests, v0.5.28)
│       ├── resume.go            # Resume command with signal handler (v0.5.29)
│       ├── signal_handler.go    # Shared signal handler preventing goroutine leaks (v0.5.29)
│       └── signal_handler_test.go  # Signal handler cleanup tests (v0.5.29)
├── pkg/                         # Public packages
│   ├── interpolation/           # Variable substitution
│   ├── validation/              # Input validation
│   ├── retry/                   # Backoff strategies
│   └── plugin/sdk/              # Plugin SDK for third-party plugins
├── tests/                       # Integration tests
│   ├── integration/             # E2E tests
│   │   ├── input_validation_functional_test.go    # Validation pipeline (v0.5.30)
│   │   └── state_persistence_functional_test.go   # Persistence tests (v0.5.30)
│   └── fixtures/workflows/      # Test fixtures
└── docs/                        # Documentation
```

## Naming Conventions

| Pattern | Location | Example |
|---------|----------|---------|
| `*_service.go` | Application layer | `workflow_service.go` |
| `*_test.go` | Same directory | `yaml_test.go` |
| Interfaces | `ports/` | `repository.go` |
| Adapters | Infrastructure subdirs | `repository/yaml.go` |

## Import Paths

```go
// Domain (no external imports)
import "github.com/vanoix/awf/internal/domain/workflow"

// Application (imports domain only)
import "github.com/vanoix/awf/internal/application"

// Infrastructure (imports domain ports)
import "github.com/vanoix/awf/internal/infrastructure/repository"

// Public packages (safe for external use)
import "github.com/vanoix/awf/pkg/interpolation"
```

## Domain Layer

Core business logic. No external dependencies.

**Location:** `internal/domain/`

**Key Entities:**

```go
type Workflow struct {
    ID          string
    Name        string
    States      map[string]State
    Initial     string
}

type State interface {
    GetName() string
    GetType() StateType
}

// Thread-safe for concurrent access during parallel execution (v0.5.23)
type ExecutionContext struct {
    mu           sync.RWMutex // protects concurrent map access
    WorkflowID   string
    Inputs       map[string]interface{}
    States       map[string]StepState
}

// Thread-safe accessors
func (c *ExecutionContext) GetStepState(name string) (StepState, bool)
func (c *ExecutionContext) SetStepState(name string, state StepState)
func (c *ExecutionContext) GetAllStepStates() map[string]StepState // returns defensive copy
```

**Ports (Interfaces):**

```go
type Repository interface {
    Load(name string) (*Workflow, error)
    List() ([]WorkflowInfo, error)
}

type StateStore interface {
    Save(ctx *ExecutionContext) error
    Load(id string) (*ExecutionContext, error)
}

type Executor interface {
    Execute(ctx context.Context, cmd Command) (Result, error)
}
```

## Application Layer

Orchestrates use cases using domain and ports.

**Location:** `internal/application/`

**Services:**
- `WorkflowService` - Loading, validation, listing
- `ExecutionService` - Execution engine with loop pattern detection helpers
- `ConversationManager` - Multi-turn conversation coordination with state helpers
- `InteractiveExecutor` - Step-by-step execution with extracted result handlers
- `ParallelExecutor` - Concurrent step coordination with branch helpers
- `StateManager` - State persistence
- `TemplateService` - Template resolution with parameter processing helpers

## Infrastructure Layer

Implements domain ports with concrete tech.

**Location:** `internal/infrastructure/`

**Adapters:**
- `repository/` - YAML file loader
- `state/` - JSON state store
- `executor/` - Shell executor
- `store/` - SQLite history (WAL mode for concurrent execution) with nil record validation (v0.5.30)
- `agents/` - AI provider adapters (Claude, Codex, Gemini) with shared helper utilities

## Key Patterns

### Dependency Injection

```go
func NewExecutionService(
    repo ports.Repository,
    store ports.StateStore,
    executor ports.Executor,
) *ExecutionService
```

### State Machine Execution

1. Load initial state
2. Execute state
3. Evaluate transitions
4. Move to next state
5. Repeat until terminal

### Atomic Operations

```go
// Write to temp, then rename (atomic on POSIX)
tmpFile := fmt.Sprintf("%s.%d.%d.tmp", path, os.Getpid(), time.Now().UnixNano())
os.WriteFile(tmpFile, data, 0644)
os.Rename(tmpFile, path)
```

### Parallel Execution

```go
g, ctx := errgroup.WithContext(ctx)
sem := make(chan struct{}, maxConcurrent)

for _, step := range steps {
    g.Go(func() error {
        sem <- struct{}{}
        defer func() { <-sem }()
        return executeStep(ctx, step)
    })
}
return g.Wait()
```

## Build Commands

```bash
make build          # Build to ./bin/awf
make install        # Install to /usr/local/bin
make test           # All tests
make test-unit      # Unit tests
make lint           # golangci-lint (17 linters)
make lint-fix       # Auto-fix linter issues
make fmt            # gofumpt (stricter than gofmt)
make quality        # lint + fmt + vet + test
```

**Details**: [Code Quality Reference](code-quality.md)

## Testing Strategy

- **Domain:** Pure unit tests
- **Application:** Mock ports
- **Infrastructure:** Integration tests
- **Interfaces:** E2E CLI tests
