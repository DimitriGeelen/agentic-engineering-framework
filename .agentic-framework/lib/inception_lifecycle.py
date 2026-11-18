#!/usr/bin/env python3
"""T-5227: the inception lifecycle — each inception an instance on aef-inception-lifecycle.

Operator rulings 2026-11-18 (question 2): an EXPLORING inception names what it waits for
(``waiting_on: agent|peer|operator``) and a revisit date (``revisit_at: YYYY-MM-DD``,
default filing date + 7); a daily check routes overdue ones to their owner; the map is
the class and every inception an instance, with time-in-step measured.

This module is the ONE place inception state maps to a map node (``NODES`` below, like
``_LIFECYCLE_NODES`` for the task map in web/blueprints/designer_api.py). Its readers:
  - GET /api/instances?template=aef-inception-lifecycle  (designer_api.py)
  - tools/corpus_overlay.py badge profile for the same map
  - fw inception lifecycle [--json] [--overdue]           (lib/inception.sh)
  - the daily routing: audit section, handover, fw operator pending, approvals page
  - field validation: create-task.sh / render_task.py, update-task.sh, the Write/Edit hook

Placement (open inceptions are the files in .tasks/active/; a completed GO inception is
also open while a build task naming it is open):

  phase            how it is read                                   node
  exploring        Recommendation EXPLORING (or none yet),          il_wait_agent | il_wait_peer
                   by waiting_on (absent = agent)                   | il_wait_operator
  ready            EXPLORING and every IW question disposed          il_ready
                   (T-5226's ready-for-recommendation)
  recommended      Recommendation GO|NO-GO|DEFER, no **Decision**    il_awaiting_decision
  decided-go       **Decision**: GO, build tasks open (or still     il_go_building
                   in active/)
  decided-closed   **Decision**: NO-GO|DEFER, still in active/       il_decided
  closed           in completed/, no open build task                 il_closed (never served
                                                                     by /api/instances)

An inception whose status is not a lifecycle status, or whose waiting_on is not one of the
three values, has no node: NO-POSITION, the same as for tasks.

entered_at: frontmatter ``step_entered_at`` when recorded; else the newest dated Updates
entry that records a status change or an inception decision; else ``created``.
"""

from __future__ import annotations

import argparse
import json
import re
import statistics
import sys
from datetime import date, datetime, timedelta, timezone
from pathlib import Path

MAP_ID = "aef-inception-lifecycle"
WAITING_ON = ("agent", "peer", "operator")
DEFAULT_REVISIT_DAYS = 7
OPEN_STATUSES = ("captured", "started-work", "issues", "work-completed")

# The one table: (phase, waiting_on) -> node uid. waiting_on is None for every phase
# but exploring.
NODES = {
    ("exploring", "agent"): "il_wait_agent",
    ("exploring", "peer"): "il_wait_peer",
    ("exploring", "operator"): "il_wait_operator",
    ("ready", None): "il_ready",
    ("recommended", None): "il_awaiting_decision",
    ("decided-go", None): "il_go_building",
    ("decided-closed", None): "il_decided",
    ("closed", None): "il_closed",
}
# Display order and plain-language labels (fw inception lifecycle).
NODE_ORDER = ("il_wait_agent", "il_wait_peer", "il_wait_operator", "il_ready",
              "il_awaiting_decision", "il_go_building", "il_decided", "il_closed")
LABELS = {
    "il_wait_agent": "exploring, waiting on the agent",
    "il_wait_peer": "exploring, waiting on a peer",
    "il_wait_operator": "exploring, waiting on the operator",
    "il_ready": "ready for a recommendation",
    "il_awaiting_decision": "awaiting the operator's decision",
    "il_go_building": "decided GO, build tasks open",
    "il_decided": "decided NO-GO or DEFER",
    "il_closed": "closed",
}
# Daily routing: the nodes whose revisit date routes the inception back to an owner.
ROUTED = {"il_wait_agent": "agent", "il_wait_peer": "peer",
          "il_wait_operator": "operator", "il_ready": "agent"}

_DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")
_FM_LINE = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*):[ \t]*(.*?)[ \t]*$")
_DECISION_RE = re.compile(r"^\*\*Decision\*\*:\s*(GO|NO-GO|DEFER)\b", re.M | re.I)
_REC_SECTION_RE = re.compile(r"^## Recommendation[ \t]*\n(.*?)(?=^##+ |\Z)", re.M | re.S)
_REC_LINE_RE = re.compile(r"^[ \t]*[-*]?[ \t]*\*\*Recommendation:\*\*[ \t]*\**[ \t]*([A-Za-z-]+)")
_UPDATE_HEAD = re.compile(r"^### (\d{4}-\d\d-\d\dT[0-9:]+Z?)\b", re.M)
_STEP_EVENT = re.compile(r"^- \*\*(?:Change:\*\* status:|Decision:\*\*)", re.M)
_TID = re.compile(r"T-\d+")


# ── field validation (filing paths, update-task, the Write/Edit hook) ──────────────────


def validate_fields(workflow_type, waiting_on, revisit_at):
    """List of problems (empty = valid). Values are raw strings; None/'' means absent."""
    errs = []
    present = [k for k, v in (("waiting_on", waiting_on), ("revisit_at", revisit_at)) if v]
    if present and workflow_type != "inception":
        errs.append(f"{' and '.join(present)} apply to inceptions only "
                    f"(workflow_type is {workflow_type or 'unset'})")
        return errs
    if waiting_on and waiting_on not in WAITING_ON:
        errs.append(f"waiting_on must be agent, peer or operator (got '{waiting_on}')")
    if revisit_at:
        ok = bool(_DATE_RE.match(revisit_at))
        if ok:
            try:
                date.fromisoformat(revisit_at)
            except ValueError:
                ok = False
        if not ok:
            errs.append(f"revisit_at must be a date YYYY-MM-DD (got '{revisit_at}')")
    return errs


def default_revisit(filed: date | None = None) -> str:
    return ((filed or datetime.now(timezone.utc).date()) + timedelta(days=DEFAULT_REVISIT_DAYS)).isoformat()


# ── reading one inception ──────────────────────────────────────────────────────────────


def _frontmatter(text):
    m = re.match(r"^---\n(.*?)\n---", text, re.S)
    if not m:
        return None, 0
    fm = {}
    for line in m.group(1).splitlines():
        km = _FM_LINE.match(line)
        if km and km.group(1) not in fm:
            fm[km.group(1)] = km.group(2).split(" #")[0].strip().strip("\"'")
    return fm, m.end()


def _verdict(body):
    m = _REC_SECTION_RE.search(body)
    if not m:
        return ""
    in_c = False
    for ln in m.group(1).split("\n"):
        if "<!--" in ln:
            in_c = True
        if not in_c:
            lm = _REC_LINE_RE.match(ln)
            if lm:
                return lm.group(1).upper()
        if "-->" in ln:
            in_c = False
    return ""


_BLOCKERS = None


def _ready_for_recommendation(text):
    """T-5226's ready-for-recommendation, from the one in-process transcription of the shell
    predicate (web/shared.py). False when it cannot be loaded: the inception then stays on
    its waiting node, which is the conservative placement."""
    global _BLOCKERS
    if _BLOCKERS is None:
        try:
            root = Path(__file__).resolve().parents[1]
            if str(root) not in sys.path:
                sys.path.insert(0, str(root))
            from web.shared import _handoff_blockers_from_text  # noqa: PLC0415
            _BLOCKERS = _handoff_blockers_from_text
        except Exception:  # noqa: BLE001 — flask absent etc.
            _BLOCKERS = False
    if not _BLOCKERS:
        return False
    try:
        return any(b.get("kind") == "ready-for-recommendation" for b in _BLOCKERS(text))
    except Exception:  # noqa: BLE001
        return False


def _ts(s):
    s = (s or "").strip().strip("\"'")
    if not s:
        return None
    try:
        if _DATE_RE.match(s):
            return datetime.fromisoformat(s).replace(tzinfo=timezone.utc)
        return datetime.fromisoformat(s.replace("Z", "+00:00")).astimezone(timezone.utc)
    except ValueError:
        return None


