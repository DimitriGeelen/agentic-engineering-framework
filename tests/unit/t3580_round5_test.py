"""T-3580 round 5: the round-4 Claude review (AMBER, no highs) — docs/reports/T-3580-round4-review.md.

1. MED  vendor honesty: the vendor is DERIVED from the registered worker kind through the one
        mapping in policy/review-backends.yaml; free text never names a vendor.
2. MED  the never-run dispatch: a signed runtime START within a start window, a TTL on the
        completion, and the dispatcher reaps a secret run.sh never took.
3. LOW  `finalised` is verified (content = completion sig, run.sh no longer alive), not trusted.
4. LOW  .context/dispatch-results/ is gitignored.
5. LOW  the completions file is under the same git-history append-only check as the ledger.
Fixtures only; no real task is judged (sovereignty hold).
"""
import json
import os
import signal
import subprocess
import sys
import time
from pathlib import Path

import pytest

_HERE = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(_HERE))
sys.path.insert(0, str(Path(__file__).resolve().parent))

from lib import review_cost  # noqa: E402
from lib import verdict_ledger as vl  # noqa: E402
import _review_runtime as rt  # noqa: E402
from t3580_judge_cli_test import TID, repo  # noqa: E402,F401
from t3580_round2_test import _commit_as  # noqa: E402
from t3580_round3_test import (  # noqa: E402,F401
    TERMLINK, _closed, _record, _run_worker, _why, prod, rtrepo,
)

LEDGER = _HERE / "lib" / "verdict_ledger.py"


def _ticked(root):
    return [t["ac"] for t in vl.apply(TID, root)["ticked"]]


def _rows(root, rel):
    return [json.loads(ln) for ln in (root / rel).read_text().splitlines() if ln.strip()]


def _write_rows(root, rel, rows):
    (root / rel).write_text("".join(json.dumps(r) + "\n" for r in rows))


def _resign_dispatch(root, did, **changes):
    """A registry row altered and re-signed with the key: what a same-user forger (or a legacy
    registration) produces. It verifies as a dispatch; the ledger must still judge its contents."""
    rows = _rows(root, vl.DISPATCHES)
    for r in rows:
        if r["dispatch_id"] == did:
            r.update(changes)
            r["sig"] = vl._sign(vl._dispatch_key(root), r)
    _write_rows(root, vl.DISPATCHES, rows)


def _green_seat(root, did, run_id="", rung=""):
    _record(root, did, **({"run_id": run_id} if run_id else {}), **({"rung": rung} if rung else {}))
    _commit_as(root, f"reviewer-{did}")
    rt.finish(root, did)


def _shell_fn(*names) -> str:
    """The named function definitions, lifted verbatim from termlink.sh."""
    src = TERMLINK.read_text()
    out = []
    for n in names:
        i = src.index(f"\n{n}() {{\n") + 1
        out.append(src[i:src.index("\n}\n", i) + 3])
    return "".join(out)


# ── 1. vendor honesty: one mapping, derived from the registered kind ─────────────────────────

_THREE_KINDS = """backends:
  - {id: k-claude, name: C, harness_class: subscription, cost_class: internal,
     approval_required: false, cost_estimate_method: unmetered, description: x,
     worker_kind: claude, vendor: anthropic}
  - {id: k-codex, name: X, harness_class: subscription, cost_class: internal,
     approval_required: false, cost_estimate_method: unmetered, description: x,
     worker_kind: codex, vendor: openai}
  - {id: k-opencode, name: Z, harness_class: subscription, cost_class: internal,
     approval_required: false, cost_estimate_method: unmetered, description: x,
     worker_kind: opencode, vendor: zai}
  - {id: openrouter, name: OR, harness_class: pay_per_use, cost_class: paid,
     approval_required: true, cost_estimate_method: tokens_estimated, description: x}
"""

SEATS = [{"seat": s, "vendor": s} for s in ("seat-a", "seat-b", "seat-c")]


def _panel(root, kinds):
    vl.register_run("run-p", TID, acs=[1], rung="rung-5-panel", seats=SEATS, required_vendors=3,
                    root=root)
    for s, k in zip(SEATS, kinds):
        did = f"rv-{s['seat']}"
        rt.dispatch(root, did, TID, worker_kind=k, run_id="run-p", seat=s["seat"])   # pre-launch
        _green_seat(root, did, run_id="run-p", rung=f"rung-5-panel:{s['seat']}")


