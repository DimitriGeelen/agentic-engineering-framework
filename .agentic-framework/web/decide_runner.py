"""T-3749: run `fw inception decide` detached, so Watchtower never kills it.

Watchtower used to run the decide chain through run_fw_command(timeout=30).
Measured on this repo (tests/scripts/t3749-decide-timing.sh) the chain took
~40 s: the task reached completed/ at ~23 s and post-move side effects
(component resolution, episodic, emit_review) ran to the end. The timeout
killed the chain mid-flight and the page reported "Command timed out" as a
gate refusal, for a decision that had landed (T-3631, 2026-10-02).

Shape of the fix:

* `launch()` starts `python3 -m web.decide_runner --run …` in its own session
  (start_new_session), so neither a request timeout nor a Watchtower restart
  reaches it. The runner runs the decide with no timeout, logs stdout/stderr
  to a run directory under .context/working/decide/, records the exit code in
  status.json, then commits whatever the chain wrote after Watchtower's own
  commit (episodic, components, Updates).
* One chain per task: launch() takes an exclusive flock on
  .context/working/decide/<task>.lock and hands it to the runner, which holds
  it until it exits. A second GO click while a chain is running gets `Busy`.
* `classify()` turns (landed, completed, running, rc) into one outcome; the
  blueprint words its message from that, so a still-running chain is never
  described as a timeout or a gate refusal.
* `surface()` reports a run whose follow-up commit failed, or whose process
  died before finishing, on the inception page (no silent uncommitted state).
"""
from __future__ import annotations

import fcntl
import json
import os
import subprocess
import sys
import threading
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path

STATE_SUBDIR = Path(".context") / "working" / "decide"

# Outcomes of a Watchtower decide, as classify() reports them.
NOT_LANDED = "not_landed"            # chain finished, no decision in the task
PENDING = "pending"                  # chain still running, decision not yet written
LANDED_COMPLETING = "landed_completing"  # decision written, completion still running
LANDED_RUNNING = "landed_running"    # decision + completion landed, follow-ups running
LANDED_DONE = "landed_done"          # everything finished, exit 0
LANDED_GATE_REFUSED = "landed_gate_refused"  # decision written, completion refused
LANDED_FOLLOWUP_FAILED = "landed_followup_failed"  # completed, a later step exited non-zero
BUSY = "busy"                        # another chain for this task is still running

LANDED_OUTCOMES = {LANDED_COMPLETING, LANDED_RUNNING, LANDED_DONE,
                   LANDED_GATE_REFUSED, LANDED_FOLLOWUP_FAILED}


class Busy(Exception):
    """A decide chain for this task is already running."""


@dataclass
class Launch:
    proc: subprocess.Popen
    run_dir: Path

    @property
    def status_path(self) -> Path:
        return self.run_dir / "status.json"

    @property
    def out_log(self) -> Path:
        return self.run_dir / "stdout.log"

    @property
    def err_log(self) -> Path:
        return self.run_dir / "stderr.log"


def state_dir(project_root) -> Path:
    return Path(project_root) / STATE_SUBDIR


def lock_path(project_root, task_id: str) -> Path:
    return state_dir(project_root) / f"{task_id}.lock"


def read_status(run_dir: Path) -> dict:
    try:
        return json.loads((Path(run_dir) / "status.json").read_text())
    except (OSError, ValueError):
        return {}


def _write_status(run_dir: Path, **fields) -> None:
    st = read_status(run_dir)
    st.update(fields)
    tmp = Path(run_dir) / "status.json.tmp"
    tmp.write_text(json.dumps(st, indent=2) + "\n")
    os.replace(tmp, Path(run_dir) / "status.json")


def _now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def is_running(project_root, task_id: str) -> bool:
    """True while a runner holds this task's lock."""
    p = lock_path(project_root, task_id)
    if not p.exists():
        return False
    fd = os.open(p, os.O_RDWR)
    try:
        fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        return True
    else:
        fcntl.flock(fd, fcntl.LOCK_UN)
        return False
    finally:
        os.close(fd)


