"""T-5216 (T-5211 slice 1): the decide chain posts ONE non-urgent notice to the
project's own sidecar inbox after the decision commit lands.

Pinned here, with the sender stubbed (no real sidecar traffic):
  1. exactly one notice per decision, after the decision commit, through
     `fw sidecar send --to <own id> --notice`, carrying id, verdict and commit;
  2. a failed post (sender missing, non-zero exit, timeout) leaves the decision
     and its commits unchanged and is recorded in the run status;
  3. a second pass (follow-up commit, a re-run) does not post again;
  4. the body holds only id, verdict, commit and the fixed next-step line.
"""
from __future__ import annotations

import stat
import sys
from types import SimpleNamespace
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO_ROOT))

from web import decide_runner as dr  # noqa: E402
import web.shared as shared  # noqa: E402
import web.blueprints.inception as insp  # noqa: E402

TASK = "T-9901"
SHA = "abc1234"
SECRET = "TASK-BODY-SECRET-do-not-leak"


def _script(path: Path, body: str) -> str:
    path.write_text("#!/usr/bin/env bash\n" + body)
    path.chmod(path.stat().st_mode | stat.S_IEXEC)
    return str(path)


@pytest.fixture
def env(tmp_path, monkeypatch):
    """A project root, a fake fw chain that writes nothing, and stubbed commits."""
    root = tmp_path / "proj"
    (root / ".context" / "working" / "decide").mkdir(parents=True)
    monkeypatch.setattr(shared, "PROJECT_ROOT", root)
    commits = []

    def fake_commit(task_id, decision, followup=False):
        commits.append(followup)
        return True, f"{task_id}: inception decision {decision.upper()}"

    monkeypatch.setattr(insp, "_commit_decision", fake_commit)
    monkeypatch.setattr(insp, "_decision_recorded_in_task", lambda t, d: True)
    monkeypatch.setattr(dr, "_primary_landed", lambda t, d: True)
    monkeypatch.setattr(dr, "_decision_commit_id", lambda t, d: SHA)
    monkeypatch.setattr(dr, "_own_address", lambda: "proj")
    monkeypatch.delenv("FW_DECIDE_LOCK_FD", raising=False)
    # The chain itself: sleeps briefly so the runner's poll loop sees it running.
    fw = _script(tmp_path / "fw", "sleep 0.8\nexit 0\n")

    return SimpleNamespace(root=root, fw=fw, commits=commits, tmp=tmp_path)


def _run_dir(e, n=1):
    d = e.root / ".context" / "working" / "decide" / f"{TASK}-run{n}"
    d.mkdir()
    return d


def _stub_sender(monkeypatch, result=(True, "sent")):
    calls = []

    def fake(fw_bin, to, body):
        calls.append((fw_bin, to, body))
        return result
    monkeypatch.setattr(dr, "_send_notice", fake)
    return calls


# ---------------------------------------------------------------- 1. one notice

@pytest.mark.parametrize("decision,verdict", [("go", "GO"), ("no-go", "NO-GO"), ("defer", "DEFER")])
def test_one_notice_after_the_decision_commit(env, monkeypatch, decision, verdict):
    calls = _stub_sender(monkeypatch)
    run = _run_dir(env)
    assert dr._run(run, env.fw, TASK, decision, SECRET) == 0
    assert len(calls) == 1, calls
    _, to, body = calls[0]
    assert to == "proj"
    assert TASK in body and verdict in body and SHA in body
    st = dr.read_status(run)
    assert st["notice"]["state"] == "sent" and st["notice"]["commit"] == SHA
    assert st["commit_ok"] is True and st["state"] == "done"
    # posted after the primary commit (False = primary, True = follow-up)
    assert env.commits[0] is False


def test_no_notice_when_no_decision_commit_exists(env, monkeypatch):
    calls = _stub_sender(monkeypatch)
    monkeypatch.setattr(dr, "_decision_commit_id", lambda t, d: "")
    dr._run(_run_dir(env), env.fw, TASK, "go", SECRET)
    assert calls == []


