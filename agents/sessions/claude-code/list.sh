#!/usr/bin/env python3
"""Claude Code session adapter for `fw sessions` (T-2417).

Reads `claude agents --all --json` and emits canonical JSONL on stdout per the
contract in agents/sessions/SCHEMA.md. The renderer (agents/sessions/render.py)
consumes the JSONL and prints the grouped tree.

Exit codes (per SCHEMA.md):
  0  ok (JSONL emitted; zero lines is valid)
  2  `claude` not on PATH OR `claude agents --all --json` failed
  3  `claude agents --all --json` returned malformed JSON

This file is CC-specific by design. The renderer + dispatcher stay agent-neutral
per Constitutional Directive 4 (Portability).

Empirical CC JSON shape (observed 2026-06-16, n=25 live sample):
  - kind=background sessions → `state` ∈ {blocked, done, failed}, `id` present
  - kind=interactive sessions → `status` ∈ {busy, idle}, `pid` present
  - All sessions: cwd, kind, startedAt, sessionId, name
"""
# Named .sh for adapter-protocol convention (consistent with other agent dirs);
# shebang routes to python3. Bash never executes a line here.
import json
import os
import shutil
import subprocess
import sys
import time

NOW = int(time.time())

# Map CC's native state strings to canonical state values.
#
# CC emits two distinct fields by session kind:
#   - kind=background sessions → `state` ∈ {blocked, done, failed}
#   - kind=interactive sessions → `status` ∈ {busy, idle}
# The adapter reads `state` first, falls back to `status`, then "".
STATE_MAP = {
    # background `state` values
    "blocked": "needs-input",
    "needs_input": "needs-input",
    "done": "completed",
    "failed": "completed",
    # interactive `status` values
    "busy": "working",
    "idle": "completed",
    # generic aliases
    "working": "working",
    "completed": "completed",
    "": "completed",
}


def project_for(cwd):
    """Return basename(git_toplevel) if cwd is inside a repo; else '(loose)'.

    Loose-cwd cases (per T-2416 IW-4): cwd is $HOME, /tmp, /var/tmp, or any
    path not inside a git repo.
    """
    if not cwd or not isinstance(cwd, str):
        return "(loose)"
    # Cheap pre-filter for clearly-loose paths.
    home = os.path.expanduser("~")
    if cwd in (home, "/tmp", "/var/tmp", "/", "/root"):
        return "(loose)"
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
    """Compute age_seconds from CC's startedAt / updatedAt (millis).

    Prefer updatedAt if present (last activity); fall back to startedAt.
    """
    for field in ("updatedAt", "startedAt", "statusUpdatedAt"):
        v = session.get(field)
        if isinstance(v, (int, float)) and v > 0:
            # CC emits unix millis. Convert to seconds.
            ts = int(v / 1000) if v > 1e11 else int(v)
            return max(0, NOW - ts)
    return 0


def main():
    if not shutil.which("claude"):
        print("claude-code adapter: `claude` not on PATH", file=sys.stderr)
        return 2

    try:
        result = subprocess.run(
            ["claude", "agents", "--all", "--json"],
            capture_output=True,
            text=True,
            timeout=10,
        )
    except (subprocess.TimeoutExpired, OSError) as e:
        print(f"claude-code adapter: `claude agents --all --json` failed: {e}", file=sys.stderr)
        return 2

    if result.returncode != 0:
        print(
            f"claude-code adapter: `claude agents --all --json` exit {result.returncode}",
            file=sys.stderr,
        )
        return 2

    try:
        data = json.loads(result.stdout)
    except json.JSONDecodeError as e:
        print(f"claude-code adapter: malformed JSON from `claude agents`: {e}", file=sys.stderr)
        return 3

    if not isinstance(data, list):
        print(
            f"claude-code adapter: expected JSON array, got {type(data).__name__}",
            file=sys.stderr,
        )
        return 3

    for s in data:
        if not isinstance(s, dict):
            continue
        cwd = s.get("cwd", "") or ""
        # Read state from native field by kind:
        #   background: `state` (blocked|done|failed)
        #   interactive: `status` (busy|idle)
        state_raw = (s.get("state") or s.get("status") or "").lower()
        desc_hint = ""
        if state_raw == "failed":
            desc_hint = "failed"
        out = {
            "provider": "claude-code",
            "project": project_for(cwd),
            "name": s.get("name", "") or "",
            "state": STATE_MAP.get(state_raw, "completed"),
            "age_seconds": age_seconds_for(s),
            "session_id": s.get("sessionId", "") or "",
        }
        if cwd:
            out["cwd"] = cwd
        if desc_hint:
            out["description"] = desc_hint
        sys.stdout.write(json.dumps(out, separators=(",", ":")) + "\n")

    return 0


if __name__ == "__main__":
    sys.exit(main())
