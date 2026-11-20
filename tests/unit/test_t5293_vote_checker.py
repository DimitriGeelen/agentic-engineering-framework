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

from PIL import Image  # noqa: E402

from lib import verdict_format as vf  # noqa: E402
from lib import verdict_ledger as vl  # noqa: E402
from lib import vote_checker as vc  # noqa: E402

TASK = "T-9200"
SHOT = f".context/working/judge-evidence/{TASK}/02-page.png"


def _git(root, *a):
    return subprocess.run(["git", *a], cwd=root, check=True, capture_output=True, text=True).stdout


@pytest.fixture
def src(tmp_path):
    """A small repo: header.css committed (the reviewed revision), a capture left untracked."""
    _git(tmp_path, "init", "-q")
    _git(tmp_path, "config", "user.email", "t@t")
    _git(tmp_path, "config", "user.name", "t")
    css = tmp_path / "web/static/css/header.css"
    css.parent.mkdir(parents=True)
    css.write_text(".a { color: red; }\n.settings {\n  display:   none;\n}\n.b { margin: 0; }\n")
    _git(tmp_path, "add", "-A")
    _git(tmp_path, "commit", "-qm", "base")
    rev = _git(tmp_path, "rev-parse", "HEAD").strip()
    shot = tmp_path / SHOT
    shot.parent.mkdir(parents=True)
    im = Image.new("RGB", (1280, 200), "white")
    for x in range(900, 960):          # the "icons" the T-5262 reference shows at 895,45,65,25
        for y in range(50, 65):
            im.putpixel((x, y), (0, 0, 0))
    im.save(shot)
    css.write_text("changed after the review\n")   # working tree differs from the revision
    return tmp_path, rev


def _vote(evidence_pairs, vote="red", rule='criterion: "the settings icon is visible"', ac=2,
          failed=None):
    lines = [vf.BEGIN, "format: verdict/1", f"task: {TASK}", "reviewer: seat", "round: 1",
             f"vote: {vote}", f"failed: [{'' if vote == 'green' else ac}]" if failed is None
             else f"failed: {failed}", "", f"## AC{ac} Settings icon visible",
             f"Vote: {vote}"]
    for e, l_ in evidence_pairs:
        lines += [f"Evidence: {e}", f"Location: {l_}"]
    lines += [f"Rule: {rule}", "Conclusion: so it holds or not."]
    if vote != "green":
        lines.append("Guidance: fix it")
    lines += ["", "## Counter-search", "Searched: x", "Found: y", "", "## Change-my-mind", "z", vf.END]
    parsed, problems = vf.parse_vote("\n".join(lines), task=TASK, expected_acs=[ac])
    return parsed, problems


# ── quotes and locations ─────────────────────────────────────────────────────

def test_quote_found_at_the_named_line_elsewhere_and_not_found(src):
    root, rev = src
    loc = "web/static/css/header.css"
    at = vc.check_quote(".settings {", f"{loc}:2", root, rev)
    assert at["result"] == "found-at-location" and at["location_exists"] is True
    assert at["source"].startswith("revision")           # read at the revision, not the tree
    el = vc.check_quote(".b { margin: 0; }", f"{loc}:1", root, rev)
    assert el["result"] == "found-elsewhere" and el["found_at_line"] == 5
    no = vc.check_quote("display: block", f"{loc}:3", root, rev)
    assert no["result"] == "not-found" and no["normalised"] == "not-found"


def test_whitespace_normalised_match_is_reported_separately(src):
    root, rev = src
    r = vc.check_quote("display: none;", "web/static/css/header.css:3", root, rev)
    assert r["result"] == "not-found" and r["normalised"] == "found-at-location"


def test_a_line_outside_the_file_and_a_missing_file(src):
    root, rev = src
    r = vc.check_quote(".a", "web/static/css/header.css:40-41", root, rev)
    assert r["location_exists"] is False and r["result"] == "found-elsewhere"
    m = vc.check_quote("x", "nope/missing.py:1", root, rev)
    assert m["location_exists"] is False and m["result"] == "not-found"


def test_a_command_location_is_not_run_and_not_checkable(src, tmp_path):
    root, rev = src
    flag = tmp_path / "ran"
    r = vc.check_quote("ok", f"command: touch {flag}", root, rev)
    assert r["result"] == "not-checkable" and not flag.exists()


# ── images ───────────────────────────────────────────────────────────────────

