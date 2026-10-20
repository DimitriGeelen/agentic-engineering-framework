"""T-4456 — an antigravity seat that exits 0 because headless mode auto-denied its command tool
is reported unavailable with that reason, not as a bare 'exit 0'."""
from __future__ import annotations

import json
import sys
from pathlib import Path

_HERE = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(_HERE))
sys.path.insert(0, str(Path(__file__).resolve().parent))

from lib.reviewer import judge_cli  # noqa: E402
from _review_runtime import hermetic_review_env  # noqa: E402,F401  (autouse)
import t3852_unavailable_seat_test as ut  # noqa: E402
from t3852_unavailable_seat_test import wdirs  # noqa: E402,F401

DENIED = ("jetski: no output produced — a tool required the command permission that headless "
          "mode cannot prompt for, so it was auto-denied. Add an allow-rule under permissions.allow\n")


def test_exit_zero_with_an_auto_denied_command_tool_is_named(wdirs):
    ut._dead_seat(wdirs, "judge-a-1", exit_code=0)
    (wdirs / "judge-a-1" / "result.md").write_text(DENIED)
    assert judge_cli._unavailable_reason("judge-a-1") == "tool permission auto-denied (headless) (exit 0)"


def test_the_denial_in_stderr_is_found_too(wdirs):
    ut._dead_seat(wdirs, "judge-a-2", exit_code=0)
    (wdirs / "judge-a-2" / "stderr.log").write_text(DENIED)
    assert "auto-denied" in judge_cli._unavailable_reason("judge-a-2")


def test_control_a_silent_exit_zero_stays_a_bare_exit(wdirs):
    ut._dead_seat(wdirs, "judge-a-3", exit_code=0)
    assert judge_cli._unavailable_reason("judge-a-3") == "exit 0"


# ── a seat whose printed verdict the LEDGER refused is not unavailable ───────────────────────
# Field case (AEF 2026-10-20, T-4490): antigravity printed a full review; record-for-worker
# refused it ("the screenshot of '/config' is not cited as evidence") into refusals-interim.jsonl,
# and the judge reported the seat `unavailable: exit 0`.

from lib import verdict_ledger as vl  # noqa: E402
from t3580_judge_cli_test import TASTE, TID, _mk_task, repo  # noqa: E402,F401

REASON = "the screenshot of '/config' is not cited as evidence"


def _refuse(root: Path, did: str, ac: int = 1) -> None:
    p = root / vl.REFUSALS
    p.parent.mkdir(parents=True, exist_ok=True)
    with p.open("a") as f:
        f.write(json.dumps({"ac": ac, "class": "unseen-page", "dispatch_id": did,
                            "gate": "reviewer-verdict", "reason": REASON, "task": TID}) + "\n")


def _crits(root: Path) -> list[dict]:
    _mk_task(root, TASTE)
    ctx = vl._task_ctx(root, TID)
    return [{"ac_index": c.index, "index": c.index} for c in vl.human_criteria(ctx.text)][:1]


def test_a_refused_verdict_is_named_and_the_seat_is_not_unavailable(repo, wdirs):
    ut._dead_seat(wdirs, "judge-r-1", exit_code=0)
    _refuse(repo, "judge-r-1")
    res = judge_cli._collect(repo, TID, "judge-r-1", _crits(repo))[0]
    assert res["source"] == "verdict-refused", res
    assert REASON in res["why"], res
    assert "unavailable" not in res, res


def test_control_no_refusal_for_this_dispatch_stays_unavailable(repo, wdirs):
    ut._dead_seat(wdirs, "judge-r-2", exit_code=0)
    _refuse(repo, "judge-r-other")
    res = judge_cli._collect(repo, TID, "judge-r-2", _crits(repo))[0]
    assert res["source"] == "no-ledger-row" and res["unavailable"] == "exit 0", res
