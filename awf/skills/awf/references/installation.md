# Installation

## Prerequisites

- Go 1.21+
- Make (for building from source)
- [golangci-lint](https://golangci-lint.run/) (optional, for development)

## Quick Install

```bash
go install github.com/awf-project/cli/cmd/awf@latest
```

## From Source

```bash
git clone https://github.com/awf-project/cli.git
cd awf
make build    # Binary at ./bin/awf
make install  # Optional: install to /usr/local/bin
```

## Verify

```bash
awf version
```

## Shell Completion

```bash
# Bash
awf completion bash > /etc/bash_completion.d/awf

# Zsh
awf completion zsh > "${fpath[1]}/_awf"

# Fish
awf completion fish > ~/.config/fish/completions/awf.fish
```

## Dependencies

| Package | Purpose |
|---------|---------|
| `spf13/cobra` | CLI framework |
| `gopkg.in/yaml.v3` | YAML parsing |
| `fatih/color` | Terminal colors |
| `google/uuid` | UUID generation |
| `modernc.org/sqlite` | History storage |
| `expr-lang/expr` | Expression evaluation |
