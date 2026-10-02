#!/usr/bin/env python3
"""Design-conformance register checks (T-3691 items 3 and 5, T-3694).

One predicate module, four consumers: `fw audit` (structure section), `fw doctor`,
Watchtower /approvals, and the close gate in agents/task-create/update-task.sh.
Two surfaces with two copies of a predicate is how a gap survives (L-638), so
every consumer imports or shells out to this file.

A register is a fenced YAML block whose top-level key is `register:` inside a
Markdown design doc. Rows are {id, text, source, owner_task, status, evidence}.
Register docs are found two ways: linked from an arc (`design_doc:` or
`register_docs:` in .context/arcs/*.yaml), and any Markdown under docs/ that
carries such a block. The second way exists because the sidecar register was
written into a doc no arc linked, which made the T-3691 close gate inert for the
very arc it was built for.

Checks:
  violations     — a row with no owner_task, an owner that does not exist, or an
                   owner that is completed while the row is not built (audit FAIL,
                   doctor WARN).
  stale-keystones — a captured task that owns an unbuilt row, or is named as an
                   arc's keystone / slice 1, captured for more than N days (audit
                   WARN, /approvals line).
  self-deferral  — the closing task's own body or result defers work to a task id
                   that does not exist, is not active, or never mentions the
                   closing task (the T-3691 "deferred to T-3692/T-3693" hole).

CLI (exit 0 = clean, 1 = findings, 2 = usage error):
  design_register.py violations [--root DIR]
  design_register.py stale-keystones [--root DIR] [--days N] [--json]
  design_register.py close-check TASK_FILE [--root DIR]
  design_register.py self-deferral TASK_FILE [--root DIR]
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

import yaml

TASK_ID_RE = re.compile(r"\bT-\d{3,}\b")
_FENCE_RE = re.compile(r"```ya?ml[ \t]*\n(.*?)```", re.DOTALL)


# ---------------------------------------------------------------- tasks

def _frontmatter(text: str) -> dict:
    if not text.startswith("---"):
        return {}
    end = text.find("\n---", 3)
    if end < 0:
        return {}
    try:
        fm = yaml.safe_load(text[3:end]) or {}
    except yaml.YAMLError:
        return {}
    return fm if isinstance(fm, dict) else {}


def _body(text: str) -> str:
    if not text.startswith("---"):
        return text
    end = text.find("\n---", 3)
    return text[end + 4:] if end >= 0 else text


def task_index(root: Path) -> dict:
    """{task_id: {location, status, name, path, fm}} over active/ and completed/."""
    out: dict = {}
    for loc in ("active", "completed"):
        d = root / ".tasks" / loc
        if not d.is_dir():
            continue
        for p in sorted(d.glob("T-*.md")):
            m = re.match(r"(T-\d+)-", p.name)
            if not m:
                continue
            tid = m.group(1)
            try:
                text = p.read_text(errors="replace")
            except OSError:
                continue
            fm = _frontmatter(text)
            out[tid] = {
                "location": loc,
                "status": str(fm.get("status") or ""),
                "name": str(fm.get("name") or ""),
                "path": p,
                "fm": fm,
                "text": text,
            }
    return out


def is_live(info: dict | None) -> bool:
    """Active means in active/ and not already work-completed."""
    return bool(info) and info["location"] == "active" and info["status"] != "work-completed"


# ---------------------------------------------------------------- registers

def parse_register(path: Path) -> list:
    """Rows of every `register:` fenced YAML block in a Markdown doc."""
    try:
        text = path.read_text(errors="replace")
    except OSError:
        return []
    rows = []
    for block in _FENCE_RE.findall(text):
        if not re.match(r"\s*register:", block):
            continue
        try:
            data = yaml.safe_load(block)
        except yaml.YAMLError:
            continue
        for r in (data or {}).get("register") or []:
            if isinstance(r, dict):
                rows.append(r)
    return rows


def _arc_files(root: Path) -> list:
    d = root / ".context" / "arcs"
    return sorted(d.glob("*.yaml")) if d.is_dir() else []


def _load_arc(p: Path) -> dict:
    try:
        data = yaml.safe_load(p.read_text(errors="replace")) or {}
    except (OSError, yaml.YAMLError):
        return {}
    return data if isinstance(data, dict) else {}


def _as_list(v) -> list:
    if v is None or v == "":
        return []
    return list(v) if isinstance(v, (list, tuple)) else [v]


def arc_register_docs(root: Path, arc: dict) -> list:
    out = []
    for rel in _as_list(arc.get("design_doc")) + _as_list(arc.get("register_docs")):
        p = root / str(rel).lstrip("/")
        if p.is_file() and parse_register(p):
            out.append(p)
    return out


def resolve_arc(root: Path, arc_id: str) -> dict:
    """Arc by filename slug or by its `id:` field (arc-011 lives in
    parallel-execution-aef.yaml, which a filename-only lookup never finds)."""
    arc_id = str(arc_id or "").strip()
    if not arc_id:
        return {}
    for p in _arc_files(root):
        if p.stem == arc_id:
            return _load_arc(p)
    for p in _arc_files(root):
        a = _load_arc(p)
        if str(a.get("id") or "") == arc_id or str(a.get("slug") or "") == arc_id:
            return a
    return {}


def find_register_docs(root: Path) -> list:
    docs = set()
    for p in _arc_files(root):
        docs.update(arc_register_docs(root, _load_arc(p)))
    ddir = root / "docs"
    if ddir.is_dir():
        for p in ddir.rglob("*.md"):
            try:
                text = p.read_text(errors="replace")
            except OSError:
                continue
            if re.search(r"^register:", text, re.M) and parse_register(p):
                docs.add(p)
    return sorted(docs)


def register_violations(root: Path, tasks: dict | None = None) -> list:
    tasks = task_index(root) if tasks is None else tasks
    out = []
    for doc in find_register_docs(root):
        rel = str(doc.relative_to(root)) if doc.is_relative_to(root) else str(doc)
        for row in parse_register(doc):
            rid = row.get("id", "?")
            owner = str(row.get("owner_task") or "").strip()
            status = str(row.get("status") or "").strip()
            if not owner:
                out.append(f"{rel}: {rid}: no owner_task")
                continue
            info = tasks.get(owner)
            if info is None:
                out.append(f"{rel}: {rid}: owner_task {owner} does not exist")
            elif not is_live(info) and status != "built":
                out.append(f"{rel}: {rid}: owner {owner} is completed but row status is "
                           f"'{status or 'unset'}' (not built)")
    return out


# ---------------------------------------------------------------- stale keystones

_KEYSTONE_NAME_RE = re.compile(r"\bkeystone\b|\bslice[ -]?1\b", re.I)
_S1_RE = re.compile(r"\bS1\b")
_CAPTURED_RE = re.compile(
    r"^### (\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z)[^\n]*\n(?:(?!^### )[^\n]*\n)*?[^\n]*→\s*captured\b",
    re.M)


def _parse_ts(v) -> datetime | None:
    if isinstance(v, datetime):
        return v if v.tzinfo else v.replace(tzinfo=timezone.utc)
    s = str(v or "").strip()
    if not s:
        return None
    try:
        dt = datetime.fromisoformat(s.replace("Z", "+00:00"))
    except ValueError:
        return None
    return dt if dt.tzinfo else dt.replace(tzinfo=timezone.utc)


def captured_since(info: dict) -> datetime | None:
    """Last transition into captured, else created."""
    hits = _CAPTURED_RE.findall(info.get("text", ""))
    if hits:
        return _parse_ts(hits[-1])
    return _parse_ts(info["fm"].get("created"))


def stale_keystones(root: Path, days: float = 3.0, now: datetime | None = None,
                    tasks: dict | None = None) -> list:
    tasks = task_index(root) if tasks is None else tasks
    now = now or datetime.now(timezone.utc)
    reasons: dict = {}
    arc_of: dict = {}  # task id -> arc slug, when an arc names the task itself

    for doc in find_register_docs(root):
        for row in parse_register(doc):
            if str(row.get("status") or "") == "built":
                continue
            owner = str(row.get("owner_task") or "").strip()
            if owner:
                reasons.setdefault(owner, set()).add(f"owns unbuilt register row {row.get('id', '?')}")

    arc_slug_by_id = {}
    for p in _arc_files(root):
        a = _load_arc(p)
        slug = str(a.get("slug") or p.stem)
        arc_slug_by_id[str(a.get("id") or p.stem)] = slug
        arc_slug_by_id[p.stem] = slug
        for key in ("keystone_task", "keystone", "slice_1", "slice_1_task"):
            for tid in _as_list(a.get(key)):
                reasons.setdefault(str(tid), set()).add(f"named as {key} of arc {slug}")
                arc_of.setdefault(str(tid), slug)

    for tid, info in tasks.items():
        arc_id = str(info["fm"].get("arc_id") or "").strip()
        if arc_id and (_KEYSTONE_NAME_RE.search(info["name"]) or _S1_RE.search(info["name"])):
            reasons.setdefault(tid, set()).add(f"keystone/slice 1 of arc {arc_slug_by_id.get(arc_id, arc_id)}")

    out = []
    for tid, why in reasons.items():
        info = tasks.get(tid)
        if not info or info["location"] != "active" or info["status"] != "captured":
            continue
        since = captured_since(info)
        if since is None:
            continue
        age = (now - since).total_seconds() / 86400.0
        if age <= days:
            continue
        arc_id = str(info["fm"].get("arc_id") or "")
        out.append({
            "task_id": tid,
            "name": info["name"],
            "arc": arc_slug_by_id.get(arc_id, arc_id) if arc_id else arc_of.get(tid, ""),
            "days_captured": int(age),
            "captured_since": since.strftime("%Y-%m-%dT%H:%M:%SZ"),
            "reasons": sorted(why),
        })
    out.sort(key=lambda r: -r["days_captured"])
    return out


# ---------------------------------------------------------------- self-deferral

# Sections that describe the PROBLEM (or are machine-written) are not the task's
# own result; a Context line that says "T-3691 deferred to T-3692" is a finding
# about another task, not a deferral by this one.
_SKIP_SECTIONS = {"context", "updates", "reviewer verdict", "rca", "decision"}
# A deferral names its target AFTER the verb: "deferred to T-X", "split into
# T-X and T-Y", "handed off to T-X". "follow-up" is the one shape that names the
# target on either side ("new tasks T-X, T-Y for follow-up"). `deferred:T-X` is a
# ships_in referent literal, not prose, and is dropped before matching.
_DEFER_AFTER_RE = re.compile(
    r"\bdefer(?:s|red|ring)?\b\W+(?:[\w/()'\"-]+\W+){0,8}?(?:to|into|until)\b"
    r"|\bpostpone[sd]?\b\W+(?:[\w/()'\"-]+\W+){0,8}?to\b"
    r"|\bsplit (?:off )?into\b|\bleft for\b|\bhanded (?:off|over) to\b",
    re.I)
_FOLLOWUP_RE = re.compile(r"\bfollow[- ]?ups?\b", re.I)


def _deferral_targets(sentence: str) -> list:
    s = re.sub(r"\bdeferred:\S+", "", sentence, flags=re.I)
    ids = []
    for m in _DEFER_AFTER_RE.finditer(s):
        # Targets sit right after the verb ("deferred to separate tasks (T-X,
        # T-Y)"); an id further along the sentence is usually its subject or
        # evidence, not where the work went.
        ids += TASK_ID_RE.findall(s[m.end():m.end() + 100])
    if _FOLLOWUP_RE.search(s):
        ids += TASK_ID_RE.findall(s)
    return list(dict.fromkeys(ids))


def _own_result_text(text: str) -> str:
    body = _body(text)
    body = re.sub(r"<!--.*?-->", "", body, flags=re.S)
    body = re.sub(r"```.*?```", "", body, flags=re.S)
    body = re.sub(r"`[^`\n]*`", "", body)
    keep, skip = [], False
    for line in body.splitlines():
        m = re.match(r"^##\s+(.+?)\s*$", line)
        if m:
            skip = m.group(1).strip().lower() in _SKIP_SECTIONS
            continue
        if not skip:
            keep.append(line)
    return "\n".join(keep)


def self_deferrals(task_file: Path, root: Path, tasks: dict | None = None) -> list:
    """Deferrals in the closing task's own result whose target cannot own them."""
    try:
        text = task_file.read_text(errors="replace")
    except OSError:
        return []
    m = re.match(r"(T-\d+)", task_file.name)
    self_id = m.group(1) if m else str(_frontmatter(text).get("id") or "")
    tasks = task_index(root) if tasks is None else tasks
    problems, seen = [], set()
    own = _own_result_text(text)
    sentences = re.split(r"(?<=[.;!?])\s+|\n", own)
    for s in sentences:
        for tid in _deferral_targets(s):
            if tid == self_id or tid in seen:
                continue
            seen.add(tid)
            info = tasks.get(tid)
            snippet = s.strip()[:120]
            if info is None:
                problems.append(f"{tid} does not exist — \"{snippet}\"")
            elif not is_live(info):
                problems.append(f"{tid} is not active ({info['location']}/{info['status']}) — \"{snippet}\"")
            elif not re.search(rf"\b{re.escape(self_id)}\b", info["text"]):
                problems.append(f"{tid} never mentions {self_id}, so nothing ties it to this "
                                f"deferral (\"{info['name'][:60]}\") — \"{snippet}\"")
    return problems


