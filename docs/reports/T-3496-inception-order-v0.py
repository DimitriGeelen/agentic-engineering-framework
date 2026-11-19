#!/usr/bin/env python3
"""T-3496 exploration spike, v0: which inception first? (read-only)

Prints this project's open inceptions in a suggested order, with the reasons
beside each. Reads task files only; writes nothing. The weights are a first
guess, printed in the header so they can be argued with; the operator's
reactions to this list are the evidence for IW-3/IW-4.

Usage: python3 docs/reports/T-3496-inception-order-v0.py [PROJECT_ROOT] [--all]
"""
import datetime as dt
import glob
import os
import re
import sys

import yaml

WEIGHTS = {
    "peer_waiting": 3.0,         # a peer project is blocked on our answer
    "mention": 1.0,              # per other active task that names it (cap 5)
    "related": 0.5,              # per declared related task (cap 2)
    "per_day_waiting": 0.1,      # days in the current step (cap 3)
    "overdue": 2.0,              # revisit date passed
    "all_disposed": 2.0,         # every question answered: only the verdict left
    "part_disposed": 1.0,        # x fraction answered
    "no_questions": -1.0,        # nothing filed yet: cost to finish unknown
    "delay_words": 1.0,          # problem text says something is stuck/broken
    "component": 0.5,            # per declared component (cap 2)
}
DELAY_RE = re.compile(r"\b(parked|stuck|blocked|broken|regression|fails?|outage|lost)\b", re.I)
Q_RE = re.compile(r"^\s*-\s*\*\*IW-\d+", re.M)
D_RE = re.compile(r"disposition:\s*(answered|deferred|dissolved)")


def strip_comments(text):
    out, in_c = [], False
    for ln in text.split("\n"):
        if in_c:
            if "-->" in ln:
                in_c = False
            continue
        if ln.lstrip().startswith("<!--"):
            if "-->" not in ln[ln.index("<!--") + 4:]:
                in_c = True
            continue
        out.append(ln)
    return "\n".join(out)


def section(text, head):
    m = re.search(rf"^## {head}\s*\n(.*?)(?=^## |\Z)", text, re.S | re.M)
    return strip_comments(m.group(1)) if m else ""


def verdict(text):
    m = re.search(r"^\s*[-*]?\s*\*\*Recommendation:\*\*\s*\**\s*([A-Za-z-]+)",
                  section(text, "Recommendation"), re.M)
    return m.group(1).upper() if m else ""


def load(root):
    tasks = {}
    for f in glob.glob(os.path.join(root, ".tasks/active/*.md")):
        t = open(f, encoding="utf-8", errors="replace").read()
        m = re.match(r"---\n(.*?)\n---", t, re.S)
        try:
            fm = yaml.safe_load(m.group(1)) if m else None
        except yaml.YAMLError:
            fm = None
        if isinstance(fm, dict) and fm.get("id"):
            tasks[fm["id"]] = (fm, t)
    return tasks


def days_since(v, today):
    if not v:
        return None
    try:
        d = dt.date.fromisoformat(str(v)[:10])
    except ValueError:
        return None
    return (today - d).days


def score(tid, fm, text, tasks, today):
    s, why = 0.0, []
    waiting = fm.get("waiting_on") or "?"
    if waiting == "peer":
        s += WEIGHTS["peer_waiting"]
        why.append("a peer is waiting")
    mentions = sum(1 for o, (_, ot) in tasks.items()
                   if o != tid and re.search(rf"\b{re.escape(tid)}\b", ot))
    if mentions:
        s += WEIGHTS["mention"] * min(mentions, 5)
        why.append(f"named by {mentions} other active task(s)")
    rel = fm.get("related_tasks") or []
    if rel:
        s += WEIGHTS["related"] * min(len(rel), 2)
        why.append(f"{len(rel)} related task(s)")
    d = days_since(fm.get("step_entered_at"), today)
    if d:
        s += min(WEIGHTS["per_day_waiting"] * d, 3.0)
        why.append(f"{d} day(s) in this step")
    r = days_since(fm.get("revisit_at"), today)
    if r is not None and r > 0:
        s += WEIGHTS["overdue"]
        why.append(f"revisit overdue {r} day(s)")
    oq = section(text, "Open Questions")
    q, dsp = len(Q_RE.findall(oq)), len(D_RE.findall(oq))
    if q == 0:
        s += WEIGHTS["no_questions"]
        why.append("no questions filed yet")
    elif dsp >= q:
        s += WEIGHTS["all_disposed"]
        why.append(f"all {q} question(s) answered: verdict left")
    else:
        s += WEIGHTS["part_disposed"] * dsp / q
        why.append(f"{dsp} of {q} question(s) answered")
    if DELAY_RE.search(section(text, "Problem Statement")[:3000]):
        s += WEIGHTS["delay_words"]
        why.append("problem says something is stuck/broken")
    comps = fm.get("components") or []
    if comps:
        s += WEIGHTS["component"] * min(len(comps), 2)
        why.append(f"touches {len(comps)} component(s)")
    return s, waiting, why


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    root = args[0] if args else os.getcwd()
    show_all = "--all" in sys.argv
    today = dt.date.today()
    tasks = load(root)
    rows = []
    for tid, (fm, text) in tasks.items():
        if fm.get("workflow_type") != "inception" or fm.get("status") == "work-completed":
            continue
        v = verdict(text)
        if re.search(r"^## Decision\s*\n+\*\*Decision\*\*", text, re.M):
            continue
        s, waiting, why = score(tid, fm, text, tasks, today)
        rows.append((s, tid, waiting, v or "-", str(fm.get("name", ""))[:60], why))
    rows.sort(key=lambda r: (-r[0], r[1]))
    print(f"Inception order v0 (T-3496 spike, read-only) — {len(rows)} open, {today}")
    print("weights: " + ", ".join(f"{k}={v}" for k, v in WEIGHTS.items()))
    for group, label in (("agent", "Waiting on the agent"), ("peer", "Waiting on a peer"),
                         ("operator", "Waiting on the operator"), ("?", "Owner not set")):
        g = [r for r in rows if r[2] == group]
        if not g:
            continue
        print(f"\n## {label} ({len(g)})")
        for i, (s, tid, _, v, name, why) in enumerate(g if show_all else g[:10], 1):
            print(f"{i:>2}. {tid}  {s:5.1f}  [{v}]  {name}")
            print(f"      {'; '.join(why)}")


if __name__ == "__main__":
    main()
