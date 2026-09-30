#!/usr/bin/env python3
"""T-3580 round 3 — the LEDGER enforces, not the judge CLI.

Answers docs/reports/T-3580-round2-review-openai.md (RED: 3 high, 4 medium, 1 low). Every
negative control goes through the ledger's shared validator (`satisfying_verdict` via `apply`,
`render_verdicts`, `audit`) or through the REAL dispatch runtime (run.sh extracted from
agents/termlink/termlink.sh and executed in bash). Fixture repos and fake dispatchers only: no
real task is judged and no `.context/reviews/` is created in this repo.
"""
import json
import os
import re
import stat
import subprocess
import sys
from pathlib import Path

import pytest

_HERE = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(_HERE))
sys.path.insert(0, str(Path(__file__).resolve().parent))

from lib import verdict_ledger as vl  # noqa: E402
from lib.reviewer import judge_cli  # noqa: E402
import _review_runtime as rt  # noqa: E402
from t3580_judge_cli_test import (  # noqa: E402,F401
    ALL_KINDS, NOCAP, _all_kinds, TASTE, TID, FakeWorker, _git, _ident, _judge, _mk_task, _produce, repo,
)
from t3580_round2_test import (  # noqa: E402
    _commit_as, _crit, _ctx, _dispatch, _task_file,
)

TERMLINK = _HERE / "agents" / "termlink" / "termlink.sh"


def _head(root):
    return subprocess.run(["git", "rev-parse", "HEAD"], cwd=root, capture_output=True,
                          text=True).stdout.strip()


def _why(root, ac=1):
    return vl.satisfying_verdict(_ctx(root), _crit(root, ac))[1]


def _record(root, did, outcome="green", ac=1, **kw):
    rep = root / f".context/reviews/evidence/{TID}/AC{ac}-{did}.md"
    rep.parent.mkdir(parents=True, exist_ok=True)
    rep.write_text(f"checked {did}\n")
    if outcome != "green":
        kw.setdefault("guidance", "needs work")
    kw.setdefault("rung", "rung-1-same-vendor-independent")
    return vl.record(TID, ac, outcome, reviewer=f"reviewer-{did}:claude", dispatch_id=did,
                     digest=vl.criterion_digest(_crit(root, ac)),
                     evidence=[str(rep.relative_to(root))], root=root, **kw)


@pytest.fixture()
def prod(repo):
    _mk_task(repo, TASTE)
    (repo / "notes.md").write_text("notes v1\n")
    _produce(repo)
    return repo


# ── 1. HIGH: the completion is the RUNTIME's, never `record`'s ──────────────────────────────