# ---------------------------------------------------------------- close gate

def close_check(task_file: Path, root: Path, tasks: dict | None = None) -> list:
    """Register problems that refuse `--status work-completed` (T-3691 item 2).

    1. A row of a register linked from the task's arc that the task body defers
       ("R7 deferred", "deferred: R7") while the row has no live owner.
    2. Any register row the closing task itself owns that is not built. This is
       the T-3561 shape: the owner closed and the row stayed partial, so the
       register pointed at a finished task for work nobody was doing. The audit
       catches it afterwards; this refuses it at the earliest moment.
    """
    try:
        text = task_file.read_text(errors="replace")
    except OSError:
        return []
    m = re.match(r"(T-\d+)", task_file.name)
    self_id = m.group(1) if m else ""
    tasks = task_index(root) if tasks is None else tasks
    fm = _frontmatter(text)
    problems = []

    arc = resolve_arc(root, str(fm.get("arc_id") or ""))
    body = _body(text).lower()
    for doc in arc_register_docs(root, arc) if arc else []:
        for row in parse_register(doc):
            rid = str(row.get("id") or "")
            if not rid:
                continue
            r = re.escape(rid.lower())
            # Any verb form: T-3691's version matched only "deferred", so "this
            # slice defers R2" passed and its own suite's treatment tests were red.
            dv = r"\bdefer(?:s|red|ring)?\b"
            if not re.search(rf"\b{r}\b.*{dv}|{dv}.*\b{r}\b", body):
                continue
            owner = str(row.get("owner_task") or "").strip()
            status = str(row.get("status") or "")
            if not owner:
                problems.append(f"{rid}: deferred here but has no owner_task")
            elif owner == self_id:
                continue  # reported by check 2 below
            elif owner not in tasks:
                problems.append(f"{rid}: deferred to owner_task {owner}, which does not exist")
            elif not is_live(tasks[owner]) and status != "built":
                problems.append(f"{rid}: deferred to owner_task {owner}, which is completed "
                                f"while the row is '{status}'")

    for doc in find_register_docs(root):
        for row in parse_register(doc):
            if str(row.get("owner_task") or "").strip() != self_id:
                continue
            status = str(row.get("status") or "")
            if status != "built":
                problems.append(f"{row.get('id', '?')}: owned by {self_id} and still '{status}' — "
                                f"build it, or re-point owner_task to the task that will")
    return problems


