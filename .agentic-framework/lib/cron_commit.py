#!/usr/bin/env python3
"""T-4695 — a cron job's output is either committed by the job or not tracked.

THE CLASS. Scheduled jobs rewrite tracked files and nothing commits them: 87
modified files in one live session (35 generated component docs, 22 runtime
files under .context/working, monitor samples, audit LATEST snapshots), picked
up later by whichever unrelated commit staged broadly. T-4676 fixed it for the
two estimator sweeps inside estimator.py; this is the same rule for any job,
driven by two optional fields on the job in .context/cron-registry.yaml:

  commit_task:  T-XXXX        task id the job's own commits carry
  commit_paths: [path, ...]   outputs the job commits itself (a below)
  ignore_paths: [glob, ...]   outputs that are per-host derived state and must
                              stay untracked and gitignored (b below)

  run     wrap a job:  cron_commit.py run --job ID -- <command ...>
          Snapshots which files under commit_paths are already dirty, runs the
          command, then commits exactly the files under commit_paths that the
          run changed — one commit, `git commit -- <paths>` so another worker's
          staged files stay out of it, files that were dirty before the run
          skipped (that edit belongs to someone else), index.lock retried. Same
          semantics as T-4676's _commit_sweep_writes. Exit: the command's own
          status, or 1 when it succeeded but the commit failed.

  check   the rail:  cron_commit.py check [--max-age-hours N]
          For every active job: a tracked file under commit_paths that is still
          modified N hours (default 26: a daily job plus slack) after it was
          written was not committed by its writer; a tracked file matching
          ignore_paths is runtime state still in git. Prints one line per
          finding. Exit 0 clean, 1 findings, 2 setup error.

WHAT IT CANNOT SEE. Output a job writes that its registry entry does not
declare. Declaring the outputs is the job owner's step; the rail checks the
declaration holds, not that it is complete.
"""
from __future__ import annotations

import argparse
import fnmatch
import os
import subprocess
import sys
import time
from pathlib import Path

import yaml

DEFAULT_MAX_AGE_HOURS = 26


def _project_root() -> Path:
    return Path(os.environ.get("PROJECT_ROOT") or os.getcwd()).resolve()


def _git(root: Path, *args: str) -> subprocess.CompletedProcess:
    return subprocess.run(["git", "-C", str(root), *args],
                          capture_output=True, text=True)


def load_jobs(root: Path) -> list[dict]:
    reg = root / ".context" / "cron-registry.yaml"
    if not reg.is_file():
        return []
    data = yaml.safe_load(reg.read_text()) or {}
    return [j for j in (data.get("jobs") or []) if isinstance(j, dict)]


def dirty_under(root: Path, paths: list[str]) -> set[str] | None:
    """Repo-relative paths under `paths` that are modified, staged or untracked
    (not ignored). None when root is not a git work tree."""
    if not paths:
        return set()
    if _git(root, "rev-parse", "--is-inside-work-tree").returncode != 0:
        return None
    r = _git(root, "status", "--porcelain=v1", "-z", "--untracked-files=all",
             "--", *paths)
    if r.returncode != 0:
        return None
    dirty: set[str] = set()
    entries = r.stdout.split("\0")
    i = 0
    while i < len(entries):
        e = entries[i]
        i += 1
        if len(e) < 4:
            continue
        dirty.add(e[3:])
        if e[0] in "RC":
            i += 1  # rename/copy: the next entry is the source path
    return dirty


def commit_writes(root: Path, before: set[str], paths: list[str],
                  task_id: str, label: str) -> bool:
    """Commit the files under `paths` that became dirty since `before`. True
    when there was nothing to commit or the commit landed."""
    after = dirty_under(root, paths)
    if after is None:
        return True
    written = sorted(after - before)
    if not written:
        return True
    untracked = [p for p in written
                 if _git(root, "ls-files", "--error-unmatch", "--", p).returncode != 0]
    if untracked:
        _git(root, "add", "--", *untracked)
    msg = (f"{task_id}: {label} — {len(written)} generated file(s)\n\n"
           f"Committed by the cron job itself (T-4695, lib/cron_commit.py): only\n"
           f"files this run wrote; files with uncommitted edits from before the\n"
           f"run were left alone.")
    r = None
    for _ in range(6):
        r = _git(root, "commit", "-q", "-m", msg, "--", *written)
        if r.returncode == 0:
            return True
        if "index.lock" not in (r.stderr + r.stdout):
            break
        time.sleep(5)  # another worker is committing
    detail = ((r.stderr or r.stdout).strip().splitlines() or ["no output"])[-1]
    print(f"ERROR: {label}: commit of {len(written)} file(s) failed — they stay "
          f"uncommitted: {detail}", file=sys.stderr)
    return False


def cmd_run(root: Path, job_id: str, command: list[str]) -> int:
    if command and command[0] == "--":
        command = command[1:]
    if not command:
        print("ERROR: cron_commit run: no command after --", file=sys.stderr)
        return 2
    job = next((j for j in load_jobs(root) if j.get("id") == job_id), None)
    paths = list((job or {}).get("commit_paths") or [])
    task_id = (job or {}).get("commit_task") or ""
    if not paths or not task_id:
        print(f"WARN: cron_commit: job {job_id!r} declares no commit_task/"
              f"commit_paths — running without committing", file=sys.stderr)
        return subprocess.call(command, cwd=root)
    before = dirty_under(root, paths)
    rc = subprocess.call(command, cwd=root)
    if before is None:
        return rc
    committed = commit_writes(root, before, paths, task_id, job_id)
    if rc != 0:
        return rc
    return 0 if committed else 1