def test_no_notice_when_the_commit_failed(env, monkeypatch):
    calls = _stub_sender(monkeypatch)
    monkeypatch.setattr(insp, "_commit_decision", lambda t, d, followup=False: (False, "hook refused"))
    run = _run_dir(env)
    dr._run(run, env.fw, TASK, "go", SECRET)
    assert calls == []
    assert "notice" not in dr.read_status(run)


def test_real_sender_invokes_fw_sidecar_send_notice(env, tmp_path):
    """The real _send_notice, against a fake fw that records its argv."""
    argv_file = tmp_path / "argv"
    fw = _script(tmp_path / "fw-rec", f'printf "%s\\n" "$@" > "{argv_file}"\nexit 0\n')
    ok, detail = dr._send_notice(fw, "proj", "hello")
    assert ok and detail == "sent"
    assert argv_file.read_text().splitlines() == [
        "sidecar", "send", "--to", "proj", "--notice", "--body", "hello"]


# ---------------------------------------------------------------- 2. failures

def _assert_failure_recorded(env, run, reason_fragment):
    st = dr.read_status(run)
    assert st["notice"]["state"] == "failed", st
    assert reason_fragment in st["notice"]["reason"]
    # decision outcome and commits untouched
    assert st["state"] == "done" and st["rc"] == 0 and st["commit_ok"] is True
    assert st["primary_commit_ok"] is True
    assert env.commits == [False, True]


def test_sender_missing(env, monkeypatch):
    # the chain's fw is real; the notice's sender is a path that does not exist
    real = dr._send_notice
    missing = str(env.tmp / "no-such-fw")
    monkeypatch.setattr(dr, "_send_notice", lambda fw_bin, to, body: real(missing, to, body))
    run = _run_dir(env)
    assert dr._run(run, env.fw, TASK, "go", SECRET) == 0
    _assert_failure_recorded(env, run, "could not run the sender")


def test_sender_nonzero_exit(env, monkeypatch):
    bad = _script(env.tmp / "fw-bad", 'echo "no receiver for proj" >&2\nexit 3\n')
    real = dr._send_notice
    monkeypatch.setattr(dr, "_send_notice", lambda fw_bin, to, body: real(bad, to, body))
    run = _run_dir(env)
    assert dr._run(run, env.fw, TASK, "go", SECRET) == 0
    _assert_failure_recorded(env, run, "exit 3: no receiver for proj")


def test_sender_timeout(env, monkeypatch):
    slow = _script(env.tmp / "fw-slow", "sleep 5\n")
    real = dr._send_notice
    monkeypatch.setattr(dr, "NOTICE_TIMEOUT", 0.3)
    monkeypatch.setattr(dr, "_send_notice", lambda fw_bin, to, body: real(slow, to, body))
    run = _run_dir(env)
    assert dr._run(run, env.fw, TASK, "go", SECRET) == 0
    _assert_failure_recorded(env, run, "timed out")


def test_own_address_unknown_is_recorded_not_raised(env, monkeypatch):
    calls = _stub_sender(monkeypatch)

    def boom():
        raise RuntimeError("project id resolved to '.agentic-framework'")
    monkeypatch.setattr(dr, "_own_address", boom)
    run = _run_dir(env)
    assert dr._run(run, env.fw, TASK, "go", SECRET) == 0
    assert calls == []
    _assert_failure_recorded(env, run, "own sidecar address unknown")


def test_sender_raising_is_recorded_not_raised(env, monkeypatch):
    def boom(fw_bin, to, body):
        raise OSError("disk gone")
    monkeypatch.setattr(dr, "_send_notice", boom)
    run = _run_dir(env)
    assert dr._run(run, env.fw, TASK, "go", SECRET) == 0
    _assert_failure_recorded(env, run, "notice step error")


