#!/usr/bin/env python3
"""What is pending for the operator RIGHT NOW, read from live state (T-4095).

The agent used to compose "waiting on you" lists from its memory of earlier asks, so decided
inceptions (T-4023 GO 13:12, T-4017, T-4039) were asked for again. This is the one source of
operator-facing pending lists: it reads task files, git, the runme directory and the paid-proposal
ledger, and a decided item is excluded by construction.

  operator_pending.py pending [--json]    the list, grouped by kind
  operator_pending.py decided <task-file> print "already decided: ..." and exit 0, else exit 1

Reuses: web.shared.task_review_state (T-4053 readiness predicate), lib.review_cost.proposals,
the runme directory layout of lib/runme.sh, and the `**Decision**:` line lib/inception.sh writes.
"""
from __future__ import annotations

import json
import os
import re
import subprocess
import sys
import time
from pathlib import Path

FW = Path(os.environ.get("FRAMEWORK_ROOT") or Path(__file__).resolve().parent.parent)
PROJECT = Path(os.environ.get("PROJECT_ROOT") or Path.cwd())

_VERDICTS = ("NO-GO", "GO", "DEFER")
_TID = re.compile(r"^(T-\d+)")


def _fm(text: str) -> dict:
    """Flat frontmatter scalars (id, name, status, workflow_type, owner) — enough here."""
    out: dict = {}
    if not text.startswith("---"):
        return out
    end = text.find("\n---", 3)
    for line in text[3:end if end > 0 else 0].splitlines():
        m = re.match(r"^([a-z_]+):\s*(.*)$", line)
        if m:
            out[m.group(1)] = m.group(2).strip().strip('"')
    return out


def _file_decision(text: str) -> dict | None:
    """The recorded `**Decision**:` of a task body, or None (absent / template placeholder)."""
    for line in text.splitlines():
        if line.startswith("**Decision**:"):
            val = line.split(":", 1)[1].strip().strip("*").strip().upper()
            for v in _VERDICTS:
                if val == v or val.startswith(v + " ") or val.startswith(v + "("):
                    d = re.search(r"^\*\*Date\*\*:\s*(\S+)", text, re.M)
                    return {"verdict": v, "date": d.group(1) if d else "", "source": "task file"}
    return None


def _commit_decision(task_id: str, project: Path) -> dict | None:
    """A decision commit for the task reachable from HEAD — survives a task file whose Decision
    section was reverted (G-114), which is exactly when memory and file disagree."""
    try:
        r = subprocess.run(
            ["git", "-C", str(project), "log", "-1", "--format=%cI%x09%s",
             "--grep", f"^{task_id}: inception decision ", "-E"],
            capture_output=True, text=True, timeout=20)
    except (OSError, subprocess.SubprocessError):
        return None
    line = r.stdout.strip()
    if r.returncode != 0 or not line:
        return None
    date, _, subj = line.partition("\t")
    m = re.search(r"inception decision ([A-Z-]+)", subj)
    if not m or m.group(1) not in _VERDICTS:
        return None
    via = re.search(r"\(via ([^)]+)\)", subj)
    return {"verdict": m.group(1), "date": date,
            "source": ("via " + via.group(1)) if via else "decision commit"}


def inception_decision(path: Path, project: Path = PROJECT) -> dict | None:
    """Decision record for an inception task file, or None when still undecided."""
    text = path.read_text(encoding="utf-8", errors="replace")
    d = _file_decision(text)
    if d:
        commit = _commit_decision(_fm(text).get("id", ""), project)
        if commit and commit["verdict"] == d["verdict"]:
            d["source"] = commit["source"]
        return d
    m = _TID.match(path.name)
    tid = _fm(text).get("id") or (m.group(1) if m else "")
    return _commit_decision(tid, project) if tid else None


def _base_url() -> str:
    f = PROJECT / ".context" / "working" / "watchtower.url"
    try:
        u = f.read_text().strip()
        if u:
            return u.rstrip("/")
    except OSError:
        pass
    fw = PROJECT / "bin" / "fw"
    if not fw.exists():
        fw = PROJECT / ".agentic-framework" / "bin" / "fw"
    try:
        r = subprocess.run([str(fw), "watchtower", "url"], capture_output=True, text=True, timeout=20)
        if r.returncode == 0 and r.stdout.strip():
            return r.stdout.strip().splitlines()[-1].rstrip("/")
    except (OSError, subprocess.SubprocessError):
        pass
    return ""


def _recommendation(text: str) -> str:
    m = re.search(r"^\s*[-*]?\s*\*\*Recommendation:?\*\*:?\s*(NO-GO|GO|DEFER)\b", text, re.M)
    return m.group(1) if m else "none written"


def _active_tasks() -> list[Path]:
    return sorted((PROJECT / ".tasks" / "active").glob("T-*.md"))


def undecided_inceptions() -> list[dict]:
    out = []
    for p in _active_tasks():
        text = p.read_text(encoding="utf-8", errors="replace")
        fm = _fm(text)
        if fm.get("workflow_type") != "inception" or fm.get("status") in ("captured",):
            continue
        if inception_decision(p):
            continue
        out.append({"id": fm.get("id", p.name[:6]), "name": fm.get("name", ""),
                    "recommendation": _recommendation(text), "path": f"/inception/{fm.get('id')}"})
    return out


