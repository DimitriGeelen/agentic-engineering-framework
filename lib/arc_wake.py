#!/usr/bin/env python3
"""Arc owner wake-up and the per-arc daily wake limit (T-5252, T-5224 slice 3).

T-5224 GO, IW-3/IW-4 (docs/reports/T-5224-arc-orchestrator.md): an arc whose owner
role is switched on (``fw arc owner <arc> on``, lib/arc_owner.py) wakes its owner

  * when a member task changes status (trigger ``status``; update-task.sh calls
    ``task-event`` right after its journal append), and
  * when the latest journal ``next`` entry has a deadline in the past (trigger
    ``deadline``; ``sweep`` runs from cron every 15 minutes and wakes each passed
    deadline once).

How it wakes is ``owner.wake`` in the arc YAML:

  notice  one idle-aware sidecar notice to this project's own address
          (lib/agent_notice.send_notice — the same path as decision notices):
          "arc <slug>: <what happened>; run: fw arc resume <slug>"
  worker  ``fw termlink dispatch`` under the next step's task (when active) or the
          arc's anchor_task, with a prompt that starts with ``fw arc resume <slug>``.
          The dispatch's own worker cap applies; a refused dispatch is recorded and
          never retried here.

Limit: ``owner.wake_limit`` (default 12) wakes per arc per UTC day. Over it no wake
is sent, the refusal is recorded, and the operator is told ONCE per arc per day
(fw_notify push, and the item shows in ``fw operator pending`` for the rest of the
day). This is what stops an owner whose own journal writes wake it again from
looping.

Ledger: ``.context/arcs/<slug>.wakes.jsonl`` beside the journal, append-only, one
JSON row per wake or refusal: ts, trigger, reason, channel, outcome, detail
(+ task, key, operator_notified where relevant). Outcomes:
  sent | refused-limit | dispatch-refused | error | skipped
``skipped`` (wakes switched off, or a test run with no stub) does not count toward
the limit and does not use up a deadline.

Arcs whose owner role is not on (or whose journal is off) never wake and get no
ledger rows.

Switches: FW_ARC_WAKE=0 records ``skipped`` instead of waking. In a test run
(pytest/bats) nothing real is sent unless FW_ARC_WAKE_FW_BIN names a stub ``fw``;
FW_ARC_WAKE_OPERATOR_CMD names a stub for the operator push.

CLI:
  python3 lib/arc_wake.py wake <arc> --trigger T --reason R [--json]
  python3 lib/arc_wake.py task-event <task-file> <from> <to>   (update-task.sh; exit 0)
  python3 lib/arc_wake.py sweep [--json]                        (cron)
  python3 lib/arc_wake.py today <arc> [--json]                  (count/limit line)
"""

from __future__ import annotations

import argparse
import datetime as _dt
import fcntl
import json
import os
import re
import subprocess
import sys
from pathlib import Path

_HERE = Path(__file__).resolve().parent
if str(_HERE.parent) not in sys.path:
    sys.path.insert(0, str(_HERE.parent))

from lib import arc_journal as aj  # noqa: E402
from lib import arc_owner as ao  # noqa: E402
from lib.arc_membership import parse_arc_id_value, read_frontmatter  # noqa: E402

DEFAULT_LIMIT = 12
DISPATCH_TIMEOUT = 120
NOTIFY_TIMEOUT = 30
# Outcomes that are a wake attempt (count toward the daily limit).
_COUNTED = ("sent", "dispatch-refused", "error")


def _root(project_root=None) -> Path:
    return Path(project_root or os.environ.get("PROJECT_ROOT") or Path.cwd())


def _utcnow() -> _dt.datetime:
    return _dt.datetime.now(_dt.timezone.utc)


def _fw_bin() -> str:
    return os.environ.get("FW_ARC_WAKE_FW_BIN") or str(_HERE.parent / "bin" / "fw")


def _disabled() -> str | None:
    if os.environ.get("FW_ARC_WAKE") == "0":
        return "wakes switched off (FW_ARC_WAKE=0)"
    if not os.environ.get("FW_ARC_WAKE_FW_BIN") and (
            os.environ.get("PYTEST_CURRENT_TEST") or os.environ.get("BATS_RUN_TMPDIR")):
        return "test run: no real wake (set FW_ARC_WAKE_FW_BIN to a stub)"
    return None


