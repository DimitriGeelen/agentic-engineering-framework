"""T-5292 — verdict/1: the structured reviewer vote, its brief, and the strict reader.

Covers the task's Agent criteria: the brief (both variants) asks for the structure; a complete
pass and a complete fail are accepted; each missing label is refused; an inconsistent overall
vote is refused; prose that only says "all criteria hold" is refused (1409 caveat c); old
free-text rows and old-brief runs read exactly as before; new rows carry the format and the
parsed structure, and a refused criterion gets no row with the reason in its evidence report.
"""
import json
import re
import sys
from pathlib import Path

import pytest

_HERE = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(_HERE))
sys.path.insert(0, str(Path(__file__).resolve().parent))

from lib import verdict_format as vf  # noqa: E402
from lib import verdict_ledger as vl  # noqa: E402
from lib.reviewer import judge_cli  # noqa: E402

TASK = "T-9200"

PASS = f"""===VERDICT===
format: verdict/1
task: {TASK}
reviewer: reviewer-judge-x:claude
round: 1
vote: green
failed: []

## AC1 The brief asks for the structure
Vote: green
Evidence: "Vote format (verdict/1 — required, pass and fail alike)"
Location: lib/reviewer/judge_cli.py:912
Rule: criterion: "the brief asks for the structured vote"
Conclusion: The heading at that line asks for it, so the clause holds.

## Counter-search
Searched: both brief variants for a missing structure
Found: both carry the vote format section

## Change-my-mind
A brief variant without the `Verdict format: verdict/1` line.
===END===
"""

FAIL = f"""Some notes before the vote.
===VERDICT===
format: verdict/1
task: {TASK}
reviewer: seat-codex
round: 1
vote: red
failed: [2]

## AC1 Header renders
Vote: green
Evidence: image: .context/working/judge-evidence/{TASK}/01-root.png region 0,0,1280,80
Location: .context/working/judge-evidence/{TASK}/01-root.png region 0,0,1280,80
Rule: criterion: "the header renders"
Conclusion: The header band is drawn across the top of the capture.

## AC2 Settings icon visible
Vote: red
Evidence: image: shot.png selector header .settings
Location: shot.png selector header .settings
Evidence: "display: none"
Location: web/static/css/header.css:88
Rule: criterion: "the settings icon is visible at every width"
Conclusion: The rule hides the icon at 1280 px,
  so it is not visible at that width.
Guidance: drop the display:none for widths >= 1024 px

## Counter-search
Searched: every media query in header.css
Found: none shows the icon below 1440 px

## Change-my-mind
A 1280 px capture showing the icon in that region.
===END===
"""


def _drop(text: str, line_prefix: str) -> str:
    return "\n".join(ln for ln in text.split("\n") if not ln.startswith(line_prefix))


# ── the reader ───────────────────────────────────────────────────────────────

