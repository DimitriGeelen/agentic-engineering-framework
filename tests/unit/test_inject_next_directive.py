"""T-2364 (T-2158 S2) — unit tests for inject-next-directive.py.

Covers:
  AC#1 — helper reads .next-directive.yaml and emits "## Next Directive" section
  AC#2 — iteration counter increments across invocations + persists to state file
  AC#3 — refuse-to-inject when iteration > max_iterations OR expires_at passed
  AC#4 — no-directive / no-state degrades silently (empty stdout, exit 0)
"""

import importlib.util
import subprocess
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

import pytest
import yaml

PROJECT_ROOT = Path(__file__).resolve().parents[2]
HELPER = PROJECT_ROOT / "agents" / "context" / "inject-next-directive.py"


def _load_helper():
    """Import the helper module by file path (it has a hyphen in the name)."""
    spec = importlib.util.spec_from_file_location("inject_next_directive", HELPER)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def _file_layout(tmp_path):
    """Create the expected .context/working/ layout under tmp_path."""
    working = tmp_path / ".context" / "working"
    working.mkdir(parents=True)
    return working


def _write_directive(working, **overrides):
    """Write a default .next-directive.yaml; allow per-test overrides."""
    payload = {
        "directive": "continue T-XXXX",
        "filed_by": "operator",
        "filed_at": "2026-06-13T09:15:00Z",
        "expires_at": "2026-06-14T09:00:00Z",
        "iteration": 0,
        "max_iterations": 5,
        "tier_ceiling": 1,
    }
    payload.update(overrides)
    (working / ".next-directive.yaml").write_text(yaml.safe_dump(payload))


def _run_subprocess(tmp_path, now=None):
    """Invoke the helper as a subprocess and return (stdout, exitcode)."""
    args = [sys.executable, str(HELPER), "--project-root", str(tmp_path)]
    if now:
        args += ["--now", now]
    result = subprocess.run(args, capture_output=True, text=True)
    return result.stdout, result.returncode


# ─── AC#4 baseline: degrade-to-no-op paths ──────────────────────────────────

def test_no_directive_file_is_silent_no_op(tmp_path):
    _file_layout(tmp_path)
    stdout, rc = _run_subprocess(tmp_path)
    assert rc == 0
    assert stdout == ""


def test_directive_file_empty_directive_field_is_silent(tmp_path):
    working = _file_layout(tmp_path)
    (working / ".next-directive.yaml").write_text("directive: ''\nfiled_by: self\n")
    stdout, rc = _run_subprocess(tmp_path)
    assert rc == 0
    assert stdout == ""


def test_directive_file_missing_directive_field_is_silent(tmp_path):
    working = _file_layout(tmp_path)
    (working / ".next-directive.yaml").write_text("filed_by: self\n")
    stdout, rc = _run_subprocess(tmp_path)
    assert rc == 0
    assert stdout == ""


def test_malformed_yaml_is_silent_no_op(tmp_path):
    working = _file_layout(tmp_path)
    (working / ".next-directive.yaml").write_text("not: [valid: yaml")
    stdout, rc = _run_subprocess(tmp_path)
    assert rc == 0
    assert stdout == ""


# ─── AC#1: helper emits "## Next Directive" section ─────────────────────────

def test_first_resume_emits_next_directive_section(tmp_path):
    working = _file_layout(tmp_path)
    _write_directive(working, directive="extend post-compact-resume.sh")
    stdout, rc = _run_subprocess(tmp_path, now="2026-06-13T10:00:00Z")
    assert rc == 0
    assert stdout.startswith("## Next Directive (iteration 1/5, tier_ceiling 1)")
    assert "extend post-compact-resume.sh" in stdout
    assert "Filed by: operator at 2026-06-13T09:15:00Z" in stdout
    assert "LOOP TERMINATED" not in stdout