def launch(task_id: str, decision: str, rationale: str, *,
           project_root, framework_root) -> Launch:
    """Start the detached runner. Raises Busy if one is already running."""
    sdir = state_dir(project_root)
    sdir.mkdir(parents=True, exist_ok=True)
    lock_fd = os.open(lock_path(project_root, task_id), os.O_RDWR | os.O_CREAT, 0o600)
    try:
        try:
            fcntl.flock(lock_fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise Busy(task_id)
        stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
        run_dir = sdir / f"{task_id}-{stamp}"
        run_dir.mkdir()
        _write_status(run_dir, task_id=task_id, decision=decision, state="starting",
                      started=_now())
        env = {k: v for k, v in os.environ.items() if k != "CLAUDECODE"}
        env["PROJECT_ROOT"] = str(project_root)
        # The runner module lives beside this file; framework_root only names
        # the fw that runs the chain (a test points it at a fake).
        env["PYTHONPATH"] = str(Path(__file__).resolve().parents[1]) + (
            os.pathsep + env["PYTHONPATH"] if env.get("PYTHONPATH") else "")
        env["FW_DECIDE_LOCK_FD"] = str(lock_fd)
        with open(run_dir / "runner.log", "ab") as runner_log:
            proc = subprocess.Popen(
                [sys.executable, "-m", "web.decide_runner", "--run", str(run_dir),
                 str(Path(framework_root) / "bin" / "fw"), task_id, decision, rationale],
                cwd=str(project_root), env=env,
                stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=runner_log,
                start_new_session=True, pass_fds=(lock_fd,),
            )
    finally:
        # The child inherited the locked descriptor; it holds the lock from here.
        os.close(lock_fd)
    # Reap the child when it exits so it never lingers as a zombie of Flask.
    threading.Thread(target=proc.wait, daemon=True).start()
    return Launch(proc=proc, run_dir=run_dir)


def classify(decision: str, *, landed: bool, completed: bool, running: bool,
             rc) -> str:
    """One outcome for the operator message. Pure; see the module docstring."""
    completes = decision in ("go", "no-go")
    if landed:
        if completes and not completed:
            return LANDED_COMPLETING if running else LANDED_GATE_REFUSED
        if running:
            return LANDED_RUNNING
        return LANDED_DONE if rc == 0 else LANDED_FOLLOWUP_FAILED
    return PENDING if running else NOT_LANDED


def surface(project_root, task_id: str):
    """A warning about the latest Watchtower decide for this task, or None.

    Reports what would otherwise be silent: the follow-up commit failed, or
    the runner is gone without having recorded that it finished.
    """
    sdir = state_dir(project_root)
    if not sdir.is_dir():
        return None
    runs = sorted(p for p in sdir.glob(f"{task_id}-*") if p.is_dir())
    if not runs:
        return None
    run = runs[-1]
    st = read_status(run)
    rel = os.path.relpath(run, project_root)
    if st.get("state") == "done":
        if st.get("commit_ok") is False:
            return (f"The decision's follow-up writes are not committed: "
                    f"{st.get('commit_msg', '')} (log: {rel})")
        return None
    if is_running(project_root, task_id):
        return None
    return (f"The decide run for {task_id} stopped before it finished "
            f"(state: {st.get('state', 'unknown')}). Check the task and the log: {rel}")


# ---------------------------------------------------------------- runner side

def _run(run_dir: Path, fw_bin: str, task_id: str, decision: str, rationale: str) -> int:
    from web.shared import PROJECT_ROOT  # env PROJECT_ROOT set by launch()
    _write_status(run_dir, state="running", pid=os.getpid())
    with open(run_dir / "stdout.log", "ab") as out, open(run_dir / "stderr.log", "ab") as err:
        # No timeout, on purpose: the chain must run to its end (T-3749).
        rc = subprocess.call(
            [fw_bin, "inception", "decide", task_id,
             decision, "--rationale", rationale, "--from-watchtower"],
            cwd=str(PROJECT_ROOT), stdin=subprocess.DEVNULL, stdout=out, stderr=err,
        )
    _write_status(run_dir, state="finished", rc=rc, finished=_now())
    from web.blueprints.inception import _commit_decision, _decision_recorded_in_task
    commit_ok, commit_msg = True, "decision not recorded; nothing to commit"
    if _decision_recorded_in_task(task_id, decision):
        commit_ok, commit_msg = _commit_decision(task_id, decision, followup=True)
    _write_status(run_dir, state="done", commit_ok=commit_ok, commit_msg=commit_msg,
                  done=_now())
    return 0


def main(argv=None) -> int:
    argv = list(sys.argv[1:] if argv is None else argv)
    if len(argv) != 6 or argv[0] != "--run":
        print("usage: python3 -m web.decide_runner --run RUN_DIR FW_BIN TASK_ID DECISION RATIONALE",
              file=sys.stderr)
        return 2
    _, run_dir, fw_bin, task_id, decision, rationale = argv
    # FW_DECIDE_LOCK_FD stays open for this process's lifetime: that is the lock.
    return _run(Path(run_dir), fw_bin, task_id, decision, rationale)


if __name__ == "__main__":
    sys.exit(main())
