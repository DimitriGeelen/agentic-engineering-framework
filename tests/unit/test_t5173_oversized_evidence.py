"""T-5173: evidence over the large-file commit limit is caught where it is made.

T-5167: 12-13 MB full-page screenshots made the review runtime's verdict commit fail after the
reviewer had worked; the green stayed uncommitted, fw audit FAILed, the operator had to discard
it, and the judge printed the hook message cut mid-word ('ould not be in git').
"""
from __future__ import annotations

import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))
sys.path.insert(0, str(ROOT / "agents" / "ux-review"))
sys.path.insert(0, str(Path(__file__).resolve().parent))

from lib import large_file_limit  # noqa: E402
from lib import verdict_ledger as vl  # noqa: E402
from lib.reviewer import judge_cli  # noqa: E402
import ux_shots  # noqa: E402
from _review_runtime import hermetic_review_env  # noqa: E402,F401  (autouse)
from t3580_judge_cli_test import NOCAP, RENDER, TID, _mk_task, repo  # noqa: E402,F401


# ── the limit is read the way the git guard reads it ─────────────────────────────────────────

def test_limit_default_and_env(monkeypatch):
    monkeypatch.delenv("FW_LARGE_FILE_BLOCK_BYTES", raising=False)
    assert large_file_limit.block_bytes() == 10_485_760
    monkeypatch.setenv("FW_LARGE_FILE_BLOCK_BYTES", "2048")
    assert large_file_limit.block_bytes() == 2048
    for bad in ("", "x", "0", "-5"):
        monkeypatch.setenv("FW_LARGE_FILE_BLOCK_BYTES", bad)
        assert large_file_limit.block_bytes() == 10_485_760


def test_guard_default_matches_the_shell_guard():
    sh = (ROOT / "agents/git/lib/large-file-scan.sh").read_text()
    assert f"echo {large_file_limit.DEFAULT_BLOCK_BYTES}" in sh


# ── fw ux shots reports oversized shots ──────────────────────────────────────────────────────

def test_size_report(tmp_path, monkeypatch):
    monkeypatch.setenv("FW_LARGE_FILE_BLOCK_BYTES", "1000")
    small, half, big = tmp_path / "a.png", tmp_path / "b.png", tmp_path / "c.png"
    small.write_bytes(b"x" * 100)
    half.write_bytes(b"x" * 600)
    big.write_bytes(b"x" * 1500)
    errors, warnings_ = ux_shots.size_report([small, half, big])
    assert len(errors) == 1 and str(big) in errors[0] and "crop" in errors[0]
    assert len(warnings_) == 1 and str(half) in warnings_[0]


def test_main_exits_nonzero_on_an_oversized_shot(tmp_path, monkeypatch, capsys):
    monkeypatch.setenv("FW_LARGE_FILE_BLOCK_BYTES", "1000")

    def fake_capture(shots):
        out = []
        for s in shots:
            Path(s.path).parent.mkdir(parents=True, exist_ok=True)
            Path(s.path).write_bytes(b"x" * 1500)
            out.append(s.path)
        return out
    monkeypatch.setattr(ux_shots, "capture", fake_capture)
    monkeypatch.setattr(ux_shots, "write_manifests", lambda *a, **k: None)
    rc = ux_shots.main(["T-9", "page=http://127.0.0.1:9/x", "--root", str(tmp_path),
                        "--widths", "1024,1440,1920"])
    assert rc == ux_shots.EXIT_OVERSIZED
    assert capsys.readouterr().err.count("ERROR") == 3


# ── the judge refuses before anything is dispatched ──────────────────────────────────────────

def test_oversized_evidence_lists_captures_and_visual_shots(tmp_path, monkeypatch):
    monkeypatch.setenv("FW_LARGE_FILE_BLOCK_BYTES", "1000")
    (tmp_path / "cap.png").write_bytes(b"x" * 1500)
    (tmp_path / "vis.png").write_bytes(b"x" * 1500)
    (tmp_path / "ok.png").write_bytes(b"x" * 10)
    ev = {"shots": ["cap.png", "ok.png"], "visual": {"shots": [{"path": "vis.png"}, {"path": "ok.png"}]}}
    assert sorted(p for p, _ in judge_cli._oversized_evidence(tmp_path, ev)) == ["cap.png", "vis.png"]


def test_judge_refuses_and_registers_nothing(repo, monkeypatch):
    _mk_task(repo, RENDER)
    monkeypatch.setenv("FW_LARGE_FILE_BLOCK_BYTES", "1000")
    big = repo / ".context/visual" / TID / "page@1024.png"
    big.parent.mkdir(parents=True, exist_ok=True)
    big.write_bytes(b"x" * 1500)
    rel = str(big.relative_to(repo))

    def fake_evidence(*a, **k):
        return {"needed": True, "pages": ["/review"], "shots": [], "error": "", "captures": [],
                "partial": [], "visual": {"shots": [{"path": rel}]}}
    monkeypatch.setattr(judge_cli, "_gather_evidence", fake_evidence)
    monkeypatch.setattr(vl, "register_run", lambda *a, **k: pytest.fail("a run was registered"))
    res = judge_cli.judge(TID, repo, capture=NOCAP)
    assert res["code"] == 1
    assert "nothing dispatched" in res["error"] and rel in res["error"] and "crop" in res["error"]


# ── a refused commit keeps the start of git's message ────────────────────────────────────────

def test_clip_keeps_the_start():
    msg = "BLOCKED: a/b.png is 13 MB and should not be in git: unstage it\n" + "detail " * 400
    out = vl._clip_git_error(msg)
    assert out.startswith("BLOCKED: a/b.png is 13 MB and should not be in git")
    assert "characters cut" in out and out.endswith(msg.strip()[-300:])
    assert vl._clip_git_error("short error") == "short error"