def _entered_at(fm, body):
    rec = _ts(fm.get("step_entered_at"))
    if rec:
        return rec, "step_entered_at"
    heads = list(_UPDATE_HEAD.finditer(body))
    newest = None
    for i, h in enumerate(heads):
        end = heads[i + 1].start() if i + 1 < len(heads) else len(body)
        if _STEP_EVENT.search(body, h.end(), end):
            t = _ts(h.group(1))
            if t and (newest is None or t > newest):
                newest = t
    if newest:
        return newest, "history"
    return _ts(fm.get("created")), "created"


def place(text, completed=False, building=False):
    """dict(node, phase, waiting_on, reason) for one task file's text, or None when it is
    not an inception. node is None (NO-POSITION) when no table row applies."""
    fm, end = _frontmatter(text)
    if fm is None:
        return {"node": None, "reason": "no frontmatter", "fm": {}}
    if fm.get("workflow_type") != "inception":
        return None
    body = text[end:]
    status = fm.get("status", "")
    raw_wait = fm.get("waiting_on", "")
    out = {"fm": fm, "status": status, "waiting_on": raw_wait or "agent",
           "waiting_on_recorded": bool(raw_wait), "reason": ""}
    decision = _DECISION_RE.search(body)
    decision = decision.group(1).upper() if decision else ""
    if completed:
        phase = "decided-go" if (decision == "GO" and building) else "closed"
    elif status not in OPEN_STATUSES:
        out.update(node=None, reason=f"status '{status}' is not a lifecycle status")
        return out
    elif decision == "GO":
        phase = "decided-go"
    elif decision in ("NO-GO", "DEFER"):
        phase = "decided-closed"
    else:
        verdict = _verdict(body)
        if verdict in ("GO", "NO-GO", "NOGO", "DEFER"):
            phase = "recommended"
        elif verdict in ("EXPLORING", "") and _ready_for_recommendation(text):
            phase = "ready"
        else:
            phase = "exploring"
    key = (phase, out["waiting_on"] if phase == "exploring" else None)
    node = NODES.get(key)
    if node is None:
        out["reason"] = f"waiting_on '{raw_wait}' is not agent, peer or operator"
    out.update(node=node, phase=phase, decision=decision)
    return out


# ── the population ─────────────────────────────────────────────────────────────────────


def _open_build_refs(root):
    """{inception id: [open build task ids]} from active non-inception tasks whose
    unlocks_inception_decision, related_tasks or name names a task id."""
    refs = {}
    for p in sorted((root / ".tasks" / "active").glob("T-*.md")):
        try:
            head = p.read_text(errors="replace")[:6000]
        except OSError:
            continue
        fm, _ = _frontmatter(head)
        if not fm or fm.get("workflow_type") == "inception":
            continue
        tid = fm.get("id") or "-".join(p.name.split("-")[:2])
        named = " ".join(fm.get(k, "") for k in ("unlocks_inception_decision", "related_tasks", "name"))
        for ref in set(_TID.findall(named)) - {tid}:
            refs.setdefault(ref, []).append(tid)
    return refs


