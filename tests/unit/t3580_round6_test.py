"""T-3580 round 6: the second-family (codex) review — RED — docs/reports/T-3580-second-family-codex.md.

1. HIGH   the ledger enforces the IW-7 rung the task requires, computed by the ONE policy function
          `judge` uses (lib/review_policy.py), at record AND apply. A review dispatch is bound to
          its authorised run at REGISTRATION (before launch); a step-down needs a ceiling decision
          the ledger re-derives. Negative control: an unbound, lower-rung review of a high-impact
          task does not tick.
Fixtures only; no real task is judged (sovereignty hold).
"""
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

import pytest

_HERE = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(_HERE))
sys.path.insert(0, str(Path(__file__).resolve().parent))

from lib import review_policy  # noqa: E402
from lib import verdict_ledger as vl  # noqa: E402
from lib.reviewer import judge_cli  # noqa: E402
import _review_runtime as rt  # noqa: E402
from t3580_judge_cli_test import (  # noqa: E402,F401
    NOCAP, TASTE, TID, FakeWorker, _judge, _mk_task, _produce, repo,
)
from t3580_round2_test import _commit_as, _crit, _ctx  # noqa: E402
from t3580_round3_test import HI, _record, _why  # noqa: E402

R1 = "rung-1-same-vendor-independent"
R3 = "rung-3-termlink-single-reviewer"


def _ticked(root):
    return [t["ac"] for t in vl.apply(TID, root)["ticked"]]


@pytest.fixture()
def hi(repo):
    """A high-impact task (blast_radius 9): IW-7 requires a rung-5 panel."""
    _mk_task(repo, TASTE, extra_fm=HI)
    (repo / "notes.md").write_text("notes v1\n")
    _produce(repo)
    return repo


def _seat_green(root, did, *, run_id="", seat="", rung=R1):
    rt.dispatch(root, did, TID, run_id=run_id, seat=seat)
    _record(root, did, rung=rung, **({"run_id": run_id} if run_id else {}))
    _commit_as(root, f"reviewer-{did}")
    rt.finish(root, did)


def _spend(root, cost, ts=None):
    p = root / review_policy.SPEND_LOG
    p.parent.mkdir(parents=True, exist_ok=True)
    with p.open("a") as f:
        f.write(json.dumps({"ts": ts or datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
                            "task": "T-1", "rung": 5, "cost": cost}) + "\n")


# ── 1. HIGH: the ledger enforces the required rung ───────────────────────────────────────────

class TestRequiredRung:
    def test_the_policy_says_rung_5_for_this_fixture(self, hi):
        assert vl.required_strength(_ctx(hi), _crit(hi))[0] == 5

    def test_negative_control_unbound_lower_rung_review_of_a_high_impact_task_is_refused(self, hi):
        """The review's named negative control: a real review dispatch, no run, `--rung` 1."""
        rt.dispatch(hi, "rv-1", TID)
        with pytest.raises(vl.VerdictRefused, match="requires rung 5.*not bound to an authorised"):
            _record(hi, "rv-1", rung=R1)

    def test_negative_control_at_apply_the_same_row_does_not_tick(self, hi, monkeypatch):
        """Application side: the row gets past `record` (its strength check bypassed), is
        committed by its worker and completed by the runtime; apply still ticks nothing."""
        rt.dispatch(hi, "rv-1", TID)
        with monkeypatch.context() as m:
            m.setattr(vl, "_strength_fault", lambda *a, **k: None)
            _record(hi, "rv-1", rung=R1)
        _commit_as(hi, "reviewer-rv-1")
        rt.finish(hi, "rv-1")
        assert _ticked(hi) == []
        assert "under-strength" in _why(hi) and "requires rung 5" in _why(hi)

    def test_negative_a_run_below_the_required_rung_without_a_ceiling_decision(self, hi):
        vl.register_run("run-3", TID, acs=[1], rung=R3, seats=[{"seat": "claude", "vendor": "c"}],
                        root=hi)
        rt.dispatch(hi, "rv-1", TID, run_id="run-3", seat="claude")
        with pytest.raises(vl.VerdictRefused, match="is rung 3 with no ceiling decision"):
            _record(hi, "rv-1", rung=R3, run_id="run-3")

    def test_negative_the_row_claims_a_rung_its_run_did_not_authorise(self, repo):
        _mk_task(repo, TASTE)          # low impact: rung 1 required
        _produce(repo)
        vl.register_run("run-1", TID, acs=[1], rung=R1, seats=[{"seat": "claude", "vendor": "c"}],
                        root=repo)
        rt.dispatch(repo, "rv-1", TID, run_id="run-1", seat="claude")
        with pytest.raises(vl.VerdictRefused, match="claims rung 5; its run 'run-1' authorised rung 1"):
            _record(repo, "rv-1", rung="rung-5-panel:claude", run_id="run-1")

    def test_negative_a_panel_run_that_asks_for_one_vendor(self, hi):
        seats = [{"seat": s, "vendor": s} for s in "abc"]
        vl.register_run("run-p", TID, acs=[1], rung="rung-5-panel", seats=seats, required_vendors=1,
                        root=hi)
        rt.dispatch(hi, "rv-a", TID, run_id="run-p", seat="a")
        with pytest.raises(vl.VerdictRefused, match="requires 1 vendor"):
            _record(hi, "rv-a", rung="rung-5-panel:a", run_id="run-p")

    def test_control_a_low_impact_task_needs_no_run(self, repo):
        _mk_task(repo, TASTE)
        _produce(repo)
        _seat_green(repo, "rv-1")
        assert _ticked(repo) == [1]

    def test_lowering_the_risk_fields_after_the_review_does_not_lower_the_requirement(self, hi):
        """Scored at the reviewed revision too: the task at dispatch time said blast_radius 9."""
        rt.dispatch(hi, "rv-1", TID)
        f = next((hi / ".tasks" / "active").glob(f"{TID}-*.md"))
        f.write_text(f.read_text().replace("blast_radius: 9", "blast_radius: 0"))
        assert review_policy.required_rung(vl.frontmatter(f.read_text()), [""])[0] == 1
        with pytest.raises(vl.VerdictRefused, match="requires rung 5"):
            _record(hi, "rv-1", rung=R1)


