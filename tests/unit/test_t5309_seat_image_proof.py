"""T-5309: proof that a harness seat saw the screenshots it votes on.

Codex never chose to open screenshots in judge runs (T-5289), so the review runtime attaches every
screenshot the brief cites at launch (`codex exec -i <file>`) and records the list with sha256 in
the dispatch dir (attached-images.json). Antigravity runs with `--output-format stream-json`; its
read_file steps are its record. The checker (lib/vote_checker.py):
  - codex, attached           → viewed (by content hash, so a renamed copy still matches)
  - codex, not attached, no view → not viewed
  - antigravity read_file of the image → viewed; without one → not viewed
  - no record at all          → cannot tell
"""

import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path

import pytest

_HERE = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(_HERE))

from PIL import Image  # noqa: E402

from lib import review_seat_evidence as rse  # noqa: E402
from lib import verdict_format as vf  # noqa: E402
from lib import vote_checker as vc  # noqa: E402

TASK = "T-9309"
SHOT = f".context/working/judge-evidence/{TASK}/02-page.png"
SHOT2 = f".context/visual/{TASK}/arc@1440.png"
TERMLINK = _HERE / "agents/termlink/termlink.sh"


def _png(path: Path, colour: object = "white", size=(64, 32)) -> bytes:
    path.parent.mkdir(parents=True, exist_ok=True)
    Image.new("RGB", size, colour).save(path)
    return path.read_bytes()


def _agy_record(d: Path, reads: list[str], commands: tuple = ()) -> Path:
    """An antigravity stream-json run record, shaped like the 2026-11-20 probe (trimmed)."""
    d.mkdir(parents=True, exist_ok=True)
    ev = [{"event": "init", "conversation_id": "c1", "init": {"cwd": "/tmp/tree"}},
          {"event": "step_update", "step_update": {"conversation_id": "c1", "step_index": 0,
                                                   "state": "DONE", "step_type": "user_input"}}]
    i = 1
    for c in commands:
        ev.append({"event": "step_update", "step_update": {
            "step_index": i, "state": "DONE", "step_type": "tool", "tool_name": "run_command",
            "tool_info": {"name": "run_command", "parameters": {"CommandLine": c}}}})
        i += 1
    for p in reads:
        for state in ("ACTIVE", "DONE"):
            ev.append({"event": "step_update", "step_update": {
                "step_index": i, "state": state, "step_type": "tool", "tool_name": "read_file",
                "tool_info": {"name": "read_file", "parameters": {"Path": p}}}})
        i += 1
    ev.append({"event": "result", "result": {"conversation_id": "c1", "status": "SUCCESS",
                                             "response": "CARDS: 8\n"}})
    (d / "result.jsonl").write_text("\n".join(json.dumps(e) for e in ev) + "\n")
    return d


def _codex_commands_only(d: Path, commands: list[str]) -> Path:
    d.mkdir(parents=True, exist_ok=True)
    ev = [{"type": "thread.started", "thread_id": "t"}]
    ev += [{"type": "item.completed", "item": {"type": "command_execution", "command": c}}
           for c in commands]
    ev.append({"type": "turn.completed"})
    (d / "result.jsonl").write_text("\n".join(json.dumps(e) for e in ev) + "\n")
    return d


@pytest.fixture
def evidence(tmp_path):
    """A project with two cited screenshots, a brief citing them, and the export tree."""
    proj = tmp_path / "proj"
    data1 = _png(proj / SHOT, "white")
    data2 = _png(proj / SHOT2, "black")
    brief = (f"Screenshots: `{SHOT}` and `{SHOT2}`; also `.context/working/judge-evidence/{TASK}/"
             f"notes.txt` and `.context/project/secret.yaml`.\n")
    (proj / f".context/working/judge-evidence/{TASK}/notes.txt").write_text("n\n")
    tree = tmp_path / "wdir/tree"
    tree.mkdir(parents=True)
    return proj, brief, tree, data1, data2


# ── the codex launch: attach every cited screenshot ─────────────────────────────────────────