def instances(root, today=None, include_closed=False):
    """(rows, examined, unplaced). rows: one dict per inception — open ones from
    .tasks/active/, completed GO ones with open build tasks, and (include_closed) every other
    completed inception on il_closed."""
    root = Path(root)
    today = today or datetime.now(timezone.utc).date()
    now = datetime.combine(today, datetime.min.time(), tzinfo=timezone.utc)
    builds = _open_build_refs(root)
    rows, unplaced, examined = [], [], 0

    def _row(p, text, completed):
        fm_id = re.search(r"^id:[ \t]*(T-\d+)", text, re.M)
        tid = fm_id.group(1) if fm_id else "-".join(p.name.split("-")[:2])
        pl = place(text, completed=completed, building=bool(builds.get(tid)))
        if pl is None:
            return None
        fm = pl["fm"]
        _, end = _frontmatter(text)
        entered, source = _entered_at(fm, text[end:])
        revisit = fm.get("revisit_at", "")
        if revisit and validate_fields("inception", None, revisit):
            revisit_valid = False
        else:
            revisit_valid = True
        if not revisit and pl.get("node") in ROUTED:
            filed = _ts(fm.get("created"))
            revisit = default_revisit(filed.date() if filed else None)
            revisit_source = "default"
        else:
            revisit_source = "recorded" if revisit else ""
        node = pl.get("node")
        owner = ROUTED.get(node)
        overdue = bool(owner and revisit_valid and revisit and revisit <= today.isoformat())
        return {
            "task": tid, "file": p.name, "name": fm.get("name", ""), "node": node,
            "phase": pl.get("phase"), "status": pl.get("status", ""),
            "owner": fm.get("owner", ""), "waiting_on": pl.get("waiting_on") if node else fm.get("waiting_on", ""),
            "next_step_owner": owner,
            "entered_at": entered.strftime("%Y-%m-%dT%H:%M:%SZ") if entered else None,
            "entered_source": source,
            "days_in_step": round((now - entered).total_seconds() / 86400, 1) if entered else None,
            "revisit_at": revisit or None, "revisit_source": revisit_source,
            "revisit_valid": revisit_valid, "overdue": overdue,
            "decision": pl.get("decision", ""), "build_tasks": builds.get(tid, []),
            "reason": pl.get("reason", ""), "completed": completed,
        }

    for p in sorted((root / ".tasks" / "active").glob("T-*.md")):
        try:
            text = p.read_text(errors="replace")
        except OSError as e:
            examined += 1
            unplaced.append({"task": p.name, "reason": f"unreadable: {e}"})
            continue
        if re.match(r"^---\n(.*?)\n---", text, re.S) is None:
            examined += 1  # cannot tell what it is: reported, never dropped (as for tasks)
            unplaced.append({"task": p.name, "reason": "no frontmatter"})
            continue
        if not re.search(r"^workflow_type:[ \t]*['\"]?inception\b", text, re.M):
            continue
        examined += 1
        r = _row(p, text, completed=False)
        if r:
            rows.append(r)
    done_dir = root / ".tasks" / "completed"
    if done_dir.is_dir():
        wanted = None if include_closed else set(builds)
        for p in sorted(done_dir.glob("T-*.md")):
            tid = "-".join(p.name.split("-")[:2])
            if wanted is not None and tid not in wanted:
                continue
            try:
                text = p.read_text(errors="replace")
            except OSError:
                continue
            if not re.search(r"^workflow_type:[ \t]*['\"]?inception\b", text, re.M):
                continue
            r = _row(p, text, completed=True)
            if r and (include_closed or r["node"] == "il_go_building"):
                examined += 1
                rows.append(r)
    return rows, examined, unplaced


def overdue_by_owner(root, today=None):
    """{agent: [rows], peer: [rows], operator: [rows]} — the daily routing."""
    out = {o: [] for o in WAITING_ON}
    rows, _, _ = instances(root, today)
    for r in rows:
        if r["overdue"] and r["next_step_owner"]:
            out[r["next_step_owner"]].append(r)
    for o in out:
        out[o].sort(key=lambda r: (r["revisit_at"] or "", r["task"]))
    return out


def summary(root, today=None):
    """Per node: count, median days in step, overdue count (fw inception lifecycle)."""
    rows, examined, unplaced = instances(root, today, include_closed=True)
    nodes = []
    for uid in NODE_ORDER:
        here = [r for r in rows if r["node"] == uid]
        days = [r["days_in_step"] for r in here if r["days_in_step"] is not None]
        nodes.append({
            "node": uid, "label": LABELS[uid], "count": len(here),
            "median_days_in_step": round(statistics.median(days), 1) if days else None,
            "overdue": sum(1 for r in here if r["overdue"]),
            "owner": ROUTED.get(uid),
        })
    no_pos = [{"task": r["task"], "reason": r["reason"]} for r in rows if r["node"] is None]
    return {"map": MAP_ID, "generated": (today or datetime.now(timezone.utc).date()).isoformat(),
            "nodes": nodes, "no_position": no_pos, "unplaced": unplaced,
            "open": sum(1 for r in rows if r["node"] not in (None, "il_closed")),
            "overdue": sum(1 for r in rows if r["overdue"])}


# ── fw inception wait: record who holds the next step ──────────────────────────────────


