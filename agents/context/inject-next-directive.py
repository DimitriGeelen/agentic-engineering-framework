#!/usr/bin/env python3
"""T-2364/T-2365 (T-2158 S2+S3) — next-directive injector for post-compact resume.

Reads `.context/working/.next-directive.yaml` (filed by operator or by a
prior auto-handover) and emits a "## Next Directive" section to stdout for
inclusion in the SessionStart `additionalContext` JSON. Maintains the
per-resume iteration counter in `.context/working/.continuous-mode.yaml`
(unified config + runtime state — schema documented in T-2365 S3).

Behavior:
  - Continuous-mode is OFF by default (.continuous-mode.yaml has
    `enabled: false`). When OFF, this helper returns empty (no-op) even if a
    directive file is present — backward compat with all sessions pre-S3.
  - When ON, the directive is surfaced, the iteration counter advances, and
    the LOOP TERMINATED notice replaces the directive when caps are hit
    (iteration > max_iterations, or expires_at passed, or expires_after_seconds
    elapsed since the directive was filed).
  - `--source compact` resets `current_iteration` to 0 BEFORE evaluating —
    manual operator /compact starts a fresh loop. `--source resume` (or
    omitted) advances the counter as normal.
  - Exit code is always 0; degrades silently to empty stdout when any input
    is missing or malformed (matches the rest of the resume hook's posture).

Usage:
    inject-next-directive.py --project-root /path/to/project [--source compact|resume] [--now ISO8601]

Tests: tests/unit/test_inject_next_directive.py
"""

import argparse
import os
import re
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

# T-2367 (S5): first task reference in a directive, used to resolve the
# "planned next action" when the directive has no explicit `next_task:` field.
TASK_REF_RE = re.compile(r"\bT-(\d+)\b")

try:
    import yaml
except ImportError:
    sys.exit(0)


CONFIG_DEFAULTS = {
    "enabled": False,
    "max_iterations": 10,
    "tier_ceiling": 1,
    "expires_after_seconds": 86400,
    "current_iteration": 0,
}


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
    if isinstance(value, datetime):
        return value if value.tzinfo else value.replace(tzinfo=timezone.utc)
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


def read_frontmatter(path):
    """Extract the YAML frontmatter block (between the first two `---` lines)
    of a task Markdown file. Returns {} on any failure."""
    try:
        text = path.read_text()
    except Exception:
        return {}
    if not text.startswith("---"):
        return {}
    parts = text.split("\n---", 1)
    if len(parts) < 2:
        return {}
    body = parts[0]
    body = body[3:] if body.startswith("---") else body
    try:
        data = yaml.safe_load(body) or {}
        return data if isinstance(data, dict) else {}
    except Exception:
        return {}


def find_task_reference(text):
    """First `T-NNNN` reference in free text, or None."""
    m = TASK_REF_RE.search(text or "")
    return f"T-{m.group(1)}" if m else None


def resolve_task_blast_radius(project_root, task_id):
    """Pre-execution blast-radius of a planned task = its BVP F8
    `cost_estimate.blast_radius` (T-2367 / arc-012 S5).

    `fw fabric blast-radius` (named in the original filing) measures a *committed*
    git ref's downstream impact — it cannot score a not-yet-started task, so the
    bounded-autonomy ceiling reads the estimator's pre-computed blast-radius
    instead. See the task's Evolution log.

    Priority: confirmed `cost_estimate.blast_radius` → latest
    `cost_estimate_proposed[].cost_estimate.blast_radius`. Returns int or None.
    """
    if not task_id:
        return None
    for sub in ("active", "completed"):
        d = project_root / ".tasks" / sub
        if not d.is_dir():
            continue
        for f in sorted(d.glob(f"{task_id}-*.md")):
            fm = read_frontmatter(f)
            ce = fm.get("cost_estimate")
            if isinstance(ce, dict) and ce.get("blast_radius") is not None:
                v = _coerce_int(ce.get("blast_radius"), None)
                if v is not None:
                    return v
            cep = fm.get("cost_estimate_proposed")
            if isinstance(cep, list) and cep:
                last = cep[-1]
                if isinstance(last, dict) and isinstance(last.get("cost_estimate"), dict):
                    v = _coerce_int(last["cost_estimate"].get("blast_radius"), None)
                    if v is not None:
                        return v
    return None


def write_state(path, state):
    """Write the continuous-mode unified file. Silent on failure.

    T-100191: same-dir temp + os.replace — a kill mid-dump must not truncate
    the live state file (L-493 non-atomic-YAML-write class)."""
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        tmp = path.with_name(path.name + ".tmp")
        with tmp.open("w") as f:
            yaml.safe_dump(state, f, default_flow_style=False, sort_keys=False)
        os.replace(tmp, path)
    except Exception:
        pass


def _coerce_int(value, fallback):
    if value is None:
        return fallback
    try:
        return int(value)
    except (ValueError, TypeError):
        return fallback


