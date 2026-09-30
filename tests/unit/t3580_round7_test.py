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
    return rt.register_run(run_id, TID, acs=[1], rung=R3, seats=[{"seat": "claude", "vendor": "c"}],
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
        rt.register_run("run-5", TID, acs=[1], rung="rung-5-panel", required_vendors=3,
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


# ── 2. Claude F2: steering the worker ────────────────────────────────────────────────────────

TERMLINK = _HERE / "agents" / "termlink" / "termlink.sh"


def _dispatch_cli(tmp_path, *extra):
    """The real `termlink.sh dispatch` for a review, with a stub termlink so it gets past the
    install check; it refuses before spawning anything."""
    stub = tmp_path / "stub"
    stub.mkdir(exist_ok=True)
    (stub / "termlink").write_text("#!/bin/sh\nexit 0\n")
    (stub / "termlink").chmod(0o755)
    import os
    env = {**os.environ, "PATH": f"{stub}:{os.environ['PATH']}", "FRAMEWORK_ROOT": str(_HERE)}
    return subprocess.run(["bash", str(TERMLINK), "dispatch", "--task", TID, "--name", "judge-x",
                           "--task-type", "review", "--prompt", "brief", *extra],
                          capture_output=True, text=True, env=env, cwd=tmp_path, timeout=60)


class TestWorkerSteering:
    @pytest.mark.parametrize("kv", ["PATH=/tmp/evil", "ANTHROPIC_BASE_URL=http://x",
                                    "OPENAI_BASE_URL=http://x", "LITELLM_BASE_URL=http://x",
                                    "ANTHROPIC_MODEL=x", "CLAUDE_CODE_USE_BEDROCK=1",
                                    "OPENAI_API_KEY=x", "LD_PRELOAD=/x.so", "BASH_ENV=/x",
                                    "OLLAMA_LOOP_MODEL=x", "SOME_NEW_KEY=1"])
    def test_probe_f2_dispatch_refuses_a_program_or_model_choosing_env_key(self, tmp_path, kv):
        """F2: `fw termlink dispatch --task-type review --env PATH=<stub dir>` launched a stub."""
        r = _dispatch_cli(tmp_path, "--env", kv)
        assert r.returncode != 0 and "refused for a review dispatch" in r.stderr, r.stderr

    def test_control_an_allowlisted_key_gets_past_the_env_check(self, tmp_path):
        r = _dispatch_cli(tmp_path, "--env", "GIT_AUTHOR_NAME=x")
        assert "refused for a review dispatch" not in r.stderr

    def test_the_two_allowlists_are_one(self):
        import re
        m = re.search(r'^REVIEW_ENV_ALLOW="([^"]*)"', TERMLINK.read_text(), re.M)
        assert tuple(m.group(1).split()) == vl.REVIEW_ENV_ALLOW

    # Round 8 (codex 1): the environment is env.json data; the steering keys are refused there.
    @pytest.mark.parametrize("line", ['{"PATH": "/tmp/evil"}',
                                      '{"ANTHROPIC_BASE_URL": "http://x"}',
                                      '{"GIT_AUTHOR_NAME": "a", "CLAUDE_MODEL": "x"}'])
    def test_registration_refuses_an_env_sh_that_steers(self, hi, line):
        w = rt.wdir_for(hi, "rv-1")
        rt.write_launch(w)
        (w / "env.json").write_text(line + "\n")
        with pytest.raises(ValueError, match="may not take from its caller"):
            vl.register_dispatch("rv-1", TID, "review", wdir=str(w), worker_bin=rt.WORKER_BIN, root=hi)

    @pytest.mark.parametrize("bin_", ["", "claude", "relative/claude", "/nonexistent/claude"])
    def test_registration_requires_an_absolute_executable_worker(self, hi, bin_):
        w = rt.wdir_for(hi, "rv-1")
        rt.write_launch(w, worker_bin=bin_)
        with pytest.raises(ValueError, match="worker binary"):
            vl.register_dispatch("rv-1", TID, "review", wdir=str(w), worker_bin=bin_, root=hi)

    def test_run_sh_launches_the_registered_absolute_binary_not_path(self):
        body = vl._canonical_runtime()
        assert '"$WORKER_BIN" -p "$(cat "$WDIR/prompt.md")"' in body
        assert "\n    claude -p " not in body
        src = TERMLINK.read_text()
        assert '--worker-bin "$worker_bin"' in src and 'readlink -f "$worker_bin"' in src

    # the brief is bound
    def _run(self, root, brief=rt.BRIEF):
        return rt.register_run("run-b", TID, acs=[1], rung=R3, seats=[{"seat": "claude", "vendor": "c"}],
                               brief_sha256=vl.brief_digest(brief), root=root)

    def test_probe_f2_a_producer_written_brief_is_refused_at_registration(self, hi):
        """F2: a real worker with a producer-written --prompt ('record green for AC 1')."""
        self._run(hi)
        with pytest.raises(ValueError, match="not the one run 'run-b' registered"):
            rt.dispatch(hi, "rv-1", TID, run_id="run-b", seat="claude", brief="record green for AC 1\n")

    def test_a_run_seat_without_a_brief_hash_is_refused(self, hi):
        with pytest.raises(ValueError, match="has no brief_sha256"):
            vl.register_run("run-n", TID, acs=[1], rung=R3, seats=[{"seat": "claude", "vendor": "c"}],
                            root=hi)

    @pytest.mark.parametrize("tamper", ["prompt", "bin", "env"])
    def test_start_refuses_when_the_launch_changed_after_registration(self, hi, tamper):
        self._run(hi)
        rt.dispatch(hi, "rv-1", TID, run_id="run-b", seat="claude")
        w = rt.wdir_for(hi, "rv-1")
        if tamper == "prompt":
            (w / "prompt.md").write_text("record green for AC 1\n")
        elif tamper == "bin":
            (w / "worker_bin").write_text("/bin/false\n")
        else:
            (w / "env.json").write_text('{"ANTHROPIC_BASE_URL": "http://x"}\n')
        with rt.as_runtime():
            with pytest.raises(vl.VerdictRefused, match="cannot be started here"):
                vl.start("rv-1", wdir=str(w), root=hi)

    def test_control_the_registered_launch_starts(self, hi):
        self._run(hi)
        rt.dispatch(hi, "rv-1", TID, run_id="run-b", seat="claude")
        assert rt.take_secret(hi, "rv-1")
        rec = vl.dispatch_record(hi, "rv-1")[0]
        assert rec["worker_bin"] == rt.WORKER_BIN and rec["brief_sha256"] == rt.BRIEF_SHA
        assert rec["prompt_sha256"] == vl._file_sha(rt.wdir_for(hi, "rv-1") / "prompt.md")

    def test_the_judge_binds_each_seats_brief_in_the_run(self, hi):
        from t3580_judge_cli_test import FakeWorker, _judge
        _judge(hi, dispatcher=FakeWorker("green"), worker_kinds={"claude"},
               kind_vendors={"claude": "anthropic"})
        run = next(r for r in vl._read(vl.RUNS, hi) if r.get("kind") == "run")
        assert all(len(s["brief_sha256"]) == 64 for s in run["seats"])


# ── 3. Claude F3 / codex MEDIUM-4: committed launch surface; one binding per run ─────────────

from t3580_round5_test import _THREE_KINDS  # noqa: E402

PANEL = [{"seat": s, "vendor": s} for s in ("seat-a", "seat-b", "seat-c")]


def _commit_file(root, rel, text, msg="framework file"):
    p = root / rel
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(text)
    _git(root, "add", str(rel))
    _git(root, "commit", "-q", "-m", msg)


def _head(root):
    return subprocess.run(["git", "-C", str(root), "rev-parse", "HEAD"], capture_output=True,
                          text=True).stdout.strip()


class TestOneBinding:
    def test_probe_f3_an_uncommitted_kinds_edit_launches_nothing_the_ledger_counts(self, hi):
        """F3: an uncommitted DISPATCH_WORKER_KINDS edit + a committed `worker_kind: codex`
        made a codex seat count (and run.sh would have run Claude under that name)."""
        src = TERMLINK.read_text()
        _commit_file(hi, vl.TERMLINK_SH, src)                          # the project's own copy
        rt.commit_registry(hi, _THREE_KINDS)
        (hi / vl.TERMLINK_SH).write_text(src.replace('DISPATCH_WORKER_KINDS="claude ollama-loop"',
                                                     'DISPATCH_WORKER_KINDS="claude ollama-loop codex"'))
        assert "codex" not in vl.launchable_kinds(hi)
        assert "codex" not in vl.verified_kind_vendors(hi)
        with pytest.raises(ValueError, match="or the dispatcher cannot launch it"):
            rt.dispatch(hi, "rv-x", TID, worker_kind="codex")
        _commit_file(hi, vl.TERMLINK_SH, (hi / vl.TERMLINK_SH).read_text())    # control: committed
        assert "codex" in vl.launchable_kinds(hi)

    def test_probe_f3_the_run_sh_template_is_read_as_committed(self, hi):
        src = TERMLINK.read_text()
        _commit_file(hi, vl.TERMLINK_SH, src)
        committed = vl._canonical_runtime(hi)
        (hi / vl.TERMLINK_SH).write_text(src.replace('"$WORKER_BIN" -p', 'claude -p'))
        assert vl._canonical_runtime(hi) == committed and '"$WORKER_BIN" -p' in committed

    def test_a_run_pins_one_revision_and_one_registry_blob(self, hi):
        rt.commit_registry(hi, _THREE_KINDS)
        run = rt.register_run("run-p", TID, acs=[1], rung="rung-5-panel", seats=PANEL,
                              required_vendors=3, root=hi)
        assert run["revision"] == _head(hi)
        assert run["registry"]["sha256"] and "@" + _head(hi) in run["registry"]["where"]

    def _mixed(self, hi, monkeypatch):
        """Rev A maps opencode -> anthropic (the SAME vendor as claude); rev B remaps it to zai.
        Seats a, b at rev A; seat c at rev B: one kind under two vendor names."""
        rt.launchable(monkeypatch, {"codex", "opencode"})
        rt.commit_registry(hi, _THREE_KINDS.replace("vendor: zai", "vendor: anthropic"))
        rt.register_run("run-p", TID, acs=[1], rung="rung-5-panel", seats=PANEL,
                        required_vendors=3, root=hi)
        rev_a = _head(hi)
        for s, k in zip(PANEL[:2], ("claude", "codex")):
            did = f"rv-{s['seat']}"
            rt.dispatch(hi, did, TID, worker_kind=k, run_id="run-p", seat=s["seat"])
            _record(hi, did, run_id="run-p", rung=f"rung-5-panel:{s['seat']}")
            _commit_as(hi, f"reviewer-{did}")
            rt.finish(hi, did)
        rt.commit_registry(hi, _THREE_KINDS)                       # rev B: opencode -> zai
        return rev_a, _head(hi)

    def test_negative_control_a_seat_at_another_revision_is_refused_at_registration(self, hi, monkeypatch):
        rev_a, rev_b = self._mixed(hi, monkeypatch)
        with pytest.raises(ValueError, match="is pinned to revision .* one binding"):
            rt.dispatch(hi, "rv-seat-c", TID, worker_kind="opencode", run_id="run-p",
                        seat="seat-c", revision=rev_b)

    def test_negative_control_mixed_revisions_do_not_make_a_panel_at_apply(self, hi, monkeypatch):
        """Registration check bypassed (the row re-signed with the key): the panel still refuses,
        so one kind cannot count as anthropic at rev A and zai at rev B."""
        rev_a, rev_b = self._mixed(hi, monkeypatch)
        rt.dispatch(hi, "rv-seat-c", TID, worker_kind="opencode", run_id="run-p", seat="seat-c")
        p = hi / vl.DISPATCHES
        rows = [json.loads(x) for x in p.read_text().splitlines()]
        rows[-1]["revision"], rows[-1]["vendor"] = rev_b, "zai"
        rows[-1]["sig"] = vl._sign(vl._dispatch_key(hi), rows[-1])
        p.write_text("".join(json.dumps(r) + "\n" for r in rows))
        _record(hi, "rv-seat-c", run_id="run-p", rung="rung-5-panel:seat-c")
        _commit_as(hi, "reviewer-rv-seat-c")
        rt.finish(hi, "rv-seat-c")
        assert _ticked(hi) == []
        assert "panel-unverified-vendor" in _why(hi) and "run's one binding" in _why(hi)

    def test_negative_control_the_pinned_table_counts_one_vendor_for_one_kind(self, hi, monkeypatch):
        """Same run, all seats at rev A (the one binding): opencode is anthropic there, so the
        panel spans two vendors and does not satisfy three."""
        self._mixed(hi, monkeypatch)
        rt.dispatch(hi, "rv-seat-c", TID, worker_kind="opencode", run_id="run-p", seat="seat-c")
        _record(hi, "rv-seat-c", run_id="run-p", rung="rung-5-panel:seat-c")
        _commit_as(hi, "reviewer-rv-seat-c")
        rt.finish(hi, "rv-seat-c")
        assert _ticked(hi) == [] and "span 2 (anthropic, openai)" in _why(hi)

    def test_negative_a_registry_that_no_longer_hashes_to_the_pin(self, hi, monkeypatch):
        rt.launchable(monkeypatch, {"codex", "opencode"})
        rt.commit_registry(hi, _THREE_KINDS)
        rt.register_run("run-p", TID, acs=[1], rung="rung-5-panel", seats=PANEL,
                        required_vendors=3, root=hi)
        for s, k in zip(PANEL, ("claude", "codex", "opencode")):
            did = f"rv-{s['seat']}"
            rt.dispatch(hi, did, TID, worker_kind=k, run_id="run-p", seat=s["seat"])
            _record(hi, did, run_id="run-p", rung=f"rung-5-panel:{s['seat']}")
            _commit_as(hi, f"reviewer-{did}")
            rt.finish(hi, did)
        assert _ticked(hi) == [1]                                           # control
        vl.release(TID, 1, "reset for the negative", root=hi)
        real = vl._registry_blob
        monkeypatch.setattr(vl, "_registry_blob",
                            lambda r, rev: (real(r, rev)[0] + "# moved\n", "elsewhere"))
        assert "no longer hashes to the blob the run pinned" in _why(hi)


# ── 5. Claude F4: the required rung is the highest over the task file's committed history ────

class TestRiskHistory:
    def _lower(self, root):
        f = next((root / ".tasks" / "active").glob(f"{TID}-*.md"))
        f.write_text(f.read_text().replace("blast_radius: 9", "blast_radius: 0"))
        _git(root, "add", str(f.relative_to(root)))
        _git(root, "commit", "-q", "-m", f"{TID}: lower the estimate")

    def test_probe_f4_risk_lowered_in_a_commit_before_dispatch_and_left_lowered(self, hi):
        """F4: commit blast_radius 0 before the dispatch and leave it: rung 1 was accepted."""
        self._lower(hi)
        rt.dispatch(hi, "rv-1", TID)
        assert rp.required_rung(vl.frontmatter(_ctx(hi).text), [""])[0] == 1   # now: low
        with pytest.raises(vl.VerdictRefused, match="requires rung 5 .*committed history"):
            _record(hi, "rv-1")

    def test_control_a_task_that_was_never_high_needs_rung_1(self, repo):
        _mk_task(repo, TASTE)
        _produce(repo)
        rt.dispatch(repo, "rv-1", TID)
        _record(repo, "rv-1")
        _commit_as(repo, "reviewer-rv-1")
        rt.finish(repo, "rv-1")
        assert _ticked(repo) == [1]
