"""T-4195 — Layer 1 escalation ignores description: comment lines and quotations.

832 OBS-466 (their T-1150): a Verification `#` comment or an AC that quotes a
destructive command in backticks escalated the task as if it ran it. Drives the
REAL evaluate_escalations against the REAL policy file, both directions.
"""

from __future__ import annotations

import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(ROOT))

from lib.reviewer import static_scan as ss  # noqa: E402


@pytest.fixture(scope="module")
def esc() -> dict:
    return ss.load_catalogue(ROOT / "policy" / "escalation-patterns.yaml")


def _ids(esc, ac: str = "", verif: str = ""):
    return {t.trigger_id for t in ss.evaluate_escalations(ac, verif, {}, esc)}


# ── description must not escalate ──


def test_verification_comment_line_does_not_escalate(esc):
    verif = "# never run rm -rf or git push --force here\ntrue\n"
    assert "destructive-action" not in _ids(esc, verif=verif)


def test_indented_verification_comment_does_not_escalate(esc):
    verif = "   # git reset --hard is what the old flow did\nbats tests/unit/x.bats\n"
    assert "destructive-action" not in _ids(esc, verif=verif)


def test_verification_html_comment_does_not_escalate(esc):
    verif = "<!-- example: rm -rf build/ -->\ntrue\n"
    assert "destructive-action" not in _ids(esc, verif=verif)


def test_verification_publish_comment_does_not_escalate(esc):
    verif = "# do not npm publish from here\ntrue\n"
    assert "external-publish" not in _ids(esc, verif=verif)


def test_backticked_ac_quotation_does_not_escalate(esc):
    ac = "- [ ] The gate refuses a `force-push` without an approval"
    assert "destructive-action" not in _ids(esc, ac=ac)


def test_double_quoted_ac_quotation_does_not_escalate(esc):
    ac = '- [ ] Block message names "hard reset" as the refused action'
    assert "destructive-action" not in _ids(esc, ac=ac)


def test_ac_html_comment_does_not_escalate(esc):
    ac = "<!-- e.g. force-push the branch -->\n- [ ] Parser handles empty input"
    assert "destructive-action" not in _ids(esc, ac=ac)


# ── real operations still escalate ──


def test_executable_rm_rf_still_escalates(esc):
    verif = "# cleanup first\nrm -rf build/ && true\n"
    assert "destructive-action" in _ids(esc, verif=verif)


def test_executable_force_push_after_comment_still_escalates(esc):
    verif = "# push it\ngit push --force origin x\n"
    assert "destructive-action" in _ids(esc, verif=verif)


def test_unquoted_ac_force_push_still_escalates(esc):
    ac = "- [ ] Force-push the rewritten branch to origin"
    assert "destructive-action" in _ids(esc, ac=ac)


def test_quote_outside_does_not_hide_unquoted_hit(esc):
    ac = '- [ ] Rename "old" to "new", then hard reset the deploy branch'
    assert "destructive-action" in _ids(esc, ac=ac)