def test_section_renders_max_iter_unset_as_infinity(tmp_path):
    working = _file_layout(tmp_path)
    _write_directive(working, max_iterations=None)
    stdout, _ = _run_subprocess(tmp_path, now="2026-06-13T10:00:00Z")
    # ∞ renders when max_iterations is unset
    assert "iteration 1/∞" in stdout


def test_section_renders_tier_ceiling_unset(tmp_path):
    working = _file_layout(tmp_path)
    _write_directive(working, tier_ceiling=None)
    stdout, _ = _run_subprocess(tmp_path, now="2026-06-13T10:00:00Z")
    assert "tier_ceiling unset" in stdout


# ─── AC#2: iteration counter increments + persists ──────────────────────────

def test_iteration_counter_increments_across_invocations(tmp_path):
    working = _file_layout(tmp_path)
    _write_directive(working)
    stdout1, _ = _run_subprocess(tmp_path, now="2026-06-13T10:00:00Z")
    stdout2, _ = _run_subprocess(tmp_path, now="2026-06-13T11:00:00Z")
    stdout3, _ = _run_subprocess(tmp_path, now="2026-06-13T12:00:00Z")
    assert "iteration 1/5" in stdout1
    assert "iteration 2/5" in stdout2
    assert "iteration 3/5" in stdout3


def test_state_file_persists_after_first_resume(tmp_path):
    working = _file_layout(tmp_path)
    _write_directive(working, directive="hello world")
    _run_subprocess(tmp_path, now="2026-06-13T10:00:00Z")
    state_file = working / ".continuous-mode-state.yaml"
    assert state_file.is_file()
    state = yaml.safe_load(state_file.read_text())
    assert state["iteration"] == 1
    assert state["last_resumed_at"] == "2026-06-13T10:00:00Z"
    assert state["last_directive_seen"] == "hello world"
    assert state["last_terminated_reason"] == ""


def test_state_file_carries_iteration_across_calls(tmp_path):
    working = _file_layout(tmp_path)
    _write_directive(working)
    _run_subprocess(tmp_path, now="2026-06-13T10:00:00Z")
    _run_subprocess(tmp_path, now="2026-06-13T11:00:00Z")
    state = yaml.safe_load((working / ".continuous-mode-state.yaml").read_text())
    assert state["iteration"] == 2


# ─── AC#3: refuse-to-inject on cap or expiry ────────────────────────────────

def test_loop_terminated_when_iteration_exceeds_cap(tmp_path):
    working = _file_layout(tmp_path)
    _write_directive(working, max_iterations=2)
    out1, _ = _run_subprocess(tmp_path, now="2026-06-13T10:00:00Z")
    out2, _ = _run_subprocess(tmp_path, now="2026-06-13T10:30:00Z")
    out3, _ = _run_subprocess(tmp_path, now="2026-06-13T11:00:00Z")
    assert "iteration 1/2" in out1
    assert "iteration 2/2" in out2
    assert "LOOP TERMINATED" in out3
    assert "iteration 3 exceeds max_iterations 2" in out3


def test_loop_terminated_when_expires_at_passed(tmp_path):
    working = _file_layout(tmp_path)
    # Expiry in the past
    _write_directive(working, expires_at="2026-06-12T00:00:00Z")
    stdout, rc = _run_subprocess(tmp_path, now="2026-06-13T10:00:00Z")
    assert rc == 0
    assert "LOOP TERMINATED" in stdout
    assert "expires_at 2026-06-12T00:00:00Z passed" in stdout


def test_loop_terminated_state_records_reason(tmp_path):
    working = _file_layout(tmp_path)
    _write_directive(working, max_iterations=0)  # cap=0 → first call is over
    _run_subprocess(tmp_path, now="2026-06-13T10:00:00Z")
    state = yaml.safe_load((working / ".continuous-mode-state.yaml").read_text())
    assert state["iteration"] == 1
    assert "exceeds max_iterations 0" in state["last_terminated_reason"]


