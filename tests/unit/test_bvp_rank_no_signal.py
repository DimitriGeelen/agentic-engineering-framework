"""T-4486: `fw bvp rank --include-proposed` excludes all-no-signal proposals from the
medians and quadrants and lists them in a NOTE block."""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import test_bvp_cli_rank_proposed as base  # noqa: E402

bvp = base.bvp
NO_SIG = ("D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 (no-signal)")


def _task(tmp_path, tid, scores, rationale, cost):
    d = tmp_path / ".tasks" / "active"
    d.mkdir(parents=True, exist_ok=True)
    (tmp_path / ".tasks" / "completed").mkdir(exist_ok=True)
    lines = ["---", f"id: {tid}", f'name: "{tid} t"', "status: started-work",
             "workflow_type: build", "owner: agent", "horizon: now",
             "bvp_scores_proposed:", "  - ts: '2026-10-20T00:00:00Z'", "    scores:"]
    lines += [f"      {k}: {v}" for k, v in scores.items()]
    if rationale:
        lines.append(f"    rationale: {rationale}")
    lines += ["cost_estimate_proposed:", "  - ts: '2026-10-20T00:00:00Z'",
              "    cost_estimate:", f"      blast_radius: {cost}", "      tier: 2",
              "      effort: 2", "---", "body"]
    (d / f"{tid}-t.md").write_text("\n".join(lines) + "\n")


def _fm(scores, rationale):
    return {"bvp_scores_proposed": [{"scores": scores, "rationale": rationale}]}


def test_detector_true_only_when_every_driver_no_signal():
    s = {"D1": 0, "D2": 0, "D3": 0, "D4": 0}
    assert bvp._proposal_is_all_no_signal(_fm(s, NO_SIG)) is True
    mixed = "D1=4 (body:x); D2=0 (no-signal); D3=0 (no-signal); D4=0 (no-signal)"
    assert bvp._proposal_is_all_no_signal(_fm(s, mixed)) is False


def test_detector_false_when_it_cannot_tell():
    s = {"D1": 0}
    assert bvp._proposal_is_all_no_signal({}) is False
    assert bvp._proposal_is_all_no_signal(_fm(s, None)) is False
    assert bvp._proposal_is_all_no_signal(_fm(s, "  ")) is False
    assert bvp._proposal_is_all_no_signal(_fm({}, NO_SIG)) is False


def test_rank_excludes_all_no_signal_and_lists_note(tmp_path):
    sig = {"D1": 5, "D2": 5, "D3": 5, "D4": 5}
    for tid, cost in (("T-99101", 1), ("T-99102", 8)):
        _task(tmp_path, tid, sig, "D1=5 (body:a); D2=5 (body:b); D3=5 (body:c); D4=5 (body:d)", cost)
    _task(tmp_path, "T-99103", {"D1": 0, "D2": 0, "D3": 0, "D4": 0}, NO_SIG, 1)
    out, _e, rc = base._run_fw_bvp(tmp_path, "--include-proposed")
    assert rc == 0
    assert "NOTE: 1/3 task(s) (33%) scored every driver no-signal" in out
    assert "Unassessed: T-99103" in out
    row = next(l for l in out.splitlines() if l.startswith("T-99103"))
    assert row.split()[4] == "-"
    # the no-signal task did not drag the median: the signal tasks still get quadrants
    for tid in ("T-99101", "T-99102"):
        r = next(l for l in out.splitlines() if l.startswith(tid))
        assert r.split()[4] != "-"


def test_rank_without_no_signal_proposals_has_no_note(tmp_path):
    sig = {"D1": 4, "D2": 3, "D3": 3, "D4": 2}
    _task(tmp_path, "T-99111", sig, "D1=4 (body:a); D2=3 (body:b); D3=3 (body:c); D4=2 (body:d)", 2)
    _task(tmp_path, "T-99112", {"D1": 1, "D2": 1, "D3": 0, "D4": 0}, "D1=1 (body:a); D2=1 (body:b); D3=0 (no-signal); D4=0 (no-signal)", 5)
    out, _e, rc = base._run_fw_bvp(tmp_path, "--include-proposed")
    assert rc == 0
    assert "no-signal — the estimator" not in out
    assert "Unassessed" not in out
    assert "T-99111" in out and "T-99112" in out