class TestRuntimeCompletion:
    def test_control_worker_records_commits_exits_runtime_signs_ticks(self, prod):
        _dispatch(prod, "rv-1")
        _record(prod, "rv-1")
        _commit_as(prod, "reviewer-rv-1")
        comp = rt.finish(prod, "rv-1")
        assert comp["source"] == "runtime" and comp["session"] == "rv-1" and comp["exit_code"] == 0
        assert comp["result_sha256"] and len(comp["verdicts"]) == 1
        assert [t["ac"] for t in vl.apply(TID, prod)["ticked"]] == [1]
        assert vl.audit(prod)[0] == 0

    def test_record_cannot_manufacture_a_completion(self, prod):
        """`record` writes no completion and holds no way to sign one."""
        _dispatch(prod, "rv-1")
        _record(prod, "rv-1")
        _commit_as(prod, "reviewer-rv-1")
        assert not (prod / vl.COMPLETIONS).exists()
        assert not hasattr(vl, "make_completion")
        src = (_HERE / "lib" / "verdict_ledger.py").read_text()
        body = src[src.index("def record("):src.index("def _route_to_operator(")]
        assert "COMPLETIONS" not in body and "complete(" not in body and "_sign_row" not in body
        assert _why(prod).startswith("unknown: the latest verdict") and "no-completion" in _why(prod)

    def test_complete_refuses_inside_the_workers_own_environment(self, prod, monkeypatch):
        _dispatch(prod, "rv-1")
        _record(prod, "rv-1")
        w = rt.wdir_for(prod, "rv-1")
        (w / "exit_code").write_text("0\n")
        secret = rt.take_secret(prod, "rv-1")
        monkeypatch.setattr(vl, "_runtime_fault", lambda *a, **k: "")   # round 6: runtime double
        monkeypatch.setenv(vl._WORKER_ENV, "rv-1")
        with pytest.raises(vl.VerdictRefused, match="never from inside the worker"):
            vl.complete("rv-1", wdir=str(w), exit_code=0, secret=secret, root=prod)
        monkeypatch.delenv(vl._WORKER_ENV)
        assert vl.complete("rv-1", wdir=str(w), exit_code=0, secret=secret, root=prod)      # control

    def test_complete_refuses_before_the_worker_exited(self, prod):
        _dispatch(prod, "rv-1")
        secret = rt.take_secret(prod, "rv-1")
        with rt.as_runtime(), pytest.raises(vl.VerdictRefused, match="has not exited"):
            vl.complete("rv-1", wdir=str(rt.wdir_for(prod, "rv-1")), exit_code=0, secret=secret, root=prod)

    def test_complete_refuses_a_worker_dir_other_than_the_registered_one(self, prod, tmp_path):
        _dispatch(prod, "rv-1")
        other = tmp_path / "elsewhere"
        other.mkdir()
        (other / "exit_code").write_text("0\n")
        with pytest.raises(vl.VerdictRefused, match="is not the one registered"):
            vl.complete("rv-1", wdir=str(other), exit_code=0, secret=rt.take_secret(prod, "rv-1"), root=prod)

    def test_a_second_completion_voids_both(self, prod):
        """A worker that forges its own completion before exiting only invalidates itself."""
        _dispatch(prod, "rv-1")
        _record(prod, "rv-1")
        _commit_as(prod, "reviewer-rv-1")
        rt.finish(prod, "rv-1")          # the forgery (exit state written early)
        rt.finish(prod, "rv-1")          # the runtime's own, at real exit
        assert "completion-duplicate" in _closed(prod)
        assert vl.audit(prod)[0] == 2

    def test_a_row_written_after_the_worker_exited_does_not_count(self, prod):
        _dispatch(prod, "rv-1")
        rt.finish(prod, "rv-1")          # worker exited having written nothing
        _record(prod, "rv-1")            # someone appends in its name afterwards
        _commit_as(prod, "reviewer-rv-1")
        assert "not-in-completion" in _closed(prod)
        assert vl.audit(prod)[0] == 2

    def test_a_green_from_a_worker_that_exited_non_zero_does_not_count(self, prod):
        _dispatch(prod, "rv-1")
        _record(prod, "rv-1")
        _commit_as(prod, "reviewer-rv-1")
        rt.finish(prod, "rv-1", exit_code=137)
        assert "worker-failed" in _closed(prod)

    def test_control_a_non_green_from_a_failed_worker_is_still_attributable(self, prod):
        _dispatch(prod, "rv-1")
        _record(prod, "rv-1", "amber")
        _commit_as(prod, "reviewer-rv-1")
        rt.finish(prod, "rv-1", exit_code=1)
        assert _why(prod) == "latest verdict is 'amber'"


def _closed(root, ac=1):
    assert vl.apply(TID, root)["ticked"] == []
    return _why(root, ac)


# ── 1+5. the REAL runtime: run.sh from termlink.sh, the brief's commands in a real shell ─────

def _run_sh() -> str:
    src = TERMLINK.read_text()
    start = src.index("cat > \"$wdir/run.sh\" <<'RUNEOF'\n") + len("cat > \"$wdir/run.sh\" <<'RUNEOF'\n")
    return src[start:src.index("\nRUNEOF\n", start)] + "\n"


