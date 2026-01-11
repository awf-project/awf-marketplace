# Code Quality

AWF uses golangci-lint v2 as a single aggregator for 17 specialized linters. Configuration follows late-2025 Go best practices.

## Quick Reference

```bash
make lint           # Run all 17 linters
make lint-fix       # Auto-fix issues
make fmt            # Format with gofumpt
make quality        # lint + fmt + vet + test
```

## Linter Categories

| Category | Linters | Purpose |
|----------|---------|---------|
| Core quality | errcheck, govet, staticcheck, ineffassign, unused | Bug detection |
| Readability | misspell, revive | Clear, maintainable code |
| Error handling | errorlint | Proper `%w` wrapping |
| Security | gosec | Vulnerability detection |
| Architecture | depguard | Hexagonal layer constraints |
| Modern Go | gocognit, gocritic, exhaustive, noctx, prealloc, wrapcheck | Late-2025 patterns |

## Common Issues

### Cognitive Complexity (gocognit)

**Threshold**: 15 (stricter than default 30)

```go
// Before (complexity 18) - too much nesting
func Validate(w *Workflow) error {
    if w.Name == "" {
        return errors.New("name required")
    } else {
        if len(w.States) == 0 {
            // ...nested logic
        }
    }
}

// After (complexity 8) - early returns + helpers
func Validate(w *Workflow) error {
    if w.Name == "" {
        return errors.New("name required")
    }
    if len(w.States) == 0 {
        return errors.New("states required")
    }
    return validateStates(w.States)
}
```

**Shared helper extraction**: When multiple implementations share logic, extract to a common helpers file:

```go
// internal/infrastructure/agents/helpers.go
func CloneState(state map[string]interface{}) map[string]interface{} { ... }
func EstimateTokens(text string) int { ... }
func GetStringOption(opts map[string]interface{}, key, def string) string { ... }
```

### Error Wrapping (errorlint)

```go
// Before - breaks error chains
return fmt.Errorf("failed: %v", err)

// After - preserves error chain
return fmt.Errorf("failed: %w", err)
```

### Missing Enum Cases (exhaustive)

```go
// Before - missing cases
switch status {
case StatusRunning:
    return "running"
}

// After - all cases or default
switch status {
case StatusRunning:
    return "running"
case StatusCompleted, StatusFailed:
    return "done"
default:
    return "unknown"
}
```

### HTTP Context (noctx)

```go
// Before - no cancellation support
req, _ := http.NewRequest("GET", url, nil)

// After - includes context
req, _ := http.NewRequestWithContext(ctx, "GET", url, nil)
```

## Architecture Enforcement (depguard)

Domain layer (`internal/domain/`) cannot import:
- `github.com/spf13/cobra` - CLI framework
- `go.uber.org/zap` - Concrete logger
- `github.com/fatih/color` - UI components
- `github.com/schollz/progressbar/v3` - UI components

Use `ports.Logger` interface instead.

## Using //nolint

Use sparingly with explanation:

```go
//nolint:gosec // G204 intentional - shell executor design
cmd := exec.Command("sh", "-c", userCmd)
```

**Good reasons**:
- `G204 intentional - shell executor design`
- `G304 validated - path checked against allowlist`
- `gocognit - Cobra command setup legitimately complex`

**Bad reasons**:
- `TODO fix later`
- `linter is annoying`
- (no comment)

## Formatter

AWF uses gofumpt (stricter than gofmt):

```bash
make fmt   # Run before make lint
```

**gofumpt rules**:
- Groups imports (stdlib, third-party, internal)
- Removes unnecessary blank lines
- Enforces consistent formatting

## CI Integration

GitHub Actions runs same checks:

```yaml
- name: Lint
  uses: golangci/golangci-lint-action@v9
  with:
    version: latest
    args: --timeout=5m
```

**Quality gates**:
1. `make lint` - zero issues
2. `make fmt` - no changes
3. `make test` - all pass

## Pre-Commit Workflow

```bash
# 1. Make changes
vim internal/domain/workflow/workflow.go

# 2. Format code
make fmt

# 3. Check for issues
make lint

# 4. Fix auto-fixable issues
make lint-fix

# 5. Run all quality checks
make quality

# 6. Commit if all checks pass
git commit -m "feat(workflow): add validation"
```
