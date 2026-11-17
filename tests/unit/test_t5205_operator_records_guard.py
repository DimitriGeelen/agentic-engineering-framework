"""T-5205: --help on operator verbs passes the Bash text gate; the operator-only records
(accepted misses, the subscription registry and its change log) are guarded against agent
Write/Edit and Bash writes."""
from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path

import pytest

FW = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(FW))
from lib import shell_write_scan as sws  # noqa: E402

HOOK = FW / "agents" / "context" / "check-human-ac-tick.py"


@pytest.mark.parametrize("cmd", [
    "python3 lib/human_ac_ticks.py delegation widen --help",
    "python3 .agentic-framework/lib/human_ac_ticks.py delegation grant -h",
    "python3 lib/human_ac_ticks.py delegation revoke --help",
    "python3 lib/accepted_miss.py accept --help",
    "bin/fw task accept-miss --help",
    "bin/fw quota subscription add --help",
    "python3 lib/subscriptions.py assign --help",
])
def test_help_on_operator_verbs_passes(cmd):
    assert not sws.scan(cmd, cwd=str(FW), project_root=str(FW)), cmd


@pytest.mark.parametrize("cmd", [
    "python3 lib/human_ac_ticks.py delegation widen --help --class act-in-the-world",
    "python3 lib/human_ac_ticks.py delegation widen --class act-in-the-world --ruling R",
    "python3 lib/accepted_miss.py accept T-1 --ac 2 --reason x --help",
    "bin/fw task accept-miss T-1 --ac 2 --reason x",
    "bin/fw quota subscription add claude-a --harness claude --help",
    "python3 lib/subscriptions.py assign claude-a --kind claude",
])
def test_operator_verbs_with_real_arguments_are_still_refused(cmd):
    assert sws.scan(cmd, cwd=str(FW), project_root=str(FW)), cmd


@pytest.mark.parametrize("cmd", [
    "echo '{}' >> .context/reviews/accepted-misses.jsonl",
    "echo '{}' >> .context/costs/subscription-changes.jsonl",
    "sed -i 's/a/b/' policy/subscriptions.yaml",
    "tee policy/subscriptions.yaml < x.yaml",
])
def test_bash_writes_to_operator_records_are_refused(cmd):
    assert sws.scan(cmd, cwd=str(FW), project_root=str(FW)), cmd


def _hook(tool: str, path: str, agent: bool = True) -> int:
    env = {k: v for k, v in os.environ.items()
           if k not in ("CLAUDECODE", "AI_AGENT", "FW_ALLOW_HUMAN_AC_TICK")}
    if agent:
        env["CLAUDECODE"] = "1"
    env["PROJECT_ROOT"] = str(FW)
    payload = {"tool_name": tool, "tool_input": {"file_path": path, "old_string": "a",
                                                  "new_string": "b", "content": "x"}}
    return subprocess.run([sys.executable, str(HOOK)], input=json.dumps(payload), text=True,
                          capture_output=True, env=env, timeout=60).returncode


@pytest.mark.parametrize("path", [
    "/opt/x/.context/reviews/accepted-misses.jsonl",
    "/opt/x/.context/costs/subscription-changes.jsonl",
    "/opt/x/policy/subscriptions.yaml",
    "policy/subscriptions.yaml",
])
@pytest.mark.parametrize("tool", ["Edit", "Write"])
def test_agent_edit_or_write_to_operator_records_is_blocked(path, tool):
    assert _hook(tool, path) == 2


def test_unrelated_policy_file_and_operator_are_not_blocked():
    assert _hook("Edit", "/opt/x/policy/review-backends.yaml") == 0
    assert _hook("Edit", "/opt/x/policy/subscriptions.yaml", agent=False) == 0
