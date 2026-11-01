"""T-4944 (operator 2026-11-01, "vision-gated"): a harness review seat (codex, opencode) could
never record a render green, because the runtime cited only the seat's report. A probe showed
codex sees a supplied screenshot and opencode cannot (docs/reports/T-4944-harness-seat-vision.md).

Pinned here:
  - the registry's `vision` field is boolean or absent;
  - the runtime cites a run's screenshot for a seat only when the committed registry says the
    kind can see AND the seat named that file in its verdict;
  - a judge with a render criterion does not seat a kind declared `vision: false`.
"""
from __future__ import annotations

import sys
from pathlib import Path

import pytest
import yaml

_HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(_HERE.parent.parent))
sys.path.insert(0, str(_HERE))

from lib import review_cost as rc  # noqa: E402
from lib import verdict_ledger as vl  # noqa: E402

REG = _HERE.parent.parent / "policy" / "review-backends.yaml"


def _registry(tmp_path, **vision):
    data = yaml.safe_load(REG.read_text())
    for b in data["backends"]:
        if b.get("worker_kind") in vision:
            b["vision"] = vision[b["worker_kind"]]
    p = tmp_path / "reg.yaml"
    p.write_text(yaml.safe_dump(data))
    return p


def test_vision_must_be_boolean(tmp_path):
    with pytest.raises(rc.CostError, match="vision must be true/false"):
        rc.load_registry(_registry(tmp_path, codex="yes"))


def test_committed_registry_declares_the_probed_kinds():
    got = rc.worker_vision(REG)
    assert got["codex"] is True and got["opencode"] is False


def test_absent_vision_is_unknown_not_false(tmp_path):
    data = yaml.safe_load(REG.read_text())
    for b in data["backends"]:
        b.pop("vision", None)
    p = tmp_path / "reg.yaml"
    p.write_text(yaml.safe_dump(data))
    assert rc.worker_vision(p) == {}


# ── the runtime's citation on a seat's behalf ───────────────────────────────

RUN = {"captures": [{"page": "/approvals", "ok": True, "path": ".context/working/judge-evidence/T-9/01-approvals.png"},
                    {"page": "/x", "ok": False, "path": ".context/working/judge-evidence/T-9/02-x.png"}],
       "visual": {"shots": [{"path": ".context/visual/T-9/arc-closure@1440.png"},
                            {"path": ".context/visual/T-9/arc-closure@1920.png"}]}}


@pytest.fixture
def seat_env(tmp_path, monkeypatch):
    for rel in (RUN["captures"][0]["path"], RUN["captures"][1]["path"],
                RUN["visual"]["shots"][0]["path"], RUN["visual"]["shots"][1]["path"]):
        (tmp_path / rel).parent.mkdir(parents=True, exist_ok=True)
        (tmp_path / rel).write_bytes(b"png")
    monkeypatch.setattr(vl, "run_for_dispatch", lambda root, did: (RUN, {}, ""))
    return tmp_path


def _named(root, monkeypatch, kinds, kind, block):
    monkeypatch.setattr(vl, "kind_vision", lambda root, revision="": kinds)
    return vl._seat_named_screenshots(root, "d1", kind, "rev", {"block": block})


def test_vision_seat_is_cited_only_for_files_it_named(seat_env, monkeypatch):
    block = ("1. [AC1] VERDICT: green\nWHY: arc-closure@1440.png shows 8 cards; 01-approvals.png "
             "loads; 02-x.png too")
    got = _named(seat_env, monkeypatch, {"codex": True}, "codex", block)
    assert got == [".context/working/judge-evidence/T-9/01-approvals.png",
                   ".context/visual/T-9/arc-closure@1440.png"]     # not the failed capture, not @1920


def test_blind_or_unknown_kind_is_never_cited(seat_env, monkeypatch):
    block = "1. [AC1] VERDICT: green\nWHY: 01-approvals.png arc-closure@1440.png"
    assert _named(seat_env, monkeypatch, {"opencode": False}, "opencode", block) == []
    assert _named(seat_env, monkeypatch, {}, "codex", block) == []


def test_a_named_file_that_is_missing_is_not_cited(seat_env, monkeypatch):
    (seat_env / RUN["visual"]["shots"][0]["path"]).unlink()
    got = _named(seat_env, monkeypatch, {"codex": True}, "codex", "WHY: arc-closure@1440.png")
    assert got == []


# ── the judge does not seat a blind kind on a render criterion ──────────────

def test_judge_excludes_blind_kinds_only_for_render_criteria(monkeypatch, tmp_path):
    from lib.reviewer import judge_cli
    seen = {}

    def plan(root, rung, kinds, kv=None, exclude_kinds=frozenset()):
        seen["exclude"] = set(exclude_kinds)
        raise RuntimeError("stop after planning")
    monkeypatch.setattr(judge_cli, "_plan_seats", plan)
    monkeypatch.setattr(vl, "kind_vision", lambda root, revision="": {"codex": True, "opencode": False})
    monkeypatch.setattr(vl, "_head_sha", lambda root: "0" * 40)
    monkeypatch.setattr(vl, "task_required_strength", lambda *a, **k: (3, "test"))
    monkeypatch.setattr(judge_cli.review_policy, "ceiling_decision",
                        lambda *a, **k: {"granted": 3, "note": "", "spent": 0, "ceiling": 0})
    for render in (True, False):
        crit = {"ac_index": 1, "text": "t", "class": "render-surface" if render else "taste",
                "render": render, "body": "b", "index": 1}
        monkeypatch.setattr(judge_cli, "_partition", lambda *a, **k: ([crit], []))
        monkeypatch.setattr(judge_cli, "_load_task", lambda *a, **k: {"text": "", "path": tmp_path / "t.md"},
                            raising=False)
        try:
            res = judge_cli.judge("T-9", tmp_path, dry_run=True, worker_kinds={"codex", "opencode"},
                                  kind_vendors={"codex": "openai", "opencode": "zai"}, model_preflight=False)
        except Exception:  # noqa: BLE001 - anything before planning is not under test here
            res = {}
        assert "exclude" in seen, f"judge stopped before seat planning: {res.get('error')!r}"
        assert ("opencode" in seen["exclude"]) is render
        seen.clear()