class TestVendorMapping:
    def test_negative_reviewer_control_free_text_vendors_for_one_kind_are_refused(self, prod):
        """The round-4 reviewer's control: three worker_kind=claude dispatches registered as
        'anthropic', 'vendor-2', 'vendor-3'. The two free-text vendors are refused outright."""
        rt.dispatch(prod, "rv-a", TID, worker_kind="claude", vendor="anthropic")
        for did, v in (("rv-b", "vendor-2"), ("rv-c", "vendor-3")):
            with pytest.raises(ValueError, match="is not the one .* maps worker kind 'claude'"):
                rt.dispatch(prod, did, TID, worker_kind="claude", vendor=v)
        assert [r["vendor"] for r in _rows(prod, vl.DISPATCHES)] == ["anthropic"]

    def test_negative_register_dispatch_cli_takes_no_vendor(self, prod):
        r = subprocess.run([sys.executable, str(LEDGER), "register-dispatch", "--dispatch-id", "x1",
                            "--task", TID, "--task-type", "review", "--vendor", "vendor-2"],
                           cwd=prod, capture_output=True, text=True,
                           env={**os.environ, "PROJECT_ROOT": str(prod)})
        assert r.returncode == 2 and "unrecognized arguments: --vendor" in r.stderr

    def test_negative_resigned_inconsistent_rows_do_not_satisfy_a_three_vendor_panel(self, prod):
        """Rows that reached the registry with vendor != mapping[kind] (re-signed with the key, or
        registered before round 5) make their seat unverified at apply — they are not counted."""
        _panel(prod, ["claude"] * 3)
        _resign_dispatch(prod, "rv-seat-b", vendor="vendor-2")
        _resign_dispatch(prod, "rv-seat-c", vendor="vendor-3")
        assert _ticked(prod) == []
        assert "panel-unverified-vendor" in _why(prod) and "'claude'" in _why(prod)

    def test_negative_three_claude_seats_are_one_vendor(self, prod):
        _panel(prod, ["claude"] * 3)
        assert _closed(prod).startswith("degraded") and "span 1" in _closed(prod)

    def test_control_three_distinct_registered_kinds_satisfy_the_panel(self, prod):
        (prod / "policy").mkdir()
        (prod / "policy" / "review-backends.yaml").write_text(_THREE_KINDS)
        _panel(prod, ["claude", "codex", "opencode"])
        assert [r["vendor"] for r in _rows(prod, vl.DISPATCHES)] == ["anthropic", "openai", "zai"]
        assert _ticked(prod) == [1]

    def test_negative_a_review_kind_the_mapping_does_not_know_is_refused(self, prod):
        with pytest.raises(ValueError, match="has no vendor in policy/review-backends.yaml"):
            rt.dispatch(prod, "rv-x", TID, worker_kind="codex")    # real registry: no codex kind

    def test_the_dispatcher_prints_the_same_one_mapping(self):
        out = subprocess.run(["bash", str(TERMLINK), "worker-kinds", "--vendors"],
                             capture_output=True, text=True).stdout
        printed = dict(ln.split() for ln in out.splitlines())
        table = vl.kind_vendors(_HERE)
        assert printed and all(table[k] == v for k, v in printed.items())
        fn = _shell_fn("_worker_vendor")
        assert "anthropic" not in fn and "ollama-local" not in fn and "kind-vendors" in fn

    def test_negative_registry_mapping_one_kind_to_two_vendors_does_not_load(self, tmp_path):
        p = tmp_path / "r.yaml"
        p.write_text(_THREE_KINDS.replace("worker_kind: codex", "worker_kind: claude"))
        with pytest.raises(review_cost.CostError, match="maps to two vendors"):
            review_cost.worker_vendors(p)


# ── 2. the never-run dispatch ────────────────────────────────────────────────────────────────

def _never_ran(root, did="rv-1"):
    """Registered, never run: the caller reads the LEFTOVER secret file (no start), writes a row,
    commits it under the worker identity, and fakes the exit state and result stream."""
    rt.dispatch(root, did, TID)
    secret = rt.take_secret(root, did, start=False)
    _record(root, did)
    _commit_as(root, f"reviewer-{did}")
    w = rt.wdir_for(root, did)
    (w / "exit_code").write_text("0\n")
    (w / "result.jsonl").write_text('{"type":"result","result":"VERDICT: green"}\n')
    return w, secret