def _set_fm_key(fm_text, key, value):
    line = f"{key}: {value}"
    new, n = re.subn(rf"(?m)^{re.escape(key)}:.*$", lambda m: line, fm_text, count=1)
    if n:
        return new
    new, n = re.subn(r"(?m)^(related_tasks:.*)$", lambda m: m.group(1) + "\n" + line, fm_text, count=1)
    return new if n else fm_text.rstrip("\n") + "\n" + line


def set_wait(path, on, revisit=None, now=None):
    """Set waiting_on / revisit_at (default today + 7) / step_entered_at on one inception
    and record the change under ## Updates. Returns the new revisit date; raises ValueError
    with the problems when the values or the task do not qualify."""
    path = Path(path)
    text = path.read_text()
    m = re.match(r"^---\n(.*?)\n---", text, re.S)
    if not m:
        raise ValueError(f"{path.name}: no frontmatter")
    fm, _ = _frontmatter(text)
    now = now or datetime.now(timezone.utc)
    revisit = revisit or default_revisit(now.date())
    errs = validate_fields(fm.get("workflow_type"), on, revisit)
    if errs:
        raise ValueError("; ".join(errs))
    before = fm.get("waiting_on") or "agent"
    stamp = now.strftime("%Y-%m-%dT%H:%M:%SZ")
    head = m.group(1)
    for k, v in (("waiting_on", on), ("revisit_at", revisit), ("step_entered_at", f"'{stamp}'"),
                 ("last_update", stamp)):
        head = _set_fm_key(head, k, v)
    text = "---\n" + head + "\n---" + text[m.end():]
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    from task_updates import insert_entry  # noqa: PLC0415
    text = insert_entry(text, f"### {stamp} — inception-wait [inception-lifecycle]\n"
                              f"- **Change:** waiting_on: {before} → {on}\n"
                              f"- **Revisit:** {revisit}")
    path.write_text(text)
    return revisit


# ── CLI ────────────────────────────────────────────────────────────────────────────────


def _print_summary(s):
    print(f"Inception lifecycle ({s['map']}) — {s['open']} open, {s['overdue']} overdue")
    print(f"  {'step':<40} {'count':>5} {'median days':>12} {'overdue':>8}")
    for n in s["nodes"]:
        med = "-" if n["median_days_in_step"] is None else f"{n['median_days_in_step']:.1f}"
        print(f"  {n['label']:<40} {n['count']:>5} {med:>12} {n['overdue']:>8}")
    if s["no_position"]:
        print(f"  NO-POSITION: {len(s['no_position'])} — "
              + ", ".join(f"{x['task']} ({x['reason']})" for x in s["no_position"][:5]))
    if s["unplaced"]:
        print(f"  unplaced files: {len(s['unplaced'])}")


def _print_overdue(by, owner=None, limit=0):
    heads = {"agent": "Overdue inceptions — the agent's next step",
             "peer": "Overdue inceptions — remind the peer (the agent sends it: fw sidecar send --to <peer>)",
             "operator": "Overdue inceptions — questions waiting for the operator"}
    for o in ([owner] if owner else WAITING_ON):
        rows = by.get(o, [])
        if not rows:
            continue
        print(f"{heads[o]} ({len(rows)}):")
        for r in rows[: limit or None]:
            print(f"  - {r['task']} {LABELS.get(r['node'], '')}, revisit {r['revisit_at']}: {r['name']}")
        if limit and len(rows) > limit:
            print(f"  ... and {len(rows) - limit} more (fw inception lifecycle --overdue)")


HANDOVER_LIMIT = 15


