#!/bin/bash
# lib/config.sh — 3-tier configuration resolution
#
# Pattern: explicit arg > FW_* env var > hardcoded default
#
# Usage:
#   source "$FRAMEWORK_ROOT/lib/config.sh"
#   CONTEXT_WINDOW=$(fw_config "CONTEXT_WINDOW" 300000)
#   DISPATCH_LIMIT=$(fw_config_int "DISPATCH_LIMIT" 2)
#
# Origin: T-817 inception (traceAI pattern adoption), T-819 build

[[ -n "${_FW_CONFIG_LOADED:-}" ]] && return 0
_FW_CONFIG_LOADED=1

# _fw_config_file_val KEY — read a value from .framework.yaml
# Supports dot-notation (e.g., watchtower.port) and flat keys
_fw_config_file_val() {
    local key="$1"
    local config_file="${PROJECT_ROOT:-.}/.framework.yaml"

    # Skip if no config file
    [ -f "$config_file" ] || return 1

    # For simple (non-dotted) keys, use grep for speed (no Python startup).
    # T-1557 / L-302: guard the inner grep with `|| true` so a missing key does
    # not silent-exit the calling shell under set -e -o pipefail.
    if [[ "$key" != *.* ]]; then
        local val
        val=$( { grep "^${key}:" "$config_file" 2>/dev/null || true; } | head -1 | sed "s/^${key}:[[:space:]]*//;s/[[:space:]]*$//;s/^[\"']//;s/[\"']$//")
        [ -n "$val" ] && echo "$val" && return 0
        return 1
    fi

    # For dotted keys, use Python for nested YAML lookup
    python3 - "$config_file" "$key" << 'PYVAL' 2>/dev/null
import yaml, sys
try:
    with open(sys.argv[1]) as f:
        data = yaml.safe_load(f) or {}
    parts = sys.argv[2].split('.')
    current = data
    for part in parts:
        if isinstance(current, dict) and part in current:
            current = current[part]
        else:
            sys.exit(1)
    print(current)
except:
    sys.exit(1)
PYVAL
}

# fw_config KEY DEFAULT [EXPLICIT_VALUE]
# Returns: EXPLICIT_VALUE if non-empty, else FW_KEY env var, else .framework.yaml, else DEFAULT
# _fw_registry_default KEY — the default this key declares in FW_CONFIG_REGISTRY.
# Empty when the key is not registered. Defined above fw_config because fw_config
# calls it (T-3013).
_fw_registry_default() {
    local want="$1" entry
    for entry in "${FW_CONFIG_REGISTRY[@]}"; do
        if [ "${entry%%|*}" = "$want" ]; then
            local rest="${entry#*|}"
            printf '%s' "${rest%%|*}"
            return 0
        fi
    done
    return 0
}

