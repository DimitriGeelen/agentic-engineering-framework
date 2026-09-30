"""T-3580 round 4: the round-3 OpenAI RED findings and the Z.ai lows.

1. HIGH  `complete` is a public command: a completion now needs the per-dispatch runtime secret.
2. HIGH  panel diversity counted backend ids: it now counts the vendor registered with each dispatch.
3. MED   `wait` returned on exit_code, before signing: review waits now require `finalised`.
5.       worker results are copied into the project, where `fw termlink result` finds them.
Fixtures and fake dispatchers only; no real task is judged (sovereignty hold).
"""
import hashlib
import inspect
import json
import os
import shutil
import stat
import subprocess
import sys
import threading
import time
import uuid
from pathlib import Path

import pytest

_HERE = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(_HERE))
sys.path.insert(0, str(Path(__file__).resolve().parent))

from lib import verdict_ledger as vl  # noqa: E402
from lib.reviewer import judge_cli  # noqa: E402
import _review_runtime as rt  # noqa: E402
from t3580_judge_cli_test import (  # noqa: E402,F401
    NOCAP, TASTE, TID, FakeWorker, _judge, _mk_task, _produce, repo,
)
from t3580_round2_test import _commit_as, _crit, _ctx  # noqa: E402
from t3580_round3_test import (  # noqa: E402,F401
    HI, TERMLINK, _closed, _record, _run_worker, _why, prod, rtrepo,
)

LEDGER = _HERE / "lib" / "verdict_ledger.py"


def _ticked(root):
    return [t["ac"] for t in vl.apply(TID, root)["ticked"]]


# ── 1. HIGH: completion needs the runtime's per-dispatch secret ──────────────────────────────

