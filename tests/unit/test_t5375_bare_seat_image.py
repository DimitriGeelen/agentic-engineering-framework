"""T-5375 — a seat that cites the judge's per-seat screenshot copy by BARE file name, in Evidence
and in a bare `<name> region …` Location, is checked against
`.context/reviews/evidence/<task>/<name>` instead of being graded not-checkable. Anything else
(a missing file, another task's directory, `..`, an absolute path outside, a name that is not a
seat copy) is refused exactly as before.

The vote below is the T-5376 rung-5 claude-code seat's vote, verbatim
(.context/dispatch/judge-t-5376-r5-claude-code-4898f9d85707/result.md)."""
import json
import os
import subprocess
import sys
from pathlib import Path

import pytest

_HERE = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(_HERE))

from PIL import Image  # noqa: E402

from lib import verdict_format, vote_checker as vc  # noqa: E402

TASK = "T-5376"
DID = "judge-t-5376-r5-claude-code-4898f9d85707"
EVD = f".context/reviews/evidence/{TASK}"
SIZES = {"1920": (1920, 6900), "1440": (1440, 7800), "1024": (1024, 9800)}


def _name(w: str) -> str:
    return f"config@{w}-{DID}.png"


VOTE = f"""===VERDICT===
format: verdict/1
task: T-5376
reviewer: reviewer-judge-t-5376-r5-claude-code-4898f9d85707:claude-code
round: 1
vote: green
failed: []

## AC1 The new INDEX_EXCLUDE_DIRS row on the Watchtower config page reads like its neighbours
Vote: green
Evidence: image: config@1920-judge-t-5376-r5-claude-code-4898f9d85707.png region 235,6750,1460,125
Location: config@1920-judge-t-5376-r5-claude-code-4898f9d85707.png region 235,6750,1460,125
Evidence: "By default every git-tracked document is indexed. Empty = built-in exclusions only; absolute paths and .. are ignored. T-5376"
Location: config@1920-judge-t-5376-r5-claude-code-4898f9d85707.png region 235,6750,1460,125
Evidence: image: config@1440-judge-t-5376-r5-claude-code-4898f9d85707.png region 100,7330,1340,390
Location: config@1440-judge-t-5376-r5-claude-code-4898f9d85707.png region 100,7330,1340,390
Evidence: image: config@1024-judge-t-5376-r5-claude-code-4898f9d85707.png region 40,9300,984,460
Location: config@1024-judge-t-5376-r5-claude-code-4898f9d85707.png region 40,9300,984,460
Rule: criterion: "same columns and wrapping as the other rows; the description is readable and does not push the table wider; no overlap at your window width."
Conclusion: At 1024, 1440 and 1920 px the INDEX_EXCLUDE_DIRS row uses the same four columns and wrapping as its neighbours, its description is fully readable, and the table's right edge is unchanged, so the criterion holds at every width captured.

## Counter-search
Searched: the 1024 px crop for clipped text or name-cell overflow; the 1440 px crop for a shifted table edge; the 1920 px crop for a cut-off last description line; the full-page captures for overlap with "Custom Settings".
Found: no clipping, overlap or edge shift. The name cell breaks mid-token at 1024 px, but neighbouring rows break the same way, and the "DEFAULT" badge wraps on every row.

## Change-my-mind
A capture at one of the three widths where the INDEX_EXCLUDE_DIRS description is cut off, overlaps FW_HANDOVERS, or widens the table relative to the neighbouring rows.
===END===
"""


@pytest.fixture
def root(tmp_path):
    subprocess.run(["git", "init", "-q"], cwd=tmp_path, check=True)
    return tmp_path


def _copies(root: Path, task: str = TASK) -> None:
    for w, size in SIZES.items():
        f = root / ".context/reviews/evidence" / task / _name(w)
        f.parent.mkdir(parents=True, exist_ok=True)
        Image.new("RGB", size, "white").save(f)


def _seat(root: Path, did: str = DID) -> Path:
    """A claude stream-json seat record that Read each per-seat copy."""
    d = root / ".context" / "dispatch" / did
    d.mkdir(parents=True, exist_ok=True)
    lines: list[dict] = [{"type": "system", "subtype": "init"}]
    for w in SIZES:
        lines.append({"type": "assistant", "message": {"content": [
            {"type": "tool_use", "name": "Read",
             "input": {"file_path": str(root / EVD / _name(w))}}]}})
    (d / "result.jsonl").write_text("\n".join(json.dumps(x) for x in lines) + "\n")
    return d


def _vote_check(root: Path, seat: Path) -> dict:
    parsed, problems = verdict_format.parse_vote(VOTE, task=TASK, expected_acs=[1])
    acc = verdict_format.accepted(parsed, problems)
    assert list(acc) == [1], problems
    return vc.check_vote(acc[1], root, "", seat, task=TASK, write_crops=False)


# ── the T-5376 claude-code vote ───────────────────────────────────────────────────────────────