def test_region_inside_writes_the_crop_beside_the_evidence(src):
    root, rev = src
    r = vc.check_image(f"image: {SHOT} region 895,45,65,25", f"{SHOT} region 895,45,65,25",
                       root, rev, task=TASK)
    assert r["image_exists"] and r["region_inside"] is True and r["location_agrees"]
    assert r["crop"] == f".context/reviews/evidence/{TASK}/02-page-895_45_65_25-crop.png"
    with Image.open(root / r["crop"]) as im:
        assert im.size == (65, 25)
    assert not list((root / r["crop"]).parent.glob("*.tmp.*"))


def test_region_outside_the_image_and_a_missing_image(src):
    root, rev = src
    r = vc.check_image(f"image: {SHOT} region 1200,150,100,100", f"{SHOT} region 1200,150,100,100",
                       root, rev, task=TASK)
    assert r["region_inside"] is False and "crop" not in r and r["result"] == "problem"
    m = vc.check_image("image: gone.png region 0,0,1,1", "gone.png region 0,0,1,1", root, rev, task=TASK)
    assert m["image_exists"] is False and m["result"] == "problem"


def test_selector_is_named_and_a_location_naming_another_region_disagrees(src):
    root, rev = src
    s = vc.check_image(f"image: {SHOT} selector header .settings", f"{SHOT} selector header .settings",
                       root, rev, task=TASK)
    assert s["selector_named"] and s["selector"] == "header .settings" and s["location_agrees"]
    d = vc.check_image(f"image: {SHOT} region 0,0,10,10", f"{SHOT} region 0,0,20,20", root, rev, task=TASK)
    assert d["location_agrees"] is False


def test_png_header_gives_the_size_without_pil(src):
    root, _ = src
    data = (root / SHOT).read_bytes()
    assert vc.image_size(data) == (1280, 200)
    assert vc.image_size(b"not an image") is None


# ── seat run records ─────────────────────────────────────────────────────────

def _codex_record(d: Path, commands):
    d.mkdir(parents=True, exist_ok=True)
    ev: list = [{"type": "thread.started"}, {"type": "turn.started"}]
    for c in commands:
        it = {"type": "command_execution", "command": c, "aggregated_output": "", "status": "completed"}
        ev += [{"type": "item.started", "item": it}, {"type": "item.completed", "item": it}]
    ev += [{"type": "item.completed", "item": {"type": "agent_message", "text": "Opened all 11 screenshots"}},
           {"type": "turn.completed"}]
    (d / "result.jsonl").write_text("\n".join(json.dumps(e) for e in ev) + "\n")
    return d


def _claude_record(d: Path, read_paths):
    d.mkdir(parents=True, exist_ok=True)
    ev: list = [{"type": "system", "subtype": "init"}]
    for p in read_paths:
        ev.append({"type": "assistant", "message": {"content": [
            {"type": "tool_use", "name": "Read", "input": {"file_path": p}}]}})
        ev.append({"type": "user", "message": {"content": [{"type": "tool_result"}]}})
    ev.append({"type": "result", "subtype": "success"})
    (d / "result.jsonl").write_text("\n".join(json.dumps(e) for e in ev) + "\n")
    return d


def test_codex_record_with_only_commands_is_not_viewed(tmp_path):
    d = _codex_record(tmp_path / "codex", [f"ls -l .context/working/judge-evidence/{TASK}",
                                          f"cp {SHOT} .context/reviews/evidence/{TASK}/"])
    views = vc.seat_viewed_images(d)
    assert views is not None and vc.image_viewed(views, SHOT) is False
    assert "02-page.png" in views["__named_in_commands__"]


def test_codex_image_view_item_is_viewed(tmp_path):
    d = tmp_path / "cx"
    d.mkdir()
    (d / "result.jsonl").write_text(json.dumps(
        {"type": "item.completed", "item": {"type": "view_image", "path": f"/tmp/tree/{SHOT}"}}) + "\n")
    assert vc.image_viewed(vc.seat_viewed_images(d), SHOT) is True


def test_claude_read_of_the_png_or_its_copy_is_viewed(tmp_path):
    d = _claude_record(tmp_path / "cl", [f"/x/.context/reviews/evidence/{TASK}/02-page-judge-abc.png"])
    views = vc.seat_viewed_images(d)
    assert vc.image_viewed(views, SHOT) is True                 # matched by stem, copy name
    assert vc.image_viewed(views, "03-other.png") is False