# ---------------------------------------------------------------- ledger

def ledger_path(arc: str, project_root=None) -> Path:
    slug, _n, yaml_path = aj.resolve_arc(arc, project_root)
    return yaml_path.parent / f"{slug}.wakes.jsonl"


def read_ledger(arc: str, project_root=None) -> list[dict]:
    p = ledger_path(arc, project_root)
    rows: list[dict] = []
    if not p.is_file():
        return rows
    for raw in p.read_text(encoding="utf-8", errors="replace").splitlines():
        try:
            r = json.loads(raw)
        except json.JSONDecodeError:
            continue
        if isinstance(r, dict):
            rows.append(r)
    return rows


def _today_rows(rows: list[dict], now: _dt.datetime) -> list[dict]:
    day = now.strftime("%Y-%m-%d")
    return [r for r in rows if str(r.get("ts", "")).startswith(day)]


def owner_config(arc: str, project_root=None) -> dict:
    """{on, wake, limit, slug}. ``on`` needs journal: true and owner.role on."""
    st = ao.state(arc, project_root)
    o = st.get("owner") or {}
    lim = str(o.get("wake_limit") or "")
    return {"slug": st["slug"],
            "on": bool(st.get("journal")) and o.get("role") == "on",
            "wake": o.get("wake") if o.get("wake") in ao.WAKES else "notice",
            "limit": int(lim) if lim.isdigit() else DEFAULT_LIMIT}


def today(arc: str, project_root=None, now: _dt.datetime | None = None) -> dict:
    now = now or _utcnow()
    cfg = owner_config(arc, project_root)
    rows = _today_rows(read_ledger(arc, project_root), now)
    return {"arc": cfg["slug"], "on": cfg["on"], "wake": cfg["wake"], "limit": cfg["limit"],
            "count": sum(1 for r in rows if r.get("outcome") in _COUNTED),
            "refused": sum(1 for r in rows if r.get("outcome") == "refused-limit")}


# ---------------------------------------------------------------- channels (stubbable)

def _send_notice(body: str, root: Path) -> tuple[bool, str]:
    from lib import agent_notice
    try:
        to = agent_notice.own_address()
    except Exception as e:  # noqa: BLE001
        return False, f"own sidecar address unknown: {e}"[:300]
    ok, detail = agent_notice.send_notice(_fw_bin(), to, body, cwd=root)
    return ok, (f"to {to}: {detail}" if ok else detail)


def _dispatch(task: str, name: str, prompt: str, root: Path) -> tuple[bool, str]:
    try:
        r = subprocess.run([_fw_bin(), "termlink", "dispatch", "--task", task, "--name", name,
                            "--prompt", prompt],
                           cwd=str(root), stdin=subprocess.DEVNULL, capture_output=True, text=True,
                           timeout=DISPATCH_TIMEOUT, env=dict(os.environ, PROJECT_ROOT=str(root)))
    except subprocess.TimeoutExpired:
        return False, f"dispatch timed out after {DISPATCH_TIMEOUT}s"
    except Exception as e:  # noqa: BLE001
        return False, f"could not run dispatch: {e}"[:300]
    if r.returncode != 0:
        why = [ln for ln in (r.stderr or r.stdout or "").strip().splitlines() if ln.strip()]
        return False, f"exit {r.returncode}: {why[0] if why else 'no output'}"[:300]
    return True, f"worker {name} under {task}"


def _notify_operator(title: str, message: str, root: Path) -> tuple[bool, str]:
    stub = os.environ.get("FW_ARC_WAKE_OPERATOR_CMD")
    if stub:
        cmd = [stub, title, message]
    elif _disabled():
        return False, "not pushed (test run)"
    else:
        cmd = ["bash", "-c", 'source "$1/lib/notify.sh" && fw_notify "$2" "$3" arc-wake-limit framework',
               "_", str(_HERE.parent), title, message]
    try:
        r = subprocess.run(cmd, cwd=str(root), stdin=subprocess.DEVNULL, capture_output=True, text=True,
                           timeout=NOTIFY_TIMEOUT, env=dict(os.environ, PROJECT_ROOT=str(root)))
    except Exception as e:  # noqa: BLE001
        return False, f"push failed: {e}"[:200]
    return r.returncode == 0, "pushed" if r.returncode == 0 else f"push exit {r.returncode}"


# ---------------------------------------------------------------- wake

