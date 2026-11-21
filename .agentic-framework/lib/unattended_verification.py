#!/usr/bin/env python3
"""T-5268: may a stored ## Verification line run unattended, outside its close?

Two audit rails re-execute stored Verification lines long after the close they
were written for, on a live host, with nobody watching: CTL-013 (agents/audit/
audit.sh, recently completed tasks) and verify-queue (CTL-013b, lib/verify_queue.py,
the human review queue). Before this module they disagreed — verify-queue refused
a pattern list, CTL-013 refused only nested `fw audit` — so the rail without the
list was the one that ran `rm -rf` or an HTTP write. One predicate, both rails.

Origin: 0506-Voxtype-extention (msg ac237c0c, their P25). verify-queue re-ran an
old task's line that called a spike script whose EXIT trap did
`pkill -f voxtype-review`, and their live services got SIGTERM twice.

A text check never sees inside a script the line calls (the same boundary as
Tier 0, T-2742), so the author can declare it: a trailing comment
`# needs: fixture` makes both rails skip the line. Bash reads it as a comment,
so the P-011 close gate — which runs every line — still runs it.

Every unattended run or skip is appended to HISTORY_REL, one JSON row per line,
so a run can be matched to an incident afterwards (the rotation state keeps only
the last timestamp per task).

CLI:
  unattended_verification.py check "<line>"
      exit 0 = may run (nothing printed); exit 3 = skip, reason on stdout.
  unattended_verification.py history --runner R --task T --line L
                                     --outcome pass|fail|timeout|skipped [--reason S]
      append one history row under $PROJECT_ROOT (default: cwd).
"""

from __future__ import annotations

import datetime as _dt
import hashlib
import json
import os
import re
import sys
from pathlib import Path

HISTORY_REL = ".context/audits/verify-queue/history.jsonl"
RUNNERS = ("verify-queue", "ctl-013")
OUTCOMES = ("pass", "fail", "timeout", "skipped")

# Author's declaration: a trailing `#` comment containing `needs: fixture`.
# Case-insensitive; must be the last thing on the line. A `#` inside a quoted
# string is not distinguished — over-skipping an unattended re-run is the safe
# direction, and the close gate runs the line either way.
FIXTURE_MARKER = re.compile(r"(?:^|\s)#[^\n]*\bneeds:\s*fixture\b[^\n]*$", re.IGNORECASE)
FIXTURE_REASON = "declared '# needs: fixture' (runs at close only)"

