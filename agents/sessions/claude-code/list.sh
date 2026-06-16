#!/usr/bin/env bash
# T-2417: Claude Code session adapter for `fw sessions`.
#
# Reads `claude agents --json` and emits canonical JSONL on stdout per the
# contract in agents/sessions/SCHEMA.md. The renderer (agents/sessions/render.py)
# consumes the JSONL and prints the grouped tree.
#
# Exit codes (per SCHEMA.md):
#   0  ok (JSONL emitted; zero lines is valid)
#   2  `claude` not on PATH
#   3  `claude agents --json` returned malformed JSON
#
# This file is CC-specific by design. All other consumers (renderer, dispatcher)
# stay agent-neutral per Constitutional Directive 4 (Portability).

set -euo pipefail

if ! command -v claude >/dev/null 2>&1; then
    echo "claude-code adapter: \`claude\` not on PATH" >&2
    exit 2
fi

raw=$(claude agents --all --json 2>/dev/null) || {
    echo "claude-code adapter: \`claude agents --all --json\` failed" >&2
    exit 2
}

# Pipe to python3 for JSON->JSONL transform with project/state mapping.
# Using python3 because jq alone can't easily compute basename + git-toplevel
# checks reliably across all session cwds.
echo "$raw" | python3 - "$@" <<'PYEOF'
import json
import os
import subprocess
import sys
import time

NOW = int(time.time())

# Map CC's native state strings to canonical state values.
# CC states observed: blocked, working, done, busy. Empty/missing → completed.
STATE_MAP = {
    "blocked": "needs-input",
    "needs_input": "needs-input",
    "working": "working",
    "busy": "working",
    "done": "completed",
    "completed": "completed",
    "": "completed",
}


def project_for(cwd):
    """Return basename(git_toplevel) if cwd is inside a repo; else '(loose)'.

    Loose-cwd cases (per T-2416 IW-4): cwd is $HOME, $HOME/file, /tmp, /var/tmp,
    or any path not inside a git repo.
    """
    if not cwd or not isinstance(cwd, str):
        return "(loose)"
    # Cheap pre-filter for clearly-loose paths.
    home = os.path.expanduser("~")
    if cwd in (home, "/tmp", "/var/tmp", "/", "/root"):
        return "(loose)"
    # Try `git -C <cwd> rev-parse --show-toplevel`. If it fails or path doesn't
    # exist, it's loose.
    try:
        if not os.path.isdir(cwd):
            return "(loose)"
        result = subprocess.run(
            ["git", "-C", cwd, "rev-parse", "--show-toplevel"],
            capture_output=True,
            text=True,
            timeout=2,
        )
        if result.returncode != 0:
            return "(loose)"
        toplevel = result.stdout.strip()
        if not toplevel:
            return "(loose)"
        return os.path.basename(toplevel)
    except (subprocess.TimeoutExpired, OSError):
        return "(loose)"


def age_seconds_for(session):
    """Compute age_seconds from CC's startedAt (millis) or updatedAt.

    Prefer updatedAt if present (last activity); fall back to startedAt.
    """
    for field in ("updatedAt", "startedAt", "statusUpdatedAt"):
        v = session.get(field)
        if isinstance(v, (int, float)) and v > 0:
            # CC emits unix millis. Convert to seconds.
            ts = int(v / 1000) if v > 1e11 else int(v)
            return max(0, NOW - ts)
    return 0


try:
    data = json.loads(sys.stdin.read())
except json.JSONDecodeError as e:
    print(f"claude-code adapter: malformed JSON from `claude agents`: {e}", file=sys.stderr)
    sys.exit(3)

if not isinstance(data, list):
    print(f"claude-code adapter: expected JSON array, got {type(data).__name__}", file=sys.stderr)
    sys.exit(3)

for s in data:
    if not isinstance(s, dict):
        continue
    cwd = s.get("cwd", "") or ""
    state_raw = (s.get("state") or "").lower()
    out = {
        "provider": "claude-code",
        "project": project_for(cwd),
        "name": s.get("name", "") or "",
        "state": STATE_MAP.get(state_raw, "completed"),
        "age_seconds": age_seconds_for(s),
        "session_id": s.get("sessionId", "") or "",
    }
    # Optional fields
    if cwd:
        out["cwd"] = cwd
    # CC has no first-class "description" field on agents --json output;
    # the right-column text in the picker comes from internal state.json
    # which is not exposed here. Leave description unset for v1.
    sys.stdout.write(json.dumps(out, separators=(",", ":")) + "\n")
PYEOF