def _anchor_task(arc: str, root: Path) -> str | None:
    _s, _n, path = aj.resolve_arc(arc, root)
    m = re.search(r"(?m)^anchor_task:\s*['\"]?(T-\d+)", path.read_text(encoding="utf-8", errors="replace"))
    return m.group(1) if m else None


def _worker_task(arc: str, root: Path) -> str | None:
    entries, _bad = aj.read(arc, root)
    nexts = [e for e in entries if e["kind"] == "next"]
    if nexts and nexts[-1].get("task"):
        info = ao._task_info(root, str(nexts[-1]["task"]))
        if info and info["active"]:
            return info["id"]
    return _anchor_task(arc, root)


def wake(arc: str, reason: str, trigger: str, project_root=None, now: _dt.datetime | None = None,
         key: str | None = None) -> dict | None:
    """Wake the arc's owner once. Returns the ledger row, or None when the arc is not on."""
    root = _root(project_root)
    now = now or _utcnow()
    cfg = owner_config(arc, root)
    if not cfg["on"]:
        return None
    slug = cfg["slug"]
    path = ledger_path(arc, root)
    row = {"ts": now.strftime("%Y-%m-%dT%H:%M:%SZ"), "trigger": trigger, "reason": reason,
           "channel": cfg["wake"]}
    if key:
        row["key"] = key
    fd = os.open(path, os.O_RDWR | os.O_APPEND | os.O_CREAT, 0o644)
    try:
        # The whole count-decide-wake-record step holds the lock, so two triggers at
        # once cannot both pass the limit.
        fcntl.flock(fd, fcntl.LOCK_EX)
        try:
            rows = _today_rows(read_ledger(arc, root), now)
            count = sum(1 for r in rows if r.get("outcome") in _COUNTED)
            why_off = _disabled()
            if why_off:
                row.update(outcome="skipped", detail=why_off)
            elif count >= cfg["limit"]:
                already = any(r.get("outcome") == "refused-limit" and r.get("operator_notified") for r in rows)
                row.update(outcome="refused-limit",
                           detail=f"{count} of {cfg['limit']} wakes used today (UTC)")
                if not already:
                    _ok, d = _notify_operator(
                        f"Arc {slug}: wake limit reached",
                        f"Arc {slug} reached its wake limit ({cfg['limit']} per day); further wakes "
                        f"are refused until tomorrow (UTC). Latest: {reason}. Check: fw arc show {slug}",
                        root)
                    row["operator_notified"] = True
                    row["detail"] += f"; operator told ({d})"
            elif cfg["wake"] == "worker":
                task = _worker_task(arc, root)
                if not task:
                    row.update(outcome="error", detail="no task to dispatch under: the next step names "
                               "no active task and the arc has no anchor_task")
                else:
                    name = f"arc-wake-{slug}-{now.strftime('%H%M%S')}"
                    prompt = (f"fw arc resume {slug}\n\nYou were woken as the owner of arc {slug}: {reason}. "
                              f"Run the command above first, then act on the next step it names.")
                    ok, d = _dispatch(task, name, prompt, root)
                    row.update(outcome="sent" if ok else "dispatch-refused", detail=d, task=task)
            else:
                body = f"arc {slug}: {reason}; run: fw arc resume {slug}"
                ok, d = _send_notice(body, root)
                row.update(outcome="sent" if ok else "error", detail=d)
        except Exception as e:  # noqa: BLE001 — never raise into a status change
            row.update(outcome="error", detail=f"wake step error: {e}"[:300])
        line = (json.dumps(row, ensure_ascii=False) + "\n").encode("utf-8")
        size = os.fstat(fd).st_size
        if size:
            os.lseek(fd, size - 1, os.SEEK_SET)
            if os.read(fd, 1) != b"\n":
                line = b"\n" + line
        os.write(fd, line)
        os.fsync(fd)
        fcntl.flock(fd, fcntl.LOCK_UN)
    finally:
        os.close(fd)
    return row


