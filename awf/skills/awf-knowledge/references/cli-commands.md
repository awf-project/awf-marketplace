# CLI Commands Reference

## Commands Overview

| Command | Description |
|---------|-------------|
| `awf init` | Initialize AWF in directory |
| `awf run <workflow>` | Execute a workflow |
| `awf run <pack>/<workflow>` | Execute workflow from installed pack |
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
| `awf workflow install <owner/repo>` | Install workflow pack from GitHub Releases |
| `awf workflow list` | List installed workflow packs |
| `awf workflow info <name>` | Show pack manifest, plugin status, and README |
| `awf workflow update <name>` | Update installed workflow pack to latest release |
| `awf workflow search <query>` | Search GitHub for AWF workflow packs |
| `awf workflow remove <name>` | Remove installed workflow pack |
| `awf version` | Show version |
| `awf completion <shell>` | Generate autocompletion |
| `awf upgrade` | Self-update the AWF binary from GitHub Releases |
| `awf upgrade --check` | Check for a newer version without installing |

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

Execute a workflow or a workflow from an installed pack.

```bash
awf run <workflow> [flags]
awf run <pack>/<workflow> [flags]    # Run workflow from installed pack
awf run <workflow> --help            # Show workflow inputs
```

### Running Pack Workflows

Use `<pack>/<workflow>` syntax to execute workflows from installed packs without path juggling:

```bash
# Install pack first
awf workflow install myorg/speckit

# Run workflow from pack
awf run speckit/specify --input file=main.go
```

**Pack resolution order** (for `{{.awf.prompts_dir}}` and `{{.awf.scripts_dir}}` inside a pack workflow):
1. `.awf/prompts/<pack-name>/` — local user override (project-level)
2. Pack's embedded `prompts/` directory — pack-provided default
3. `$XDG_CONFIG_HOME/awf/prompts/` — global XDG fallback

Place a file at `.awf/prompts/<pack>/override.md` to override any pack-embedded prompt without modifying the pack.

| Flag | Description |
|------|-------------|
| `--help` | Display workflow inputs and description |
| `--input, -i` | Input (key=value), repeatable |
| `--output, -o` | Output mode: silent, streaming, buffered (see below) |
| `--step, -s` | Execute single step |
| `--mock, -m` | Mock state values (key=value) |
| `--dry-run` | Preview without executing |
| `--interactive` | Step-by-step mode |
| `--breakpoint, -b` | Pause at specific steps |
| `--skip-plugins` | Skip loading and executing plugins |
| `--validator-timeout` | Timeout for validator plugins (e.g. `30s`) |
| `--otel-exporter` | OTLP gRPC endpoint for distributed tracing (overrides `telemetry.exporter` in config) |
| `--otel-service-name` | Service name for traces (overrides `telemetry.service_name` in config) |

### Output Mode (`--output`)

| Mode | Behavior |
|------|----------|
| `streaming` | Streams step output to terminal as it runs. For agent steps, display depends on `output_format` (see below). |
| `buffered` | Collects step output and writes it at completion. Same agent-step display filtering as `streaming`. |
| `silent` | Suppresses all terminal output. Post-processing still runs; template variables are still populated. |

**Agent step display filtering with `--output streaming` or `buffered`:**

The `output_format` field on an agent step controls what appears on the terminal:

| `output_format` | Terminal display |
|-----------------|-----------------|
| `text` or omitted | NDJSON filtered to plain text |
| `json` | Raw NDJSON passed through |

`--output silent` suppresses agent output regardless of `output_format`. Template interpolation (e.g. `{{.states.step.Output}}`) is unaffected by the output mode — `state.Output` always contains the full agent response.

