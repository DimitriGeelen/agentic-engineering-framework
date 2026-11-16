#!/usr/bin/env python3
"""accepted_miss — the third acceptance-criterion state: an operator-accepted miss (T-5181).

Build of inception T-5152 (GO 2026-11-16; origin 832 T-1415). An Agent criterion that was
honestly NOT met can be resolved for P-010 — never counted as met — when the operator
accepts the miss:

    - [~] <criterion title>
      **Accepted miss:** AM-xxxxxxxx — <operator's reason>

The marker alone means nothing. It counts only when `.context/reviews/accepted-misses.jsonl`
(append-only) holds a row for this task whose `digest` is the criterion's CURRENT canonical
digest (`lib/verdict_ledger.criterion_digest`: title + body, framework annotations excluded)
and whose `id` is the one the annotation cites. Editing the criterion after acceptance voids
it. A bare `[~]`, a stale one, or any other box character counts as unchecked.

The agent may PROPOSE a miss by adding `**Miss proposed:** <why, with evidence>` under an
open criterion; that line changes nothing for any gate and is excluded from the digest.
Only the FIRST `**Accepted miss:**` line, directly under the title, is the annotation and
outside the digest; any other such line is criterion text (T-5181 review #7).

Verbs (`accept` is the operator's alone: refused under CLAUDECODE/AI_AGENT even with
--i-am-human, like `human_ac_ticks.py delegation widen` — T-5181 review #1; a row written
with `by: agent-override` by an older build never resolves anything):
    accept T-XXX --ac N --reason "..."   rewrite the box, annotate, append the ledger row
    gate FILE [--stdin [--agent]]        P-010 helper: MISS / BAD lines. With --stdin the
                                         boxes are those in the text the CALLER counted
                                         (one source of truth, T-5181 review #2)
    list FILE                            accepted misses of a task (close output, episodic)
    audit                                FAIL on a committed [~] without a matching row, and on
                                         a non-append-only ledger history

Exit codes of `audit`: 0 clean, 2 at least one finding, 3 could not run.

WHAT THIS DOES NOT CLAIM: every agent here runs as the same OS user as the operator; one
that appends a ledger row from a script is indistinguishable from the operator (same
residual as T-3581 / human_ac_ticks). The audit catches hand-written markers and history
rewrites, not a coherent forgery.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import subprocess
import sys
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path

_HERE = Path(__file__).resolve().parent
if str(_HERE.parent) not in sys.path:
    sys.path.insert(0, str(_HERE.parent))
if str(_HERE) not in sys.path:
    sys.path.insert(0, str(_HERE))

from lib.verdict_ledger import criterion_digest as _vl_criterion_digest  # noqa: E402
from lib.verdict_ledger import history_fault as _vl_history_fault  # noqa: E402
from comment_strip import strip_html_comment_lines  # noqa: E402

LEDGER = ".context/reviews/accepted-misses.jsonl"

#: Any one-character box. P-010 counts every one of these as a criterion (T-5181): before,
#: `\[[ x]\]` ignored `[~]` and every other character, so rewriting an open box hid it.
#: Leading and inner whitespace is ASCII only (T-5181 review 2, #1): Python's `\s` also matches
#: \x1c-\x1f and U+0085, which grep's `\s` does not, so a box Python counted could be invisible
#: to the shell's `grep -cE '^\s*-\s*\[.\]'` and one accepted miss could cancel an open box.
#: ASCII space/tab/VT/FF/CR is a subset of grep's [[:space:]] in every locale, so every box this
#: parser sees, the shell counts too.
_WS = r"[ \t\v\f\r]"
BOX_RE = re.compile(rf"^(?P<indent>{_WS}*)-{_WS}*\[(?P<state>.)\]{_WS}*(?P<body>.*?){_WS}*$")
#: The shell gate strips inline comments per line before counting (update-task.sh, T-1967/T-2554);
#: accept must digest the same text the gate does (T-5181 review 2, #2).
_INLINE_COMMENT_RE = re.compile(r"<!--(?:[^-]|-[^-]|--[^>])*-->")
SUBHEAD_RE = re.compile(r"^### (.*)$")
AC_HEADING_RE = re.compile(r"^## Acceptance Criteria[ \t]*$")
ANNOTATION_RE = re.compile(r"^\s*\*\*Accepted miss:\*\*\s*(AM-[0-9a-f]{8})\b\s*(?:—|-)?\s*(.*)$")
#: Lines that never enter the digest: our own annotation and the agent's proposal.
PROPOSED_RE = re.compile(r"^\s*\*\*Miss proposed:\*\*")
#: `id:` frontmatter line, and the T-NNNN prefix of a task file's basename.
_ID_LINE_RE = re.compile(r"(?m)^id:\s*(T-\d+)\s*$")
_NAME_ID_RE = re.compile(r"(T-\d+)(?=[-.])")


@dataclass
class Box:
    """One checkbox line under `## Acceptance Criteria` with its continuation lines."""
    subhead: str
    state: str
    title: str
    start: int
    lines: list[str] = field(default_factory=list)
    index: int = 0            # 1-based within the gated (Agent) list; 0 when not gated

    @property
    def is_human(self) -> bool:
        return self.subhead.lower().startswith("human")

    def annotation(self) -> tuple[str, str] | None:
        """The annotation is the line DIRECTLY under the title, and only that one."""
        m = ANNOTATION_RE.match(self.lines[1]) if len(self.lines) > 1 else None
        return (m.group(1), m.group(2).strip()) if m else None


class _Crit:
    """Duck-typed stand-in for lib.delegation.Criterion: what criterion_digest reads."""

    def __init__(self, title: str, lines: list[str]):
        self.title = title
        self.lines = lines


def digest(box: Box) -> str:
    """verdict_ledger.criterion_digest over the box, minus the annotation (the line directly
    under the title, when it is one) and any `**Miss proposed:**` line. Every other
    `**Accepted miss:**` line is criterion text and inside the digest (T-5181 review #7)."""
    rest = box.lines[1:]
    if rest and ANNOTATION_RE.match(rest[0]):
        rest = rest[1:]
    lines = [box.lines[0]] + [ln for ln in rest if not PROPOSED_RE.match(ln)]
    return _vl_criterion_digest(_Crit(box.title, lines))


def parse(text: str) -> list[Box]:
    """Every box under the FIRST `## Acceptance Criteria`, comments stripped.

    Line indices refer to the comment-stripped text; use `locate` to edit the raw file."""
    text = "\n".join(_INLINE_COMMENT_RE.sub("", ln) for ln in (text or "").split("\n"))
    lines = strip_html_comment_lines(text).split("\n")
    start = next((i + 1 for i, ln in enumerate(lines) if AC_HEADING_RE.match(ln)), -1)
    if start < 0:
        return []
    end = next((j for j in range(start, len(lines)) if lines[j].startswith("## ")), len(lines))
    return _boxes(lines, start, end, "")


def parse_counted(text: str, subhead: str = "") -> list[Box]:
    """Every box in `text` EXACTLY as given — the text a shell gate already counted, after its
    own comment strip. No stripping and no section search here: a box this sees is a box the
    caller counted, so a miss can never resolve a box the caller did not count (T-5181 #2)."""
    lines = text.split("\n")
    return _boxes(lines, 0, len(lines), subhead)


def _boxes(lines: list[str], start: int, end: int, subhead: str) -> list[Box]:
    out: list[Box] = []
    cur: Box | None = None

    def close(at: int) -> None:
        nonlocal cur
        if cur is not None:
            cur.lines = lines[cur.start:at]
            out.append(cur)
            cur = None

    for i in range(start, end):
        ln = lines[i]
        sh = SUBHEAD_RE.match(ln)
        if sh:
            close(i)
            subhead = sh.group(1).strip()
            continue
        m = BOX_RE.match(ln)
        if m:
            close(i)
            cur = Box(subhead=subhead, state=m.group("state"), title=m.group("body"), start=i)
    close(end)
    return out


def gated(boxes: list[Box]) -> list[Box]:
    """The criteria P-010 gates on: `### Agent…` ones when the section has an Agent subhead,
    otherwise every box (P-010's un-split mode). Numbered 1-based."""
    has_agent = any(b.subhead.startswith("Agent") for b in boxes)
    sel = [b for b in boxes if b.subhead.startswith("Agent")] if has_agent else list(boxes)
    for n, b in enumerate(sel, 1):
        b.index = n
    return sel


def _jsonl(path: Path) -> list[dict]:
    out: list[dict] = []
    if not path.is_file():
        return out
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            r = json.loads(line)
        except json.JSONDecodeError:
            continue
        if isinstance(r, dict):
            out.append(r)
    return out


def ledger_rows(root: Path) -> list[dict]:
    return _jsonl(root / LEDGER)


def _task_id_of(path: Path, text: str) -> tuple[str, str]:
    """(task id, '') when the `id:` line and the file name's T-NNNN prefix agree, else
    ('', why). Rows are keyed by task id; taking it from `id:` alone let a file whose id was
    changed to another task's reuse that task's rows (T-5181 review #3)."""
    m = _ID_LINE_RE.search(text)
    n = _NAME_ID_RE.match(path.name)
    if not m:
        return "", f"{path.name} has no `id: T-NNNN` line"
    if not n:
        return "", f"{path.name} does not start with a T-NNNN id"
    if m.group(1) != n.group(1):
        return "", f"id: {m.group(1)} does not match the file name {path.name}"
    return m.group(1), ""


def judge(boxes: list[Box], task_id: str, rows: list[dict],
          id_why: str = "") -> list[tuple[Box, str, dict | None]]:
    """For every non-met gated box: (box, why-not-resolved or '', matching row).

    why == '' means a valid accepted miss. One ledger row resolves one box. task_id == ''
    (the file's identity did not verify, `id_why` says why) resolves nothing."""
    by_id = {r.get("id"): r for r in rows if task_id and r.get("task") == task_id and r.get("id")}
    used: set[str] = set()
    out: list[tuple[Box, str, dict | None]] = []
    for b in boxes:
        if b.state in "xX":
            continue
        if b.state == " ":
            out.append((b, "open", None))
            continue
        if b.state != "~":
            out.append((b, f"unknown box state [{b.state}] — counts as unchecked", None))
            continue
        if b.is_human:
            out.append((b, "[~] on a Human criterion — accepted misses are Agent-only", None))
            continue
        ann = b.annotation()
        if not ann:
            out.append((b, "[~] without an **Accepted miss:** annotation — counts as unchecked", None))
            continue
        if not task_id:
            out.append((b, f"[~] cannot resolve: {id_why or 'task id unknown'}", None))
            continue
        row = by_id.get(ann[0])
        if row is None:
            out.append((b, f"[~] cites {ann[0]} but {LEDGER} has no such row for {task_id}", None))
            continue
        if row.get("by") == "agent-override":
            out.append((b, f"[~] {ann[0]} was recorded under agent control (by: agent-override) "
                           f"and never resolves a criterion — accepting a miss is the operator's", row))
            continue
        if row.get("digest") != digest(b):
            out.append((b, f"[~] {ann[0]} is stale — the criterion was edited after acceptance", row))
            continue
        if ann[0] in used:
            out.append((b, f"[~] {ann[0]} already resolves another criterion", row))
            continue
        used.add(ann[0])
        out.append((b, "", row))
    return out


def valid_misses(root: Path, task_text: str, task_id: str) -> list[tuple[int, str, str, str]]:
    """(ac_n, id, title, reason) for every gated `[~]` backed by a matching ledger row."""
    res = judge(gated(parse(task_text)), task_id, ledger_rows(root))
    return [(b.index, row["id"], b.title, str(row.get("reason", "")))
            for b, why, row in res if not why and row]


def _root_for(task_file: Path) -> Path:
    env = os.environ.get("PROJECT_ROOT")
    p = task_file.resolve()
    if p.parent.parent.name == ".tasks":
        return p.parent.parent.parent
    return Path(env) if env else Path.cwd()


def _project_root() -> Path:
    env = os.environ.get("PROJECT_ROOT")
    if env:
        return Path(env)
    r = subprocess.run(["git", "rev-parse", "--show-toplevel"], capture_output=True, text=True)
    return Path(r.stdout.strip()) if r.returncode == 0 and r.stdout.strip() else Path.cwd()


def _find_task(root: Path, task_id: str) -> Path | None:
    for sub in ("active", "completed"):
        d = root / ".tasks" / sub
        hits = sorted(d.glob(f"{task_id}-*.md")) + sorted(d.glob(f"{task_id}.md"))
        if hits:
            return hits[0]
    return None


def _raw_index(raw_lines: list[str], stripped_line_no: int) -> int:
    """Map a line number in the comment-stripped text back to the raw text (same rule as
    comment_strip.strip_html_comment_lines)."""
    keep: list[int] = []
    in_comment = False
    for i, line in enumerate(raw_lines):
        line = _INLINE_COMMENT_RE.sub("", line)  # same pre-pass as parse()
        s = line.lstrip()
        if in_comment:
            if "-->" in line:
                in_comment = False
            continue
        if s.startswith("<!--"):
            if "-->" not in s[4:]:
                in_comment = True
            continue
        keep.append(i)
    return keep[stripped_line_no]


def accept(root: Path, task: str, ac_n: int, reason: str, by: str) -> dict:
    """Accept Agent criterion `ac_n` of `task` as missed. ValueError names the refusal."""
    if not (reason or "").strip():
        raise ValueError("--reason is required: the operator's reason for accepting the miss")
    path = _find_task(root, task)
    if path is None:
        raise ValueError(f"no task file for {task} under .tasks/active or .tasks/completed")
    if path.parent.name != "active":
        raise ValueError(f"{task} is already completed; an accepted miss applies to an open task")
    text = path.read_text(encoding="utf-8")
    boxes = parse(text)
    sel = gated(boxes)
    agent = [b for b in sel if not b.is_human]
    has_human = any(b.is_human for b in boxes)
    box = next((b for b in agent if b.index == ac_n), None)
    if box is None:
        if 1 <= ac_n <= len(sel):
            raise ValueError(f"{task} criterion #{ac_n} is a Human criterion — accepted misses "
                             f"apply to Agent criteria only")
        tail = " (Human criteria cannot be accepted as misses)" if has_human else ""
        raise ValueError(f"{task} has no Agent criterion #{ac_n} — it has {len(agent)}{tail}")
    if box.state in "xX":
        raise ValueError(f"{task} Agent criterion #{ac_n} is already met ([{box.state}]) — "
                         f"an accepted miss is for a criterion that was not met")
    if box.state == "~":
        res = judge([box], task, ledger_rows(root))
        if res and not res[0][1] and res[0][2]:
            raise ValueError(f"{task} Agent criterion #{ac_n} is already an accepted miss "
                             f"({res[0][2]['id']})")
    if box.state not in " ~":
        raise ValueError(f"{task} Agent criterion #{ac_n} has box [{box.state}]; reset it to "
                         f"[ ] first")
    d = digest(box)
    ts = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    am_id = "AM-" + hashlib.sha256(f"{ts}\n{task}\n{ac_n}\n{d}\n{reason}".encode()).hexdigest()[:8]
    reason1 = " ".join(reason.split())

    raw = text.split("\n")
    i = _raw_index(raw, box.start)
    m = BOX_RE.match(raw[i])
    if not m:
        raise ValueError(f"could not locate criterion #{ac_n} in {path.name}")
    raw[i] = re.sub(r"\[.\]", "[~]", raw[i], count=1)
    # Replace a previous (stale/void) annotation — only the one directly under the title, the
    # line digest() excludes; any other such line is criterion text and stays.
    j = i + 1
    if j < len(raw) and ANNOTATION_RE.match(raw[j]):
        del raw[j]
    raw.insert(j,f"{m.group('indent')}  **Accepted miss:** {am_id} — {reason1}")
    row = {"ts": ts, "id": am_id, "task": task, "ac": ac_n, "digest": d,
           "title": box.title, "reason": reason1, "by": by}
    p = root / LEDGER
    p.parent.mkdir(parents=True, exist_ok=True)
    with p.open("a", encoding="utf-8") as f:
        f.write(json.dumps(row, sort_keys=True) + "\n")
    path.write_text("\n".join(raw), encoding="utf-8")
    return row


# ── Audit ────────────────────────────────────────────────────────────────────

def _git(root: Path, *args: str) -> tuple[int, str]:
    r = subprocess.run(["git", "-C", str(root), *args], capture_output=True, text=True)
    return r.returncode, r.stdout


#: Where this module lives in a repo: the framework itself, and a vendored consumer.
_MODULE_PATHS = ("lib/accepted_miss.py", ".agentic-framework/lib/accepted_miss.py")


def legacy_boxes(root: Path) -> set[tuple[str, str]]:
    """(task file name, box line) pairs that already existed before this module was committed.

    Forward-looking, like human_ac_ticks: a `[~]` written before accepted misses existed
    (one in this repo — T-2535's DESCOPED line) had no ledger to cite. When the module is not
    committed in this repository (fixtures, fresh consumers) nothing is grandfathered."""
    rc, out = _git(root, "log", "--diff-filter=A", "--format=%H", "HEAD", "--", *_MODULE_PATHS)
    shas = out.split() if rc == 0 else []
    if not shas:
        return set()
    base = shas[-1] + "^"
    if _git(root, "rev-parse", "-q", "--verify", base + "^{commit}")[0] != 0:
        return set()   # the module arrived in the root commit: nothing predates it
    legacy: set[tuple[str, str]] = set()
    for name in _files_with_tilde(root, base):
        rc, text = _git(root, "show", f"{base}:{name}")
        if rc == 0 and "[~]" in text:
            legacy |= {(Path(name).name, b.lines[0].strip()) for b in parse(text) if b.state == "~"}
    return legacy


def _files_with_tilde(root: Path, rev: str) -> list[str]:
    """Task files at `rev` containing a literal `[~]` anywhere — a superset of the files with
    a `[~]` box. One `git grep` instead of a `git show` per task file (T-5181 review #5)."""
    r = subprocess.run(["git", "-C", str(root), "grep", "-l", "-F", "[~]", rev, "--",
                        ".tasks/active", ".tasks/completed"], capture_output=True, text=True)
    if r.returncode == 1:          # no match
        return []
    if r.returncode != 0:
        raise RuntimeError(f"git grep failed at {rev}: {r.stderr.strip()[:200]}")
    pre = rev + ":"
    return [ln[len(pre):] if ln.startswith(pre) else ln for ln in r.stdout.splitlines()]


def audit(root: Path) -> tuple[int, list[str]]:
    """FAIL on a committed `[~]` with no matching row, and on a non-append-only ledger."""
    rc, _ = _git(root, "rev-parse", "-q", "--verify", "HEAD")
    if rc != 0:
        return 0, ["accepted misses: no committed history — nothing to judge"]
    findings: list[str] = []
    legacy = legacy_boxes(root)
    n_legacy = 0
    fault = _vl_history_fault(root, Path(LEDGER))
    if fault:
        findings.append(f"FAIL ledger {LEDGER}: {fault}")
    rc, blob = _git(root, "show", f"HEAD:{LEDGER}")
    rows = [json.loads(ln) for ln in blob.splitlines() if ln.strip().startswith("{")] if rc == 0 else []
    try:
        names = _files_with_tilde(root, "HEAD")
    except RuntimeError as e:
        return 3, [f"accepted misses: {e} — committed tasks UNVERIFIED"]
    n_valid = 0
    for name in names:
        if not name.endswith(".md"):
            continue
        rc, text = _git(root, "show", f"HEAD:{name}")
        if rc != 0:
            return 3, [f"accepted misses: git show HEAD:{name} failed — UNVERIFIED"]
        boxes = parse(text)
        if not any(b.state == "~" for b in boxes):
            continue
        tid, id_why = _task_id_of(Path(name), text)
        tid_label = tid or Path(name).name
        sel = gated(boxes)
        for b, why, _ in judge(sel, tid, rows, id_why):
            if b.state != "~":
                continue
            if why and (Path(name).name, b.lines[0].strip()) in legacy:
                n_legacy += 1
            elif why:
                findings.append(f"FAIL {tid_label} criterion #{b.index}: {why} — {b.title[:80]}")
            else:
                n_valid += 1
        for b in boxes:
            if b.state == "~" and b not in sel and \
                    (Path(name).name, b.lines[0].strip()) not in legacy:
                findings.append(f"FAIL {tid_label}: [~] outside the gated Agent criteria — {b.title[:80]}")
    if findings:
        return 2, findings + [f"{len(findings)} accepted-miss finding(s)"]
    tail = f" ({n_legacy} pre-T-5181 [~] grandfathered)" if n_legacy else ""
    return 0, [f"accepted misses: {n_valid} committed, all backed by {LEDGER}; ledger "
               f"append-only{tail}"]


# ── CLI ──────────────────────────────────────────────────────────────────────

def _under_agent_control() -> bool:
    return os.environ.get("CLAUDECODE") == "1" or bool(os.environ.get("AI_AGENT", "").strip())


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(prog="accepted_miss")
    sub = ap.add_subparsers(dest="cmd", required=True)
    a = sub.add_parser("accept", help="operator: accept Agent criterion N of a task as missed")
    a.add_argument("task_id")
    a.add_argument("--ac", type=int, required=True, help="Agent criterion number (1-based)")
    a.add_argument("--reason", required=True)
    a.add_argument("--i-am-human", action="store_true",
                   help="accepted for compatibility; it does not lift the agent-control refusal")
    g = sub.add_parser("gate", help="P-010 helper: MISS/BAD lines for the gated criteria")
    g.add_argument("task_file")
    g.add_argument("--stdin", action="store_true",
                   help="judge only the boxes in the text on stdin — the text the caller counted")
    g.add_argument("--agent", action="store_true",
                   help="with --stdin: the text is the ### Agent block, heading already removed")
    li = sub.add_parser("list", help="accepted misses of a task file")
    li.add_argument("task_file")
    li.add_argument("--yaml", action="store_true", help="episodic YAML list items")
    sub.add_parser("audit", help="FAIL on unbacked committed [~] and on ledger rewrites")
    args = ap.parse_args(argv)

    if args.cmd == "audit":
        try:
            rc, lines = audit(_project_root())
        except Exception as e:  # noqa: BLE001 — could not run is its own exit code
            print(f"accepted misses: audit could not run: {e}")
            return 3
        print("\n".join(lines))
        return rc

    if args.cmd in ("gate", "list"):
        path = Path(args.task_file)
        # Lenient: box parsing needs no strict decode, and a bad byte elsewhere in the file is
        # the verification extractor's refusal to raise (T-3232), not this gate's.
        text = path.read_text(encoding="utf-8", errors="replace")
        root = _root_for(path)
        tid, id_why = _task_id_of(path, text)
        if args.cmd == "gate" and args.stdin:
            boxes = parse_counted(sys.stdin.read(), "Agent" if args.agent else "")
            gated(boxes)  # numbering only: Agent boxes when present, else every box
            res = judge(boxes, tid, ledger_rows(root), id_why)
        else:
            res = judge(gated(parse(text)), tid, ledger_rows(root), id_why)
        if args.cmd == "gate":
            for b, why, row in res:
                if not why and row:
                    print(f"MISS\t{b.index}\t{row['id']}\t{b.title}\t{row.get('reason', '')}")
                elif why != "open":
                    print(f"BAD\t{b.index}\t{why}\t{b.lines[0].strip()}")
            return 0
        for b, why, row in res:
            if why or not row:
                continue
            if args.yaml:
                q = lambda s: "'" + str(s).replace("'", "''") + "'"  # noqa: E731
                print(f"  - id: {q(row['id'])}\n    criterion: {q(b.title)}\n"
                      f"    reason: {q(row.get('reason', ''))}")
            else:
                print(f"{row['id']}  #{b.index} {b.title} — {row.get('reason', '')}")
        return 0

    if _under_agent_control():
        # T-5181 review #1: --i-am-human does not open this door (as T-5180's `widen`).
        print("REFUSED: accepting a missed criterion is the operator's act and is never recorded "
              "under agent control (CLAUDECODE/AI_AGENT set; --i-am-human does not apply). "
              "Propose it instead: add `**Miss proposed:** <why, with evidence>` under the "
              f"criterion, and hand the task over with: fw task review {args.task_id}",
              file=sys.stderr)
        return 2
    by = os.environ.get("USER") or "operator"
    try:
        row = accept(_project_root(), args.task_id, args.ac, args.reason, by)
    except ValueError as e:
        print(f"REFUSED: {e}", file=sys.stderr)
        return 1
    print(f"accepted miss {row['id']} for {args.task_id} Agent AC#{args.ac} in {LEDGER}\n"
          f"  It resolves the criterion for P-010 and is never counted as met. Commit the task "
          f"file and the ledger together.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
