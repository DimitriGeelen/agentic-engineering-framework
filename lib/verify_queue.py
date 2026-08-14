#!/usr/bin/env python3
"""T-2765: re-run stored ## Verification for the human review queue.

`fw audit` CTL-013 already re-runs stored verification — over the latest 3 files
in `.tasks/completed/`. The review queue lives in `.tasks/active/`, so the 221
tasks a human is about to finalise were outside every rail's population. A line
that rots after completion stayed red until the operator tripped it at close
(L-539; found by T-2764 — T-2632 red for a week, T-2634 alongside it).

Two reuse rules this module exists to honour, both learned the expensive way:

  * The population comes from `fw review-queue --ids`, i.e. from the ONE
    predicate that defines "awaiting human review" (`count_unchecked_human_acs`,
    centralised by T-2075). It is not re-derived from status/owner here.
  * Block extraction shells out to `extract_verification_block` in
    lib/verification-port.sh. There are already three implementations of that
    predicate in this repo and they disagree; this is deliberately not a fourth.
"""

from __future__ import annotations

import json
import os
import re
import subprocess
import sys
import time
from pathlib import Path

STATE_REL = ".context/working/.verify-queue-state.json"
DEFAULT_LIMIT = 5
DEFAULT_TIMEOUT = 180

# Lines we refuse to execute. CTL-013 already skips nested audit invocations
# (L-391); scaling from 3 tasks to the whole queue widens the blast radius
# enough that "skip and say so" beats "run and hope". Reported as SKIPPED, never
# as PASS — a skip that reads as a pass is the vacuous-green class this rail
# exists to remove.
UNSAFE_PATTERNS = [
    (re.compile(r"\bfw\s+audit\b"), "nested audit invocation (L-391)"),
    (re.compile(r"\bcorpus\s+prove\b"), "destructive on the live corpus store"),
    (re.compile(r"\brm\s+-rf\b"), "destructive"),
    (re.compile(r"\bgit\s+push\b"), "outward-facing"),
    (re.compile(r"\bgit\s+reset\s+--hard\b"), "destructive"),
]


def _root() -> Path:
    return Path(os.environ.get("PROJECT_ROOT", ".")).resolve()


def _framework_root() -> Path:
    return Path(os.environ.get("FRAMEWORK_ROOT", os.environ.get("PROJECT_ROOT", "."))).resolve()


def _fw_bin() -> str:
    cand = _framework_root() / "bin" / "fw"
    if cand.is_file():
        return str(cand)
    cand = _root() / ".agentic-framework" / "bin" / "fw"
    if cand.is_file():
        return str(cand)
    return "fw"


def queue_ids(root: Path) -> list[str]:
    """Population = `fw review-queue --ids`. Never re-derived locally."""
    r = subprocess.run([_fw_bin(), "review-queue", "--ids"],
                       capture_output=True, text=True, cwd=str(root), timeout=120)
    if r.returncode != 0:
        return []
    return [ln.strip() for ln in r.stdout.splitlines() if re.fullmatch(r"T-\d+", ln.strip())]


def task_file(root: Path, task_id: str) -> Path | None:
    for sub in ("active", "completed"):
        hits = sorted((root / ".tasks" / sub).glob(f"{task_id}-*.md"))
        if hits:
            return hits[0]
    return None


def verification_lines(root: Path, path: Path) -> list[str]:
    """Reuse the shared extractor. Not a fourth implementation — a call into the
    existing one, so a change there changes this rail too."""
    port_lib = _framework_root() / "lib" / "verification-port.sh"
    if not port_lib.is_file():
        port_lib = root / "lib" / "verification-port.sh"
    script = f'source "{port_lib}"; extract_verification_block "{path}"'
    r = subprocess.run(["bash", "-c", script], capture_output=True, text=True,
                       cwd=str(root), timeout=60)
    return [ln for ln in r.stdout.splitlines() if ln.strip()]


