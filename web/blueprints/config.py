"""Config blueprint — framework configuration visibility (T-819)."""

import os
import subprocess

from flask import Blueprint

from web.shared import PROJECT_ROOT, render_page

bp = Blueprint("config", __name__)

# Known settings registry (mirrors lib/config.sh FW_CONFIG_REGISTRY)
SETTINGS = [
    ("CONTEXT_WINDOW", "200000", "Context window size for budget enforcement (tokens)"),
    ("PORT", "3000", "Watchtower web UI listen port"),
    ("DISPATCH_LIMIT", "2", "Agent tool dispatches before TermLink gate triggers"),
    ("BUDGET_RECHECK_INTERVAL", "5", "Re-read transcript every N tool calls"),
    ("BUDGET_STATUS_MAX_AGE", "90", "Max seconds before cached budget status is stale"),
    ("TOKEN_CHECK_INTERVAL", "5", "Check token usage every N tool calls"),
    ("HANDOVER_COOLDOWN", "600", "Seconds between auto-handover triggers"),
    ("STALE_TASK_DAYS", "7", "Days before a task is flagged stale"),
    ("MAX_RESTARTS", "5", "Max consecutive auto-restarts"),
    ("SAFE_MODE", "0", "Bypass task gate (escape hatch)"),
    ("CALL_WARN", "40", "Tool-call count threshold for warn level (fallback)"),
    ("CALL_URGENT", "60", "Tool-call count threshold for urgent level (fallback)"),
    ("CALL_CRITICAL", "80", "Tool-call count threshold for critical level (fallback)"),
    ("BASH_TIMEOUT", "300000", "Default Bash tool timeout in milliseconds"),
]


def _get_config():
    """Get all settings with current values and sources."""
    result = []
    for key, default, description in SETTINGS:
        env_var = f"FW_{key}"
        env_val = os.environ.get(env_var)
        if env_val is not None and env_val != "":
            current = env_val
            source = "env"
        else:
            current = default
            source = "default"

        # Range validation
        warning = None
        if key == "CONTEXT_WINDOW":
            try:
                v = int(current)
                if v < 50000:
                    warning = "Very low — budget gate will fire early"
                elif v > 2000000:
                    warning = "Exceeds known model limits"
            except ValueError:
                warning = f"Not a valid integer: {current}"
        elif key == "DISPATCH_LIMIT":
            try:
                v = int(current)
                if v > 10:
                    warning = "Very high — risk of context explosion"
            except ValueError:
                warning = f"Not a valid integer: {current}"

        result.append({
            "key": key,
            "env_var": env_var,
            "default": default,
            "current": current,
            "source": source,
            "description": description,
            "warning": warning,
        })
    return result


@bp.route("/config")
def config_page():
    settings = _get_config()
    override_count = sum(1 for s in settings if s["source"] == "env")
    warning_count = sum(1 for s in settings if s["warning"])

    return render_page(
        "config.html",
        title="Configuration",
        settings=settings,
        override_count=override_count,
        warning_count=warning_count,
        total_count=len(settings),
    )