class TestStrictReader:
    def test_a_complete_pass_is_accepted(self):
        parsed, problems = vf.parse_vote(PASS, task=TASK, expected_acs=[1])
        assert problems == {}
        ok = vf.accepted(parsed, problems)
        assert list(ok) == [1]
        s = ok[1]
        assert s["format"] == "verdict/1" and s["header"]["vote"] == "green"
        assert s["criterion"]["vote"] == "green"
        assert s["criterion"]["evidence"] == ['"Vote format (verdict/1 — required, pass and fail alike)"']
        assert s["counter_search"]["searched"] and s["change_my_mind"]

    def test_a_complete_fail_is_accepted_with_repeated_pairs_and_continuations(self):
        parsed, problems = vf.parse_vote(FAIL, task=TASK, expected_acs=[1, 2])
        assert problems == {}
        ok = vf.accepted(parsed, problems)
        assert set(ok) == {1, 2}
        c2 = ok[2]["criterion"]
        assert c2["vote"] == "red" and len(c2["evidence"]) == 2 and len(c2["location"]) == 2
        assert "so it is not visible" in c2["conclusion"]
        assert ok[2]["header"]["failed"] == [2]

    @pytest.mark.parametrize("label", ["Vote", "Evidence", "Location", "Rule", "Conclusion"])
    def test_each_missing_criterion_label_is_refused(self, label):
        text = _drop(PASS, f"{label}:")
        parsed, problems = vf.parse_vote(text, task=TASK, expected_acs=[1])
        assert vf.accepted(parsed, problems) == {}
        assert any(label in p for p in problems.get(1, []) + problems.get(vf.VOTE, []))

    @pytest.mark.parametrize("label", ["Evidence", "Rule", "Conclusion"])
    def test_an_empty_label_is_refused(self, label):
        text = re.sub(rf"(?m)^{label}:.*$", f"{label}:", PASS)
        parsed, problems = vf.parse_vote(text, task=TASK, expected_acs=[1])
        assert vf.accepted(parsed, problems) == {}

    @pytest.mark.parametrize("key", list(vf.HEADER_KEYS))
    def test_each_missing_header_field_is_refused(self, key):
        parsed, problems = vf.parse_vote(_drop(PASS, f"{key}:"), task=TASK, expected_acs=[1])
        assert vf.accepted(parsed, problems) == {}
        assert any(key in p for p in problems[vf.VOTE])

    @pytest.mark.parametrize("section", ["## Counter-search", "## Change-my-mind"])
    def test_each_missing_section_is_refused(self, section):
        head, _, rest = PASS.partition(section)
        # drop the section and its body up to the next section or the end marker
        nxt = re.search(r"(?m)^(## |===END===)", rest[1:])
        text = head + rest[1 + nxt.start():]
        parsed, problems = vf.parse_vote(text, task=TASK, expected_acs=[1])
        assert vf.accepted(parsed, problems) == {}
        assert any(section[3:] in p for p in problems[vf.VOTE])

    def test_a_missing_counter_search_label_is_refused(self):
        parsed, problems = vf.parse_vote(_drop(PASS, "Found:"), task=TASK, expected_acs=[1])
        assert vf.accepted(parsed, problems) == {}

    def test_a_fail_without_guidance_is_refused_for_that_criterion_only(self):
        parsed, problems = vf.parse_vote(_drop(FAIL, "Guidance:"), task=TASK, expected_acs=[1, 2])
        assert vf.VOTE not in problems and problems.get(2)
        assert set(vf.accepted(parsed, problems)) == {1}

    def test_an_outcome_outside_the_set_is_refused(self):
        text = PASS.replace("Vote: green", "Vote: pass")
        parsed, problems = vf.parse_vote(text, task=TASK, expected_acs=[1])
        assert vf.accepted(parsed, problems) == {}
        assert any("'pass'" in p for p in problems[1])

    def test_an_overall_vote_disagreeing_with_the_criteria_is_refused(self):
        text = FAIL.replace("vote: red", "vote: green").replace("failed: [2]", "failed: []")
        parsed, problems = vf.parse_vote(text, task=TASK, expected_acs=[1, 2])
        assert vf.accepted(parsed, problems) == {}
        assert any("disagrees" in p for p in problems[vf.VOTE])

    def test_a_failed_list_naming_the_wrong_criteria_is_refused(self):
        text = FAIL.replace("failed: [2]", "failed: [1]")
        parsed, problems = vf.parse_vote(text, task=TASK, expected_acs=[1, 2])
        assert vf.accepted(parsed, problems) == {}
        assert any("failed" in p for p in problems[vf.VOTE])

    def test_an_overall_red_over_only_amber_criteria_is_refused(self):
        text = FAIL.replace("Vote: red", "Vote: amber")
        parsed, problems = vf.parse_vote(text, task=TASK, expected_acs=[1, 2])
        assert vf.accepted(parsed, problems) == {}

    def test_prose_that_only_says_all_criteria_hold_is_refused(self):
        prose = ("I reviewed the task carefully. All criteria hold; the work is good.\n"
                 "VERDICT: green\nSummary: 1 green\n")
        parsed, problems = vf.parse_vote(prose, task=TASK, expected_acs=[1])
        assert vf.accepted(parsed, problems) == {}
        assert problems[vf.VOTE] and problems[1]

    def test_a_paraphrased_evidence_and_a_bare_page_location_are_refused(self):
        text = (PASS.replace('Evidence: "Vote format (verdict/1 — required, pass and fail alike)"',
                             "Evidence: the brief asks for it")
                .replace("Location: lib/reviewer/judge_cli.py:912", "Location: page 2"))
        parsed, problems = vf.parse_vote(text, task=TASK, expected_acs=[1])
        assert vf.accepted(parsed, problems) == {}
        assert len(problems[1]) == 2

    def test_unequal_evidence_and_location_pairs_are_refused(self):
        text = PASS.replace("Location: lib/reviewer/judge_cli.py:912\n",
                            "Location: lib/reviewer/judge_cli.py:912\nLocation: a.py:1\n")
        parsed, problems = vf.parse_vote(text, task=TASK, expected_acs=[1])
        assert vf.accepted(parsed, problems) == {}

    def test_two_vote_blocks_are_refused(self):
        parsed, problems = vf.parse_vote(PASS + PASS, task=TASK, expected_acs=[1])
        assert vf.accepted(parsed, problems) == {}

    def test_another_tasks_vote_is_refused(self):
        parsed, problems = vf.parse_vote(PASS, task="T-1", expected_acs=[1])
        assert vf.accepted(parsed, problems) == {}

    def test_a_criterion_the_brief_did_not_name_is_refused(self):
        parsed, problems = vf.parse_vote(PASS, task=TASK, expected_acs=[3])
        assert vf.accepted(parsed, problems) == {}
        assert problems.get(3)

    def test_markdown_bold_and_ansi_are_tolerated(self):
        text = "\x1b[1m" + PASS.replace("Vote: green", "**Vote:** green") + "\x1b[0m"
        parsed, problems = vf.parse_vote(text, task=TASK, expected_acs=[1])
        assert problems == {}


