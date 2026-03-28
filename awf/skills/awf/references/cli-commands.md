# CLI Commands Reference

## Commands Overview

| Command | Description |
|---------|-------------|
| `awf init` | Initialize AWF in directory |
| `awf run <workflow>` | Execute a workflow |
| `awf run <workflow> --help` | Show workflow inputs |
| `awf resume [id]` | Resume interrupted workflow |
| `awf list` | List available workflows |
| `awf status <id>` | Show execution status |
| `awf validate <workflow>` | Validate syntax |
| `awf diagram <workflow>` | Generate workflow visualization |
| `awf history` | Show execution history |
| `awf config show` | Display project config |
| `awf plugin list` | List installed plugins |
| `awf plugin install <owner/repo>` | Install plugin from GitHub Releases |
| `awf plugin update <name>` | Update installed plugin to latest release |
| `awf plugin remove <name>` | Remove installed plugin |
| `awf plugin search <query>` | Search GitHub for AWF plugins |
| `awf plugin enable <name>` | Enable a plugin |
| `awf plugin disable <name>` | Disable a plugin |
| `awf version` | Show version |
| `awf completion <shell>` | Generate autocompletion |

## Global Flags

| Flag | Description |
|------|-------------|
| `--verbose, -v` | Verbose output |
| `--quiet, -q` | Suppress non-error output |
| `--no-color` | Disable colors |
| `--format, -f` | Output format: text, json, table, quiet |
| `--config` | Config file path |
| `--storage` | Storage directory path |
| `--log-level` | Log level: debug, info, warn, error |

## awf init

Initialize AWF in current directory.

```bash
awf init [--force] [--global]
```

| Flag | Description |
|------|-------------|
| `--force` | Overwrite existing files |
| `--global` | Create global prompts and scripts in `$XDG_CONFIG_HOME/awf/` |

Creates:
```
.awf.yaml
.awf/
├── workflows/example.yaml
├── templates/
├── prompts/           # Local prompts
└── scripts/           # Local scripts (example.sh included)
```

State storage uses XDG paths: `$XDG_STATE_HOME/awf/` (~/.local/state/awf/)

With `--global`:
```
$XDG_CONFIG_HOME/awf/
├── prompts/           # Global prompts (shared across projects)
└── scripts/           # Global scripts (shared across projects)
```

## awf run

Execute a workflow.

```bash
awf run <workflow> [flags]
awf run <workflow> --help    # Show workflow inputs
```

| Flag | Description |
|------|-------------|
| `--help` | Display workflow inputs and description |
| `--input, -i` | Input (key=value), repeatable |
| `--output, -o` | Output mode: silent, streaming, buffered |
| `--step, -s` | Execute single step |
| `--mock, -m` | Mock state values (key=value) |
| `--dry-run` | Preview without executing |
| `--interactive` | Step-by-step mode |
| `--breakpoint, -b` | Pause at specific steps |

### Interactive Input Collection

When required inputs are missing and stdin is connected to a terminal, AWF prompts for values:

```bash
awf run deploy
# env (string, required):
# > prod
#
# version (string, required):
# > 1.2.3
```

**Behavior (v0.6.18):**
- **Terminal**: Prompts interactively, with config file values pre-filling inputs
- **Non-terminal** (pipes, scripts, CI/CD): Returns error requiring `--input` flags
- **All inputs provided**: Executes immediately without prompts
- **Config integration**: `.awf/config.yaml` values reduce prompts in `--interactive` and `--dry-run` modes

**Enum inputs** display numbered options:

```bash
# env (string, required):
# Options:
#   1. dev
#   2. staging
#   3. prod
# Select (1-3): 2
```

**Optional inputs** can be skipped by pressing Enter:

```bash
# timeout (integer, optional, default: 300):
# >
# Using default: 300
```

**Details**: [Interactive Input Collection](interactive-inputs.md)

### Workflow Help

```bash
awf run deploy --help
```

Displays:
- Workflow description
- Input parameters (name, type, required/optional, defaults)

**Examples:**

```bash
# Basic
awf run deploy

# With inputs
awf run deploy -i env=prod -i version=1.2.3

# Streaming output
awf run deploy -o streaming

# Dry run
awf run deploy --dry-run

# Interactive
awf run deploy --interactive

# Breakpoints
awf run deploy --interactive -b build,deploy

# Single step with mock
awf run deploy -s deploy_step -m states.build.output="v1.2.3"
```

**Interactive Mode Actions:**

| Key | Action |
|-----|--------|
| `c` | Continue - execute step |
| `s` | Skip - skip step |
| `a` | Abort - stop workflow |
| `i` | Inspect - show details |
| `e` | Edit - modify parameters |
| `r` | Retry - retry last step |

## awf resume

Resume interrupted workflow.

```bash
awf resume [workflow-id] [flags]
```

| Flag | Description |
|------|-------------|
| `--list, -l` | List resumable workflows |
| `--input, -i` | Override input on resume |
| `--output, -o` | Output mode |

```bash
# List resumable
awf resume --list

# Resume specific
awf resume abc123-def456

# Resume with override
awf resume abc123 -i max_tokens=5000
```

## awf list

List available workflows.

```bash
awf list [-f json|table]
```

## awf status

Show execution status.

```bash
awf status <workflow-id> [-f json]
```

## awf validate

Validate workflow syntax.

```bash
awf validate <workflow> [-v]
```

**Validates:**
- YAML syntax
- State references
- Transition graph (cycles, unreachable)
- Terminal states
- Template references
- Input definitions
- Parallel strategies
- Operations from disabled plugins (emits actionable warnings, not errors)