#: A stand-in for `claude -p`: it does what the brief says, by running the brief's OWN record and
#: commit lines in bash (placeholders filled in), so shell expansion is exercised for real.
_STUB = r'''#!/usr/bin/env python3
import os, re, subprocess, sys
prompt = sys.argv[sys.argv.index("-p") + 1]
mode = os.environ.get("STUB_MODE", "green")
did = os.environ["FW_SIDECAR_AGENT_ID"]
task = re.search(r"^Task: (T-\d+)$", prompt, re.M).group(1)
rec = next(l.strip() for l in prompt.splitlines() if l.strip().startswith("bin/fw reviewer verdict record"))
com = next(l.strip() for l in prompt.splitlines() if l.strip().startswith("git add .context/reviews"))
dg = subprocess.run(["bin/fw", "reviewer", "verdict", "digest", task, "--ac", "1"],
                    capture_output=True, text=True, check=True).stdout.strip()
rep = f".context/reviews/evidence/{task}/AC1-{did}.md"
os.makedirs(os.path.dirname(rep), exist_ok=True)
open(rep, "w").write("checked\n")
if mode == "forge":   # try to sign its own completion from inside the worker
    r = subprocess.run([sys.executable, os.environ["LEDGER"], "complete", "--dispatch-id", did,
                        "--wdir", os.environ["WDIR_EXPECTED"], "--exit-code", "0"],
                       capture_output=True, text=True)
    print("FORGE rc=%d %s" % (r.returncode, r.stderr.strip()), file=sys.stderr)
if mode == "forge-noenv":   # round 4: strip the worker marker and try without the secret
    env = {k: v for k, v in os.environ.items() if k != "FW_SIDECAR_AGENT_ID"}
    open(os.path.join(os.environ["WDIR_EXPECTED"], "exit_code"), "w").write("0\n")
    r = subprocess.run([sys.executable, os.environ["LEDGER"], "complete", "--dispatch-id", did,
                        "--wdir", os.environ["WDIR_EXPECTED"], "--exit-code", "0", "--secret-stdin"],
                       input="", capture_output=True, text=True, env=env)
    print("FORGE rc=%d %s" % (r.returncode, r.stderr.strip()), file=sys.stderr)
if mode == "peek":   # round 4: can the worker see the completion secret? (round 6: issued at start)
    import hashlib, json as _j
    want = next(_j.loads(l)["secret_sha256"]
                for l in open(".context/reviews/review-completions.jsonl")
                if did in l and '"start"' in l)
    f = os.path.join(os.environ["WDIR_EXPECTED"], ".completion-secret")
    in_env = any(hashlib.sha256(v.strip().encode()).hexdigest() == want for v in os.environ.values())
    print("PEEK file=%d env=%d" % (os.path.exists(f), in_env), file=sys.stderr)
line = (rec.replace("<N>", "1").replace("<OUTCOME>", "green").replace("<DIGEST>", dg)
           .replace("<REPORT>", rep))
subprocess.run(["bash", "-c", line], check=True, stdout=sys.stderr)   # keep the stream JSON-only
subprocess.run(["bash", "-c", com], check=True, stdout=sys.stderr)
print('{"type":"result","result":"1. [AC] x\\nVERDICT: green"}')
sys.exit(3 if mode == "fail" else 0)
'''


@pytest.fixture()
def rtrepo(repo):
    """A fixture project wired like a consumer: .agentic-framework -> this framework (so run.sh
    resolves FRAMEWORK_ROOT to a tree holding lib/verdict_ledger.py), and a bin/fw shim routing
    `reviewer verdict` to the ledger CLI."""
    (repo / ".agentic-framework").symlink_to(_HERE)
    (repo / "bin").mkdir()
    shim = repo / "bin" / "fw"
    shim.write_text(f'#!/bin/bash\n[ "$1 $2" = "reviewer verdict" ] && shift 2 && '
                    f'exec python3 {_HERE}/lib/verdict_ledger.py "$@"\nexit 9\n')
    shim.chmod(shim.stat().st_mode | stat.S_IEXEC)
    _mk_task(repo, TASTE)
    _produce(repo)
    return repo


def _run_worker(root, mode="green"):
    """Register exactly as cmd_dispatch does, then execute the real run.sh with the stub claude."""
    did = "judge-t-9200-r1-a1b2c3d4e5f6"
    wdir = root.parent / f"{root.name}-tl" / did
    wdir.mkdir(parents=True)
    brief = judge_cli._build_brief(TID, [{"index": 1, "ac_index": 1, "body": "x", "render": False}],
                                   revision=_head(root))
    (wdir / "prompt.md").write_text(brief)
    (wdir / "task").write_text(TID)
    stub_dir = root.parent / f"{root.name}-stub"
    stub_dir.mkdir()
    (stub_dir / "claude").write_text(_STUB)
    (stub_dir / "claude").chmod(0o755)
    # Round 7: the worker binary is resolved to an absolute path AT DISPATCH and registered; run.sh
    # launches exactly that (the stub here), never whatever `claude` PATH finds at run time.
    (wdir / "worker_bin").write_text(f"{stub_dir / 'claude'}\n")
    (wdir / "env.sh").write_text(f"export FW_SIDECAR_AGENT_ID={did}\n"
                                 f"export FW_REVIEW_REVISION={_head(root)}\n"
                                 f"export GIT_AUTHOR_NAME='fw worker' GIT_AUTHOR_EMAIL=w@x.y "
                                 f"GIT_COMMITTER_NAME='fw worker' GIT_COMMITTER_EMAIL=w@x.y\n")
    (wdir / "run.sh").write_text(_run_sh())
    r = subprocess.run([sys.executable, str(_HERE / "lib/verdict_ledger.py"), "register-dispatch",
                        "--dispatch-id", did, "--task", TID, "--task-type", "review",
                        "--revision", _head(root), "--wdir", str(wdir),
                        "--worker-bin", str(stub_dir / "claude")],
                       cwd=root, env={**os.environ, "PROJECT_ROOT": str(root)}, capture_output=True, text=True)
    assert r.returncode == 0, r.stderr
    (stub_dir / "termlink").write_text("#!/bin/sh\nexit 0\n")
    (stub_dir / "termlink").chmod(0o755)
    env = {k: v for k, v in os.environ.items() if not k.startswith(("FW_", "GIT_"))}
    env.update(PATH=f"{stub_dir}:{os.environ['PATH']}", STUB_MODE=mode,
               LEDGER=str(_HERE / "lib/verdict_ledger.py"), WDIR_EXPECTED=str(wdir))
    env.pop("PROJECT_ROOT", None)
    # Output to a file, not a pipe: run.sh's watchdog `sleep` outlives it and would hold a pipe open.
    with (wdir.parent / f"{did}.out").open("w") as fh:
        out = subprocess.run(["bash", str(wdir / "run.sh"), did, str(root), str(wdir), "60", "",
                              "review", ""], stdout=fh, stderr=subprocess.STDOUT, env=env, timeout=120)
    return did, wdir, (wdir.parent / f"{did}.out").read_text()


