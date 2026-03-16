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
│   WorkflowService │ ExecutionService │ PluginService        │
└───────────────────────────┬─────────────────────────────────┘
                            │
┌───────────────────────────┴─────────────────────────────────┐
│                      DOMAIN LAYER                           │
│   Workflow │ Step │ Plugin │ Ports (Interfaces)             │
└───────────────────────────┬─────────────────────────────────┘
                            │
┌───────────────────────────┴─────────────────────────────────┐
│                  INFRASTRUCTURE LAYER                       │
│  YAMLRepository │ JSONStateStore │ AgentProviders │ GitHub │ Notify │
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
│   │   │   ├── audit_event.go   # AuditEvent model with start/complete constructors (v0.6.7)
│   │   │   ├── domain_test_helpers_test.go  # Shared test utilities (v0.5.26)
│   │   │   ├── agent_config_*_test.go       # Agent config tests (split, v0.5.26)
│   │   │   ├── step_*_test.go               # Step tests by type (v0.5.26)
│   │   │   └── template_validation_*_test.go  # Template tests by namespace (v0.5.26)
│   │   ├── operation/           # Operation interface
│   │   └── ports/               # Repository, StateStore, Executor, ExpressionValidator (v0.5.33), AuditTrailWriter (v0.6.7)
│   ├── application/             # Services (depends on ports only, v0.5.34)
│   │   ├── workflow_service.go  # Loading/validation
│   │   ├── execution_service.go # Execution engine (AgentRegistry interface, v0.5.34)
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
│   │   ├── repository/yaml.go   # YAML file loader with validator injection (v0.5.33)
│   │   ├── expression/          # Expression validation adapter (v0.5.33)
│   │   │   └── expr_validator.go  # expr-lang implementation of ExpressionValidator port
│   │   ├── state/json.go        # JSON state store
│   │   ├── executor/shell.go    # Shell executor
│   │   ├── store/                # Persistence stores (v0.5.30)
│   │   │   ├── sqlite_history_store.go       # SQLite history (WAL mode)
│   │   │   ├── sqlite_history_store_test.go  # SQLite tests (2,082 lines, 43 tests)
│   │   │   ├── json_store.go                 # JSON state store
│   │   │   └── json_store_test.go            # JSON tests (+384 lines, 13 tests)
│   │   ├── audit/               # Audit trail writer (v0.6.7)
│   │   │   ├── file_writer.go   # POSIX atomic JSONL append, 4KB truncation, mutex
│   │   │   └── doc.go           # Package documentation
│   │   ├── logger/              # Logging utilities (v0.5.24)
│   │   │   └── masker.go        # Secret masking in logs/errors (TOKEN pattern added v0.6.7)
│   │   ├── diagram/             # Workflow visualization (v0.5.28)
│   │   │   ├── dot_generator.go              # DOT format generation
│   │   │   ├── diagram_test_helpers_test.go  # Shared test utilities
│   │   │   ├── dot_generator_core_test.go    # Core DOT generation (33 tests)
│   │   │   ├── generator_edges_test.go       # Edge generation (24 tests)
│   │   │   ├── generator_header_test.go      # Header formatting (16 tests)
│   │   │   ├── generator_highlight_test.go   # Syntax highlighting (15 tests)
│   │   │   ├── generator_nodes_test.go       # Node creation (18 tests)
│   │   │   └── generator_parallel_test.go    # Parallel diagram gen (24 tests)
│   │   ├── agents/              # AI provider adapters
│   │   │   ├── registry.go      # AgentRegistry implementation (GetAgents method, v0.5.34)
│   │   │   ├── helpers.go       # Shared utilities (cloneState, estimateTokens)
│   │   │   ├── claude_provider.go
│   │   │   ├── codex_provider.go
│   │   │   ├── gemini_provider.go
│   │   │   ├── openai_compatible_provider.go  # Chat Completions API (v0.6.6)
│   │   │   └── options.go       # Functional options (WithHTTPClient)
│   │   ├── github/              # Built-in GitHub plugin (v0.5.41)
│   │   │   ├── auth.go          # gh CLI auth detection and token retrieval
│   │   │   ├── client.go        # gh CLI wrapper via exec.Command (no shell)
│   │   │   ├── operations.go    # 9 operation schemas with typed input/output
│   │   │   ├── provider.go      # Operation dispatcher with input sanitization
│   │   │   ├── batch.go         # Batch execution with fail_fast/all_succeed strategies
│   │   │   └── doc.go           # Package documentation
│   │   ├── notify/              # Built-in notification plugin (v0.5.43)
│   │   │   ├── types.go         # Backend interface, NotificationPayload, BackendResult
│   │   │   ├── provider.go      # NotifyOperationProvider with dynamic backend registration
│   │   │   ├── operations.go    # notify.send operation schema
│   │   │   ├── desktop.go       # Desktop backend (notify-send / osascript)
│   │   │   ├── ntfy.go          # ntfy backend (HTTP POST)
│   │   │   ├── slack.go         # Slack backend (Block Kit webhook)
│   │   │   ├── webhook.go       # Generic webhook backend (JSON POST)
│   │   │   ├── http.go          # Shared HTTP sender (10s timeout)
│   │   │   └── doc.go           # Package documentation
│   │   └── plugin/              # Plugin manager, composite provider (v0.5.43)
│   │       ├── registry.go      # RPC plugin registry
│   │       └── composite.go     # CompositeOperationProvider (multiplexes GitHub + Notify)
│   └── interfaces/cli/          # Cobra commands
│       ├── ui/                  # UI formatting helpers
│       │   ├── output.go        # Table output, row builders
│       │   ├── dry_run_formatter.go  # Dry-run display formatting
│       │   └── field_formatters_test.go  # Field formatter tests
│       ├── config.go            # Config loading with AWF_PROMPT_PATH support (v0.5.28)
│       ├── list.go              # List command with prompt helpers
│       ├── list_helpers_test.go # List helper unit tests
│       ├── cli_test_helpers_test.go  # Shared CLI test utilities (v0.5.28)
│       ├── migration_coverage_test.go  # Migration notice tests (v0.5.37, 181 lines, 8 tests)
│       ├── run.go               # Main run command implementation
│       ├── run_agent_test.go         # Agent execution tests (14 tests, v0.5.28)
│       ├── run_execution_test.go     # Execution flow tests (9 tests, v0.5.28)
│       ├── run_flags_test.go         # Flag parsing tests (27 tests, v0.5.28)
│       ├── run_interactive_test.go   # Interactive mode tests (2 tests, v0.5.28)
│       ├── validate_coverage_test.go # Validate command unit tests (v0.5.37)
│       ├── resume.go            # Resume command with signal handler (v0.5.29)
│       ├── signal_handler.go    # Shared signal handler preventing goroutine leaks (v0.5.29)
│       └── signal_handler_test.go  # Signal handler cleanup tests (v0.5.29)
├── pkg/                         # Public packages
│   ├── interpolation/           # Variable substitution
│   ├── validation/              # Input validation
│   ├── retry/                   # Backoff strategies
│   └── plugin/sdk/              # Plugin SDK for third-party plugins
├── scripts/                     # Development scripts
│   └── audit-skips.sh           # Test skip categorization audit (v0.5.39, 9 patterns)
├── tests/                       # Integration tests
│   ├── integration/             # E2E tests (use //go:build integration tag)
│   │   ├── test_helpers.go      # Skip helpers (skipOnShortMode, skipInCI, skipIfRootUser, skipOnPlatform)
│   │   ├── test_helpers_skip_test.go  # Skip helper validation (v0.5.39, 431 lines)
│   │   ├── c030_t001_audit_script_test.go  # Audit script tests (v0.5.39, 471 lines)
│   │   ├── input_validation_functional_test.go    # Validation pipeline (v0.5.30)
│   │   └── state_persistence_functional_test.go   # Persistence tests (v0.5.30)
│   ├── fixtures/audit_skips/    # Audit script test fixtures (v0.5.39)
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
import "github.com/awf-project/cli/internal/domain/workflow"

