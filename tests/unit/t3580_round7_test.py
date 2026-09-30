"""T-3580 round 7 — targeted fixes from the round-6 reviews:
docs/reports/T-3580-round6-review-codex.md (codex, RED) and docs/reports/T-3580-round4-review.md
"## Round 6 review" (Claude, AMBER). Each class opens with the reviewer's probe (red before the fix).

1. The ceiling step-down lever (codex HIGH-1 + MEDIUM-2, Claude F1).
Fixtures only; no real task is judged (sovereignty hold).
"""
import json
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

import pytest

_HERE = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(_HERE))
sys.path.insert(0, str(Path(__file__).resolve().parent))

from lib import review_policy as rp  # noqa: E402
from lib import verdict_ledger as vl  # noqa: E402
import _review_runtime as rt  # noqa: E402
from t3580_judge_cli_test import TASTE, TID, _mk_task, _produce, repo  # noqa: E402,F401
from t3580_round2_test import _commit_as, _crit, _ctx  # noqa: E402
from t3580_round3_test import HI, _record, _why  # noqa: E402

R3 = "rung-3-termlink-single-reviewer"
_TS = "%Y-%m-%dT%H:%M:%SZ"
CEIL = f"FW_{rp.CEILING_KEY}"


def _git(root, *args):
    subprocess.run(["git", "-C", str(root), *args], check=True, capture_output=True,
                   env={"GIT_AUTHOR_NAME": "Cost Clerk", "GIT_AUTHOR_EMAIL": "c@x",
                        "GIT_COMMITTER_NAME": "Cost Clerk", "GIT_COMMITTER_EMAIL": "c@x",
                        "PATH": "/usr/bin:/bin"})


def _cost(root, amount, *, ts=None, commit=True, purpose="reviewer-judge run-x seat claude"):
    """One reviewer-judge row in the cost ledger, committed (by a non-producer, no task id)."""
    p = root / rp.COST_LEDGER
    p.parent.mkdir(parents=True, exist_ok=True)
    with p.open("a") as f:
        f.write(json.dumps({"ts": ts or datetime.now(timezone.utc).strftime(_TS), "task": "T-1",
                            "backend": "claude-code", "purpose": purpose,
                            "cost_amount": amount}) + "\n")
    if commit:
        _git(root, "add", str(rp.COST_LEDGER))
        _git(root, "commit", "-q", "-m", "cost ledger")


def _ticked(root):
    return [t["ac"] for t in vl.apply(TID, root)["ticked"]]


@pytest.fixture()
def hi(repo, monkeypatch):
    monkeypatch.delenv(CEIL, raising=False)
    _mk_task(repo, TASTE, extra_fm=HI)
    (repo / "notes.md").write_text("notes v1\n")
    _produce(repo)
    return repo


def _stepped_run(root, run_id="run-c"):
    return vl.register_run(run_id, TID, acs=[1], rung=R3, seats=[{"seat": "claude", "vendor": "c"}],
                           rung_due=5, reason="blast_radius=9", root=root)


def _green(root, did="rv-1", run_id="run-c"):
    rt.dispatch(root, did, TID, run_id=run_id, seat="claude")
    _record(root, did, rung=R3, run_id=run_id)
    _commit_as(root, f"reviewer-{did}")
    rt.finish(root, did)