def test_opencode_read_of_the_png_is_viewed(tmp_path):
    d = tmp_path / "oc"
    d.mkdir()
    (d / "result.jsonl").write_text(json.dumps({"type": "tool_use", "part": {
        "type": "tool", "tool": "read", "state": {"input": {"filePath": f"/t/{SHOT}"}}}}) + "\n")
    assert vc.image_viewed(vc.seat_viewed_images(d), SHOT) is True


def test_unknown_event_naming_the_image_is_cannot_tell(tmp_path):
    d = tmp_path / "cl2"
    d.mkdir()
    (d / "result.jsonl").write_text(json.dumps({"type": "assistant", "message": {"content": [
        {"type": "tool_use", "name": "mcp__x__look", "input": {"p": "02-page.png"}}]}}) + "\n")
    assert vc.image_viewed(vc.seat_viewed_images(d), SHOT) is None


def test_no_record_or_an_unknown_shape_is_cannot_tell_never_yes(tmp_path):
    d = tmp_path / "agy"
    d.mkdir()
    (d / "result.md").write_text("I opened every screenshot.\n")   # antigravity: final text only
    assert vc.seat_viewed_images(d) is None
    (d / "result.jsonl").write_text("not json\n")
    assert vc.seat_viewed_images(d) is None
    assert vc.image_viewed(None, SHOT) is None


# ── the whole vote ───────────────────────────────────────────────────────────

def test_t5262_case_red_on_a_region_showing_the_icons_from_a_seat_that_never_looked(src, tmp_path):
    root, rev = src
    parsed, problems = _vote([(f"image: {SHOT} region 895,45,65,25", f"{SHOT} region 895,45,65,25")])
    assert problems == {}
    seat = _codex_record(tmp_path / "judge-t-9200-r5-codex-000000000001",
                         [f"ls .context/working/judge-evidence/{TASK}", f"cp {SHOT} /tmp/x.png"])
    st = vf.accepted(parsed, problems)[2]
    res = vc.check_vote(st, root, rev, seat)
    img = res["criteria"]["2"]["items"][0]
    assert img["region_inside"] is True and img["crop"]           # the region is there, cropped
    with Image.open(root / img["crop"]) as im:                    # and shows the icons
        assert im.getpixel((10, 10)) == (0, 0, 0)
    assert img["seat_viewed"] is False                            # but the seat never opened it
    assert res["cites_image"] and res["seat_record_readable"]


def test_full_vote_complete_consistent_rule_and_quotes(src):
    root, rev = src
    parsed, problems = _vote([('"display:   none;"', "web/static/css/header.css:3"),
                              (f"image: {SHOT} selector .settings", f"{SHOT} selector .settings")])
    assert problems == {}
    res = vc.check_vote(parsed, root, rev, None, criterion_text="the settings icon is visible at every width")
    assert res["complete"] and res["consistent"]
    c = res["criteria"]["2"]
    assert c["rule"] == {"present": True, "quoted": "the settings icon is visible",
                         "quote_in_criterion": True}
    assert [i["result"] for i in c["items"]] == ["found-at-location", "ok"]
    assert c["items"][1]["seat_viewed"] is None and "no seat run record" in c["items"][1]["seat_viewed_why"]


def test_inconsistency_and_an_unknown_rule_quote_are_reported(src):
    root, rev = src
    parsed, _ = _vote([('".a"', "web/static/css/header.css:1")])
    st = vf.structure(parsed, 2)
    st["header"] = {**st["header"], "failed": []}                 # red but not listed in failed
    res = vc.check_vote(st, root, rev, None, criterion_text="something else entirely")
    assert res["consistent"] is False and res["inconsistent"]
    assert res["criteria"]["2"]["rule"]["quote_in_criterion"] is False
    st["criterion"] = {**st["criterion"], "rule": ""}
    res = vc.check_vote(st, root, rev, None)
    assert res["complete"] is False and res["criteria"]["2"]["rule"]["present"] is False


def test_safe_check_never_raises():
    out = vc.safe_check(None, "/nonexistent", "")
    assert "error" in out


# ── ledger rows ──────────────────────────────────────────────────────────────

def _old_row():
    return {"outcome": "green", "guidance": "", "evidence": ["a"], "evidence_sha256": {},
            "ac_digest": "d", "revision": "r"}