def evaluate(directive_data, state_data, now_utc, source="resume", blast_lookup=None):
    """Compute the next state + the section to emit.

    state_data is the unified `.continuous-mode.yaml` dict (config + runtime
    state in one file, per T-2365 S3 schema).

    blast_lookup (T-2367 / S5): optional callable taking a task id and returning
    that task's blast-radius (int) or None. When provided and a tier_ceiling is
    set, the planned next task's blast-radius is compared against the ceiling;
    a breach freezes the iteration counter and replaces the directive with an
    operator-continuation notice (the bounded-autonomy ceiling). When None
    (continuous-mode loop without a resolver), no ceiling check fires.

    Returns (new_state, section_text). section_text is "" if no directive
    is present OR continuous-mode is disabled (caller treats as no-op).
    """
    new_state = dict(CONFIG_DEFAULTS)
    new_state.update(state_data)

    if not new_state.get("enabled", False):
        return new_state, ""

    directive = directive_data.get("directive")
    if not isinstance(directive, str) or not directive.strip():
        return new_state, ""
    directive = directive.strip()

    # T-2365 AC#3: `--source compact` resets the iteration counter to 0
    # BEFORE the post-resume increment, so a fresh manual /compact begins
    # a fresh loop. `--source resume` (default) advances as usual.
    if source == "compact":
        new_state["current_iteration"] = 0

    old_iter = _coerce_int(new_state.get("current_iteration", 0), 0)
    new_iter = old_iter + 1

    # Per-directive `max_iterations` overrides config when present.
    directive_max = directive_data.get("max_iterations")
    config_max = new_state.get("max_iterations")
    max_iter = _coerce_int(directive_max, _coerce_int(config_max, None))

    # Per-directive expires_at takes precedence over config-derived expiry.
    expires_at = directive_data.get("expires_at")
    expires_dt = parse_iso8601(expires_at)
    if expires_dt is None:
        secs = _coerce_int(new_state.get("expires_after_seconds"), None)
        filed_at = parse_iso8601(directive_data.get("filed_at"))
        if secs is not None and filed_at is not None:
            expires_dt = filed_at + timedelta(seconds=secs)
            expires_at = expires_dt  # display this computed value

    tier_ceiling = directive_data.get("tier_ceiling", new_state.get("tier_ceiling"))
    tier_ceiling_int = _coerce_int(tier_ceiling, None)
    filed_by = directive_data.get("filed_by", "unknown")
    filed_at = directive_data.get("filed_at", "unknown")

    # T-2404: resolve the planned-next-action task ref once, used by both the
    # ceiling check (below) and the bootstrap imperative (in the normal-path
    # section). Explicit `next_task:` field wins over the first prose T-NNNN.
    task_ref = directive_data.get("next_task") or find_task_reference(directive)

    terminated_reason = None
    if max_iter is not None and new_iter > max_iter:
        terminated_reason = f"iteration {new_iter} exceeds max_iterations {max_iter}"
    elif expires_dt is not None and now_utc > expires_dt:
        terminated_reason = (
            f"expires_at {format_iso8601(expires_at)} passed "
            f"(now {now_utc.strftime('%Y-%m-%dT%H:%M:%SZ')})"
        )

    # T-2367 (S5): bounded-autonomy ceiling. Evaluated only when the loop has
    # not already terminated on caps, a tier_ceiling is set, and a blast-radius
    # resolver is available. The "planned next action" is the directive's
    # explicit `next_task:` field, else the first T-NNNN reference in the prose.
    # A breach FREEZES the iteration counter (operator resumes the same
    # iteration after sign-off) rather than advancing it.
    ceiling_breach = None  # (task_ref, blast_radius, ceiling) when breached
    if terminated_reason is None and tier_ceiling_int is not None and blast_lookup is not None:
        if task_ref:
            blast_radius = blast_lookup(task_ref)
            if blast_radius is not None and blast_radius > tier_ceiling_int:
                ceiling_breach = (task_ref, blast_radius, tier_ceiling_int)

    now_iso = now_utc.strftime("%Y-%m-%dT%H:%M:%SZ")
    # Freeze the counter on a ceiling breach; advance otherwise.
    new_state["current_iteration"] = old_iter if ceiling_breach else new_iter
    new_state["last_resumed_at"] = now_iso
    new_state["last_directive_seen"] = directive[:200]
    if ceiling_breach:
        _ref, _br, _ceil = ceiling_breach
        new_state["last_terminated_reason"] = (
            f"tier ceiling exceeded: {_ref} blast-radius {_br} > tier_ceiling {_ceil}"
        )
    else:
        new_state["last_terminated_reason"] = terminated_reason or ""
    new_state["last_source"] = source

    if ceiling_breach:
        _ref, _br, _ceil = ceiling_breach
        section = (
            "## Next Directive — TIER CEILING EXCEEDED (T-2367)\n"
            "\n"
            f"Operator continuation required: the planned next action **{_ref}** has "
            f"blast-radius **{_br}**, which exceeds the configured `tier_ceiling` "
            f"**{_ceil}**.\n"
            "\n"
            f"- Iteration counter: {old_iter} (frozen — not advanced)\n"
            f"- Planned next action: {_ref}\n"
            f"- Blast-radius (BVP cost_estimate): {_br}\n"
            f"- Tier ceiling: {_ceil}\n"
            "\n"
            "The pre-filed directive has NOT been surfaced for auto-pickup. To "
            "proceed, the operator must either raise `tier_ceiling` in "
            "`.context/working/.continuous-mode.yaml`, narrow the planned task's "
            "scope, or run the next action manually under direct supervision.\n"
        )
        return new_state, section

    if terminated_reason:
        section = (
            "## Next Directive — LOOP TERMINATED (T-2364/T-2365)\n"
            "\n"
            f"The continuous-mode directive cap was reached: **{terminated_reason}**.\n"
            "\n"
            f"- Iteration counter: {new_iter}\n"
            f"- Max iterations: {max_iter if max_iter is not None else 'unset'}\n"
            f"- Expires at: {format_iso8601(expires_at)}\n"
            "\n"
            "The pre-filed directive has NOT been surfaced for auto-pickup.\n"
            "Operator continuation required: edit `.context/working/.continuous-mode.yaml`\n"
            "(reset `current_iteration` to 0, set `enabled: false`, or extend caps) or\n"
            "remove `.context/working/.next-directive.yaml` to drop the directive.\n"
        )
    else:
        max_label = str(max_iter) if max_iter is not None else "∞"
        tier_label = str(tier_ceiling) if tier_ceiling is not None else "unset"
        # T-2404: bootstrap imperative — the substrate delivers the directive
        # into additionalContext but nothing fires /resume or /start-work
        # afterwards (skills require explicit invocation, not hook events).
        # Without this line the loop arms but stalls waiting for human input.
        # Suppressed on TERMINATED/CEILING paths (operator-required states).
        if task_ref:
            bootstrap = (
                f"Invoke `/resume` to surface project state, then "
                f"`bin/fw work-on {task_ref}` to set focus before any edit. "
                f"The task gate (G-020) refuses Write/Edit without an active task."
            )
        else:
            bootstrap = (
                "Invoke `/resume` to surface project state, then pick a "
                "continuation from the directive above and run "
                "`bin/fw work-on T-NNNN` (or `bin/fw task create` for a new task) "
                "to set focus before any edit. The task gate (G-020) refuses "
                "Write/Edit without an active task."
            )
        section = (
            f"## Next Directive (iteration {new_iter}/{max_label}, tier_ceiling {tier_label})\n"
            "\n"
            f"{directive}\n"
            "\n"
            f"- Filed by: {filed_by} at {format_iso8601(filed_at)}\n"
            f"- Expires at: {format_iso8601(expires_at)}\n"
            f"- Source: SessionStart `{source}`\n"
            "- State: `.context/working/.continuous-mode.yaml`\n"
            "- Origin: T-2363 (S1) → T-2364 (S2) → T-2365 (S3) → T-2404.\n"
            "\n"
            "### Bootstrap (T-2404)\n"
            "\n"
            f"{bootstrap}\n"
        )
    return new_state, section