**Details**: [Agent Steps - Streaming Output Display](agent-steps.md#streaming-output-display)

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

# Pack workflow
awf run speckit/specify --input file=main.go

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

List available workflows — local and from installed packs.

```bash
awf list [-f json|table]
```

Output includes:
- Local workflows from `.awf/workflows/` (labeled `(local)`)
- Pack workflows listed as `pack/workflow` with `SOURCE=pack`

```bash
awf list
# NAME                   SOURCE
# hello                  (local)
# speckit/specify        pack
# speckit/review         pack
```

## awf status

Show execution status.

```bash
awf status <workflow-id> [-f json]
```

## awf validate

Validate workflow syntax.

```bash
awf validate <workflow> [-v] [--skip-plugins]
```

| Flag | Description |
|------|-------------|
| `--skip-plugins` | Skip validator plugins during validation |

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

Execution IDs are displayed in full (36-character UUIDs) and workflow names are never truncated. Columns auto-size to fit the content. Copy an ID directly from the output to use with `awf status` or `awf resume`.

```bash
# Recent
awf history
# ID                                    WORKFLOW  STATUS   STARTED              DURATION
# 550e8400-e29b-41d4-a716-446655440000  deploy    success  2025-12-01 10:05:00  4.2s
# 3f9a1c2d-0e4b-47f8-b123-9d8e7c6b5a4f  deploy    failed   2025-11-30 18:42:11  1.1s

# Filter
awf history -w deploy -s failed --since 2025-12-01

# Stats
awf history --stats

# Use a full ID from history output directly
awf status 550e8400-e29b-41d4-a716-446655440000
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
awf plugin list --step-types             # Show STEP TYPES capability column
awf plugin list --validators             # Show VALIDATORS capability column
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
# NAME                        TYPE      VERSION  STATUS   ENABLED  CAPABILITIES  SOURCE
# github                      builtin   v0.4.0   builtin  yes      operations
# http                        builtin   v0.4.0   builtin  yes      operations
# notify                      builtin   v0.4.0   builtin  yes      operations
# awf-plugin-slack            external  1.0.0    running  yes      operations    myorg/awf-plugin-slack
# awf-plugin-database         external  1.0.0    running  yes      step_types    myorg/awf-plugin-database
# awf-plugin-security-valid   external  1.2.0    running  yes      validators    myorg/awf-plugin-security-validator

# List operations per plugin
awf plugin list --operations
# github: get_issue, get_pr, create_issue, create_pr, add_labels, add_comment, list_comments, batch
# notify: send

# Show step-type and validator capability details
awf plugin list --step-types --validators
# NAME                      STEP TYPES   VALIDATORS
# awf-plugin-database       sql_query    -
# awf-plugin-security-val   -            secrets,commands

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

## awf workflow

Manage workflow packs.

```bash
awf workflow install <owner/repo>    # Install workflow pack from GitHub Releases
awf workflow install <owner/repo>@<version>  # Pin to specific version
awf workflow list                    # List installed packs
awf workflow info <name>             # Show pack details
awf workflow update <name>           # Update pack to latest release
awf workflow update --all            # Update all installed packs
awf workflow search <query>          # Search GitHub for AWF workflow packs
awf workflow remove <name>           # Remove installed workflow pack
```

**Pack location:** `$XDG_DATA_HOME/awf/workflow-packs/` (~/.local/share/awf/workflow-packs/)

A workflow pack is a GitHub Release tarball containing an `awf-pack.yaml` manifest and workflow YAML files. AWF downloads the tarball, verifies the SHA-256 checksum, validates the manifest, and atomically installs the pack.

### awf workflow install

```bash
awf workflow install <owner/repo>            # install latest release
awf workflow install <owner/repo>@v1.2.0     # pin to specific release tag
```

| Flag | Description |
|------|-------------|
| `@<version>` | Pin to a specific release tag (e.g. `owner/repo@v1.2.0`) |

**Behavior:**
- Downloads and verifies SHA-256 checksum against the release manifest
- Validates `awf-pack.yaml` including CLI version constraints
- Warns if the pack declares plugin dependencies not currently installed
- Substitutes `dev` CLI version with `0.5.0` for constraint evaluation
- Enforces 1MB size limit on manifest reads (OOM protection)

```bash
awf workflow install myorg/my-workflows
awf workflow install myorg/my-workflows@v2.0.0
```

### awf workflow list

```bash
awf workflow list
```

Lists all installed workflow packs with name, version, source URL, and included workflow names.

```bash
awf workflow list
# NAME          VERSION  SOURCE                     WORKFLOWS
# speckit       1.2.0    myorg/speckit              specify, review
# my-workflows  2.0.0    myorg/my-workflows         deploy, release
```

Also shows a `(local)` entry when `.awf/workflows/` contains workflow files.

### awf workflow info

```bash
awf workflow info <name>
```

Shows manifest details for an installed pack: name, version, source, CLI version constraints, plugin dependencies (with install status and actionable install commands), included workflows, and the pack's embedded README.

```bash
awf workflow info speckit
# Name:     speckit
# Version:  1.2.0
# Source:   myorg/speckit
# Requires: awf >= 0.6.0
# Plugins:
#   awf-plugin-github  [installed]
#   awf-plugin-db      [not installed] -> run: awf plugin install myorg/awf-plugin-db
# Workflows:
#   specify, review
```

### awf workflow update

```bash
awf workflow update <name>     # Update named pack to latest release
awf workflow update --all      # Update all installed packs
```

Fetches the latest release from the stored source repository, verifies the checksum, and atomically replaces the pack. Updates `state.json` with the new version and `updated_at` timestamp.

| Flag | Description |
|------|-------------|
| `--all` | Update every installed pack; mutually exclusive with `<name>` |

```bash
awf workflow update speckit
awf workflow update --all
```

### awf workflow search

```bash
awf workflow search [<query>]
```

Searches GitHub for repositories tagged `awf-workflow`. Optional keyword narrows results. Search queries are URL-encoded automatically.

```bash
awf workflow search              # list all awf-workflow repos
awf workflow search speckit      # filter by keyword
```

### awf workflow remove

```bash
awf workflow remove <name>
```

Removes the named workflow pack directory from `$XDG_DATA_HOME/awf/workflow-packs/`.

```bash
awf workflow remove my-workflows
```

### awf-pack.yaml manifest

Each workflow pack contains an `awf-pack.yaml` manifest:

```yaml
name: my-workflows
version: "1.0.0"
min_cli_version: "0.6.0"    # optional, semver constraint
max_cli_version: "1.0.0"    # optional
plugins:                     # optional, warns if not installed
  - awf-plugin-database
workflows:
  - deploy.yaml
  - release.yaml
```

| Field | Required | Description |
|-------|----------|-------------|
| `name` | yes | Pack identifier used for install/remove |
| `version` | yes | Pack version |
| `min_cli_version` | no | Minimum AWF CLI version required |
| `max_cli_version` | no | Maximum AWF CLI version supported |
| `plugins` | no | Plugin dependencies (installation warnings only) |
| `workflows` | yes | List of workflow YAML files included in the pack |

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

## awf upgrade

Self-update the AWF binary from GitHub Releases.

```bash
awf upgrade [flags]
```

| Flag | Description |
|------|-------------|
| `--check` | Check for a newer version without downloading |
| `--force` | Download and install even if already on the latest version |
| `--version <tag>` | Install a specific release tag (e.g. `v0.6.33`) |

```bash
# Upgrade to the latest release
awf upgrade

# Check for a newer version without installing
awf upgrade --check

# Install a specific version
awf upgrade --version v0.6.20

# Force reinstall (bypass package manager detection)
awf upgrade --force
```

Set `GITHUB_TOKEN` to avoid GitHub API rate limits (shared with `awf plugin install` and `awf workflow install`).

**Details**: [Self-Update Reference](upgrade.md)

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
