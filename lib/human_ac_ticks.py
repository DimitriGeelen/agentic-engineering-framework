#!/usr/bin/env python3
"""human_ac_ticks — provenance ledger + post-hoc detector for `### Human` ticks (T-3695).

The PreToolUse guard (`check-human-ac-tick`, Write|Edit|Bash) refuses the text-visible
ways an agent can tick a `### Human` box. It cannot see a script file, a path built at run
time, or anything that never goes through a tool call (T-2742 scope boundary). This module
is the after-the-fact half: `fw audit` walks every commit since this detector landed (by
ancestry, see anchor_commit) that changed a task
file and FAILs on each Human box that went `[ ]` → `[x]` (or was ADDED ticked, or moved out
of `### Human` and ticked) without provenance.

PROVENANCE — a tick counts as the human's when either holds:
  1. the ledger `.context/reviews/human-ac-ticks.jsonl` has a row for (task, criterion
     text) — written by Watchtower's tick endpoint (follow-up task, render surface) or by
     the operator: `python3 lib/human_ac_ticks.py ack T-XXX --ac N` (refused under agent
     control unless --i-am-human);
  2. the criterion carries a `**Reviewer verdict:** green <id>` annotation whose id is a
     green row for this task in `.context/reviews/verdicts.jsonl` AND an applied tick in
     `applied.jsonl` (verdict_checker) — the T-3579 verdict path; whether that row is
     genuine is `lib/verdict_ledger.py audit`'s FAIL to raise.
One ledger row licenses ONE tick (consumed oldest-first), every `### Human` section is
read, and merge commits are judged against every parent.
Everything else FAILs. The FAIL line names the committing identity and says AGENT when it
is one (an `@aef.local` dispatch/reviewer identity, or a `Co-Authored-By: Claude` /
"Generated with Claude Code" trailer).

WHAT THIS DOES NOT CLAIM: every agent here runs as the same OS user as the operator. An
agent that writes a ledger row by a route the text gate cannot see (a script) and commits
it under a human identity is indistinguishable from the operator. The detector catches
accidents and unsophisticated bypasses — a `sed -i` tick committed by a session — not a
coherent forgery. Same residual as T-3581.

Exit codes of `audit`: 0 clean, 2 at least one unprovenanced tick, 3 could not run.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import subprocess
import sys
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from comment_strip import strip_html_comment_lines  # noqa: E402

LEDGER = ".context/reviews/human-ac-ticks.jsonl"
# Forward-looking (T-2232 pattern): history before the detector shipped is not re-judged —
# Watchtower ticks committed by sessions before the ledger existed have no row to find.
# The default range is ANCESTRY from the commit that added this file (anchor_commit); this
# date is only the fallback for a repo where the detector is not committed.
CUTOFF = "2026-10-02T00:00:00Z"

BOX_RE = re.compile(r"^\s*-\s*\[([ xX])\]\s*(.*)$")
VERDICT_RE = re.compile(r"\*\*Reviewer verdict:\*\*\s*green\s+(\S+)")
AGENT_TRAILER_RE = re.compile(
    r"(?im)^co-authored-by:.*(claude|anthropic)|generated with \[?claude code")


def _root() -> Path:
    return Path(os.environ.get("PROJECT_ROOT") or Path.cwd())


def criterion_key(text: str) -> str:
    return re.sub(r"\s+", " ", text).strip()


def key_digest(task_id: str, key: str) -> str:
    return hashlib.sha256(f"{task_id}\n{key}".encode()).hexdigest()[:24]


def _human_section(text: str) -> str:
    """EVERY `### Human` section, concatenated — a second one is not a hiding place
    (T-3695 review round 1: only the first was read)."""
    return "\n".join(m.group(0) for m in
                     re.finditer(r"(?ms)^### Human\b.*?(?=^### |^## [^A]|\Z)", text or ""))


def boxes(section: str) -> list[tuple[str, bool, str]]:
    """[(key, ticked, verdict id cited by a green annotation or "")], HTML comments stripped."""
    lines = strip_html_comment_lines(section).split("\n")
    out = []
    for i, line in enumerate(lines):
        m = BOX_RE.match(line)
        if not m:
            continue
        ann = ""
        for nxt in lines[i + 1:]:
            if BOX_RE.match(nxt) or nxt.startswith("#"):
                break
            v = VERDICT_RE.search(nxt)
            if v:
                ann = v.group(1)
                break
        out.append((criterion_key(m.group(2)), m.group(1) in "xX", ann))
    return out


def verdict_checker(root: Path, task_id: str):
    """A predicate: does verdict id `vid` back a tick on `task_id`?

    An annotation is text anyone can write (review round 1: a fabricated
    `**Reviewer verdict:** green` was exempt). It counts only when the reviewer-verdict
    ledger has that id as a green row for this task AND the applied ledger records
    verdict_ledger.apply ticking it. Whether that verdict row is itself genuine (signed
    review dispatch, non-producer commit) is `verdict_ledger.py audit`'s FAIL to raise."""
    greens, applied = set(), set()
    for rel, sink in ((".context/reviews/verdicts.jsonl", greens), (".context/reviews/applied.jsonl", applied)):
        p = root / rel
        if not p.exists():
            continue
        for line in p.read_text(encoding="utf-8", errors="replace").splitlines():
            try:
                r = json.loads(line)
            except (json.JSONDecodeError, ValueError):
                continue
            if not isinstance(r, dict) or r.get("task") != task_id:
                continue
            if sink is greens and r.get("outcome") == "green" and r.get("id"):
                greens.add(str(r["id"]))
            elif sink is applied:
                for t in r.get("ticked") or []:
                    if isinstance(t, dict) and t.get("verdict_id"):
                        applied.add(str(t["verdict_id"]))
    return lambda vid: bool(vid) and vid in greens and vid in applied