def partial_complete() -> tuple[list[dict], list[dict]]:
    """(ready, waiting) — active non-inception tasks with an unticked Human criterion."""
    sys.path.insert(0, str(FW))
    os.environ.setdefault("PROJECT_ROOT", str(PROJECT))
    from web.shared import READY, task_review_state  # noqa: E402
    ready, waiting = [], []
    for p in _active_tasks():
        text = p.read_text(encoding="utf-8", errors="replace")
        fm = _fm(text)
        if fm.get("workflow_type") == "inception":
            continue
        state, reasons, n = task_review_state(p)
        if state is None:
            continue
        rec = {"id": fm.get("id", p.name[:6]), "name": fm.get("name", ""), "open_human": n,
               "path": f"/review/{fm.get('id')}", "reasons": list(reasons)}
        (ready if state == READY else waiting).append(rec)
    return ready, waiting


def unrun_runmes() -> list[dict]:
    root = PROJECT / ".context" / "runme"
    out = []
    if not root.is_dir():
        return out
    cutoff = time.time() - 7 * 86400
    for d in sorted(root.iterdir()):
        if not (d / "runme.sh").is_file() or d.stat().st_mtime < cutoff:
            continue
        log = d / "run.log"
        text = log.read_text(errors="replace") if log.is_file() else ""
        if "RUNME EXIT" in text:
            continue
        state = "handed over, not started" if "RUNME START" not in text else "started, no EXIT"
        out.append({"name": d.name, "state": state, "line": f"bash {d / 'runme.sh'}"})
    return out


def pending_proposals() -> list[dict]:
    sys.path.insert(0, str(FW / "lib"))
    os.environ.setdefault("PROJECT_ROOT", str(PROJECT))
    import review_cost  # noqa: E402
    return [{"id": p["id"], "task": p.get("task"), "backend": p.get("backend"),
             "estimate_cost": p.get("estimate_cost"), "why": (p.get("why") or "")[:140]}
            for p in review_cost.proposals().values() if p.get("status") == "pending"]


def issue_replies() -> list[dict]:
    """T-4660: GitHub submitter replies nobody has acted on, one row per issue."""
    sys.path.insert(0, str(FW / "lib"))
    os.environ.setdefault("PROJECT_ROOT", str(PROJECT))
    import issues  # noqa: E402
    by_issue: dict = {}
    for r in issues._undecided_replies():
        by_issue.setdefault(r["issue"], []).append(r)
    return [{"issue": n, "count": len(rs), "class": rs[-1]["class"]} for n, rs in sorted(by_issue.items())]


def collect() -> dict:
    ready, waiting = partial_complete()
    try:
        replies = issue_replies()
    except Exception:  # a broken ledger must not blank the operator's whole list
        replies = []
    return {"issue_replies": replies, "inceptions": undecided_inceptions(), "reviews": ready, "runmes": unrun_runmes(),
            "paid_proposals": pending_proposals(), "waiting_on_agent": len(waiting)}


def render(data: dict) -> str:
    base = _base_url()
    link = (lambda p: f"{base}{p}") if base else (lambda p: p)
    lines = ["# Pending for the operator (live)", ""]
    n = 0
    if data["inceptions"]:
        lines.append("## Inception decisions")
        for i in data["inceptions"]:
            lines.append(f"- {i['id']} — {i['name']} — recommendation: {i['recommendation']} — {link(i['path'])}")
        lines.append("")
        n += len(data["inceptions"])
    if data["reviews"]:
        lines.append("## Human checks (ready)")
        for r in data["reviews"]:
            lines.append(f"- {r['id']} — {r['name']} — {r['open_human']} open — {link(r['path'])}")
        lines.append("")
        n += len(data["reviews"])
    if data["runmes"]:
        lines.append("## Runmes")
        for r in data["runmes"]:
            lines.append(f"- {r['name']} ({r['state']}): {r['line']}")
        lines.append("")
        n += len(data["runmes"])
    if data["paid_proposals"]:
        lines.append("## Paid review proposals (approve with `fw review approve <id>`)")
        for p in data["paid_proposals"]:
            lines.append(f"- {p['id']} — {p['task']} on {p['backend']} (~${p['estimate_cost']}) — {p['why']}")
        lines.append("")
        n += len(data["paid_proposals"])
    if data.get("issue_replies"):
        lines.append("## GitHub issue replies (`fw issues replies`)")
        for r in data["issue_replies"]:
            lines.append(f"- #{r['issue']} — {r['count']} submitter repl{'y' if r['count'] == 1 else 'ies'} "
                         f"({r['class']}) — `fw issues replies`")
        lines.append("")
        n += len(data["issue_replies"])
    if n == 0:
        lines.append("Nothing is waiting on the operator.")
    if data["waiting_on_agent"]:
        lines.append(f"({data['waiting_on_agent']} task(s) with open Human checks are still waiting on the agent, not listed.)")
    return "\n".join(lines).rstrip() + "\n"


def main(argv: list[str]) -> int:
    cmd = argv[0] if argv else "pending"
    if cmd == "decided":
        if len(argv) < 2:
            print("usage: operator_pending.py decided <task-file>", file=sys.stderr)
            return 2
        p = Path(argv[1])
        if _fm(p.read_text(errors="replace")).get("workflow_type") != "inception":
            return 1
        d = inception_decision(p)
        if not d:
            return 1
        print(f"already decided: {d['verdict']} on {d['date'] or 'unknown date'} ({d['source']})")
        return 0
    if cmd == "pending":
        data = collect()
        if "--json" in argv[1:]:
            print(json.dumps(data, indent=2))
        else:
            sys.stdout.write(render(data))
        return 0
    print("usage: operator_pending.py pending [--json] | decided <task-file>", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
