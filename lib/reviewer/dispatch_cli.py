"""Dispatch mode for the reviewer (T-1951, G-066 prong 3).

CLI entry: python3 -m lib.reviewer.dispatch_cli T-XXX [--timeout N] [--json]

Spawns an isolated TermLink worker (via lib.termlink_worker.TermLinkWorker) that
runs `bin/fw reviewer T-XXX` in a separate process, then posts the full JSON
verdict to the fw bus. The caller reads results via:

    fw bus manifest T-XXX
    fw bus read T-XXX R-NNN

Single-hop guard: aborts when FW_REVIEWER_IN_DISPATCH=1 is set, preventing
recursive --dispatch loops inside worker sessions.

Sovereignty: the worker runs the same static_scan.py that the inline path
uses — verdict shape (PASS/CONCERN/FAIL, findings, auto_ticked, needs_human)
is identical. No semantic divergence.
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import uuid
from pathlib import Path

from lib.termlink_worker import TermLinkWorker

# Env-var sentinel that prevents recursive dispatch inside a worker session.
SENTINEL_ENV = "FW_REVIEWER_IN_DISPATCH"

# Temporary dir for worker scripts and verdict files.
_TMP_DIR = Path("/tmp")


def _project_root() -> Path:
    return Path(os.environ.get("PROJECT_ROOT") or os.getcwd())


def _fw_bin(root: Path) -> str:
    """Resolve the fw binary path for the current project."""
    for cand in [root / "bin" / "fw", root / ".agentic-framework" / "bin" / "fw"]:
        if cand.exists():
            return str(cand)
    return "fw"


def _write_worker_script(fw: str, task_id: str, session_name: str) -> Path:
    """Write the shell script that the TermLink worker Claude session will execute.

    The script:
    1. Runs `bin/fw reviewer <task_id> --json` (inline path, NOT --dispatch)
    2. Posts the JSON verdict to fw bus (auto-size-gated at 2KB)
    3. On reviewer failure, posts an error envelope to bus so the parent can
       surface a clean error via `fw bus manifest` rather than silently failing.
    """
    script_path = _TMP_DIR / f"fw-reviewer-worker-{session_name}.sh"
    tmp_verdict = f"/tmp/fw-reviewer-{session_name}-verdict.json"

    script_content = f"""#!/bin/bash
# TermLink reviewer worker — T-1951 dispatch mode
# FW_REVIEWER_IN_DISPATCH=1 is set — do not add --dispatch
TMP="{tmp_verdict}"
FW="{fw}"
TASK="{task_id}"

# Run inline reviewer (captures both stdout and stderr to TMP).
# T-2330 (termlink): capture RC BEFORE the test — `if ! cmd; then RC=$?`
# stores the NEGATED status (always 0 on failure), so every reviewer
# failure reported "ERROR (rc=0)" and the worker exited 0 (fail-open).
"$FW" reviewer "$TASK" --json > "$TMP" 2>&1
RC=$?
if [ "$RC" -ne 0 ]; then
    ERR=$(head -5 "$TMP" 2>/dev/null || echo "reviewer exited rc=$RC")
    "$FW" bus post --task "$TASK" --agent reviewer-dispatched \\
        --summary "reviewer: ERROR (rc=$RC)" \\
        --result "$ERR" || true
    exit "$RC"
fi

# Extract overall verdict field from JSON
OVERALL=$(python3 -c "import json; d=json.load(open('$TMP')); print(d.get('overall', 'UNKNOWN'))" 2>/dev/null || echo "UNKNOWN")

# Post full verdict blob to fw bus (>=2KB is auto-moved to blob storage)
"$FW" bus post --task "$TASK" --agent reviewer-dispatched \\
    --summary "reviewer: $OVERALL" \\
    --blob "$TMP"