# ---------------------------------------------------------------- 3. once only

def test_followup_commit_does_not_post_again(env, monkeypatch):
    calls = _stub_sender(monkeypatch)
    dr._run(_run_dir(env), env.fw, TASK, "go", SECRET)
    assert env.commits == [False, True]  # both commits ran
    assert len(calls) == 1


def test_rerun_of_the_same_decision_does_not_post_again(env, monkeypatch):
    calls = _stub_sender(monkeypatch)
    dr._run(_run_dir(env, 1), env.fw, TASK, "go", SECRET)
    run2 = _run_dir(env, 2)
    dr._run(run2, env.fw, TASK, "go", SECRET)
    assert len(calls) == 1
    assert dr.read_status(run2)["notice"]["state"] == "skipped"


def test_a_new_decision_commit_does_post(env, monkeypatch):
    """Once per decision, not once per task: a later re-decision gets its own notice."""
    calls = _stub_sender(monkeypatch)
    dr._run(_run_dir(env, 1), env.fw, TASK, "defer", SECRET)
    monkeypatch.setattr(dr, "_decision_commit_id", lambda t, d: "def5678")
    dr._run(_run_dir(env, 2), env.fw, TASK, "go", SECRET)
    assert len(calls) == 2


def test_failed_post_is_not_retried_within_the_run(env, monkeypatch):
    calls = _stub_sender(monkeypatch, result=(False, "exit 1: boom"))
    dr._run(_run_dir(env), env.fw, TASK, "go", SECRET)
    assert len(calls) == 1


# ---------------------------------------------------------------- 4. content

@pytest.mark.parametrize("decision", ["go", "no-go", "defer"])
def test_notice_holds_only_id_verdict_commit_and_next_step(decision):
    body = dr.notice_text(TASK, decision, SHA)
    assert body == (f"Inception {TASK} decided {decision.upper()} by the operator "
                    f"(commit {SHA}). {dr.NOTICE_NEXT_STEP[decision]}")


def test_no_task_text_reaches_the_notice(env, monkeypatch):
    calls = _stub_sender(monkeypatch)
    # task file text and the rationale must not leak into the body
    (env.root / ".tasks" / "completed").mkdir(parents=True)
    (env.root / ".tasks" / "completed" / f"{TASK}-x.md").write_text(f"# {TASK}\n{SECRET}\n")
    dr._run(_run_dir(env), env.fw, TASK, "go", SECRET)
    body = calls[0][2]
    assert SECRET not in body
    assert body == dr.notice_text(TASK, "go", SHA)


def test_malformed_task_id_is_skipped(env, monkeypatch):
    calls = _stub_sender(monkeypatch)
    run = _run_dir(env)
    dr._post_decision_notice(run, env.fw, "T-1; rm", "go")
    assert calls == []
    assert dr.read_status(run)["notice"]["state"] == "skipped"


def test_decision_commit_id_finds_the_decision_commit(tmp_path, monkeypatch):
    """_decision_commit_id against a real throwaway repo."""
    import subprocess
    repo = tmp_path / "repo"
    repo.mkdir()
    g = lambda *a: subprocess.run(["git", *a], cwd=repo, check=True, capture_output=True,  # noqa: E731
                                  env=dr.git_clean_env())
    g("init", "-q")
    g("-c", "user.email=t@t", "-c", "user.name=t", "commit", "-q", "--allow-empty",
      "-m", f"{TASK}: inception decision GO (via Watchtower)")
    want = g("rev-parse", "--short", "HEAD").stdout.decode().strip()
    g("-c", "user.email=t@t", "-c", "user.name=t", "commit", "-q", "--allow-empty", "-m", "other")
    monkeypatch.setattr(shared, "PROJECT_ROOT", repo)
    assert dr._decision_commit_id(TASK, "go") == want
    assert dr._decision_commit_id(TASK, "no-go") == ""