class TestRealRuntime:
    def test_control_run_sh_signs_the_completion_after_the_worker_exits(self, rtrepo):
        did, wdir, out = _run_worker(rtrepo)
        assert (wdir / "exit_code").read_text().strip() == "0", out + (wdir / "stderr.log").read_text()
        comps = vl._completions_for(rtrepo, did)
        assert len(comps) == 1, (wdir / "stderr.log").read_text()
        c = comps[0]
        assert c["source"] == "runtime" and c["session"] == did and c["exit_code"] == 0
        assert c["result_sha256"] == vl._result_sha(wdir)
        row = vl._read(vl.VERDICTS, rtrepo)[-1]
        # 5. the brief's double-quoted reviewer expanded in a real shell
        assert row["reviewer"] == f"reviewer-{did}:reviewer" and row["worker"] == f"reviewer-{did}"
        log = subprocess.run(["git", "log", "-1", "--format=%an|%cn"], cwd=rtrepo,
                             capture_output=True, text=True).stdout.strip()
        assert log == f"reviewer-{did}|reviewer-{did}"
        assert [t["ac"] for t in vl.apply(TID, rtrepo)["ticked"]] == [1]
        assert vl.audit(rtrepo)[0] == 0

    def test_a_worker_signing_its_own_completion_is_refused_and_voids_nothing_else(self, rtrepo):
        did, wdir, out = _run_worker(rtrepo, mode="forge")
        assert "FORGE rc=1" in (wdir / "stderr.log").read_text()
        assert "never from inside the worker" in (wdir / "stderr.log").read_text()
        assert len(vl._completions_for(rtrepo, did)) == 1           # only the runtime's
        assert [t["ac"] for t in vl.apply(TID, rtrepo)["ticked"]] == [1]

    def test_a_worker_that_exits_non_zero_leaves_a_green_that_does_not_count(self, rtrepo):
        did, wdir, out = _run_worker(rtrepo, mode="fail")
        assert vl._completions_for(rtrepo, did)[0]["exit_code"] == 3
        assert "worker-failed" in _closed(rtrepo)