def _migrate_legacy_state(project_root, target_path):
    """If the pre-S3 `.continuous-mode-state.yaml` exists but the unified
    `.continuous-mode.yaml` doesn't, fold the legacy iteration into the new
    file so an in-flight loop survives the schema bump. One-shot — the legacy
    file is removed after the migration writes."""
    legacy = project_root / ".context" / "working" / ".continuous-mode-state.yaml"
    if not legacy.is_file() or target_path.is_file():
        return
    legacy_data = load_yaml(legacy)
    if not legacy_data:
        return
    unified = dict(CONFIG_DEFAULTS)
    unified["current_iteration"] = _coerce_int(legacy_data.get("iteration"), 0)
    for k in ("last_resumed_at", "last_directive_seen", "last_terminated_reason"):
        if legacy_data.get(k) is not None:
            unified[k] = legacy_data[k]
    unified["enabled"] = False  # default OFF — operator opts in via `fw config set`
    write_state(target_path, unified)
    try:
        legacy.unlink()
    except Exception:
        pass


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project-root", required=True, help="absolute path to PROJECT_ROOT")
    parser.add_argument(
        "--source",
        default="resume",
        choices=["resume", "compact", "startup"],
        help="SessionStart matcher: 'compact' resets the counter, 'resume' advances",
    )
    parser.add_argument(
        "--now",
        default=None,
        help="ISO-8601 timestamp to use as 'now' (for tests); default = utcnow()",
    )
    args = parser.parse_args(argv)

    project_root = Path(args.project_root)
    state_file = project_root / ".context" / "working" / ".continuous-mode.yaml"
    directive_file = project_root / ".context" / "working" / ".next-directive.yaml"

    _migrate_legacy_state(project_root, state_file)

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

    # T-2367 (S5): resolve the planned task's blast-radius from its BVP
    # cost_estimate frontmatter (see resolve_task_blast_radius docstring).
    blast_lookup = lambda task_id: resolve_task_blast_radius(project_root, task_id)
    new_state, section = evaluate(
        directive_data, state_data, now_utc, source=args.source, blast_lookup=blast_lookup
    )
    if not section:
        return 0

    write_state(state_file, new_state)
    sys.stdout.write(section)
    return 0


if __name__ == "__main__":
    sys.exit(main())