# ── the brief ────────────────────────────────────────────────────────────────

CRIT = [{"index": 1, "ac_index": 3, "body": "x", "render": False},
        {"index": 2, "ac_index": 5, "body": "y", "render": False}]


@pytest.mark.parametrize("kind", ["claude", "codex"])
def test_both_brief_variants_ask_for_verdict_1(kind):
    brief = judge_cli._build_brief(TASK, CRIT, rung=1, revision="abc", kind=kind)
    assert vf.brief_format(brief) == "verdict/1"
    for needle in ("===VERDICT===", "format: verdict/1", "failed:", "## AC3", "## AC5",
                   "Vote:", "Evidence:", "Location:", "Rule:", "Conclusion:", "Guidance:",
                   "## Counter-search", "Searched:", "Found:", "## Change-my-mind",
                   "region x,y,w,h", "selector <css>", "Vote: green", "Vote: red"):
        assert needle in brief, needle


def test_the_filled_example_in_the_brief_is_itself_a_valid_vote():
    brief = judge_cli._build_brief(TASK, CRIT, rung=1, revision="abc", kind="codex")
    parsed, problems = vf.parse_vote(brief, task=TASK, expected_acs=[3, 5])
    assert problems == {}, problems


def test_an_old_brief_has_no_format_and_keeps_the_old_reader():
    assert vf.brief_format("## Output format\nVERDICT: green\n") == ""
    assert vl.parse_harness_verdicts("1. [AC] x\nVERDICT: green\nWHY: y\n")[1]["outcome"] == "green"


def test_parse_printed_reads_a_verdict_1_block_and_refuses_a_malformed_one():
    crit = [{"index": 1, "ac_index": 1}, {"index": 2, "ac_index": 2}]
    fail = FAIL.replace(f"task: {TASK}", "task: T-9200")
    assert judge_cli._parse_printed(fail, crit) == {1: "green", 2: "red"}
    assert judge_cli._parse_printed(_drop(fail, "Rule:"), crit) == {1: "unknown", 2: "unknown"}


