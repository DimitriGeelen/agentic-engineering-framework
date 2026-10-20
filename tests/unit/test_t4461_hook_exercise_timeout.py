"""T-4461: a hook probe that runs past its budget is undetermined, not a failed resolve.

Origin: dimitri-mint-dev T-160 — one of three `fw doctor` runs on an I/O-bound host
printed `FAIL Hook exercise from /tmp: 1/26 hook(s) failed to resolve`. The probe
counted subprocess.TimeoutExpired as a failure.
"""
import json
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "lib" / "doctor-hook-exercise.py"


def _run(tmp_path, commands):
    claude = tmp_path / ".claude"
    claude.mkdir()
    hooks = [{"hooks": [{"type": "command", "command": c}]} for c in commands]
    (claude / "settings.json").write_text(json.dumps({"hooks": {"PreToolUse": hooks}}))
    r = subprocess.run(
        [sys.executable, str(SCRIPT)],
        env=dict(os.environ, SETTINGS_FILE=str(claude / "settings.json"),
                 HOOK_EXERCISE_TIMEOUT="1"),
        capture_output=True, text=True, timeout=60)
    return r.stdout.splitlines()


def test_slow_hook_is_undetermined_not_failed(tmp_path):
    out = _run(tmp_path, ["sleep 3"])
    assert out[0] == "1|0|1", out
    assert out[1].startswith("TIMEOUT|PreToolUse|sleep|not determined (timed out"), out
    assert not any(line.startswith("FAIL|") for line in out), out


def test_missing_hook_still_fails_beside_a_slow_one(tmp_path):
    out = _run(tmp_path, ["true", "sleep 3", "/nonexistent/t4461-hook"])
    assert out[0] == "3|1|1", out
    assert any(line.startswith("FAIL|PreToolUse|t4461-hook|exit 127") for line in out), out
    assert any(line.startswith("TIMEOUT|PreToolUse|sleep|") for line in out), out
