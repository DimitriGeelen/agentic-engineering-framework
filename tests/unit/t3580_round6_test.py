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
    """Round 7: spend is read from the COMMITTED cost ledger (the untracked spend log is gone)."""
    from t3580_round7_test import _cost
    _cost(root, cost, ts=ts)


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
        rt.register_run("run-3", TID, acs=[1], rung=R3, seats=[{"seat": "claude", "vendor": "c"}],
                        root=hi)
        rt.dispatch(hi, "rv-1", TID, run_id="run-3", seat="claude")
        with pytest.raises(vl.VerdictRefused, match="is rung 3 with no ceiling decision"):
            _record(hi, "rv-1", rung=R3, run_id="run-3")

    def test_negative_the_row_claims_a_rung_its_run_did_not_authorise(self, repo):
        _mk_task(repo, TASTE)          # low impact: rung 1 required
        _produce(repo)
        rt.register_run("run-1", TID, acs=[1], rung=R1, seats=[{"seat": "claude", "vendor": "c"}],
                        root=repo)
        rt.dispatch(repo, "rv-1", TID, run_id="run-1", seat="claude")
        with pytest.raises(vl.VerdictRefused, match="claims rung 5; its run 'run-1' authorised rung 1"):
            _record(repo, "rv-1", rung="rung-5-panel:claude", run_id="run-1")

    def test_negative_a_panel_run_that_asks_for_one_vendor(self, hi):
        seats = [{"seat": s, "vendor": s} for s in "abc"]
        rt.register_run("run-p", TID, acs=[1], rung="rung-5-panel", seats=seats, required_vendors=1,
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
        rt.register_run(run_id, TID, acs=[1], rung=R3,
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
        rt.register_run("run-o", "T-1", acs=[1], rung=R3, seats=[{"seat": "claude", "vendor": "c"}],
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

    def _stepped(self, root, *, spent=199.0, ceiling="200"):
        """The judge's path: ceiling reached, rung 5 due, rung 3 granted, decision in the run
        (round 7: computed BY THE LEDGER at registration, from the committed cost ledger)."""
        _spend(root, spent)
        import os
        os.environ[f"FW_{review_policy.CEILING_KEY}"] = ceiling
        run = rt.register_run("run-c", TID, acs=[1], rung=R3, seats=[{"seat": "claude", "vendor": "c"}],
                              rung_due=5, reason="blast_radius=9", root=root)
        dec = run["ceiling_decision"]
        assert dec["granted"] == 3
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
        (hi / review_policy.COST_LEDGER).write_text("")        # the spend it cited is gone
        rt.dispatch(hi, "rv-1", TID, run_id="run-c", seat="claude")
        with pytest.raises(vl.VerdictRefused, match="steps rung 5 down to 3, but cost ledger"):
            _record(hi, "rv-1", rung=R3, run_id="run-c")
        assert dec["spend_lines"] == 1

    def test_negative_a_raised_ceiling_withdraws_the_step_down(self, hi, monkeypatch):
        self._stepped(hi)
        _seat_green(hi, "rv-1", run_id="run-c", seat="claude", rung=R3)
        monkeypatch.setenv(f"FW_{review_policy.CEILING_KEY}", "1000")
        assert _ticked(hi) == [] and "ceiling-unverified" in _why(hi)

    def _steer(self, monkeypatch, **fields):
        """Round 7: a caller cannot pass a decision, so steer the one the ledger computes."""
        real = review_policy.ceiling_decision
        monkeypatch.setattr(review_policy, "ceiling_decision",
                            lambda *a, **k: dict(real(*a, **k), **fields))

    def test_negative_a_hand_written_decision_that_does_not_re_derive(self, hi, monkeypatch):
        self._steer(monkeypatch, granted=3)                   # nothing spent, claimed as a step-down
        rt.register_run("run-f", TID, acs=[1], rung=R3, seats=[{"seat": "claude", "vendor": "c"}],
                        rung_due=5, root=hi)
        monkeypatch.undo()
        rt.dispatch(hi, "rv-1", TID, run_id="run-f", seat="claude")
        with pytest.raises(vl.VerdictRefused, match="is granted 5, not the recorded 3"):
            _record(hi, "rv-1", rung=R3, run_id="run-f")

    def test_negative_a_decision_that_steps_down_twice(self, hi, monkeypatch):
        self._stepped(hi, spent=999)
        self._steer(monkeypatch, granted=1)
        rt.register_run("run-1", TID, acs=[1], rung=R1, seats=[{"seat": "claude", "vendor": "c"}],
                        rung_due=5, root=hi)
        monkeypatch.undo()
        rt.unbound_spend(monkeypatch)       # round 8: undo() dropped the suite's row binding patch
        import os
        os.environ[f"FW_{review_policy.CEILING_KEY}"] = "200"
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
        # Round 8 (codex 2): judge planning and the ledger share ONE history-aware requirement.
        assert "review_policy.required_rung" in inspect.getsource(vl.task_required_strength)
        assert "task_required_strength(" in inspect.getsource(vl.required_strength)
        assert "vl.task_required_strength(" in inspect.getsource(judge_cli.judge)
        assert "_IRREVERSIBLE_RE" not in inspect.getsource(judge_cli)

    def test_application_judge_at_the_ceiling_records_a_decision_that_the_ledger_accepts(
            self, hi, monkeypatch):
        """End to end: the judge steps rung 5 down to 3 at the ceiling, the run carries the
        decision, the worker's green is accepted by record and ticks at apply."""
        # Round 8 (N4): the worker records through a CLI subprocess, so the spend must genuinely
        # count: 32 signed, started rung-3 seats (96) against the floor ceiling 100.
        rt.bound_spend(hi, 32)
        monkeypatch.setenv(f"FW_{review_policy.CEILING_KEY}", "100")
        res = _judge(hi, dispatcher=FakeWorker("green"), worker_kinds={"claude"},
                     kind_vendors={"claude": "anthropic"})
        assert res["rung_due"] == 5 and res["rung"] == 3, res.get("ceiling_note")
        run = next(r for r in vl._read(vl.RUNS, hi) if r.get("kind") == "run" and r.get("task") == TID)
        assert run["ceiling_decision"]["due"] == 5 and run["ceiling_decision"]["granted"] == 3
        assert res["outcomes"] == {1: "green"}
        assert _ticked(hi) == [1]


# ── 2. MEDIUM: the completion capability is issued by the runtime, and authenticated there ───

import os  # noqa: E402
import subprocess  # noqa: E402

from t3580_round3_test import _run_sh, _run_worker, prod, rtrepo  # noqa: E402,F401

LEDGER = _HERE / "lib" / "verdict_ledger.py"


def _registered_never_ran(root, did="rv-1"):
    """The round-5 attack's setup: a dispatch registered through the public command, a row
    written and committed under the worker identity, exit/result files faked. Never launched."""
    rt.dispatch(root, did, TID)
    _record(root, did)
    _commit_as(root, f"reviewer-{did}")
    w = rt.wdir_for(root, did)
    (w / "exit_code").write_text("0\n")
    (w / "result.jsonl").write_text('{"type":"result","result":"VERDICT: green"}\n')
    return w


def _env(root):
    return {**{k: v for k, v in os.environ.items() if k != vl._WORKER_ENV}, "PROJECT_ROOT": str(root)}


class TestRuntimeCapability:
    def test_negative_registration_hands_the_caller_nothing(self, prod):
        w = _registered_never_ran(prod)
        # Round 7: brief.md / prompt.md / worker_bin are the DISPATCHER's launch files, not
        # anything registration issues; there is still no secret among them. Round 9: plus the
        # pinned worker settings.json registration copies from the committed policy file.
        assert sorted(p.name for p in w.iterdir()) == ["brief.md", "exit_code", "prompt.md",
                                                       "result.jsonl", "settings.json", "worker_bin"]
        assert "secret" not in (prod / vl.DISPATCHES).read_text()

    def test_negative_the_round5_control_python_start_then_complete_is_refused(self, prod):
        """The review's finding verbatim: `_never_ran`, then the Python start()/complete() — the
        shared implementation now authenticates its caller, so neither runs and nothing ticks."""
        w = _registered_never_ran(prod)
        with pytest.raises(vl.VerdictRefused, match="cannot be started here: the parent process"):
            vl.start("rv-1", wdir=str(w), root=prod)
        with pytest.raises(vl.VerdictRefused, match="no runtime start record"):
            vl.complete("rv-1", wdir=str(w), exit_code=0, secret="0" * 64, root=prod)
        assert vl._starts_for(prod, "rv-1") == [] and vl._completions_for(prod, "rv-1") == []
        assert _ticked(prod) == [] and "no-completion" in _why(prod)

    def test_negative_complete_is_authenticated_too(self, prod):
        """Even holding a genuinely issued secret, a caller that is not the runtime cannot sign."""
        w = _registered_never_ran(prod)
        secret = rt.take_secret(prod, "rv-1")               # issued by a (double) runtime start
        assert secret
        with pytest.raises(vl.VerdictRefused, match="cannot be completed here: the parent process"):
            vl.complete("rv-1", wdir=str(w), exit_code=0, secret=secret, root=prod)
        assert _ticked(prod) == []

    def test_negative_a_shell_that_only_names_run_sh_is_not_the_runtime(self, prod):
        w = _registered_never_ran(prod)
        (w / "run.sh").write_text(_run_sh())                 # even the canonical file
        r = subprocess.run(["bash", "-c", f'"{sys.executable}" "{LEDGER}" start --dispatch-id rv-1 '
                            f'--wdir "{w}"', str(w / "run.sh")], capture_output=True, text=True,
                           cwd=prod, env=_env(prod))
        assert r.returncode == 1 and "is not a shell running" in r.stderr, r.stderr
        assert r.stdout.strip() == "" and vl._starts_for(prod, "rv-1") == []

    def test_negative_a_run_sh_that_is_not_the_canonical_runtime(self, prod):
        w = _registered_never_ran(prod)
        (w / "run.sh").write_text(f'#!/bin/bash\nexec "{sys.executable}" "{LEDGER}" start '
                                  f'--dispatch-id rv-1 --wdir "{w}"\n')
        r = subprocess.run(["bash", str(w / "run.sh")], capture_output=True, text=True, cwd=prod,
                           env=_env(prod))
        # exec replaces the shell: the parent is the test, not run.sh
        assert r.returncode == 1 and "cannot be started here" in r.stderr, r.stderr
        (w / "run.sh").write_text(f'#!/bin/bash\n"{sys.executable}" "{LEDGER}" start '
                                  f'--dispatch-id rv-1 --wdir "{w}"\n')
        r = subprocess.run(["bash", str(w / "run.sh")], capture_output=True, text=True, cwd=prod,
                           env=_env(prod))
        assert r.returncode == 1 and "is not the dispatch runtime termlink.sh writes" in r.stderr, r.stderr
        assert vl._starts_for(prod, "rv-1") == [] and _ticked(prod) == []

    def test_control_a_launched_worker_starts_signs_and_ticks(self, rtrepo):
        """Positive control that actually launches a worker: the real run.sh from termlink.sh runs
        a stub `claude` that follows the brief; the runtime's authenticated start issues the
        secret, the worker records and commits, the runtime completes, apply ticks."""
        did, wdir, out = _run_worker(rtrepo)
        st = vl._starts_for(rtrepo, did)
        assert len(st) == 1 and st[0]["secret_sha256"] and st[0]["pid"] > 0, out
        comps = vl._completions_for(rtrepo, did)
        assert len(comps) == 1 and comps[0]["exit_code"] == 0
        assert (wdir / "finalised").read_text().startswith("signed:")
        assert not any(p.name.startswith(".completion") for p in wdir.iterdir())
        assert _ticked(rtrepo) == [1]

    def test_the_worker_never_holds_the_secret(self, rtrepo):
        did, wdir, out = _run_worker(rtrepo, mode="peek")
        log = (wdir / "stderr.log").read_text()
        assert "PEEK file=0 env=0" in log, log
        assert _ticked(rtrepo) == [1]


# ── 3. LOW: vendor provenance = the COMMITTED registry + a launchable worker kind ───────────

from t3580_round5_test import _THREE_KINDS  # noqa: E402

PANEL = [{"seat": s, "vendor": s} for s in ("seat-a", "seat-b", "seat-c")]


def _three_seat_panel(root, kinds=("claude", "codex", "opencode")):
    rt.register_run("run-p", TID, acs=[1], rung="rung-5-panel", seats=PANEL, required_vendors=3,
                    root=root)
    for s, k in zip(PANEL, kinds):
        did = f"rv-{s['seat']}"
        rt.dispatch(root, did, TID, worker_kind=k, run_id="run-p", seat=s["seat"])
        _record(root, did, run_id="run-p", rung=f"rung-5-panel:{s['seat']}")
        _commit_as(root, f"reviewer-{did}")
        rt.finish(root, did)


class TestVendorProvenance:
    def test_negative_an_uncommitted_registry_declares_nothing(self, prod, monkeypatch):
        """The review's case: the round-5 three-vendor control used a working-tree registry."""
        (prod / "policy").mkdir()
        (prod / "policy" / "review-backends.yaml").write_text(_THREE_KINDS)    # NOT committed
        rt.launchable(monkeypatch, {"codex", "opencode"})
        assert "codex" not in vl.kind_vendors(prod)
        with pytest.raises(ValueError, match="'codex' has no vendor .* as committed"):
            rt.dispatch(prod, "rv-x", TID, worker_kind="codex")

    def test_negative_an_uncommitted_edit_does_not_change_a_committed_vendor(self, prod):
        rt.commit_registry(prod, _THREE_KINDS)
        (prod / "policy" / "review-backends.yaml").write_text(
            _THREE_KINDS.replace("vendor: anthropic", "vendor: someone-else"))
        assert vl.kind_vendors(prod)["claude"] == "anthropic"

    def test_negative_a_committed_but_unlaunchable_kind_is_refused_at_registration(self, prod):
        rt.commit_registry(prod, _THREE_KINDS)
        assert vl.kind_vendors(prod)["codex"] == "openai"           # declared and committed ...
        assert "codex" not in vl.launchable_kinds()                  # ... but no worker can run
        with pytest.raises(ValueError, match="or the dispatcher cannot launch it"):
            rt.dispatch(prod, "rv-x", TID, worker_kind="codex")

    def test_negative_at_apply_an_unlaunchable_seat_does_not_count(self, hi, monkeypatch):
        """Registered while (pretend) launchable; at apply the dispatcher cannot launch the kind:
        the seat's vendor is unverified and the panel does not tick."""
        rt.commit_registry(hi, _THREE_KINDS)
        with monkeypatch.context() as m:
            rt.launchable(m, {"codex", "opencode"})
            _three_seat_panel(hi)
            assert _ticked(hi) == [1]                                # control while launchable
        f = next((hi / ".tasks" / "active").glob(f"{TID}-*.md"))
        f.write_text(f.read_text().replace("- [x] [REVIEW]", "- [ ] [REVIEW]"))
        (hi / vl.APPLIED).unlink(missing_ok=True)
        ctx, crit = _ctx(hi), _crit(hi)
        good, why = vl.satisfying_verdict(ctx, crit)
        assert good is None and "panel-unverified-vendor" in why and "launchable" in why

    def test_negative_the_registry_is_read_at_the_reviewed_revision(self, prod, monkeypatch):
        """A kind committed only AFTER the reviewed revision names no vendor for that review."""
        early = subprocess.run(["git", "rev-parse", "HEAD"], cwd=prod, capture_output=True,
                               text=True).stdout.strip()
        rt.commit_registry(prod, _THREE_KINDS)
        rt.launchable(monkeypatch, {"codex"})
        with pytest.raises(ValueError, match="'codex' has no vendor"):
            rt.dispatch(prod, "rv-x", TID, worker_kind="codex", revision=early)
        rt.dispatch(prod, "rv-y", TID, worker_kind="codex")                  # control: at HEAD
        assert vl.dispatch_record(prod, "rv-y")[0]["vendor"] == "openai"

    def test_control_committed_and_launchable_three_vendors_tick(self, hi, monkeypatch):
        rt.commit_registry(hi, _THREE_KINDS)
        rt.launchable(monkeypatch, {"codex", "opencode"})
        _three_seat_panel(hi)
        assert _ticked(hi) == [1]

    def test_antigravity_is_a_google_kind_and_a_spare_seat(self):
        """T-3582 (operator 2026-10-01): antigravity is a real worker kind — vendor google, its
        committed binary run through the operator-approved sudo form — and the SPARE seat: the
        panel takes the first three seat backends in registry order (claude, codex, opencode)."""
        import yaml
        reg = yaml.safe_load((_HERE / "policy" / "review-backends.yaml").read_text())["backends"]
        agy = next(b for b in reg if b["id"] == "antigravity")
        assert agy["worker_kind"] == "antigravity" and agy["vendor"] == "google"
        assert agy["binary"].startswith("/") and agy["cost_class"] == "internal"
        seats, _paid = judge_cli._backends(_HERE)
        assert [s["id"] for s in seats][:3] == ["claude-code", "codex", "opencode"]
        assert "antigravity" in [s["id"] for s in seats][3:]
        assert set(vl.verified_kind_vendors(_HERE)) <= vl.launchable_kinds()

    def test_launchable_kinds_are_what_the_dispatcher_prints(self):
        out = subprocess.run(["bash", str(_HERE / "agents/termlink/termlink.sh"), "worker-kinds"],
                             capture_output=True, text=True).stdout.split()
        assert set(out) == vl.launchable_kinds() and out


@pytest.fixture(autouse=True)
def _unbound_spend(monkeypatch):
    """Round 8 (N4): this suite exercises the ceiling arithmetic with hand-written judge rows; the
    binding of a row to a signed, started run seat is proven in t3580_round8_test.TestSpendIsBound
    (see _review_runtime.unbound_spend)."""
    rt.unbound_spend(monkeypatch)
