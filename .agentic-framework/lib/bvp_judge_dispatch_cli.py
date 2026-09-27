"""Dispatch mode for the BVP score judge (T-3526), reusing T-1951's shape.

CLI entry: python3 -m lib.bvp_judge_dispatch_cli T-XXX [--timeout N] [--json]

Spawns an isolated TermLink worker (via lib.termlink_worker.TermLinkWorker) that
runs `bin/fw bvp judge T-XXX --json` in a separate process, then posts the full
JSON verdict to the fw bus. The caller reads results via:

    fw bus manifest T-XXX
    fw bus read T-XXX R-NNN

This is a deliberate structural copy of lib/reviewer/dispatch_cli.py (T-1951,
G-066 prong 3) — not a second dispatch mechanism, the SAME one applied to a
different inline command. Single-hop guard: aborts when
FW_BVP_JUDGE_IN_DISPATCH=1 is set, preventing recursive --dispatch loops inside
worker sessions.
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
SENTINEL_ENV = "FW_BVP_JUDGE_IN_DISPATCH"

_TMP_DIR = Path("/tmp")


def _project_root() -> Path:
    return Path(os.environ.get("PROJECT_ROOT") or os.getcwd())


def _fw_bin(root: Path) -> str:
    for cand in [root / "bin" / "fw", root / ".agentic-framework" / "bin" / "fw"]:
        if cand.exists():
            return str(cand)
    return "fw"


def _write_worker_script(fw: str, task_id: str, session_name: str) -> Path:
    """The script the TermLink worker Claude session executes.

    1. Runs `bin/fw bvp judge <task_id> --json` (inline path, NOT --dispatch)
    2. Posts the JSON verdict to fw bus (auto-size-gated at 2KB)
    3. On failure, posts an error envelope so the parent sees a clean error via
       `fw bus manifest` instead of silent failure — same rc-capture-before-test
       fix as T-2330 (`if ! cmd; then RC=$?` stores the NEGATED status).
    """
    script_path = _TMP_DIR / f"fw-bvp-judge-worker-{session_name}.sh"
    tmp_verdict = f"/tmp/fw-bvp-judge-{session_name}-verdict.json"

    script_content = f"""#!/bin/bash
# TermLink bvp-judge worker — T-3526 dispatch mode (T-1951 shape)
# FW_BVP_JUDGE_IN_DISPATCH=1 is set — do not add --dispatch
TMP="{tmp_verdict}"
FW="{fw}"
TASK="{task_id}"

"$FW" bvp judge "$TASK" --json > "$TMP" 2>&1
RC=$?
if [ "$RC" -ne 0 ] && [ "$RC" -ne 1 ]; then
    # rc=1 is a legitimate non-green verdict (amber/red/unknown), not a failure.
    ERR=$(head -5 "$TMP" 2>/dev/null || echo "bvp judge exited rc=$RC")
    "$FW" bus post --task "$TASK" --agent bvp-judge-dispatched \\
        --summary "bvp judge: ERROR (rc=$RC)" \\
        --result "$ERR" || true
    exit "$RC"
fi

STATE=$(python3 -c "import json; d=json.load(open('$TMP')); print(d.get('state', d.get('reason','UNKNOWN')))" 2>/dev/null || echo "UNKNOWN")

"$FW" bus post --task "$TASK" --agent bvp-judge-dispatched \\
    --summary "bvp judge: $STATE" \\
    --blob "$TMP"
"""

    script_path.write_text(script_content)
    script_path.chmod(0o755)
    return script_path


def _build_worker_prompt(script_path: Path) -> str:
    return (
        f"Execute this shell script using the Bash tool: bash {script_path}\n"
        f"FW_BVP_JUDGE_IN_DISPATCH=1 is already set in your environment. "
        f"Do not add --dispatch to any bvp judge command.\n"
        f"Do not do anything else — just execute the script and report success or failure."
    )


def _fire_dispatch(worker: TermLinkWorker, prompt: str) -> tuple[int, str]:
    argv = worker._build_dispatch_argv(prompt)
    proc = subprocess.Popen(
        argv, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
        stderr=subprocess.PIPE, text=True,
    )
    rc = proc.wait()
    stderr_text = proc.stderr.read() if proc.stderr else ""
    return rc, stderr_text


def main(argv: list[str] | None = None) -> int:
    argv = argv if argv is not None else sys.argv[1:]

    if os.environ.get(SENTINEL_ENV):
        print(
            "ERROR: FW_BVP_JUDGE_IN_DISPATCH=1 is set — recursive --dispatch is not "
            "allowed. Run `bin/fw bvp judge T-XXX` (without --dispatch) instead.",
            file=sys.stderr,
        )
        return 3

    parser = argparse.ArgumentParser(
        prog="fw bvp judge --dispatch",
        description="Spawn a TermLink worker to run the BVP score judge in isolation.",
    )
    parser.add_argument("task_id", help="Task ID to judge (e.g. T-3526)")
    parser.add_argument("--timeout", type=int, default=600,
                         help="Worker timeout in seconds (default: 600)")
    parser.add_argument("--json", action="store_true",
                         help="Emit dispatch status as JSON (session name, task_id)")
    args = parser.parse_args(argv)

    root = _project_root()
    fw = _fw_bin(root)

    suffix = uuid.uuid4().hex[:6]
    session_name = f"bvp-judge-{args.task_id.lower()}-{suffix}"

    script_path = _write_worker_script(fw, args.task_id, session_name)
    prompt = _build_worker_prompt(script_path)

    worker = TermLinkWorker(
        model="",
        cwd=str(root),
        task_id=args.task_id,
        name=session_name,
        env={SENTINEL_ENV: "1"},
        timeout=args.timeout,
        fw_bin=fw,
    )

    rc, stderr_text = _fire_dispatch(worker, prompt)
    if rc != 0:
        print(f"ERROR: dispatch failed (rc={rc}): {stderr_text.strip()}", file=sys.stderr)
        return 1

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
        print(f"Tags:         task:{args.task_id}, kind:bvp-judge")
        print(f"Observe:      termlink list")
        print(f"Read result:  {fw} bus manifest {args.task_id}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