class TestNeverRun:
    def test_negative_never_run_leftover_secret_fake_files_complete_is_refused_at_apply(self, prod):
        w, secret = _never_ran(prod)
        assert secret                                               # the secret WAS readable
        with pytest.raises(vl.VerdictRefused, match="no runtime start record"):
            vl.complete("rv-1", wdir=str(w), exit_code=0, secret=secret, root=prod)
        r = subprocess.run([sys.executable, str(LEDGER), "complete", "--dispatch-id", "rv-1",
                            "--wdir", str(w), "--exit-code", "0", "--secret-stdin"], input=secret,
                           capture_output=True, text=True, cwd=prod,
                           env={**os.environ, "PROJECT_ROOT": str(prod)})
        assert r.returncode == 1 and "no runtime start record" in r.stderr
        assert _ticked(prod) == [] and "no-completion" in _why(prod)

    def test_negative_the_start_cli_refuses_a_caller_that_is_not_run_sh(self, prod):
        w, secret = _never_ran(prod)
        r = subprocess.run([sys.executable, str(LEDGER), "start", "--dispatch-id", "rv-1",
                            "--wdir", str(w), "--secret-stdin"], input=secret,
                           capture_output=True, text=True, cwd=prod,
                           env={**os.environ, "PROJECT_ROOT": str(prod)})
        assert r.returncode == 1 and "not this command's parent" in r.stderr
        assert vl._starts_for(prod, "rv-1") == []

    def test_negative_the_start_window_closes(self, prod, monkeypatch):
        w, secret = _never_ran(prod)
        t = time.time() + vl.START_WINDOW + 5
        monkeypatch.setattr(vl, "_clock", lambda: t)
        with pytest.raises(vl.VerdictRefused, match="start window"):
            vl.start("rv-1", wdir=str(w), secret=secret, root=prod)

    def test_negative_the_secret_expires_at_the_ttl(self, prod, monkeypatch):
        w, secret = _never_ran(prod)
        vl.start("rv-1", wdir=str(w), secret=secret, root=prod)
        t = time.time() + vl.DEFAULT_TTL + 5
        monkeypatch.setattr(vl, "_clock", lambda: t)
        with pytest.raises(vl.VerdictRefused, match="past its TTL"):
            vl.complete("rv-1", wdir=str(w), exit_code=0, secret=secret, root=prod)

    def test_control_started_in_window_completes_and_ticks(self, prod):
        w, secret = _never_ran(prod)
        vl.start("rv-1", wdir=str(w), secret=secret, root=prod)
        vl.complete("rv-1", wdir=str(w), exit_code=0, secret=secret, root=prod)
        assert _ticked(prod) == [1]

    def test_negative_a_dispatch_starts_once(self, prod):
        w, secret = _never_ran(prod)
        vl.start("rv-1", wdir=str(w), secret=secret, root=prod)
        with pytest.raises(vl.VerdictRefused, match="already started"):
            vl.start("rv-1", wdir=str(w), secret=secret, root=prod)

    def test_negative_apply_refuses_a_completion_whose_start_is_gone(self, prod):
        rt.dispatch(prod, "rv-1", TID)
        _green_seat(prod, "rv-1")
        rows = [r for r in _rows(prod, vl.COMPLETIONS) if r.get("kind") != "start"]
        _write_rows(prod, vl.COMPLETIONS, rows)       # untracked file: no history to protect it
        assert _ticked(prod) == [] and "no-start" in _why(prod)

    def test_negative_apply_refuses_a_completion_signed_after_the_ttl(self, prod):
        rt.dispatch(prod, "rv-1", TID)
        _green_seat(prod, "rv-1")
        rows = _rows(prod, vl.COMPLETIONS)
        for r in rows:
            if r.get("kind") == "completion":
                r["epoch"] += vl.DEFAULT_TTL + 5
                r["sig"] = vl._sign_row(vl._dispatch_key(prod), {k: v for k, v in r.items() if k != "sig"})
        _write_rows(prod, vl.COMPLETIONS, rows)
        assert _ticked(prod) == [] and "expired" in _why(prod)

    def test_the_dispatcher_reaps_a_secret_run_sh_never_took(self, tmp_path):
        (tmp_path / ".completion-secret").write_text("s\n")
        r = subprocess.run(["bash", "-c", _shell_fn("_reap_unstarted_secret")
                            + f'_reap_unstarted_secret "{tmp_path}"'],
                           capture_output=True, text=True,
                           env={**os.environ, "TERMLINK_REVIEW_START_WAIT": "1"})
        assert r.returncode == 1 and "did not start" in r.stderr
        assert not (tmp_path / ".completion-secret").exists()
        # control: a secret already taken by run.sh is not an error
        r = subprocess.run(["bash", "-c", _shell_fn("_reap_unstarted_secret")
                            + f'_reap_unstarted_secret "{tmp_path}"'], capture_output=True, text=True)
        assert r.returncode == 0

    def test_cmd_dispatch_reaps_on_every_path(self):
        src = TERMLINK.read_text()
        body = src[src.index("\ncmd_dispatch() {"):src.index("\ncmd_wait() {")]
        assert "trap \"rm -f '$wdir/.completion-secret'\" EXIT" in body     # die inside cmd_spawn
        assert '_reap_unstarted_secret "$wdir"' in body                    # run.sh never started
        run_sh = body[body.index("<<'RUNEOF'"):]
        assert "trap 'rm -f \"$WDIR/.completion-secret\"' EXIT" in run_sh

    def test_real_run_sh_records_its_start_before_the_worker(self, rtrepo):
        did, wdir, out = _run_worker(rtrepo)
        starts = vl._starts_for(rtrepo, did)
        assert len(starts) == 1 and starts[0]["pid"] > 0, out
        comp = vl._completions_for(rtrepo, did)[0]
        assert starts[0]["epoch"] <= comp["epoch"]
        assert _ticked(rtrepo) == [1]