def unprovenanced_ticks(old: str, new: str, verdict_ok=lambda _vid: False) -> list[tuple[str, str]]:
    """[(criterion key, kind)] for ticks in `new` that `old` did not have.

    kind: "ticked" (was [ ] under Human), "added-ticked" (new under Human, already [x]),
    "moved-ticked" (left Human unticked, reappears ticked elsewhere in the file).
    A tick whose annotation cites a verdict `verdict_ok` accepts is excluded.
    """
    oh, nh = boxes(_human_section(old)), boxes(_human_section(new))
    old_ticked = Counter(k for k, t, _ in oh if t)
    old_open = Counter(k for k, t, _ in oh if not t)
    new_ticked = Counter(k for k, t, a in nh if t and not verdict_ok(a))
    new_ann = Counter(k for k, t, a in nh if t and verdict_ok(a))
    out = []
    for k, n in new_ticked.items():
        extra = n - max(0, old_ticked[k] - new_ann[k])
        for _ in range(max(0, extra)):
            out.append((k, "ticked" if old_open[k] else "added-ticked"))
    new_human_keys = Counter(k for k, _, _ in nh)
    elsewhere = Counter(k for k, t, _ in boxes(new) if t) - Counter(k for k, t, _ in nh if t)
    for k, n in old_open.items():
        gone = n - new_human_keys[k]
        if gone > 0 and elsewhere[k] > 0:
            out.append((k, "moved-ticked"))
    return out


# ── ledger ───────────────────────────────────────────────────────────────────

def ledger_rows(root: Path) -> list[dict]:
    p = root / LEDGER
    rows = []
    if not p.exists():
        return rows
    for line in p.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            rows.append(json.loads(line))
        except json.JSONDecodeError:
            continue
    return rows


def record(root: Path, task_id: str, key: str, via: str, by: str) -> dict:
    row = {"ts": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"), "task": task_id,
           "digest": key_digest(task_id, key), "criterion": key[:200], "via": via, "by": by}
    p = root / LEDGER
    p.parent.mkdir(parents=True, exist_ok=True)
    with p.open("a", encoding="utf-8") as f:
        f.write(json.dumps(row, sort_keys=True) + "\n")
    return row


