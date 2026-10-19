#!/usr/bin/env python3
"""fw audit: issue-ledger lag (G-119 detection, T-4370).

A task with a `github_issue:` field implies a lifecycle stage on that GitHub issue:

  status started-work                       -> in-progress
  status work-completed                     -> fixed-on-bleeding-edge
  a commit (subject starting with its id)
    contained in a v* tag                   -> released

`fw issues` posts those stages and records each one in .context/issues/intake.jsonl. When the
post never happened (or failed into a *-pending.jsonl nobody reads), the ledger is behind the
task, and nothing else in the framework says so. This module compares the two and reports the
lag. It is detection only: no network, no `gh`, no ledger writes. Internal-author issues (T-4342,
ledger rows with class: internal) are exempt — the operator reads those directly.

CLI:  python3 lib/issues_lag.py audit --root PROJECT_ROOT
      exit 0 = no lag, 1 = lag listed on stdout, 2 = could not run
"""
import argparse
import json
import os
import re
import subprocess
import sys
from pathlib import Path

# Lifecycle order: a later stage on the ledger satisfies an earlier expectation.
ORDER = ["received", "classified", "accepted", "in-progress", "fixed-on-bleeding-edge",
         "available-for-testing", "released", "closed-released"]
RANK = {s: i for i, s in enumerate(ORDER)}
NOT_STAGES = {"reply", "baseline", "edited"}  # ledger rows that are not lifecycle stages

_ID_RE = re.compile(r"^T-\d+\b")


def _ledger_path(root: Path) -> Path:
    d = os.environ.get("FW_ISSUES_DIR")
    return (Path(d) if d else root / ".context" / "issues") / "intake.jsonl"


def _read_ledger(path: Path) -> list:
    rows = []
    if not path.exists():
        return rows
    for line in path.read_text(errors="replace").splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            row = json.loads(line)
        except ValueError:
            continue  # a torn line is not a row
        if isinstance(row, dict):
            rows.append(row)
    return rows


def _frontmatter(text: str) -> str:
    if not text.startswith("---"):
        return ""
    parts = text.split("---", 2)
    return parts[1] if len(parts) >= 3 else ""


def _task_records(root: Path) -> list:
    """Every task file under active/ and completed/ that carries a github_issue: field."""
    out = []
    for state in ("active", "completed"):
        for path in sorted((root / ".tasks" / state).glob("T-*.md")):
            fm = _frontmatter(path.read_text(errors="replace"))
            issue = re.search(r'^github_issue:\s*"?#?(\d+)"?\s*$', fm, re.M)
            if not issue:
                continue
            tid = re.search(r"^id:\s*(T-\d+)", fm, re.M)
            name = re.match(r"(T-\d+)", path.name)
            status = re.search(r"^status:\s*(\S+)", fm, re.M)
            out.append({"issue": int(issue.group(1)),
                        "task": tid.group(1) if tid else (name.group(1) if name else path.stem),
                        "status": status.group(1) if status else ""})
    return out


def _git(root: Path, args: list) -> str | None:
    p = subprocess.run(["git", "-C", str(root)] + args, capture_output=True, text=True)
    return p.stdout if p.returncode == 0 else None


def _task_commits(root: Path) -> dict:
    """Task id -> commit hashes whose subject starts with that id, from HEAD."""
    out = _git(root, ["log", "--format=%H%x09%s", "HEAD"]) or ""
    by_task: dict = {}
    for line in out.splitlines():
        sha, _, subject = line.partition("\t")
        m = _ID_RE.match(subject)
        if m:
            by_task.setdefault(m.group(0), []).append(sha)
    return by_task


def _tagged_commits(root: Path) -> set:
    """Every commit reachable from a v* tag. One rev-list, no per-task walk."""
    out = _git(root, ["rev-list", "--glob=refs/tags/v*"]) or ""
    return set(out.split())


def _stages_for(rows: list, issue: int) -> tuple:
    """(stage tokens seen for the issue, internal?, last lifecycle stage string or 'none')."""
    tokens: set = set()
    internal = False
    last = "none"
    for r in rows:
        if r.get("issue") != issue:
            continue
        if r.get("class") == "internal":
            internal = True
        stage = str(r.get("stage", ""))
        if not stage or stage in NOT_STAGES:
            continue
        tokens.update(stage.split("+"))
        last = stage
    return tokens, internal, last


def _satisfied(tokens: set, expected: str) -> bool:
    return any(RANK.get(t, -1) >= RANK[expected] for t in tokens)


def _expected(rec: dict, tagged: set, commits: list) -> str | None:
    if any(c in tagged for c in commits):
        return "released"
    if rec["status"] == "work-completed":
        return "fixed-on-bleeding-edge"
    if rec["status"] == "started-work":
        return "in-progress"
    return None


MITIGATION = {
    "in-progress": "bin/fw issues lifecycle {task} --event started",
    "fixed-on-bleeding-edge": "bin/fw issues lifecycle {task} --event closed",
    "released": "bin/fw issues release vX --range ...",
}


def check_lag(root) -> list:
    """Findings for every linked task whose ledger lacks the stage its state implies.

    Each finding: {issue, task, expected, last, mitigation}. Read-only."""
    root = Path(root)
    records = _task_records(root)
    if not records:  # no linked task: skip the two git walks entirely
        return []
    rows = _read_ledger(_ledger_path(root))
    tagged = _tagged_commits(root)
    commits = _task_commits(root)
    findings = []
    for rec in records:
        tokens, internal, last = _stages_for(rows, rec["issue"])
        if internal:
            continue
        expected = _expected(rec, tagged, commits.get(rec["task"], []))
        if expected is None:
            continue
        if expected == "released" and "closed-released" in tokens:
            continue
        if _satisfied(tokens, expected):
            continue
        findings.append({"issue": rec["issue"], "task": rec["task"], "expected": expected,
                         "last": last,
                         "mitigation": MITIGATION[expected].format(task=rec["task"])})
    return sorted(findings, key=lambda f: (f["issue"], f["task"]))


def format_finding(f: dict) -> str:
    return (f"#{f['issue']} {f['task']} expected {f['expected']}, ledger has {f['last']}"
            f" — {f['mitigation']}")


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description="issue-ledger lag check (G-119)")
    sub = ap.add_subparsers(dest="cmd", required=True)
    a = sub.add_parser("audit", help="list lagging issues (read-only)")
    a.add_argument("--root", default=os.environ.get("PROJECT_ROOT") or os.getcwd())
    args = ap.parse_args(argv)
    try:
        findings = check_lag(args.root)
    except OSError as e:
        print(f"could not run: {e}", file=sys.stderr)
        return 2
    for f in findings:
        print(f"LAG {format_finding(f)}")
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main())