def task_event(task_file: str, old: str, new: str, project_root=None) -> dict | None:
    fm, _c = read_frontmatter(Path(task_file))
    m_arc = re.search(r"(?m)^arc_id:\s*(.+?)\s*$", fm)
    arc = parse_arc_id_value(m_arc.group(1)) if m_arc else ""
    if not arc:
        return None
    m_id = re.search(r"(?m)^id:\s*(T-\d+)\s*$", fm)
    if m_id:
        task = m_id.group(1)
    else:
        m_name = re.match(r"(T-\d+)", Path(task_file).name)
        task = m_name.group(1) if m_name else Path(task_file).stem
    try:
        aj.resolve_arc(arc, project_root)
    except aj.JournalError:
        return None
    return wake(arc, f"{task} {old or '?'} → {new}", "status", project_root)


def sweep(project_root=None, now: _dt.datetime | None = None) -> list[dict]:
    """Wake every opted-in arc whose latest next deadline has passed, once per deadline."""
    root = _root(project_root)
    now = now or _utcnow()
    out: list[dict] = []
    arcs_dir = root / ".context" / "arcs"
    for y in sorted(arcs_dir.glob("*.yaml")):
        m = re.search(r"(?m)^slug:\s*['\"]?([^'\"\s#]+)", y.read_text(encoding="utf-8", errors="replace"))
        arc = m.group(1) if m else y.stem
        try:
            if not owner_config(arc, root)["on"]:
                continue
            entries, _bad = aj.read(arc, root)
        except aj.JournalError:
            continue
        nexts = [e for e in entries if e["kind"] == "next"]
        if not nexts or not nexts[-1].get("deadline"):
            continue
        nxt = nexts[-1]
        try:
            due = _dt.date.fromisoformat(str(nxt["deadline"]))
        except ValueError:
            continue
        if due >= now.date():
            continue
        key = f"{nxt['ts']}|{nxt['deadline']}"
        if any(r.get("key") == key and r.get("outcome") != "skipped" for r in read_ledger(arc, root)):
            continue
        row = wake(arc, f"next step '{nxt['step']}' (owner {nxt['owner']}) was due {nxt['deadline']}",
                   "deadline", root, now=now, key=key)
        if row:
            out.append({"arc": arc, **row})
    return out


# ---------------------------------------------------------------- CLI

def main(argv=None) -> int:
    ap = argparse.ArgumentParser(prog="arc_wake.py", description="Arc owner wake-up (T-5252)")
    sub = ap.add_subparsers(dest="cmd", required=True)
    w = sub.add_parser("wake")
    w.add_argument("arc")
    w.add_argument("--trigger", default="manual")
    w.add_argument("--reason", required=True)
    w.add_argument("--json", action="store_true")
    t = sub.add_parser("task-event")
    t.add_argument("task_file")
    t.add_argument("old")
    t.add_argument("new")
    s = sub.add_parser("sweep")
    s.add_argument("--json", action="store_true")
    d = sub.add_parser("today")
    d.add_argument("arc")
    d.add_argument("--json", action="store_true")
    try:
        args = ap.parse_args(argv)
    except SystemExit as e:
        return 2 if e.code else 0
    try:
        if args.cmd == "wake":
            row = wake(args.arc, args.reason, args.trigger)
            if row is None:
                print(f"arc {args.arc}: owner role is not on; no wake")
            else:
                print(json.dumps(row, ensure_ascii=False) if args.json
                      else f"wake {row['outcome']} ({row['channel']}): {row.get('detail', '')}")
            return 0
        if args.cmd == "task-event":
            row = task_event(args.task_file, args.old, args.new)
            if row and row.get("outcome") in ("error", "dispatch-refused"):
                print(f"arc wake {row['outcome']}: {row.get('detail', '')}", file=sys.stderr)
            return 0
        if args.cmd == "sweep":
            rows = sweep()
            if args.json:
                print(json.dumps(rows, ensure_ascii=False))
            else:
                for r in rows:
                    print(f"{r['arc']}: {r['outcome']} ({r['channel']}) — {r['reason']}")
            return 0
        if args.cmd == "today":
            t_ = today(args.arc)
            if args.json:
                print(json.dumps(t_))
            elif t_["on"]:
                extra = f", {t_['refused']} refused over the limit" if t_["refused"] else ""
                print(f"Wakes today (UTC): {t_['count']} of {t_['limit']} (wake: {t_['wake']}{extra})")
            return 0
    except aj.JournalError as e:
        print(f"arc_wake: {e}", file=sys.stderr)
        return 2
    except OSError as e:
        print(f"arc_wake: {e}", file=sys.stderr)
        return 3
    return 2


if __name__ == "__main__":
    sys.exit(main())