# ── harness parse with a verdict/1 brief ─────────────────────────────────────

def test_harness_parse_with_a_verdict_1_brief_keys_by_criterion_and_carries_structure():
    printed, problems = vl.parse_harness_vote(FAIL, task=TASK, crits=[(1, 1), (2, 2)])
    assert problems == {}
    assert printed[2]["outcome"] == "red" and printed[2]["guidance"].startswith("drop")
    assert printed[2]["structured"]["format"] == "verdict/1"
    assert "shot.png" in printed[2]["block"]


def test_harness_parse_refuses_the_old_free_text_when_the_brief_asked_for_verdict_1():
    printed, problems = vl.parse_harness_vote("1. [AC] x\nVERDICT: green\nWHY: all hold\n",
                                              task=TASK, crits=[(1, 1)])
    assert printed == {} and problems[vf.VOTE]


# ── rows ─────────────────────────────────────────────────────────────────────

def _old_row() -> dict:
    st = vl._STATE["green"]
    jv = {"contract": "judge_verdict/1", "judge": "r", "state": st,
          "judged": f"{TASK}#AC1", "guidance": "", "evidence": [], "ts": "x"}
    return {"id": "V-1", "ts": "x", "task": TASK, "ac": 1, "ac_digest": "d", "outcome": "green",
            "verdict": st, "guidance": "", "reviewer": "r", "dispatch_id": "dd",
            "rung": "1", "evidence": [], "judgement": jv}


def test_an_old_row_without_format_validates_and_hashes_exactly_as_before():
    row = _old_row()
    assert vl._structural_fault(row) == ""
    body = {"outcome": "green", "guidance": "", "evidence": [], "evidence_sha256": {},
            "ac_digest": "d", "revision": ""}
    import hashlib
    want = hashlib.sha256(json.dumps(body, sort_keys=True, separators=(",", ":")).encode()).hexdigest()
    assert vl.verdict_hash(row) == want


def test_a_new_row_carries_format_and_structure_and_its_hash_covers_them():
    parsed, problems = vf.parse_vote(PASS, task=TASK, expected_acs=[1])
    row = {**_old_row(), "format": "verdict/1", "structured": vf.accepted(parsed, problems)[1]}
    assert vl._structural_fault(row) == ""
    h = vl.verdict_hash(row)
    assert h != vl.verdict_hash(_old_row())
    row["structured"]["criterion"]["conclusion"] = "changed"
    assert vl.verdict_hash(row) != h


def test_a_row_whose_structure_disagrees_with_its_outcome_is_malformed():
    parsed, problems = vf.parse_vote(PASS, task=TASK, expected_acs=[1])
    row = {**_old_row(), "outcome": "red", "format": "verdict/1",
           "structured": vf.accepted(parsed, problems)[1]}
    row["judgement"] = {**row["judgement"], "state": vl._STATE["red"]}
    row["verdict"] = vl._STATE["red"]
    assert "structured" in vl._structural_fault(row)
    assert "format" in vl._structural_fault({**_old_row(), "format": "verdict/9", "structured": {}})


# ── self-recording seats: `record` validates the AC report ───────────────────

def test_report_check_accepts_a_valid_report_and_refuses_prose(tmp_path):
    rep = tmp_path / "AC1-d.md"
    rep.write_text(PASS + "\nfree notes after the vote\n")
    s, why = vl.check_vote_report(rep, task=TASK, ac=1, outcome="green")
    assert why == "" and s["criterion"]["vote"] == "green"
    rep.write_text("checked; all criteria hold\n")
    s, why = vl.check_vote_report(rep, task=TASK, ac=1, outcome="green")
    assert s is None and "verdict/1" in why
    assert "verdict/1 check: refused" in rep.read_text()       # the reason is in the report


