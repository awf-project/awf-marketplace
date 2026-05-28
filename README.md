# AWF Marketplace

Plugin marketplace for AWF CLI https://github.com/awf-project/cli and [ZPM](https://github.com/awf-project/ZPM), compatible with Claude Code and Codex.

## Installation

### Codex

```bash
codex plugin marketplace add awf-project/awf-marketplace
```

Codex also discovers the repo-scoped marketplace at `.agents/plugins/marketplace.json`.

### Claude Code

```bash
/plugin marketplace add awf-project/awf-marketplace
```

## Plugins

| Plugin | Description |
|--------|-------------|
| `awf` | AWF CLI - skills, agents, and commands for Claude; skills for Codex |
| `zpm` | ZPM - skills, agents, hooks and commands for Claude; skills, hooks, and MCP config for Codex |

## Author

Alex "pocky" Balmes 

- [alex.balmes.co](https://alex.balmes.co)
- [vanoix.com](https://vanoix.com)
- [akawaka.fr](https://akawaka.fr)

## License

[EUPL-1.2](LICENSE)
