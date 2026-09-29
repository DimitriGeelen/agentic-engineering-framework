"""T-3554 (OBS-571): the mechanical-signal regex matched ordinary English.

`_HUMAN_AC_MECHANICAL_RE`'s T-1897 conformance alternates ended in `\\S` —

    \\bnames?\\s+(the\\s+|current\\s+|missing\\s+)?\\S
    \\bshows?\\s+(?!no\\b)(the\\s+|current\\s+|missing\\s+)?\\S

`\\S` is ANY non-space character, so `\\bnames?\\s+\\S` matched any sentence
containing "name" followed by a word:

    MATCH 'name y'   | Please name your favourite colour.
    MATCH 'shows s'  | This paragraph shows something entirely subjective.

All 13 tasks on the D-626 delegation surface classified `deterministic` on a
fragment like that, and none was safely delegable. And because the T-3445 rail
WARNs only when reviewer-closeable is 0, reporting 13 fake ones suppressed the
alarm for exactly the condition the fakes created.

THE CONTROLS ARE LOAD-BEARING IN BOTH DIRECTIONS. A regex that matches nothing
drops every false positive and is useless; a regex that matches everything is
where we started. `test_conformance_cases_t1897_was_written_for_still_match` is
the half that a "just delete the alternates" fix would fail.
"""

import sys
from pathlib import Path

FW_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(FW_ROOT / "lib"))
sys.path.insert(0, str(FW_ROOT))

from reviewer.static_scan import _HUMAN_AC_MECHANICAL_RE as R  # noqa: E402

# Real conformance phrasing — the shapes T-1897 was built for. The object of the
# verb is an identifier: backticked, a flag, a path, ALL-CAPS, a task id, quoted.
CONFORMANCE = [
    "block message names `--switch-focus`",
    "stderr names the --switch-focus flag",
    "gate refusal shows current focus",
    "names the missing FW_SAFE_MODE key",
    "output names T-1730",
    'the message names "focus.yaml"',
    "shows .context/working/focus.yaml",
    "the block message names PROJECT_ROOT",
    "shows `status: success`",
]

# Ordinary English. Every one of these came from a real criterion or from the
# probe set used to characterise the defect.
PROSE = [
    "Please name your favourite colour.",
    "This paragraph shows something entirely subjective.",
    "Confirm the verdicts are the right call and name the reason.",
    "A relaunched session shows the listener still attached.",
    "The operator should name a successor mechanism.",
    "Verify the layout shows a clean hierarchy.",
    "Live wire-level smoke shows a working endpoint.",
    "Confirm the substrate change matches ADR-0004's intent — Names matching.",
    "Transfer the four external review findings and shows the consolidated matrix.",
    "Dependency links are clickable and descriptions readable on the page.",
]

# Alternates this task did NOT touch. They must keep working — the fix narrows
# two branches, not the dialect.
OTHER_DIALECTS = [
    "grep -q expected output.txt",
    "wc -l returns 3",
    "exit code 0",
    "returns 0",
    "exits 0",
    "HTTP 200",
    "file exists",
    "file missing",
    "stdout contains the id",
    "audit log row appended",
    "points at the config",
    "block-message names the bypass",
    "test -f /tmp/x",
    "curl -sf localhost",
]


def test_conformance_cases_t1897_was_written_for_still_match():
    """CONTROL. Deleting the two alternates outright would pass every PROSE test
    below and fail this one — which is why it is here."""
    missed = [s for s in CONFORMANCE if not R.search(s)]
    assert not missed, f"lost real conformance shapes: {missed}"


def test_ordinary_prose_no_longer_matches():
    still = [(s, R.search(s).group(0).strip()) for s in PROSE if R.search(s)]
    assert not still, f"prose still classified as a shell check: {still}"


def test_untouched_dialects_are_unaffected():
    """The I/O-checking branches predate T-1897 and are not in scope here."""
    missed = [s for s in OTHER_DIALECTS if not R.search(s)]
    assert not missed, f"unrelated alternates broke: {missed}"


def test_the_two_originating_probes_specifically():
    """Named individually because they are the evidence in OBS-571, and a
    regression here means the report has become untrue."""
    assert not R.search("Please name your favourite colour.")
    assert not R.search("This paragraph shows something entirely subjective.")


def test_all_caps_branch_is_case_sensitive():
    """Load-bearing, and the bug in my own first draft of this fix.

    The pattern compiles with re.I. Under re.I, `[A-Z][A-Z0-9_]{2,}` matches any
    three-letter word — so "name your" and "shows something" sailed through the
    tightened version until the branch was wrapped in `(?-i: )`. A fix that
    reintroduces the defect it is fixing is worth one test of its own.
    """
    assert R.search("names the FW_SAFE_MODE key"), "ALL-CAPS identifier must match"
    assert not R.search("names the successor mechanism"), "lowercase word must not"


def test_multiword_prefix_is_accepted():
    """`the missing X` is two prefix words. The original allowed only one, which
    dropped the T-1762 gate-refusal phrasing when the object was tightened."""
    assert R.search("names the missing FW_SAFE_MODE key")


def test_negation_object_still_excluded_t2641():
    """`shows no X` is a UI-absence assertion, not grep-able conformance — a
    foreign-corpus false positive 832 hit. The `(?!no\\b)` guard survives."""
    assert not R.search("maps show no prompt")
    assert not R.search("shows no `banner`")
