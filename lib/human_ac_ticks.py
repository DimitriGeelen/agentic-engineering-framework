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
     text) — written by Watchtower's toggle-ac endpoint (T-4070, via=watchtower) or by
     the operator: `python3 lib/human_ac_ticks.py ack T-XXX --ac N` (refused under agent
     control unless --i-am-human);
  2. the criterion carries a `**Reviewer verdict:** green <id>` annotation whose id is a
     green row for this task in `.context/reviews/verdicts.jsonl` AND an applied tick in
     `applied.jsonl` (verdict_checker) — the T-3579 verdict path; whether that row is
     genuine is `lib/verdict_ledger.py audit`'s FAIL to raise;
  3. a STANDING DELEGATION (T-4165, inception T-4158): the operator records once, in
     `.context/reviews/standing-delegations.jsonl` (`delegation grant`, refused under agent
     control unless --i-am-human), a criterion pattern, a scope (arc and/or task list), a
     condition pattern and an expiry. An agent tick counts when the criterion carries
     `**Delegated tick:** SD-xxxxxxxx verdict <id>` and: the grant is unrevoked, unexpired
     and older than the tick commit; the task is in scope; the ticked title matches the
     pattern; <id> is a GREEN verdict row for this task bound (ac_digest) to a DIFFERENT
     Human criterion whose title matches the condition; and the ticked criterion is not
     tier0-or-bypass / act-in-the-world (lib/delegation.py). One cite licenses one tick.
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
import dataclasses
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
DELEGATIONS = ".context/reviews/standing-delegations.jsonl"
DELEGATED_RE = re.compile(r"\*\*Delegated tick:\*\*\s*(SD-[0-9a-f]+)\s+verdict\s+(\S+)")
MAX_DELEGATION_DAYS = 366
# T-4158: the operator may delegate an approval, never an action they alone can take
NEVER_DELEGABLE = ("tier0-or-bypass", "act-in-the-world")
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


_GENERATED_RE = re.compile(r"^\s*\*\*(Reviewer (verdict|escalation)\b|Delegated tick:)")


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
    if not re.fullmatch(r"T-\d+", task_id or ""):
        raise ValueError(f"refusing to record provenance for task id {task_id!r}: a row with no "
                         "real task can never back a tick (T-4075)")
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


# ── standing delegation (T-4165) ─────────────────────────────────────────────

def delegation_cites(text: str) -> list[tuple[str, str, str]]:
    """[(criterion key, grant id, verdict id)] for Human boxes carrying a
    `**Delegated tick:**` annotation — same walk and same key as `boxes`."""
    lines = strip_html_comment_lines(_human_section(text)).split("\n")
    keys = [k for k, _, _ in boxes(_human_section(text))]
    out, n = [], -1
    for i, line in enumerate(lines):
        if not BOX_RE.match(line):
            continue
        n += 1
        for nxt in lines[i + 1:]:
            if BOX_RE.match(nxt) or nxt.startswith("#"):
                break
            d = DELEGATED_RE.search(nxt)
            if d:
                out.append((keys[n], d.group(1), d.group(2)))
                break
    return out


def delegation_grants(root: Path) -> dict[str, dict]:
    """{grant id: grant row + 'revoked' (ts or "")}; a revoke for an unknown id is ignored."""
    grants: dict[str, dict] = {}
    for r in _jsonl(root, DELEGATIONS):
        gid = str(r.get("id") or "")
        if r.get("kind") == "grant" and gid and gid not in grants:
            grants[gid] = dict(r, revoked="")
        elif r.get("kind") == "revoke" and gid in grants and not grants[gid]["revoked"]:
            grants[gid]["revoked"] = str(r.get("ts") or "")
    return grants


def _task_arcs(text: str) -> set[str]:
    m = re.match(r"(?s)---\n(.*?)\n---", text or "")
    fm = m.group(1) if m else ""
    arcs = set(re.findall(r"(?m)^arc_id:\s*['\"]?([\w.-]+)", fm))
    arcs |= set(re.findall(r"\barc:([\w.-]+)", " ".join(re.findall(r"(?m)^tags:.*$", fm))))
    return arcs


