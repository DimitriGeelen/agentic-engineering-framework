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

Exit codes of `audit`: 0 clean, 2 at least one unprovenanced tick, 3 could not run,
4 not evaluated — no commit exists (no repository, or unborn HEAD with no refs), so there
is no committed history (T-3728: fixture and fresh projects; a repo whose history cannot
be read is still 3).
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


_GENERATED_RE = re.compile(r"^\s*\*\*Reviewer (verdict|escalation)\b")


def boxes(section: str) -> list[tuple[str, bool, str]]:
    """[(key, ticked, verdict id cited by a green annotation or "")], HTML comments stripped.

    The KEY is the criterion's title AND its body (Steps/Expected/If-not lines, minus the
    generated verdict annotations): two criteria that share a title are different
    criteria, so a tick cannot be moved from one to the other unseen (review round 3)."""
    lines = strip_html_comment_lines(section).split("\n")
    out = []
    for i, line in enumerate(lines):
        m = BOX_RE.match(line)
        if not m:
            continue
        ann, body = "", []
        for nxt in lines[i + 1:]:
            if BOX_RE.match(nxt) or nxt.startswith("#"):
                break
            v = VERDICT_RE.search(nxt)
            if v and not ann:
                ann = v.group(1)
            if nxt.strip() and not _GENERATED_RE.match(nxt):
                body.append(nxt.strip())
        key = criterion_key(m.group(2)) + ("\n" + "\n".join(body) if body else "")
        out.append((key, m.group(1) in "xX", ann))
    return out


def record_ticked(root: Path, task_id: str, text: str, titles: list[str], via: str, by: str) -> int:
    """Record provenance for Human boxes a framework verb just ticked, by title.

    The ledger key is the full criterion key (title + body, see `boxes`); callers that
    only know the line they ticked pass its title. Each title occurrence records one
    ticked box with that title (duplicates are matched in order)."""
    used: set[int] = set()
    n = 0
    bx = boxes(_human_section(text))
    for title in titles:
        t = criterion_key(title)
        for i, (k, ticked, _) in enumerate(bx):
            if i not in used and ticked and k.split("\n", 1)[0] == t:
                used.add(i)
                record(root, task_id, k, via, by)
                n += 1
                break
    return n


def _jsonl(root: Path, rel: str) -> list[dict]:
    p = root / rel
    out = []
    if p.exists():
        for line in p.read_text(encoding="utf-8", errors="replace").splitlines():
            try:
                r = json.loads(line)
            except (json.JSONDecodeError, ValueError):
                continue
            if isinstance(r, dict):
                out.append(r)
    return out


def _criterion_digests(text: str, n_boxes: int) -> list[set[str]]:
    """Per Human box (in order): the verdict_ledger.criterion_digest(s) it may carry.

    Positional when verdict_ledger parses the same number of Human criteria as `boxes`
    does (the normal case); otherwise every digest of a same-titled criterion (looser,
    still never a digest of a differently titled one). Empty when the validator cannot
    be loaded — no validator, no exemption (fail closed)."""
    try:
        if str(Path(__file__).resolve().parent.parent) not in sys.path:
            sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
        import verdict_ledger as _vl  # noqa: PLC0415 — heavy; only when an annotation is seen
        crits = list(_vl.human_criteria(text))
        digs = [(criterion_key(c.title), _vl.criterion_digest(c)) for c in crits]
    except Exception:  # noqa: BLE001
        return [set() for _ in range(n_boxes)]
    if len(digs) == n_boxes:
        return [{d} for _, d in digs]
    titles = [k.split("\n", 1)[0] for k, _, _ in boxes(_human_section(text))]
    return [{d for t2, d in digs if t2 == t} for t in titles]


