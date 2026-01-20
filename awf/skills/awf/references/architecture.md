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
│   │   │   └── template_validation.go  # Template validation with BFS helpers
│   │   ├── operation/           # Operation interface
│   │   └── ports/               # Repository, StateStore, Executor
│   ├── application/             # Services
│   │   ├── workflow_service.go  # Loading/validation
│   │   ├── execution_service.go # Execution engine with loop pattern helpers
│   │   ├── execution_service_*_test.go  # Thematic test files (v0.5.21)
│   │   ├── conversation_manager.go  # Multi-turn conversation coordination
│   │   ├── interactive_executor.go  # Step execution with result handlers
│   │   ├── parallel_executor.go     # Parallel step coordination
│   │   ├── state_manager.go     # State persistence
│   │   └── template_service.go  # Template resolution with param helpers
│   ├── testutil/                # Test infrastructure (v0.5.22)
│   │   ├── assertions.go        # Custom assertions with detailed failure messages
│   │   ├── builders.go          # Fluent builders for Workflow, Step, State
│   │   ├── fixtures.go          # Reusable test fixtures and factories
│   │   ├── mocks.go             # Thread-safe mocks with sync.RWMutex
│   │   └── doc.go               # Package documentation and examples
│   ├── infrastructure/          # Adapters
│   │   ├── repository/yaml.go   # YAML file loader
│   │   ├── state/json.go        # JSON state store
│   │   ├── executor/shell.go    # Shell executor
│   │   ├── store/sqlite.go      # History storage
│   │   ├── logger/              # Logging utilities (v0.5.24)
│   │   │   └── masker.go        # Secret masking in logs/errors
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
│       ├── list.go              # List command with prompt helpers
│       └── list_helpers_test.go # List helper unit tests
├── pkg/                         # Public packages
│   ├── interpolation/           # Variable substitution
│   ├── validation/              # Input validation
│   ├── retry/                   # Backoff strategies
│   └── plugin/sdk/              # Plugin SDK for third-party plugins
├── tests/                       # Integration tests
│   ├── integration/             # E2E tests
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
- `store/` - SQLite history (WAL mode for concurrent execution)
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
