#!/usr/bin/env python3
"""T-2364 (T-2158 S2) — next-directive injector for post-compact resume.

Reads `.context/working/.next-directive.yaml` (filed by operator or by a
prior auto-handover) and emits a "## Next Directive" section to stdout for
inclusion in the SessionStart `additionalContext` JSON. Also maintains the
per-resume iteration counter at `.context/working/.continuous-mode-state.yaml`.

Refuse-to-inject path: when iteration > max_iterations OR expires_at passed,
the directive section is replaced with a "LOOP TERMINATED" notice.

Exit code is always 0 — silent degradation if the file is missing or
malformed (post-compact-resume.sh treats empty stdout as no-op, matching the
rest of the hook's degrade-to-no-op posture).

Usage:
    inject-next-directive.py --project-root /path/to/project

Tests: tests/unit/test_inject_next_directive.py
"""

import argparse
import sys
from datetime import datetime, timezone
from pathlib import Path

try:
    import yaml
except ImportError:
    sys.exit(0)


def format_iso8601(value):
    """Render a value as ISO-8601 Z if it's a datetime, else str(value).
    YAML auto-coerces unquoted ISO timestamps to datetime — this normalises
    both string and datetime inputs to the same display form."""
    if value is None:
        return "unset"
    if isinstance(value, datetime):
        if value.tzinfo is None:
            value = value.replace(tzinfo=timezone.utc)
        return value.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    s = str(value).strip()
    return s if s else "unset"


def parse_iso8601(value):
    """Parse an ISO-8601 timestamp; return None on failure."""
    if value is None:
        return None
    s = str(value).strip()
    if not s:
        return None
    if s.endswith("Z"):
        s = s[:-1] + "+00:00"
    try:
        dt = datetime.fromisoformat(s)
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=timezone.utc)
        return dt
    except Exception:
        return None


def load_yaml(path):
    """Load a YAML file; return empty dict on any failure."""
    try:
        with path.open() as f:
            data = yaml.safe_load(f) or {}
        if not isinstance(data, dict):
            return {}
        return data
    except Exception:
        return {}


def write_state(path, state):
    """Write the continuous-mode state file. Silent on failure."""
    try:
        with path.open("w") as f:
            yaml.safe_dump(state, f, default_flow_style=False, sort_keys=False)
    except Exception:
        pass


def evaluate(directive_data, state_data, now_utc):
    """Compute the next state + the section to emit.

    Returns (new_state, section_text). section_text is "" if no directive
    is present (caller treats as no-op).
    """
    directive = directive_data.get("directive")
    if not isinstance(directive, str) or not directive.strip():
        return state_data, ""
    directive = directive.strip()

    old_iter_raw = state_data.get("iteration", 0)
    try:
        old_iter = int(old_iter_raw or 0)
    except (ValueError, TypeError):
        old_iter = 0
    new_iter = old_iter + 1

    max_iter_raw = directive_data.get("max_iterations")
    max_iter = None
    if max_iter_raw is not None:
        try:
            max_iter = int(max_iter_raw)
        except (ValueError, TypeError):
            max_iter = None

    expires_at = directive_data.get("expires_at")
    expires_dt = parse_iso8601(expires_at)

    tier_ceiling = directive_data.get("tier_ceiling")
    filed_by = directive_data.get("filed_by", "unknown")
    filed_at = directive_data.get("filed_at", "unknown")

    terminated_reason = None
    if max_iter is not None and new_iter > max_iter:
        terminated_reason = f"iteration {new_iter} exceeds max_iterations {max_iter}"
    elif expires_dt is not None and now_utc > expires_dt:
        terminated_reason = f"expires_at {format_iso8601(expires_at)} passed (now {now_utc.strftime('%Y-%m-%dT%H:%M:%SZ')})"

    now_iso = now_utc.strftime("%Y-%m-%dT%H:%M:%SZ")
    new_state = dict(state_data)
    new_state["iteration"] = new_iter
    new_state["last_resumed_at"] = now_iso
    new_state["last_directive_seen"] = directive[:200]
    new_state["last_terminated_reason"] = terminated_reason or ""

    if terminated_reason:
        section = (
            "## Next Directive — LOOP TERMINATED (T-2364)\n"
            "\n"
            f"The continuous-mode directive cap was reached: **{terminated_reason}**.\n"
            "\n"
            f"- Iteration counter: {new_iter}\n"
            f"- Max iterations: {max_iter if max_iter is not None else 'unset'}\n"
            f"- Expires at: {format_iso8601(expires_at)}\n"
            "\n"
            "The pre-filed directive has NOT been surfaced for auto-pickup.\n"
            "Operator continuation required: review `.context/working/.continuous-mode-state.yaml`\n"
            "and either reset the iteration counter, extend `expires_at`, or remove the\n"
            "directive file at `.context/working/.next-directive.yaml`.\n"
        )
    else:
        max_label = str(max_iter) if max_iter is not None else "∞"
        tier_label = str(tier_ceiling) if tier_ceiling is not None else "unset"
        section = (
            f"## Next Directive (iteration {new_iter}/{max_label}, tier_ceiling {tier_label})\n"
            "\n"
            f"{directive}\n"
            "\n"
            f"- Filed by: {filed_by} at {format_iso8601(filed_at)}\n"
            f"- Expires at: {format_iso8601(expires_at)}\n"
            "- State: `.context/working/.continuous-mode-state.yaml`\n"
            "- Origin: T-2363 (S1 substrate) → T-2364 (S2 injection).\n"
        )
    return new_state, section


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project-root", required=True, help="absolute path to PROJECT_ROOT")
    parser.add_argument(
        "--now",
        default=None,
        help="ISO-8601 timestamp to use as 'now' (for tests); default = utcnow()",
    )
    args = parser.parse_args(argv)

    project_root = Path(args.project_root)
    directive_file = project_root / ".context" / "working" / ".next-directive.yaml"
    state_file = project_root / ".context" / "working" / ".continuous-mode-state.yaml"

    if not directive_file.is_file():
        return 0

    directive_data = load_yaml(directive_file)
    if not directive_data:
        return 0

    state_data = load_yaml(state_file) if state_file.is_file() else {}

    if args.now:
        now_utc = parse_iso8601(args.now)
        if now_utc is None:
            now_utc = datetime.now(timezone.utc)
    else:
        now_utc = datetime.now(timezone.utc)

    new_state, section = evaluate(directive_data, state_data, now_utc)
    if not section:
        return 0

    write_state(state_file, new_state)
    sys.stdout.write(section)
    return 0


if __name__ == "__main__":
    sys.exit(main())
