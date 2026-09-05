"""T-3280 (G-102 defect B) — sanitizer for operator-facing gate stderr.

Fixture is the literal shape of the 2026-09-05 T-3278 incident response:
the disposition gate's agent-facing block message rendered raw to the
operator, Tier-2 bypass flags included.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from web.blueprints.inception import _operator_facing_stderr


INCIDENT = """=== Task Update ===
Task:    T-3278 ("Restart-based M2 transport...")
File:    /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3278.md
WARNING: Completing human-owned task (--skip-sovereignty bypass)
Acceptance criteria: 3/3 checked
ERROR: Cannot complete inception — 5 Open Question(s) under-disposed.

T-2190 (T-2186 Slice 4): every IW-N question in ## Open Questions must carry
  disposition: answered|deferred|dissolved
  rationale: <evidence>
Never binary. See 050-Inceptions.md §Disposition Gate.

Missing:

    - IW-1 (disposition=false rationale=false)

Options:
  1. Add disposition + rationale lines per missing question
  2. --skip-disposition-gate "rationale"  (direct, logged Tier-2)
  3. FW_SKIP_DISPOSITION_GATE=1 <command>  (env-var, logged Tier-2)
"""


def test_bypass_flags_are_stripped():
    out = _operator_facing_stderr(INCIDENT)
    assert "--skip-disposition-gate" not in out
    assert "FW_SKIP_DISPOSITION_GATE" not in out
    assert "Options:" not in out


def test_sovereignty_warning_and_banner_are_stripped():
    out = _operator_facing_stderr(INCIDENT)
    assert "--skip-sovereignty" not in out
    assert "=== Task Update ===" not in out
    assert "Task:    T-3278" not in out


def test_substantive_reason_survives():
    out = _operator_facing_stderr(INCIDENT)
    assert "Cannot complete inception" in out
    assert "5 Open Question(s) under-disposed" in out
    assert "IW-1" in out
    assert "disposition: answered|deferred|dissolved" in out


def test_empty_and_none_degrade_safely():
    assert _operator_facing_stderr("") == ""
    assert _operator_facing_stderr(None) == ""


def test_blank_line_runs_are_collapsed():
    out = _operator_facing_stderr(INCIDENT)
    assert "\n\n\n" not in out