def _matches(rel: str, pattern: str) -> bool:
    pattern = pattern.rstrip("/")
    return (fnmatch.fnmatchcase(rel, pattern)
            or rel.startswith(pattern + "/"))


def check(root: Path, max_age_hours: float) -> list[str]:
    findings: list[str] = []
    if _git(root, "rev-parse", "--is-inside-work-tree").returncode != 0:
        return findings
    tracked = _git(root, "ls-files", "-z").stdout.split("\0")
    now = time.time()
    for job in load_jobs(root):
        if job.get("status", "active") != "active":
            continue
        jid = job.get("id", "?")
        cpaths = list(job.get("commit_paths") or [])
        if cpaths:
            r = _git(root, "status", "--porcelain=v1", "-z",
                     "--untracked-files=no", "--", *cpaths)
            for e in r.stdout.split("\0"):
                if len(e) < 4:
                    continue
                rel = e[3:]
                try:
                    age_h = (now - (root / rel).stat().st_mtime) / 3600
                except OSError:
                    continue
                if age_h >= max_age_hours:
                    findings.append(
                        f"uncommitted\t{jid}\t{rel}\twritten {age_h:.0f}h ago, "
                        f"still modified — the job's own commit did not take it")
        for pat in job.get("ignore_paths") or []:
            for rel in tracked:
                if rel and _matches(rel, pat):
                    findings.append(
                        f"tracked\t{jid}\t{rel}\tdeclared runtime output "
                        f"(ignore_paths: {pat}) but tracked — git rm --cached it")
    return findings


def selftest() -> int:
    """Regression check in a temp git repo (no hooks, no network): the run
    wrapper commits only what the job wrote and skips pre-dirty files; the rail
    flags an aged uncommitted output and a tracked ignore_paths file, and is
    clean once both are resolved. Prints PASS/FAIL per case; exit 1 on any FAIL."""
    import tempfile
    fails = 0

    def ok(name: str, cond: bool) -> None:
        nonlocal fails
        print(f"{'PASS' if cond else 'FAIL'} {name}")
        fails += 0 if cond else 1

    with tempfile.TemporaryDirectory() as td:
        root = Path(td)
        g = lambda *a: _git(root, "-c", "user.name=t", "-c", "user.email=t@t",
                            "-c", "core.hooksPath=/dev/null", *a)
        g("init", "-q")
        (root / ".context").mkdir()
        (root / "gen").mkdir()
        (root / "state").mkdir()
        (root / ".context" / "cron-registry.yaml").write_text(yaml.safe_dump({"jobs": [
            {"id": "gen-job", "status": "active", "commit_task": "T-1",
             "commit_paths": ["gen"], "ignore_paths": ["state/*.log"]}]}))
        for n in ("a.md", "b.md"):
            (root / "gen" / n).write_text("v1\n")
        (root / "state" / "run.log").write_text("x\n")
        g("add", "-A")
        g("commit", "-q", "-m", "T-1: seed")
        os.environ.setdefault("GIT_AUTHOR_NAME", "t")
        os.environ.setdefault("GIT_AUTHOR_EMAIL", "t@t")
        os.environ.setdefault("GIT_COMMITTER_NAME", "t")
        os.environ.setdefault("GIT_COMMITTER_EMAIL", "t@t")
        _git(root, "config", "core.hooksPath", "/dev/null")

        (root / "gen" / "b.md").write_text("foreign edit\n")  # dirty before run
        writer = ("import pathlib; [pathlib.Path('gen', n).write_text('v2\\n') "
                  "for n in ('a.md', 'b.md', 'c.md')]")
        rc = cmd_run(root, "gen-job", ["--", sys.executable, "-c", writer])
        ok("run exits 0", rc == 0)
        last = _git(root, "show", "--name-only", "--format=%s", "HEAD").stdout.split()
        ok("run commits written files a.md and new c.md", "gen/a.md" in last and "gen/c.md" in last)
        ok("run skips pre-dirty b.md", "gen/b.md" not in last)
        ok("commit subject carries commit_task", last[:1] == ["T-1:"])

        old = time.time() - 30 * 3600
        os.utime(root / "gen" / "b.md", (old, old))
        found = check(root, DEFAULT_MAX_AGE_HOURS)
        ok("rail flags aged uncommitted output", any(f.startswith("uncommitted\tgen-job\tgen/b.md") for f in found))
        ok("rail flags tracked ignore_paths file", any(f.startswith("tracked\tgen-job\tstate/run.log") for f in found))
        g("commit", "-q", "-m", "T-1: b", "--", "gen/b.md")
        g("rm", "-q", "--cached", "state/run.log")
        g("commit", "-q", "-m", "T-1: untrack", "--", "state/run.log")
        ok("rail clean once committed and untracked", check(root, DEFAULT_MAX_AGE_HOURS) == [])
    return 1 if fails else 0


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(prog="cron_commit.py")
    sub = ap.add_subparsers(dest="cmd", required=True)
    sub.add_parser("selftest")
    r = sub.add_parser("run")
    r.add_argument("--job", required=True)
    r.add_argument("command", nargs=argparse.REMAINDER)
    c = sub.add_parser("check")
    c.add_argument("--max-age-hours", type=float, default=DEFAULT_MAX_AGE_HOURS)
    a = ap.parse_args(argv)
    if a.cmd == "selftest":
        return selftest()
    root = _project_root()
    try:
        if a.cmd == "run":
            return cmd_run(root, a.job, a.command)
        findings = check(root, a.max_age_hours)
    except (OSError, yaml.YAMLError) as e:
        print(f"ERROR: cron_commit: {e}", file=sys.stderr)
        return 2
    for f in findings:
        print(f)
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
