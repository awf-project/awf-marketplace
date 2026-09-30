# AWF Marketplace

Plugin marketplace for [AWF CLI](https://github.com/awf-project/cli), [ZPM](https://github.com/awf-project/ZPM), and [Tower](https://github.com/awf-project/tower), compatible with Claude Code and Codex.

## Installation

### Codex

```bash
codex plugin marketplace add awf-project/awf-marketplace
codex plugin add awf@awf-marketplace
codex plugin add zpm@awf-marketplace
codex plugin add tower@awf-marketplace
```

Codex also discovers the repo-scoped marketplace at `.agents/plugins/marketplace.json`.

### Claude Code

```bash
/plugin marketplace add awf-project/awf-marketplace
/plugin install awf@awf-marketplace
/plugin install zpm@awf-marketplace
/plugin install tower@awf-marketplace
```

The Claude commands above run inside a Claude Code session. From a shell, use
`claude plugin marketplace add` and `claude plugin install` instead. Choose the
installation scope in the plugin panel, or pass `--scope project` or
`--scope local` to the shell installation command.

Install only the plugins you need. Adding the marketplace registers the catalog;
installing a plugin loads its components.

### Prerequisites and verification

- AWF workflows require the `awf` executable in `PATH`.
- ZPM requires `zpm` in `PATH`; Tower requires `tower` in `PATH`. The plugins
  configure MCP connections but do not install these binaries.
- ZPM lifecycle hooks require Python 3 (`python3` in `PATH`). In Codex, review
  and trust the installed hooks through `/hooks` before they run.

In Claude Code, use `/mcp` to check the bundled servers and `/plugin` to check
installed plugins. Follow any `/reload-plugins` instruction after installation.
In Codex, use `codex plugin list` and start a new session to verify the installed
skills and MCP connections.

## Plugins

| Plugin | Description |
|--------|-------------|
| `awf` | AWF CLI - skills and agents for Claude; skills for Codex |
| `zpm` | ZPM - skills, agents, hooks and commands for Claude; skills, hooks, and MCP config for Codex |
| `tower` | Tower - workspace skills and MCP configuration for Claude and Codex |

## Author

Alex "pocky" Balmes 

- [alex.balmes.co](https://alex.balmes.co)
- [vanoix.com](https://vanoix.com)

## License

[EUPL-1.2](LICENSE)
