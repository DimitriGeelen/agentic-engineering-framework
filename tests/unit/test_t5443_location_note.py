"""T-5293 — the mechanical checker of a verdict/1 vote (lib/vote_checker.py).

Covers the task's Agent criteria: per quote found at the named line / elsewhere in the file /
not found (verbatim and whitespace-normalised); path:line exists; image exists and its region
lies inside it, with the crop written beside the seat's evidence; selector named; rule present;
overall vote consistent; `command:` not checkable; seat-viewed-evidence from each record shape
(codex, claude, opencode, none) including the T-5262 case; and the new field on ledger rows.
"""
import json
import subprocess
import sys
from pathlib import Path

import pytest

_HERE = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(_HERE))
sys.path.insert(0, str(Path(__file__).resolve().parent))


# T-5443: a seat may annotate a `<path>:<line>` Location with a trailing note
# (`(note)` or `— note`). The note is stripped; the bare path:line is kept and checked
# exactly as strictly as before (150-skills-manager msg 028d73f6, mistral-vibe seat).
from test_t5293_vote_checker import TASK, _vote, src  # noqa: E402,F401

from lib import verdict_format as vf  # noqa: E402
from lib import vote_checker as vc  # noqa: E402

CSS = "web/static/css/header.css"


@pytest.mark.parametrize("note", [" (pre-change revision)", " — the hidden rule", " – en dash note",
                                  " (two\n  lines)"])
def test_a_trailing_note_is_accepted_and_the_bare_location_stored(note):
    parsed, problems = _vote([('"display:   none;"', f"{CSS}:3{note}")])
    assert problems == {}
    assert parsed["criteria"][2]["location"] == [f"{CSS}:3"]


def test_a_range_with_a_note_keeps_the_range():
    parsed, problems = _vote([('"x"', f"{CSS}:2-4 (block)")])
    assert problems == {} and parsed["criteria"][2]["location"] == [f"{CSS}:2-4"]


@pytest.mark.parametrize("loc", [f"{CSS}:3foo", f"{CSS}:3 note without separator",
                                 f"web/static css/header.css:3 (note)", f"{CSS}:x (note)",
                                 f"{CSS}:3 ()", f"{CSS}:3 (note) trailing", f"{CSS} (note)",
                                 f"{CSS}:3 —"])
def test_malformed_locations_stay_refused_with_or_without_a_note(loc):
    _, problems = _vote([('"x"', loc)])
    assert any("is not `<path>:<line>`" in p for p in problems.get(2, [])), problems


def test_note_does_not_hide_a_bad_line_or_missing_file(src):  # noqa: F811
    root, rev = src
    ok, _ = _vote([('"display:   none;"', f"{CSS}:3 (pre-change)")], vote="green")
    r = vc.check_vote(ok, root, rev, None)
    assert [i["result"] for i in r["criteria"]["2"]["items"]] == ["found-at-location"]
    bad, problems = _vote([('".a"', f"{CSS}:40 (past the end)"),
                           ('"x"', "nope/missing.py:1 — not there")], vote="green")
    assert problems == {}
    items = vc.check_vote(bad, root, rev, None)["criteria"]["2"]["items"]
    assert [i["location_exists"] for i in items] == [False, False]
    assert items[0]["location"] == f"{CSS}:40" and items[1]["result"] == "not-found"


def test_non_file_locations_are_untouched():
    assert vf.bare_location("command: grep -n x (y)") == "command: grep -n x (y)"
    assert vf.bare_location("shot.png region 1,2,3,4") == "shot.png region 1,2,3,4"


def test_the_brief_says_a_note_is_ignored():
    assert "is allowed and ignored" in "\n".join(vf.brief_lines(TASK, [1], printed=False))