class TestCeilingLever:
    # ── the reviewers' probes ────────────────────────────────────────────────
    def test_probe_codex_high1_a_new_run_cannot_reuse_an_old_decision(self, hi, monkeypatch):
        """codex: as_of 2020, one historical 10001 spend line, ceiling 10000 -> accepted. Now the
        decision must be computed at the run's own registration; an old clock is refused."""
        _cost(hi, 10001, ts="2020-01-01T00:00:00Z")
        monkeypatch.setenv(CEIL, "10000")
        old = datetime(2020, 1, 1, 0, 0, 1, tzinfo=timezone.utc)
        real = rp.ceiling_decision
        monkeypatch.setattr(rp, "ceiling_decision", lambda root, due, reason="", now=None:
                            real(root, due, reason, old))
        run = _stepped_run(hi)
        assert run["ceiling_decision"]["granted"] == 3          # the stale decision was steered in
        monkeypatch.setattr(rp, "ceiling_decision", real)
        rt.dispatch(hi, "rv-1", TID, run_id="run-c", seat="claude")
        with pytest.raises(vl.VerdictRefused, match="not at its run's registration"):
            _record(hi, "rv-1", rung=R3, run_id="run-c")

    def test_probe_old_spend_cannot_step_a_new_run_down(self, hi, monkeypatch):
        _cost(hi, 10001, ts="2020-01-01T00:00:00Z")
        monkeypatch.setenv(CEIL, "10000")
        with pytest.raises(ValueError, match="grants rung 5"):
            _stepped_run(hi)

    def test_probe_claude_p1_untracked_spend_does_not_count(self, hi, monkeypatch):
        """P1: one hand-written line (cost 1e9) in an untracked file stepped rung 5 down."""
        _cost(hi, 1e9, commit=False)
        monkeypatch.setenv(CEIL, "10000")
        with pytest.raises(ValueError, match="grants rung 5"):
            _stepped_run(hi)
        assert not hasattr(rp, "SPEND_LOG")

    @pytest.mark.parametrize("ceil", ["0", "-1", "nan", "inf", "-inf", "abc", "50", "99.99"])
    def test_probe_claude_p2_p3_codex_m2_a_bad_or_low_ceiling_never_steps_down(self, hi, monkeypatch, ceil):
        _cost(hi, 1e6)
        monkeypatch.setenv(CEIL, ceil)
        with pytest.raises(ValueError, match="grants rung 5"):
            _stepped_run(hi)
        assert rp.apply_ceiling(5, "", 1e6, ceil)[0] == 5

    def test_probe_claude_p5_a_zero_ceiling_in_framework_yaml(self, hi):
        (hi / ".framework.yaml").write_text(f"{rp.CEILING_KEY}: 0\n")
        _cost(hi, 1e6)
        with pytest.raises(ValueError, match="below the floor"):
            _stepped_run(hi)

    @pytest.mark.parametrize("amount", [float("nan"), float("inf"), -5, "12"])
    def test_non_finite_negative_or_malformed_spend_refuses_a_step_down(self, hi, monkeypatch, amount):
        _cost(hi, 1e6)
        _cost(hi, amount)
        monkeypatch.setenv(CEIL, "200")
        with pytest.raises(ValueError, match="grants rung 5"):
            _stepped_run(hi)

    def test_codex_m2_nan_fields_in_a_decision_are_a_controlled_refusal(self, hi, monkeypatch):
        _cost(hi, 1e6)
        monkeypatch.setenv(CEIL, "200")
        run = _stepped_run(hi)
        for bad in ({"spent": float("nan")}, {"spent": "x"}, {"spend_lines": "x"},
                    {"as_of": None}, {"ledger_rev": "HEAD"}, {"due": None}):
            dec = dict(run["ceiling_decision"], **bad)
            assert "malformed" in rp.verify_ceiling_decision(hi, dec, run["ts"])

    def test_a_rewritten_committed_cost_row_refuses(self, hi, monkeypatch):
        _cost(hi, 1e6)
        monkeypatch.setenv(CEIL, "200")
        _stepped_run(hi)
        p = hi / rp.COST_LEDGER
        p.write_text(p.read_text().replace("1000000", "1000001"))
        _git(hi, "commit", "-qam", "rewrite")
        rt.dispatch(hi, "rv-1", TID, run_id="run-c", seat="claude")
        with pytest.raises(vl.VerdictRefused, match="steps rung 5 down to 3, but cost ledger.*append-only"):
            _record(hi, "rv-1", rung=R3, run_id="run-c")

    def test_the_caller_cannot_supply_a_decision(self):
        import inspect
        assert "ceiling_decision" not in inspect.signature(vl.register_run).parameters

    # ── positive control + disclosure ───────────────────────────────────────
    def test_control_a_committed_spend_over_a_valid_ceiling_steps_down_and_ticks(self, hi, monkeypatch):
        _cost(hi, 199)
        monkeypatch.setenv(CEIL, "200")
        run = _stepped_run(hi)
        dec = run["ceiling_decision"]
        assert (dec["due"], dec["granted"], dec["as_of"]) == (5, 3, run["ts"])
        _green(hi)
        assert _ticked(hi) == [1]
        text = next((hi / ".tasks" / "active").glob(f"{TID}-*.md")).read_text()
        assert "STEP-DOWN: rung 3 granted, rung 5 due, reviewed at rung 3, weekly spend ceiling" in text

    def test_control_a_raised_ceiling_withdraws_the_step_down(self, hi, monkeypatch):
        _cost(hi, 199)
        monkeypatch.setenv(CEIL, "200")
        _stepped_run(hi)
        _green(hi)
        monkeypatch.setenv(CEIL, "100000")
        assert _ticked(hi) == [] and "ceiling-unverified" in _why(hi)

    def test_audit_warns_on_every_step_down(self, hi, monkeypatch):
        _cost(hi, 199)
        monkeypatch.setenv(CEIL, "200")
        _stepped_run(hi)
        rc, out = vl.audit(hi)
        assert any(ln.startswith("WARN step-down: run run-c") and "rung 5 due" in ln for ln in out)

    def test_control_no_step_down_no_warn(self, hi):
        vl.register_run("run-5", TID, acs=[1], rung="rung-5-panel", required_vendors=3,
                        seats=[{"seat": s, "vendor": s} for s in "abc"], rung_due=5, root=hi)
        assert not any("step-down" in ln for ln in vl.audit(hi)[1])

    def test_audit_sh_surfaces_the_warn(self):
        src = (_HERE / "agents" / "audit" / "audit.sh").read_text()
        assert "_audit_review_step_downs" in src and "^WARN step-down" in src

    def test_config_description_says_what_is_recorded(self):
        src = (_HERE / "lib" / "config.sh").read_text()
        line = next(ln for ln in src.splitlines() if "REVIEWER_JUDGE_WEEKLY_SPEND_CEILING|" in ln)
        assert "verdict records the degradation" not in line
        assert "SIGNED REVIEW RUN records the decision" in line and "Floor 100" in line
