"""T-5341: every committed codex render green must be backed by a peer seat in the same run
that voted green with a logged view of the images (lib/vote_checker's view rule)."""
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))
from lib import codex_render_backing as crb  # noqa: E402

IMG = ".context/visual/T-9/page@1024.png"


def _item(proof: str | None) -> dict:
    it = {"kind": "image", "image": IMG, "seat_viewed": proof is not None}
    if proof == "attached":
        it["seat_viewed_how"] = "attached at launch (T-5309)"
        it["view_proof"] = "attached"
    elif proof == "logged":
        it["view_proof"] = "logged"
    return it


def _row(seat: str, outcome: str = "green", *, run: str = "run-1", ac: int = 1,
         proof: str | None = "logged", cls: str = "render-surface", rid: str | None = None) -> dict:
    r = {"id": rid or f"V-{seat}-{run}", "task": "T-9", "ac": ac, "run_id": run,
         "reviewer": f"reviewer-judge-t-9-{seat}-aaaaaaaaaaaa:{seat}", "outcome": outcome,
         "criterion_class": cls, "dispatch_id": f"judge-t-9-{seat}-aaaaaaaaaaaa",
         "rung": "rung-5-panel:" + seat, "evidence": [IMG], "format": "verdict/1"}
    r["check"] = {"criteria": {str(ac): {"items": [_item(proof)]}}}
    return r


def _codex(**kw) -> dict:
    return _row("codex", proof="attached", **kw)


def _an(rows, tmp_path):
    return crb.analyse(rows, tmp_path, registry={})


def test_backed_by_logged_view_peer(tmp_path):
    res = _an([_codex(), _row("claude-code"), _row("antigravity", proof="attached")], tmp_path)
    assert res["count"] == 1 and res["backed"] == 1 and res["unbacked"] == []
    assert res["greens"][0]["backed_by"].startswith("claude-code")


def test_peer_green_attached_only_is_unbacked(tmp_path):
    res = _an([_codex(), _row("antigravity", proof="attached")], tmp_path)
    assert res["backed"] == 0 and len(res["unbacked"]) == 1
    assert "attached-only" in res["unbacked"][0]["why"]
    assert any(l.startswith("UNBACKED T-9 AC1") for l in crb.report_lines(res))


def test_peer_amber_is_unbacked(tmp_path):
    res = _an([_codex(), _row("claude-code", outcome="amber")], tmp_path)
    assert res["backed"] == 0 and "claude-code voted amber" in res["unbacked"][0]["why"]


def test_single_seat_run_is_unbacked(tmp_path):
    res = _an([_codex(run="run-solo")], tmp_path)
    assert res["count"] == 1 and res["unbacked"][0]["why"].startswith("no peer seat in the run")


def test_peer_in_other_run_or_other_ac_does_not_back(tmp_path):
    res = _an([_codex(), _row("claude-code", run="run-2"), _row("antigravity", ac=2)], tmp_path)
    assert res["backed"] == 0


def test_no_codex_render_greens_passes(tmp_path):
    rows = [_row("claude-code"), _codex(outcome="amber"), _codex(cls="unclassified", run="r9")]
    res = _an(rows, tmp_path)
    assert res["count"] == 0 and res["unbacked"] == []
    assert crb.report_lines(res)[-1] == "codex render greens: 0, backed by a viewing peer: 0"


def test_old_row_uses_seat_run_record(tmp_path):
    """A row with no recorded check: the seat's result.jsonl decides (vote_checker rules)."""
    peer = _row("claude-code")
    del peer["check"], peer["format"]
    wd = tmp_path / "wd"
    wd.mkdir()
    ev = {"type": "assistant", "message": {"content": [
        {"type": "tool_use", "name": "Read", "input": {"file_path": str(tmp_path / IMG)}}]}}
    (wd / "result.jsonl").write_text(json.dumps(ev) + "\n")
    reg = {peer["dispatch_id"]: str(wd)}
    assert crb.analyse([_codex(), peer], tmp_path, registry=reg)["backed"] == 1
    # attached manifest only, no logged Read → attached-only, unbacked
    (wd / "result.jsonl").write_text(json.dumps({"type": "result"}) + "\n")
    (wd / "attached-images.json").write_text(json.dumps({"attached": [{"path": IMG, "sha256": "x"}]}))
    res = crb.analyse([_codex(), peer], tmp_path, registry=reg)
    assert res["backed"] == 0 and "attached-only" in res["unbacked"][0]["why"]
    # no record at all → cannot show a view
    res = crb.analyse([_codex(), peer], tmp_path / "none", registry={})
    assert res["backed"] == 0 and "not on disk" in res["unbacked"][0]["why"]


def _git(d: Path, *a):
    subprocess.run(["git", "-C", str(d), *a], check=True, capture_output=True,
                   env={"GIT_AUTHOR_NAME": "t", "GIT_AUTHOR_EMAIL": "t@t", "GIT_COMMITTER_NAME": "t",
                        "GIT_COMMITTER_EMAIL": "t@t", "PATH": "/usr/bin:/bin", "HOME": str(d)})


def test_cli_uses_committed_rows_only(tmp_path):
    _git(tmp_path, "init", "-q")
    led = tmp_path / crb.VERDICTS
    led.parent.mkdir(parents=True)
    led.write_text(json.dumps(_row("claude-code", cls="unclassified")) + "\n")
    _git(tmp_path, "add", ".")
    _git(tmp_path, "commit", "-qm", "x")
    # an uncommitted unbacked codex green never counts
    with led.open("a") as fh:
        fh.write(json.dumps(_codex(run="solo")) + "\n")
    p = subprocess.run([sys.executable, str(ROOT / "lib/codex_render_backing.py"), "audit",
                        "--root", str(tmp_path)], capture_output=True, text=True)
    assert p.returncode == 0, p.stdout + p.stderr
    assert "codex render greens: 0" in p.stdout
    _git(tmp_path, "add", ".")
    _git(tmp_path, "commit", "-qm", "y")
    p = subprocess.run([sys.executable, str(ROOT / "lib/codex_render_backing.py"), "audit",
                        "--root", str(tmp_path)], capture_output=True, text=True)
    assert p.returncode == 1 and "UNBACKED T-9 AC1" in p.stdout


def test_cli_error_is_rc2_not_pass(tmp_path):
    p = subprocess.run([sys.executable, str(ROOT / "lib/codex_render_backing.py"), "audit",
                        "--root", str(tmp_path / "not-a-repo")], capture_output=True, text=True)
    assert p.returncode == 2 and p.stdout.startswith("ERROR")


#: Measured 2026-11-21 (T-5341 Context): the 8 rung-5 codex render greens, all backed.
RUNG5 = {"V-20261118-78758b41", "V-20261118-01cc1300", "V-20261118-e8c2bea4", "V-20261120-f26149c6",
         "V-20261120-186cf24f", "V-20261120-0e780694", "V-20261120-627f9b9b", "V-20261120-836a2b4c"}


def test_live_ledger():
    res = crb.analyse(crb.committed_rows(ROOT), ROOT)
    assert res["count"] >= 9
    by_id = {g["id"]: g for g in res["greens"]}
    assert RUNG5 <= set(by_id)
    assert all("backed_by" in by_id[i] for i in RUNG5), [by_id[i] for i in RUNG5 if "why" in by_id[i]]
    assert "V-20261121-b5203aa7" in {u["id"] for u in res["unbacked"]}   # T-5344, single seat