class TestBriefQuoting:
    def _exec(self, tmp_path, line, did):
        fw = tmp_path / "bin" / "fw"
        fw.parent.mkdir()
        fw.write_text('#!/usr/bin/env python3\nimport json,sys\nprint(json.dumps(sys.argv[1:]))\n')
        fw.chmod(0o755)
        line = (line.replace("<N>", "1").replace("<OUTCOME>", "green").replace("<DIGEST>", "d")
                    .replace("<REPORT>", "r.md"))
        r = subprocess.run(["bash", "-c", line], cwd=tmp_path, capture_output=True, text=True,
                           env={**os.environ, "FW_SIDECAR_AGENT_ID": did})
        argv = json.loads(r.stdout)
        return argv[argv.index("--reviewer") + 1], argv[argv.index("--dispatch-id") + 1]

    def test_generated_record_command_expands_the_dispatch_id_in_a_real_shell(self, tmp_path):
        brief = judge_cli._build_brief(TID, [{"index": 1, "ac_index": 1, "body": "x"}], rung=5,
                                       seat="codex", run_id="run-x")
        line = next(l.strip() for l in brief.splitlines()
                    if l.strip().startswith("bin/fw reviewer verdict record"))
        assert self._exec(tmp_path, line, "rv-9") == ("reviewer-rv-9:codex", "rv-9")

    def test_negative_control_the_round_2_single_quoted_form_does_not_expand(self, tmp_path):
        line = judge_cli.record_command(TID, "codex", 5, "run-x").replace(
            '"reviewer-$FW_SIDECAR_AGENT_ID:codex"', "'reviewer-$FW_SIDECAR_AGENT_ID:codex'")
        assert self._exec(tmp_path, line, "rv-9")[0] == "reviewer-$FW_SIDECAR_AGENT_ID:codex"

    def test_generated_commit_command_commits_as_the_worker(self, prod):
        _dispatch(prod, "rv-1")
        _record(prod, "rv-1")
        r = subprocess.run(["bash", "-c", judge_cli.commit_command(TID)], cwd=prod, text=True,
                           capture_output=True, env={**os.environ, "FW_SIDECAR_AGENT_ID": "rv-1"})
        assert r.returncode == 0, r.stderr
        log = subprocess.run(["git", "log", "-1", "--format=%an|%cn"], cwd=prod, capture_output=True,
                             text=True).stdout.strip()
        assert log == "reviewer-rv-1|reviewer-rv-1"


# ── 2. HIGH: the reviewed revision is captured before the review, not at record time ─────────

class TestReviewedRevision:
    def test_control_unchanged_implementation_ticks(self, prod):
        rev = _head(prod)
        _dispatch(prod, "rv-1", revision=rev)
        row = _record(prod, "rv-1")
        _commit_as(prod, "reviewer-rv-1")
        rt.finish(prod, "rv-1")
        assert row["revision"] == rev
        assert [t["ac"] for t in vl.apply(TID, prod)["ticked"]] == [1]

    def _change_during_review(self, prod, did):
        rev = _head(prod)
        _dispatch(prod, did, revision=rev)
        (prod / "notes.md").write_text(f"notes changed during review {did}\n")
        _git(prod, "add", "notes.md")
        _git(prod, "commit", "-q", "-m", f"{TID}: change the implementation", env=_ident("Builder Bot"))
        return rev

    def test_implementation_changed_between_review_and_record(self, prod, monkeypatch):
        """Negative control: work lands WHILE the reviewer reviews. `record` refuses the green;
        a row that gets past `record` anyway is bound to what was reviewed (not HEAD at record)
        and the shared validator refuses it at apply."""
        rev = self._change_during_review(prod, "rv-1")
        with pytest.raises(vl.VerdictRefused, match="work changed after reviewed revision"):
            _record(prod, "rv-1")
        with monkeypatch.context() as m:
            m.setattr(vl, "_stale_fault", lambda *a, **k: None)
            row = _record(prod, "rv-1")
        _commit_as(prod, "reviewer-rv-1")
        comp = rt.finish(prod, "rv-1")
        assert row["revision"] == rev != _head(prod) and comp["revision"] == rev
        why = _closed(prod)
        assert "stale-review" in why and "notes.md" in why

    def test_a_non_green_recorded_after_the_change_is_bound_to_the_reviewed_revision(self, prod):
        rev = self._change_during_review(prod, "rv-1")
        row = _record(prod, "rv-1", "amber")
        assert row["revision"] == rev != _head(prod)

    def test_an_unrelated_commit_moving_head_does_not_rebind_the_row(self, prod):
        rev = _head(prod)
        _dispatch(prod, "rv-1", revision=rev)
        (prod / "other.txt").write_text("x\n")
        _git(prod, "add", "other.txt")
        _git(prod, "commit", "-q", "-m", "unrelated", env=_ident("Someone"))
        row = _record(prod, "rv-1")
        _commit_as(prod, "reviewer-rv-1")
        rt.finish(prod, "rv-1")
        assert row["revision"] == rev and [t["ac"] for t in vl.apply(TID, prod)["ticked"]] == [1]

    def test_a_row_naming_another_revision_than_its_dispatch_is_refused(self, prod):
        rev = _head(prod)
        _dispatch(prod, "rv-1", revision=rev)
        _record(prod, "rv-1")
        rows = vl._read(vl.VERDICTS, prod)
        (prod / "x.txt").write_text("x")
        _git(prod, "add", "x.txt")
        _git(prod, "commit", "-q", "-m", "later", env=_ident("Someone"))
        rows[-1]["revision"] = _head(prod)
        (prod / vl.VERDICTS).write_text(json.dumps(rows[-1]) + "\n")
        _commit_as(prod, "reviewer-rv-1")
        rt.finish(prod, "rv-1")
        assert "the dispatch was issued to review" in _closed(prod)

    def test_judge_captures_head_before_dispatch_and_hands_it_to_the_dispatcher(self, prod):
        head = _head(prod)
        w = FakeWorker("green")
        res = _judge(prod, dispatcher=w)
        assert res["revision"] == head and w.calls[0]["revision"] == head
        assert vl.dispatch_record(prod, w.calls[0]["did"])[0]["revision"] == head
        assert f"You review revision `{head}`" in w.calls[0]["brief"]

    def test_dispatch_argv_carries_the_revision_and_termlink_parses_it(self):
        argv = judge_cli._dispatch_argv(Path("fw"), task_id=TID, name="n", prompt_file=Path("p"),
                                        root=Path("/r"), vendor="claude", timeout=1, revision="abc")
        assert argv[argv.index("--review-revision") + 1] == "abc"
        sh = TERMLINK.read_text()
        assert "--review-revision)" in sh
        assert '--revision "$review_revision" --wdir "$wdir"' in sh