def _utc(ts: str) -> str:
    """Any ISO timestamp → `YYYY-MM-DDTHH:MM:SSZ` (UTC), so string comparison is ordering."""
    try:
        return datetime.fromisoformat(ts.replace("Z", "+00:00")).astimezone(
            timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    except (ValueError, AttributeError):
        return ""


def delegation_refusal(grant: dict | None, task_id: str, text: str, key: str, verdict_id: str,
                       verdict_digest: dict[str, str], commit_date: str) -> str:
    """"" when the standing delegation backs this tick, else why it does not."""
    if not grant:
        return "no such grant"
    when = _utc(commit_date)
    if not when:
        return "tick commit has no readable date"
    if _utc(str(grant.get("ts") or "")) > when or not _utc(str(grant.get("ts") or "")):
        return "tick predates the grant"
    if grant.get("revoked") and _utc(grant["revoked"]) <= when:
        return "grant revoked"
    if str(grant.get("expires") or "") < when[:10]:
        return "grant expired"
    in_tasks = task_id in (grant.get("tasks") or [])
    in_arc = bool(grant.get("arc")) and grant["arc"] in _task_arcs(text)
    if not (in_tasks or in_arc):
        return "task outside the grant's scope"
    title = key.split("\n", 1)[0]
    try:
        if not re.search(str(grant.get("pattern") or ""), title) or not grant.get("pattern"):
            return "criterion does not match the grant pattern"
        cond = re.compile(str(grant.get("condition") or ""))
    except re.error:
        return "grant pattern does not compile"
    digest = verdict_digest.get(verdict_id)
    if not digest:
        return f"{verdict_id} is not a green verdict for {task_id}"
    try:
        if str(Path(__file__).resolve().parent.parent) not in sys.path:
            sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
        import verdict_ledger as _vl  # noqa: PLC0415
        from lib.delegation import classify  # noqa: PLC0415
        crits = list(_vl.human_criteria(text))
    except Exception:  # noqa: BLE001 — no validator, no delegation (fail closed)
        return "verdict/classifier modules unavailable"
    bound = [c for c in crits if _vl.criterion_digest(c) == digest]
    if not any(criterion_key(c.title) != title and cond.search(c.title) and grant.get("condition")
               for c in bound):
        return f"{verdict_id} is not bound to a different criterion matching the condition"
    for c in crits:
        if criterion_key(c.title) == title:
            producer = [ln for ln in c.lines if not _GENERATED_RE.match(ln)]
            cls = classify(dataclasses.replace(c, lines=producer)).cls
            if cls in NEVER_DELEGABLE:
                return f"criterion class {cls} is never delegable"
    return ""


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


def record(root: Path, task_id: str, key: str, via: str, by: str,
           extra: dict | None = None) -> dict:
    if not re.fullmatch(r"T-\d+", task_id or ""):  # T-4075: never a '?' placeholder row
        raise ValueError(f"refusing to record provenance for task id {task_id!r}")
    row = {"ts": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"), "task": task_id,
           "digest": key_digest(task_id, key), "criterion": key[:200], "via": via, "by": by}
    row.update({k: v for k, v in (extra or {}).items() if k not in row})
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


class _BlobReader:
    """`git show REV:PATH` for many blobs through ONE `git cat-file --batch` (T-4375).

    The audit read ~5,000 blobs, one process each: ~57 s of the pre-push structure audit.
    Same bytes, same decoding, same failure (CalledProcessError -> rc 3) as _blob."""

    def __init__(self, root: Path):
        self.root = root
        self.proc = subprocess.Popen(["git", "-C", str(root), "cat-file", "--batch"],
                                     stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                     stderr=subprocess.DEVNULL)

    def show(self, rev: str, path: str) -> str:
        spec = f"{rev}:{path}"
        if "\n" in spec:
            return _blob(self.root, rev, path)
        self.proc.stdin.write(spec.encode() + b"\n")
        self.proc.stdin.flush()
        header = self.proc.stdout.readline()
        parts = header.split()
        if len(parts) != 3 or parts[1] != b"blob":
            raise subprocess.CalledProcessError(128, ["git", "show", spec], header)
        data = self.proc.stdout.read(int(parts[2]) + 1)[:-1]
        return data.decode("utf-8", errors="replace")

    def close(self) -> None:
        try:
            self.proc.stdin.close()
        except OSError:
            pass
        self.proc.wait()


def _diff_trees(root: Path, pairs: list[tuple[str, str | None]]) -> list[str]:
    """For each (sha, parent), the stdout of `git diff-tree -r -M -z --no-commit-id
    --name-status [parent sha | --root sha] -- .tasks`, from ONE `--stdin` run (T-4375).

    diff-tree echoes a stdin line that is not a commit, so a sentinel line before each
    pair splits the output back per pair, empty diffs included."""
    if not pairs:
        return []
    lines = []
    for i, (sha, parent) in enumerate(pairs):
        lines.append(f"#fw-t4375-{i}")
        lines.append(f"{sha} {parent}" if parent else sha)
    out = subprocess.run(["git", "-C", str(root), "diff-tree", "--stdin", "--root", "-r", "-M",
                          "-z", "--no-commit-id", "--name-status", "--", ".tasks"],
                         input="\n".join(lines) + "\n", capture_output=True, text=True,
                         check=True).stdout
    chunks = re.split(r"#fw-t4375-(\d+)\n", out)
    got = [""] * len(pairs)
    for k in range(1, len(chunks) - 1, 2):
        got[int(chunks[k])] = chunks[k + 1]
    return got


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


def committed_ledger_digests(root: Path, rev: str = "HEAD") -> Counter:
    """Digest counts of the ledger as committed at `rev` (T-4769). Only used to NAME a tick
    whose licence is an uncommitted row; the audit's budget is still the working tree."""
    p = subprocess.run(["git", "-C", str(root), "show", f"{rev}:{LEDGER}"], capture_output=True,
                       encoding="utf-8", errors="replace")
    out: Counter = Counter()
    for line in (p.stdout if p.returncode == 0 else "").splitlines():
        try:
            r = json.loads(line)
        except (json.JSONDecodeError, ValueError):
            continue
        if isinstance(r, dict):
            out[r.get("digest")] += 1
    return out


def scan_commits(root: Path, since: str | None = None, rev: str = "HEAD",
                 pending: list | None = None) -> tuple[list[dict], str]:
    """(every unprovenanced Human tick in non-merge commits in range, range description).

    Range: `since` (a date) when given; else `<anchor>..rev`; else the CUTOFF date (a repo
    where the detector is not committed, e.g. an untracked vendored copy).
    `pending`, when given, receives each tick licensed only by a ledger row that is in the
    working tree but not committed at `rev` (T-4769) — it passes HERE and FAILs in every
    other checkout."""
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
               "--format=%x1e%H%x1f%P%x1f%an <%ae>%x1f%ae%x1f%ce%x1f%cI%x1f%B", *rng)
    # One ledger row covers ONE tick (review round 1: a single `ack` used to license every
    # later re-tick of the same criterion text).
    budget = Counter(r.get("digest") for r in ledger_rows(root))
    checkers: dict = {}
    findings = []
    commits = []
    for rec in log.split("\x1e")[1:]:
        parts = rec.split("\x1f", 6)
        if len(parts) < 7:
            continue
        commits.append(parts)
    # T-4375: every diff-tree in one process, every blob through one cat-file --batch
    # (was one process per commit-parent pair and per blob: ~6,500 forks, ~90 s).
    diffs = iter(_diff_trees(root, [(p[0], parent) for p in commits
                                    for parent in (p[1].split() or [None])]))
    blobs = _BlobReader(root)
    mine: list = []
    try:
        found = _scan(root, commits, diffs, blobs, budget, checkers, findings,
                      committed_ledger_digests(root, rev), mine)
        # T-4824 (055's T-483): the remedy for an unvouched tick is "un-tick it"; a
        # history-only scan kept failing the old commit after the un-tick, leaving the
        # operator's `ack` of a tick they did not make as the only exit.
        gone = _unticked_at(root, rev, blobs, {f["task"] for f in found + mine})
    finally:
        blobs.close()
    if pending is not None:
        pending.extend(p for p in mine if (p["task"], p["key"]) not in gone)
    return [f for f in found if (f["task"], f["key"]) not in gone], where