def test_t5376_vote_is_checkable_with_seat_copies(root):
    _copies(root)
    out = _vote_check(root, _seat(root))
    assert vc.check_reasons(out, render=True, panel=True) == []
    items = out["criteria"]["1"]["items"]
    imgs = [it for it in items if it["kind"] == "image"]
    assert len(imgs) == 3
    for it in imgs:
        assert it["image_exists"] is True and it["region_inside"] is True
        assert it["image"] == f"{EVD}/{it['cited_name']}"
        assert it["resolved_via"] == "seat-copy"
        assert it["seat_viewed"] is True and it["result"] == "ok"
    q = [it for it in items if it["kind"] == "quote"]
    assert len(q) == 1 and q[0]["image_location"] is True
    assert q[0]["result"] == "not-checkable" and q[0]["location_exists"] is True
    assert q[0]["path"] == f"{EVD}/{_name('1920')}"


def test_t5376_vote_without_copies_stays_not_checkable(root):
    out = _vote_check(root, _seat(root))
    reasons = vc.check_reasons(out, render=True, panel=True)
    assert sum("missing" in r for r in reasons) == 3
    assert any("does not exist" in r for r in reasons)          # the quote's image location


def test_region_outside_seat_copy_still_reported(root):
    _copies(root)
    f = root / EVD / _name("1920")
    Image.new("RGB", (1920, 100), "white").save(f)               # too short for y=6750
    out = _vote_check(root, _seat(root))
    assert any("outside" in r for r in vc.check_reasons(out, render=True, panel=True))


# ── the resolver and its refusals ─────────────────────────────────────────────────────────────

def test_seat_copy_path_resolves_only_existing_copy(root):
    _copies(root)
    assert vc.seat_copy_path(_name("1920"), TASK, root, DID) == f"{EVD}/{_name('1920')}"
    assert vc.seat_copy_path(_name("1920"), TASK, root) == f"{EVD}/{_name('1920')}"
    assert vc.seat_copy_path(_name("800"), TASK, root, DID) is None          # not there


def test_cited_image_path_uses_the_same_resolver(root):
    _copies(root)
    n = _name("1440")
    spec = "region 100,7330,1340,390"
    assert vc.cited_image_path(f"image: {n} {spec}", f"{n} {spec}", task=TASK, root=root,
                               dispatch_id=DID) == f"{EVD}/{n}"
    assert vc.cited_image_path(f"image: {n} {spec}", f"{n} {spec}") == n    # no task: as before


def test_other_tasks_directory_is_not_used(root):
    _copies(root, task="T-9999")
    assert vc.seat_copy_path(_name("1920"), TASK, root, DID) is None
    r = vc.check_image(f"image: {_name('1920')} region 1,1,2,2", f"{_name('1920')} region 1,1,2,2",
                       root, "", task=TASK, write_crops=False)
    assert r["image_exists"] is False and r["image"] == _name("1920")


def test_another_seats_copy_is_not_this_seats(root):
    _copies(root)
    other = "judge-t-5376-r5-codex-57fec5b3cfce"
    assert vc.seat_copy_path(_name("1920"), TASK, root, other) is None


def test_name_that_is_not_a_seat_copy_is_not_resolved(root):
    (root / EVD).mkdir(parents=True)
    Image.new("RGB", (10, 10)).save(root / EVD / "config@1920.png")
    assert vc.seat_copy_path("config@1920.png", TASK, root) is None
    assert vc.seat_copy_path("config@1920.png", TASK, root, DID) is None


@pytest.mark.parametrize("name", ["../" + "x-" + DID + ".png", "..", ".", "",
                                  "sub/x-" + DID + ".png"])
def test_path_like_names_refused(root, name):
    _copies(root)
    assert vc.seat_copy_path(name, TASK, root, DID) is None


@pytest.mark.parametrize("task", ["", "../T-5376", "T-5376/..", "x"])
def test_bad_task_refused(root, task):
    _copies(root)
    assert vc.seat_copy_path(_name("1920"), task, root, DID) is None


def test_symlink_out_of_evidence_dir_refused(root, tmp_path_factory):
    outside = tmp_path_factory.mktemp("outside") / "secret.png"
    Image.new("RGB", (10, 10)).save(outside)
    (root / EVD).mkdir(parents=True)
    os.symlink(outside, root / EVD / _name("1920"))
    assert vc.seat_copy_path(_name("1920"), TASK, root, DID) is None


def test_dotdot_and_absolute_evidence_unchanged(root, tmp_path_factory):
    _copies(root)
    outside = tmp_path_factory.mktemp("abs") / _name("1920")
    Image.new("RGB", (10, 10)).save(outside)
    for img in (f"../{_name('1920')}", str(outside)):
        r = vc.check_image(f"image: {img} region 1,1,2,2", f"{img} region 1,1,2,2", root, "",
                           task=TASK, write_crops=False)
        # not redirected into the evidence dir (how such a path is read is unchanged by T-5375)
        assert "resolved_via" not in r and r["image"] == img
        assert r.get("size") != list(SIZES["1920"])


def test_quote_on_image_location_without_agreeing_image_evidence_refused(root):
    _copies(root)
    n = _name("1920")
    vote = {"header": {"task": TASK, "vote": "green", "failed": []},
            "criterion": {"ac": 1, "vote": "green", "evidence": ['"some text"'],
                          "location": [f"{n} region 1,1,2,2"], "rule": "criterion: \"x\"",
                          "conclusion": "c"}}
    out = vc.check_vote(vote, root, "", None, task=TASK, write_crops=False)
    items = [it for c in out["criteria"].values() for it in c["items"]]
    assert items and items[0]["result"] == "location-mismatch"
    assert any("neither path:line nor command:" in r for r in vc.check_reasons(out))
