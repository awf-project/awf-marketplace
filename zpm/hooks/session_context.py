"""Provide ZPM lifecycle context for Claude Code and Codex command hooks."""

import json
import sys


MEMORY_CONTEXT = (
    "Use one shared ZPM memory segment for the current task or feature. "
    "Honor the memory selected by the user or coordinating agent. Otherwise use "
    "list_memories and inspect existing .zpm/kb/<segment>/ directories to find "
    "the relevant segment; mount it if it exists but is not mounted. Create and "
    "mount a project segment only when no suitable segment exists. Do not create "
    "a segment per agent, phase, finding, or date. Pass the selected memory name "
    "to every delegated agent and use the explicit memory parameter on all "
    "knowledge reads, writes, consistency checks, and snapshots. Inspect "
    "get_knowledge_schema in that memory and query existing facts before adding "
    "knowledge. Store findings, decisions, and relationships through ZPM tools; "
    "do not write ad hoc .pl files or discovery reports as a substitute for "
    "shared memory unless the user requests an export or deliverable. Let ZPM "
    "manage knowledge.pl, WALs, and snapshots. Respect read-only mounts; do not "
    "silently fall back to default or a new segment when a write fails."
)


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
                    "check health. Use the tool names exposed by this runtime. "
                    + MEMORY_CONTEXT + " "
                    "If the server is unavailable, continue the user's task "
                    "without generating replacement knowledge files."
                ),
            },
        }))
    elif event.get("hook_event_name") == "Stop" and not event.get("stop_hook_active"):
        # Both hosts mark the continuation so this reminder cannot loop.
        print(json.dumps({
            "decision": "block",
            "reason": (
                "Consider whether this turn produced useful project discoveries "
                "to persist with the available ZPM tools. "
                + MEMORY_CONTEXT + " "
                "Store only relevant new knowledge in the selected memory, "
                "and save a snapshot there only if useful. If nothing needs "
                "storing or ZPM is unavailable, finish without further action."
            ),
        }))


if __name__ == "__main__":
    main()