def _unticked_at(root: Path, rev: str, blobs: "_BlobReader", tids: set) -> set:
    """{(task id, criterion key)} whose EVERY ### Human box, in every file of the task the
    scan reads (.tasks/), is unticked at `rev`. A criterion that is gone or renamed is not
    in the set (it keeps its finding); if git cannot answer, the set is empty (fail closed).
    Every box, not the first: an identical unticked copy above a standing tick must not
    resolve it (055's T-483 review)."""
    if not tids:
        return set()
    state: dict = {}  # (tid, key) -> any box ticked
    try:
        names = _git(root, "ls-tree", "-r", "-z", "--name-only", rev, "--", ".tasks").split("\0")
        for name in names:
            if not name.endswith(".md") or not re.search(r"(^|/)T-\d+", os.path.basename(name)):
                continue
            tid = _task_id(name)
            if tid not in tids:
                continue
            for key, ticked, _ in boxes(_human_section(blobs.show(rev, name))):
                state[(tid, key)] = state.get((tid, key), False) or ticked
    except (subprocess.CalledProcessError, OSError, ValueError):
        return set()
    return {k for k, ticked in state.items() if not ticked}


def _scan(root, commits, diffs, blobs, budget, checkers, findings,
          committed: Counter | None = None, pending: list | None = None) -> list[dict]:
    grants = delegation_grants(root)
    cited: Counter = Counter()  # (grant id, verdict id) already spent: one cite, one tick
    for sha, parents, who, aemail, cemail, cdate, msg in commits:
        parents = parents.split() or [None]
        agent = is_agent_identity(aemail, cemail, msg)
        per_parent: list[dict] = []
        for parent in parents:
            # -z: NUL-separated, never C-quoted — a non-ASCII filename is otherwise printed
            # as "...caf\303\251.md" and silently skipped (review round 3)
            got: dict = {}
            fields = next(diffs).split("\0")
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
                old = "" if (status.startswith("A") or not parent) else blobs.show(parent, old_path)
                tid = _task_id(new_path)
                backing = checkers.setdefault(tid, VerdictBacking(root, tid))
                new = blobs.show(sha, new_path)
                got[new_path] = (tid, unprovenanced_ticks(old, new, backing), new)
            per_parent.append(got)
        # a tick is NEW in this commit only if it is new relative to EVERY parent; a tick
        # inherited from a merged branch was judged in that branch's own commit
        paths = set(per_parent[0])
        for got in per_parent[1:]:
            paths &= set(got)
        for path in sorted(paths):
            tid, first, new = per_parent[0][path]
            keys = Counter(k for k, _, _ in first)
            for got in per_parent[1:]:
                keys &= Counter(k for k, _, _ in got[path][1])  # kinds may differ per parent
            cites = {k: (g, v) for k, g, v in delegation_cites(new)} if first else {}
            for key, kind, vid in first:
                if keys[key] <= 0:
                    continue
                keys[key] -= 1
                if vid and checkers[tid].consume(vid):
                    continue  # a bound verdict with an unspent applied tick event
                d = key_digest(tid, key)
                if budget[d] > 0:
                    budget[d] -= 1
                    if committed is not None and committed[d] > 0:
                        committed[d] -= 1
                    elif pending is not None:  # T-4769: licensed by an UNCOMMITTED row
                        pending.append({"commit": sha, "task": tid, "criterion": key[:100], "key": key})
                    continue
                why = ""
                if key in cites:  # T-4165: a standing delegation, cited on the criterion
                    gid, dvid = cites[key]
                    why = delegation_refusal(grants.get(gid), tid, new, key, dvid,
                                             checkers[tid].digest, cdate)
                    if not why and cited[(gid, dvid)]:
                        why = f"{gid} verdict {dvid} already licensed a tick"
                    if not why:
                        cited[(gid, dvid)] += 1
                        continue
                    kind += f" (delegation refused: {why})"
                findings.append({"commit": sha, "who": who, "agent": agent, "task": tid,
                                 "path": path, "kind": kind if not vid else kind + " (verdict replayed)",
                                 "criterion": key[:100], "key": key, "merge": len(parents) > 1})
    return findings


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
    pending: list[dict] = []
    try:
        findings, since = scan_commits(root, since, pending=pending)
    except (subprocess.CalledProcessError, OSError) as e:
        return 3, [f"could not read git history: {e}"]
    # T-4769: a row that is only in the working tree licenses the tick HERE and nowhere
    # else; say so on the summary line (the one fw audit prints). Verdict unchanged.
    lines = [f"NOTE {p['task']} tick in {p['commit'][:10]} \"{p['criterion']}\" is licensed by "
             f"a provenance row that is not committed" for p in pending]
    tail = (f"; {len(pending)} tick(s) licensed only by UNCOMMITTED rows — commit {LEDGER}, "
            f"or every other checkout FAILs them as 'no record'") if pending else ""
    if not findings:
        return 0, lines + [f"no unprovenanced ### Human ticks in commits since {since}{tail}"]
    for f in findings:
        lines.append(
            f"FAIL {f['task']} {f['kind']} in {'merge ' if f.get('merge') else ''}{f['commit'][:10]} by "
            f"{'AGENT ' if f['agent'] else ''}{f['who']}: \"{f['criterion']}\" — no Watchtower/"
            f"operator record and no reviewer verdict. Ticked in Watchtower? Then the server is "
            f"stale (bin/fw watchtower restart) or the tick predates T-4070: the operator "
            f"records it with: python3 lib/human_ac_ticks.py ack {f['task']} --ac N. Recorded "
            f"in another checkout? A row counts only where it exists: commit {LEDGER} there")
    lines.append(f"{len(findings)} unprovenanced ### Human tick(s) since {since}{tail}")
    return 2, lines