def handover_md(root, today=None, limit=HANDOVER_LIMIT):
    """Markdown for the handover: overdue inceptions the agent owns (next actions) and the
    peer reminders the agent sends. Empty string when none are overdue."""
    by = overdue_by_owner(root, today)
    out = []
    if by["agent"]:
        out += ["## Overdue Inceptions — Next Actions for the Agent", "",
                "Their revisit date has passed and the next step is the agent's "
                "(T-5227). Move each one on, or record who it now waits for: "
                "`fw inception wait T-XXX agent|peer|operator [--revisit YYYY-MM-DD]`.", ""]
        out += [f"- {r['task']}: {r['name']} — {LABELS[r['node']]}, revisit {r['revisit_at']}"
                for r in by["agent"][:limit]]
        if len(by["agent"]) > limit:
            out.append(f"- ... and {len(by['agent']) - limit} more: `fw inception lifecycle --overdue`")
        out.append("")
    if by["peer"]:
        out += ["## Overdue Inceptions — Remind the Peer", "",
                "These wait on another agent and their revisit date has passed. The agent "
                "sends the reminder (`fw sidecar send --to <peer> --body \"...\"`, the peer is "
                "named in the task), then sets a new date with `fw inception wait T-XXX peer "
                "--revisit YYYY-MM-DD`.", ""]
        out += [f"- {r['task']}: {r['name']} — revisit {r['revisit_at']}" for r in by["peer"][:limit]]
        if len(by["peer"]) > limit:
            out.append(f"- ... and {len(by['peer']) - limit} more: `fw inception lifecycle --overdue --owner peer`")
        out.append("")
    if by["operator"]:
        out += [f"{len(by['operator'])} overdue inception question(s) wait for the operator: "
                "listed by `fw operator pending` and on the approvals page.", ""]
    return "\n".join(out).rstrip("\n")


def main(argv=None):
    ap = argparse.ArgumentParser(prog="fw inception lifecycle", description=(
        "Inception lifecycle: per step the count, the median days in step and the overdue "
        "count; --overdue lists overdue inceptions by owner (the daily routing)."))
    ap.add_argument("--root", default=None, help="project root (default: PROJECT_ROOT or cwd)")
    ap.add_argument("--json", action="store_true")
    ap.add_argument("--overdue", action="store_true", help="list overdue inceptions by owner")
    ap.add_argument("--owner", choices=WAITING_ON, help="with --overdue: one owner only")
    ap.add_argument("--limit", type=int, default=0, help="with --overdue: max rows per owner")
    ap.add_argument("--today", default=None, help=argparse.SUPPRESS)
    ap.add_argument("--validate", nargs=3, metavar=("WORKFLOW_TYPE", "WAITING_ON", "REVISIT_AT"),
                    help="check field values; exit 1 with the problems on stderr")
    ap.add_argument("--set-wait", nargs=2, metavar=("TASK_FILE", "WAITING_ON"), help=argparse.SUPPRESS)
    ap.add_argument("--revisit", default=None, help=argparse.SUPPRESS)
    ap.add_argument("--handover", action="store_true", help=argparse.SUPPRESS)
    a = ap.parse_args(argv)
    if a.handover:
        import os
        md = handover_md(Path(a.root or os.environ.get("PROJECT_ROOT") or "."),
                         date.fromisoformat(a.today) if a.today else None)
        if md:
            print(md)
        return 0
    if a.set_wait:
        try:
            when = set_wait(a.set_wait[0], a.set_wait[1], a.revisit)
        except (ValueError, OSError) as e:
            print(f"Refused: {e}", file=sys.stderr)
            return 1
        print(f"waiting_on: {a.set_wait[1]}, revisit_at: {when}")
        return 0
    if a.validate:
        errs = validate_fields(*(v if v not in ("-", "") else None for v in a.validate))
        for e in errs:
            print(e, file=sys.stderr)
        return 1 if errs else 0
    import os
    root = Path(a.root or os.environ.get("PROJECT_ROOT") or ".")
    today = date.fromisoformat(a.today) if a.today else None
    if a.overdue:
        by = overdue_by_owner(root, today)
        if a.owner:
            by = {a.owner: by[a.owner]}
        if a.json:
            print(json.dumps({o: [{k: r[k] for k in ("task", "name", "node", "waiting_on",
                                                       "revisit_at", "entered_at", "days_in_step")}
                                  for r in rows] for o, rows in by.items()}, indent=2))
        else:
            _print_overdue(by, a.owner, a.limit)
        return 0
    s = summary(root, today)
    if a.json:
        print(json.dumps(s, indent=2))
    else:
        _print_summary(s)
    return 0


if __name__ == "__main__":
    sys.exit(main())