# ── 3. HIGH: every required page is kept; capture is capped, the requirement is not ──────────

SEVEN = [f"/p{i}" for i in range(1, 8)]
RENDER7 = ("- [ ] [REVIEW] The dashboard layout reads clearly when rendered at "
           + ", ".join(f"`{p}`" for p in SEVEN) + "\n"
           "  **Steps:**\n  1. Open the pages\n  **Expected:** tidy\n  **If not:** note it\n")


def _capture_all(url, pages, out):
    out.mkdir(parents=True, exist_ok=True)
    shots = []
    for i, pg in enumerate(pages):
        p = out / judge_cli._shot_name(i, pg)
        p.write_bytes(pg.encode())
        shots.append(p)
    return shots, ""


@pytest.fixture()
def r7(repo):
    (repo / "web/blueprints").mkdir(parents=True)
    (repo / "web/blueprints/dash.py").write_text("x = 1\n")
    _mk_task(repo, RENDER7, extra_fm="components:\n  - web/blueprints/dash.py\n")
    _produce(repo)
    return repo


class TestSevenPages:
    def test_every_page_is_registered_and_the_seventh_is_recorded_uncaptured(self, r7):
        w = FakeWorker("green")
        res = _judge(r7, dispatcher=w, capture=_capture_all)
        run = next(r for r in vl._read(vl.RUNS, r7) if r.get("kind") == "run")
        assert run["pages"] == {"1": SEVEN}
        caps = {c["page"]: c for c in run["captures"]}
        assert all(caps[p]["ok"] for p in SEVEN[:6])
        assert not caps["/p7"]["ok"] and "capped" in caps["/p7"]["error"]
        assert "did NOT see: `/p7`" in w.calls[0]["brief"]
        assert res["outcomes"] == {1: "unknown"}             # the worker's green is refused

    def test_ledger_refuses_a_green_missing_the_seventh_page(self, r7, monkeypatch):
        """Application negative control: the row gets past `record` (its run check bypassed) and
        apply / check-render still refuse it, naming the seventh page."""
        shots = {}
        for p in SEVEN[:6]:
            f = r7 / f"shot{p.strip('/')}.png"
            f.write_bytes(p.encode())
            shots[p] = f
        caps = [{"page": p, "ok": True, "sha256": vl._hash_path(shots[p]), "error": ""} for p in SEVEN[:6]]
        caps.append({"page": "/p7", "ok": False, "sha256": "", "error": "not captured: capped"})
        rt.register_run("run-7", TID, acs=[1], rung="rung-3-termlink-single-reviewer",
                        seats=[{"seat": "claude", "vendor": "claude"}], pages={"1": SEVEN},
                        captures=caps, root=r7)
        rt.dispatch(r7, "rv-1", TID, run_id="run-7", seat="claude")     # round 6: bound pre-launch
        with monkeypatch.context() as m:
            m.setattr(vl, "_run_fault", lambda *a, **k: None)
            rep = r7 / f".context/reviews/evidence/{TID}/AC1-rv-1.md"
            rep.parent.mkdir(parents=True, exist_ok=True)
            rep.write_text("looked\n")
            vl.record(TID, 1, "green", reviewer="reviewer-rv-1:claude",
                      rung="rung-3-termlink-single-reviewer", dispatch_id="rv-1",
                      digest=vl.criterion_digest(_crit(r7)), run_id="run-7", root=r7,
                      evidence=[str(rep.relative_to(r7))] + [f.name for f in shots.values()])
        _commit_as(r7, "reviewer-rv-1")
        rt.finish(r7, "rv-1")
        why = _closed(r7)
        assert "unseen-page" in why and "'/p7'" in why
        assert vl.render_verdicts(TID, r7) == []

    def test_control_six_pages_all_captured_reach_green(self, repo):
        six = SEVEN[:6]
        crit = RENDER7.replace(", `/p7`", "")
        (repo / "web/blueprints").mkdir(parents=True)
        (repo / "web/blueprints/dash.py").write_text("x = 1\n")
        _mk_task(repo, crit, extra_fm="components:\n  - web/blueprints/dash.py\n")
        _produce(repo)
        res = _judge(repo, dispatcher=FakeWorker("green"), capture=_capture_all)
        run = next(r for r in vl._read(vl.RUNS, repo) if r.get("kind") == "run")
        assert run["pages"] == {"1": six} and res["outcomes"] == {1: "green"}