class TestCompletionSecret:
    def _never_ran(self, root, did="rv-1"):
        """A registered dispatch whose worker never ran: a caller writes the row, commits it
        under the worker identity, and fakes the exit state and result stream."""
        rt.dispatch(root, did, TID)
        _record(root, did)
        _commit_as(root, f"reviewer-{did}")
        w = rt.wdir_for(root, did)
        (w / "exit_code").write_text("0\n")
        (w / "result.jsonl").write_text('{"type":"result","result":"1. [AC] x\\nVERDICT: green"}\n')
        return w

    def test_fake_exit_files_and_complete_without_the_secret_is_refused_and_apply_refuses(self, prod):
        w = self._never_ran(prod)
        with pytest.raises(vl.VerdictRefused, match="no valid completion secret"):
            vl.complete("rv-1", wdir=str(w), exit_code=0, root=prod)
        with pytest.raises(vl.VerdictRefused, match="no valid completion secret"):
            vl.complete("rv-1", wdir=str(w), exit_code=0, secret="f" * 64, root=prod)
        r = subprocess.run([sys.executable, str(LEDGER), "complete", "--dispatch-id", "rv-1",
                            "--wdir", str(w), "--exit-code", "0", "--secret-stdin"], input="guess",
                           capture_output=True, text=True, cwd=prod,
                           env={**os.environ, "PROJECT_ROOT": str(prod)})
        assert r.returncode == 1 and "no valid completion secret" in r.stderr
        assert not (prod / vl.COMPLETIONS).exists()
        assert _ticked(prod) == [] and "no-completion" in _why(prod)
        rc, lines = vl.audit(prod)
        assert rc != 0 and any("no completion" in ln for ln in lines)

    def test_control_a_started_runtime_with_its_secret_is_accepted(self, prod):
        """Renamed in round 5: this is the RUNTIME path — `take_secret` records the signed start
        run.sh makes. The never-ran path (secret read from a leftover file, no start) is the
        negative control in t3580_round5_test.TestNeverRun."""
        w = self._never_ran(prod)
        assert vl.complete("rv-1", wdir=str(w), exit_code=0, root=prod,
                           secret=rt.take_secret(prod, "rv-1"))
        assert _ticked(prod) == [1]

    def test_only_the_hash_is_registered_and_the_file_is_0600(self, prod):
        rt.dispatch(prod, "rv-1", TID)
        f = rt.wdir_for(prod, "rv-1") / vl.COMPLETION_SECRET_FILE
        assert stat.S_IMODE(f.stat().st_mode) == 0o600
        secret = f.read_text().strip()
        reg = (prod / vl.DISPATCHES).read_text()
        assert secret not in reg
        assert hashlib.sha256(secret.encode()).hexdigest() in reg

    def test_a_dispatch_registered_without_a_secret_cannot_be_completed(self, prod):
        rt.dispatch(prod, "rv-1", TID)
        rows = [json.loads(l) for l in (prod / vl.DISPATCHES).read_text().splitlines()]
        rows[0].pop("completion_secret_sha256")
        rows[0]["sig"] = vl._sign(vl._dispatch_key(prod), rows[0])     # a re-signed legacy row
        (prod / vl.DISPATCHES).write_text("".join(json.dumps(r) + "\n" for r in rows))
        (rt.wdir_for(prod, "rv-1") / "exit_code").write_text("0\n")
        with pytest.raises(vl.VerdictRefused, match="without a completion secret"):
            vl.complete("rv-1", wdir=str(rt.wdir_for(prod, "rv-1")), exit_code=0,
                        secret=rt.take_secret(prod, "rv-1"), root=prod)

    def test_real_runtime_the_worker_never_sees_the_secret(self, rtrepo):
        did, wdir, out = _run_worker(rtrepo, mode="peek")
        log = (wdir / "stderr.log").read_text()
        assert "PEEK file=0 env=0" in log, log
        assert not (wdir / ".completion-secret").exists()
        assert _ticked(rtrepo) == [1]                            # control: the runtime signed

    def test_real_runtime_a_worker_stripping_its_marker_still_cannot_complete(self, rtrepo):
        did, wdir, out = _run_worker(rtrepo, mode="forge-noenv")
        log = (wdir / "stderr.log").read_text()
        assert "FORGE rc=1" in log and "no valid completion secret" in log, log
        assert len(vl._completions_for(rtrepo, did)) == 1       # only the runtime's own
        assert _ticked(rtrepo) == [1]

    def test_the_worker_kind_run_must_be_the_registered_one(self, prod):
        rt.dispatch(prod, "rv-1", TID, worker_kind="claude")
        w = rt.wdir_for(prod, "rv-1")
        (w / "exit_code").write_text("0\n")
        with pytest.raises(vl.VerdictRefused, match="worker kind"):
            vl.complete("rv-1", wdir=str(w), exit_code=0, worker_kind="ollama-loop",
                        secret=rt.take_secret(prod, "rv-1"), root=prod)


# ── 2. HIGH: a panel counts registered vendors, not backend ids ──────────────────────────────

SEATS = [{"seat": "alias-a", "vendor": "alias-a"}, {"seat": "alias-b", "vendor": "alias-b"},
         {"seat": "alias-c", "vendor": "alias-c"}]


def _alias_panel(root, vendors):
    vl.register_run("run-p", TID, acs=[1], rung="rung-5-panel", seats=SEATS, required_vendors=3,
                    root=root)
    for s, v in zip(SEATS, vendors):
        did = f"rv-{s['seat']}"
        rt.dispatch(root, did, TID, worker_kind="claude", vendor=v)
        _record(root, did, run_id="run-p")
        _commit_as(root, f"reviewer-{did}")
        rt.finish(root, did)
        vl.bind_dispatch("run-p", s["seat"], did, s["vendor"], root=root)   # distinct labels


_ALIASES = ("backends:\n" + "".join(
    f"  - id: alias-{x}\n    name: A{x}\n    harness_class: subscription\n    cost_class: internal\n"
    f"    approval_required: false\n    cost_estimate_method: unmetered\n    description: x\n"
    f"    match:\n      - '--worker-kind[= ]claude\\b'\n    worker_kind: claude\n    vendor: anthropic\n"
    for x in "abc")
    + "  - id: openrouter\n    name: OR\n    harness_class: pay_per_use\n    cost_class: paid\n"
      "    approval_required: true\n    cost_estimate_method: tokens_estimated\n    description: x\n")