def test_manifest_lists_each_cited_image_with_its_hash(evidence):
    proj, brief, tree, data1, data2 = evidence
    copied = rse.copy_cited(brief, proj, tree)
    m = rse.image_manifest(copied, tree)
    assert [a["path"] for a in m["attached"]] == [SHOT, SHOT2]          # images only, brief order
    assert [a["sha256"] for a in m["attached"]] == [hashlib.sha256(data1).hexdigest(),
                                                    hashlib.sha256(data2).hexdigest()]
    assert m["not_attached"] == []


def test_codex_argv_has_dash_i_for_each_named_screenshot(evidence):
    proj, brief, tree, *_ = evidence
    m = rse.image_manifest(rse.copy_cited(brief, proj, tree), tree)
    argv = rse.codex_image_argv(m)
    assert argv == ["-i", str(tree / SHOT), "-i", str(tree / SHOT2)]


def test_cli_writes_manifest_and_prints_nul_separated_args(evidence, tmp_path):
    proj, brief, tree, *_ = evidence
    b = tmp_path / "brief.md"
    b.write_text(brief)
    man = tmp_path / "wdir/attached-images.json"
    script = _HERE / "lib/review_seat_evidence.py"
    subprocess.run([sys.executable, str(script), str(b), str(proj), str(tree), "--manifest", str(man)],
                   check=True, capture_output=True)
    assert json.loads(man.read_text())["attached"][0]["path"] == SHOT
    out = subprocess.run([sys.executable, str(script), "--codex-args", str(man)], check=True,
                         capture_output=True).stdout
    assert out.split(b"\0")[:-1] == [b"-i", str(tree / SHOT).encode(), b"-i", str(tree / SHOT2).encode()]
    # no manifest: no args, exit 0
    none = subprocess.run([sys.executable, str(script), "--codex-args", str(tmp_path / "nope.json")],
                          capture_output=True)
    assert none.returncode == 0 and none.stdout == b""


def test_over_the_cap_the_rest_are_recorded_not_attached(tmp_path):
    tree = tmp_path / "tree"
    rels = [f".context/visual/{TASK}/s{i}.png" for i in range(4)]
    for i, r in enumerate(rels):
        _png(tree / r, (i, i, i))
    m = rse.image_manifest(rels, tree, cap=2)
    assert [a["path"] for a in m["attached"]] == rels[:2]
    assert [a["path"] for a in m["not_attached"]] == rels[2:]
    assert all("cap" in a["why"] for a in m["not_attached"])


def test_runtime_codex_launch_passes_the_image_args_before_other_flags():
    s = TERMLINK.read_text()
    assert '--manifest "$WDIR/attached-images.json"' in s
    assert "--codex-args \"$WDIR/attached-images.json\"" in s
    line = next(ln for ln in s.splitlines() if '"$WORKER_BIN" exec ' in ln and "workspace-write" in ln)
    # -i takes several values: the image args must be followed by a flag, never by the prompt.
    assert re.search(r'"\$WORKER_BIN" exec \$\{CODEX_IMAGE_ARGS\[@\]\+"\$\{CODEX_IMAGE_ARGS\[@\]\}"\} -s ', line)


def test_runtime_antigravity_runs_stream_json_into_result_jsonl():
    s = TERMLINK.read_text()
    line = next(ln for ln in s.splitlines() if "/usr/bin/sudo -n -u dimitri-mint-dev" in ln
                and '"$WORKER_BIN" -p' in ln)
    assert "--output-format stream-json" in line and '> "$WDIR/result.jsonl"' in line


# ── the checker ─────────────────────────────────────────────────────────────────────────────

def test_codex_attached_is_viewed_by_hash_even_under_another_name(evidence):
    proj, brief, tree, data1, _ = evidence
    wdir = tree.parent
    _codex_commands_only(wdir, ["ls"])
    rse.write_manifest(wdir / rse.MANIFEST_NAME, rse.image_manifest(rse.copy_cited(brief, proj, tree), tree))
    views = vc.seat_viewed_images(wdir)
    assert vc.image_viewed(views, SHOT) is True
    sha = hashlib.sha256(data1).hexdigest()
    assert vc.image_viewed(views, ".context/reviews/evidence/x/renamed.png", sha) is True
    assert vc.image_viewed(views, ".context/reviews/evidence/x/other.png", "0" * 64) is False


