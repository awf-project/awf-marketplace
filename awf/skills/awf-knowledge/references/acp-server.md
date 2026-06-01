# ACP Server Reference

`awf acp-serve` starts a transparent ACP (Agent Communication Protocol) server over stdio. External agents (Claude Desktop, IDEs) discover and execute AWF workflows as JSON-RPC 2.0 slash commands without modifying workflow definitions.

## Starting the Server

```bash
awf acp-serve
```

The server reads from stdin and writes to stdout. Terminate with SIGINT/SIGTERM or by closing stdin.

```bash
# Smoke-test: create a session and list slash commands
echo '{"jsonrpc":"2.0","id":1,"method":"session/new","params":{}}' | awf acp-serve
```

## Session Protocol

### Create Session

Send `session/new` to open a session. The response lists all discoverable workflows as slash commands.

```json
{"jsonrpc":"2.0","id":1,"method":"session/new","params":{}}
```

**Response — 200 OK:**

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "session_id": "550e8400-e29b-41d4-a716-446655440000",
    "tools": [
      {"name": "/local__deploy", "description": "Deploy to environment"},
      {"name": "/speckit__specify", "description": "Generate API specification"}
    ]
  }
}
```

### Execute a Slash Command

```json
{
  "jsonrpc": "2.0",
  "id": 2,
  "method": "tools/call",
  "params": {
    "name": "/speckit__specify",
    "arguments": {"target": "my-api"}
  }
}
```

### Multi-Turn Parking

When a workflow parks (requires user input mid-run), the response signals the client:

```json
{
  "jsonrpc": "2.0",
  "id": 2,
  "result": {
    "parked": true,
    "prompt": "What aspect of the API should I focus on?",
    "session_id": "550e8400-e29b-41d4-a716-446655440000"
  }
}
```

Resume by sending a continuation turn:

```json
{
  "jsonrpc": "2.0",
  "id": 3,
  "method": "tools/call",
  "params": {
    "name": "/session/continue",
    "arguments": {
      "session_id": "550e8400-e29b-41d4-a716-446655440000",
      "input": "Focus on authentication endpoints"
    }
  }
}
```

## Slash Command Name Encoding

Pack and workflow names use slash-safe encoding: `/` and `.` are replaced with `__`.

| Workflow | Slash Command |
|----------|---------------|
| Local `deploy` | `/local__deploy` |
| Pack `speckit/specify` | `/speckit__specify` |
| `my.pack/my.workflow` | `/my__pack__my__workflow` |

Decode for `awf run`: strip the leading `/` and replace `__` with `/`.

```bash
# Decode /speckit__specify → awf run speckit/specify
awf run $(echo "speckit__specify" | tr '__' '/')
```

## Claude Desktop Integration

Add to Claude Desktop configuration:

```json
{
  "acpServers": {
    "awf": {
      "command": "awf",
      "args": ["acp-serve"]
    }
  }
}
```

After connecting, type `/` in Claude Desktop to see all AWF workflows as slash commands.

## ACP Error Codes

| Code | JSON-RPC Meaning |
|------|-----------------|
| `ACP.SESSION_NOT_FOUND` | Session ID does not exist or has expired |
| `ACP.WORKFLOW_NOT_FOUND` | Slash command targets a workflow not in the catalog |
| `ACP.INVALID_COMMAND` | Slash command name failed name-encoding validation |

## ACP vs MCP vs REST

| Feature | `awf acp-serve` | `awf mcp serve` | `awf serve` |
|---------|-----------------|-----------------|--------------|
| Protocol | ACP / JSON-RPC 2.0 | MCP / JSON-RPC 2.0 | HTTP REST |
| Transport | stdio | stdio | TCP |
| Workflow execution | Yes (slash commands) | No (plugin ops only) | Yes |
| Multi-turn parking | Yes | No | Partial (resume API) |
| Discovery | Slash commands | MCP tools | REST endpoints |
| Target clients | Claude Desktop, IDEs | Claude Code, Gemini | External systems |

**Details**: [CLI Commands - awf acp-serve](cli-commands.md#awf-acp-serve) | [MCP Proxy Reference](mcp-proxy.md) | [HTTP REST API Reference](api.md)