def test_report_check_refuses_a_report_whose_vote_differs_from_the_recorded_outcome(tmp_path):
    rep = tmp_path / "AC1-d.md"
    rep.write_text(PASS)
    s, why = vl.check_vote_report(rep, task=TASK, ac=1, outcome="red")
    assert s is None and "green" in why


# ── end to end: a malformed vote gets no row, and its report says why ────────

from t3580_judge_cli_test import (  # noqa: E402,F401
    TASTE, TID, FakeWorker, _judge, _mk_task, _produce, repo)
from t3582_harness_kinds_test import _brief as _hbrief, _launch, hrepo  # noqa: E402,F401
import t3580_round3_test as r3  # noqa: E402
from _review_runtime import hermetic_review_env  # noqa: E402,F401  (autouse)


def test_self_recording_seat_with_a_prose_report_records_nothing(repo, monkeypatch):
    _mk_task(repo, TASTE)
    _produce(repo)
    monkeypatch.setattr(vf, "example_vote", lambda *a, **k: "Checked it. All criteria hold.\n")
    res = _judge(repo, dispatcher=FakeWorker("green"))
    assert res["outcomes"] == {1: "unknown"}
    assert "verdict/1" in res["dispatches"][0]["error"]
    assert not [r for r in vl._read(vl.VERDICTS, repo) if r.get("task") == TID]
    reps = list((repo / ".context/reviews/evidence" / TID).glob("AC1-*.md"))
    assert reps and "verdict/1 check: refused" in reps[0].read_text()


def test_self_recording_seat_with_a_valid_report_carries_the_structure(repo):
    _mk_task(repo, TASTE)
    _produce(repo)
    res = _judge(repo, dispatcher=FakeWorker("green"))
    assert res["outcomes"] == {1: "green"}
    rows = [r for r in vl._read(vl.VERDICTS, repo) if r.get("task") == TID]
    assert len(rows) == 1 and rows[0]["format"] == "verdict/1"
    assert rows[0]["structured"]["criterion"]["vote"] == "green"
    assert vl._structural_fault(rows[0]) == ""


def test_harness_seat_printing_prose_gets_no_row_and_its_report_says_why(hrepo):
    rev = r3._head(hrepo)
    did = "judge-t-9200-r1-codex-prose0000001"
    w, out, rc = _launch(hrepo, did=did, kind="codex", brief=_hbrief(hrepo, "codex", rev),
                         revision=rev, mode="prose")
    assert not [r for r in vl._read(vl.VERDICTS, hrepo) if r.get("dispatch_id") == did]
    rep = hrepo / ".context/reviews/evidence" / TID / f"AC1-{did}.md"
    assert rep.is_file() and "REFUSED" in rep.read_text() and "free text" in rep.read_text()


def test_harness_seat_printing_verdict_1_records_the_structure(hrepo):
    rev = r3._head(hrepo)
    did = "judge-t-9200-r1-codex-struct000001"
    w, out, rc = _launch(hrepo, did=did, kind="codex", brief=_hbrief(hrepo, "codex", rev),
                         revision=rev, mode="red")
    rows = [r for r in vl._read(vl.VERDICTS, hrepo) if r.get("dispatch_id") == did]
    assert len(rows) == 1 and rows[0]["format"] == "verdict/1" and rows[0]["outcome"] == "red"
    assert rows[0]["structured"]["header"]["failed"] == [1]
    comp = vl._completions_for(hrepo, did)[0]
    assert comp["verdicts"][0]["verdict_sha256"] == vl.verdict_hash(rows[0])


def test_an_empty_or_error_output_is_no_attempt_but_prose_with_a_verdict_line_is():
    assert not vf.attempted("")
    assert not vf.attempted('{"type":"error","error":{"name":"ProviderError"}}')
    assert vf.attempted("All criteria hold.\nVERDICT: green\n")
    assert vf.attempted(PASS)