def _under_agent_control() -> bool:
    return os.environ.get("CLAUDECODE") == "1" or bool(os.environ.get("AI_AGENT", "").strip())


# ── audit ────────────────────────────────────────────────────────────────────

def _git(root: Path, *args: str) -> str:
    return subprocess.run(["git", "-C", str(root), *args], capture_output=True, text=True,
                          check=True).stdout


def _blob(root: Path, rev: str, path: str) -> str:
    r = subprocess.run(["git", "-C", str(root), "show", f"{rev}:{path}"], capture_output=True,
                       text=True)
    return r.stdout if r.returncode == 0 else ""


def _task_id(path: str) -> str:
    m = re.search(r"T-\d+", os.path.basename(path))
    return m.group(0) if m else "?"


def is_agent_identity(author_email: str, committer_email: str, message: str) -> bool:
    return (author_email.endswith("@aef.local") or committer_email.endswith("@aef.local")
            or bool(AGENT_TRAILER_RE.search(message)))


DETECTOR_PATHS = ("lib/human_ac_ticks.py", ".agentic-framework/lib/human_ac_ticks.py")


def anchor_commit(root: Path) -> str | None:
    """The OLDEST commit that added this detector to the repo (framework or vendored copy).

    The default scan range is ANCESTRY from here (`anchor..HEAD`), not a date: `git log
    --since` trusts committer dates, so a tick committed with a backdated
    GIT_COMMITTER_DATE would fall outside a date window. Ancestry cannot be backdated.
    """
    out = _git(root, "log", "--diff-filter=A", "--format=%H", "HEAD", "--", *DETECTOR_PATHS).split()
    return out[-1] if out else None


def scan_commits(root: Path, since: str | None = None, rev: str = "HEAD") -> tuple[list[dict], str]:
    """(every unprovenanced Human tick in non-merge commits in range, range description).

    Range: `since` (a date) when given; else `<anchor>..rev`; else the CUTOFF date (a repo
    where the detector is not committed, e.g. an untracked vendored copy)."""
    if since:
        rng, where = [f"--since={since}", rev], since
    else:
        anchor = anchor_commit(root)
        if anchor:
            rng, where = [f"{anchor}..{rev}"], f"detector commit {anchor[:10]}"
        else:
            rng, where = [f"--since={CUTOFF}", rev], CUTOFF
    # Oldest first, merges INCLUDED (review round 1: a tick made while resolving a merge
    # appeared in no non-merge commit). Ledger rows are consumed in this order.
    log = _git(root, "log", "--topo-order", "--reverse",
               "--format=%x1e%H%x1f%P%x1f%an <%ae>%x1f%ae%x1f%ce%x1f%B", *rng)
    # One ledger row covers ONE tick (review round 1: a single `ack` used to license every
    # later re-tick of the same criterion text).
    budget = Counter(r.get("digest") for r in ledger_rows(root))
    checkers: dict = {}
    findings = []
    for rec in log.split("\x1e")[1:]:
        parts = rec.split("\x1f", 5)
        if len(parts) < 6:
            continue
        sha, parents, who, aemail, cemail, msg = parts
        parents = parents.split() or [None]
        agent = is_agent_identity(aemail, cemail, msg)
        per_parent: list[dict] = []
        for parent in parents:
            args = ["diff-tree", "-r", "-M", "--no-commit-id", "--name-status"]
            args += [parent, sha] if parent else ["--root", sha]
            got: dict = {}
            for fl in _git(root, *args, "--", ".tasks").splitlines():
                cols = fl.split("\t")
                status = cols[0]
                if status.startswith("D") or len(cols) < 2:
                    continue
                old_path, new_path = (cols[1], cols[2]) if status[0] in "RC" and len(cols) > 2 else (cols[1], cols[1])
                if not new_path.endswith(".md") or not re.search(r"(^|/)T-\d+", os.path.basename(new_path)):
                    continue
                old = "" if (status.startswith("A") or not parent) else _blob(root, parent, old_path)
                tid = _task_id(new_path)
                ok = checkers.setdefault(tid, verdict_checker(root, tid))
                got[new_path] = (tid, Counter(unprovenanced_ticks(old, _blob(root, sha, new_path), ok)))
            per_parent.append(got)
        # a tick is NEW in this commit only if it is new relative to EVERY parent; a tick
        # inherited from a merged branch was judged in that branch's own commit
        paths = set(per_parent[0])
        for got in per_parent[1:]:
            paths &= set(got)
        for path in sorted(paths):
            tid, first = per_parent[0][path]
            keys = Counter()
            for (key, _kind), n in first.items():
                keys[key] += n
            for got in per_parent[1:]:
                other = Counter()
                for (key, _kind), n in got[path][1].items():
                    other[key] += n
                keys &= other  # kinds may differ per parent; the KEY is what must be new
            kinds = {key: kind for (key, kind) in first}
            for key, n in sorted(keys.items()):
                kind = kinds.get(key, "ticked")
                for _ in range(n):
                    d = key_digest(tid, key)
                    if budget[d] > 0:
                        budget[d] -= 1
                        continue
                    findings.append({"commit": sha, "who": who, "agent": agent, "task": tid,
                                     "path": path, "kind": kind, "criterion": key[:100],
                                     "merge": len(parents) > 1})
    return findings, where


