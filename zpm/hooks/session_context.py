"""Provide ZPM lifecycle context for Claude Code and Codex command hooks."""

import json
import sys


def main():
    try:
        event = json.load(sys.stdin)
    except (ValueError, OSError):
        return
    if not isinstance(event, dict):
        return

    if event.get("hook_event_name") == "SessionStart":
        print(json.dumps({
            "hookSpecificOutput": {
                "hookEventName": "SessionStart",
                "additionalContext": (
                    "The ZPM plugin provides a Prolog knowledge MCP server. "
                    "When its tools are available, use get_persistence_status to "
                    "check health and get_knowledge_schema to inspect existing "
                    "knowledge. Use the tool names exposed by this runtime. "
                    "If the server is unavailable, continue the user's task."
                ),
            },
        }))
    elif event.get("hook_event_name") == "Stop" and not event.get("stop_hook_active"):
        # Both hosts mark the continuation so this reminder cannot loop.
        print(json.dumps({
            "decision": "block",
            "reason": (
                "Consider whether this turn produced useful project discoveries "
                "to persist with the available ZPM tools. Store only relevant "
                "new knowledge, and save a snapshot if useful. If nothing needs "
                "storing or ZPM is unavailable, finish without further action."
            ),
        }))


if __name__ == "__main__":
    main()
