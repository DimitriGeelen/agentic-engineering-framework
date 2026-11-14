"""T-5008 criterion 3 (ring20-dashboard b2be4058): a review seat may not signal processes by name.
The opencode seat's config denies pkill/killall/kill $(pgrep …) in its bash permission, the Claude
review worker's committed settings deny the same, and the brief says so. (Harness seats also run
in a PID namespace — criterion 1; codex has no per-command rule, so the namespace is its guard.)"""
from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

_HERE = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(_HERE / "lib"))
sys.path.insert(0, str(_HERE))

import verdict_ledger as vl  # noqa: E402

PATTERNS = ("pkill *", "killall *", "kill *$(pgrep*")


def test_opencode_seat_config_denies_signalling_by_name():
    cfg = json.loads(vl.opencode_seat_config("/tmp/seat-x/tmp"))
    bash = cfg["agent"]["plan"]["permission"]["bash"]
    for p in PATTERNS:
        assert bash.get(p) == "deny", (p, bash)
    # the T-4844 SEAT_TMP allowance is still there, unchanged
    ext = cfg["agent"]["plan"]["permission"]["external_directory"]
    assert ext == {"/tmp/seat-x/tmp": "allow", "/tmp/seat-x/tmp/*": "allow"}


def test_opencode_itself_resolves_the_rules_to_deny():
    """Ask the installed opencode, as T-4844 did for the allowance. Without opencode on PATH this
    asserts nothing about opencode and says so (the config test above still holds)."""
    oc = shutil.which("opencode")
    if not oc:
        print("opencode not installed: resolver check not run")
        return
    env = dict(os.environ, OPENCODE_CONFIG_CONTENT=vl.opencode_seat_config("/tmp/seat-x/tmp"))
    r = subprocess.run([oc, "debug", "agent", "plan"], capture_output=True, text=True,
                       timeout=90, env=env, cwd="/tmp")
    out = r.stdout + r.stderr
    for p in PATTERNS:
        i = out.find(f'"pattern": "{p}"')
        assert i >= 0, f"opencode did not load the rule {p!r}"
        assert '"action": "deny"' in out[i:i + 120], f"rule {p!r} not resolved to deny"


def test_the_claude_review_worker_settings_deny_signalling_by_name():
    d = json.loads((_HERE / "policy" / "review-worker-settings.json").read_text())
    deny = d["permissions"]["deny"]
    for rule in ("Bash(pkill:*)", "Bash(killall:*)", "Bash(kill $(pgrep:*)"):
        assert rule in deny, deny
    assert d.get("crossSessionInbound") == "refuse"   # the T-3580 rule is kept


def test_the_seat_brief_tells_the_reviewer_how_to_stop_its_own_server():
    src = (_HERE / "lib" / "reviewer" / "judge_cli.py").read_text()
    assert "Never stop or signal a process you did not start" in src
    assert 'kill \\"$pid\\"' in src