class TestVendorDiversity:
    def test_three_distinct_labels_for_one_registered_vendor_do_not_make_a_panel(self, prod):
        _alias_panel(prod, ["anthropic"] * 3)
        assert _ticked(prod) == []
        assert _closed(prod).startswith("degraded") and "span 1" in _closed(prod)

    # Round 5: the round-4 "control" (three claude dispatches registered as anthropic / vendor-2 /
    # vendor-3) was the attack itself. Its replacement, with three distinct registered KINDS, and
    # the inconsistent-registration negative controls live in t3580_round5_test.TestVendorMapping.

    def test_judge_with_three_registry_aliases_for_one_worker_kind(self, repo):
        """Application negative control: the real dispatcher table (not monkeypatched) maps all
        three aliases to one vendor, the judge reports degraded, and the ledger refuses."""
        (repo / "policy").mkdir()
        (repo / "policy" / "review-backends.yaml").write_text(_ALIASES)
        _mk_task(repo, TASTE, extra_fm=HI)
        _produce(repo)
        kv = judge_cli._kind_vendors(repo)
        w = FakeWorker("green", vendors=kv)
        res = _judge(repo, dispatcher=w, worker_kinds={"claude"})
        assert res["rung"] == 5 and len(w.calls) == 3
        assert res["dispatch_vendors"] == [kv["claude"]]
        assert res["degraded"] == judge_cli.DEGRADED_SINGLE_VENDOR
        assert res["outcomes"] != {1: "green"}
        assert _ticked(repo) == []

    def test_the_dispatcher_names_a_vendor_for_every_kind_it_accepts(self):
        kinds = subprocess.run(["bash", str(TERMLINK), "worker-kinds"], capture_output=True,
                               text=True).stdout.split()
        kv = judge_cli._kind_vendors(Path("."))
        assert kinds and set(kv) == set(kinds) and all(kv.values())

    def test_cmd_dispatch_registers_kind_and_vendor(self):
        src = TERMLINK.read_text()
        assert '--worker-kind "${worker_kind:-claude}" --ttl' in src     # round 5: no free-text vendor
        assert '--vendor' not in src.split("register-dispatch", 1)[1].split("finalise_required", 1)[0]


# ── 3. MEDIUM: a review wait returns only once the runtime has finalised ─────────────────────

def _fw_shim(tmp: Path) -> Path:
    """bin/fw's `termlink` route, and a termlink binary that knows no sessions."""
    b = tmp / "shimbin"
    b.mkdir(exist_ok=True)
    (b / "termlink").write_text("#!/bin/sh\nexit 1\n")
    (b / "termlink").chmod(0o755)
    fw = b / "fw"
    fw.write_text(f'#!/bin/bash\n[ "$1" = termlink ] && shift && exec bash {TERMLINK} "$@"\nexit 9\n')
    fw.chmod(0o755)
    return fw


