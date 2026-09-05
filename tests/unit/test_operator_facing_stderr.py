"""T-3280 (G-102 defect B) — sanitizer for operator-facing gate stderr.

Fixture is the literal shape of the 2026-09-05 T-3278 incident response:
the disposition gate's agent-facing block message rendered raw to the
operator, Tier-2 bypass flags included.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

# T-3284: the implementation moved to web.shared (one copy, N call sites).
from web.shared import operator_facing_stderr as _operator_facing_stderr


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


# ── T-3284: parity pins ──────────────────────────────────────────────────────
# The 2026-09-05 T-3278 incident cluster produced three fixes of the same
# L-399 shape (a fix authored only at the surface where the failure fired).
# These pins make the *class* fail loudly instead of waiting for an operator.

def test_blueprint_alias_is_the_shared_implementation():
    """inception.py must not re-grow its own copy of the sanitizer."""
    from web.blueprints import inception as _inc
    from web import shared as _sh
    assert _inc._operator_facing_stderr is _sh.operator_facing_stderr


def test_every_stderr_render_site_is_sanitized():
    """Source-scan pin: in the blueprints that render subprocess stderr to the
    operator (inception decide paths, approvals decide/batch endpoints), every
    line that puts `stderr` into rendered output must reference the sanitizer.

    Heuristic: within web/blueprints/{inception,approvals}.py, any statement
    line mentioning `stderr` inside a return/append/assignment that feeds a
    render must also mention `operator_facing_stderr` (allowing the multi-line
    pattern where the sanitizer call wraps on the previous line). Capture and
    plumbing lines (subprocess capture, logging, tuple unpack, comments) are
    exempt. A new raw render point fails here rather than in production."""
    import re

    root = Path(__file__).resolve().parents[2]
    exempt = re.compile(
        r"^\s*#"                                  # comments
        r"|capture_output|PIPE|communicate"        # subprocess plumbing
        r"|logging\.|logger\.|log_"                # server-side logs, not renders
        r"|stdout, stderr, ok = "                  # tuple unpack from run_fw_command
        r"|proc\.stderr or \"\"\)\s*$"             # bare capture without render
        r"|def |import "
    )
    offenders = []
    for rel in ("web/blueprints/inception.py", "web/blueprints/approvals.py"):
        lines = (root / rel).read_text(encoding="utf-8").splitlines()
        for i, line in enumerate(lines):
            if "stderr" not in line or "_operator_facing_stderr" in line \
                    or "operator_facing_stderr" in line:
                continue
            if exempt.search(line):
                continue
            # is stderr being rendered (returned/appended/formatted)?
            if re.search(r"return|append|warning|error|reason|warn\b|err\b", line):
                # allow the wrapped-call shape: sanitizer named on a nearby line
                ctx = "\n".join(lines[max(0, i - 2): i + 2])
                if "operator_facing_stderr" in ctx:
                    continue
                # server-side logging calls span lines; their continuation args
                # mention stderr but render nothing to the operator
                if re.search(r"logging\.|logger\.", "\n".join(lines[max(0, i - 3): i + 1])):
                    continue
                offenders.append(f"{rel}:{i + 1}: {line.strip()}")
    assert not offenders, (
        "raw stderr reaches an operator render without operator_facing_stderr:\n"
        + "\n".join(offenders)
    )