def _bad_syntax(line: str) -> bool:
    """True when bash cannot parse the line as a command.

    `bash -n` parses without executing — the same predicate
    lib/verification-port.sh's find_unparseable_verification_lines uses. It is
    re-expressed here rather than shelled out to per line because this rail runs
    over the whole corpus and a subprocess per line is the difference between a
    fast rail and a slow one; the expression is one flag and cannot drift
    meaningfully. The shared lib remains the authority for the close gate.
    """
    if not line.strip():
        return False
    p = subprocess.run(["bash", "-n", "-c", line], capture_output=True,
                       text=True, stdin=subprocess.DEVNULL, timeout=10)
    return p.returncode != 0


def _unparseable(root: Path, lines: list[str]) -> bool:
    return any(_bad_syntax(ln) for ln in lines)


def _unsafe(line: str) -> str | None:
    for pat, why in UNSAFE_PATTERNS:
        if pat.search(line):
            return why
    return None


def run_task(root: Path, task_id: str, timeout: int) -> dict:
    """Run one task's stored block. Returns a verdict record."""
    path = task_file(root, task_id)
    if path is None:
        return {"task": task_id, "status": "missing", "total": 0, "passed": 0,
                "failed": 0, "skipped": 0, "failures": []}
    lines = verification_lines(root, path)
    rec = {"task": task_id, "file": str(path.relative_to(root)), "status": "pass",
           "total": len(lines), "passed": 0, "failed": 0, "skipped": 0,
           "timed_out": 0, "failures": []}
    if not lines:
        rec["status"] = "empty"
        return rec
    # T-2991: the second execution site of the same block. If the close gate
    # refuses an unparseable block, this rail must refuse it too — otherwise the
    # path without the gate is the one that runs it, which is the L-399
    # producer/consumer split that let the `--switch-focus` contract be
    # circumvented for three weeks. Refusing the WHOLE block (not just the bad
    # line) is deliberate: the lines below an unterminated quote are the body of
    # a wrapped command, and running them individually is precisely the failure
    # (`import yaml,sys` as bash → ImageMagick screenshot in the repo root,
    # T-2990).
    if _unparseable(root, lines):
        rec["status"] = "unparseable"
        rec["skipped"] = len(lines)
        rec["failures"] = [{"line": ln, "why": "block has unparseable line(s) — "
                            "see T-2991; the gate is line-oriented"}
                           for ln in lines if _bad_syntax(ln)]
        return rec
    for line in lines:
        why = _unsafe(line)
        if why:
            rec["skipped"] += 1
            continue
        try:
            # cwd=PROJECT_ROOT so `.tasks/active/<file>` self-references resolve (L-356).
            # `set -eo pipefail` so the line is judged the way P-011 judges it — an
            # interactive shell has neither flag and will disagree (T-2743).
            # stdin=DEVNULL: a stored line that reads stdin (an unguarded `read`,
            # a pager, an interactive prompt) would otherwise block for the whole
            # timeout on every run. The gate runs non-interactively; so do we.
            p = subprocess.run(["bash", "-c", f"set -eo pipefail; {line}"],
                               capture_output=True, text=True, cwd=str(root),
                               stdin=subprocess.DEVNULL, timeout=timeout)
            rc, out = p.returncode, (p.stdout + p.stderr)
        except subprocess.TimeoutExpired:
            # A timeout is absence of evidence, not evidence of failure — some
            # stored blocks run whole pytest suites that legitimately exceed the
            # budget. Counting it red would put the same defect in this rail that
            # L-539 is about: two states with opposite meaning sharing one bucket.
            rec["timed_out"] += 1
            continue
        if rc == 0:
            rec["passed"] += 1
        else:
            rec["failed"] += 1
            rec["failures"].append({
                "command": line.strip(),
                "rc": rc,
                "output": "\n".join(out.splitlines()[:5]),
            })
    if rec["failed"]:
        rec["status"] = "fail"
    elif rec["timed_out"]:
        rec["status"] = "timeout"
    elif rec["passed"] == 0:
        rec["status"] = "skipped"
    return rec


def load_state(root: Path) -> dict:
    p = root / STATE_REL
    try:
        return json.loads(p.read_text())
    except Exception:
        return {}


def save_state(root: Path, state: dict) -> None:
    p = root / STATE_REL
    p.parent.mkdir(parents=True, exist_ok=True)
    tmp = p.with_suffix(p.suffix + ".tmp")
    tmp.write_text(json.dumps(state, indent=1, sort_keys=True))
    os.replace(tmp, p)


