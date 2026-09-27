"""Tests for lib/ac_placeholder.py — the shared AC template-stub predicate (T-3528).

Mapped to T-3528's Agent ACs:
  (1) one shared predicate, both Python readers import it
  (2) stub of ANY length is non-substantive (the length floor is not the decider)
  (5) cross-language parity with the bash reader is PINNED, not asserted
  (6) the missing fixture exists — real template stubs, asserted non-green

The parity test is the load-bearing one. `lib/task-audit.sh` and
`agents/context/check-active-task.sh` cannot import Python (one of them runs in a
PreToolUse hook on every Write/Edit), so the readers stay separate by design and
this test is the only thing holding them together.
"""

from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(ROOT / "lib"))

import ac_placeholder as ap  # noqa: E402

TASK_AUDIT_SH = ROOT / "lib" / "task-audit.sh"
CHECK_ACTIVE_TASK_SH = ROOT / "agents" / "context" / "check-active-task.sh"


# ───────────────────────── the predicate itself ─────────────────────────────


@pytest.mark.parametrize("sample", ap.CANONICAL_SAMPLES)
def test_every_canonical_sample_is_a_placeholder(sample):
    assert ap.is_placeholder_item(sample), f"{sample!r} should read as a template stub"


@pytest.mark.parametrize("sample", ap.CANONICAL_NON_SAMPLES)
def test_real_ac_text_and_routing_prefixes_are_not_placeholders(sample):
    """The routing prefixes are the ones that matter — a predicate that swallowed
    [REVIEW]/[REVIEWER] would refuse every correctly routed criterion in the corpus."""
    assert not ap.is_placeholder_item(sample), f"{sample!r} must NOT read as a stub"


def test_stub_inside_a_real_checkbox_line_is_still_caught():
    assert ap.is_placeholder_item("- [ ] [First criterion]")


def test_case_insensitive_by_design():
    """Deliberately wider than task-audit.sh. A detector that fails open on case
    is the defect class this module closes."""
    assert ap.is_placeholder_item("[first criterion]")
    assert ap.is_placeholder_item("[todo]")


def test_length_is_not_the_decider():
    """The OBS-560 defect in one assertion: the first ordinal stub clears the
    judge's 15-char floor, so length cannot be what answers this question."""
    stub = "[First criterion]"
    assert len(stub) > 15, "fixture no longer reproduces OBS-560's arithmetic"
    assert ap.is_placeholder_item(stub)


# ───────────────────────── all_placeholder / block shapes ───────────────────


def test_empty_is_not_all_placeholder():
    """Absence and template-text are different findings; collapsing them is how
    a check ends up answering the question next to the one it was asked."""
    assert ap.all_placeholder([]) is False
    assert ap.all_placeholder(None) is False


def test_all_placeholder_needs_every_item():
    assert ap.all_placeholder(["[First criterion]", "[Second criterion]"]) is True
    assert ap.all_placeholder(["[First criterion]", "A real substantive criterion"]) is False


def test_placeholder_items_names_the_offenders():
    got = ap.placeholder_items(["[TODO]", "Real criterion text here", "[Criterion 2]"])
    assert got == ["[TODO]", "[Criterion 2]"]


def test_block_shape_treats_empty_and_checkbox_less_as_unscoped():
    assert ap.is_placeholder_block("") is True
    assert ap.is_placeholder_block("   \n\n  ") is True
    assert ap.is_placeholder_block("Some prose but no checkbox at all") is True
    assert ap.is_placeholder_block("- [ ] A real substantive criterion here") is False


# ───────────────────────── cross-language parity (AC 5) ─────────────────────


def _bash_placeholder_regex() -> str:
    """Extract the LIVE regex from lib/task-audit.sh rather than restating it.

    Restating it would make this test pass while the two readers drifted, which
    is the failure mode it exists to prevent.
    """
    text = TASK_AUDIT_SH.read_text()
    # The file contains a shell-quoted ERE, so the bracket is backslash-escaped
    # there: match a literal backslash followed by `[Criterion`.
    m = re.search(r"grep -qE '(\\\[Criterion[^']*)'", text)
    assert m, ("could not find the placeholder regex in lib/task-audit.sh — if it "
               "moved or was renamed, update this extractor; do NOT inline a copy "
               "of the pattern here (T-3528)")
    return m.group(1)


def test_bash_placeholder_regex_is_still_findable():
    assert _bash_placeholder_regex().startswith(r"\[Criterion")


@pytest.mark.parametrize("sample", ap.CANONICAL_SAMPLES)
def test_bash_and_python_readers_agree(sample):
    """Every sample the Python predicate flags must also match the REAL bash
    regex, run as bash runs it. If either side drops a pattern, this goes red."""
    regex = _bash_placeholder_regex()
    proc = subprocess.run(["grep", "-qE", regex], input=sample, text=True)
    assert proc.returncode == 0, (
        f"{sample!r} matches the Python predicate but NOT lib/task-audit.sh's "
        f"regex — the two readers have drifted")
    assert ap.is_placeholder_item(sample)


def test_control_leg_the_parity_test_can_fail():
    """Without this, a parity test that matched everything would look identical
    to one that matched correctly."""
    regex = _bash_placeholder_regex()
    proc = subprocess.run(["grep", "-qE", regex],
                          input="A genuinely authored acceptance criterion", text=True)
    assert proc.returncode != 0, "the bash regex matches arbitrary prose — it is too wide"


def test_g020_gate_still_carries_its_own_narrower_reader():
    """Documents the deliberate boundary (T-3528): the PreToolUse hook keeps its
    own grep rather than shelling out to python3. If someone consolidates it
    later, this test should be deleted with that change — not before.
    """
    text = CHECK_ACTIVE_TASK_SH.read_text()
    assert "criterion\\]" in text or "criterion]" in text, (
        "the G-020 gate no longer greps for ordinal criterion stubs — if it now "
        "delegates to lib/ac_placeholder.py, remove this test")