class TestBoundBeforeLaunch:
    def _run(self, root, run_id="run-3", seats=("claude",)):
        vl.register_run(run_id, TID, acs=[1], rung=R3,
                        seats=[{"seat": s, "vendor": s} for s in seats], root=root)

    def test_the_binding_is_in_the_signed_registration(self, hi):
        self._run(hi)
        rt.dispatch(hi, "rv-1", TID, run_id="run-3", seat="claude")
        rec, why = vl.dispatch_record(hi, "rv-1")
        assert why == "" and rec["run_id"] == "run-3" and rec["seat"] == "claude"
        run, bind, _ = vl.run_for_dispatch(hi, "rv-1")
        assert run["run_id"] == "run-3" and bind["seat"] == "claude"

    def test_negative_there_is_no_post_launch_bind(self):
        assert not hasattr(vl, "bind_dispatch")

    def test_negative_a_seat_is_dispatched_once(self, hi):
        self._run(hi)
        rt.dispatch(hi, "rv-1", TID, run_id="run-3", seat="claude")
        with pytest.raises(ValueError, match="already dispatched"):
            rt.dispatch(hi, "rv-2", TID, run_id="run-3", seat="claude")

    @pytest.mark.parametrize("run_id,seat,needle", [
        ("run-none", "claude", "not registered"),
        ("run-3", "nobody", "not a seat of run"),
    ])
    def test_negative_an_unknown_run_or_seat_is_refused_at_registration(self, hi, run_id, seat, needle):
        self._run(hi)
        with pytest.raises(ValueError, match=needle):
            rt.dispatch(hi, "rv-1", TID, run_id=run_id, seat=seat)

    def test_negative_a_run_for_another_task(self, hi):
        vl.register_run("run-o", "T-1", acs=[1], rung=R3, seats=[{"seat": "claude", "vendor": "c"}],
                        root=hi)
        with pytest.raises(ValueError, match="is for 'T-1'"):
            rt.dispatch(hi, "rv-1", TID, run_id="run-o", seat="claude")

    def test_negative_editing_the_binding_breaks_the_registration_signature(self, hi):
        self._run(hi)
        self._run(hi, "run-5")
        rt.dispatch(hi, "rv-1", TID, run_id="run-3", seat="claude")
        p = hi / vl.DISPATCHES
        rows = [json.loads(x) for x in p.read_text().splitlines()]
        rows[-1]["run_id"] = "run-5"
        p.write_text("".join(json.dumps(r) + "\n" for r in rows))
        assert vl.dispatch_record(hi, "rv-1")[0] is None

    def test_the_judge_passes_run_and_seat_to_the_dispatcher(self, hi):
        argv = judge_cli._dispatch_argv(Path("fw"), task_id=TID, name="n", prompt_file=Path("p"),
                                        root=hi, vendor="claude", timeout=1, run_id="run-x",
                                        seat="claude")
        assert argv[argv.index("--review-run") + 1] == "run-x"
        assert argv[argv.index("--review-seat") + 1] == "claude"
        src = (_HERE / "agents" / "termlink" / "termlink.sh").read_text()
        body = src[src.index("\ncmd_dispatch() {"):src.index("<<'RUNEOF'")]
        assert "--review-run|--review-seat)" in body
        assert '--run-id "$review_run"' in body and '--seat "$review_seat"' in body