def select(ids: list[str], state: dict, limit: int) -> list[str]:
    """Least-recently-checked first, never-checked before ever-checked. Rotation
    is the whole point: a fixed head-of-list would re-check the same tasks daily
    and never reach the tail, which is exactly how CTL-013's top-3 window let
    the queue rot."""
    return sorted(ids, key=lambda t: state.get(t, {}).get("ts", 0))[:limit]


def _print_one(r: dict) -> None:
    """One verdict line per task, emitted as soon as that task finishes.

    A failing task names the command and shows the first lines of its output —
    a red result has to be actionable without re-deriving which line broke.
    """
    if r["status"] == "fail":
        print(f"\033[31mFAIL\033[0m  {r['task']}  "
              f"{r['failed']}/{r['total']} command(s) failing", flush=True)
        for f in r["failures"]:
            print(f"        $ {f['command'][:120]}")
            print(f"          rc={f['rc']}")
            for ln in f["output"].splitlines():
                print(f"          | {ln[:120]}", flush=True)
    elif r["status"] == "empty":
        print(f"\033[90mNONE\033[0m  {r['task']}  no stored verification", flush=True)
    elif r["status"] == "missing":
        print(f"\033[90m????\033[0m  {r['task']}  task file not found", flush=True)
    elif r["status"] == "timeout":
        print(f"\033[33mTIME\033[0m  {r['task']}  "
              f"{r['timed_out']}/{r['total']} did not finish in budget "
              f"(not counted red)", flush=True)
    elif r["status"] == "skipped":
        print(f"\033[33mSKIP\033[0m  {r['task']}  "
              f"{r['skipped']}/{r['total']} skipped, none executed", flush=True)
    else:
        note = f", {r['skipped']} skipped" if r["skipped"] else ""
        print(f"\033[32mPASS\033[0m  {r['task']}  {r['passed']}/{r['total']}{note}",
              flush=True)


def main(argv: list[str]) -> int:
    limit, only, want_all, as_json = DEFAULT_LIMIT, None, False, False
    timeout = int(os.environ.get("FW_VERIFY_QUEUE_TIMEOUT", DEFAULT_TIMEOUT))
    i = 0
    while i < len(argv):
        a = argv[i]
        if a == "--limit":
            i += 1
            limit = int(argv[i])
        elif a.startswith("--limit="):
            limit = int(a.split("=", 1)[1])
        elif a == "--all":
            want_all = True
        elif a == "--task":
            i += 1
            only = argv[i]
        elif a.startswith("--task="):
            only = a.split("=", 1)[1]
        elif a == "--json":
            as_json = True
        else:
            print(f"ERROR: unknown argument '{a}'", file=sys.stderr)
            return 2
        i += 1

    root = _root()
    if only:
        targets = [only]
    else:
        ids = queue_ids(root)
        if not ids:
            print("No tasks awaiting human review.")
            return 0
        state = load_state(root)
        targets = ids if want_all else select(ids, state, limit)

    state = load_state(root)
    results = []
    for tid in targets:
        rec = run_task(root, tid, timeout)
        results.append(rec)
        state[tid] = {"ts": int(time.time()), "status": rec["status"],
                      "failed": rec["failed"], "total": rec["total"]}
        # Persist and report per task, not at the end: a full sweep of this queue
        # runs for hours (some stored blocks are whole pytest suites), and a run
        # that only speaks when finished is a run nobody waits for. Partial
        # progress survives an interrupt — the rotation state is already written.
        save_state(root, state)
        if not as_json:
            _print_one(rec)
    save_state(root, state)

    red = [r for r in results if r["status"] == "fail"]
    if as_json:
        print(json.dumps({"checked": len(results), "red": len(red),
                          "results": results}, indent=1))
        return 1 if red else 0

    timed = [r for r in results if r["status"] == "timeout"]
    print()
    print(f"{len(results)} task(s) checked · \033[31m{len(red)} red\033[0m"
          + (f" · \033[33m{len(timed)} over budget\033[0m" if timed else ""))
    if not only and not want_all:
        total_q = len(queue_ids(root))
        print(f"\033[2mrotation: least-recently-checked first · {total_q} in queue · "
              f"state {STATE_REL}\033[0m")
    return 1 if red else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