# ── CLI ──────────────────────────────────────────────────────────────────────

def _human_criterion(root: Path, task_id: str, n: int) -> str | None:
    for sub in ("active", "completed"):
        for p in sorted((root / ".tasks" / sub).glob(f"{task_id}-*.md")):
            bx = boxes(_human_section(p.read_text(encoding="utf-8")))
            if 1 <= n <= len(bx):
                return bx[n - 1][0]
    return None


def _append(root: Path, rel: str, row: dict) -> None:
    p = root / rel
    p.parent.mkdir(parents=True, exist_ok=True)
    with p.open("a", encoding="utf-8") as f:
        f.write(json.dumps(row, sort_keys=True) + "\n")


def grant_delegation(root: Path, pattern: str, condition: str, arc: str, tasks: list[str],
                     expires: str, by: str, today: str | None = None) -> dict:
    """Append a standing-delegation grant; ValueError names what is wrong with it."""
    for name, rx in (("--pattern", pattern), ("--condition", condition)):
        try:
            if not rx or re.search(rx, ""):
                raise ValueError(f"{name} {rx!r} matches every criterion — name the criterion")
        except re.error as e:
            raise ValueError(f"{name} does not compile: {e}") from None
    bad = [t for t in tasks if not re.fullmatch(r"T-\d+", t)]
    if bad or not (arc or tasks):
        raise ValueError("scope needs --arc and/or --tasks T-1,T-2 (task ids)")
    today = today or datetime.now(timezone.utc).strftime("%Y-%m-%d")
    try:
        days = (datetime.strptime(expires, "%Y-%m-%d") - datetime.strptime(today, "%Y-%m-%d")).days
    except ValueError:
        raise ValueError(f"--expires {expires!r} is not YYYY-MM-DD") from None
    if not 0 <= days <= MAX_DELEGATION_DAYS:
        raise ValueError(f"--expires must be today..{MAX_DELEGATION_DAYS} days ahead")
    ts = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    row = {"ts": ts, "kind": "grant", "pattern": pattern, "condition": condition,
           "arc": arc or None, "tasks": tasks, "expires": expires, "by": by,
           "id": "SD-" + hashlib.sha256(f"{ts}\n{pattern}\n{condition}\n{arc}\n{tasks}"
                                        .encode()).hexdigest()[:8]}
    _append(root, DELEGATIONS, row)
    return row


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(prog="human_ac_ticks")
    sub = ap.add_subparsers(dest="cmd", required=True)
    dg = sub.add_parser("delegation", help="operator: standing delegation of Human ticks (T-4165)")
    dsub = dg.add_subparsers(dest="dcmd", required=True)
    g = dsub.add_parser("grant", help="delegate ticks of a criterion pattern, on a green verdict")
    g.add_argument("--pattern", required=True, help="regex on the delegated criterion's title")
    g.add_argument("--condition", required=True,
                   help="regex on the title of the criterion whose GREEN verdict must exist")
    g.add_argument("--arc", default="", help="scope: tasks whose arc_id (or arc: tag) is this")
    g.add_argument("--tasks", default="", help="scope: comma-separated task ids")
    g.add_argument("--expires", required=True, help="YYYY-MM-DD, at most a year ahead")
    g.add_argument("--i-am-human", action="store_true")
    r = dsub.add_parser("revoke", help="revoke a grant; ticks committed afterwards stop counting")
    r.add_argument("grant_id")
    r.add_argument("--reason", default="")
    r.add_argument("--i-am-human", action="store_true")
    dsub.add_parser("list", help="show grants and their state")
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
    if args.cmd == "delegation" and args.dcmd == "list":
        today = datetime.now(timezone.utc).strftime("%Y-%m-%d")
        for gid, gr in delegation_grants(root).items():
            state = ("revoked " + gr["revoked"]) if gr["revoked"] else \
                ("expired" if str(gr.get("expires")) < today else "active")
            print(f"{gid} {state} expires={gr.get('expires')} arc={gr.get('arc') or '-'} "
                  f"tasks={','.join(gr.get('tasks') or []) or '-'} pattern={gr.get('pattern')!r} "
                  f"condition={gr.get('condition')!r} by={gr.get('by')}")
        return 0
    if args.cmd == "delegation" and _under_agent_control() and not args.i_am_human:
        print("REFUSED: a standing delegation is the operator's grant (CLAUDECODE/AI_AGENT set). "
              "Ask the operator to run it in their own terminal.", file=sys.stderr)
        return 2
    if args.cmd == "delegation":
        by = "agent-override" if _under_agent_control() else (os.environ.get("USER") or "operator")
        if args.dcmd == "revoke":
            if args.grant_id not in delegation_grants(root):
                print(f"no grant {args.grant_id} in {DELEGATIONS}", file=sys.stderr)
                return 1
            _append(root, DELEGATIONS, {"ts": datetime.now(timezone.utc).strftime(
                "%Y-%m-%dT%H:%M:%SZ"), "kind": "revoke", "id": args.grant_id, "by": by,
                "reason": args.reason})
            print(f"revoked {args.grant_id}")
            return 0
        tasks = [t.strip() for t in args.tasks.split(",") if t.strip()]
        try:
            row = grant_delegation(root, args.pattern, args.condition, args.arc, tasks,
                                   args.expires, by)
        except ValueError as e:
            print(f"REFUSED: {e}", file=sys.stderr)
            return 1
        print(f"granted {row['id']} in {DELEGATIONS}: an agent cites it on the criterion as\n"
              f"  **Delegated tick:** {row['id']} verdict <green verdict id>")
        return 0
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