class VerdictBacking:
    """Which verdict annotations may exempt a tick on one task.

    An annotation is text anyone can write. It exempts a tick only when (review rounds 1-2)
      * `verdicts.jsonl` has the cited id as a GREEN row for this task,
      * that row's `ac_digest` equals verdict_ledger.criterion_digest of THE criterion the
        annotation sits under (no reuse of A's verdict on B), and
      * `applied.jsonl` records verdict_ledger.apply ticking it — ONE applied tick event
        licenses ONE tick (no replay after an un-tick); `consume` spends it.
    Whether the verdict row is itself genuine (signed review dispatch, non-producer commit)
    is `verdict_ledger.py audit`'s FAIL to raise."""

    def __init__(self, root: Path, task_id: str):
        self.digest = {str(r["id"]): str(r.get("ac_digest") or "")
                       for r in _jsonl(root, ".context/reviews/verdicts.jsonl")
                       if r.get("task") == task_id and r.get("outcome") == "green" and r.get("id")}
        self.budget = Counter()
        for r in _jsonl(root, ".context/reviews/applied.jsonl"):
            if r.get("task") == task_id:
                for t in r.get("ticked") or []:
                    if isinstance(t, dict) and t.get("verdict_id"):
                        self.budget[str(t["verdict_id"])] += 1

    def bound(self, vid: str, digests: set[str]) -> bool:
        return bool(vid) and bool(self.digest.get(vid)) and self.digest[vid] in digests

    def consume(self, vid: str) -> bool:
        if self.budget[vid] > 0:
            self.budget[vid] -= 1
            return True
        return False