"""

    script_path.write_text(script_content)
    script_path.chmod(0o755)
    return script_path


def _build_worker_prompt(script_path: Path) -> str:
    """Prompt for the Claude worker session.

    The worker executes the pre-written shell script using the Bash tool.
    FW_REVIEWER_IN_DISPATCH=1 is passed via TermLinkWorker env overlay, so
    any accidental recursive invocation is blocked.
    """
    return (
        f"Execute this shell script using the Bash tool: bash {script_path}\n"
        f"FW_REVIEWER_IN_DISPATCH=1 is already set in your environment. "
        f"Do not add --dispatch to any reviewer command.\n"
        f"Do not do anything else — just execute the script and report success or failure."
    )


def _fire_dispatch(worker: TermLinkWorker, prompt: str) -> tuple[int, str]:
    """Invoke fw termlink dispatch (non-blocking: returns once the session is spawned).

    Uses TermLinkWorker to build the dispatch argv (fw_bin resolution, env
    overlay, tag wiring). We run only the dispatch step — not the wait+replay
    step — so the parent returns immediately.

    Returns (rc, stderr) where rc=0 means the TermLink session was spawned.
    """
    argv = worker._build_dispatch_argv(prompt)
    proc = subprocess.Popen(
        argv,
        stdin=subprocess.DEVNULL,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    rc = proc.wait()
    stderr_text = proc.stderr.read() if proc.stderr else ""
    return rc, stderr_text


def main(argv: list[str] | None = None) -> int:
    argv = argv if argv is not None else sys.argv[1:]

    # ── Single-hop guard ──────────────────────────────────────────────────────
    if os.environ.get(SENTINEL_ENV):
        print(
            "ERROR: FW_REVIEWER_IN_DISPATCH=1 is set — recursive --dispatch is not "
            "allowed. Run `bin/fw reviewer T-XXX` (without --dispatch) instead.",
            file=sys.stderr,
        )
        return 3

    # ── Argument parsing ──────────────────────────────────────────────────────
    parser = argparse.ArgumentParser(
        prog="fw reviewer --dispatch",
        description="Spawn a TermLink worker to run the reviewer in isolation.",
    )
    parser.add_argument("task_id", help="Task ID to review (e.g. T-1951)")
    parser.add_argument(
        "--timeout",
        type=int,
        default=600,
        help="Worker timeout in seconds (default: 600)",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Emit dispatch status as JSON (session name, task_id)",
    )
    args = parser.parse_args(argv)

    root = _project_root()
    fw = _fw_bin(root)

    # ── Session name: task_id + random suffix for concurrency safety ──────────
    suffix = uuid.uuid4().hex[:6]
    session_name = f"reviewer-{args.task_id.lower()}-{suffix}"

    # ── Write the worker shell script ─────────────────────────────────────────
    script_path = _write_worker_script(fw, args.task_id, session_name)

    # ── Build the Claude worker prompt ────────────────────────────────────────
    prompt = _build_worker_prompt(script_path)

    # ── Create TermLinkWorker (provides fw_bin resolution + dispatch command) ──
    worker = TermLinkWorker(
        model="",
        cwd=str(root),
        task_id=args.task_id,
        name=session_name,
        env={"FW_REVIEWER_IN_DISPATCH": "1"},
        timeout=args.timeout,
        fw_bin=fw,
    )

    # ── Fire dispatch (non-blocking) ──────────────────────────────────────────
    rc, stderr_text = _fire_dispatch(worker, prompt)
    if rc != 0:
        print(
            f"ERROR: dispatch failed (rc={rc}): {stderr_text.strip()}",
            file=sys.stderr,
        )
        return 1

    # ── Surface session info to caller ────────────────────────────────────────
    if args.json:
        print(json.dumps({
            "status": "dispatched",
            "session": session_name,
            "task_id": args.task_id,
            "worker_script": str(script_path),
            "bus_channel": args.task_id,
        }))
    else:
        print(f"Dispatched:   {session_name}")
        print(f"Tags:         task:{args.task_id}, kind:reviewer")
        print(f"Observe:      termlink list")
        print(f"Read result:  {fw} bus manifest {args.task_id}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
