"""Exercise the lifecycle hook's JSON protocol without either host installed."""

import json
from pathlib import Path
import subprocess
import sys
import unittest


SCRIPT = Path(__file__).with_name("session_context.py")


class SessionContextTests(unittest.TestCase):
    def run_hook(self, payload):
        result = subprocess.run(
            [sys.executable, str(SCRIPT)], input=payload,
            capture_output=True, text=True, check=True,
        )
        self.assertEqual(result.stderr, "")
        return json.loads(result.stdout) if result.stdout else None

    def test_start_and_stop_share_memory_policy(self):
        start = self.run_hook('{"hook_event_name":"SessionStart"}')
        context = start["hookSpecificOutput"]
        self.assertEqual(context["hookEventName"], "SessionStart")
        stop = self.run_hook('{"hook_event_name":"Stop"}')
        self.assertEqual(stop["decision"], "block")
        for text in (context["additionalContext"], stop["reason"]):
            for instruction in (
                "list_memories", "mount it if it exists", "explicit memory",
                "every delegated agent", "do not write ad hoc .pl files",
                "Respect read-only mounts", "is unavailable",
            ):
                with self.subTest(instruction=instruction):
                    self.assertIn(instruction, text)

    def test_continuation_does_not_block_again(self):
        self.assertIsNone(self.run_hook(
            '{"hook_event_name":"Stop","stop_hook_active":true}'
        ))

    def test_irrelevant_or_invalid_events_are_ignored(self):
        for payload in ('{}', '[]', 'null', '', '{',
                        '{"hook_event_name":"PostToolUse"}'):
            with self.subTest(payload=payload):
                self.assertIsNone(self.run_hook(payload))


if __name__ == "__main__":
    unittest.main()
