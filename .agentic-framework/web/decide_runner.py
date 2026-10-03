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
  to a run directory under .context/working/decide/, and records progress and
  the exit code in status.json. It commits the decision as soon as it lands
  and again when the chain ends (episodic, components, Updates) — the request
  itself never commits, so it never waits on git or the commit lock.
* One chain per task: launch() takes an exclusive flock on
  .context/working/decide/<task>.lock and hands it to the runner, which passes
  it on to fw, so it is held until the chain itself has ended — a runner that
  dies, even before recording fw_pid, does not free it. As a second line,
  launch() also refuses while the recorded fw_pid is alive (/proc-checked). A second GO
  click while a chain is running gets `Busy`.
* `classify()` turns (landed, completed, running, rc) into one outcome; the
  blueprint words its message from that. A still-running chain is never
  described as a timeout or a gate refusal, and only a plain non-zero exit
  (a gate's own refusal) gets gate wording — a signal or crash is
  LANDED_INTERRUPTED.
* `surface()` reports, on the inception page, a run that exited non-zero, a
  commit that failed, or a runner that died before finishing.
"""
from __future__ import annotations

import fcntl
import json
import os
import subprocess
import sys
import threading
import time
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
LANDED_INTERRUPTED = "landed_interrupted"  # decision written, chain stopped abnormally
BUSY = "busy"                        # another chain for this task is still running

LANDED_OUTCOMES = {LANDED_COMPLETING, LANDED_RUNNING, LANDED_DONE,
                   LANDED_GATE_REFUSED, LANDED_FOLLOWUP_FAILED, LANDED_INTERRUPTED}


def gate_exit(rc) -> bool:
    """A refusal the chain itself reported: a plain non-zero exit.

    Gates exit 1/2. A negative rc is a signal (subprocess), >=128 is a shell's
    128+N for a killed child, 124 is timeout(1)'s "timed out", 125-127 are
    "could not run" codes, -1 is the runner's "died without an exit code",
    None is "unknown" — none of those is a gate, so none gets gate wording.
    """
    return isinstance(rc, int) and 0 < rc < 124


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


def _runs(project_root, task_id: str) -> list:
    sdir = state_dir(project_root)
    if not sdir.is_dir():
        return []
    return sorted(p for p in sdir.glob(f"{task_id}-*") if p.is_dir())


def _pid_is_decide(pid, task_id: str) -> bool:
    """Is `pid` alive and still the `fw inception decide <task_id>` we started?

    /proc/<pid>/cmdline guards against pid reuse; without /proc, liveness only.
    """
    if not isinstance(pid, int) or pid <= 0:
        return False
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return False
    except PermissionError:
        pass
    try:
        with open(f"/proc/{pid}/cmdline", "rb") as f:
            argv = f.read().split(b"\0")
    except OSError:
        return True
    return b"decide" in argv and task_id.encode() in argv


def _live_chain(project_root, task_id: str) -> bool:
    """A decide whose runner is gone but whose fw process still runs."""
    for run in reversed(_runs(project_root, task_id)):
        st = read_status(run)
        if st.get("state") in ("finished", "done"):
            return False
        if _pid_is_decide(st.get("fw_pid"), task_id):
            return True
    return False


def is_running(project_root, task_id: str) -> bool:
    """True while a runner holds this task's lock, or its fw still runs."""
    p = lock_path(project_root, task_id)
    if p.exists():
        fd = os.open(p, os.O_RDWR)
        try:
            fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return True
        else:
            fcntl.flock(fd, fcntl.LOCK_UN)
        finally:
            os.close(fd)
    return _live_chain(project_root, task_id)


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
        # The lock belongs to the runner. If the runner died while its fw kept
        # going, the lock is free but the chain is not: refuse that too.
        if _live_chain(project_root, task_id):
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
            if running:
                return LANDED_COMPLETING
            return LANDED_GATE_REFUSED if gate_exit(rc) else LANDED_INTERRUPTED
        if running:
            return LANDED_RUNNING
        return LANDED_DONE if rc == 0 else LANDED_FOLLOWUP_FAILED
    return PENDING if running else NOT_LANDED


def surface(project_root, task_id: str):
    """A warning about the latest Watchtower decide for this task, or None.

    Reports what would otherwise be silent once the request has returned:
    the chain exited non-zero, a commit failed, or the runner is gone without
    having recorded that it finished. Every such run since the last CLEAN run
    (done, exit 0, committed) is reported, so a newer attempt — running or
    failed — cannot hide an older failure. A clean run supersedes what came
    before it: it ran the whole chain (archive, episodic, commit) to the end.
    """
    runs = _runs(project_root, task_id)
    live = is_running(project_root, task_id)
    problems = []
    for i, run in enumerate(reversed(runs)):
        st = read_status(run)
        rel = os.path.relpath(run, project_root)
        if st.get("state") == "done":
            if st.get("rc") == 0 and st.get("commit_ok") is not False:
                break  # clean: everything older is superseded
            parts = []
            if st.get("rc") != 0:
                parts.append(f"the decide command exited with code {st.get('rc')} — "
                             f"check that the task is where you expect it")
            if st.get("commit_ok") is False:
                parts.append(f"its writes are not committed: {st.get('commit_msg', '')}")
            problems.append("; ".join(parts) + f" (log: {rel})")
        elif i == 0 and live:
            continue  # the newest run is still going: nothing to report yet
        else:
            problems.append(f"a decide run stopped before it finished "
                            f"(state: {st.get('state', 'unknown')}; log: {rel})")
    if not problems:
        return None
    return f"Decide runs for {task_id} that need a look: " + " | ".join(problems)


# ---------------------------------------------------------------- runner side

def _primary_landed(task_id: str, decision: str) -> bool:
    from web.blueprints.inception import _decision_recorded_in_task, _task_in_completed
    if not _decision_recorded_in_task(task_id, decision):
        return False
    return decision not in ("go", "no-go") or _task_in_completed(task_id)


def _run(run_dir: Path, fw_bin: str, task_id: str, decision: str, rationale: str) -> int:
    """Run the chain to its end; commit the decision when it lands, and again at the end.

    Both commits happen HERE, not in the request: the request must answer on
    the primary result and never wait on git or on the commit lock.
    """
    from web.shared import PROJECT_ROOT  # env PROJECT_ROOT set by launch()
    from web.blueprints.inception import _commit_decision, _decision_recorded_in_task
    _write_status(run_dir, state="running", pid=os.getpid())
    with open(run_dir / "stdout.log", "ab") as out, open(run_dir / "stderr.log", "ab") as err:
        # No timeout, on purpose: the chain must run to its end (T-3749).
        # The task lock goes to fw too (and so to its children): if this runner
        # dies at any point — even before fw_pid is recorded — the lock stays held
        # until the chain itself has ended, so a second GO cannot overlap it.
        lock_fds = ()
        if os.environ.get("FW_DECIDE_LOCK_FD", "").isdigit():
            lock_fds = (int(os.environ["FW_DECIDE_LOCK_FD"]),)
        proc = subprocess.Popen(
            [fw_bin, "inception", "decide", task_id,
             decision, "--rationale", rationale, "--from-watchtower"],
            cwd=str(PROJECT_ROOT), stdin=subprocess.DEVNULL, stdout=out, stderr=err,
            pass_fds=lock_fds,
        )
        _write_status(run_dir, fw_pid=proc.pid)
        primary_committed = False
        while proc.poll() is None:
            if not primary_committed and _primary_landed(task_id, decision):
                ok, msg = _commit_decision(task_id, decision)
                _write_status(run_dir, primary_commit_ok=ok, primary_commit_msg=msg)
                primary_committed = True
            time.sleep(0.5)
        rc = proc.returncode
    _write_status(run_dir, state="finished", rc=rc, finished=_now())
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