# ── 3. `finalised` is verified ───────────────────────────────────────────────────────────────

def _done(w) -> bool:
    fn = _shell_fn("_worker_done", "_runtime_alive")
    return subprocess.run(["bash", "-c", fn + f'_worker_done "{w}/"'], timeout=30).returncode == 0


class TestFinalisedVerified:
    @pytest.fixture()
    def w(self, tmp_path):
        d = tmp_path / "judge-x"
        d.mkdir()
        (d / "exit_code").write_text("0\n")
        (d / "finalise_required").write_text("")
        (d / "completion.json").write_text(json.dumps({"sig": "abc123"}))
        return d

    def test_negative_an_early_bare_marker_is_not_finalised(self, w):
        (w / "finalised").write_text("signed\n")                    # the round-4 format
        assert not _done(w)

    def test_negative_a_sig_that_is_not_the_completions(self, w):
        (w / "finalised").write_text("signed:ffff\n")
        assert not _done(w)

    def test_negative_a_matching_marker_while_run_sh_still_runs(self, w):
        (w / "finalised").write_text("signed:abc123\n")
        p = subprocess.Popen(["bash", "-c", "sleep 30; :", str(w / "run.sh")])
        try:
            time.sleep(0.3)
            assert not _done(w)
        finally:
            p.send_signal(signal.SIGTERM)
            p.wait()
        assert _done(w)                                              # control: runtime gone

    def test_control_unsigned_with_a_reason(self, w):
        (w / "finalised").write_text("unsigned:completion-refused\n")
        assert _done(w)


# ── 4. dispatch results are gitignored ───────────────────────────────────────────────────────

def test_dispatch_results_are_gitignored():
    r = subprocess.run(["git", "check-ignore", "-q", ".context/dispatch-results/any-worker.md"],
                       cwd=_HERE)
    assert r.returncode == 0
    assert subprocess.run(["git", "ls-files", ".context/dispatch-results"], cwd=_HERE,
                          capture_output=True, text=True).stdout == ""


# ── 5. the completions file: append-only against git history ─────────────────────────────────

class TestCompletionsHistory:
    def _done(self, prod):
        rt.dispatch(prod, "rv-1", TID)
        _green_seat(prod, "rv-1")
        _commit_as(prod, "dispatcher")        # completions (and its start) now committed

    def test_control_committed_and_appended_only(self, prod):
        self._done(prod)
        assert vl.history_fault(prod, vl.COMPLETIONS) == ""
        assert _ticked(prod) == [1]

    def test_negative_a_committed_completion_modified_later(self, prod):
        self._done(prod)
        rows = _rows(prod, vl.COMPLETIONS)
        rows[-1]["exit_code"] = 0
        rows[-1]["note"] = "edited"
        _write_rows(prod, vl.COMPLETIONS, rows)
        assert "does not contain its committed rows" in vl.history_fault(prod, vl.COMPLETIONS)
        _commit_as(prod, "dispatcher")
        assert "modified, deleted or replaced" in vl.history_fault(prod, vl.COMPLETIONS)
        assert _ticked(prod) == [] and "completion-history" in _why(prod)
        rc, lines = vl.audit(prod)
        assert rc == 2 and any(ln.startswith("FAIL completions integrity") for ln in lines)

    def test_untracked_completions_are_a_named_warn(self, prod):
        rt.dispatch(prod, "rv-1", TID)
        rt.finish(prod, "rv-1")
        _rc, lines = vl.audit(prod)
        assert any(ln.startswith("WARN completions file untracked") for ln in lines)