def unprovenanced_ticks(old: str, new: str, backing: "VerdictBacking | None" = None
                        ) -> list[tuple[str, str, str]]:
    """[(criterion key, kind, verdict id or "")] for ticks in `new` that `old` did not have.

    kind: "ticked" (was [ ] under Human), "added-ticked" (new under Human, already [x]),
    "moved-ticked" (left Human unticked, reappears ticked elsewhere in the file).
    The third field names a verdict BOUND to this criterion (see VerdictBacking) — the
    caller still has to `consume` an applied tick event for it to count.
    """
    def title(k: str) -> str:
        return k.split("\n", 1)[0]

    oh, nh = boxes(_human_section(old)), boxes(_human_section(new))
    old_ticked = Counter(k for k, t, _ in oh if t)
    old_open = Counter(k for k, t, _ in oh if not t)
    old_open_titles = Counter(title(k) for k in old_open.elements())
    annotated = backing is not None and any(t and a for _, t, a in nh)
    digests = _criterion_digests(new, len(nh)) if annotated else [set() for _ in nh]
    # 1. a tick the old text already had, on the SAME criterion (title + body), is not new
    def ordinals(bx):  # position of each box among the boxes sharing its title
        seen: Counter = Counter()
        out_ = []
        for k, _, _ in bx:
            out_.append(seen[title(k)])
            seen[title(k)] += 1
        return out_

    n_ord, o_ord = ordinals(nh), ordinals(oh)
    leftover: list[tuple[str, str, int]] = []
    remaining = Counter(old_ticked)
    for idx, (k, t, a) in enumerate(nh):
        if not t:
            continue
        if remaining[k] > 0:
            remaining[k] -= 1
            continue
        leftover.append((k, a if backing and backing.bound(a, digests[idx]) else "", n_ord[idx]))
    # 2. ...nor is one whose criterion only had its BODY edited: an old ticked criterion
    #    whose key no longer exists in the new text pairs with a new tick of the same title
    #    AT THE SAME POSITION among same-titled criteria. Moving a tick onto a sibling
    #    that shares the title is a new tick (review round 3).
    new_all = Counter(k for k, _, _ in nh)
    orphans = {(title(k), o_ord[i]) for i, (k, t, _) in enumerate(oh) if t and new_all[k] == 0}
    out = []
    for k, vid, o in leftover:
        if not vid and (title(k), o) in orphans:
            orphans.discard((title(k), o))
            continue
        kind = "ticked" if (old_open[k] or old_open_titles[title(k)]) else "added-ticked"
        out.append((k, kind, vid))
    new_human_keys = Counter(k for k, _, _ in nh)
    elsewhere = Counter(k for k, t, _ in boxes(new) if t) - Counter(k for k, t, _ in nh if t)
    for k, n in old_open.items():
        gone = n - new_human_keys[k]
        if gone > 0 and elsewhere[k] > 0:
            out.append((k, "moved-ticked", ""))
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
    # check=True: an unreadable blob is an audit that could not run (rc 3), never "no ticks"
    return subprocess.run(["git", "-C", str(root), "show", f"{rev}:{path}"], capture_output=True,
                          check=True, encoding="utf-8", errors="replace").stdout


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
            # -z: NUL-separated, never C-quoted — a non-ASCII filename is otherwise printed
            # as "...caf\303\251.md" and silently skipped (review round 3)
            args = ["diff-tree", "-r", "-M", "-z", "--no-commit-id", "--name-status"]
            args += [parent, sha] if parent else ["--root", sha]
            got: dict = {}
            fields = _git(root, *args, "--", ".tasks").split("\0")
            j = 0
            while j < len(fields) - 1:
                status = fields[j]
                if not status:
                    j += 1
                    continue
                if status[0] in "RC":
                    old_path, new_path = fields[j + 1], fields[j + 2]
                    j += 3
                else:
                    old_path = new_path = fields[j + 1]
                    j += 2
                if status.startswith("D"):
                    continue
                if not new_path.endswith(".md") or not re.search(r"(^|/)T-\d+", os.path.basename(new_path)):
                    continue
                old = "" if (status.startswith("A") or not parent) else _blob(root, parent, old_path)
                tid = _task_id(new_path)
                backing = checkers.setdefault(tid, VerdictBacking(root, tid))
                got[new_path] = (tid, unprovenanced_ticks(old, _blob(root, sha, new_path), backing))
            per_parent.append(got)
        # a tick is NEW in this commit only if it is new relative to EVERY parent; a tick
        # inherited from a merged branch was judged in that branch's own commit
        paths = set(per_parent[0])
        for got in per_parent[1:]:
            paths &= set(got)
        for path in sorted(paths):
            tid, first = per_parent[0][path]
            keys = Counter(k for k, _, _ in first)
            for got in per_parent[1:]:
                keys &= Counter(k for k, _, _ in got[path][1])  # kinds may differ per parent
            for key, kind, vid in first:
                if keys[key] <= 0:
                    continue
                keys[key] -= 1
                if vid and checkers[tid].consume(vid):
                    continue  # a bound verdict with an unspent applied tick event
                d = key_digest(tid, key)
                if budget[d] > 0:
                    budget[d] -= 1
                    continue
                findings.append({"commit": sha, "who": who, "agent": agent, "task": tid,
                                 "path": path, "kind": kind if not vid else kind + " (verdict replayed)",
                                 "criterion": key[:100], "merge": len(parents) > 1})
    return findings, where


def _no_history(root: Path) -> str | None:
    """Why no commit can exist to audit, or None. Only two states qualify (T-3728):
    no repository at all (no `.git` at the root AND git agrees), or a repository with an
    unborn HEAD and not a single ref (fresh `git init`; also a fixture dir nested in an
    empty enclosing repo). Anything else that fails to read is a broken repo: rc 3."""
    def run(*args: str) -> subprocess.CompletedProcess:
        return subprocess.run(["git", "-C", str(root), *args], capture_output=True, text=True)
    try:
        if run("rev-parse", "--is-inside-work-tree").returncode != 0:
            return None if (root / ".git").exists() else "not a git repository"
        if run("rev-parse", "--verify", "-q", "HEAD").returncode == 0:
            return None
        refs = run("for-each-ref", "--count=1")
        if refs.returncode == 0 and not refs.stdout.strip():
            return "git repository has no commits"
    except OSError:
        pass  # no git binary: could not run (rc 3), not "no history"
    return None


def audit(root: Path, since: str | None = None) -> tuple[int, list[str]]:
    why = _no_history(root)
    if why:
        return 4, [f"{why} — no committed history to audit"]
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