class TestCeilingDecision:
    """A step-down is allowed only through a recorded decision the ledger re-derives."""

    def _stepped(self, root, *, spent=9.0, ceiling="10"):
        """The judge's path: ceiling reached, rung 5 due, rung 3 granted, decision in the run."""
        _spend(root, spent)
        import os
        os.environ[f"FW_{review_policy.CEILING_KEY}"] = ceiling
        dec = review_policy.ceiling_decision(root, 5, "blast_radius=9")
        assert dec["granted"] == 3
        vl.register_run("run-c", TID, acs=[1], rung=R3, seats=[{"seat": "claude", "vendor": "c"}],
                        ceiling_decision=dec, root=root)
        return dec

    @pytest.fixture(autouse=True)
    def _env(self, monkeypatch):
        monkeypatch.delenv(f"FW_{review_policy.CEILING_KEY}", raising=False)
        yield

    def test_control_a_verified_step_down_counts_and_ticks(self, hi):
        self._stepped(hi)
        _seat_green(hi, "rv-1", run_id="run-c", seat="claude", rung=R3)
        assert _ticked(hi) == [1]

    def test_negative_a_decision_the_spend_log_does_not_back(self, hi):
        dec = self._stepped(hi)
        (hi / review_policy.SPEND_LOG).write_text("")           # the spend it cited is gone
        rt.dispatch(hi, "rv-1", TID, run_id="run-c", seat="claude")
        with pytest.raises(vl.VerdictRefused, match="ceiling-unverified|spend-log lines"):
            _record(hi, "rv-1", rung=R3, run_id="run-c")
        assert dec["spend_lines"] == 1

    def test_negative_a_raised_ceiling_withdraws_the_step_down(self, hi, monkeypatch):
        self._stepped(hi)
        _seat_green(hi, "rv-1", run_id="run-c", seat="claude", rung=R3)
        monkeypatch.setenv(f"FW_{review_policy.CEILING_KEY}", "1000")
        assert _ticked(hi) == [] and "ceiling-unverified" in _why(hi)

    def test_negative_a_hand_written_decision_that_does_not_re_derive(self, hi):
        dec = review_policy.ceiling_decision(hi, 5)          # nothing spent: rung 5 granted
        dec.update(granted=3)                                 # ... claimed as a step-down
        vl.register_run("run-f", TID, acs=[1], rung=R3, seats=[{"seat": "claude", "vendor": "c"}],
                        ceiling_decision=dec, root=hi)
        rt.dispatch(hi, "rv-1", TID, run_id="run-f", seat="claude")
        with pytest.raises(vl.VerdictRefused, match="is granted 5, not the recorded 3"):
            _record(hi, "rv-1", rung=R3, run_id="run-f")

    def test_negative_a_decision_that_steps_down_twice(self, hi):
        dec = self._stepped(hi, spent=99)
        dec2 = dict(dec, granted=1)
        vl.register_run("run-1", TID, acs=[1], rung=R1, seats=[{"seat": "claude", "vendor": "c"}],
                        ceiling_decision=dec2, root=hi)
        rt.dispatch(hi, "rv-1", TID, run_id="run-1", seat="claude")
        with pytest.raises(vl.VerdictRefused, match="granted 3, not the recorded 1"):
            _record(hi, "rv-1", rung=R1, run_id="run-1")


class TestOnePolicy:
    def test_judge_and_ledger_call_the_same_function(self, monkeypatch):
        calls = []
        real = review_policy.required_rung

        def spy(fm, bodies):
            calls.append(1)
            return real(fm, bodies)
        monkeypatch.setattr(review_policy, "required_rung", spy)
        judge_cli._calculate_rung({"frontmatter": {"name": "x"}}, [])
        assert calls
        import inspect
        assert "review_policy.required_rung" in inspect.getsource(vl.required_strength)
        assert "_IRREVERSIBLE_RE" not in inspect.getsource(judge_cli)

    def test_application_judge_at_the_ceiling_records_a_decision_that_the_ledger_accepts(
            self, hi, monkeypatch):
        """End to end: the judge steps rung 5 down to 3 at the ceiling, the run carries the
        decision, the worker's green is accepted by record and ticks at apply."""
        _spend(hi, 9.0)
        monkeypatch.setenv(f"FW_{review_policy.CEILING_KEY}", "10")
        res = _judge(hi, dispatcher=FakeWorker("green"), worker_kinds={"claude"},
                     kind_vendors={"claude": "anthropic"})
        assert res["rung_due"] == 5 and res["rung"] == 3, res.get("ceiling_note")
        run = next(r for r in vl._read(vl.RUNS, hi) if r.get("kind") == "run")
        assert run["ceiling_decision"]["due"] == 5 and run["ceiling_decision"]["granted"] == 3
        assert res["outcomes"] == {1: "green"}
        assert _ticked(hi) == [1]
