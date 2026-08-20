"""Config blueprint — framework configuration visibility (T-819, T-893)."""

import os
import subprocess

import yaml as pyyaml
from flask import Blueprint

from web.shared import PROJECT_ROOT, render_page

bp = Blueprint("config", __name__)

# Known settings registry (mirrors lib/config.sh FW_CONFIG_REGISTRY)
SETTINGS = [
    ("CONTEXT_WINDOW", "300000", "Context window size for budget enforcement (tokens)"),
    ("PORT", "3000", "Watchtower web UI listen port"),
    ("RAIL_IDENTITY_FILE", "", "Project-owned termlink signing identity for outbound rail posts (T-2904). Empty = sign as host key, which is indistinguishable from co-resident agents. Created on first use."),
    ("RAIL_PROJECT_LABEL", "", "Canonical from_project label attached to outbound rail posts (T-2905). Empty = derived from the project directory name, normalised. Emitted, never typed at a call site."),
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
    ("KEYLOCK_TIMEOUT", "300", "Per-key lock stale cleanup timeout in seconds"),
    ("TERMLINK_WORKER_TIMEOUT", "600", "TermLink worker execution timeout in seconds"),
    ("HANDOVER_DEDUP_COOLDOWN", "300", "Seconds between duplicate handover detection"),
    ("INCEPTION_COMMIT_LIMIT", "2", "Max exploration commits before inception decision gate"),
    ("CONSUMER_SCAN_DIRS", "/opt", "Colon-separated directories to scan for consumer projects"),
    ("NTFY_URL", "", "ntfy server base URL for push notifications (empty = dispatcher default; each install sets its own instance, no host-local fallback; T-2439)"),
    # T-2838: both keys shipped in lib/config.sh and were honoured by the CLI while
    # never appearing on /config. tests/lint/config-registry-parity.bats has asserted
    # this parity since T-1187 and was failing unread — see T-2837.
    ("DISPATCH_MODEL_DEFAULT", "", "Default LLM model for fw termlink dispatch when --model omitted (e.g. sonnet, haiku, opus); T-1643/W3"),
    ("ARC_COMPLETION_THRESHOLD", "0.80", "Ratio of completed children at which fw audit warns an in-progress arc (G-062 mechanism #2); T-1656"),
    # T-2842: honoured by shipped code and documented in CLAUDE.md, but absent
    # from the registry — so they were env-var-only and never rendered here.
    ("BRANCH_BEHIND_WARN", "50", "Commits-behind-origin/master threshold for the branch-hygiene WARN and handover merge-back nudge; T-100143/T-100144"),
    ("STALE_ARC_DAYS", "30", "Days without a constituent-task commit before fw audit WARNs an in-progress arc as stale; T-1855"),
    ("BRANCH_STALE_DAYS", "30", "Days without a commit ON a branch before its behind-count may raise a branch-hygiene staleness finding; gates BRANCH_BEHIND_WARN so a busy master cannot make every healthy branch stale; T-3094"),
    ("RETIRE_WHEN_ADVISORY", "1", "Enable the audit retire_when advisory rail for free drivers; 0 silences the section; T-2169"),
    ("GITIGNORE_REGISTER_ADVISORY", "1", "Enable the audit WARN for .gitignore comment blocks that defer work without naming a T-/G-/OBS-/L- entry; 0 silences it; T-2994"),
    ("INDEX_STALE_DAYS", "7", "Days before fw doctor WARNs that the vector index is stale, measured from the corpus manifest's build time; T-3013"),
    ("RECALL_USAGE_DAYS", "7", "Window fw doctor looks back over for semantic-recall queries; zero rows in the window WARNs — the G-064 zero-consumer signal; T-3019"),
    ("INDEX_HANDOVERS", "1", "Include .context/handovers/ in the semantic index (web/search_utils.py:collect_files). 0 excludes them: ~90MB / 1,710 files leave fw ask, fw recall, /search and the RAG path. Reversible; deletes nothing. T-3024"),
    ("HANDOVER_DIGEST", "1", "Digest the three handover state dumps (Observation Inbox, Work in Progress, Awaiting Your Action) to count + regenerating command + top-N. 0 emits the full dumps as before. Narrative sections are unaffected either way. T-3028"),
    ("HANDOVER_DIGEST_TOP_N", "5", "How many entries each digested handover section retains in full before referring the reader to the regenerating command. T-3028"),
    ("TIER0_APPROVAL_TTL", "300", "Seconds a granted Tier 0 approval admits the command, for BOTH the 'fw tier0 approve' and Watchtower legs (agents/context/check-tier0.sh). Legacy TIER0_WATCHTOWER_TTL still wins when explicitly set. NOT the pending-request staleness window. T-3080"),
]


def _read_framework_yaml():
    """Read .framework.yaml config file, return dict or empty dict."""
    config_path = os.path.join(PROJECT_ROOT, ".framework.yaml")
    if not os.path.isfile(config_path):
        return {}
    try:
        with open(config_path) as f:
            return pyyaml.safe_load(f) or {}
    except Exception:
        return {}


def _file_val(file_data, key):
    """Look up a key in .framework.yaml data. Supports dot-notation."""
    parts = key.split(".")
    current = file_data
    for part in parts:
        if isinstance(current, dict) and part in current:
            current = current[part]
        else:
            return None
    return str(current) if current is not None else None


def _get_config():
    """Get all settings with current values and sources."""
    file_data = _read_framework_yaml()
    result = []
    for key, default, description in SETTINGS:
        env_var = f"FW_{key}"
        env_val = os.environ.get(env_var)
        if env_val is not None and env_val != "":
            current = env_val
            source = "env"
        else:
            fval = _file_val(file_data, key)
            if fval is not None:
                current = fval
                source = "file"
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


def _get_project_info():
    """Get project info and custom settings from .framework.yaml."""
    file_data = _read_framework_yaml()
    standard_keys = {"project_name", "version", "provider", "initialized_at",
                     "upgraded_from", "last_upgrade", "upstream_repo"}
    known_fw_keys = {k for k, _, _ in SETTINGS}

    project_info = {}
    for k in ["project_name", "version", "provider"]:
        if k in file_data:
            project_info[k] = file_data[k]

    # Custom settings: anything not standard and not a known FW_ key
    custom = {}
    for k, v in file_data.items():
        if k not in standard_keys and k not in known_fw_keys:
            if isinstance(v, dict):
                for sk, sv in v.items():
                    custom[f"{k}.{sk}"] = sv
            else:
                custom[k] = v

    return project_info, custom


@bp.route("/config")
def config_page():
    settings = _get_config()
    override_count = sum(1 for s in settings if s["source"] in ("env", "file"))
    warning_count = sum(1 for s in settings if s["warning"])
    project_info, custom_settings = _get_project_info()

    return render_page(
        "config.html",
        title="Configuration",
        settings=settings,
        override_count=override_count,
        warning_count=warning_count,
        total_count=len(settings),
        project_info=project_info,
        custom_settings=custom_settings,
    )