def test_codex_not_attached_and_not_viewed_is_not_viewed(tmp_path):
    d = _codex_commands_only(tmp_path / "cx", [f"cp {SHOT} /tmp/x.png"])
    views = vc.seat_viewed_images(d)
    assert views is not None and vc.image_viewed(views, SHOT) is False


def test_manifest_alone_is_a_record(evidence):
    proj, brief, tree, *_ = evidence
    wdir = tree.parent
    m = rse.image_manifest(rse.copy_cited(brief, proj, tree), tree)
    m["attached"] = m["attached"][:1]
    rse.write_manifest(wdir / rse.MANIFEST_NAME, m)
    views = vc.seat_viewed_images(wdir)                     # no result.jsonl
    assert vc.image_viewed(views, SHOT) is True
    assert vc.image_viewed(views, SHOT2) is False


def test_antigravity_read_file_of_the_image_is_viewed(tmp_path):
    d = _agy_record(tmp_path / "agy", [f"/x/wdir/tree/{SHOT}"])
    views = vc.seat_viewed_images(d)
    assert vc.image_viewed(views, SHOT) is True
    assert vc.image_viewed(views, SHOT2) is False


def test_antigravity_without_an_image_read_is_not_viewed(tmp_path):
    d = _agy_record(tmp_path / "agy", ["/x/wdir/tree/README.md"], commands=[f"file {SHOT}"])
    views = vc.seat_viewed_images(d)
    assert views is not None and vc.image_viewed(views, SHOT) is False
    assert "02-page.png" in views["__named_in_commands__"]


def test_antigravity_unknown_tool_naming_the_image_is_cannot_tell(tmp_path):
    d = tmp_path / "agy"
    d.mkdir()
    (d / "result.jsonl").write_text(json.dumps({"event": "step_update", "step_update": {
        "step_type": "tool", "tool_name": "call_mcp_tool",
        "tool_info": {"name": "call_mcp_tool", "parameters": {"x": "02-page.png"}}}}) + "\n")
    assert vc.image_viewed(vc.seat_viewed_images(d), SHOT) is None


def test_missing_record_is_cannot_tell(tmp_path):
    d = tmp_path / "none"
    d.mkdir()
    (d / "result.md").write_text("I opened every screenshot.\n")
    assert vc.seat_viewed_images(d) is None
    assert vc.image_viewed(vc.seat_viewed_images(d), SHOT) is None


def test_check_vote_counts_an_attached_screenshot_as_viewed(evidence):
    proj, brief, tree, *_ = evidence
    subprocess.run(["git", "init", "-q"], cwd=proj, check=True)
    subprocess.run(["git", "-c", "user.email=t@t", "-c", "user.name=t", "commit", "-q",
                    "--allow-empty", "-m", "base"], cwd=proj, check=True)
    rev = subprocess.run(["git", "rev-parse", "HEAD"], cwd=proj, check=True, capture_output=True,
                         text=True).stdout.strip()
    wdir = tree.parent / "judge-t-9309-r5-codex-000000000001"
    wdir.mkdir()
    _codex_commands_only(wdir, ["ls"])
    rse.write_manifest(wdir / rse.MANIFEST_NAME,
                       rse.image_manifest(rse.copy_cited(brief, proj, tree), tree))
    lines = [vf.BEGIN, "format: verdict/1", f"task: {TASK}", "reviewer: seat", "round: 1",
             "vote: green", "failed: []", "", "## AC2 Settings icon visible", "Vote: green",
             f"Evidence: image: {SHOT} region 0,0,10,10", f"Location: {SHOT} region 0,0,10,10",
             'Rule: criterion: "icon visible"', "Conclusion: it holds.", "",
             "## Counter-search", "Searched: x", "Found: y", "", "## Change-my-mind", "z", vf.END]
    parsed, problems = vf.parse_vote("\n".join(lines), task=TASK, expected_acs=[2])
    assert problems == {}
    res = vc.check_vote(vf.accepted(parsed, problems)[2], proj, rev, wdir, write_crops=False)
    img = res["criteria"]["2"]["items"][0]
    assert img["seat_viewed"] is True and "attached" in img["seat_viewed_how"]
