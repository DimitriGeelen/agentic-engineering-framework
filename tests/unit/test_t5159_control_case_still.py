"""T-5159: a control case written "X is still blocked" must not veto "Confirmed, thank you".

The three replies below are the real ones on #98, #111 and #112 (2026-11-14), verbatim apart
from line wrapping. `fw issues confirm-close` refused all three before this fix.
"""
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "lib"))
import issues  # noqa: E402

REAL = {
    98: ("Tested on v1.8.16-be.49 in a throwaway container (no network, non-root, fresh `fw init`): with "
         "`playwright` added to ABSENT_COMPONENTS, fw doctor now reads \"OK Playwright pip package not "
         "installed — absent by choice\", and the Playwright WARN is gone (1 before, 0 after). A misspelled "
         "name is still reported. Confirmed, thank you; that covers everything we asked for in this issue.\n"),
    111: ("Tested on v1.8.16-be.49 in a throwaway container, calling the boundary gate with the JSON input "
          "Claude Code sends: `grep -rE '/home/|192\\.168\\.' docs/` now passes, and as a control, "
          "`cat /home/other-account/notes.md` is still blocked. Confirmed, thank you.\n"),
    112: ("Tested on v1.8.16-be.49 in a throwaway container, onboarding tasks open, calling the task gate "
          "with the JSON input Claude Code sends: `awk -F: '$2>9' notes.txt` now passes, and as a control, "
          "the same command with `> out.txt` appended is still blocked. Confirmed, thank you.\n"),
}


@pytest.mark.parametrize("n", sorted(REAL))
def test_real_control_case_replies_are_confirmed(n):
    assert issues.classify_reply(REAL[n]) == "confirmed"


@pytest.mark.parametrize("text,want", [
    ("Tested it. The page is still slow. Confirmed, thank you.", "other"),        # bare "still" is doubt
    ("Tested it. Confirmed fixed, except on Windows.", "other"),
    ("Tested it. Confirmed fixed. However the log is odd.", "other"),
    ("Case A still fails. Confirmed, thank you.", "not-fixed"),
    ("It is still broken. Confirmed, thank you.", "not-fixed"),
    ("Tested it; the old path still works. Confirmed, thank you.", "confirmed"),
])
def test_other_counter_signals_keep_their_effect(text, want):
    assert issues.classify_reply(text) == want