# Lines we refuse to execute unattended. Reported as SKIPPED, never as PASS —
# a skip that reads as a pass is the vacuous-green class these rails remove.
UNSAFE_PATTERNS = [
    # T-1870/L-391: the audit lock is held by the outer audit; a nested one
    # exits "Another audit is already running". `\bfw` also covers bin/fw and
    # .agentic-framework/bin/fw; `audit\b` keeps `fw auditor` runnable.
    (re.compile(r"\bfw\s+audit\b"), "nested-audit invocation (L-391)"),
    (re.compile(r"\bcorpus\s+prove\b"), "destructive on the live corpus store"),
    (re.compile(r"\brm\s+-rf\b"), "destructive"),
    (re.compile(r"\bgit\s+push\b"), "outward-facing"),
    (re.compile(r"\bgit\s+reset\s+--hard\b"), "destructive"),
    # T-4026: an HTTP write changes a live service. These rails re-run blocks
    # OUTSIDE a close, every day, so they must only observe: T-2529's save-check
    # re-created a deleted map in the live designer store at each 07:12 audit.
    # Scoped to the curl/wget segment (no |;& in between) so a line that merely
    # greps for "POST" still runs. Case-sensitive on purpose: -D (dump headers)
    # is a read and must not match -d.
    (re.compile(r"\bcurl\b[^|;&\n]*?\s(?:-[A-Za-z]*X\s*(?i:POST|PUT|PATCH|DELETE)\b"
                r"|--request[=\s]+(?i:POST|PUT|PATCH|DELETE)\b"
                r"|-d\b|--data(?:-[a-z]+)?\b|-F\b|--form\b|--json\b)"),
     "HTTP write against a live service"),
    (re.compile(r"\bwget\b[^|;&\n]*?\s--(?:post-data|post-file|method)\b"),
     "HTTP write against a live service"),
    # T-5268: process control on a live host (0506 P25). `kill -0 PID` only
    # tests existence and stays runnable; `kill` with a signal or a pid does not.
    (re.compile(r"(?:^|[\s;&|(`$])kill\s+(?!-0\b)(?:-|%|\d)"), "process control (kill)"),
    (re.compile(r"\b(?:pkill|killall)\b"), "process control (pkill/killall)"),
    (re.compile(r"\bsystemctl\b[^|;&\n]*?\s(?:stop|restart|kill|disable)\b"),
     "process control (systemctl)"),
    (re.compile(r"\bservice\s+\S+\s+(?:stop|restart)\b"), "process control (service)"),
    # Command position only (line start, after ; & | ( ` or sudo), so a line
    # that greps a log for "shutdown" or tests reboot.log still runs.
    (re.compile(r"(?:^|[;&|(`]|\bsudo)\s*(?:shutdown|reboot)(?=\s|$|[;&|)])"),
     "process control (shutdown/reboot)"),
    # T-5336 (1023 field report): a stored line that changes the repo changes it at EVERY
    # unattended re-run (1023's `git add -A .context` staged the real .context each audit).
    # Command position only, so a line that greps for the text "git add" still runs; global
    # options (-C path, -c k=v, --git-dir=..) may sit between `git` and the verb. Read-only
    # verbs (log, status, diff, show, rev-parse, ls-files, ...) stay runnable.
    (re.compile(r"(?:^|[;&|(`$]|\bsudo)\s*git(?:\s+-[Cc]\s+\S+|\s+--[\w-]+(?:=\S+)?)*\s+"
                r"(?:stash(?!\s+(?:list|show)\b)(?=\s|$|[;&|)'\"])|"
                r"(?:add|commit|checkout|switch|restore|clean|rm|mv|merge|rebase|"
                r"cherry-pick|revert|am|apply|reset|update-index|update-ref)(?=\s|$|[;&|)'\"])|"
                r"tag\s+(?:-[a-zA-Z]*[dasfu]\b|--(?:delete|annotate|sign|force)\b|[^-\s])|"
                r"branch\s+(?:-[a-zA-Z]*[dDmM]\b|--delete\b|--move\b))"),
     "repo-mutating git command"),
    # T-5336: a shell redirect that writes into framework state. Exempt: .context/working/
    # (runtime state the framework rewrites constantly; stored lines park test output there)
    # and .context/scratch/ (gitignored).
    (re.compile(r">>?\s*['\"]?(?:\./)?(?:\$PROJECT_ROOT/|\$\{PROJECT_ROOT\}/)?"
                r"\.(?:tasks/|context/(?!working/|scratch/))"),
     "writes into .context/ or .tasks/"),
]


def unattended_refusal(line: str) -> str | None:
    """None when the line may run unattended; otherwise the reason it may not."""
    if FIXTURE_MARKER.search(line.rstrip()):
        return FIXTURE_REASON
    for pat, why in UNSAFE_PATTERNS:
        if pat.search(line):
            return why
    return None


def _now() -> str:
    return _dt.datetime.now(_dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def append_history(root: Path, runner: str, task: str, line: str,
                   outcome: str, reason: str = "") -> None:
    """Append one row. Opened in append mode only — rows are never rewritten."""
    if runner not in RUNNERS:
        raise ValueError(f"unknown runner {runner!r}")
    if outcome not in OUTCOMES:
        raise ValueError(f"unknown outcome {outcome!r}")
    path = Path(root) / HISTORY_REL
    path.parent.mkdir(parents=True, exist_ok=True)
    row = {"ts": _now(), "runner": runner, "task": task,
           "line_sha256": hashlib.sha256(line.strip().encode()).hexdigest(),
           "outcome": outcome, "reason": reason}
    with open(path, "a", encoding="utf-8") as fh:
        fh.write(json.dumps(row, sort_keys=True) + "\n")


def _main(argv: list[str]) -> int:
    if len(argv) == 2 and argv[0] == "check":
        why = unattended_refusal(argv[1])
        if why:
            print(why)
            return 3
        return 0
    if argv and argv[0] == "history":
        opts = {"--runner": None, "--task": None, "--line": None,
                "--outcome": None, "--reason": ""}
        i = 1
        while i < len(argv):
            if argv[i] in opts and i + 1 < len(argv):
                opts[argv[i]] = argv[i + 1]
                i += 2
            else:
                print(f"ERROR: unknown argument '{argv[i]}'", file=sys.stderr)
                return 2
        if None in (opts["--runner"], opts["--task"], opts["--line"], opts["--outcome"]):
            print("ERROR: --runner, --task, --line and --outcome are required", file=sys.stderr)
            return 2
        try:
            append_history(Path(os.environ.get("PROJECT_ROOT", ".")), opts["--runner"],
                           opts["--task"], opts["--line"], opts["--outcome"], opts["--reason"])
        except ValueError as e:
            print(f"ERROR: {e}", file=sys.stderr)
            return 2
        return 0
    print((__doc__ or "").split("CLI:", 1)[-1], file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(_main(sys.argv[1:]))
