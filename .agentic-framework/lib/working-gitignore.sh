#!/bin/bash
# T-4231 — keep runtime state under .context/working/ out of a consumer's git.
#
# Hooks, doctor, audit, Watchtower and the budget gate write counters, locks,
# pid/url files, cursors, logs and telemetry into .context/working/. The
# framework repo ignores some of them in its ROOT .gitignore, which no consumer
# inherits; `fw init` only wrote five names. So a fresh consumer's bootstrap
# commit tracked .verb-counter/.verb-counter.lock/.budget-gate-counter, and the
# rest showed up in the audit's uncommitted-changes rail on every run. Origin:
# 1023 msg cc1a5259 item 6 (their T-126/T-127 re-probe on vendored 1.8.10).
#
# Deliberately NOT listed — these are records a project keeps in git:
# .gate-bypass-log.yaml, feedback-stream.yaml, reviewer-overrides.yaml,
# delegations.jsonl, tier0-action-events.jsonl, happiness.jsonl,
# pending-updates.yaml, arc-focus.yaml, .next-directive.yaml,
# .continuous-mode.yaml, .onboarding-complete.
#
# One list, two writers: init (fresh write) and upgrade (append-missing). The
# rules live in the nested .context/working/.gitignore, so they are relative to
# that directory. Same shape as lib/vec-index-gitignore.sh (T-3861).

FW_WORKING_IGNORE_MARKER="# T-4231: runtime state (counters, locks, pid/url, cursors, logs, telemetry)."

fw_working_ignore_rules() {
    printf '%s\n' \
        '*.lock' \
        '*.pid' \
        '*.log' \
        '*.log.*' \
        '*.tmp' \
        '*.yaml.bak' \
        '*.cursor' \
        '.*-counter' \
        '.session-baseline' \
        '.session-start-ts' \
        '.session-turn-offset' \
        '.session-metrics.yaml' \
        '.session-end-log' \
        '.transcript-path' \
        '.claude-fw-conversation' \
        '.budget-status' \
        '.budget-band-announced' \
        '.restart-requested' \
        '.auto-restart-pending' \
        '.handover-in-progress' \
        '.compact-log' \
        '.loop-detect.json' \
        '.dispatch-flag' \
        '.dispatch-approval' \
        '.approval-notified' \
        '.stop-next-nudge-at' \
        '.stop-dismissed' \
        '.continuous-halt' \
        '.continuous-mode-state.yaml' \
        '.pre-compact.last-run' \
        '.pre-compact.handover.stderr' \
        '.obs-highwater' \
        '.fabric-describe.last' \
        '.push-state.json' \
        '.verify-queue-state.json' \
        '.upstream-issues-sent' \
        '.rail-mcp-label-bypass' \
        '.bare-path-violations.yaml' \
        '.revisits-due.txt' \
        '.revisits-undated.txt' \
        '.reviewed-*' \
        '.tier0-approval' \
        '.tier0-approval.pending' \
        '.tier0-action.pending.json' \
        'tier0-action-approvals.json' \
        'watchtower.url' \
        'watchtower.port' \
        'estate-push-state.json' \
        'recall-telemetry.jsonl' \
        'continuous-run.jsonl' \
        'subagent-returns.jsonl' \
        'focus.*.yaml' \
        'decide/' \
        'episodic-gen/' \
        'litellm/' \
        'ollama-pulls/'
}

# fw_working_ensure_ignored <project_root> [--dry-run]
# Appends any missing rule to <root>/.context/working/.gitignore (created if
# absent). Prints the number of rules added (0 = already complete). Idempotent.
fw_working_ensure_ignored() {
    local root="$1" dry="${2:-}"
    local gi="$root/.context/working/.gitignore"
    local rule missing=()
    while IFS= read -r rule; do
        if [ ! -f "$gi" ] || ! grep -qxF "$rule" "$gi"; then
            missing+=("$rule")
        fi
    done < <(fw_working_ignore_rules)
    if [ "${#missing[@]}" -gt 0 ] && [ "$dry" != "--dry-run" ]; then
        mkdir -p "$root/.context/working"
        {
            # keep the appended block on its own lines even if the file lacks a final newline
            if [ -s "$gi" ] && [ -n "$(tail -c1 "$gi")" ]; then echo; fi
            [ -f "$gi" ] && grep -qxF "$FW_WORKING_IGNORE_MARKER" "$gi" || echo "$FW_WORKING_IGNORE_MARKER"
            printf '%s\n' "${missing[@]}"
        } >> "$gi"
    fi
    echo "${#missing[@]}"
}

# fw_working_tracked_runtime <project_root>
# Prints tracked files under .context/working/ that the rules above now ignore —
# an ignore rule does not untrack a file a project already committed.
fw_working_tracked_runtime() {
    local root="$1"
    git -C "$root" rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 0
    git -C "$root" ls-files -ci --exclude-standard -- .context/working 2>/dev/null
}