def test_no_cap_no_expiry_runs_forever(tmp_path):
    working = _file_layout(tmp_path)
    _write_directive(working, max_iterations=None, expires_at=None)
    for i in range(1, 11):
        out, _ = _run_subprocess(tmp_path, now=f"2026-06-13T{i:02d}:00:00Z")
        assert "LOOP TERMINATED" not in out
        assert f"iteration {i}/∞" in out


# ─── Programmatic API tests (faster, exercise evaluate() directly) ──────────

def test_evaluate_returns_empty_section_when_directive_missing():
    mod = _load_helper()
    state, section = mod.evaluate(
        {"filed_by": "self"}, {}, datetime(2026, 6, 13, 10, 0, tzinfo=timezone.utc)
    )
    assert section == ""


def test_evaluate_advances_iteration():
    mod = _load_helper()
    now = datetime(2026, 6, 13, 10, 0, tzinfo=timezone.utc)
    state, section = mod.evaluate(
        {"directive": "do X", "max_iterations": 5}, {"iteration": 3}, now
    )
    assert state["iteration"] == 4
    assert "iteration 4/5" in section


def test_evaluate_handles_malformed_iteration_state():
    mod = _load_helper()
    now = datetime(2026, 6, 13, 10, 0, tzinfo=timezone.utc)
    state, section = mod.evaluate(
        {"directive": "do X"}, {"iteration": "not-a-number"}, now
    )
    # Falls back to 0, then increments to 1
    assert state["iteration"] == 1
    assert "iteration 1/" in section


def test_parse_iso8601_accepts_z_suffix():
    mod = _load_helper()
    dt = mod.parse_iso8601("2026-06-14T09:00:00Z")
    assert dt is not None
    assert dt.tzinfo is timezone.utc
    assert dt.year == 2026


def test_format_iso8601_normalises_datetime_to_z_suffix():
    """YAML auto-coerces unquoted ISO timestamps to datetime; display must
    normalise back to Z-suffix form so operator-facing output stays consistent
    regardless of how the directive file was written."""
    mod = _load_helper()
    dt = datetime(2026, 6, 14, 9, 0, tzinfo=timezone.utc)
    assert mod.format_iso8601(dt) == "2026-06-14T09:00:00Z"
    # Naive datetime: assumed UTC
    naive = datetime(2026, 6, 14, 9, 0)
    assert mod.format_iso8601(naive) == "2026-06-14T09:00:00Z"
    # Pass-through for string
    assert mod.format_iso8601("2026-06-14T09:00:00Z") == "2026-06-14T09:00:00Z"
    # None → "unset"
    assert mod.format_iso8601(None) == "unset"
    # Empty → "unset"
    assert mod.format_iso8601("") == "unset"


def test_loop_terminated_message_normalises_datetime_expiry(tmp_path):
    """When .next-directive.yaml has an unquoted ISO expires_at, YAML coerces
    it to datetime — but the LOOP TERMINATED message must still render the
    Z-suffix form, not Python's '2026-06-14 09:00:00+00:00' repr."""
    working = _file_layout(tmp_path)
    # Unquoted form — yaml coerces to datetime
    payload = """directive: do X
filed_by: operator
filed_at: 2026-06-13T09:15:00Z
expires_at: 2026-06-12T00:00:00Z
max_iterations: 5
"""
    (working / ".next-directive.yaml").write_text(payload)
    stdout, _ = _run_subprocess(tmp_path, now="2026-06-13T10:00:00Z")
    assert "LOOP TERMINATED" in stdout
    assert "2026-06-12T00:00:00Z passed" in stdout
    assert "2026-06-12 00:00:00+00:00" not in stdout


def test_parse_iso8601_returns_none_on_garbage():
    mod = _load_helper()
    assert mod.parse_iso8601("not-a-date") is None
    assert mod.parse_iso8601("") is None
    assert mod.parse_iso8601(None) is None