# ── 4. MEDIUM: an invalid latest row is `unknown`, whatever colour it claims ────────────────

class TestValidateBeforeReport:
    def test_committed_red_with_no_completion_is_unknown_not_red(self, prod):
        _dispatch(prod, "rv-1")
        _record(prod, "rv-1", "red")
        _commit_as(prod, "reviewer-rv-1")                 # no runtime completion
        why = _why(prod)
        assert why.startswith("unknown:") and "no-completion" in why and "'red'" not in why

    def test_control_valid_red_is_reported_red(self, prod):
        _dispatch(prod, "rv-1")
        _record(prod, "rv-1", "red")
        _commit_as(prod, "reviewer-rv-1")
        rt.finish(prod, "rv-1")
        assert _why(prod) == "latest verdict is 'red'"

    def test_apply_withdraws_with_the_unknown_reason(self, prod):
        _dispatch(prod, "rv-1")
        _record(prod, "rv-1")
        _commit_as(prod, "reviewer-rv-1")
        rt.finish(prod, "rv-1")
        assert vl.apply(TID, prod)["ticked"]
        _dispatch(prod, "rv-2")
        _record(prod, "rv-2", "red")                      # a later red with no completion
        _commit_as(prod, "reviewer-rv-2")
        res = vl.apply(TID, prod)
        assert res["withdrawn"] and res["withdrawn"][0]["why"].startswith("unknown:")

    def test_judge_reports_an_invalid_red_as_unknown(self, prod):
        res = _judge(prod, dispatcher=FakeWorker("red", runtime=False))
        assert res["outcomes"] == {1: "unknown"}
        assert "no-completion" in res["dispatches"][0]["results"][0]["why"]


# ── 7. cost: the registry decides the seats, every seat logs a cost, paid seats only propose ──

def _costs(root, name="reviews.jsonl"):
    p = root / ".context" / "costs" / name
    return [json.loads(x) for x in p.read_text().splitlines() if x.strip()] if p.exists() else []


HI = "cost_estimate:\n  blast_radius: 9\n"