class TestFinalisedWait:
    @pytest.fixture()
    def tl(self, prod, tmp_path, monkeypatch):
        did = f"judge-t-9200-r1-{uuid.uuid4().hex[:12]}"
        w = Path("/tmp/tl-dispatch") / did
        w.mkdir(parents=True)
        fw = _fw_shim(tmp_path)
        monkeypatch.setenv("PATH", f"{fw.parent}:{os.environ['PATH']}")
        yield prod, did, w, fw
        shutil.rmtree(w, ignore_errors=True)

    def test_wait_holds_past_exit_code_until_the_delayed_signing_finalises(self, tl):
        prod, did, w, fw = tl
        vl.register_dispatch(did, TID, "review", revision="", wdir=str(w), worker_kind="claude",
                             vendor="anthropic", root=prod)
        secret = (w / vl.COMPLETION_SECRET_FILE).read_text().strip()
        (w / vl.COMPLETION_SECRET_FILE).unlink()
        (w / "finalise_required").write_text("")
        _record(prod, did)
        _commit_as(prod, f"reviewer-{did}")
        (w / "result.jsonl").write_text('{"type":"result","result":"ok"}\n')
        (w / "exit_code").write_text("0\n")               # the worker has exited ...

        rc = {}
        t = threading.Thread(target=lambda: rc.update(v=judge_cli._await_worker(fw, did, prod, 30)))
        t.start()
        time.sleep(3)
        assert t.is_alive(), "wait returned on exit_code, before the runtime signed"
        crit = [{"index": 1, "ac_index": 1}]
        assert judge_cli._collect(prod, TID, did, crit)[0]["outcome"] == "unknown"  # not yet

        os.environ.pop(vl._WORKER_ENV, None)               # ... and the runtime signs, late
        vl.start(did, wdir=str(w), secret=secret, root=prod)   # round 5: (normally run.sh's first act)
        c = vl.complete(did, wdir=str(w), exit_code=0, session=did, secret=secret, root=prod)
        (w / "completion.json").write_text(json.dumps({"sig": c["sig"]}))
        (w / "finalised").write_text(f"signed:{c['sig']}\n")
        t.join(15)
        assert not t.is_alive() and rc["v"] == 0
        assert judge_cli._collect(prod, TID, did, crit)[0]["outcome"] == "green"

    def test_a_failed_signing_still_finalises_so_wait_returns(self, tl):
        prod, did, w, fw = tl
        (w / "finalise_required").write_text("")
        (w / "exit_code").write_text("0\n")
        (w / "finalised").write_text("unsigned:completion-refused\n")
        assert judge_cli._await_worker(fw, did, prod, 10) == 0

    def test_control_a_non_review_dispatch_returns_on_exit_code(self, tl):
        prod, did, w, fw = tl
        (w / "exit_code").write_text("0\n")
        t0 = time.time()
        assert judge_cli._await_worker(fw, did, prod, 10) == 0 and time.time() - t0 < 8

    def test_real_run_sh_writes_finalised_after_the_completion(self, rtrepo):
        did, wdir, out = _run_worker(rtrepo)
        sig = json.loads((wdir / "completion.json").read_text())["sig"]
        assert (wdir / "finalised").read_text().strip() == f"signed:{sig}"
        assert (wdir / "finalised").stat().st_mtime_ns >= (wdir / "completion.json").stat().st_mtime_ns


# ── 4. Z.ai lows ───────────────────────────────────────────────────────────────────────────

class TestZaiLows:
    def test_worker_session_is_recorded_from_the_result_stream(self, prod):
        rt.dispatch(prod, "rv-1", TID)
        c = rt.finish(prod, "rv-1", result=b'{"type":"system","session_id":"sess-42"}\n'
                                           b'{"type":"result","result":"x"}\n')
        assert c["worker_session"] == "sess-42"

    def test_no_default_vendor_in_the_dispatch_path(self):
        for fn in (judge_cli._dispatch_real, judge_cli._dispatch_reviewer):
            d = inspect.signature(fn).parameters["vendor"].default
            assert d in (inspect.Parameter.empty, ""), fn.__name__
        with pytest.raises(ValueError, match="no worker kind"):
            judge_cli._dispatch_reviewer(TID, "b", 1, False, Path("."), dispatcher=lambda **k: "x")

    def test_consumer_path_reason_records_the_held_calibration(self):
        imp = judge_cli._impact({"frontmatter": {"name": "x", "components": ["lib/foo.py"]}}, [])
        assert imp["tier"] == "medium" and "held at medium" in imp["reasons"][0]


# ── 5. durable worker results ────────────────────────────────────────────────────────────────

class TestDurableResult:
    def test_run_sh_copies_the_result_into_the_project(self, rtrepo):
        did, wdir, out = _run_worker(rtrepo)
        kept = rtrepo / ".context" / "dispatch-results" / f"{did}.md"
        assert kept.read_text() == (wdir / "result.md").read_text() and kept.read_text().strip()

    def test_result_falls_back_to_the_kept_copy_once_the_wdir_is_gone(self, tmp_path):
        name = f"gone-{uuid.uuid4().hex[:8]}"
        kept = tmp_path / ".context" / "dispatch-results" / f"{name}.md"
        kept.parent.mkdir(parents=True)
        kept.write_text("the verdict text\n")
        r = subprocess.run(["bash", str(TERMLINK), "result", name], capture_output=True, text=True,
                           env={**os.environ, "PROJECT_ROOT": str(tmp_path)})
        assert r.returncode == 0 and "the verdict text" in r.stdout