fw_config() {
    local key="$1"
    # T-3013 / OBS-255: `$2` was unguarded, so `fw_config KEY` — the natural call
    # when the registry already states the default — was FATAL under `set -u`,
    # which bin/fw sets globally. Fatal in the quietest possible way: an
    # unbound-variable exit is not a command failure, so `|| fallback` does not
    # catch it, and a `2>/dev/null` on the call hides the message. It surfaced as
    # `fw doctor` stopping at line 31 of 113 with exit 1 and no error text.
    #
    # With no default argument we now fall back to FW_CONFIG_REGISTRY, which is
    # where the default is written down anyway. Safe by construction: the previous
    # one-arg behaviour was a hard exit, so no caller can be relying on it.
    local default
    if [ $# -ge 2 ]; then
        default="$2"
    else
        default="$(_fw_registry_default "$key")"
    fi
    local explicit="${3:-}"

    # Tier 1: Explicit argument wins
    if [ -n "$explicit" ]; then
        echo "$explicit"
        return
    fi

    # Tier 2: Environment variable (FW_ prefix)
    local env_var="FW_${key}"
    local env_val="${!env_var:-}"
    if [ -n "$env_val" ]; then
        echo "$env_val"
        return
    fi

    # Tier 3: .framework.yaml persistent config (T-891)
    local file_val
    file_val=$(_fw_config_file_val "$key" 2>/dev/null) && [ -n "$file_val" ] && {
        echo "$file_val"
        return
    }

    # Tier 4: Default
    echo "$default"
}

# _fw_humanize_seconds SECONDS
# Render a duration in seconds as a short human phrase, for prose that quotes a
# resolved config window alongside the raw number (T-3087). Called by the Tier 0
# grant-window messages in bin/fw (tier0 approve, approvals help), both of which
# source this file first.
#
# Non-numeric or empty input echoes back unchanged: these are message strings, so
# a surprising value should surface in the text, never abort the command.
#   300 -> "5 minutes"   3600 -> "1 hour"   90 -> "1 minute 30 seconds"
_fw_humanize_seconds() {
    local total="${1:-}"
    if ! [[ "$total" =~ ^[0-9]+$ ]]; then
        echo "$total"
        return
    fi

    local unit count parts=""
    for unit in "86400:day" "3600:hour" "60:minute" "1:second"; do
        local secs="${unit%%:*}" name="${unit##*:}"
        count=$(( total / secs ))
        if [ "$count" -gt 0 ]; then
            [ "$count" -gt 1 ] && name="${name}s"
            parts="${parts}${parts:+ }${count} ${name}"
            total=$(( total - count * secs ))
        fi
    done

    echo "${parts:-0 seconds}"
}

# fw_config_int KEY DEFAULT [EXPLICIT_VALUE]
# Same as fw_config but validates the result is a non-negative integer.
# Falls back to DEFAULT on invalid input.
fw_config_int() {
    local key="$1"
    # Same unguarded-$2 hazard as fw_config (T-3013 / OBS-255).
    local default
    if [ $# -ge 2 ]; then
        default="$2"
    else
        default="$(_fw_registry_default "$key")"
    fi
    local val
    val=$(fw_config "$@")
    if ! [[ "$val" =~ ^[0-9]+$ ]]; then
        echo "WARNING: FW_$key must be a non-negative integer, got '$val' — using default $default" >&2
        echo "$default"
        return
    fi
    echo "$val"
}

# fw_hook_crash_trap — Install EXIT trap for PreToolUse hooks (T-821)
# Distinguishes "hook crashed" (exit 1) from "hook blocked" (exit 2).
# Uses EXIT (not ERR) so it only fires when the script actually exits,
# not on every intermediate command failure.
fw_hook_crash_trap() {
    local hook_name="${1:-unknown}"
    local crash_log="${PROJECT_ROOT:-.}/.context/working/.hook-crashes.log"
    # shellcheck disable=SC2154 # _exit is assigned by $? inside the trap
    trap '
        _exit=$?
        if [ $_exit -ne 0 ] && [ $_exit -ne 2 ]; then
            echo "" >&2
            echo "╔══════════════════════════════════════════════════╗" >&2
            echo "║  HOOK CRASHED: '"$hook_name"' (exit $_exit)            ║" >&2
            echo "║  This is a hook malfunction, NOT a policy block ║" >&2
            echo "║  Action: Report to human, run fw doctor         ║" >&2
            echo "╚══════════════════════════════════════════════════╝" >&2
            echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] CRASH: '"$hook_name"' exit=$_exit" >> "'"$crash_log"'" 2>/dev/null
        fi
    ' EXIT
}

# fw_config_list — List all FW_* overrides (for fw doctor / Watchtower)
# Output: KEY=VALUE lines for each FW_* env var that is set
fw_config_list() {
    env | grep "^FW_" | sort
}

# fw_consumer_yamls — Emit .framework.yaml paths for all consumer projects
# Uses FW_CONSUMER_SCAN_DIRS (colon-separated, default: /opt)
# Origin: T-1195/G-044 — replaces hardcoded /opt/* globs
fw_consumer_yamls() {
    local scan_dirs
    scan_dirs=$(fw_config "CONSUMER_SCAN_DIRS" "/opt")
    local IFS=':'
    for dir in $scan_dirs; do
        [ -d "$dir" ] || continue
        for fw_yaml in "$dir"/*/.framework.yaml; do
            [ -f "$fw_yaml" ] && echo "$fw_yaml"
        done
    done
}

# Known settings registry — used by fw doctor and Watchtower /config
# Format: KEY|DEFAULT|DESCRIPTION
FW_CONFIG_REGISTRY=(
    "CONTEXT_WINDOW|300000|Context window size for budget enforcement (tokens)"
    "PORT|3000|Watchtower web UI listen port"
    "RAIL_IDENTITY_FILE||Project-owned termlink signing identity for outbound rail posts (T-2904). Empty = sign as host key, which is indistinguishable from co-resident agents. Created on first use."
    "RAIL_PROJECT_LABEL||Canonical from_project label attached to outbound rail posts (T-2905). Empty = derived from the project directory name, normalised. Emitted, never typed at a call site."
    "DISPATCH_LIMIT|2|Agent tool dispatches before TermLink gate triggers"
    "BUDGET_RECHECK_INTERVAL|5|Re-read transcript every N tool calls"
    "BUDGET_STATUS_MAX_AGE|90|Max seconds before cached budget status is stale"
    "TOKEN_CHECK_INTERVAL|5|Check token usage every N tool calls"
    "HANDOVER_COOLDOWN|600|Seconds between auto-handover triggers"
    "STALE_TASK_DAYS|7|Days before a task is flagged stale"
    "MAX_RESTARTS|5|Max consecutive auto-restarts"
    "SAFE_MODE|0|Bypass task gate (escape hatch)"
    "CALL_WARN|40|Tool-call count threshold for warn level (fallback)"
    "CALL_URGENT|60|Tool-call count threshold for urgent level (fallback)"
    "CALL_CRITICAL|80|Tool-call count threshold for critical level (fallback)"
    "BASH_TIMEOUT|300000|Default Bash tool timeout in milliseconds"
    "KEYLOCK_TIMEOUT|300|Per-key lock stale cleanup timeout in seconds"
    "TERMLINK_WORKER_TIMEOUT|600|TermLink worker execution timeout in seconds"
    "HANDOVER_DEDUP_COOLDOWN|300|Seconds between duplicate handover detection"
    "INCEPTION_COMMIT_LIMIT|2|Max exploration commits before inception decision gate"
    "CONSUMER_SCAN_DIRS|/opt|Colon-separated directories to scan for consumer projects"
    "DISPATCH_MODEL_DEFAULT||Default LLM model for fw termlink dispatch when --model omitted (e.g. sonnet, haiku, opus). T-1643/W3."
    "ARC_COMPLETION_THRESHOLD|0.80|Ratio of completed children at which fw audit warns an in-progress arc (G-062 mechanism #2). T-1656."
    "NTFY_URL||ntfy server base URL for push notifications. Empty = let the dispatcher use its own default. Each install points at its own ntfy instance via 'fw config set NTFY_URL <url>' — portable, no host-local fallback (T-2439)."
    # T-2842: all three were read by shipped code with documented defaults and
    # described in CLAUDE.md, but had no registry entry — so `fw config set`
    # could not persist them to .framework.yaml and /config never showed them.
    # They were env-var-only, which contradicts the documented 4-tier resolution
    # (flag > env > .framework.yaml > default): the third tier did not exist.
    # Defaults below are read from the CALL SITES, not from CLAUDE.md.
    "BRANCH_BEHIND_WARN|50|Commits-behind-origin/master threshold for the branch-hygiene WARN and the handover merge-back nudge (agents/handover/handover.sh). T-100143/T-100144."
    "STALE_ARC_DAYS|30|Days without a constituent-task commit before fw audit WARNs an in-progress arc as stale (agents/audit/audit.sh). T-1855."
    "BRANCH_STALE_DAYS|30|Days without a commit ON a branch before its behind-count is allowed to raise a branch-hygiene staleness finding (lib/branch-hygiene.sh). Gates BRANCH_BEHIND_WARN: master moves ~41 commits/day here, so the commit threshold alone trips in ~1.2 days and fires on every healthy branch. Same unit and default as STALE_ARC_DAYS. T-3094 (T-3093 slice 1)."
    "RETIRE_WHEN_ADVISORY|1|Enable the audit retire_when advisory rail for free drivers; 0 silences the section entirely (agents/audit/audit.sh). T-2169."
    "GITIGNORE_REGISTER_ADVISORY|1|Enable the audit WARN for .gitignore comment blocks that defer work without naming a T-/G-/OBS-/L- entry; 0 silences it (agents/audit/audit.sh, lib/gitignore-register.sh). T-2994."
    # T-3024 (T-3022 slice E'). Handovers are 68% of indexed corpus volume and 79%
    # of its growth, ~97% redundant between consecutive files, with zero executable
    # readers (T-3022 spikes 7/9/10) — but semantic retrieval is their ONLY consumer,
    # so excluding them is a judgment about what the corpus is for, not a cleanup.
    # Ships at 1 (current behaviour); flipping it is the operator's call. Nothing is
    # deleted in either state — git retains every handover regardless.
    "INDEX_HANDOVERS|1|Include .context/handovers/ in the semantic index (web/search_utils.py:collect_files). 0 excludes them: ~90MB / 1,710 files leave fw ask, fw recall, /search and the RAG path. Reversible; deletes nothing. T-3024."
    # T-3013 (T-3005 slice 4). The vector index had no doctor coverage at all
    # before this — which is why T-3004 sat for five months. 7 days is chosen
    # against the corpus's own churn: tasks, handovers and episodics change
    # daily, so a week-old index is already answering from a different project
    # than the one you are working in.
    "INDEX_STALE_DAYS|7|Days before fw doctor WARNs that the vector index is stale, measured from the corpus manifest's build time (web/embeddings.py:index_freshness). T-3013."
    "RECALL_USAGE_DAYS|7|Window fw doctor looks back over for semantic-recall queries. Zero rows in the window WARNs — the G-064 zero-consumer signal, distinct from the index being stale (web/recall_telemetry.py:usage_summary). T-3019."
    # T-3028 (T-3025 GO, option 3). State dumps are 97.3% of a handover and the
    # three of them are byte-identical between consecutive sessions. Digesting
    # them to count + regenerating command + top-N is what stops handovers being
    # 68% of the semantic corpus. Set to 0 to restore the full dumps — subtraction
    # first, and reversible by construction, is the whole point of the ordering.
    "HANDOVER_DIGEST|1|Digest the three handover state dumps (Observation Inbox, Work in Progress, Awaiting Your Action) to count + regenerating command + top-N. 0 emits the full dumps as before. Narrative sections are unaffected either way. T-3028."
    "HANDOVER_DIGEST_TOP_N|5|How many entries each digested handover section retains in full before referring the reader to the regenerating command. T-3028."
    # T-3080. ONE window for BOTH Tier 0 approval legs. Before this the CLI leg
    # (check-tier0.sh, `fw tier0 approve` grant) carried a bare 300 literal and
    # the Watchtower leg defaulted to 3600 via TIER0_WATCHTOWER_TTL — so the path
    # that takes one click pre-authorised a destructive command for 12x as long
    # as the path that takes a typed command. A misclick is the easier mistake to
    # make, so it must carry the SHORTER window; unified at the tight leg, 300.
    # This is the GRANT clock, not the request-staleness clock (how long a pending
    # card stays offerable: web/blueprints/approvals.py EXPIRY_SECONDS, T-3079).
    "TIER0_APPROVAL_TTL|300|Seconds a granted Tier 0 approval admits the command, for BOTH the 'fw tier0 approve' and Watchtower legs (agents/context/check-tier0.sh). Legacy TIER0_WATCHTOWER_TTL still wins when explicitly set. NOT the pending-request staleness window. T-3080."
)

# fw_config_registry — Print all known settings with current values
# Output: KEY|DEFAULT|CURRENT|SOURCE|DESCRIPTION
fw_config_registry() {
    for entry in "${FW_CONFIG_REGISTRY[@]}"; do
        local key default desc
        key=$(echo "$entry" | cut -d'|' -f1)
        default=$(echo "$entry" | cut -d'|' -f2)
        desc=$(echo "$entry" | cut -d'|' -f3)

        local env_var="FW_${key}"
        local env_val="${!env_var:-}"
        local current source

        if [ -n "$env_val" ]; then
            current="$env_val"
            source="env"
        else
            local file_val
            if file_val=$(_fw_config_file_val "$key" 2>/dev/null) && [ -n "$file_val" ]; then
                current="$file_val"
                source="file"
            else
                current="$default"
                source="default"
            fi
        fi

        echo "${key}|${default}|${current}|${source}|${desc}"
    done
}