def audit(root: Path, since: str | None = None) -> tuple[int, list[str]]:
    try:
        findings, since = scan_commits(root, since)
    except (subprocess.CalledProcessError, OSError) as e:
        return 3, [f"could not read git history: {e}"]
    if not findings:
        return 0, [f"no unprovenanced ### Human ticks in commits since {since}"]
    lines = []
    for f in findings:
        lines.append(
            f"FAIL {f['task']} {f['kind']} in {'merge ' if f.get('merge') else ''}{f['commit'][:10]} by "
            f"{'AGENT ' if f['agent'] else ''}{f['who']}: \"{f['criterion']}\" — no Watchtower/"
            f"operator record and no reviewer verdict")
    lines.append(f"{len(findings)} unprovenanced ### Human tick(s) since {since}")
    return 2, lines


# ── CLI ──────────────────────────────────────────────────────────────────────

def _human_criterion(root: Path, task_id: str, n: int) -> str | None:
    for sub in ("active", "completed"):
        for p in sorted((root / ".tasks" / sub).glob(f"{task_id}-*.md")):
            bx = boxes(_human_section(p.read_text(encoding="utf-8")))
            if 1 <= n <= len(bx):
                return bx[n - 1][0]
    return None


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(prog="human_ac_ticks")
    sub = ap.add_subparsers(dest="cmd", required=True)
    a = sub.add_parser("audit", help="FAIL on unprovenanced ### Human ticks since the cutoff")
    a.add_argument("--since", default=None,
                   help="a date; default: ancestry from the commit that added this detector")
    k = sub.add_parser("ack", help="operator: record that YOU ticked Human criterion N")
    k.add_argument("task_id")
    k.add_argument("--ac", type=int, required=True, help="Human criterion number (1-based)")
    k.add_argument("--i-am-human", action="store_true")
    args = ap.parse_args(argv)
    root = _root()
    if args.cmd == "audit":
        rc, lines = audit(root, args.since)
        print("\n".join(lines))
        return rc
    if _under_agent_control() and not args.i_am_human:
        print("REFUSED: recording a Human tick is the operator's act (CLAUDECODE/AI_AGENT set). "
              "Hand the task over with: fw task review " + args.task_id, file=sys.stderr)
        return 2
    key = _human_criterion(root, args.task_id, args.ac)
    if key is None:
        print(f"{args.task_id} has no Human criterion #{args.ac}", file=sys.stderr)
        return 1
    by = "agent-override" if _under_agent_control() else (os.environ.get("USER") or "operator")
    row = record(root, args.task_id, key, "operator-ack", by)
    print(f"recorded {row['digest']} for {args.task_id} Human AC#{args.ac} in {LEDGER}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
