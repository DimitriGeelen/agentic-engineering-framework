"""T-3852 (ring20 T-2194): a review seat that ends WITHOUT a verdict for an availability reason
(vendor usage limit, rate limit, crash, missing binary) is UNAVAILABLE, not a verdict. It is
reassigned the way a not-evaluated seat is — the criterion re-runs with that kind excluded, so the
next registry seat fills the panel — and the reason is named wherever the result is reported.

Field case: rung 5, seat codex hit its usage limit (result.jsonl turn.failed), exit 1, no ledger
row; the panel ended `unknown (no-ledger-row)` and never reached the spare seat.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

import pytest

_HERE = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(_HERE))
sys.path.insert(0, str(Path(__file__).resolve().parent))

from lib import verdict_ledger as vl  # noqa: E402
from lib.reviewer import judge_cli  # noqa: E402
import _review_runtime as rt  # noqa: E402
import t3582_harness_kinds_test as hk  # noqa: E402
from t3580_judge_cli_test import NOCAP, TID, FakeWorker, repo  # noqa: E402,F401

# The panel's registry order plus the spare seat (policy/review-backends.yaml: antigravity).
KV4 = {"claude": "anthropic", "codex": "openai", "opencode": "zai", "antigravity": "google"}


@pytest.fixture()
def hrepo4(repo, monkeypatch):
    """A rung-5 fixture registry with the spare antigravity seat after claude, codex, opencode."""
    monkeypatch.setitem(hk._STUBS, "antigravity", hk._OPENCODE)
    return hk._hrepo(repo, hk.HI)


@pytest.fixture()
def wdirs(tmp_path, monkeypatch):
    """Where the dispatcher keeps worker dirs (lib/dispatch_tokens.dispatch_dir)."""
    d = tmp_path / "tl-dispatch"
    monkeypatch.setenv("FW_DISPATCH_DIR", str(d))
    return d


def _dead_seat(wdirs: Path, did: str, *, exit_code: int, stream: list[dict] | None = None) -> None:
    """A worker dir for a seat that exited without writing a ledger row."""
    w = wdirs / did
    w.mkdir(parents=True)
    (w / "exit_code").write_text(f"{exit_code}\n")
    if stream is not None:
        (w / "result.jsonl").write_text("".join(json.dumps(e) + "\n" for e in stream))


USAGE = [{"type": "turn.failed", "error": {"message": "You've hit your usage limit. Try again later."}}]


def _panel(root, monkeypatch, *, dead: dict[str, dict], modes: dict[str, str] | None = None,
           reassign: bool = True, wdirs: Path):
    """Run the rung-5 judge. `dead[kind]` = kwargs for _dead_seat (that seat writes no row);
    every other kind runs the real run.sh with stub harness binaries, verdict `modes[kind]`."""
    rt.unbound_spend(monkeypatch)
    seen = []
    spare = FakeWorker("green")   # antigravity's run.sh launch needs sudo as another user
    real_dispatch = rt.dispatch

    def dispatch_pinned(root, did, task, **kw):
        # The fixture registry pins the stub as the spare kind's binary; register that one.
        return real_dispatch(root, did, task, worker_bin=str(hk._stub_dir(Path(root)) / "antigravity"),
                             **kw)

    monkeypatch.setattr(rt, "dispatch", dispatch_pinned)

    def dispatcher(*, task_id, brief, root, name, vendor, revision="", run_id="", seat=""):
        did = f"{name}-{len(seen) + 1:012x}"
        if vendor in dead:
            _dead_seat(wdirs, did, **dead[vendor])
            seen.append({"did": did, "kind": vendor, "rows": 0})
            return did
        if vendor == "antigravity":
            did = spare(task_id=task_id, brief=brief, root=root, name=name, vendor=vendor,
                        revision=revision, run_id=run_id, seat=seat)
            seen.append({"did": did, "kind": vendor})
            return did
        _w, _out, rc = hk._launch(root, did=did, kind=vendor, brief=brief, revision=revision,
                                  run_id=run_id, seat=seat, mode=(modes or {}).get(vendor, "green"))
        seen.append({"did": did, "kind": vendor, "rc": rc})
        return did

    fn = judge_cli.judge_with_reassign if reassign else judge_cli.judge
    res = fn(TID, root, dispatcher=dispatcher, capture=NOCAP, worker_kinds=set(KV4),
             kind_vendors=dict(KV4))
    return res, seen


def _crit(root):
    ctx = vl._task_ctx(root, TID)
    return ctx, next(x for x in vl.human_criteria(ctx.text) if x.index == 1)


class TestUnavailableSeatIsReassigned:
    def test_a_seat_that_exits_with_no_row_is_reassigned_and_the_panel_completes_green(
            self, hrepo4, monkeypatch, wdirs):
        res, seen = _panel(hrepo4, monkeypatch, dead={"codex": dict(exit_code=1, stream=USAGE)},
                           wdirs=wdirs)
        # Pre-fix: the panel stopped at codex and the criterion stayed unknown (no-ledger-row).
        assert [s["kind"] for s in seen][:2] == ["claude", "codex"], seen
        assert "antigravity" in [s["kind"] for s in seen], seen   # the spare seat ran
        assert res["reassigned"] and res["reassigned"][0]["excluded"] == ["codex"], res
        assert res["reassigned"][0]["unavailable"] == {"codex": "usage limit (exit 1)"}, res
        assert res["outcomes"][1] == vl.GREEN, res.get("why")
        ctx, crit = _crit(hrepo4)
        good, why = vl.satisfying_verdict(ctx, crit)
        assert good is not None, why

    def test_control_an_amber_seat_is_a_verdict_and_is_not_reassigned(
            self, hrepo4, monkeypatch, wdirs):
        res, seen = _panel(hrepo4, monkeypatch, dead={}, modes={"codex": "amber"}, wdirs=wdirs)
        assert [s["kind"] for s in seen] == ["claude", "codex"], seen   # stops at the amber
        assert res["outcomes"][1] == "amber", res
        assert res["reassigned"] == [], res
        codex = next(d for d in res["dispatches"] if d.get("kind") == "codex")
        assert codex["results"][0]["source"] == "ledger", codex
        assert "unavailable" not in codex["results"][0], codex


class TestOperatorWhenEveryKindIsUnavailable:
    def test_the_operator_message_names_each_unavailable_seat_and_its_reason(
            self, hrepo4, monkeypatch, wdirs):
        dead = {"claude": dict(exit_code=2), "codex": dict(exit_code=1, stream=USAGE),
                "opencode": dict(exit_code=3), "antigravity": dict(exit_code=1, stream=[
                    {"type": "error", "message": "429 Too Many Requests: rate limit"}])}
        res, _seen = _panel(hrepo4, monkeypatch, dead=dead, wdirs=wdirs)
        assert res["outcomes"][1] in (vl.NOT_EVALUATED, judge_cli.UNKNOWN), res
        why = res["why"][1]
        assert why.startswith("OPERATOR: no seat kind could evaluate"), why
        assert "codex (usage limit (exit 1))" in why, why
        assert "opencode (exit 3)" in why and "antigravity (rate limit (exit 1))" in why, why

    def test_t4010_exit_code_3_holds_when_nothing_was_recorded(self, hrepo4, monkeypatch, wdirs):
        dead = {k: dict(exit_code=1) for k in KV4}
        res, _seen = _panel(hrepo4, monkeypatch, dead=dead, wdirs=wdirs)
        assert res["code"] == 3, res
        assert "no review seat recorded a verdict" in res["no_seat_recorded"]


class TestReasonExtraction:
    def test_usage_limit_is_named_with_the_exit_status(self, wdirs):
        _dead_seat(wdirs, "judge-x-1", exit_code=1, stream=USAGE)
        assert judge_cli._unavailable_reason("judge-x-1") == "usage limit (exit 1)"

    def test_rate_limit_is_named(self, wdirs):
        _dead_seat(wdirs, "judge-x-2", exit_code=1, stream=[{"type": "error", "message": "HTTP 429"}])
        assert judge_cli._unavailable_reason("judge-x-2") == "rate limit (exit 1)"

    def test_a_bare_exit_status_is_named(self, wdirs):
        _dead_seat(wdirs, "judge-x-3", exit_code=127)
        assert judge_cli._unavailable_reason("judge-x-3") == "exit 127"

    def test_no_completion_at_all_is_named_and_is_short(self, wdirs):
        assert judge_cli._unavailable_reason("judge-never-ran") == "no completion"

    def test_the_reason_is_short_and_carries_no_raw_log(self, wdirs):
        raw = "x" * 5000
        _dead_seat(wdirs, "judge-x-4", exit_code=1, stream=[{"type": "error", "message": raw}])
        assert len(judge_cli._unavailable_reason("judge-x-4")) <= 40
