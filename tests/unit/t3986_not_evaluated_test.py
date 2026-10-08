"""T-3986 (832 T-1082): a reviewer seat that could not evaluate must say NOT-EVALUATED, never vote.

Operator ruling 2026-10-07: a skewed judgement is never acceptable — "reporting amber for something
that has not been revealed gives a really skewed image". The ladder is: fix the seat (a writable
temp dir) → upstream → reassign to another seat kind → operator.

Runs through the real run.sh with stub harness binaries (fixtures from t3582_harness_kinds_test).
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

import pytest

_HERE = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(_HERE))
sys.path.insert(0, str(Path(__file__).resolve().parent))

from lib import judge_verdict  # noqa: E402
from lib import verdict_ledger as vl  # noqa: E402
from lib.reviewer import judge_cli  # noqa: E402
import _review_runtime as rt  # noqa: E402
import t3580_round3_test as r3  # noqa: E402
from t3580_judge_cli_test import NOCAP, TID, repo  # noqa: E402,F401
from t3582_harness_kinds_test import _brief, _launch, hrepo, hrepo_hi  # noqa: E402,F401

KV = {"claude": "anthropic", "codex": "openai", "opencode": "zai"}


def _crit(root):
    ctx = vl._task_ctx(root, TID)
    return ctx, next(x for x in vl.human_criteria(ctx.text) if x.index == 1)


def _rows(root, did):
    return [r for r in vl._read(vl.VERDICTS, root) if r.get("dispatch_id") == did]


def _panel(root, modes: dict[str, str], monkeypatch, *, reassign=False):
    """Run the judge on a rung-5 panel; `modes` is the stub verdict per worker kind."""
    rt.unbound_spend(monkeypatch)
    seen = []

    def dispatcher(*, task_id, brief, root, name, vendor, revision="", run_id="", seat=""):
        did = f"{name}-{len(seen) + 1:012x}"
        w, out, rc = _launch(root, did=did, kind=vendor, brief=brief, revision=revision,
                             run_id=run_id, seat=seat, mode=modes.get(vendor, "green"))
        seen.append({"did": did, "kind": vendor, "rc": rc})
        return did

    fn = judge_cli.judge_with_reassign if reassign else judge_cli.judge
    res = fn(TID, root, dispatcher=dispatcher, capture=NOCAP, worker_kinds=set(KV),
             kind_vendors=dict(KV))
    return res, seen


# ── 1. the vocabulary ────────────────────────────────────────────────────────────────────────

class TestVocabulary:
    def test_not_evaluated_is_an_outcome_and_needs_a_reason(self):
        assert vl.NOT_EVALUATED in vl.OUTCOMES
        assert vl._STATE[vl.NOT_EVALUATED] == judge_verdict.UNKNOWN
        with pytest.raises(judge_verdict.VerdictError):
            judge_verdict.verdict(vl._STATE[vl.NOT_EVALUATED], "", judged="x", judge="y")

    def test_printed_not_evaluated_is_parsed_not_dropped(self):
        out = vl.parse_harness_verdicts("1. [AC] x\nVERDICT: not-evaluated\nWHY: no browser\n"
                                        "GUIDANCE: needs a seat that can run playwright\n")
        assert out[1]["outcome"] == vl.NOT_EVALUATED and "playwright" in out[1]["guidance"]
        assert judge_cli._parse_printed("1. [AC] x\nVERDICT: not-evaluated\n",
                                        [{"index": 1}]) == {1: vl.NOT_EVALUATED}

    def test_every_brief_tells_the_seat_not_to_vote_on_what_it_did_not_see(self):
        for kind in ("claude", "codex"):
            b = _brief(Path("."), kind, "abc")
            assert "not-evaluated" in b and "Never vote on what you did not see" in b
        failed = judge_cli._build_brief(TID, [{"index": 1, "ac_index": 1, "body": "x", "render": True}],
                                        evidence={"needed": True, "shots": [], "error": "boom"})
        assert "Return `not-evaluated`" in failed and "not amber, not red" in failed


# ── 2. the seat's writable temp dir; the export it reviews is checked unchanged ───────────────

class TestSeatTempDir:
    def test_codex_seat_writes_its_temp_dir_and_the_export_is_untouched(self, hrepo):
        rev = r3._head(hrepo)
        did = "judge-t-9200-r1-codex-tmpdir000001"
        w, out, rc = _launch(hrepo, did=did, kind="codex", brief=_brief(hrepo, "codex", rev),
                             revision=rev)
        seen = json.loads(Path(str(w) + ".seen").read_text())
        assert seen["tmpdir"] == str(w / "tmp") and (w / "tmp" / "harness.tmp").is_file()
        assert (w / "exit_code").read_text().strip() == "0", (w / "stderr.log").read_text()
        assert [r["outcome"] for r in _rows(hrepo, did)] == ["green"]

    def test_a_seat_that_modifies_its_export_has_its_greens_voided(self, hrepo):
        rev = r3._head(hrepo)
        did = "judge-t-9200-r1-codex-touched00001"
        w, out, rc = _launch(hrepo, did=did, kind="codex", brief=_brief(hrepo, "codex", rev),
                             revision=rev, mode="green+touch")
        assert "modified the export it reviewed" in (w / "stderr.log").read_text()
        assert (w / "exit_code").read_text().strip() != "0"
        ctx, crit = _crit(hrepo)
        good, why = vl.satisfying_verdict(ctx, crit)
        assert good is None, why


# ── 3. a single seat that could not evaluate: no tick, no block, no operator routing ──────────

class TestSingleSeat:
    def test_not_evaluated_is_recorded_neither_ticks_nor_escalates(self, hrepo):
        rev = r3._head(hrepo)
        did = "judge-t-9200-r1-codex-noteval00001"
        _launch(hrepo, did=did, kind="codex", brief=_brief(hrepo, "codex", rev), revision=rev,
                mode="not-evaluated")
        rows = _rows(hrepo, did)
        assert [r["outcome"] for r in rows] == [vl.NOT_EVALUATED] and rows[0]["guidance"]
        ctx, crit = _crit(hrepo)
        good, why = vl.satisfying_verdict(ctx, crit)
        assert good is None and why.startswith("not-evaluated"), why
        assert "Reviewer escalation" not in ctx.text                    # not routed to the operator
        applied = [a for a in vl._read(vl.APPLIED, hrepo) if a.get("verdict_id") == rows[0]["id"]]
        assert applied == []
        vl.apply(TID, hrepo)
        assert not _crit(hrepo)[1].ticked

    def test_a_later_not_evaluated_does_not_withdraw_an_earlier_green(self, hrepo):
        rev = r3._head(hrepo)
        g = "judge-t-9200-r1-codex-green0000001"
        _launch(hrepo, did=g, kind="codex", brief=_brief(hrepo, "codex", rev), revision=rev)
        n = "judge-t-9200-r1-opencode-noteval01"
        _launch(hrepo, did=n, kind="opencode", brief=_brief(hrepo, "opencode", rev), revision=rev,
                mode="not-evaluated")
        assert [r["outcome"] for r in _rows(hrepo, n)] == [vl.NOT_EVALUATED]
        ctx, crit = _crit(hrepo)
        good, why = vl.satisfying_verdict(ctx, crit)
        assert good is not None and good["dispatch_id"] == g, why

    def test_control_a_later_red_still_withdraws_it(self, hrepo):
        rev = r3._head(hrepo)
        _launch(hrepo, did="judge-t-9200-r1-codex-green0000002", kind="codex",
                brief=_brief(hrepo, "codex", rev), revision=rev)
        _launch(hrepo, did="judge-t-9200-r1-opencode-red000001", kind="opencode",
                brief=_brief(hrepo, "opencode", rev), revision=rev, mode="red")
        ctx, crit = _crit(hrepo)
        good, why = vl.satisfying_verdict(ctx, crit)
        assert good is None and "red" in why


# ── 4. a rung-5 panel: the seats that evaluated decide ───────────────────────────────────────

class TestPanel:
    def test_two_evaluating_greens_and_one_not_evaluated_tick(self, hrepo_hi, monkeypatch):
        res, seen = _panel(hrepo_hi, {"codex": "not-evaluated"}, monkeypatch)
        assert [s["kind"] for s in seen] == ["claude", "codex", "opencode"], seen   # not stopped
        assert res["outcomes"] == {1: "green"}, res.get("why")
        ctx, crit = _crit(hrepo_hi)
        good, why = vl.satisfying_verdict(ctx, crit)
        assert good is not None, why

    def test_one_evaluating_green_is_not_enough_and_is_reassigned(self, hrepo_hi, monkeypatch):
        res, seen = _panel(hrepo_hi, {"codex": "not-evaluated", "opencode": "not-evaluated"},
                           monkeypatch, reassign=True)
        assert res["outcomes"][1] != "green", res
        assert res["reassigned"] and res["reassigned"][0]["excluded"] == ["codex", "opencode"], res
        ctx, crit = _crit(hrepo_hi)
        good, why = vl.satisfying_verdict(ctx, crit)
        assert good is None, why
        # The reassigned run (claude only) cannot seat a three-vendor panel: the operator's.
        assert res["outcomes"][1] in (vl.NOT_EVALUATED, judge_cli.UNKNOWN)
        assert res["why"][1].startswith("OPERATOR: no seat kind could evaluate"), res["why"]

    def test_control_an_evaluating_amber_still_blocks(self, hrepo_hi, monkeypatch):
        res, seen = _panel(hrepo_hi, {"codex": "amber"}, monkeypatch)
        assert [s["kind"] for s in seen] == ["claude", "codex"]               # stops at amber
        assert res["outcomes"][1] == "amber"
