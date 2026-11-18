"""One non-urgent notice to this project's own agent after an operator action (T-5211).

T-5216 (slice 1) built the notifier inside web/decide_runner.py for inception decisions;
T-5222 (slice 2) lifts it here so every operator action that hands the next step to the
agent uses ONE sender:

  * the decide chain (web/decide_runner.py, its own once-per-commit marker logic),
  * a Human criterion ticked in Watchtower (`POST /api/task/<id>/toggle-ac`),
  * a restatement accepted or rejected (lib/reviewer/restatement_cli.py),
  * a paid-review proposal approved (lib/review_cost.py approve()).

Rules (inception T-5211):
  * the post goes through the existing `fw sidecar send --notice` path, to the
    project's own id (lib/sidecar/circuit.project_id());
  * the body is a FIXED text per action carrying only ids, numbers and states, never
    criterion text or any other task-file text;
  * a failed post never changes the action's result: `post()` never raises, and logs
    the outcome to `.context/working/agent-notices.jsonl`;
  * short timeout; the web request never waits for it (`wait=False` runs it on a
    daemon thread);
  * test runs never send for real: under pytest or bats `post()` skips unless
    FW_AGENT_NOTICES=1; FW_AGENT_NOTICES=0 switches notices off anywhere.
"""

from __future__ import annotations

import json
import os
import re
import subprocess
import threading
from datetime import datetime, timezone
from pathlib import Path

NOTICE_TIMEOUT = 20      # seconds; decide chain (detached runner)
ACTION_TIMEOUT = 10      # seconds; the three operator actions
LOG = Path(".context/working/agent-notices.jsonl")

# git's repo-local variables: a hook-inherited GIT_DIR must not steer the sender
# (T-4242; the same set as web/decide_runner.GIT_LOCAL_ENV_VARS)
GIT_LOCAL_ENV_VARS = frozenset((
    "GIT_ALTERNATE_OBJECT_DIRECTORIES", "GIT_CONFIG", "GIT_CONFIG_PARAMETERS",
    "GIT_CONFIG_COUNT", "GIT_OBJECT_DIRECTORY", "GIT_DIR", "GIT_WORK_TREE",
    "GIT_IMPLICIT_WORK_TREE", "GIT_GRAFT_FILE", "GIT_INDEX_FILE", "GIT_NO_REPLACE_OBJECTS",
    "GIT_REPLACE_REF_BASE", "GIT_PREFIX", "GIT_SHALLOW_FILE", "GIT_COMMON_DIR",
))

_TASK_RE = re.compile(r"^T-\d+$")
_ID_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._:-]{0,79}$")


def framework_root() -> Path:
    return Path(__file__).resolve().parent.parent


def project_root() -> Path:
    env = os.environ.get("PROJECT_ROOT")
    return Path(env) if env else Path.cwd()


def default_fw_bin() -> str:
    return str(framework_root() / "bin" / "fw")


def clean_env(env=None) -> dict:
    src = os.environ if env is None else env
    return {k: v for k, v in src.items() if k not in GIT_LOCAL_ENV_VARS}


def own_address() -> str:
    """This project's own sidecar id (lib/sidecar/circuit.project_id())."""
    from lib.sidecar import circuit
    return circuit.project_id()


def send_notice(fw_bin: str, to: str, body: str, *, cwd=None, timeout: float = NOTICE_TIMEOUT,
                env=None):
    """Post through `fw sidecar send --notice`. Returns (ok, detail); never raises."""
    try:
        r = subprocess.run([fw_bin, "sidecar", "send", "--to", to, "--notice", "--body", body],
                           cwd=str(cwd or project_root()), stdin=subprocess.DEVNULL,
                           capture_output=True, text=True, timeout=timeout,
                           env=env if env is not None else clean_env())
    except subprocess.TimeoutExpired:
        return False, f"timed out after {timeout}s"
    except Exception as e:  # sender missing, not executable
        return False, f"could not run the sender: {e}"[:300]
    if r.returncode != 0:
        why = (r.stderr or r.stdout or "").strip().splitlines()
        return False, f"exit {r.returncode}: {why[-1] if why else 'no output'}"[:300]
    return True, "sent"


# ------------------------------------------------------------------ fixed texts

def _ok_task(task_id) -> str:
    t = str(task_id)
    if not _TASK_RE.match(t):
        raise ValueError("not a task id")
    return t


def _ok_id(x) -> str:
    s = str(x)
    if not _ID_RE.match(s):
        raise ValueError("not an id")
    return s