# ---------------------------------------------------------------- CLI

def _root(arg: str | None) -> Path:
    return Path(arg or os.environ.get("PROJECT_ROOT") or os.getcwd()).resolve()


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(prog="design_register.py")
    sub = ap.add_subparsers(dest="cmd")
    v = sub.add_parser("violations")
    v.add_argument("--root")
    s = sub.add_parser("stale-keystones")
    s.add_argument("--root")
    s.add_argument("--days", type=float, default=3.0)
    s.add_argument("--json", action="store_true")
    c = sub.add_parser("close-check")
    c.add_argument("task_file")
    c.add_argument("--root")
    d = sub.add_parser("self-deferral")
    d.add_argument("task_file")
    d.add_argument("--root")
    a = ap.parse_args(argv)
    if not a.cmd:
        ap.print_usage(sys.stderr)
        return 2
    root = _root(a.root)
    if a.cmd == "violations":
        found = register_violations(root)
        if not found and not find_register_docs(root):
            print("no register docs")
        for f in found:
            print(f)
        return 1 if found else 0
    if a.cmd == "stale-keystones":
        rows = stale_keystones(root, days=a.days)
        if a.json:
            print(json.dumps(rows))
        else:
            for r in rows:
                print(f"{r['task_id']}: captured {r['days_captured']}d — {'; '.join(r['reasons'])}")
        return 1 if rows else 0
    if a.cmd == "close-check":
        found = close_check(Path(a.task_file), root)
        for f in found:
            print(f)
        return 1 if found else 0
    if a.cmd == "self-deferral":
        found = self_deferrals(Path(a.task_file), root)
        for f in found:
            print(f)
        return 1 if found else 0
    return 2


if __name__ == "__main__":
    sys.exit(main())