## awf diagram

Generate DOT format workflow visualizations.

```bash
awf diagram <workflow> [flags]
```

| Flag | Description |
|------|-------------|
| `--output, -o` | Output file (default: stdout). Extension determines format |
| `--direction, -d` | Graph direction: TB, LR, BT, RL (default: TB) |
| `--highlight` | Comma-separated steps to highlight |

**Output formats:**
- `.dot` - Raw DOT format
- `.png` - PNG image (requires Graphviz)
- `.svg` - SVG image (requires Graphviz)
- `.pdf` - PDF document (requires Graphviz)

**Node shapes:**
- Ellipse: terminal states
- Box: step states
- Diamond: parallel states

**Edge styles:**
- Solid: success transitions
- Dashed: failure transitions

**Examples:**

```bash
# Print DOT to stdout
awf diagram deploy

# Export to PNG
awf diagram deploy -o workflow.png

# Left-to-right layout with highlighted steps
awf diagram deploy -d LR --highlight build,test

# Export to SVG
awf diagram deploy -o workflow.svg
```

**Graphviz requirement:**
Image export (PNG/SVG/PDF) requires the `dot` command from Graphviz:

```bash
# Debian/Ubuntu
sudo apt install graphviz

# macOS
brew install graphviz

# Verify installation
dot -V
```

## awf history

Show execution history.

```bash
awf history [flags]
```

| Flag | Description |
|------|-------------|
| `--workflow, -w` | Filter by workflow |
| `--status, -s` | Filter: success, failed, interrupted |
| `--since` | Since date (YYYY-MM-DD) |
| `--limit, -n` | Max entries (default: 20) |
| `--stats` | Statistics only |

```bash
# Recent
awf history

# Filter
awf history -w deploy -s failed --since 2025-12-01

# Stats
awf history --stats
```

## awf config

Manage project configuration.

```bash
awf config show [-f text|json|quiet]
```

Displays contents of `.awf/config.yaml` with current input defaults.

```bash
# Text output (default)
awf config show

# JSON for scripting
awf config show -f json
```

## awf plugin

Manage AWF plugins.

```bash
awf plugin list                          # List all plugins (built-in + external)
awf plugin list --operations             # List operations per plugin
awf plugin install <owner/repo>          # Install plugin from GitHub Releases
awf plugin update <name>                 # Update installed plugin to latest release
awf plugin remove <name>                 # Remove installed plugin
awf plugin search <query>                # Search GitHub for AWF plugins
awf plugin enable <plugin-name>          # Enable a plugin
awf plugin disable <plugin-name>         # Disable a plugin
```

**Plugin location:** `$XDG_DATA_HOME/awf/plugins/` (~/.local/share/awf/plugins/)

Built-in providers (`github`, `http`, `notify`) are listed with `TYPE=builtin`. External plugins show `TYPE=external`. The `SOURCE` column shows the GitHub `owner/repo` for installed plugins. Disabling any plugin gates its operations at both `awf validate` and `awf run` time.

```bash
# List plugins
awf plugin list
# Output:
# NAME               TYPE      VERSION  STATUS   ENABLED  CAPABILITIES  SOURCE
# github             builtin   v0.4.0   builtin  yes      operations
# http               builtin   v0.4.0   builtin  yes      operations
# notify             builtin   v0.4.0   builtin  yes      operations
# awf-plugin-slack   external  1.0.0    running  yes      operations    myorg/awf-plugin-slack

# List operations per plugin
awf plugin list --operations
# github: get_issue, get_pr, create_issue, create_pr, add_labels, add_comment, list_comments, batch
# notify: send

# Install from GitHub Releases
awf plugin install myorg/awf-plugin-slack
awf plugin install myorg/awf-plugin-slack@v1.2.0   # pin version
awf plugin install myorg/awf-plugin-slack --force   # reinstall

# Update to latest release
awf plugin update awf-plugin-slack

# Remove plugin
awf plugin remove awf-plugin-slack
awf plugin remove awf-plugin-slack --keep-data   # preserve plugin state

# Search GitHub
awf plugin search slack

# Enable / disable
awf plugin enable awf-plugin-slack
awf plugin disable awf-plugin-slack
awf plugin disable notify   # also works for built-ins
```

### awf plugin install flags

| Flag | Description |
|------|-------------|
| `@<version>` | Pin to a specific release tag (e.g. `owner/repo@v1.2.0`) |
| `--force` | Reinstall even if already installed |

Downloads the platform-matched binary from GitHub Releases, verifies SHA-256 checksum against the release manifest, and atomically installs via temp-file rename. Requires `gh` CLI or `GITHUB_TOKEN` for private repositories.

### awf plugin remove flags

| Flag | Description |
|------|-------------|
| `--keep-data` | Remove binary but preserve plugin state |

### awf plugin update

Fetches the latest release from the stored `SOURCE` repository and atomically replaces the binary. Requires the plugin to have been installed via `awf plugin install`.

## awf completion

Generate shell autocompletion.

```bash
# Bash
awf completion bash > /etc/bash_completion.d/awf

# Zsh
awf completion zsh > "${fpath[1]}/_awf"

# Fish
awf completion fish > ~/.config/fish/completions/awf.fish
```

## Output Formats

| Format | Use |
|--------|-----|
| `text` | Interactive terminal (default) |
| `json` | Scripting, CI/CD |
| `table` | Reports |
| `quiet` | Pipelines (IDs only) |

```bash
# JSON for scripting
awf list -f json
awf status abc123 -f json

# Quiet for pipes
WORKFLOW_ID=$(awf run deploy -f quiet)
```
