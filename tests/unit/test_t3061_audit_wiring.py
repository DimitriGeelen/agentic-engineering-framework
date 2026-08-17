"""T-3061: the unclosed-but-satisfied rule reaches `fw audit`, and only once.

`tests/unit/test_task_satisfaction.py` pins the *rule* (15 tests, both directions,
with a live-corpus positive control). It cannot see whether anything calls it — and
for a while nothing did: `lib/task_satisfaction.py` shipped tested and imported by
its own test only, while `agents/audit/active-task-scan.py` carried a second copy of
the same predicate inline. The two agreed on all 18 corpus hits, which is precisely
why a later divergence would have gone unnoticed: a wired-nowhere helper reads
exactly like a wired-everywhere one.

So this file asserts the join, not the rule:
  1. the scan emits `unclosed_satisfied`, and its verdict equals the library's
  2. `audit.sh` consumes that key (a producer with no consumer is not a rail)
  3. the rule is defined once — the scan imports it rather than restating it
"""

from __future__ import annotations

import json
import re
import subprocess
import sys
from pathlib import Path

import pytest

FRAMEWORK_ROOT = Path(__file__).resolve().parents[2]
SCAN = FRAMEWORK_ROOT / "agents" / "audit" / "active-task-scan.py"
sys.path.insert(0, str(FRAMEWORK_ROOT / "lib"))


@pytest.fixture(scope="module")
def scan_output() -> dict:
    r = subprocess.run(
        [sys.executable, str(SCAN), ".tasks", "docs/reports"],
        cwd=FRAMEWORK_ROOT, capture_output=True, text=True, timeout=180,
    )
    assert r.returncode == 0, r.stderr[-800:]
    return json.loads(r.stdout)


def test_scan_emits_the_section(scan_output):
    assert "unclosed_satisfied" in scan_output, \
        "the scan produces no unclosed_satisfied key — the rail is unwired"
    u = scan_output["unclosed_satisfied"]
    for key in ("tasks", "count", "no_verification_count"):
        assert key in u, f"missing {key}"


def test_scan_verdict_equals_the_library(scan_output):
    """The load-bearing assertion: one rule, one answer.

    If the scan ever grows its own copy of the predicate again, this diverges the
    moment the copies disagree — which is the only moment it matters.
    """
    import task_satisfaction

    lib_ids = {r["id"] for r in task_satisfaction.scan(FRAMEWORK_ROOT / ".tasks" / "active")}
    scan_ids = {t["id"] for t in scan_output["unclosed_satisfied"]["tasks"]}

    assert scan_ids == lib_ids, (
        "audit scan and lib/task_satisfaction.py disagree — "
        f"scan-only={sorted(scan_ids - lib_ids)} lib-only={sorted(lib_ids - scan_ids)}")

    # Positive control (L-616): two empty sets are equal. An empty verdict would
    # satisfy the assertion above while proving nothing, and "no unclosed tasks"
    # is indistinguishable from "the detector never ran".
    assert lib_ids, "nothing detected at all — equality above is vacuous"


def test_confidence_split_is_carried_through(scan_output):
    """A3: gated vs ungated must survive the wiring, not just exist in the library."""
    u = scan_output["unclosed_satisfied"]
    ungated = [t for t in u["tasks"] if not t["has_verification"]]
    assert u["no_verification_count"] == len(ungated)
    # Both classes present in the live corpus, so neither branch is untested here.
    assert 0 < len(ungated) < u["count"], (
        f"{len(ungated)} of {u['count']} ungated — one class is empty, so this "
        "test no longer distinguishes them")


def test_audit_consumes_the_section():
    """A producer nobody reads is not a rail (the T-2278 shape)."""
    audit = (FRAMEWORK_ROOT / "agents" / "audit" / "audit.sh").read_text()
    assert "unclosed_satisfied" in audit, "audit.sh never reads the scan's output"
    # A5: hygiene about finished work must not fail a push. Slice to the NEXT
    # section header — a first attempt ran to EOF and tripped on an unrelated
    # `health_check_failed` further down the file, which is a false red about
    # a real rule.
    start = audit.index("UNCLOSED-BUT-SATISFIED")
    nxt = re.search(r"^# SECTION ", audit[start:], re.MULTILINE)
    section = audit[start:start + nxt.start()] if nxt else audit[start:]
    assert len(section) < len(audit) / 2, "section slice did not terminate sensibly"
    # audit.sh's emitters are the bare shell functions `warn` / `fail`. Matched at
    # line start so the section's own prose ("this is a WARN, not a FAIL") cannot
    # satisfy or trip either assertion — being mentioned is not being emitted.
    assert re.search(r"^\s*warn ", section, re.MULTILINE), \
        "the rail never calls warn — nothing surfaces"
    assert not re.search(r"^\s*fail ", section, re.MULTILINE), \
        "the rail calls fail; A5 says WARN only (it must not block a push)"


def test_rule_is_defined_once():
    """The scan imports the predicate instead of restating it."""
    src = SCAN.read_text()
    assert "from task_satisfaction import" in src, \
        "scan does not import the shared rule"
    # The inline copy's distinctive helpers must not come back.
    for gone in ("def classify_unclosed_satisfied", "def _count_checkboxes"):
        assert gone not in src, f"{gone} is back — the rule has two definitions again"