def test_hash_covers_check_only_when_present():
    old = _old_row()
    h_old = vl.verdict_hash(old)
    assert vl.verdict_hash({**old, "unrelated": 1}) == h_old
    row = {**old, "format": "verdict/1", "structured": {"x": 1}}
    h = vl.verdict_hash(row)
    with_check = {**row, "check": {"checker": vc.CHECKER, "complete": True}}
    assert vl.verdict_hash(with_check) != h
    with_check["check"]["complete"] = False
    assert vl.verdict_hash(with_check) != vl.verdict_hash({**row, "check": {"checker": vc.CHECKER,
                                                                             "complete": True}})


from t3580_judge_cli_test import (  # noqa: E402,F401
    TASTE, TID, FakeWorker, _judge, _mk_task, _produce, repo)
from t3582_harness_kinds_test import _brief as _hbrief, _launch, hrepo  # noqa: E402,F401
import t3580_round3_test as r3  # noqa: E402
from _review_runtime import hermetic_review_env  # noqa: E402,F401  (autouse)


def test_self_recording_row_carries_the_check(repo):
    _mk_task(repo, TASTE)
    _produce(repo)
    res = _judge(repo, dispatcher=FakeWorker("green"))
    assert res["outcomes"] == {1: "green"}
    rows = [r for r in vl._read(vl.VERDICTS, repo) if r.get("task") == TID]
    assert len(rows) == 1 and rows[0]["check"]["checker"] == vc.CHECKER
    assert "criteria" in rows[0]["check"] and vl._structural_fault(rows[0]) == ""


def test_harness_row_carries_the_check_and_its_hash_covers_it(hrepo):
    rev = r3._head(hrepo)
    did = "judge-t-9200-r1-codex-check0000001"
    _launch(hrepo, did=did, kind="codex", brief=_hbrief(hrepo, "codex", rev), revision=rev, mode="red")
    rows = [r for r in vl._read(vl.VERDICTS, hrepo) if r.get("dispatch_id") == did]
    assert len(rows) == 1 and rows[0]["check"]["checker"] == vc.CHECKER
    assert rows[0]["check"]["worker_kind"] == "codex"
    comp = vl._completions_for(hrepo, did)[0]
    assert comp["verdicts"][0]["verdict_sha256"] == vl.verdict_hash(rows[0])


def test_a_checker_crash_is_recorded_not_raised(monkeypatch, tmp_path):
    """The row's `check` holds the error; _vote_check (what `record` calls) never raises."""
    def boom(*a, **k):
        raise RuntimeError("checker broke")
    monkeypatch.setattr(vc, "check_vote", boom)
    out = vl._vote_check(tmp_path, {"task": TASK, "wdir": str(tmp_path)}, {"criterion": {}}, "", "c")
    assert "checker broke" in out["error"]
    out = vl._vote_check(tmp_path, None, {}, "", "c")            # even a broken dispatch record
    assert "error" in out


def test_rows_without_format_carry_no_check():
    """Old-format rows are unchanged: `check` is added only next to `structured`."""
    src_text = Path(vl.__file__).read_text()
    i = src_text.index("rec[\"check\"] = _vote_check(root")
    assert "if structured is not None:" in src_text[i - 500:i]


# ── T-5308: inner double quotes escaped as \" (the real T-5303 review) ───────

def test_t5308_escaped_inner_quotes_are_found_in_the_real_file():
    root = Path(__file__).resolve().parents[2]
    rev = subprocess.run(["git", "-C", str(root), "log", "-1", "--format=%H", "--", "web/app.py"],
                         capture_output=True, text=True).stdout.strip()
    line = subprocess.run(["git", "-C", str(root), "show", f"{rev}:web/app.py"],
                          capture_output=True, text=True).stdout.splitlines()
    n = next(i for i, l in enumerate(line, 1) if 'jinja_env.globals["fw_cmd"]' in l)
    written = 'app.jinja_env.globals[\\"fw_cmd\\"] = lambda args=\\"\\": _fw_us'   # as the seat wrote it
    r = vc.check_quote(written, f"web/app.py:{n}", root, rev)
    assert r["result"] == "found-at-location" and r.get("unescaped") is True


def test_t5308_absent_quote_with_escapes_is_still_not_found(src):
    root, rev = src
    r = vc.check_quote('display: \\"flex\\"', "web/static/css/header.css:3", root, rev)
    assert r["result"] == "not-found"


def test_t5308_unescape():
    assert vc._unescape('a[\\"b\\"] \\\\n') == 'a["b"] \\n'
    assert vc._unescape("plain") == "plain"