class TestCostIntegration:
    def test_seats_are_read_from_the_registry_not_hardcoded(self, repo, monkeypatch):
        """A fixture registry with a new internal backend: the judge dispatches IT. (Round 6: the
        registry is committed by _produce, and the kind is made launchable — a registry entry
        alone is not a worker.)"""
        rt.launchable(monkeypatch, {"acme"})
        (repo / "policy").mkdir()
        (repo / "policy" / "review-backends.yaml").write_text(
            "backends:\n"
            "  - id: acme-review\n    name: Acme\n    harness_class: subscription\n"
            "    cost_class: internal\n    approval_required: false\n    cost_estimate_method: unmetered\n"
            "    description: x\n    match:\n      - '--worker-kind[= ]acme\\b'\n"
            "    worker_kind: acme\n    vendor: acme-corp\n"      # round 5: the one kind→vendor mapping
            "  - id: openrouter\n    name: OR\n    harness_class: pay_per_use\n    cost_class: paid\n"
            "    approval_required: true\n    cost_estimate_method: tokens_estimated\n    description: x\n")
        _mk_task(repo, TASTE)
        _produce(repo)
        w = FakeWorker("green")
        res = _judge(repo, dispatcher=w, worker_kinds={"acme"})
        assert [c["vendor"] for c in w.calls] == ["acme"] and res["outcomes"] == {1: "green"}
        assert [c["backend"] for c in _costs(repo)] == ["acme-review"]

    def test_the_module_names_no_vendor(self):
        src = (_HERE / "lib" / "reviewer" / "judge_cli.py").read_text()
        code = re.sub(r'(?s)""".*?"""', "", src)
        code = "\n".join(l.split("#", 1)[0] for l in code.splitlines())
        for vendor in ("claude", "codex", "opencode", "openrouter", "claude-code", "anthropic"):
            assert f'"{vendor}"' not in code, vendor

    def test_one_cost_record_per_dispatched_seat(self, repo, monkeypatch):
        _all_kinds(monkeypatch, repo)
        _mk_task(repo, TASTE, extra_fm=HI)
        _produce(repo)
        w = FakeWorker("green")
        res = _judge(repo, dispatcher=w)
        recs = _costs(repo)
        assert [r["backend"] for r in recs] == ["claude-code", "codex", "opencode"]
        assert all(r["class"] == "internal" and res["run_id"] in r["purpose"] for r in recs)
        assert [r["evidence"] for r in recs] == [c["did"] for c in w.calls]
        assert res["cost_log_errors"] == [] and not _costs(repo, "proposals.jsonl")

    def test_control_single_seat_logs_one_record(self, prod):
        _judge(prod, dispatcher=FakeWorker("green"))
        assert [r["backend"] for r in _costs(prod)] == ["claude-code"]

    def test_paid_rung_proposes_and_waits_never_dispatching(self, repo):
        _mk_task(repo, TASTE, extra_fm=HI)
        _produce(repo)
        w = FakeWorker("green")
        res = _judge(repo, dispatcher=w, worker_kinds={"claude"})
        assert [c["vendor"] for c in w.calls] == ["claude"]           # only the internal seat
        props = _costs(repo, "proposals.jsonl")
        assert [p["backend"] for p in props] == ["openrouter", "openrouter"]
        assert all(p["event"] == "proposed" and p["estimate_cost"] for p in props)
        assert {p["seat"] for p in res["proposals"]} == {"codex", "opencode"}
        waiting = [d for d in res["dispatches"] if d.get("proposal_id")]
        assert all(d["status"] == "awaiting-approval" and "dispatch_id" not in d for d in waiting)
        assert [r["backend"] for r in _costs(repo)] == ["claude-code"]  # no paid cost logged
        assert res["outcomes"] == {1: "unknown"}
        assert vl.apply(TID, repo)["ticked"] == []                      # the ledger keeps it open

    def test_a_rerun_reuses_the_open_proposal(self, repo):
        _mk_task(repo, TASTE, extra_fm=HI)
        _produce(repo)
        _judge(repo, dispatcher=FakeWorker("green"), worker_kinds={"claude"})
        _judge(repo, dispatcher=FakeWorker("green"), worker_kinds={"claude"})
        assert len(_costs(repo, "proposals.jsonl")) == 2

    def test_an_approved_paid_proposal_is_still_not_dispatched(self, repo, monkeypatch):
        _mk_task(repo, TASTE, extra_fm=HI)
        _produce(repo)
        _judge(repo, dispatcher=FakeWorker("green"), worker_kinds={"claude"})
        with judge_cli._Env(repo) as rc:
            for p in list(rc.proposals().values()):
                rc.approve(pid=p["id"], i_am_human=True, reason="test")
        w = FakeWorker("green")
        res = _judge(repo, dispatcher=w, worker_kinds={"claude"})
        assert [c["vendor"] for c in w.calls] == ["claude"]
        assert all("never dispatches a paid backend" in d["status"]
                   for d in res["dispatches"] if d.get("proposal_id"))

    def test_an_invalid_registry_refuses_the_run(self, repo):
        (repo / "policy").mkdir()
        (repo / "policy" / "review-backends.yaml").write_text(
            "backends:\n  - id: openrouter\n    name: OR\n    harness_class: pay_per_use\n"
            "    cost_class: internal\n    approval_required: false\n    cost_estimate_method: x\n"
            "    description: x\n")
        _mk_task(repo, TASTE)
        _produce(repo)
        w = FakeWorker("green")
        res = _judge(repo, dispatcher=w)
        assert res["code"] == 1 and "registry" in res["error"] and not w.calls


def test_worker_kinds_printed_are_the_ones_dispatch_accepts():
    kinds = subprocess.run(["bash", str(TERMLINK), "worker-kinds"], capture_output=True,
                           text=True).stdout.split()
    case = next(l for l in TERMLINK.read_text().splitlines() if re.match(r'^\s+""\|.*\)', l))
    accepted = set(case.strip().rstrip(": ;").split(")")[0].split("|")) - {'""'}
    assert kinds and set(kinds) == accepted