// Application (imports domain only)
import "github.com/awf-project/cli/internal/application"

// Infrastructure (imports domain ports)
import "github.com/awf-project/cli/internal/infrastructure/repository"

// Public packages (safe for external use)
import "github.com/awf-project/cli/pkg/interpolation"
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

// ExpressionValidator validates expression syntax at workflow load time (v0.5.33)
// Extracted from domain to maintain layer purity - expr-lang dependency isolated to infrastructure
type ExpressionValidator interface {
    // ValidateExpression compiles an expression without executing it
    // Returns error if expression has syntax errors
    ValidateExpression(expression string) error
}

// AgentRegistry provides agent providers to execution service (v0.5.34)
// DIP-compliant: application layer depends on interface, not concrete infrastructure type
type AgentRegistry interface {
    // Get returns agent provider by name
    Get(name string) (AgentProvider, bool)
    // Register adds an agent provider
    Register(name string, provider AgentProvider)
    // GetAgents returns all registered agent names (v0.5.34)
    GetAgents() []string
}

// AuditTrailWriter defines the contract for appending audit trail entries (v0.6.7)
type AuditTrailWriter interface {
    Write(ctx context.Context, event *workflow.AuditEvent) error
    Close() error
}
```

## Application Layer

Orchestrates use cases using domain and ports.

**Location:** `internal/application/`

**Services:**
- `WorkflowService` - Loading, validation, listing
- `ExecutionService` - Execution engine with loop pattern detection helpers and optional audit trail
- `ConversationManager` - Multi-turn conversation coordination with state helpers
- `InteractiveExecutor` - Step-by-step execution with extracted result handlers
- `ParallelExecutor` - Concurrent step coordination with branch helpers
- `StateManager` - State persistence
- `TemplateService` - Template resolution with parameter processing helpers

## Infrastructure Layer

Implements domain ports with concrete tech.

**Location:** `internal/infrastructure/`

**Adapters:**
- `repository/` - YAML file loader with validator injection (v0.5.33)
- `expression/` - Expression validation using expr-lang (v0.5.33)
- `state/` - JSON state store
- `executor/` - Shell executor
- `store/` - SQLite history (WAL mode for concurrent execution) with nil record validation (v0.5.30)
- `agents/` - AgentRegistry implementation with AI providers (v0.5.34 - implements ports.AgentRegistry interface)
- `audit/` - Audit trail writer with POSIX atomic JSONL append, 4KB entry limit, mutex for thread safety (v0.6.7)
- `github/` - Built-in GitHub plugin with 9 declarative operations, auth detection, batch execution (v0.5.41)
- `notify/` - Built-in notification plugin with 4 backends (desktop, ntfy, slack, webhook), dynamic backend registration (v0.5.43)
- `plugin/` - RPC plugin registry + CompositeOperationProvider that multiplexes GitHub and Notify providers (v0.5.43)

## Key Patterns

### Dependency Injection

```go
// ExecutionService depends on ports interfaces only (DIP-compliant, v0.5.34)
func NewExecutionService(
    repo ports.Repository,
    store ports.StateStore,
    executor ports.Executor,
) *ExecutionService