def criterion_ticked_text(task_id, index: int, ticked: int, total: int) -> str:
    t = _ok_task(task_id)
    index, ticked, total = int(index), int(ticked), int(total)
    if total > 0 and ticked >= total:
        return (f"{t}: all Human criteria ticked by the operator ({ticked} of {total}); "
                f"close it with fw task update {t} --status work-completed.")
    return f"{t}: Human criterion {index} ticked by the operator ({ticked} of {total} ticked)."


def restatement_text(task_id, verdict_id, decision: str) -> str:
    t, v = _ok_task(task_id), _ok_id(verdict_id)
    if decision == "accepted":
        return (f"{t}: restatement {v} accepted by the operator; commit the task file, "
                f"then re-run fw reviewer judge {t}.")
    if decision == "rejected":
        return (f"{t}: restatement {v} rejected by the operator; the criterion stands as "
                f"written. Read .context/reviews/restatements.jsonl for the reason.")
    raise ValueError("unknown restatement decision")


def paid_review_approved_text(proposal_id, task_id) -> str:
    p, t = _ok_id(proposal_id), _ok_task(task_id)
    return (f"Paid review {p} approved by the operator for {t}; run it, then log the cost "
            f"with fw review cost log --task {t} --proposal-id {p}.")


# ------------------------------------------------------------------ posting

def _disabled() -> str | None:
    flag = os.environ.get("FW_AGENT_NOTICES", "")
    if flag == "0":
        return "notices switched off (FW_AGENT_NOTICES=0)"
    if flag != "1" and (os.environ.get("PYTEST_CURRENT_TEST") or os.environ.get("BATS_RUN_TMPDIR")):
        return "test run: no real notice (set FW_AGENT_NOTICES=1 with a stubbed sender)"
    return None


def _log(root: Path, rec: dict) -> None:
    try:
        p = Path(root) / LOG
        p.parent.mkdir(parents=True, exist_ok=True)
        with p.open("a", encoding="utf-8") as fh:
            fh.write(json.dumps(rec, sort_keys=True) + "\n")
    except Exception:
        pass


def _deliver(action: str, task_id: str, body: str, root: Path, fw_bin: str, timeout: float) -> dict:
    rec = {"ts": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
           "action": action, "task": task_id}
    try:
        why = _disabled()
        if why:
            rec.update(state="skipped", reason=why)
        else:
            try:
                to = own_address()
            except Exception as e:
                rec.update(state="failed", reason=f"own sidecar address unknown: {e}"[:300])
            else:
                ok, detail = send_notice(fw_bin, to, body, cwd=root, timeout=timeout)
                rec.update(state="sent" if ok else "failed", to=to, reason=detail)
    except Exception as e:  # never raise into the action
        rec.update(state="failed", reason=f"notice step error: {e}"[:300])
    _log(root, rec)
    return rec


def post(action: str, task_id: str, body: str, *, wait: bool = True, root=None, fw_bin=None,
         timeout: float = ACTION_TIMEOUT):
    """Post one notice for an action whose write already succeeded. Never raises.

    wait=True: deliver now and return the log record. wait=False: deliver on a daemon
    thread and return the thread (the web request does not wait for it)."""
    try:
        root = Path(root) if root else project_root()
        fw_bin = fw_bin or default_fw_bin()
        if not wait:
            th = threading.Thread(target=_deliver, args=(action, task_id, body, root, fw_bin, timeout),
                                  name=f"agent-notice-{action}", daemon=True)
            th.start()
            return th
        return _deliver(action, task_id, body, root, fw_bin, timeout)
    except Exception:
        return None


# ------------------------------------------------------------------ the three actions

def notify_criterion_ticked(task_id, old_text: str, new_text: str, *, root=None, wait=False):
    """After a Watchtower tick: one notice when a Human criterion went unticked -> ticked.
    None on untick or when no Human criterion changed. Never raises."""
    try:
        from lib.delegation import human_criteria
        before = {c.index: c.ticked for c in human_criteria(old_text)}
        after = human_criteria(new_text)
        newly = [c.index for c in after if c.ticked and before.get(c.index) is False]
        if len(newly) != 1:
            return None
        body = criterion_ticked_text(task_id, newly[0], sum(c.ticked for c in after), len(after))
        return post("criterion-ticked", str(task_id), body, root=root, wait=wait)
    except Exception:
        return None


def notify_restatement(task_id, verdict_id, decision: str, *, root=None, wait=True):
    try:
        return post(f"restatement-{decision}", str(task_id),
                    restatement_text(task_id, verdict_id, decision), root=root, wait=wait)
    except Exception:
        return None


def notify_paid_review_approved(proposal_id, task_id, *, root=None, wait=True):
    try:
        return post("paid-review-approved", str(task_id),
                    paid_review_approved_text(proposal_id, task_id), root=root, wait=wait)
    except Exception:
        return None