// AgentRegistry injected via setter (optional dependency)
func (s *ExecutionService) SetAgentRegistry(registry ports.AgentRegistry)

// AuditTrailWriter injected via setter (optional dependency, v0.6.7)
func (s *ExecutionService) SetAuditTrailWriter(writer ports.AuditTrailWriter)
```

### Validator Injection via Function Type (v0.5.33)

Domain entities accept validators through function types to avoid import cycles:

```go
// Domain defines function type (no import of ports package)
type ValidatorFunc func(expression string) error

// Workflow accepts validator at validation time
func (w *Workflow) Validate(validator ValidatorFunc) error

// Infrastructure creates adapter and injects it
validator := expression.NewExprValidator()
workflow.Validate(validator.ValidateExpression)
```

This pattern maintains domain purity while enabling compile-time expression validation.

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
make test-integration  # Integration tests (tests/integration/)
make test-external  # Tests requiring external CLI tools (v0.5.39)
make lint           # golangci-lint (17 linters)
make lint-fix       # Auto-fix linter issues
make format         # gofumpt (stricter than gofmt)
make quality        # lint + fmt + vet + test
```

**Details**: [Code Quality Reference](code-quality.md)

## Testing Strategy

- **Domain:** Pure unit tests
- **Application:** Mock ports
- **Infrastructure:** Integration tests
- **Interfaces:** E2E CLI tests (>80% coverage since v0.5.37)
- **Skip Management:** Build tags and standardized helpers (v0.5.39, 84% skip reduction)
