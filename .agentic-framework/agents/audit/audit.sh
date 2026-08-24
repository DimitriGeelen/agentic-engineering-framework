#!/bin/bash
# Audit Agent - Mechanical Compliance Checks
# Evaluates framework compliance against specifications
#
# Usage:
#   audit.sh                              # Full audit with terminal output
#   audit.sh --section structure,quality   # Run only specified sections
#   audit.sh --output /path/to/dir        # Write YAML report to custom dir
#   audit.sh --quiet                      # Suppress terminal output (cron-friendly)
#   audit.sh --cron                       # Shorthand for --output .context/audits/cron --quiet
#   audit.sh schedule install|remove|status  # Manage cron schedule
#
# Sections: structure, compliance, quality, traceability, enforcement,
#           learning, episodic, observations, gaps, handover, graduation,
#           research, oe-research, discovery, discovery-trends, deployment

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FRAMEWORK_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$FRAMEWORK_ROOT/lib/paths.sh"
source "$FRAMEWORK_ROOT/lib/config.sh"
source "$FRAMEWORK_ROOT/lib/watchtower.sh"
source "$FRAMEWORK_ROOT/lib/traceability.sh"
AUDITS_DIR="$CONTEXT_DIR/audits"

# --- Schedule Subcommand (dispatch before heavy init) ---
if [ "${1:-}" = "schedule" ]; then
    shift
    # T-602: Project-specific cron filename to prevent multi-project collision
    # T-604: Cron definitions are git-tracked in PROJECT_ROOT/.context/cron/
    project_slug=$(basename "$PROJECT_ROOT" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9_-]/-/g')
    CRON_INSTALL="/etc/cron.d/agentic-audit-${project_slug}"
    CRON_SOURCE="$PROJECT_ROOT/.context/cron/agentic-audit.crontab"
    LEGACY_CRON_FILE="/etc/cron.d/agentic-audit"
    FW_PATH="$(readlink -f "$FRAMEWORK_ROOT/bin/fw" 2>/dev/null || echo "$FRAMEWORK_ROOT/bin/fw")"

    # Helper: copy project cron source to /etc/cron.d/ with sudo degradation
    _cron_copy_to_system() {
        local src="$1" dst="$2"
        if [ "$(id -u)" = "0" ]; then
            cp "$src" "$dst"
            chmod 644 "$dst"
            return 0
        elif command -v sudo >/dev/null 2>&1; then
            sudo cp "$src" "$dst"
            sudo chmod 644 "$dst"
            return 0
        else
            echo ""
            echo "NOTE: Root permissions required to install cron."
            echo "Run this command manually:"
            echo ""
            echo "  sudo cp \"$src\" \"$dst\" && sudo chmod 644 \"$dst\""
            echo ""
            return 1
        fi
    }

    # Helper: remove a system cron file with sudo degradation
    _cron_remove_from_system() {
        local dst="$1"
        if [ "$(id -u)" = "0" ]; then
            rm -f "$dst"
            return 0
        elif command -v sudo >/dev/null 2>&1; then
            sudo rm -f "$dst"
            return 0
        else
            echo "NOTE: Root permissions required to remove cron."
            echo "Run: sudo rm -f \"$dst\""
            return 1
        fi
    }

    # Generate the cron source file in PROJECT_ROOT (git-tracked)
    _cron_generate_source() {
        mkdir -p "$(dirname "$CRON_SOURCE")"
        cat > "$CRON_SOURCE" << CRONEOF
# Agentic Engineering Framework — Scheduled Audits (T-184 + T-196 + T-602 + T-604)
# Source of truth: $CRON_SOURCE (git-tracked)
# Installed to: $CRON_INSTALL (copy — use 'fw audit schedule install' to sync)
# Project: $PROJECT_ROOT
# Two audit tracks: Structural (project well-formed) + OE (controls working)
SHELL=/bin/bash
PATH=/usr/local/bin:/usr/bin:/bin

# === STRUCTURAL AUDITS (project well-formed) ===

# Task quality + structure integrity + discovery (every 30 min)
*/30 * * * * root PROJECT_ROOT="$PROJECT_ROOT" "$FW_PATH" audit --section structure,compliance,quality,discovery --cron 2>/dev/null

# Git traceability + episodic completeness + trend discoveries (hourly)
0 * * * * root PROJECT_ROOT="$PROJECT_ROOT" "$FW_PATH" audit --section traceability,episodic,discovery-trends --cron 2>/dev/null

# Observations + gaps (every 6 hours)
0 */6 * * * root PROJECT_ROOT="$PROJECT_ROOT" "$FW_PATH" audit --section observations,gaps --cron 2>/dev/null

# === OE AUDITS (controls working — T-195/T-196) ===

# Fast OE checks: CTL-001,003,004,018 + research CTL-014,021,022,023 (every 30 min)
15,45 * * * * root PROJECT_ROOT="$PROJECT_ROOT" "$FW_PATH" audit --section oe-fast,oe-research --cron 2>/dev/null

# Hourly OE checks: CTL-008,020 (hourly, offset from structural)
30 * * * * root PROJECT_ROOT="$PROJECT_ROOT" "$FW_PATH" audit --section oe-hourly --cron 2>/dev/null

# Daily OE checks: CTL-002,005,006,007,009,010,011,012,013,019,027 (daily at 7am)
0 7 * * * root PROJECT_ROOT="$PROJECT_ROOT" "$FW_PATH" audit --section oe-daily --cron 2>/dev/null

# Weekly OE checks: CTL-016 (Monday 9am)
0 9 * * 1 root PROJECT_ROOT="$PROJECT_ROOT" "$FW_PATH" audit --section oe-weekly --cron 2>/dev/null

# === FULL + MAINTENANCE ===

# Full audit — all sections (daily at 8am)
0 8 * * * root PROJECT_ROOT="$PROJECT_ROOT" "$FW_PATH" audit --cron 2>/dev/null

# Regenerate component reference docs (daily at 8:15am — T-387)
15 8 * * * root PROJECT_ROOT="$PROJECT_ROOT" "$FW_PATH" docs --all 2>/dev/null

# Retention: prune cron audit files older than 7 days (daily at 9am)
0 9 * * * root find "$CONTEXT_DIR/audits/cron" -name "*.yaml" -mtime +7 -delete 2>/dev/null
CRONEOF
    }

    case "${1:-status}" in
        install)
            if ! command -v crontab >/dev/null 2>&1 && [ ! -d /etc/cron.d ]; then
                echo "ERROR: cron not available on this system" >&2
                exit 1
            fi

            # T-3070: this command and 'fw cron install' used to be two
            # independent generators writing the SAME git-tracked source file
            # ($CRON_SOURCE) — this one from a hardcoded heredoc
            # (_cron_generate_source, below), 'fw cron install' from
            # .context/cron-registry.yaml. T-1112/T-1114 built the
            # registry-driven 'fw cron install' as the intended single
            # chokepoint, but this legacy entry point was never redirected to
            # it, so running 'fw audit schedule install' after editing the
            # registry silently reverted every registry-sourced schedule
            # fix back to the hardcoded template — confirmed live 2026-08-23
            # (three collision fixes reverted in one call). When a registry
            # exists, delegate entirely; the hardcoded heredoc path below
            # remains only for pre-T-448 consumer projects with no registry.
            if [ -f "$PROJECT_ROOT/.context/cron-registry.yaml" ]; then
                shift
                exec "$FW_PATH" cron install "$@"
            fi

            # Migrate legacy cron if present
            if [ -f "$LEGACY_CRON_FILE" ]; then
                legacy_project=$(grep -m1 'PROJECT_ROOT=' "$LEGACY_CRON_FILE" 2>/dev/null | sed 's/.*PROJECT_ROOT="\([^"]*\)".*/\1/')
                if [ -n "$legacy_project" ]; then
                    echo "NOTE: Migrating legacy cron from $LEGACY_CRON_FILE"
                    if [ "$legacy_project" = "$PROJECT_ROOT" ]; then
                        echo "  Same project — removing old file"
                        _cron_remove_from_system "$LEGACY_CRON_FILE"
                    else
                        echo "  WARNING: Legacy cron belongs to $legacy_project"
                        echo "  That project should run 'fw audit schedule install' to migrate"
                    fi
                    echo ""
                fi
            fi

            # Handle basename collision
            if [ -f "$CRON_INSTALL" ]; then
                existing_project=$(grep -m1 'PROJECT_ROOT=' "$CRON_INSTALL" 2>/dev/null | sed 's/.*PROJECT_ROOT="\([^"]*\)".*/\1/')
                if [ -n "$existing_project" ] && [ "$existing_project" != "$PROJECT_ROOT" ]; then
                    echo "WARNING: Cron file $CRON_INSTALL belongs to $existing_project"
                    echo "  Both projects share basename '$project_slug' — using hash suffix"
                    project_hash=$(echo "$PROJECT_ROOT" | md5sum | head -c 8)
                    CRON_INSTALL="/etc/cron.d/agentic-audit-${project_slug}-${project_hash}"
                fi
            fi

            # Step 1: Generate source file in project (git-tracked)
            _cron_generate_source
            echo "Cron source: $CRON_SOURCE (git-tracked)"

            # Step 2: Copy to system cron directory
            mkdir -p "$CONTEXT_DIR/audits/cron"
            if _cron_copy_to_system "$CRON_SOURCE" "$CRON_INSTALL"; then
                echo "Cron installed: $CRON_INSTALL"
            fi

            echo ""
            echo "Schedule:"
            echo "  Every 30min: structure, compliance, quality (structural)"
            echo "  :15/:45:     oe-fast, oe-research (OE — control verification)"
            echo "  Hourly:      traceability, episodic (structural)"
            echo "  :30:         oe-hourly (OE — git + cron checks)"
            echo "  Every 6h:    observations, gaps (structural)"
            echo "  Daily 7am:   oe-daily (OE — deep control checks)"
            echo "  Daily 8am:   full audit (all sections)"
            echo "  Daily 8:15:  regenerate component docs (T-387)"
            echo "  Monday 9am:  oe-weekly (OE — behavioral patterns)"
            echo "  Daily 9am:   retention cleanup (>7 days)"
            echo ""
            echo "Reports: $CONTEXT_DIR/audits/cron/"
            ;;
        remove)
            removed=false
            if [ -f "$CRON_INSTALL" ]; then
                if _cron_remove_from_system "$CRON_INSTALL"; then
                    echo "Cron schedule removed: $CRON_INSTALL"
                    removed=true
                fi
            fi
            # Also remove legacy file if it belongs to this project
            if [ -f "$LEGACY_CRON_FILE" ]; then
                legacy_project=$(grep -m1 'PROJECT_ROOT=' "$LEGACY_CRON_FILE" 2>/dev/null | sed 's/.*PROJECT_ROOT="\([^"]*\)".*/\1/')
                if [ "$legacy_project" = "$PROJECT_ROOT" ]; then
                    if _cron_remove_from_system "$LEGACY_CRON_FILE"; then
                        echo "Legacy cron schedule removed: $LEGACY_CRON_FILE"
                        removed=true
                    fi
                fi
            fi
            if [ "$removed" = false ]; then
                echo "No cron schedule installed for this project."
            fi
            echo ""
            echo "NOTE: Project source file kept at $CRON_SOURCE"
            echo "  To remove: rm \"$CRON_SOURCE\""
            ;;
        status)
            # Find this project's installed cron file
            actual_cron=""
            if [ -f "$CRON_INSTALL" ]; then
                actual_cron="$CRON_INSTALL"
            elif [ -f "$LEGACY_CRON_FILE" ]; then
                legacy_project=$(grep -m1 'PROJECT_ROOT=' "$LEGACY_CRON_FILE" 2>/dev/null | sed 's/.*PROJECT_ROOT="\([^"]*\)".*/\1/')
                if [ "$legacy_project" = "$PROJECT_ROOT" ]; then
                    actual_cron="$LEGACY_CRON_FILE"
                fi
            fi

            if [ -n "$actual_cron" ]; then
                echo "Cron schedule: INSTALLED ($actual_cron)"

                # T-604: Drift detection — compare project source vs installed copy
                if [ -f "$CRON_SOURCE" ]; then
                    if ! diff -q "$CRON_SOURCE" "$actual_cron" >/dev/null 2>&1; then
                        echo "  ⚠ DRIFT DETECTED: project source ≠ installed copy"
                        echo "  Source: $CRON_SOURCE"
                        echo "  Installed: $actual_cron"
                        echo ""
                        echo "  To sync: fw audit schedule install"
                    else
                        echo "  Source: $CRON_SOURCE (in sync)"
                    fi
                else
                    echo "  ⚠ No project source file — run 'fw audit schedule install' to generate"
                fi

                echo ""
                grep -v "^#" "$actual_cron" | grep -v "^$" | grep -v "^SHELL\|^PATH" | while read -r line; do
                    echo "  $line"
                done
                echo ""
                # Show latest cron audit
                local_latest=$(find "$CONTEXT_DIR/audits/cron/" -maxdepth 1 -name '*.yaml' -type f -print0 2>/dev/null | xargs -r -0 ls -t 2>/dev/null | head -1)
                if [ -n "$local_latest" ]; then
                    echo "Latest cron audit: $(basename "$local_latest")"
                    grep -E "^  (pass|warn|fail):" "$local_latest" 2>/dev/null | sed 's/^/  /'
                else
                    echo "No cron audit reports yet."
                fi
            else
                echo "Cron schedule: NOT INSTALLED"
                if [ -f "$CRON_SOURCE" ]; then
                    echo "  Project source exists: $CRON_SOURCE"
                    echo "  Install with: fw audit schedule install"
                else
                    echo "  Install with: fw audit schedule install"
                fi
            fi
            ;;
        *)
            echo "Usage: fw audit schedule {install|remove|status}"
            exit 1
            ;;
    esac
    exit 0
fi

# --- Argument Parsing ---
SECTIONS=""       # Comma-separated section names (empty = all)
OUTPUT_DIR=""     # Custom output directory (empty = default AUDITS_DIR)
QUIET=false       # Suppress terminal output

while [[ $# -gt 0 ]]; do
    case $1 in
        --section|--sections) SECTIONS="$2"; shift 2 ;;
        --output) OUTPUT_DIR="$2"; shift 2 ;;
        --quiet) QUIET=true; shift ;;
        --cron) OUTPUT_DIR="$CONTEXT_DIR/audits/cron"; QUIET=true; shift ;;
        -h|--help)
            echo "Usage: audit.sh [options]"
            echo ""
            echo "Options:"
            echo "  --section NAMES   Comma-separated sections to run (default: all)"
            echo "  --output DIR      Write YAML report to custom directory"
            echo "  --quiet           Suppress terminal output (for cron)"
            echo "  --cron            Shorthand for --output .context/audits/cron --quiet"
            echo ""
            echo "Sections: structure, compliance, quality, traceability, enforcement,"
            echo "          learning, episodic, observations, gaps, handover, graduation,"
            echo "          oe-research, oe-fast, oe-hourly, oe-daily, oe-weekly,"
            echo "          discovery, discovery-trends, deployment"
            echo ""
            echo "Subcommands:"
            echo "  schedule install  Install cron entries for periodic audits"
            echo "  schedule remove   Remove cron entries"
            echo "  schedule status   Show current schedule and latest results"
            exit 0
            ;;
        *) shift ;;
    esac
done

# T-1162/T-866/T-1464: flock guard + timeout — prevent zombie accumulation in cron AND
# foreground races. Cron-mode (QUIET=true) stays silent on collision; foreground prints
# a stderr message so the human knows why their audit didn't run.
#
# T-2930 / OBS-221: contention exits 75 (EX_TEMPFAIL), NOT 0, in BOTH lock modes.
#
# The bug this fixes is not "contention exits 0" — exit 0 was deliberate, for cron's
# zero-zombie contract. The bug is that ONE code carried TWO meanings, and the two
# callers need opposite things from it:
#
#   cron      wants silence      — a contended run is a non-event, not a failure
#   pre-push  wants to refuse    — a contended run means the gate DID NOT EVALUATE
#
# Under exit 0 the pre-push hook read "did not run" as "ran and passed". Observed live
# 2026-08-11: a push printed "=== Pre-Push Audit Check ===", then "Another audit is
# already running — exiting", and was allowed through while an invariant was RED
# moments earlier. Nothing in the output distinguished audited-and-clean from
# not-audited-at-all — the same false-green class as T-1376's port-3000 literal.
#
# 75 is EX_TEMPFAIL from sysexits.h: it already means transient/retry to any reader,
# where a private code like 3 would mean nothing outside this repo. Exit codes now
# partition cleanly and every caller can tell the three apart:
#
#   0   ran, no failures        1   ran, warnings        2   ran, FAILURES
#   75  DID NOT RUN — lock contention; the verdict is unknown, not clean
#
# Callers decide what "did not run" is worth. See agents/git/lib/hooks.sh (blocks) and
# the cron note below (immune — every generated audit line pipes to logger, so the
# pipeline exit code is logger's and no audit code ever reaches cron; pinned by
# tests/unit/t2930_audit_contention_exit_code.bats so that immunity stops being an
# accident that a future edit could silently revoke).
#
# Remedy shape accepted from 832 on the DM rail (539/541), filed here as OBS-224.
AUDIT_LOCK_DIR="${CONTEXT_DIR}/locks"
mkdir -p "$AUDIT_LOCK_DIR" 2>/dev/null
AUDIT_LOCK_FILE="$AUDIT_LOCK_DIR/audit.lock"

# T-3070: a full (unscoped) run walks all ~28 section headers, including a
# whole-tree secret/large-file scan and several sub-timeouts (bats 300s +
# corpus-lint 120s + corpus-health 90s) that section-scoped cron runs never
# touch. 600s is sized for those cron runs (each a handful of sections,
# minutes at most) — a full run measured on this corpus was still only
# 43% through its sections (12/28, killed mid EPISODIC MEMORY CHECKS) at
# the 590s mark, confirming 600s is not a contention artifact but simply too
# short for the unscoped case. FW_AUDIT_TIMEOUT still overrides either mode;
# FW_AUDIT_FULL_TIMEOUT is a full-run-only override for tuning without
# touching the cron-facing default.
if [ -z "$SECTIONS" ]; then
    AUDIT_TIMEOUT="${FW_AUDIT_TIMEOUT:-${FW_AUDIT_FULL_TIMEOUT:-3000}}"
else
    AUDIT_TIMEOUT="${FW_AUDIT_TIMEOUT:-600}"
fi

# Clean up stale lock files (older than timeout + 60s buffer)
if [ -f "$AUDIT_LOCK_FILE" ]; then
    lock_age=$(( $(date +%s) - $(stat -c %Y "$AUDIT_LOCK_FILE" 2>/dev/null || echo 0) ))
    if [ "$lock_age" -gt $(( AUDIT_TIMEOUT + 60 )) ]; then
        rm -f "$AUDIT_LOCK_FILE"
    fi
fi

# Use flock if available, otherwise simple lock file
if command -v flock >/dev/null 2>&1; then
    exec 200>"$AUDIT_LOCK_FILE"
    if ! flock -n 200; then
        # Another audit is running. Cron mode (QUIET=true) stays silent; foreground
        # prints to stderr so the user understands why nothing ran. Both exit 75 —
        # the code says "did not run", the caller decides what that is worth.
        if [ "$QUIET" != true ]; then
            echo "Another audit is already running — exiting (no verdict produced)" >&2
        fi
        exit 75
    fi
    # Apply timeout: kill self if still running after AUDIT_TIMEOUT seconds.
    # T-1464 + T-1772: detach EVERY inherited fd in the watchdog subshell, not
    # just stdio. The `sleep` child reparents to init when its subshell exits,
    # carrying any inherited fds — including (a) FD 200, the flock fd, which
    # silently kept the audit lock held for AUDIT_TIMEOUT (default 600s), and
    # (b) any pipe fds from a parent shell pipeline (e.g. bats's per-test pipe
    # at FD 3, which makes the bats orchestrator hang waiting for EOF). Walk
    # /proc/self/fd and close everything > 2 that we don't already redirect.
    ( for _fd in /proc/self/fd/*; do
          _n="${_fd##*/}"
          case "$_n" in 0|1|2) ;; *) eval "exec $_n>&-" 2>/dev/null ;; esac
      done
      sleep "$AUDIT_TIMEOUT" && kill -TERM $$ 2>/dev/null
    ) </dev/null >/dev/null 2>&1 &
    AUDIT_TIMEOUT_PID=$!
    trap "kill $AUDIT_TIMEOUT_PID 2>/dev/null; rm -f '$AUDIT_LOCK_FILE'" EXIT
else
    # Fallback: simple lock file (less robust but prevents most zombies).
    # Same 75 as the flock arm — "in ALL modes" is the point. A fix applied to only
    # the arm the developer's host happens to take leaves the other silently on the
    # old contract, and flock's presence varies by platform (it is the arm a mac or
    # a slim container is most likely to miss).
    if [ -f "$AUDIT_LOCK_FILE" ]; then
        if [ "$QUIET" != true ]; then
            echo "Another audit is already running — exiting (no verdict produced)" >&2
        fi
        exit 75
    fi
    echo $$ > "$AUDIT_LOCK_FILE"
    trap "rm -f '$AUDIT_LOCK_FILE'" EXIT
fi

# Section filter: returns 0 (true) if section should run
should_run_section() {
    [ -z "$SECTIONS" ] && return 0
    echo ",$SECTIONS," | grep -q ",$1,"
}

# Colors provided by lib/colors.sh (via paths.sh chain)

# Counters
PASS_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0
# T-3126: FAIL_COUNT partitioned by scope. Their sum equals FAIL_COUNT.
FAIL_REF_COUNT=0
FAIL_WORKTREE_COUNT=0
declare -a FAIL_WORKTREE_TITLES

# Priority actions
declare -a PRIORITY_ACTIONS

# Findings for history (format: "LEVEL|CHECK|MESSAGE")
declare -a FINDINGS

# Timestamp for this audit
AUDIT_TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
AUDIT_DATE=$(date +"%Y-%m-%d")
AUDIT_DATETIME=$(date +"%Y-%m-%d-%H%M")

# Logging functions
pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    PASS_COUNT=$((PASS_COUNT + 1))
    FINDINGS+=("PASS|$1|")
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
    echo "       Evidence: $2"
    echo "       Mitigation: $3"
    WARN_COUNT=$((WARN_COUNT + 1))
    PRIORITY_ACTIONS+=("$3")
    FINDINGS+=("WARN|$1|$3")
}

# T-3126: findings carry their SCOPE.
#
# The audit reads the working tree; that is what a health check is for. But the
# pre-push gate consumes this audit to decide a REF operation, and a FAIL owned
# by uncommitted edits, untracked files, or host state is not a property of the
# commit being pushed. Observed live 2026-08-23: two FAILs from a concurrent
# session's uncommitted bin/fw + agents/audit/audit.sh and two untracked
# tests/lint/*.bats files refused a push of a ref containing neither.
#
# The partition is emitted, not enforced, here. Verdicts are untouched: a FAIL is
# still a FAIL, still counted, still exit 2. Only the fourth argument is new, and
# it defaults to "ref" so every existing call site keeps blocking exactly as
# before. Callers that can PROVE a finding cannot be in any ref pass "worktree".
#
#   fail "<title>" "<evidence>" "<mitigation>" [ref|worktree] [<reason>]
fail() {
    local _scope="${4:-ref}" _reason="${5:-}"
    case "$_scope" in ref|worktree) ;; *) _scope="ref" ;; esac
    echo -e "${RED}[FAIL]${NC} $1"
    echo "       Evidence: $2"
    echo "       Mitigation: $3"
    if [ "$_scope" = "worktree" ]; then
        echo "       Scope: worktree${_reason:+ ($_reason)} — not present in any committed ref"
        FAIL_WORKTREE_COUNT=$((FAIL_WORKTREE_COUNT + 1))
        FAIL_WORKTREE_TITLES+=("$1")
    else
        echo "       Scope: ref — property of committed content"
        FAIL_REF_COUNT=$((FAIL_REF_COUNT + 1))
    fi
    FAIL_COUNT=$((FAIL_COUNT + 1))
    PRIORITY_ACTIONS+=("$3")
    FINDINGS+=("FAIL|$1|$3")
}

info() {
    echo -e "${CYAN}[INFO]${NC} $1"
    PASS_COUNT=$((PASS_COUNT + 1))
    FINDINGS+=("INFO|$1|")
}

# --- Verdict-over-a-set emitters (T-3105) ---
#
# THE RULE: a check may only PASS over the set it actually evaluated, and must
# report that set's size. An empty or unenumerable candidate set is a WARN, not
# a PASS.
#
# Origin — three same-day instances of one class. None of them lied; each was
# true of what it looked at. The defect is that none STATED what it looked at,
# so "I found nothing" and "I looked nowhere" rendered identically:
#
#   1. The GO-scope-not-propagated scan (repaired by hand in T-3099) gated on a
#      prose phrase matching 2 of 444 completed inceptions, and 0 after the next
#      filter. Its candidate set was empty by construction, so every PASS it ever
#      printed asserted nothing — with 179 approved inceptions invisible behind
#      it.
#   2. This file's duplicate-task-ID check scans the main checkout only. Three
#      duplicate IDs living in worktree replicas were invisible for seven weeks
#      while it printed PASS.
#   3. Off-framework sibling: an errors store that returns "No errors found"
#      when it cannot read the store — byte-identical to a genuinely clean run.
#
# "No duplicate task IDs" is not falsifiable. "No duplicate task IDs among 3124
# task file(s)" is: a reader who believes the corpus is larger than 3124 now has
# something to disagree with. That is the whole point — the count is not
# decoration, it is the claim's scope, and a claim without a scope cannot be
# wrong, which is why it also cannot be trusted.
#
#   pass_over <count> "<set-description>" "<message>" [<evidence>] [<mitigation>]
#     count > 0         -> pass "<message> — examined <count> <set-description>"
#     count == 0        -> warn "<message> — NOT EVALUATED: candidate set empty"
#     empty/non-numeric -> routed to warn_unenumerable (see below)
#
#   warn_unenumerable "<source>" "<message>" [<evidence>] [<mitigation>]
#     -> warn "<message> — NOT EVALUATED: could not read <source>"
#
# Two verbs rather than one, because the two failures are known at different
# moments. "The set was empty" is known AFTER enumeration returns a number.
# "Could not enumerate" is known BEFORE any number exists — a missing store, an
# unreadable path, an absent dependency, a `$(python3 ... 2>/dev/null)` that
# collapsed to the empty string. T-3099's hand implementation had exactly this
# two-part shape: it tested for an empty pre-scan summary and warned, then
# parsed the counts and branched on zero. Folding both into one verb would force
# every caller to invent a sentinel count for "I never got one", and the obvious
# sentinel — 0 — is precisely the value that must NOT be conflated with it.
#
# pass_over therefore routes a non-numeric count to warn_unenumerable rather
# than trusting it: a caller whose command substitution collapsed to "" must not
# be reported as having measured a set of size 0. It measured nothing.
#
# Both paths WARN, never FAIL. audit's exit code 2 means a real failure; a check
# that did not evaluate is an unknown, and an unknown that exits 2 would train
# readers to ignore it. The same reasoning as the audit's own lock-contention
# exit 75 above: "did not run" is its own verdict, distinct from both pass and
# fail.
pass_over() {
    local _count="${1//[[:space:]]/}" _set="$2" _msg="$3" _evidence="${4:-}" _mitigation="${5:-}"
    case "$_count" in
        ''|*[!0-9]*)
            warn_unenumerable "$_set" "$_msg" "$_evidence" "$_mitigation"
            return
            ;;
    esac
    if [ "$_count" -gt 0 ]; then
        pass "$_msg — examined $_count $_set"
    else
        warn "$_msg — NOT EVALUATED: candidate set empty (0 $_set)" \
             "${_evidence:-The check ran and found nothing, because there was nothing to look at. A PASS here would assert coverage the check does not have (T-3105).}" \
             "${_mitigation:-Confirm that 0 $_set is the real corpus state and not a mis-scoped enumeration or a predicate that matches nothing}"
    fi
}

# --- T-3126 scope predicates -------------------------------------------------
#
# Three helpers, all fail-safe: when they cannot answer, they answer "ref", so an
# unanswerable question keeps the pre-push gate blocking. A gate that could not
# decide is not a gate that passed (same reasoning as the exit-75 branch above).
#
# $1 is a git work tree root for every one of them; callers pass the root of the
# tree the check actually read (FRAMEWORK_ROOT for the vendored/lint checks),
# because in a split-root consumer that is a different repo from PROJECT_ROOT.

# 0 when <root> is a usable git work tree with a resolvable HEAD.
_t3126_git_ok() {
    git -C "$1" rev-parse --verify -q HEAD >/dev/null 2>&1
}

# 0 when <root>/<rel> is NOT in HEAD, or differs from its HEAD blob. i.e. "this
# path's current bytes exist nowhere in the committed history of this branch".
_t3126_path_uncommitted() {
    local _root="$1" _rel="$2"
    git -C "$_root" rev-parse -q --verify "HEAD:$_rel" >/dev/null 2>&1 || return 0
    git -C "$_root" diff --quiet HEAD -- "$_rel" 2>/dev/null || return 0
    return 1
}

# 0 when the self-vendor pair <rel> vs .agentic-framework/<rel> ALSO drifts in
# HEAD — i.e. the drift is committed and a consumer vendoring from origin would
# inherit it. Mirrors T-3125's _t3125_committed_drift decision (missing-dest
# counts as drift, because vendor-self syncs on absent OR different).
_t3126_pair_drifts_in_head() {
    local _root="$1" _rel="$2" _src _ven
    _src=$(git -C "$_root" rev-parse -q --verify "HEAD:$_rel" 2>/dev/null || true)
    _ven=$(git -C "$_root" rev-parse -q --verify "HEAD:.agentic-framework/$_rel" 2>/dev/null || true)
    # Neither side is in HEAD at all: the pair is entirely uncommitted, so no ref
    # carries this drift.
    [ -z "$_src" ] && [ -z "$_ven" ] && return 1
    [ "$_src" = "$_ven" ] && return 1
    return 0
}

warn_unenumerable() {
    local _source="$1" _msg="$2" _evidence="${3:-}" _mitigation="${4:-}"
    warn "$_msg — NOT EVALUATED: could not read $_source" \
         "${_evidence:-Enumeration of $_source failed or returned nothing parseable, so this check produced no verdict at all (T-3105).}" \
         "${_mitigation:-Repair or restore $_source, then re-run — this check asserts nothing until its candidate set can be enumerated}"
}

# --- New Project Grace Period (T-301) ---
# Detect new projects: <5 commits and no handover → suppress known day-1 noise
IS_NEW_PROJECT=false
_commit_count=$(git -C "$PROJECT_ROOT" rev-list --count HEAD 2>/dev/null || echo "0")
if [ "$_commit_count" -lt 5 ] && [ ! -f "$CONTEXT_DIR/handovers/LATEST.md" ]; then
    IS_NEW_PROJECT=true
fi

# Grace-aware warn/fail: downgrades to info for new projects
grace_warn() {
    if [ "$IS_NEW_PROJECT" = true ]; then
        info "$1 (grace: new project)"
    else
        warn "$1" "$2" "$3"
    fi
}
grace_fail() {
    if [ "$IS_NEW_PROJECT" = true ]; then
        info "$1 (grace: new project)"
    else
        fail "$1" "$2" "$3"
    fi
}

# T-2228 (T-2225 Slice 3): test-sentinel filter — skip T-Test-NNN files that
# may have leaked from tests into PROJECT_ROOT (tmp_project_root helper bypass).
# Real tasks are filed via `fw work-on` / `fw task create` which emit numeric
# T-NNNN ids; the `T-Test-` prefix is reserved for test fixtures.
_is_test_sentinel() {
    local name="${1##*/}"
    case "$name" in
        T-Test-*) return 0 ;;
        *) return 1 ;;
    esac
}

# Quiet mode: suppress terminal output (findings still collected for YAML)
if [ "$QUIET" = true ]; then
    exec 3>&1 1>/dev/null
fi

# Header
echo "=== AUDIT REPORT ==="
echo "Timestamp: $(date -Iseconds)"
echo "Project: $PROJECT_ROOT"
[ -n "$SECTIONS" ] && echo "Sections: $SECTIONS"
echo ""

# --- Task File Scans (T-955) ---
# Single-pass Python scans replace 8 separate bash loops over task files.
# Each scan runs once, results reused by multiple sections.

# Active task scan: replaces loops 1/2/5/9/10 (compliance, quality, research, ownership, D2)
ACTIVE_SCAN=""
if should_run_section "compliance" || should_run_section "quality" || should_run_section "oe-research" || should_run_section "oe-daily" || should_run_section "discovery" || should_run_section "discovery-trends"; then
    ACTIVE_SCAN=$(python3 "$FRAMEWORK_ROOT/agents/audit/active-task-scan.py" \
        "$TASKS_DIR" "$PROJECT_ROOT/docs/reports" 2>/dev/null || echo "")
fi

# Completed task scan: replaces loops 3/4/7 (episodic, research artifacts, AC gate)
# T-1882: also populated when "compliance" section is requested — CTL-028 (status-
# drift detection) moved to compliance gate so pre-push audit catches the drift
# class before ship rather than only at oe-daily cron run (was: up to 24h window).
COMPLETED_SCAN=""
if should_run_section "episodic" || should_run_section "research" || should_run_section "oe-daily" || should_run_section "compliance"; then
    COMPLETED_SCAN=$(python3 "$FRAMEWORK_ROOT/agents/audit/completed-task-scan.py" \
        "$TASKS_DIR" "$CONTEXT_DIR/episodic" "$PROJECT_ROOT/docs/reports" 2>/dev/null || echo "")
fi

# ============================================
# SECTION 1: STRUCTURE CHECKS
# ============================================
if should_run_section "structure"; then
echo "=== STRUCTURE CHECKS ==="

# Check .tasks/ directory
if [ -d "$TASKS_DIR" ]; then
    pass "Tasks directory exists"
else
    fail "Tasks directory missing" \
         ".tasks/ not found" \
         "Run: mkdir -p .tasks/{active,completed,templates}"
fi

# Check subdirectories
for subdir in active completed templates; do
    if [ -d "$TASKS_DIR/$subdir" ]; then
        pass "Tasks/$subdir directory exists"
    else
        warn "Tasks/$subdir directory missing" \
             ".tasks/$subdir not found" \
             "Run: mkdir -p .tasks/$subdir"
    fi
done

# Check template exists
if [ -f "$TASKS_DIR/templates/default.md" ]; then
    pass "Task template exists"
else
    warn "Task template missing" \
         ".tasks/templates/default.md not found" \
         "Copy zzz-default.md to .tasks/templates/default.md"
fi

# T-1279 (G-052) / T-3107 (slice 2 of 3): duplicate task IDs, over the WHOLE
# corpus rather than the main checkout alone.
#
# A git worktree checks out its own snapshot of `.tasks/`, so "the task corpus"
# is the UNION of every worktree's view (see fw_task_view_dirs, lib/paths.sh,
# T-3104). Scanning one view printed "No duplicate task IDs" for seven weeks
# while T-2505, T-2506 and T-2428 each named a DIFFERENT task in a worktree
# replica.
#
# THE DISCRIMINATOR IS IDENTITY, NOT CONTENT. Git hands the same committed task
# to every worktree, and a worktree pinned to an older commit holds an older
# REVISION of that task — same task, different bytes. On this repo's corpus a
# content-hash compare yields 2744 findings and dies of irrelevance; `created:`
# (fixed at allocation, never rewritten) yields exactly 3 — the three known
# collisions, zero false positives. Falls back to the filename slug for the 18
# legacy files with no parseable `created:`. Do not "simplify" this back to a
# hash compare; tests/unit/t3107_corpus_duplicate_ids.bats tests 5-7 pin it.
#
# Four classes, three verdicts:
#   same ID twice INSIDE one view      -> FAIL (allocator bug, live)
#   across views, identity differs     -> WARN (fork artifact: two tasks, one number)
#   across views, identity same        -> silent, counted as differing revisions
#   across views, byte-identical       -> silent, counted as replication
# The FAIL and the WARN are emitted independently: an ID can be both, and
# neither may mask the other (test 7).
if ! declare -F fw_task_view_dirs >/dev/null 2>&1; then
    warn_unenumerable "the corpus view set" \
         "No duplicate task IDs" \
         "fw_task_view_dirs is undefined — lib/paths.sh is stale relative to this audit (T-3104 lifted the view enumerator there). The corpus could not be enumerated, so this check asserted nothing." \
         "Run 'fw upgrade' (or re-sync lib/paths.sh) so fw_task_view_dirs is defined, then re-run the audit"
else
    dup_views=$(fw_task_view_dirs 2>/dev/null)
    if [ -z "$dup_views" ]; then
        warn_unenumerable "the corpus view set" \
             "No duplicate task IDs" \
             "fw_task_view_dirs returned zero views. Even a repo with no worktrees must yield the local view, so an empty set means the enumeration is broken, not that the corpus is empty." \
             "Check 'git worktree list' and TASKS_DIR resolution, then re-run the audit"
    else
        dup_py=$(cat <<'DUP_PY'
import hashlib, os, re, sys
from collections import defaultdict

ID_RE = re.compile(r'^id:\s*(T-\d+)\s*$')
CREATED_RE = re.compile(r'^created:\s*(.+?)\s*$')
SLUG_RE = re.compile(r'^T-\d+-(.*)\.md$')

views, seen = [], set()
for line in sys.stdin:
    v = line.strip()
    if not v or not os.path.isdir(v):
        continue
    real = os.path.realpath(v)
    if real in seen:
        continue
    seen.add(real)
    views.append(v)

# record: (view, path, created, slug, content-hash)
by_id = defaultdict(list)
for view in views:
    for sub in ('active', 'completed'):
        d = os.path.join(view, sub)
        if not os.path.isdir(d):
            continue
        for f in sorted(os.listdir(d)):
            if not f.startswith('T-') or not f.endswith('.md'):
                continue
            path = os.path.join(d, f)
            try:
                with open(path, 'rb') as fh:
                    raw = fh.read()
            except Exception:
                continue
            text = raw.decode('utf-8', 'replace')
            tid = created = None
            for i, line in enumerate(text.splitlines()):
                if i > 30:
                    break
                m = ID_RE.match(line)
                if m and tid is None:
                    tid = m.group(1)
                m = CREATED_RE.match(line)
                if m and created is None:
                    val = m.group(1).strip().strip('"').strip("'")
                    if val and val.lower() not in ('null', '~'):
                        created = val
            if tid is None:
                continue
            sm = SLUG_RE.match(f)
            slug = sm.group(1) if sm else f
            by_id[tid].append((view, path, created, slug,
                               hashlib.sha256(raw).hexdigest()))

files = sum(len(v) for v in by_id.values())
within_lines, fork_lines = [], []
n_identical = n_revisions = n_within = n_forks = 0

for tid in sorted(by_id, key=lambda t: (len(t), t)):
    recs = by_id[tid]

    # (a) same ID twice inside one view -> FAIL. Reported once per ID, not once
    #     per view: git replicates the offending pair into every worktree, so
    #     per-view reporting would multiply one allocator bug by the view count.
    per_view = defaultdict(list)
    for r in recs:
        per_view[r[0]].append(r)
    offending = sorted(p for v in per_view.values() if len(v) > 1 for p in (r[1] for r in v))
    if offending:
        n_within += 1
        within_lines.append('WITHIN %s (same ID twice inside one corpus view)' % tid)
        within_lines.extend('    - %s' % p for p in offending)

    # (b) across views: same task, or two tasks on one number?
    if len(per_view) < 2:
        continue
    by_created = all(r[2] for r in recs)
    ident = (lambda r: r[2]) if by_created else (lambda r: r[3])
    if len(set(ident(r) for r in recs)) > 1:
        n_forks += 1
        fork_lines.append('FORK %s (identity differs by %s)'
                          % (tid, 'created:' if by_created else 'filename slug'))
        for r in sorted(recs, key=lambda r: r[1]):
            fork_lines.append('    - %s  [%s]'
                              % (r[1], r[2] if by_created else 'slug: ' + r[3]))
    elif len(set(r[4] for r in recs)) == 1:
        n_identical += 1
    else:
        n_revisions += 1

print('=== WITHIN ===')
print('\n'.join(within_lines))
print('=== FORK ===')
print('\n'.join(fork_lines))
print('=== STATS ===')
print('files=%d views=%d identical=%d revisions=%d within=%d forks=%d'
      % (files, len(views), n_identical, n_revisions, n_within, n_forks))
DUP_PY
)
        dup_output=$(printf '%s\n' "$dup_views" | python3 -c "$dup_py" 2>&1)
        dup_rc=$?
        dup_stats=$(printf '%s\n' "$dup_output" | sed -n '/^=== STATS ===$/,$p' | sed -n '2p')
        if [ $dup_rc -ne 0 ] || [ -z "$dup_stats" ]; then
            warn_unenumerable "the corpus view set" \
                 "No duplicate task IDs" \
                 "The corpus scanner exited $dup_rc with no STATS line. First 5 lines of its output: $(printf '%s\n' "$dup_output" | head -5)" \
                 "Re-run the scanner by hand over 'fw_task_view_dirs' output to see the error, then re-run the audit"
        else
            dup_field() { printf '%s\n' "$dup_stats" | tr ' ' '\n' | sed -n "s/^$1=//p"; }
            dup_files=$(dup_field files); dup_nviews=$(dup_field views)
            dup_ident=$(dup_field identical); dup_revs=$(dup_field revisions)
            dup_within=$(printf '%s\n' "$dup_output" | sed -n '/^=== WITHIN ===$/,/^=== FORK ===$/p' | sed '1d;$d' | grep -v '^$')
            dup_forks=$(printf '%s\n' "$dup_output" | sed -n '/^=== FORK ===$/,/^=== STATS ===$/p' | sed '1d;$d' | grep -v '^$')
            dup_nforks=$(dup_field forks)

            [ -n "$dup_within" ] && fail "Duplicate task IDs detected (G-052)" \
                 "$dup_within" \
                 "Rename one of each pair: edit filename AND 'id:' frontmatter to a fresh T-NNNN"

            [ -n "$dup_forks" ] && warn "Cross-view task-ID collisions: $dup_nforks ID(s) name a different task in another corpus view" \
                 "$dup_forks" \
                 "Two tasks were minted onto one number across views (L-506 leg 2). Re-number the losing side in its worktree, or land/discard that worktree so the corpus holds one task per ID"

            if [ -z "$dup_within" ] && [ -z "$dup_forks" ]; then
                dup_set="task file(s) across $dup_nviews corpus view(s)"
                if [ "${dup_ident:-0}" -gt 0 ] || [ "${dup_revs:-0}" -gt 0 ]; then
                    dup_set="$dup_set ($dup_ident ID(s) byte-identical in every view, $dup_revs same-task at differing revisions)"
                fi
                pass_over "$dup_files" \
                     "$dup_set" \
                     "No duplicate task IDs" \
                     "Scanned every view fw_task_view_dirs enumerated, not just the main checkout (T-3107). Replication across views is counted, not reported — only a differing identity is a finding." \
                     "An empty or single-view corpus where you expect worktrees means the enumeration is mis-rooted — check 'git worktree list' and TASKS_DIR"
            fi
        fi
    fi
fi
# end duplicate-task-ID scan

# Validate all project YAML files parse correctly (T-207 regression test).
# T-1816: extended to .context/arcs/ — broken arc YAML silently 404s the
# /arcs/<id> page AND silently excludes the arc from the /arcs list page
# (try/except in web/blueprints/arcs.py:_list_arcs swallows the parse error).
yaml_fail_count=0
yaml_pass_count=0
for yaml_dir in "$PROJECT_ROOT/.context/project" "$PROJECT_ROOT/.context/arcs"; do
    [ -d "$yaml_dir" ] || continue
    for yf in "$yaml_dir"/*.yaml; do
        [ -f "$yf" ] || continue
        yf_name=$(basename "$yf")
        yf_rel="${yf#$PROJECT_ROOT/}"
        parse_err=$(python3 -c "
import yaml, sys
try:
    with open('$yf') as f:
        data = yaml.safe_load(f)
    if data is None:
        print('empty-file'); sys.exit(1)
    elif not isinstance(data, dict):
        print('not-a-mapping'); sys.exit(1)
except yaml.YAMLError as e:
    print(str(e).split(chr(10))[0]); sys.exit(1)
" 2>&1)
        # shellcheck disable=SC2181 # $? needed: parse_err captures output, exit code checked separately
        if [ $? -eq 0 ]; then
            yaml_pass_count=$((yaml_pass_count + 1))
        else
            yaml_fail_count=$((yaml_fail_count + 1))
            fail "YAML parse error: $yf_name" \
                 "$parse_err" \
                 "Fix the YAML syntax in $yf_rel (quote values containing ':' or '#')"
        fi
    done
done
# T-2456 (OBS-084): .context/inbox.yaml is a single top-level file (not under
# .context/project or .context/arcs), so the per-dir loop above never validated
# it. A note body with a backslash (e.g. a regex '\d+') written via `fw note`
# corrupted it as a YAML double-quoted-scalar escape error — and it sat unreadable
# for ~a day because no gate parsed it (`fw note list/triage` crashed, the audit
# was blind). Validate it explicitly with the same logic + counters so the
# pass-count message covers it and a future corruption FAILs the audit.
inbox_yaml="$PROJECT_ROOT/.context/inbox.yaml"
if [ -f "$inbox_yaml" ]; then
    parse_err=$(python3 -c "
import yaml, sys
try:
    with open('$inbox_yaml') as f:
        data = yaml.safe_load(f)
    if data is None:
        print('empty-file'); sys.exit(1)
    elif not isinstance(data, dict):
        print('not-a-mapping'); sys.exit(1)
except yaml.YAMLError as e:
    print(str(e).split(chr(10))[0]); sys.exit(1)
" 2>&1)
    # shellcheck disable=SC2181 # $? needed: parse_err captures output, exit code checked separately
    if [ $? -eq 0 ]; then
        yaml_pass_count=$((yaml_pass_count + 1))
    else
        yaml_fail_count=$((yaml_fail_count + 1))
        fail "YAML parse error: inbox.yaml" \
             "$parse_err" \
             "Fix .context/inbox.yaml — a note body with a backslash/quote corrupts it (T-2456); fw note now escapes new entries"
    fi
fi
if [ "$yaml_fail_count" -eq 0 ]; then
    pass_over "$yaml_pass_count" "project YAML file(s)" "All project YAML files parse correctly" \
         "" "No YAML files were found to parse — check that .context/, policy/ and .context/arcs/ exist and are populated"
fi

# T-2067: task-frontmatter parse check.
# A mangled `components:` list (or any other YAML break) in a task file
# made Watchtower `/review/T-XXX` render the "Task Not Found" 404 page —
# parse_frontmatter returns False (or empty dict on yaml.ScannerError),
# the route never reaches the 200-for-completed branch. Origins:
#   - T-2067: update-task.sh:1731 components-regex didn't handle
#     flow-style continuation lines; 4 corpus victims silently accumulated
#     (T-2018, T-2059, T-2060, T-2061).
#   - T-2069: `description: >` folded scalar terminated by blank line,
#     then col-0 numbered list interpreted as YAML keys; 1 corpus victim
#     (T-1845). Audit returns `{}` empty dict on yaml.ScannerError —
#     `if fm:` catches via Python truthiness but the diagnostic mis-attributed
#     it to the components-regex class. Tightened to distinguish False vs
#     empty-dict and mention both origin classes.
fm_fail_count=0
fm_fail_list=""
fm_trunc_count=0
fm_trunc_list=""
# T-2297: single batched python3 invocation (was per-file fork — 1 process per
# task file, ~178ms python+yaml startup × 2,261 files = 6.7 min on the audit's
# pre-push --section structure path). One fork now: file paths stream via stdin,
# python emits per-file rc<TAB>path lines; bash aggregates. Per-file rc semantics
# preserved exactly (0=ok, 2=False/None, 3=empty-dict yaml.ScannerError).
fm_parse_out=$(
    {
        for tdir in "$PROJECT_ROOT/.tasks/active" "$PROJECT_ROOT/.tasks/completed"; do
            [ -d "$tdir" ] || continue
            find "$tdir" -maxdepth 1 -name 'T-*.md' -not -name 'T-Test-*' -type f
        done
    } | python3 -c "
import sys
sys.path.insert(0, '$PROJECT_ROOT')
try:
    from web.shared import parse_frontmatter
except ImportError:
    sys.exit(0)  # web/ not present (consumer project) — skip silently
for line in sys.stdin:
    tf = line.rstrip('\n')
    if not tf:
        continue
    try:
        with open(tf) as f:
            content = f.read()
        fm, _ = parse_frontmatter(content)
        if fm is False or fm is None:
            rc = 2
        elif isinstance(fm, dict) and len(fm) == 0:
            rc = 3
        elif isinstance(fm, dict) and any((' ' in str(k) or '\t' in str(k)) for k in fm):
            # T-2779: the silent half of the T-2069 class. A folded-scalar break whose
            # orphaned paragraph happens to contain 'word: word' parses as a junk top-level
            # key and truncates description to its first line — valid YAML, rc=0, invisible.
            # Predicate is whitespace-in-key, NOT unknown-key: the schema is deliberately
            # extensible (A2 treats unknown fields as silent additions), so an unknown-key
            # test would flag bvp_scores_proposed and every field added after it.
            rc = 4
        else:
            rc = 0
    except Exception:
        rc = 2
    print(f'{rc}\t{tf}')
" 2>/dev/null
)
while IFS=$'\t' read -r rc tf; do
    [ -z "$rc" ] && continue
    [ "$rc" = "0" ] && continue
    tf_rel="${tf#$PROJECT_ROOT/}"
    # T-2779: rc=4 is a separate class with a separate repair, so it gets its own counter.
    # Merging it into the unparseable count would tell the operator a number without
    # telling them which fix applies: an rc=2/3 file simply will not parse, while an rc=4
    # file parses fine and has already lost content that has to be reconstructed by hand.
    if [ "$rc" = "4" ]; then
        fm_trunc_count=$((fm_trunc_count + 1))
        fm_trunc_list="$fm_trunc_list\n  $tf_rel"
        continue
    fi
    fm_fail_count=$((fm_fail_count + 1))
    if [ "$rc" = "3" ]; then
        fm_fail_list="$fm_fail_list\n  $tf_rel  (empty-dict / yaml.ScannerError — T-2069 class: folded scalar or quoting break)"
    else
        fm_fail_list="$fm_fail_list\n  $tf_rel  (no/invalid frontmatter delimiters — T-2067 class: components regex mangle)"
    fi
done <<< "$fm_parse_out"
if [ "$fm_fail_count" -gt 0 ]; then
    warn "Task frontmatter: $fm_fail_count task(s) have unparseable YAML" \
         "Files: $(printf '%b' "$fm_fail_list")" \
         "T-2067 class (mangled components: list — wrapped flow-style left orphan continuation)." \
         "T-2069 class (folded scalar 'description: >' terminated by blank line then col-0 lines parsed as keys; quote the description string or move structured body out of frontmatter)."
fi
if [ "$fm_trunc_count" -gt 0 ]; then
    warn "Task frontmatter: $fm_trunc_count task(s) have description content parsed as frontmatter keys" \
         "Files: $(printf '%b' "$fm_trunc_list")" \
         "T-2779 (silent half of the T-2069 class): a 'description: >' folded scalar ended early, and an orphaned paragraph containing 'word: word' became a top-level key. The file parses, so the unparseable-YAML check above cannot see it — but description was truncated at the first line and the rest of the value is now a key." \
         "Repair differs from the loud class: re-indent the orphaned paragraphs back under 'description: >' by two spaces, then confirm the description reads whole again. The content is still in the file, just in the wrong place." \
         "Producer fixed in T-2778 (create-task.sh indented only the first line at all three emission sites); this check covers any other writer of task frontmatter."
fi

# T-1856 (T-NEW-8): Anchor-task existence check.
# Each .context/arcs/*.yaml may declare `anchor_task: T-XXX` — the originating
# inception or build task. Symmetric to T-1849's arc_id validation (which
# guards task→arc refs); this guards arc→task refs. WARN-only, never blocks
# (audit exit unaffected) — matches T-1846 §4 D4 (warn not block).
anchor_missing=0
anchor_checked=0
if [ -d "$PROJECT_ROOT/.context/arcs" ]; then
    for af in "$PROJECT_ROOT/.context/arcs"/*.yaml; do
        [ -f "$af" ] || continue
        # Extract anchor_task value (single-line scalar). Tolerate quotes + null.
        anchor=$(awk -F': ' '/^anchor_task:/ {sub(/^anchor_task:[[:space:]]*/, ""); print; exit}' "$af" \
                 | tr -d ' "' \
                 | head -c 32)
        [ -z "$anchor" ] && continue
        [ "$anchor" = "null" ] && continue
        anchor_checked=$((anchor_checked + 1))
        if ! ls "$PROJECT_ROOT"/.tasks/active/"$anchor"-*.md "$PROJECT_ROOT"/.tasks/completed/"$anchor"-*.md 2>/dev/null | grep -q .; then
            arc_name=$(basename "$af" .yaml)
            warn "Arc '$arc_name' anchor_task '$anchor' not found in .tasks/{active,completed}/" \
                 "Arc references a task that does not exist (hostage state in the reverse direction — T-1849 guards task→arc; this guards arc→task)" \
                 "Either restore the task file, or update '$af' to point at the correct anchor (or set anchor_task: null if it's been retired)"
            anchor_missing=$((anchor_missing + 1))
        fi
    done
fi
if [ "$anchor_missing" -eq 0 ]; then
    pass_over "$anchor_checked" "arc anchor_task reference(s)" \
         "All arc anchor_task references resolve to existing tasks" \
         "" "0 arcs declared a non-null anchor_task — either .context/arcs/ is empty or every arc has anchor_task: null"
fi

# T-2980 (arc-017, onboarding-curriculum): seed → corpus-map reference resolution.
#
# arc-017 chose to have the onboarding curriculum ROUTE to corpus maps rather than
# embed their content. That created a reference class nothing checked: each seeded
# task's `## For the Operator` section ends with `fw corpus explain <id>`, and if
# that id stops resolving the operator gets a tool error in their first hour, from
# a system they have no model of yet.
#
# FAIL rather than WARN, deliberately diverging from the anchor_task sibling above.
# Three reasons: the reference is a command we TELL a first-time operator to run,
# so the blast radius is the framework's first impression; the seeds are templates
# copied into every consumer project by `fw init`, so a dangling ref ships to every
# install made after it lands and is found one confused operator at a time; and the
# fix is a one-line edit. Warning about a deterministic, trivially-fixable,
# operator-facing dead end would be the wrong tier.
#
# Scope is seed → corpus-map only. Watchtower path refs (/fabric, /designer) resolve
# through a different mechanism and are not checked here.
seed_ref_missing=0
seed_ref_checked=0
if [ -d "$PROJECT_ROOT/lib/seeds/tasks" ] && [ -d "$PROJECT_ROOT/.context/designer/projects" ]; then
    while IFS= read -r _line; do
        [ -z "$_line" ] && continue
        _sfile="${_line%%:*}"
        _sref="${_line##* }"
        [ -z "$_sref" ] && continue
        seed_ref_checked=$((seed_ref_checked + 1))
        if [ ! -d "$PROJECT_ROOT/.context/designer/projects/$_sref" ]; then
            fail "Seed '${_sfile#"$PROJECT_ROOT"/}' routes to corpus map '$_sref', which is not in the store" \
                 "The seed tells a first-time operator to run 'fw corpus explain $_sref'; that command will error. Seeds are copied into every project by 'fw init', so this ships to new installs." \
                 "Either the reference is stale (fix the id in the seed — check 'ls .context/designer/projects/' for the current name), or the map is genuinely missing (restore it, or drop the 'Go deeper' line rather than leaving it dangling)"
            seed_ref_missing=$((seed_ref_missing + 1))
        fi
    done <<SEEDREFS
$(grep -roE --include='*.md' "corpus explain [a-z0-9][a-z0-9-]*" "$PROJECT_ROOT/lib/seeds/tasks" 2>/dev/null)
SEEDREFS
fi
if [ "$seed_ref_missing" -eq 0 ]; then
    pass_over "$seed_ref_checked" "onboarding-seed corpus reference(s)" \
         "All onboarding-seed corpus references resolve to existing maps" \
         "" "No 'fw corpus explain <id>' reference was found in lib/seeds/tasks — either the seeds stopped routing to maps, or lib/seeds/tasks is absent"
fi

# T-2985 (arc-014, designer-corpus): corpus-lint findings reach the daily audit.
#
# The detectors work; nothing converted their output into work. `fw corpus lint` is
# not in audit, not on cron, not in any `## Verification` block — so a finding
# persisted exactly as long as nobody happened to type the command. T-2984 is the
# worked example: lane-geometry (T-2684) and lane-overflow (T-2688/T-2689) both fired
# on aef-session-lifecycle for ~4 weeks. That map is vendored into every consumer
# (T-2942) and is the one existing-project/T-001 routes a first-time operator to. It
# was found by hand-auditing arc-014, which is not a mechanism.
#
# WARN, not FAIL — and unlike the T-2980 sibling directly above, that divergence is
# the point. Seed→map references are homogeneous: dangling is always broken. Corpus
# findings are not. `emitterless-typed-event` on aef-dispatch-loop@v3 is a real seam
# (a typed catch whose throw legitimately lives outside the corpus), and `legacy-ref`
# on t2584-scratch is a scratch artefact. A blanket FAIL would exit 2 on a correct
# corpus, and an audit that fails for a known-acceptable reason trains people to stop
# reading it — which costs more than the findings do.
#
# Silent where the linter or the store is absent: vendored consumers may not carry
# tools/, and a fresh project has no map store. No traceback, no spurious WARN, and
# no PASS line claiming a scan that did not happen.
corpus_lint_findings=0
corpus_lint_scanned=0
_corpus_lint_py="$PROJECT_ROOT/tools/corpus_lint.py"
if [ -f "$_corpus_lint_py" ] && [ -d "$PROJECT_ROOT/.context/designer/projects" ]; then
    _cl_json=$(cd "$PROJECT_ROOT" && timeout 120 python3 "$_corpus_lint_py" --json 2>/dev/null)
    _cl_rows=$(printf '%s' "$_cl_json" | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
print("SCANNED\t%d\t\t" % len(d.get("scanned", [])))
for f in d.get("findings", []):
    print("FINDING\t%s\t%s\t%s\t%s" % (
        f.get("rule", "?"), f.get("map", "?"), f.get("node", "") or "-",
        " ".join(str(f.get("detail", "")).split())))
' 2>/dev/null)
    while IFS=$'\t' read -r _clk _cl1 _cl2 _cl3 _cl4; do
        case "$_clk" in
            SCANNED) corpus_lint_scanned="${_cl1:-0}" ;;
            FINDING)
                warn "Corpus lint [$_cl1] ${_cl2} :: ${_cl3}" \
                     "${_cl4}" \
                     "Inspect with 'fw corpus explain ${_cl2%@*}'. Fix the map, or — if the finding is a genuine seam rather than a defect — mark it (aef:meta seamPending=\"...\") so it stops reporting and the marker records the judgement"
                corpus_lint_findings=$((corpus_lint_findings + 1))
                ;;
        esac
    done <<CORPUSLINT
$_cl_rows
CORPUSLINT
fi
if [ "$corpus_lint_findings" -eq 0 ] && [ -f "$_corpus_lint_py" ] && [ -d "$PROJECT_ROOT/.context/designer/projects" ]; then
    pass_over "$corpus_lint_scanned" "corpus map(s)" "Corpus maps lint clean" \
         "" "tools/corpus_lint.py ran but reported 0 maps scanned — check its --json output by hand (a 120s timeout also lands here)"
fi

# T-1855 (T-NEW-7): Stale-arc warning.
# For each arc with status: in-progress, check whether ANY task with matching
# arc_id: (slug or arc-NNN form) has been touched by a commit in the last
# FW_STALE_ARC_DAYS days (default 30). If no recent activity, emit WARN —
# the arc may have stalled. WARN-only, never blocks (T-1846 §4 D4).
# Silent on draft/closed/abandoned arcs and on arcs with zero matching tasks
# (population unknown — separate signal, not staleness).
stale_arc_threshold="${FW_STALE_ARC_DAYS:-30}"
stale_arc_count=0
arcs_checked_for_staleness=0
if [ -d "$PROJECT_ROOT/.context/arcs" ] && command -v git >/dev/null 2>&1 \
    && git -C "$PROJECT_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    # T-2298: pre-compute task→arc_id map in ONE python3 pass (was per-task awk
    # fork inside per-arc loop — 8 arcs × 2,261 tasks = ~18K awk subprocesses,
    # ~90-100s wall-clock). Now: 1 python3 read of all task heads, in-memory
    # filter per arc. Skips T-Test-* sentinels (T-2228 parity with _is_test_sentinel).
    # T-2970: the map must union BOTH membership forms — `arc_id:` (T-1849
    # canonical) and the legacy `tags: [arc:<slug>]` — because arc_tasks_for
    # (lib/arc_membership.sh:108) does, and it is the reader everything else
    # agrees with. Reading arc_id: alone made four arcs read as ZERO tasks
    # (onboarding 015/016/017 and ladder-trigger-producer) and undercounted four
    # more; they then hit the zero-population `continue` below, whose stated
    # reason is "no tasks" and which therefore absorbed "tasks this map cannot
    # see" without distinction.
    #
    # This union already exists in this file at ~5250, added by T-1875 after the
    # same class cost 163 task-arc relationships across 5 arcs. T-2298's
    # performance rewrite of THIS pass (awk-fork-per-task → single python read)
    # did not carry it across. Keep both readers in step.
    task_arc_map=$(python3 -c "
import os, re
project_root = '$PROJECT_ROOT'
arc_id_re = re.compile(r'^arc_id:\s*([^\s#]+)', re.M)
arc_tag_re = re.compile(r'^tags:.*?\barc:([A-Za-z0-9_-]+)', re.M)
for d in ('active', 'completed'):
    tdir = os.path.join(project_root, '.tasks', d)
    if not os.path.isdir(tdir):
        continue
    try:
        names = os.listdir(tdir)
    except OSError:
        continue
    for fn in names:
        if not (fn.startswith('T-') and fn.endswith('.md')):
            continue
        if fn.startswith('T-Test-'):
            continue
        path = os.path.join(tdir, fn)
        try:
            with open(path) as f:
                head = f.read(4096)
        except Exception:
            continue
        # T-2970: emit one row per membership declaration; the per-arc filter
        # below matches on either, and duplicates are harmless (a task matching
        # both forms of the same arc still yields one arc).
        emitted = set()
        m = arc_id_re.search(head)
        if m:
            tag = m.group(1).strip().strip('\"').strip(chr(39))
            if tag and tag != 'null':
                emitted.add(tag)
        mt = arc_tag_re.search(head)
        if mt:
            emitted.add(mt.group(1).strip())
        for tag in emitted:
            print(f'{path}\t{tag}')
" 2>/dev/null)

    for af in "$PROJECT_ROOT/.context/arcs"/*.yaml; do
        [ -f "$af" ] || continue

        status_val=$(awk -F': ' '/^status:/ {sub(/^status:[[:space:]]*/, ""); print; exit}' "$af" \
                     | tr -d ' "' | head -c 32)
        [ "$status_val" = "in-progress" ] || continue

        arc_numeric=$(awk -F': ' '/^id:/ {sub(/^id:[[:space:]]*/, ""); print; exit}' "$af" \
                      | tr -d ' "' | head -c 32)
        arc_slug=$(awk -F': ' '/^slug:/ {sub(/^slug:[[:space:]]*/, ""); print; exit}' "$af" \
                   | tr -d ' "' | head -c 64)
        [ -z "$arc_slug" ] && arc_slug=$(basename "$af" .yaml)

        # T-2298: filter pre-computed map by this arc's slug or arc-NNN id —
        # was per-task awk fork (one awk per task per arc). Now in-memory only.
        matching_tasks=()
        seen_paths=" "
        while IFS=$'\t' read -r tp ttag; do
            [ -z "$tp" ] && continue
            if [ "$ttag" = "$arc_slug" ] || [ "$ttag" = "$arc_numeric" ]; then
                # T-2970: a task may declare membership via BOTH arc_id: and the
                # legacy arc:<slug> tag, emitting two rows. Dedupe by path so the
                # "(N task(s) in arc)" count matches `fw arc list`.
                case "$seen_paths" in *" $tp "*) continue;; esac
                seen_paths="${seen_paths}${tp} "
                matching_tasks+=("$tp")
            fi
        done <<< "$task_arc_map"

        # Zero-population arcs can't be assessed for staleness — skip.
        #
        # T-2970: this skip is a reasoned EXCLUSION (staleness is not a
        # meaningful question for an arc with no constituents), and it used to
        # double as a HOLE — arcs whose tasks the map could not read landed here
        # too, indistinguishable. The union above closes the hole; the exclusion
        # stands. The PASS line below now reports the assessed count so the two
        # can never silently merge again.
        [ "${#matching_tasks[@]}" -eq 0 ] && continue

        arcs_checked_for_staleness=$((arcs_checked_for_staleness + 1))

        # Any commit since the threshold touching any matching task → fresh.
        recent=$(git -C "$PROJECT_ROOT" log --since="${stale_arc_threshold}.days.ago" \
                     --format=%H -- "${matching_tasks[@]}" 2>/dev/null | head -1)

        if [ -z "$recent" ]; then
            warn "Arc '$arc_slug' has no task commits in the last ${stale_arc_threshold} days (${#matching_tasks[@]} task(s) in arc)" \
                 "Arc is in-progress but its constituent tasks show no recent git activity — may have stalled" \
                 "Either close/abandon the arc via 'fw arc close' or run 'fw task update T-XXX --last-update \$(date -u +%FT%TZ)' on a relevant task. Configurable via FW_STALE_ARC_DAYS (default 30)."
            stale_arc_count=$((stale_arc_count + 1))
        fi
    done
fi
if [ "$stale_arc_count" -eq 0 ]; then
    # T-2970: name the ASSESSED count, not "all". The previous wording ("All N
    # in-progress arc(s) ...") read as total coverage while N was whatever the
    # membership map happened to see — a census over survivors. Stating the
    # denominator is what makes a future shortfall visible. T-3105 moved the
    # census onto the shared verb, which also turns the previously-silent
    # zero-population case into a WARN instead of no line at all.
    pass_over "$arcs_checked_for_staleness" "in-progress arc(s) with constituents" \
         "All assessed arcs had task commits within ${stale_arc_threshold} days" \
         "" "No in-progress arc has any constituent task — either .context/arcs/ holds no in-progress entries, or the arc_id:/arc: tag join is resolving to nothing"
fi

# T-2969: draft arc with all constituents complete. `fw arc close` requires
# `in-progress` (lib/arc.sh:665), so an arc left in `draft` whose constituent
# tasks are all work-completed has no path to closure and nothing reports
# it — the stale-arc check above is silent on draft arcs BY DESIGN (right
# question, wrong population: draft-with-no-activity is backlog, not stall),
# and the close refusal itself names no remedy. Reuses task_arc_map computed
# above (same membership union: arc_id: + legacy arc:<slug> tag).
draft_complete_count=0
if [ -d "$PROJECT_ROOT/.context/arcs" ] && [ -n "${task_arc_map:-}" ]; then
    for af in "$PROJECT_ROOT/.context/arcs"/*.yaml; do
        [ -f "$af" ] || continue

        status_val=$(awk -F': ' '/^status:/ {sub(/^status:[[:space:]]*/, ""); print; exit}' "$af" \
                     | tr -d ' "' | head -c 32)
        [ "$status_val" = "draft" ] || continue

        arc_numeric=$(awk -F': ' '/^id:/ {sub(/^id:[[:space:]]*/, ""); print; exit}' "$af" \
                      | tr -d ' "' | head -c 32)
        arc_slug=$(awk -F': ' '/^slug:/ {sub(/^slug:[[:space:]]*/, ""); print; exit}' "$af" \
                   | tr -d ' "' | head -c 64)
        [ -z "$arc_slug" ] && arc_slug=$(basename "$af" .yaml)

        matching_tasks=()
        seen_paths=" "
        while IFS=$'\t' read -r tp ttag; do
            [ -z "$tp" ] && continue
            if [ "$ttag" = "$arc_slug" ] || [ "$ttag" = "$arc_numeric" ]; then
                case "$seen_paths" in *" $tp "*) continue;; esac
                seen_paths="${seen_paths}${tp} "
                matching_tasks+=("$tp")
            fi
        done <<< "$task_arc_map"

        # Zero-population draft arcs don't warn: 0/0 is vacuously "all
        # complete", which would fire on every empty draft arc — the
        # always-answers shape this whole class exists to avoid.
        [ "${#matching_tasks[@]}" -eq 0 ] && continue

        all_complete=1
        for tp in "${matching_tasks[@]}"; do
            case "$tp" in
                */completed/*) ;;
                *) all_complete=0; break ;;
            esac
        done

        if [ "$all_complete" -eq 1 ]; then
            warn "Arc '$arc_slug' is draft with all ${#matching_tasks[@]} constituent task(s) work-completed" \
                 "Draft arcs can't be closed directly ('fw arc close' requires in-progress) — this arc's work is finished but there's no path out of draft" \
                 "Run 'fw arc start $arc_slug' to move it to in-progress, then close via Watchtower (/arcs/$arc_slug/close)"
            draft_complete_count=$((draft_complete_count + 1))
        fi
    done
fi

# T-2169 (T-NEW-C, value-drivers v3 follow-up): retire_when advisory.
# For each ACTIVE free_driver in policy/value-drivers.yaml that has retire_when:
# text, run a per-driver recognition heuristic against the corpus. WARN when
# the heuristic says "looks recognisably met"; INFO when retire_when text is
# present but no dedicated heuristic exists (manual review). WARN-only, never
# blocks. One WARN per driver per run (de-duped by construction). Modelled on
# T-1855 stale-arc. Silence with FW_RETIRE_WHEN_ADVISORY=0.
if [ "${FW_RETIRE_WHEN_ADVISORY:-1}" != "0" ] \
   && [ -f "$PROJECT_ROOT/policy/value-drivers.yaml" ] \
   && command -v python3 >/dev/null 2>&1; then
    retire_when_findings=$(python3 - "$PROJECT_ROOT" <<'PY' 2>/dev/null
import sys, os, glob, subprocess, time
try:
    import yaml
except ImportError:
    sys.exit(0)

project_root = sys.argv[1]
vd_path = os.path.join(project_root, "policy", "value-drivers.yaml")
try:
    with open(vd_path) as fh:
        vd = yaml.safe_load(fh) or {}
except Exception:
    sys.exit(0)

# Active free drivers only — commented-out (candidate) entries don't appear in
# the parsed dict, so they're skipped by construction.
free = vd.get("free_drivers") or []

def recall_signals():
    """F-RECALL retire_when: 4 sub-criteria (a,b,c,d) — return count present."""
    s = 0
    # (a) positive-reinforcement / happiness capture in last 30d
    try:
        out = subprocess.check_output(
            ["git", "-C", project_root, "log",
             "--grep=positive-reinforcement", "--grep=happiness",
             "--since=30.days.ago", "--format=%H", "-n", "1"],
            stderr=subprocess.DEVNULL, text=True, timeout=5)
        if out.strip():
            s += 1
    except Exception:
        pass
    # (b) preference index file
    found_b = False
    for name in ("preference-index.yaml", "preferences.yaml"):
        if glob.glob(os.path.join(project_root, "**", name), recursive=True):
            found_b = True
            break
    if found_b:
        s += 1
    # (c) auto-sync code in agents/ or lib/
    try:
        for d in ("agents", "lib"):
            dpath = os.path.join(project_root, d)
            if not os.path.isdir(dpath):
                continue
            out = subprocess.check_output(
                ["grep", "-rlE", "auto-sync|CLAUDE-sync", dpath],
                stderr=subprocess.DEVNULL, text=True, timeout=5)
            if out.strip():
                s += 1
                break
    except Exception:
        pass
    # (d) durable reflection log mtime within last 7 days
    refl_dir = os.path.join(project_root, ".context")
    if os.path.isdir(refl_dir):
        cutoff = time.time() - 7 * 86400
        hit = False
        for root, _, files in os.walk(refl_dir):
            for f in files:
                if "reflection" in f.lower() and f.endswith(".yaml"):
                    try:
                        if os.path.getmtime(os.path.join(root, f)) > cutoff:
                            hit = True
                            break
                    except OSError:
                        pass
            if hit:
                break
        if hit:
            s += 1
    return s

def orch_signal():
    """F-ORCH retire_when: T-1643 cleanly completed OR G-064 closed."""
    # (a) T-1643 in completed/ without partial-complete marker
    for tf in glob.glob(os.path.join(project_root, ".tasks", "completed", "T-1643*.md")):
        try:
            with open(tf) as fh:
                body = fh.read()
            if "partial-complete" not in body and "[REVIEW]" not in body:
                return True
        except Exception:
            pass
    # (b) G-064 closed in concerns.yaml
    cpath = os.path.join(project_root, ".context", "project", "concerns.yaml")
    if os.path.isfile(cpath):
        try:
            with open(cpath) as fh:
                c = yaml.safe_load(fh) or {}
            entries = c.get("concerns") or c.get("entries") or []
            if isinstance(entries, dict):
                entries = list(entries.values())
            for entry in entries:
                if not isinstance(entry, dict):
                    continue
                if entry.get("id") == "G-064" and entry.get("status") == "closed":
                    return True
        except Exception:
            pass
    return False

seen = set()
for drv in free:
    if not isinstance(drv, dict):
        continue
    drv_id = drv.get("id")
    rw = drv.get("retire_when")
    if not drv_id or not rw or not str(rw).strip():
        continue
    if drv_id in seen:  # WARN-cap safety
        continue
    seen.add(drv_id)
    if drv_id == "F-RECALL":
        s = recall_signals()
        if s >= 4:
            print(f"WARN|{drv_id}|retire_when condition appears met ({s}/4 signals) — review whether to retire|")
    elif drv_id == "F-ORCH":
        if orch_signal():
            print(f"WARN|{drv_id}|retire_when condition appears met (T-1643 completed cleanly OR G-064 closed) — review whether to retire|")
    else:
        print(f"INFO|{drv_id}|retire_when text present, no recognition heuristic — manual review|")
PY
)
    retire_warn=0
    retire_info=0
    while IFS='|' read -r rw_level rw_drv rw_msg rw_ctx; do
        [ -z "$rw_level" ] && continue
        case "$rw_level" in
            WARN)
                warn "free driver $rw_drv: $rw_msg" \
                     "Retire-when text in policy/value-drivers.yaml appears recognisably satisfied${rw_ctx:+ — $rw_ctx}" \
                     "Review the driver; if truly retired, comment it out or move to candidates section. Silence with FW_RETIRE_WHEN_ADVISORY=0."
                retire_warn=$((retire_warn + 1))
                ;;
            INFO)
                info "free driver $rw_drv: $rw_msg"
                retire_info=$((retire_info + 1))
                ;;
        esac
    done <<<"$retire_when_findings"
fi

# T-1927 (T-NEW-11, arc-006): per-driver coherence audit.
# WARN when an arc claims a driver is important (weight ≥ BVP_COHERENCE_ARC_MIN
# OR arc bvp_scores[Dn] ≥ BVP_COHERENCE_ARC_MIN) but ≥ BVP_COHERENCE_FRACTION of
# its constituent tasks score that driver ≤ BVP_COHERENCE_TASK_MAX.
#
# Per-driver, NOT aggregated (D3 rejected aggregation). Non-blocking — coherence
# WARNs are signal, not failure; the compliance section still drives exit codes.
#
# Thresholds (handoff §7 M4): arc-claims ≥4, task-scores ≤1, fraction ≥0.7.
# Configurable via env vars; defaults applied if unset.
BVP_COHERENCE_ARC_MIN="${BVP_COHERENCE_ARC_MIN:-4}"
BVP_COHERENCE_TASK_MAX="${BVP_COHERENCE_TASK_MAX:-1}"
BVP_COHERENCE_FRACTION="${BVP_COHERENCE_FRACTION:-0.7}"

# Run a python pass that enumerates in-progress arcs, reads their scoped_drivers
# and bvp_scores, walks constituent tasks via arc_id (post-T-1850 single source
# of truth), and emits one line per mismatched driver: "ARC|DRIVER|N_LOW|N_TOTAL".
bvp_coherence_findings=$(python3 - "$PROJECT_ROOT" "$BVP_COHERENCE_ARC_MIN" "$BVP_COHERENCE_TASK_MAX" "$BVP_COHERENCE_FRACTION" <<'PY' 2>/dev/null
import sys, re, glob, yaml
from pathlib import Path

PROJECT_ROOT = Path(sys.argv[1])
ARC_MIN = int(sys.argv[2])
TASK_MAX = int(sys.argv[3])
FRACTION = float(sys.argv[4])

_FM_RE = re.compile(r'^---\n(.*?)\n---', re.S)

def task_score(path, driver_id):
    """Return int score for driver_id from task frontmatter, or None if absent."""
    try:
        text = path.read_text()
    except Exception:
        return None
    m = _FM_RE.match(text)
    if not m:
        return None
    try:
        fm = yaml.safe_load(m.group(1)) or {}
    except yaml.YAMLError:
        return None
    scores = fm.get('bvp_scores') or {}
    if not isinstance(scores, dict):
        return None
    return scores.get(driver_id)

arcs_dir = PROJECT_ROOT / '.context' / 'arcs'
if not arcs_dir.is_dir():
    sys.exit(0)

# Index task files by their `arc_id:` frontmatter value.
tasks_by_arc = {}
for sub in ('active', 'completed'):
    for p in (PROJECT_ROOT / '.tasks' / sub).glob('T-*.md'):
        if p.name.startswith('T-Test-'):  # T-2228 (T-2225 Slice 3): skip test sentinels
            continue
        try:
            text = p.read_text()
        except Exception:
            continue
        m = _FM_RE.match(text)
        if not m:
            continue
        try:
            fm = yaml.safe_load(m.group(1)) or {}
        except yaml.YAMLError:
            continue
        arc_id = fm.get('arc_id')
        if not arc_id:
            continue
        tasks_by_arc.setdefault(arc_id, []).append(p)

for arc_path in sorted(arcs_dir.glob('*.yaml')):
    try:
        arc = yaml.safe_load(arc_path.read_text()) or {}
    except yaml.YAMLError:
        continue
    if arc.get('status') != 'in-progress':
        continue
    slug = arc.get('slug') or arc_path.stem
    arc_nnn = arc.get('id')

    # Collect drivers the arc "claims" as important.
    claims = {}  # driver_id → asserted_value (arc-side)
    for sd in (arc.get('scoped_drivers') or []):
        try:
            w = int(sd.get('weight', 0))
        except (TypeError, ValueError):
            continue
        if w >= ARC_MIN:
            claims[sd.get('name', '?')] = w
    arc_bvp = arc.get('bvp_scores') or {}
    if isinstance(arc_bvp, dict):
        for did, val in arc_bvp.items():
            try:
                v = int(val)
            except (TypeError, ValueError):
                continue
            if v >= ARC_MIN:
                claims[did] = v

    if not claims:
        continue

    # Constituents — search by either slug or arc-NNN form per T-1849.
    constituents = list(tasks_by_arc.get(slug, []))
    if arc_nnn:
        constituents += list(tasks_by_arc.get(arc_nnn, []))
    constituents = list(set(constituents))
    if not constituents:
        continue

    for driver_id, claim_val in claims.items():
        scores = []
        for p in constituents:
            s = task_score(p, driver_id)
            if s is None:
                continue
            scores.append(int(s))
        if not scores:
            continue
        n_low = sum(1 for s in scores if s <= TASK_MAX)
        n_total = len(scores)
        if n_total == 0:
            continue
        frac = n_low / n_total
        if frac >= FRACTION:
            print(f"{slug}|{driver_id}|{claim_val}|{n_low}|{n_total}|{frac:.2f}")
PY
)

if [ -n "$bvp_coherence_findings" ]; then
    while IFS='|' read -r c_arc c_driver c_val c_low c_total c_frac; do
        warn "BVP coherence: arc ${c_arc} claims ${c_driver}=${c_val} but tasks don't support it (${c_low} of ${c_total} constituents score ${c_driver} ≤ ${BVP_COHERENCE_TASK_MAX}, ${c_frac} of fraction threshold ${BVP_COHERENCE_FRACTION})" \
             "Per-driver coherence check (T-1927, M4)" \
             "Either revise the arc claim (fw arc approve-driver / adjust bvp_scores) or revise the rubric (R2 detection — systematic single-driver warnings indicate rubric bias, not arc mis-scoring)"
    done <<< "$bvp_coherence_findings"
fi

# T-1881 (T-NEW-16, arc-grooming): ctl-arc-tag-only-pattern.
# After T-1880 consolidation, inline `grep ... arc:<slug>` legacy-tag scans
# are forbidden outside the canonical helpers. Any NEW occurrence in
# consumer code is silent-corpus #3 in waiting — a site reinventing the
# scan and missing the `arc_id` half of the union (L-397).
#
# Whitelist: lib/arc_membership.{sh,py} (canonical), lib/arc.sh (legacy
# wrappers kept as thin shims), lib/migrations/ (one-shot migration),
# tests/, docs/, .fabric/, .context/ (out-of-scope surfaces).
#
# Scope: lib/, web/, agents/, bin/, tools/ — source code paths.
# Failure mode: FAIL (not WARN) — silent corpora are the exact class
# this check exists to prevent.
arc_tag_only_violations=0
arc_tag_only_evidence=""
# Pattern: `grep` invocations targeting `arc:<slug>` (legacy tag form)
# in either `tags: [...]` or as a raw pattern argument. Excludes
# `current_arc:` and `arc_id:` which are different namespaces.
arc_tag_only_pattern='grep[^|]*"\^?tags:.*arc:|grep[^|]*arc:[A-Za-z0-9_-]'
# T-3105: count the files the scan actually walks. A grep that matches nothing
# and a grep that walked nothing print the same "no violations" line otherwise.
arc_tag_only_scanned=0
for scan_dir in lib web agents bin tools; do
    [ -d "$PROJECT_ROOT/$scan_dir" ] || continue
    arc_tag_only_scanned=$((arc_tag_only_scanned + $(find "$PROJECT_ROOT/$scan_dir" \
        \( -name '*.sh' -o -name '*.py' -o -name '*.bash' \) -type f 2>/dev/null | wc -l)))
    while IFS= read -r hit; do
        [ -z "$hit" ] && continue
        # Allowlist by path prefix.
        case "$hit" in
            *lib/arc_membership.sh:*|*lib/arc_membership.py:*) continue ;;
            *lib/arc.sh:*) continue ;;
            *lib/migrations/*) continue ;;
            *tests/*|*docs/*|*.fabric/*|*.context/*) continue ;;
        esac
        arc_tag_only_violations=$((arc_tag_only_violations + 1))
        arc_tag_only_evidence="$arc_tag_only_evidence$hit\n"
    done < <(grep -RnE "$arc_tag_only_pattern" \
                   --include='*.sh' --include='*.py' --include='*.bash' \
                   "$PROJECT_ROOT/$scan_dir" 2>/dev/null || true)
done
if [ "$arc_tag_only_violations" -eq 0 ]; then
    pass_over "$arc_tag_only_scanned" "source file(s) under lib/ web/ agents/ bin/ tools/" \
         "No inline arc:<slug> tag-only scans outside canonical lib (T-1881)" \
         "" "The scan walked no files — check that lib/ web/ agents/ bin/ tools/ exist under PROJECT_ROOT"
else
    fail "Found $arc_tag_only_violations inline arc:<slug> tag-only scan(s) outside canonical lib" \
         "$(printf '%b' "$arc_tag_only_evidence" | head -5)" \
         "Migrate to lib/arc_membership.{sh,py} (arc_tasks_for / scan_tasks_by_arc_membership). See T-1880 for pattern. Silent-corpus risk class L-397."
fi

# T-2648 (OBS-097, 832's G-004 class): split-root asset-resolution lint.
# Framework-owned dirs (lib/ agents/ policy/ bin/ web/) resolved via
# PROJECT_ROOT are invisible bugs in this repo (roots coincide) but break
# every split-root consumer — the failing path structurally cannot fire
# where the code is developed (same class as OBS-096 / T-1633). Origin:
# T-2645 fixed 3 sys.path sites 832 reported; T-2648 calibration found 5
# more live (designer pin, 3× bin/fw subprocess paths, agents/ dir read).
# Scope: Python under web/ and lib/ (shell uses different resolution
# idioms — follow-up scope, see OBS-097). Correct resolution is
# FRAMEWORK_ROOT (web/shared.py) or Path(__file__)-derived in lib/.
#
# Semantic allowlist (NOT path-prefix): lines referencing the two
# per-project policy INSTANCE files (value-drivers.yaml,
# bvp-scoring-rubric.md — seeded from the framework template by
# `fw bvp driver --init`, T-2229) are legitimate PROJECT_ROOT reads;
# parity with lib/bvp.sh's own PROJECT_ROOT resolution. A site may also
# carry an inline `OBS-097-allow:` annotation WITH a stated reason —
# for surfaces that are PROJECT_ROOT-relative end-to-end where a lone
# resolution flip would make things worse (e.g. core.py /project listing,
# whose relative_to+serving pair both assume PROJECT_ROOT).
# Failure mode: FAIL — this exact class shipped a dead /review queue to
# a consumer (832 rail 253) and two silently-dead surfaces.
splitroot_violations=0
splitroot_evidence=""
splitroot_pattern='PROJECT_ROOT[[:space:]]*/[[:space:]]*["'\''](lib|agents|policy|bin|web)["'\'']'
# T-3105: population = the Python files this scan walks (see arc_tag_only above).
splitroot_scanned=0
for scan_dir in web lib; do
    [ -d "$PROJECT_ROOT/$scan_dir" ] || continue
    splitroot_scanned=$((splitroot_scanned + $(find "$PROJECT_ROOT/$scan_dir" -name '*.py' -type f 2>/dev/null | wc -l)))
    while IFS= read -r hit; do
        [ -z "$hit" ] && continue
        case "$hit" in
            # Per-project policy instances (T-2229 --init model).
            *value-drivers.yaml*|*bvp-scoring-rubric.md*) continue ;;
            # Explicit annotated exemption (must carry a reason in-source).
            *OBS-097-allow:*) continue ;;
            *tests/*|*docs/*) continue ;;
        esac
        splitroot_violations=$((splitroot_violations + 1))
        splitroot_evidence="$splitroot_evidence$hit\n"
    done < <(grep -RnE "$splitroot_pattern" --include='*.py' \
                   "$PROJECT_ROOT/$scan_dir" 2>/dev/null || true)
done
if [ "$splitroot_violations" -eq 0 ]; then
    pass_over "$splitroot_scanned" "Python file(s) under web/ + lib/" \
         "No PROJECT_ROOT resolution of framework-owned assets (T-2648, OBS-097)" \
         "" "The scan walked no .py files under web/ or lib/ — the OBS-097 rail asserted nothing this run"
else
    fail "Found $splitroot_violations PROJECT_ROOT resolution(s) of framework-owned assets (breaks split-root consumers)" \
         "$(printf '%b' "$splitroot_evidence" | head -5)" \
         "Resolve via FRAMEWORK_ROOT (web/shared.py) or Path(__file__)-derived root in lib/. If the file is genuinely per-project state, extend the allowlist in this check WITH a stated reason. See OBS-097 / T-2645 / T-2648."
fi

# T-1975 (L-417 prevention): stale-slice-reference scan.
# When a slice ships, satellite text/tests referencing "ship in T-NNNN"
# become stale and contradict reality. Origin: T-1971/T-1972/T-1973/T-1974
# cluster in BVP arc — 4 instances landed in 20 min, all the same pattern:
# substrate evolved, satellite didn't follow. This check scans source
# surfaces for two phrasings of the anti-pattern and flags references
# whose T-NNNN already lives in .tasks/completed/. WARN (not FAIL) until
# FP rate is measured.
#
# Pattern 1: "ship | ships | shipping in T-NNNN" (forecast — present/future)
# Pattern 2: "once (that )?slice ships"
# Past-tense "shipped in T-NNNN" is intentionally NOT matched — that's a
# historical reference (correct documentation), not a stale forecast.
#
# Scope: web/templates, web/blueprints, lib (source-of-truth surfaces).
# Allowlist: tests/, docs/, .fabric/, .context/, .tasks/, audit.sh itself.
stale_slice_count=0
stale_slice_evidence=""
# T-3105: population = the files this scan walks (see arc_tag_only above).
stale_slice_scanned=0
for scan_dir in web/templates web/blueprints lib; do
    [ -d "$PROJECT_ROOT/$scan_dir" ] || continue
    stale_slice_scanned=$((stale_slice_scanned + $(find "$PROJECT_ROOT/$scan_dir" \
        \( -name '*.html' -o -name '*.py' -o -name '*.sh' \) -type f 2>/dev/null | wc -l)))
    while IFS= read -r hit; do
        [ -z "$hit" ] && continue
        # Allowlist (out-of-scope or self-referential)
        case "$hit" in
            *agents/audit/audit.sh:*) continue ;;
            *tests/*|*docs/*|*.fabric/*|*.context/*|*.tasks/*) continue ;;
        esac
        # Extract T-NNNN from the matched line.
        t_id=$(echo "$hit" | grep -oE 'T-[0-9]{2,5}' | head -1)
        if [ -n "$t_id" ]; then
            # Only flag if T-NNNN resolves to a completed task.
            if ls "$PROJECT_ROOT/.tasks/completed/${t_id}-"*.md >/dev/null 2>&1; then
                stale_slice_count=$((stale_slice_count + 1))
                stale_slice_evidence="$stale_slice_evidence$hit\n"
            fi
        else
            # "once (that )?slice ships" — no T-NNNN to verify; always flag.
            stale_slice_count=$((stale_slice_count + 1))
            stale_slice_evidence="$stale_slice_evidence$hit\n"
        fi
    done < <(grep -RniE '(\<ship\>|\<ships\>|\<shipping\>)[[:space:]]+in[[:space:]]+T-[0-9]{2,5}|once[[:space:]]+(that[[:space:]]+)?slice[[:space:]]+ships?' \
                   --include='*.html' --include='*.py' --include='*.sh' \
                   "$PROJECT_ROOT/$scan_dir" 2>/dev/null || true)
done
if [ "$stale_slice_count" -eq 0 ]; then
    pass_over "$stale_slice_scanned" "file(s) under web/templates web/blueprints lib" \
         "No stale-slice-references (L-417)" \
         "" "The scan walked no files — the L-417 rail asserted nothing this run"
else
    warn "Found $stale_slice_count stale-slice-reference(s) — satellite text references a completed task as if still pending" \
         "$(printf '%b' "$stale_slice_evidence" | head -5)" \
         "Update the satellite to describe the live behaviour (origin: L-417, T-1971/T-1972/T-1973/T-1974)"
fi

# T-2096 (OBS-036, sibling to L-417/T-1975): GO-scope-not-propagated scan.
# Forwards-pointing companion to the L-417 detector above. L-417 catches
# satellite text claiming "ships in T-NNNN" where T-NNNN is already
# completed (backwards staleness). This detector catches the inverse: a
# completed inception that recorded a GO and then propagated nothing — no
# related_tasks:, nobody back-referencing it, no build task declaring it via
# unlocks_inception_decision:. The GO scope was approved but never became
# work; humans following the breadcrumbs find a dead-end.
# Origin: T-2078 (May-29) — Recommendation said "V1 build slices (filed on GO)"
# but related_tasks: [] and the V1-a/b/c/d slices did not exist until T-2091's
# G-052 sweep backfilled them as T-2092..T-2095. WARN (not FAIL): a finding is
# "somebody should triage this", and the standing backlog is pre-existing debt,
# not a regression.
#
# T-3099: the candidate gate is STRUCTURAL. It was a regex over prose --
#   CLAIM_RE = r'filed on GO|sub-tasks (filed|created)|build slices (filed|created)
#               |child tasks (filed|spun off)'
# -- which measured 2 matches across 444 completed inceptions, 0 of which
# survived the related_tasks filter. The candidate set was empty by
# construction, so every PASS this check ever printed was vacuous. A rail keyed
# to how an author phrased a promise is silent exactly when the author writes
# carefully: an inverse correlation with the thing being measured. T-2822 --
# whose unbuilt keystone slice kept the worktree class alive for two weeks past
# its own approval -- says "each is a separate build slice", which the regex
# does not match. See docs/reports/T-3097-worktree-rca.md IW-4.
# There is no vocabulary anywhere in the predicate now: GO recorded, no
# related_tasks, no back-reference, no unlocks_inception_decision.
#
# T-2298 (preserved): single python3 pre-scan, O(M+N). Pass 1 walks completed/
# once to find candidates; pass 2 walks active/+completed/ once to build the set
# of every task id referenced by a related_tasks: line or an
# unlocks_inception_decision: entry. The original per-candidate grep fan-out
# (~1500 completed tasks x 3-4 greps + a cross-file grep per survivor) took
# 30-60s wall-clock. Skips T-Test-* sentinels (T-2228 parity).
GO_SCOPE_REPORT_DIR="$AUDITS_DIR/go-scope-unpropagated"
mkdir -p "$GO_SCOPE_REPORT_DIR" 2>/dev/null || true
GO_SCOPE_REPORT_PATH="$GO_SCOPE_REPORT_DIR/LATEST.md"
go_scope_summary=$(python3 -c "
import os, re

project_root = '$PROJECT_ROOT'
report_path = '$GO_SCOPE_REPORT_PATH'
completed_dir = os.path.join(project_root, '.tasks', 'completed')
active_dir = os.path.join(project_root, '.tasks', 'active')

WORKFLOW_RE = re.compile(r'^workflow_type: inception\$', re.M)
# Structural GO marker: the field 'fw inception decide' writes into ## Decision.
# Anchored on the field, so NO-GO / DEFER / SUPERSEDED cannot match, and no
# prose phrasing is consulted.
GO_RE = re.compile(r'^\*\*Decision\*\*:[ \t]*GO\b', re.M)
EMPTY_RT_RE = re.compile(r'^related_tasks: \[\]', re.M)
HAS_RT_RE = re.compile(r'^related_tasks:', re.M)
ID_RE = re.compile(r'^(T-\d+)')
INLINE_RT_LINE_RE = re.compile(r'^related_tasks:.*\bT-\d+\b.*\$', re.M)
# Inline list form plus the indented block form both occur in the corpus.
UNLOCKS_RE = re.compile(r'^unlocks_inception_decision:.*(?:\n[ \t]+-.*)*', re.M)
TID_RE = re.compile(r'\bT-\d+\b')


def task_files(d):
    if not os.path.isdir(d):
        return
    try:
        names = sorted(os.listdir(d))
    except OSError:
        return
    for fn in names:
        if not (fn.startswith('T-') and fn.endswith('.md')):
            continue
        if fn.startswith('T-Test-'):
            continue
        path = os.path.join(d, fn)
        try:
            with open(path) as f:
                content = f.read()
        except Exception:
            continue
        m = ID_RE.match(fn)
        if not m:
            continue
        yield path, fn, m.group(1), content


def no_related_tasks(content):
    if EMPTY_RT_RE.search(content):
        return True
    return not HAS_RT_RE.search(content)


# Pass 1: walk completed/ once. Count the population actually examined, and
# collect the structural candidates.
total_inceptions = 0
go_inceptions = 0
candidates = []   # (t_id, path)
completed_cache = []
for path, fn, t_id, content in task_files(completed_dir):
    completed_cache.append((t_id, content))
    if not WORKFLOW_RE.search(content):
        continue
    total_inceptions += 1
    if not GO_RE.search(content):
        continue
    go_inceptions += 1
    if no_related_tasks(content):
        candidates.append((t_id, path))

# Pass 2: walk active/ once and reuse the completed/ read from pass 1. Collect
# every task id referenced by a related_tasks: line or an
# unlocks_inception_decision: entry. Self-references do not count as
# propagation.
referenced = set()


def harvest(owner_id, content):
    for m in INLINE_RT_LINE_RE.finditer(content):
        for tm in TID_RE.finditer(m.group(0)):
            if tm.group(0) != owner_id:
                referenced.add(tm.group(0))
    for m in UNLOCKS_RE.finditer(content):
        for tm in TID_RE.finditer(m.group(0)):
            if tm.group(0) != owner_id:
                referenced.add(tm.group(0))


for t_id, content in completed_cache:
    harvest(t_id, content)
for path, fn, t_id, content in task_files(active_dir):
    harvest(t_id, content)

findings = [(t_id, path) for t_id, path in candidates if t_id not in referenced]


def id_key(pair):
    return int(pair[0].split('-')[1])


findings.sort(key=id_key, reverse=True)

lines = []
lines.append('# GO-scope-not-propagated inceptions')
lines.append('')
lines.append('Generated by fw audit (T-2096, structural predicate since T-3099).')
lines.append('Read-only: no task is closed, no status changed, no box ticked.')
lines.append('')
lines.append('## Criterion (structural — no prose is consulted)')
lines.append('')
lines.append('A completed task qualifies when ALL of:')
lines.append('')
lines.append('1. workflow_type: inception')
lines.append('2. the ## Decision block records a GO')
lines.append('3. related_tasks: is empty or absent')
lines.append('4. no task in active/ or completed/ names it on a related_tasks: line')
lines.append('5. no task declares unlocks_inception_decision: pointing at it')
lines.append('')
lines.append('## Population examined')
lines.append('')
lines.append('- completed inceptions: ' + str(total_inceptions))
lines.append('- with a GO recorded:   ' + str(go_inceptions))
lines.append('- findings:             ' + str(len(findings)))
lines.append('')
lines.append('These are candidates for triage, not confirmed abandoned decisions:')
lines.append('some may have shipped work that was simply never linked back. Deciding')
lines.append('which is which is the judgement this check exists to force.')
lines.append('')
lines.append('## Findings (most recent first)')
lines.append('')
if findings:
    for t_id, path in findings:
        lines.append('- ' + t_id + ' — ' + os.path.relpath(path, project_root))
else:
    lines.append('_None._')

try:
    with open(report_path, 'w') as f:
        f.write('\n'.join(lines) + '\n')
except Exception:
    pass

sample = ', '.join(t_id for t_id, _ in findings[:5])
overflow = len(findings) - min(5, len(findings))
if overflow > 0:
    sample += ' (+' + str(overflow) + ' more)'
print('|'.join([str(total_inceptions), str(go_inceptions), str(len(findings)), sample]))
" 2>/dev/null)

if [ -z "$go_scope_summary" ]; then
    # A scan that did not evaluate must not read as a scan that found nothing —
    # that is the exact defect T-3099 removed from this check. T-3105 replaced
    # the hand implementation with the shared verb: the behaviour is unchanged,
    # but there is now one definition of the rule rather than two that can drift.
    warn_unenumerable "the python3 pre-scan over $PROJECT_ROOT/.tasks" \
         "GO-scope-not-propagated scan" \
         "the pre-scan produced no summary line" \
         "Re-run the pre-scan without 2>/dev/null to see the error; the check asserts nothing until it does"
else
    IFS='|' read -r _gs_inceptions _gs_go _gs_count _gs_sample <<< "$go_scope_summary"
    if [ "${_gs_count:-0}" -eq 0 ]; then
        pass_over "${_gs_go:-0}" "GO-recorded completed inception(s) of ${_gs_inceptions:-0} completed inception(s)" \
             "No GO-scope-not-propagated inception(s) (sibling to L-417)" \
             "the workflow_type:inception filter matched ${_gs_inceptions:-0} completed task(s), of which 0 recorded a GO" \
             "Check the GO predicate against .tasks/completed/ by hand — an empty GO set is what T-3099 found and repaired, and it can regress"
    else
        warn "Found $_gs_count GO-scope-not-propagated inception(s) of ${_gs_go:-0} GO-recorded completed inception(s) examined — GO recorded, related_tasks empty, nobody back-references, no unlocks_inception_decision" \
             "$_gs_sample" \
             "Triage: per inception either backfill related_tasks: / unlocks_inception_decision:, or file the slices its GO approved. Full list: cat $GO_SCOPE_REPORT_PATH (origin: T-2078, T-2091, T-3099; sibling to L-417/T-1975)"
    fi
fi
# end GO-scope-not-propagated scan (T-3099)

# Fabric drift detection (T-212 — component topology integrity)
if [ -d "$PROJECT_ROOT/.fabric/components" ]; then
    fabric_cards=$(find "$PROJECT_ROOT/.fabric/components/" -maxdepth 1 -name '*.yaml' -type f 2>/dev/null | wc -l)
    if [ "$fabric_cards" -gt 0 ]; then
        drift_result=$(python3 -c "
import yaml, glob, os, re

PROJECT_ROOT = '$PROJECT_ROOT'
FABRIC_DIR = os.path.join(PROJECT_ROOT, '.fabric')
COMP_DIR = os.path.join(FABRIC_DIR, 'components')
WATCH_FILE = os.path.join(FABRIC_DIR, 'watch-patterns.yaml')

# Get registered locations
registered = set()
for card_path in glob.glob(os.path.join(COMP_DIR, '*.yaml')):
    with open(card_path) as f:
        data = yaml.safe_load(f)
    if data and data.get('location'):
        registered.add(data['location'])

orphaned = 0

# T-2735: this check no longer answers which watched files have no card.
# That question has exactly one answer in this file: the drift check below,
# which routes through expand_patterns.py (the T-1842 canonical expander).
# Full rationale sits beside that check. Kept prose-only and ASCII here
# because this block is a double-quoted python3 -c string, where backticks
# and dollar signs are shell-interpolated before python ever sees them
# (L-408). A backtick pair in this comment ran a glob as a command.

# Check orphaned cards
for card_path in glob.glob(os.path.join(COMP_DIR, '*.yaml')):
    with open(card_path) as f:
        data = yaml.safe_load(f)
    if data and data.get('location'):
        loc = data['location']
        # T-3049: skip URL locations. Same fix as agents/fabric/lib/drift.sh —
        # both sites answer 'is this card's file still there', and a hosted
        # service has no file to be missing. They must agree, or the CLI and the
        # daily audit report different orphan counts for one corpus.
        if re.match(r'^[a-zA-Z][a-zA-Z0-9+.-]*://', loc):
            continue
        if not os.path.exists(os.path.join(PROJECT_ROOT, loc)):
            orphaned += 1

print(f'{len(registered)} {orphaned}')
" 2>&1)
        fabric_registered=$(echo "$drift_result" | awk '{print $1}')
        fabric_orphan=$(echo "$drift_result" | awk '{print $2}')

        if [ "$fabric_orphan" -gt 0 ]; then
            warn "Fabric: $fabric_orphan orphaned card(s) (file deleted but card remains)" \
                 "$fabric_orphan cards reference missing files" \
                 "Run: fw fabric drift"
        fi
        # Coverage verdict belongs to the drift check below (T-2735) — it is the
        # one that routes through expand_patterns.py and the one that can WARN.
        pass "Fabric: $fabric_registered registered card(s)"

        # Check for unenriched cards (no depends_on AND no depended_by edges)
        # Cards explicitly marked `standalone: true` are excluded — these are
        # one-shot probes/tools with no framework imports by design (T-1754).
        unenriched_count=$(python3 -c "
import yaml, glob, os
COMP_DIR = os.path.join('$PROJECT_ROOT', '.fabric', 'components')
unenriched = 0
total = 0
for f in glob.glob(os.path.join(COMP_DIR, '*.yaml')):
    with open(f) as fh:
        d = yaml.safe_load(fh)
    if not d: continue
    if d.get('standalone') is True: continue
    total += 1
    deps = d.get('depends_on') or []
    depby = d.get('depended_by') or []
    if not deps and not depby:
        unenriched += 1
print(f'{unenriched} {total}')
" 2>&1)
        fabric_unenriched=$(echo "$unenriched_count" | awk '{print $1}')
        fabric_total=$(echo "$unenriched_count" | awk '{print $2}')
        fabric_enriched=$((fabric_total - fabric_unenriched))

        if [ "$fabric_unenriched" -gt 10 ]; then
            warn "Fabric: $fabric_unenriched/$fabric_total cards have no edges" \
                 "Graph coverage below target" \
                 "Run: fw fabric enrich"
        else
            pass "Fabric edges: $fabric_enriched/$fabric_total cards enriched ($fabric_unenriched without edges)"
        fi
    fi
fi

# Fabric drift: check for unregistered source files
WATCH_PATTERNS="$PROJECT_ROOT/.fabric/watch-patterns.yaml"
if [ -f "$WATCH_PATTERNS" ] && [ -d "$PROJECT_ROOT/.fabric/components" ]; then
    drift_result=$(python3 - "$PROJECT_ROOT" "$FRAMEWORK_ROOT" << 'DRIFTEOF'
import yaml, glob, os, sys, subprocess

# T-2735: roots arrive as argv, not from __file__. A heredoc script read from
# stdin has __file__ == '<stdin>', so any path derived from it is silently
# wrong (T-2734). Env is the fallback, argv is the contract.
PROJECT_ROOT = sys.argv[1] if len(sys.argv) > 1 else os.environ.get("PROJECT_ROOT", ".")
FRAMEWORK_ROOT = sys.argv[2] if len(sys.argv) > 2 else os.environ.get("FRAMEWORK_ROOT", "")
COMP_DIR = os.path.join(PROJECT_ROOT, ".fabric", "components")
WATCH_FILE = os.path.join(PROJECT_ROOT, ".fabric", "watch-patterns.yaml")

# Get all registered locations
registered = set()
for f in glob.glob(os.path.join(COMP_DIR, "*.yaml")):
    try:
        with open(f) as fh:
            d = yaml.safe_load(fh)
        if d and d.get("location"):
            registered.add(d["location"])
    except Exception:
        pass

# Get files matching watch patterns.
#
# T-2735: delegate expansion to expand_patterns.py — the T-1842 canonical
# expander, already used by register.sh (scan) and drift.sh. T-1842 extracted it
# precisely so the glob + exclude predicate would have one source of truth, but
# migrated only the two callers its author had in hand; the audit copies were
# left behind. The copy that stood here recursed and joined the root correctly
# but silently dropped `exclude:` — the key the expander exists to honour, and
# the one whose absence produced 5946 junk cards in the T-1842 origin incident.
expander = os.path.join(FRAMEWORK_ROOT, "agents", "fabric", "lib", "expand_patterns.py")
proc = subprocess.run(
    [sys.executable, expander, WATCH_FILE, PROJECT_ROOT],
    capture_output=True, text=True,
)
if proc.returncode != 0:
    # Loud, not silent: a broken expander must not read as "no drift".
    print(f"ERR {proc.returncode}")
    sys.exit(0)
watched = [line for line in proc.stdout.split("\n") if line.strip()]
unregistered = [rel for rel in watched if rel not in registered]

# T-2737: the registry's own contents are evidence about the watch file.
# A card exists because someone decided that file is a significant component.
# If no pattern covers it, the coverage denominator is demonstrably incomplete
# and every drift number is measuring a subset without saying so.
#
# Derived, not judged: this makes no claim about which files *should* be
# watched. It reports that the project has already answered that question for
# N files in a way the watch file cannot see.
watched_set = set(watched)
carded_unwatched = [loc for loc in registered
                    if loc not in watched_set
                    and os.path.isfile(os.path.join(PROJECT_ROOT, loc))]

print(f"{len(unregistered)} {len(registered)} {len(watched)} {len(carded_unwatched)}")
DRIFTEOF
    )
    drift_unreg=$(echo "$drift_result" | awk '{print $1}')
    drift_total=$(echo "$drift_result" | awk '{print $2}')
    drift_watched=$(echo "$drift_result" | awk '{print $3}')
    drift_carded_unwatched=$(echo "$drift_result" | awk '{print $4}')
    # T-2735: a non-numeric result means the expander failed. Without this arm
    # the `-gt 0` test below fails on the non-numeric value and falls through to
    # pass() — an instrument that cannot run would report as an instrument that
    # ran and found nothing. That is the defect this task exists to remove.
    if ! [[ "$drift_unreg" =~ ^[0-9]+$ ]]; then
        fail "Fabric drift: coverage expander failed — coverage is UNMEASURED" \
             "expand_patterns.py returned: ${drift_result:-<no output>}" \
             "Run: python3 agents/fabric/lib/expand_patterns.py .fabric/watch-patterns.yaml ."
    elif [ "$drift_unreg" -gt 0 ] 2>/dev/null; then
        warn "Fabric drift: $drift_unreg source file(s) have no fabric card" \
             "$drift_unreg unregistered files matching watch-patterns.yaml" \
             "Run: fw fabric scan"
    else
        # T-2737: state the size of the set that was actually measured. The old
        # wording was "All watched source files registered ($drift_total cards)"
        # where drift_total is the CARD count — so it read as "N files were
        # checked" while N was the registry size. 832 hit exactly this: their
        # "(15 cards)" sat on a watch file that expanded to zero files.
        pass_over "$drift_watched" "watched file(s)" "Fabric drift: all watched files registered" \
             "" "watch-patterns.yaml expanded to zero files — 832 shipped exactly this state with a green line on it (T-2737)"
    fi

    # T-2737: the watch file is the denominator of every coverage check above,
    # and nothing verified it matches the project it was stamped into by
    # `fw context init`. Two derived signals, both WARN-only.
    if [[ "$drift_watched" =~ ^[0-9]+$ ]] && [ "$drift_watched" -eq 0 ] \
       && [[ "$drift_total" =~ ^[0-9]+$ ]] && [ "$drift_total" -gt 0 ]; then
        # Degenerate case: coverage reads as complete because nothing was
        # checked. This is the shape that reported 13% as 100%.
        warn "Fabric: watch-patterns.yaml matches 0 files while $drift_total card(s) exist" \
             "Coverage checks are comparing an empty set — every fabric verdict above is vacuous" \
             "Tailor .fabric/watch-patterns.yaml to this project's source layout"
    elif [[ "$drift_carded_unwatched" =~ ^[0-9]+$ ]] && [ "$drift_carded_unwatched" -gt 0 ]; then
        warn "Fabric: $drift_carded_unwatched card(s) point at files no watch pattern covers" \
             "The registry already treats these as components; drift checks cannot see them, so coverage is measured over a subset" \
             "Widen .fabric/watch-patterns.yaml, or remove the cards if they are not components"
    fi
fi

# T-1771 (T-1768 GO follow-up): cron drift check.
# Mirrors `bin/fw doctor` cron-drift logic so the registry → generated →
# deployed pipeline is monitored alongside fabric drift, hook threshold,
# etc. — same surface, same cron, no new alert channel. WARN was the
# doctor's level; here we use FAIL on substantive drift because cron
# drift means *tasks won't run* (silent execution failure), strictly
# more serious than a missing fabric card. Origin: T-1767 (cron-touching
# task closed work-completed while drift made the new job a no-op for
# 3 days). G-064 closure path.
_cron_registry="$PROJECT_ROOT/.context/cron-registry.yaml"
if [ -f "$_cron_registry" ] && fw_is_linked_worktree "$PROJECT_ROOT"; then
    # T-2435 (OBS-077): cron is a HOST-level concern installed once from the canonical
    # main checkout. A linked worktree derives a worktree-named target that is never
    # generated/installed (and must not be), so every cron drift check below is a pure
    # worktree artifact, not content drift. Skip with INFO (counts as PASS; never blocks
    # a worktree push). The real registry→generated→deployed chain is gated on main.
    info "Cron drift checks skipped — linked worktree (cron is host-level, managed from the main checkout)"
elif [ -f "$_cron_registry" ] && \
     { source "$FRAMEWORK_ROOT/lib/cron-registry.sh"; [ "$(cron_registry_job_count "$_cron_registry")" = "0" ]; }; then
    # T-2844: `fw init` seeds `jobs: []`. An empty registry has no generated form,
    # so "present but not generated" is the correct state, not drift. Parity with
    # the same guard in `fw doctor` (bin/fw) — both surfaces emitted this on every
    # freshly initialised project. A malformed registry returns -1, not 0, and
    # falls through to the checks below on purpose.
    info "Cron drift checks skipped — registry declares no jobs (nothing to generate)"
elif [ -f "$_cron_registry" ]; then
    _cron_source="$PROJECT_ROOT/.context/cron/agentic-audit.crontab"
    _cron_target_dir="${FW_CRON_INSTALL_DIR:-/etc/cron.d}"
    _cron_slug=$(basename "$PROJECT_ROOT" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9_-]/-/g')
    _cron_target="$_cron_target_dir/agentic-audit-${_cron_slug}"

    # T-1943 (T-1942 audit-side sibling): registry → generated drift detection.
    # Mirrors bin/fw doctor logic so the third leg of the three-step sync
    # (registry → generated → deployed) is monitored at audit's daily-cron
    # cadence. FAIL severity because registry → generated drift means the new
    # cron entry is invisible to the OS scheduler — same "tasks won't run"
    # class as the deployed-side FAIL below. Origin: T-1935 (bvp-cost-estimator
    # registry entry sat 3+ days drifted while doctor reported "in sync").
    # T-1944: dry-run logic extracted to lib/cron_dry_run.py per L-332/L-408
    # (single source of truth + bash side stays parse-safe).
    if [ -f "$_cron_source" ]; then
        _cron_dry_run=$(python3 "$FRAMEWORK_ROOT/lib/cron_dry_run.py" "$PROJECT_ROOT" "$_cron_registry" "$FRAMEWORK_ROOT/bin/fw" 2>/dev/null || echo "__SKIP__")
        if [ "$_cron_dry_run" != "__SKIP__" ] && [ -n "$_cron_dry_run" ]; then
            _cron_on_disk=$(cat "$_cron_source" 2>/dev/null)
            if [ "$_cron_dry_run" != "$_cron_on_disk" ]; then
                fail "Cron drift: $_cron_registry is ahead of $_cron_source (registry edited but not generated)" \
                     "Registry has been edited since the generated crontab was produced — new/modified jobs are invisible to the OS scheduler" \
                     "Run: fw cron generate"
            fi
        fi
    fi

    if [ -f "$_cron_source" ] && [ -f "$_cron_target" ]; then
        if diff -q "$_cron_source" "$_cron_target" >/dev/null 2>&1; then
            pass "Cron registry in sync with $_cron_target"
        else
            # T-3126: the comparand is $_cron_target_dir (host state, /etc/cron.d
            # by default). No git ref contains it, and no push creates or clears
            # it — so this FAIL cannot be a property of the ref being pushed.
            fail "Cron drift: $_cron_source differs from deployed $_cron_target" \
                 "Registry edits or generator output have not been deployed — cron jobs may be running stale or absent" \
                 "Run: fw cron install" \
                 worktree "host state: $_cron_target_dir"
        fi
    elif [ -f "$_cron_source" ] && [ ! -f "$_cron_target" ]; then
        # T-3126: host-state comparand, same as the deployed-drift arm above.
        fail "Cron drift: generated but not installed at $_cron_target" \
             "Generated crontab exists but is not deployed — scheduled jobs are not running" \
             "Run: fw cron install" \
             worktree "host state: $_cron_target_dir"
    elif [ ! -f "$_cron_source" ]; then
        warn "Cron drift: registry present but not generated" \
             "$_cron_registry exists but $_cron_source is missing" \
             "Run: fw cron install"
    fi
fi

# T-1722: cron-misload lint — detect dormant USER-field crontab files.
# PL-173 case (2): a source-of-truth crontab at .context/cron/*.crontab uses
# /etc/cron.d/ USER-field syntax ('m h dom mon dow USER cmd') but no matching
# /etc/cron.d/ counterpart exists -> the crontab is dormant (jobs don't run).
# This is the silent-failure mode that ran G-058 for 16 days. The standard
# registry check above only covers the framework's auto-generated
# agentic-audit.crontab; this loop covers every other .context/cron/*.crontab
# (release-mirror-canary, heartbeat, project-specific ad-hoc files, ...).
_cron_lint_dir="$PROJECT_ROOT/.context/cron"
if [ -d "$_cron_lint_dir" ] && fw_is_linked_worktree "$PROJECT_ROOT"; then
    # T-2437 (OBS-077 keystone): sibling of the registry-block worktree-skip
    # (T-2435). This lint reads /etc/cron.d/ for an install under the WORKTREE
    # slug that never exists — cron is installed once from the main checkout
    # under the MAIN slug — so every dormant-crontab FAIL here is a pure worktree
    # artifact. Cron install state is HOST-ENVIRONMENT, not content, so it is
    # owned by the main checkout and skipped in a linked worktree.
    #
    # The content-vs-environment classification (the keystone): a pre-push /
    # audit check may FAIL in a linked worktree ONLY when it measures committed
    # CONTENT drift (self-vendor T-2436, fabric, task YAML, secrets, hook
    # threshold). Checks that measure HOST/working-copy ENVIRONMENT state
    # (cron install at /etc/cron.d/, both legs here and at the registry block)
    # are INFO-skipped — they are managed from main and their absence in a
    # transient worktree is expected, not a regression. See L-486.
    info "Cron-misload lint skipped — linked worktree (cron install is host-level, managed from the main checkout)"
elif [ -d "$_cron_lint_dir" ]; then
    _cron_lint_target_dir="${FW_CRON_INSTALL_DIR:-/etc/cron.d}"
    _cron_lint_slug=$(basename "$PROJECT_ROOT" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9_-]/-/g')
    for _cf in "$_cron_lint_dir"/*.crontab; do
        [ -f "$_cf" ] || continue
        _cf_base=$(basename "$_cf" .crontab)
        # Skip the framework's own crontab -- handled by the registry check above.
        [ "$_cf_base" = "agentic-audit" ] && continue
        # USER-field syntax detection: any non-comment / non-VAR= line whose
        # first field is cron-numeric (digits/*/-/,) AND whose 6th field looks
        # like a Unix username (starts with [a-z_] then [a-z0-9_-]*).
        _cf_userlike=$(awk '
            /^[[:space:]]*#/ { next }
            /^[[:space:]]*$/ { next }
            /^[A-Z_][A-Z0-9_]*=/ { next }
            NF >= 7 && $1 ~ /^[0-9*,/-]+$/ && $6 ~ /^[a-z_][a-z0-9_-]*$/ { print "yes"; exit }
        ' "$_cf" 2>/dev/null)
        [ "$_cf_userlike" = "yes" ] || continue
        # Find a matching install. Try canonical names first, then content match.
        _cf_install=""
        for _cand in \
            "$_cron_lint_target_dir/$_cf_base" \
            "$_cron_lint_target_dir/termlink-$_cf_base" \
            "$_cron_lint_target_dir/${_cron_lint_slug}-$_cf_base"; do
            if [ -f "$_cand" ]; then
                _cf_install="$_cand"
                break
            fi
        done
        if [ -z "$_cf_install" ]; then
            # Content fallback: pick the first command in the crontab and search
            # /etc/cron.d/ for any file containing it.
            _cf_sig=$(awk '/^[0-9*]/ { for (i=7; i<=NF; i++) printf "%s ", $i; print ""; exit }' "$_cf" 2>/dev/null \
                | head -c 80)
            if [ -n "$_cf_sig" ] && [ -d "$_cron_lint_target_dir" ]; then
                _cf_install=$(grep -lF "$_cf_sig" "$_cron_lint_target_dir"/* 2>/dev/null | head -n1)
            fi
        fi
        if [ -n "$_cf_install" ]; then
            pass "cron(${_cf_base}): USER-field syntax installed at $_cf_install"
        else
            # T-3126: host-state comparand ($_cron_lint_target_dir).
            fail "cron(${_cf_base}): USER-field syntax but no install in $_cron_lint_target_dir" \
                 "Source: $_cf. Dormant -- scheduled jobs are not running (PL-173 / G-058 prevention)." \
                 "Install: sudo cp $_cf $_cron_lint_target_dir/${_cron_lint_slug}-$_cf_base && sudo systemctl reload cron" \
                 worktree "host state: $_cron_lint_target_dir"
        fi
    done
fi

# T-3095 (T-3093 slice 2): branch hygiene promoted onto the audit cron.
#
# The rail shipped 2026-07-04 with exactly one caller — `bin/fw doctor` — and
# doctor appears on ZERO cron lines. So nothing has ever put branch hygiene in
# front of anyone on a schedule, which is why four real strands (43-55 days,
# 202 unlanded commits on one of them) sat unread. This block is the same
# promotion `bin/fw doctor` -> audit that T-1771/T-1942/T-1943 did for cron
# drift: same surface, same cron, no new alert channel.
#
# It CALLS lib/branch-hygiene.sh rather than mirroring its classification. The
# cron-drift precedent above mirrored doctor's logic, and that second copy is
# the L-399 producer/consumer split this slice deliberately does not repeat —
# there is one predicate (fw_branch_hygiene) and both surfaces read it.
#
# WARN, never FAIL: T-3093 ruled out a blocking gate and per-strand auto-filing
# because both act on a signal whose false-positive rate was only fixed in
# slice 1 (T-3094 — recency, not behind-count), and both are much harder to
# walk back than a WARN. Audit's exit code is therefore unchanged by branch
# findings alone: warnings exit 1, never 2.
_bh_lib="$FRAMEWORK_ROOT/lib/branch-hygiene.sh"
if [ -f "$_bh_lib" ] && git -C "$PROJECT_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
    if fw_is_linked_worktree "$PROJECT_ROOT"; then
        # Same guard and same reasoning as the cron blocks above (T-2435 /
        # T-2437, OBS-077): branch hygiene is a whole-repository concern
        # evaluated from the canonical checkout. A linked worktree derives a
        # different branch set and would report its own transient branch as
        # debris. Environment state, not content state -> INFO, never WARN.
        info "Branch hygiene skipped — linked worktree (branch set is whole-repo, evaluated from the main checkout)"
    elif ! git -C "$PROJECT_ROOT" rev-parse --verify -q origin/master >/dev/null 2>&1 \
         && ! git -C "$PROJECT_ROOT" rev-parse --verify -q master >/dev/null 2>&1; then
        # fw_branch_hygiene returns silently when there is no master lineage to
        # judge against — indistinguishable at the call site from a tidy repo.
        # Reporting that as "clean" is the false-green class this framework has
        # hit repeatedly (T-2732, OBS-185): a check that could not run must not
        # report as a check that ran and found nothing.
        info "Branch hygiene skipped — no master lineage to judge against (origin/master and master both absent)"
    else
        source "$_bh_lib"
        _bh_out=$(fw_branch_hygiene "$PROJECT_ROOT" 2>/dev/null || true)
        if [ -n "$_bh_out" ]; then
            _bh_count=$(printf '%s\n' "$_bh_out" | grep -c .)
            # T-3092: class-representative, not positional. A flat `head -N` is
            # what hid every remote finding in doctor (0 of 4 shown on this repo)
            # because emission order is local -> worktree -> remote and the local
            # classes filled the cap. Audit prints more sections than doctor, so
            # a truncated class here is even less likely to be noticed.
            _bh_shown=$(printf '%s\n' "$_bh_out" | fw_branch_hygiene_head 12 | sed '2,$s/^/         /')
            _bh_full="bash -c 'source \"$_bh_lib\"; fw_branch_hygiene \"$PROJECT_ROOT\"'"
            if [ "$_bh_count" -gt 12 ]; then
                _bh_shown="$_bh_shown
         … $((_bh_count - 12)) more (shown lines are one-per-class, not the worst)"
            fi
            _bh_fix="Cleanup: git branch -d <name> (merged); fw integrate run (overdue merge-back). Full list: $_bh_full"
            if printf '%s\n' "$_bh_out" | grep -q '^diverged-fork '; then
                # T-100195 (RCA T-100194): a fork is BOTH ahead and behind, so a
                # go-live `git merge origin/master` conflicts and a one-way
                # `fw integrate` cannot absorb what master has. Different remedy,
                # so it has to be named separately or the mitigation is wrong.
                _bh_fix="$_bh_fix — FORK present: reconcile while small (merge origin/master INTO the branch, or reset if its commits already landed). Do NOT use fw integrate on a fork."
            fi
            warn "Branch hygiene: $_bh_count finding(s) — stale branches, worktrees or remote refs" \
                 "$_bh_shown" \
                 "$_bh_fix"
        else
            pass "Branch hygiene: no stale branches, worktrees or remote refs"
        fi
    fi
fi

# T-1631 (B-3b of T-1626): Hook-failure threshold check.
# Reads .hook-counter + .hook-failure-counter (T-1628 telemetry) and
# warns if any hook is failing in production over threshold. Does NOT
# auto-register here — that's --register. Audit surfaces the signal;
# operator runs `fw concerns scan-hooks --register` (or cron job) to
# materialize G-entries.
HOOK_THRESHOLD_HELPER="$FRAMEWORK_ROOT/lib/hook-threshold.py"
HOOK_COUNTER_FILE="$PROJECT_ROOT/.context/working/.hook-counter"
if [ -f "$HOOK_THRESHOLD_HELPER" ] && [ -f "$HOOK_COUNTER_FILE" ]; then
    hook_threshold_out=$(PROJECT_ROOT="$PROJECT_ROOT" python3 "$HOOK_THRESHOLD_HELPER" 2>/dev/null)
    if [ -n "$hook_threshold_out" ]; then
        hook_failing=$(echo "$hook_threshold_out" | grep -c "^FAIL|" || true)
        warn "Hook threshold: $hook_failing hook(s) failing over threshold (T-1626)" \
             "$hook_threshold_out" \
             "Run: python3 $FRAMEWORK_ROOT/lib/hook-threshold.py --register (or fw upgrade if witness pattern)"
    else
        pass "Hook threshold: no hooks failing over threshold"
    fi
fi

# T-3062: the T-1845 whole-tree scanners used to live here, inside `structure`.
# They now live in SECTION 1b below. See that block for why.

# T-2244: Self-vendor drift FAIL (F2 N×M daily-cron backstop). Mirrors
# `bin/fw doctor` Check 2b (T-1434 + T-2243) and the pre-push gate
# (T-2240/T-2241). Audit is the third surface — daily cron catches any
# drift that slipped past the developer-facing gates (e.g.
# FW_SKIP_SELF_VENDOR_CHECK=1 push followed by forgotten follow-up).
#
# Only runs when PROJECT_ROOT == FRAMEWORK_ROOT (framework-repo audit).
# On consumer projects, .agentic-framework/ IS the source, not vendored.
# Per-class counters (libs + templates) so neither class can bury the
# other in the FAIL report — same pattern as T-2243 doctor leg.
check_self_vendor_drift() {
    if [ "$PROJECT_ROOT" != "$FRAMEWORK_ROOT" ]; then
        return 0
    fi
    if [ ! -d "$FRAMEWORK_ROOT/.agentic-framework" ]; then
        return 0
    fi

    local _sv_libs=0 _sv_tpl=0
    local _sv_libs_list="" _sv_tpl_list=""
    # T-3126: of the drifting pairs, how many still drift in HEAD. A pair whose
    # committed blobs already agree is drift a concurrent session created in the
    # working tree — real for `fw vendor self`, absent from every ref.
    local _sv_libs_head=0 _sv_tpl_head=0
    local _sv_git_ok=0
    _t3126_git_ok "$FRAMEWORK_ROOT" && _sv_git_ok=1

    # libs class: .agentic-framework/{bin,lib,agents,web}/* vs source
    while IFS= read -r _vf; do
        [ -f "$_vf" ] || continue
        local _rel="${_vf#$FRAMEWORK_ROOT/.agentic-framework/}"
        local _src="$FRAMEWORK_ROOT/$_rel"
        if [ -f "$_src" ] && ! cmp -s "$_vf" "$_src" 2>/dev/null; then
            _sv_libs=$((_sv_libs + 1))
            if [ "$_sv_libs" -le 5 ]; then
                _sv_libs_list="$_sv_libs_list $_rel"
            fi
            # Cannot read git → count every pair as committed (fail-safe → ref).
            if [ "$_sv_git_ok" != "1" ] || _t3126_pair_drifts_in_head "$FRAMEWORK_ROOT" "$_rel"; then
                _sv_libs_head=$((_sv_libs_head + 1))
            fi
        fi
    # T-2304 (OBS-068) + T-2307 (follow-on): `*.md` is in scope for parity with
    # `_self_vendor_agents` (T-2266+T-2304) and `_self_vendor_libs` (T-2307).
    # AGENT.md intelligence files + lib/templates/*.md siblings drift silently
    # between source and vendored copies. Audit scans bin/lib/agents/web with
    # the same filter; bin has no tracked .md content (no-op there); lib/agents
    # both have tracked .md siblings and both helpers now sync them recursively
    # via `bin/fw vendor self`. Net: audit FAIL → helper SYNC closure, no
    # `fw vendor` full-mode fallback needed.
    # T-2502: `-name "claude-fw"` added — the extensionless operator auto-restart
    # wrapper (bin/claude-fw) matches neither `*.sh`/`*.py`/`*.md` nor `fw`, so the
    # vendored copy drifted undetected (sibling of T-2501's on-PATH drift). Parity:
    # `_self_vendor_shim` (lib/upgrade.sh) now syncs claude-fw too, so this FAIL is
    # clearable via `fw vendor self` (L-399 producer/consumer parity).
    # T-2793: bin/ is scanned WHOLE, the other three keep the name filter.
    # bin/ holds executables and nothing else, so a name filter there could only
    # ever be an incomplete list of them — and was: bin/fw-shim and bin/fw-router
    # are extensionless and matched none of *.sh/*.py/fw/claude-fw/*.md, so both
    # sat outside this gate AND outside _self_vendor_shim's sync set. Parity with
    # lib/upgrade.sh:_self_vendor_shim, which now enumerates bin/ the same way.
    done < <(
        find "$FRAMEWORK_ROOT/.agentic-framework/bin" -type f ! -name "*.pyc" 2>/dev/null
        find "$FRAMEWORK_ROOT/.agentic-framework/lib" "$FRAMEWORK_ROOT/.agentic-framework/agents" "$FRAMEWORK_ROOT/.agentic-framework/web" -type f \( -name "*.sh" -o -name "*.py" -o -name "fw" -o -name "claude-fw" -o -name "*.md" \) 2>/dev/null
    )

    # templates class: .agentic-framework/.tasks/templates/*.md vs source
    if [ -d "$FRAMEWORK_ROOT/.agentic-framework/.tasks/templates" ]; then
        while IFS= read -r _vf; do
            [ -f "$_vf" ] || continue
            local _rel="${_vf#$FRAMEWORK_ROOT/.agentic-framework/}"
            local _src="$FRAMEWORK_ROOT/$_rel"
            if [ -f "$_src" ] && ! cmp -s "$_vf" "$_src" 2>/dev/null; then
                _sv_tpl=$((_sv_tpl + 1))
                if [ "$_sv_tpl" -le 5 ]; then
                    _sv_tpl_list="$_sv_tpl_list $_rel"
                fi
                if [ "$_sv_git_ok" != "1" ] || _t3126_pair_drifts_in_head "$FRAMEWORK_ROOT" "$_rel"; then
                    _sv_tpl_head=$((_sv_tpl_head + 1))
                fi
            fi
        done < <(find "$FRAMEWORK_ROOT/.agentic-framework/.tasks/templates" -type f -name "*.md" 2>/dev/null)
    fi

    if [ "$_sv_libs" -eq 0 ] && [ "$_sv_tpl" -eq 0 ]; then
        pass "Self-vendor drift: vendored .agentic-framework/ in sync with source (libs + templates)"
        return 0
    fi

    if [ "$_sv_libs" -gt 0 ]; then
        # T-2436 (OBS-076): the T-2247 comment claimed `fw vendor self` only syncs
        # .agentic-framework/lib/, so this recommended full `fw vendor`. That is
        # STALE — since T-2264/T-2266/T-2267 `fw vendor self` runs all six helpers
        # (libs+templates+policy+shim+agents+web) = bin+lib+agents+web, the exact
        # scope this libs-class check scans. Recommend `fw vendor self` so the
        # FAIL's fix command AGREES with the canonical sync verb (and with
        # `fw vendor self --check`, the read-only verifier added in T-2436).
        # T-3126: ref-scoped iff at least one drifting pair still drifts in HEAD.
        fail "Self-vendor drift: libs class — $_sv_libs file(s) out of sync (T-2244)" \
             "First $([ $_sv_libs -gt 5 ] && echo 5 || echo $_sv_libs):$_sv_libs_list" \
             "Run: fw vendor self  (syncs all vendored .agentic-framework/ classes — verify with: fw vendor self --check)" \
             "$([ "$_sv_libs_head" -gt 0 ] && echo ref || echo worktree)" \
             "$_sv_libs_head of $_sv_libs drifting pair(s) also drift in HEAD"
    fi
    if [ "$_sv_tpl" -gt 0 ]; then
        # Templates class is correctly scoped to 'fw vendor self' — it syncs
        # .tasks/templates as a sibling of lib/ (lib/upgrade.sh _self_vendor_templates).
        fail "Self-vendor drift: templates class — $_sv_tpl file(s) out of sync (T-2244)" \
             "First $([ $_sv_tpl -gt 5 ] && echo 5 || echo $_sv_tpl):$_sv_tpl_list" \
             "Run: fw vendor self  (sync .agentic-framework/ templates with source)" \
             "$([ "$_sv_tpl_head" -gt 0 ] && echo ref || echo worktree)" \
             "$_sv_tpl_head of $_sv_tpl drifting pair(s) also drift in HEAD"
    fi
}
check_self_vendor_drift

# T-2837: run the structural invariant suite (tests/lint/) from audit.
#
# The suite had a runner since T-2697 (`fw test invariants`, and inside
# `fw test all`) but nothing invoked it on a schedule: 25 cron jobs, of which
# five run `fw audit`, and none ran any test suite. So a red invariant could sit
# unread indefinitely while every automated surface stayed green — which is what
# happened. `help-router-parity` was red while 20 verbs drifted out of `fw help`
# (T-2836), and `config-registry-parity` was red for two config keys that never
# reached /config (T-2838). Both were found by hand, not by the guards that were
# already asserting them correctly.
#
# Placed in the STRUCTURE section so it inherits the */30 cron and the pre-push
# audit. Cost is 51 tests in ~6s, measured — negligible against a 30-minute job.
#
# A missing bats emits WARN, never a silent pass: "not checked" and "checked and
# clean" are different states, and collapsing them is the exact failure mode this
# check exists to end.
check_invariant_suite() {
    local _dir="$FRAMEWORK_ROOT/tests/lint"
    [ -d "$_dir" ] || return 0
    ls "$_dir"/*.bats >/dev/null 2>&1 || return 0

    if ! command -v bats >/dev/null 2>&1; then
        warn "Invariant suite NOT CHECKED — bats is not installed (T-2837)" \
             "tests/lint/ holds the structural invariants (router↔help parity, config-registry parity, single-vendor-writer); none were evaluated this run" \
             "Install bats, or run the suite where bats exists: fw test invariants"
        return 0
    fi

    local _out _red _total
    _out=$(cd "$FRAMEWORK_ROOT" && timeout 300 bats tests/lint/ 2>&1) || true
    _red=$(printf '%s\n' "$_out" | grep -c '^not ok' || true)
    _total=$(printf '%s\n' "$_out" | grep -cE '^(not ok|ok) ' || true)

    if [ "$_red" -eq 0 ]; then
        # T-2837 hand-implemented the zero-population WARN here; T-3105 folded it
        # onto the shared verb so there is one definition of the rule. The
        # bespoke evidence and mitigation are preserved verbatim — a harness that
        # emits no TAP at all is a more specific diagnosis than "set empty".
        pass_over "$_total" "structural invariant(s) (tests/lint/)" "Invariant suite green" \
             "bats ran but emitted neither 'ok' nor 'not ok' — a harness error, not a green suite (T-2837)" \
             "Run manually and read the output: fw test invariants"
        return 0
    fi

    # T-3126: decide, per RED test, whether the failure is a property of the
    # COMMIT or of the working tree. The origin case (2026-08-23) was two
    # UNTRACKED tests/lint/*.bats files a concurrent session had dropped in: bats
    # collects them, an invariant goes red, and a ref containing neither file is
    # refused.
    #
    # Two independent grounds make one RED test worktree-scoped:
    #   (a) the .bats file DECLARING it is untracked-in-HEAD or modified-vs-HEAD
    #       — the assertion itself is not in any ref;
    #   (b) its failure evidence names at least one repo path and EVERY path it
    #       names is untracked-in-HEAD or modified-vs-HEAD — the assertion is
    #       committed, but everything it is complaining about is not. This is the
    #       shape of `no-untracked-test-files.bats`, whose whole subject is files
    #       that exist nowhere but the working tree.
    # The declaring file named by bats's own `(in test file …)` line is excluded
    # from (b)'s path harvest: it is present in every failure block and is
    # normally committed, so counting it would make (b) unreachable.
    #
    # The whole FINDING is worktree-scoped only when EVERY red test is, and at
    # least one was attributable. Any red test in committed code about committed
    # content, and any red test that cannot be attributed at all, makes it
    # ref-scoped — a mixture must keep blocking.
    local _inv_scope="ref" _inv_reason=""
    local _inv_dirty=0 _inv_clean=0 _inv_unattributed=0
    if _t3126_git_ok "$FRAMEWORK_ROOT"; then
        local _inv_decl _inv_evs _inv_ev _inv_any_ev _inv_all_unc
        while IFS='|' read -r _inv_decl _inv_evs; do
            if [ -z "$_inv_decl" ] && [ -z "$_inv_evs" ]; then
                _inv_unattributed=$((_inv_unattributed + 1))
                continue
            fi
            # (a) the assertion itself is not committed
            if [ -n "$_inv_decl" ] && _t3126_path_uncommitted "$FRAMEWORK_ROOT" "$_inv_decl"; then
                _inv_dirty=$((_inv_dirty + 1))
                continue
            fi
            # (b) everything the assertion names is not committed
            _inv_any_ev=0; _inv_all_unc=1
            local _oldifs="$IFS"; IFS=';'
            for _inv_ev in $_inv_evs; do
                [ -z "$_inv_ev" ] && continue
                _inv_any_ev=1
                _t3126_path_uncommitted "$FRAMEWORK_ROOT" "$_inv_ev" || _inv_all_unc=0
            done
            IFS="$_oldifs"
            if [ "$_inv_any_ev" = "1" ] && [ "$_inv_all_unc" = "1" ]; then
                _inv_dirty=$((_inv_dirty + 1))
            else
                _inv_clean=$((_inv_clean + 1))
            fi
        done < <(printf '%s\n' "$_out" | python3 "$FRAMEWORK_ROOT/lib/bats_red_attribution.py" "$FRAMEWORK_ROOT" 2>/dev/null)

        if [ "$_inv_clean" -eq 0 ] && [ "$_inv_unattributed" -eq 0 ] && [ "$_inv_dirty" -gt 0 ]; then
            _inv_scope="worktree"
            _inv_reason="all $_inv_dirty RED test(s) are about state not committed to HEAD"
        else
            _inv_reason="$_inv_clean RED test(s) about committed content, $_inv_unattributed unattributed"
        fi
    else
        _inv_reason="git HEAD unreadable — scope undecidable, defaulting to ref"
    fi

    fail "Invariant suite: $_red of $_total structural invariant(s) RED (T-2837)" \
         "$(printf '%s\n' "$_out" | grep '^not ok' | head -3 | sed 's/^not ok [0-9]* //' | tr '\n' ';')" \
         "Run: fw test invariants" \
         "$_inv_scope" "$_inv_reason"
}
check_invariant_suite

# T-2577 (T-2571 S4): designer ghost↔task drift sweep, both directions.
# The save-time mint is non-fatal by contract (a failed mint must never break
# /api/save), so this sweep is the backstop that keeps the failure visible:
#   A: ghost with task:null older than the grace window — the mint failed (or
#      was skipped, e.g. no fw shim) and the documentation debt is invisible.
#   B: ghost task: T-ID resolving to no task file — the task was deleted or
#      renamed out from under the registry (dangling uuid↔task join).
# Silent when no registry exists (project has no designer store yet).
check_designer_ghost_drift() {
    local _reg="$PROJECT_ROOT/.context/designer/registry.yaml"
    [ -f "$_reg" ] || return 0
    local _out
    _out=$(python3 - "$_reg" "$PROJECT_ROOT" "${FW_GHOST_TASK_GRACE_HOURS:-24}" <<'PYEOF'
import glob, os, sys, time
import yaml
reg_p, root, grace_h = sys.argv[1], sys.argv[2], float(sys.argv[3])
try:
    reg = yaml.safe_load(open(reg_p)) or {}
except Exception:
    print("parse-error|||")
    raise SystemExit(0)
ghosts = reg.get("ghosts") or []
task_ids = set()
for f in glob.glob(os.path.join(root, ".tasks", "active", "T-*.md")) + glob.glob(
    os.path.join(root, ".tasks", "completed", "T-*.md")
):
    parts = os.path.basename(f).split("-")
    if len(parts) >= 2:
        task_ids.add(parts[0] + "-" + parts[1])
now = time.time()
unminted = [
    g.get("uuid", "?")
    for g in ghosts
    if not g.get("task") and (now - (g.get("first_seen") or 0)) > grace_h * 3600
]
dangling = [
    f"{g['task']}({g.get('uuid', '?')[:8]})"
    for g in ghosts
    if g.get("task") and g["task"] not in task_ids
]
print(f"{len(unminted)}|{' '.join(unminted[:5])}|{len(dangling)}|{' '.join(dangling[:5])}")
PYEOF
    )
    if [ "${_out%%|*}" = "parse-error" ]; then
        warn "Designer ghost registry unparseable: $_reg" \
             "yaml.safe_load failed — registry writes are atomic, so this suggests manual edit damage" \
             "Inspect the file; registry regenerates entries on next designer save"
        return 0
    fi
    local _unminted _unminted_list _dangling _dangling_list
    IFS='|' read -r _unminted _unminted_list _dangling _dangling_list <<< "$_out"
    if [ "${_unminted:-0}" -eq 0 ] && [ "${_dangling:-0}" -eq 0 ]; then
        pass "Designer ghost registry: ghost↔task joins clean"
        return 0
    fi
    if [ "${_unminted:-0}" -gt 0 ]; then
        warn "Designer ghosts without documentation task: $_unminted past grace window (T-2577)" \
             "uuids:$_unminted_list — save-time mint failed or was skipped; debt is invisible until minted" \
             "Re-save the referring diagram (re-triggers minting) or check the Watchtower stderr log for mint failures. Grace window: FW_GHOST_TASK_GRACE_HOURS (default 24)."
    fi
    if [ "${_dangling:-0}" -gt 0 ]; then
        warn "Designer ghost task joins dangling: $_dangling T-ID(s) resolve to no task file (T-2577)" \
             "entries:$_dangling_list — task deleted/renamed out from under the registry" \
             "Restore the task or clear the ghost's task: field so the next save re-mints"
    fi
}
check_designer_ghost_drift

# T-2621/T-2654: map-conformance rail — corpus maps vs their enforced machines.
# Which maps have a rail, and what each conforms against, lives in
# tools/conformance-registry.yaml (T-2652 GO slice 1); the checker dispatches
# on each entry's primitive. One audit line per registry entry. Divergence is
# the finding, not a failure of the rail — a map graduates to detail-authority
# only when its entry stays green (T-2619 cascading-detail model).
check_map_conformance() {
    local _tool="$PROJECT_ROOT/tools/corpus_conformance.py"
    local _registry="$PROJECT_ROOT/tools/conformance-registry.yaml"
    local _store="$PROJECT_ROOT/.context/designer/projects"
    if [ ! -f "$_tool" ] || [ ! -f "$_registry" ] || [ ! -d "$_store" ]; then
        return 0  # rail not applicable (consumer project / no corpus)
    fi
    local _maps
    _maps=$(python3 -c "
import yaml
doc = yaml.safe_load(open('$_registry')) or {}
print('\n'.join(doc.keys()))
" 2>/dev/null)
    if [ -z "$_maps" ]; then
        info "Map conformance: registry empty or unparseable — no maps opted into a rail"
        return 0
    fi
    local _map _out _rc
    while IFS= read -r _map; do
        [ -n "$_map" ] || continue
        _out=$(python3 "$_tool" --map "$_map" --root "$PROJECT_ROOT" 2>&1)
        _rc=$?
        case "$_rc" in
            0)
                if echo "$_out" | grep -q "SKIP"; then
                    info "Map conformance: $_map has no state-carrier annotations yet (rail dormant)"
                else
                    pass "Map conformance: $_map matches its enforced machine"
                fi
                ;;
            1)
                warn "Map conformance: $_map diverges from its enforced machine (T-2621/T-2654)" \
                     "$(echo "$_out" | grep -E 'map-asserts|code-allows' | tr '\n' '; ')" \
                     "Update the map (pair-draft round) or fix the registry source if the map is right — the rail must be green before the map graduates to detail-authority (T-2619)"
                ;;
            *)
                warn "Map conformance: checker failed to load $_map (T-2621/T-2654)" \
                     "$_out" \
                     "Inspect .context/designer/projects/$_map/, tools/conformance-registry.yaml, and tools/corpus_conformance.py"
                ;;
        esac
    done <<< "$_maps"
}
check_map_conformance

# T-2623: draft hygiene — drafts (id prefix draft-) untouched >30 days surface
# as INFO (never WARN: drafts are the cheap tier; staleness is a nudge, not drift).
check_stale_drafts() {
    local _store="$PROJECT_ROOT/.context/designer/projects"
    [ -d "$_store" ] || return 0
    local _now _stale="" _d _mp _upd
    _now=$(date +%s)
    for _d in "$_store"/draft-*/; do
        [ -d "$_d" ] || continue
        _mp="$_d/meta.json"
        [ -f "$_mp" ] || continue
        _upd=$(python3 -c "import json,sys; print(int(json.load(open(sys.argv[1])).get('updated') or 0))" "$_mp" 2>/dev/null || echo 0)
        if [ "${_upd:-0}" -gt 0 ] && [ $(( _now - _upd )) -gt $(( 30 * 86400 )) ]; then
            _stale="$_stale $(basename "$_d")"
        fi
    done
    if [ -n "$_stale" ]; then
        info "Stale draft(s), 30d+ untouched:$_stale — promote via the ceremony or delete from the gallery (T-2623)"
    fi
}
check_stale_drafts

# T-2994 (build slice of T-2992). A .gitignore rule is the only common
# suppression that emits nothing when it fires — no run, no report, no moment at
# which it says "I am suppressing something". So a comment beside one that
# promises future work is the single place where deferral prose is a strong
# signal rather than noise (measured: 184 false positives if the same
# vocabulary is scanned across lib/ + agents/).
#
# WARN, never FAIL. The remedy is "file it or name it", which is a judgement the
# operator makes, not a condition a gate can settle.
check_gitignore_register() {
    [ "${FW_GITIGNORE_REGISTER_ADVISORY:-1}" != "0" ] || return 0
    [ -f "$FRAMEWORK_ROOT/lib/gitignore-register.sh" ] || return 0
    # shellcheck source=/dev/null
    source "$FRAMEWORK_ROOT/lib/gitignore-register.sh"

    local _out _n _first
    if _out=$(fw_gitignore_unregistered_defers "$PROJECT_ROOT"); then
        return 0
    fi
    _n=$(echo "$_out" | grep -c .)
    _first=$(echo "$_out" | head -1 | cut -f2 | cut -c1-72)
    warn ".gitignore: $_n comment block(s) defer work without naming a register entry" \
         "First at line $(echo "$_out" | head -1 | cut -f1): $_first" \
         "File it (fw work-on / concerns.yaml) and name the id in the comment, or drop the promise. Origin T-2990: 'root-cause task pending' beside two rules, no task ever filed, 56MB over three months. Silence with FW_GITIGNORE_REGISTER_ADVISORY=0."
}
check_gitignore_register

echo ""
fi # end structure

# ============================================
# SECTION 1b: WHOLE-TREE SCANS
# ============================================
# T-1845: Audit-time secret-scan + large-file scan. These were both pre-commit
# only, which misses: --no-verify bypasses, files committed before the hook
# existed, hook installation drift on cron-run hosts. Audit-mode scan-tree
# closes the gap — same shape as the cron registry sync check above (the gate
# was wired but not measured at the audit horizon).
#
# T-3062: they belong to the DAILY horizon T-1845 named, and they were in
# `structure`, which is the horizon the pre-push hook runs on every push. That
# mismatch is why they are their own section now.
#
# Measured on this repo, `--section structure` before the split:
#
#   everything up to the hook-threshold check   51s
#   secret scan   (scan-tree)                  188s
#   large-file    (scan-tree)                   95s
#   the remaining nine checks                   13s
#   ------------------------------------------------
#   total                                      347s
#
# The pre-push hook bounds a push at 60s (handover.sh `_push_timeout`), so the
# gate could not finish inside the window it is given, on any path. Pushes were
# not blocked — they were killed partway through, which looks the same from the
# outside and reports nothing. Seven commits sat unpushed across four sessions.
# The same 283s was also being paid every 30 minutes by the `structural-30m`
# cron, which is where the audit lock contention in T-1719/OBS-221 came from.
#
# Scoping, so this stays honest: `should_run_section` is true for every section
# when no `--section` filter is given, so a full audit (`fw audit --cron`, the
# daily 08:00 job) still runs these. What changes is that a caller who asks for
# `structure` by name no longer gets them. Coverage moves from every-30-minutes
# to daily — which is the horizon T-1845 asked for in the first place. To run
# them on demand: `fw audit --section tree`.
if should_run_section "tree"; then
echo "=== WHOLE-TREE SCANS ==="

SECRET_SCANNER="$FRAMEWORK_ROOT/agents/git/lib/secret-scan.sh"
if [ -x "$SECRET_SCANNER" ]; then
    _ss_out=$(PROJECT_ROOT="$PROJECT_ROOT" "$SECRET_SCANNER" scan-tree 2>&1)
    _ss_rc=$?
    if [ "$_ss_rc" -ne 0 ]; then
        _ss_count=$(echo "$_ss_out" | grep -c "^  \[" || true)
        fail "Secret scan: $_ss_count finding(s) in tracked tree (T-1844)" \
             "$(echo "$_ss_out" | head -5)" \
             "Remove the secret from source + history (filter-repo if already committed); allowlist false-positives in .secret-scan-allowlist"
    else
        pass "Secret scan: tracked tree clean"
    fi
fi

LARGE_FILE_SCANNER="$FRAMEWORK_ROOT/agents/git/lib/large-file-scan.sh"
if [ -x "$LARGE_FILE_SCANNER" ]; then
    _lf_out=$(PROJECT_ROOT="$PROJECT_ROOT" "$LARGE_FILE_SCANNER" scan-tree 2>&1)
    _lf_rc=$?
    if [ "$_lf_rc" -ne 0 ]; then
        _lf_count=$(echo "$_lf_out" | grep -c "\[BLOCK\]" || true)
        warn "Large-file gate: $_lf_count tracked file(s) above block threshold (T-1845)" \
             "$(echo "$_lf_out" | head -5)" \
             "Untrack + add to .gitignore, or allowlist if deliberate: git rm --cached <path> && echo <path> >> .gitignore"
    else
        pass "Large-file gate: tracked tree clean"
    fi
fi

echo ""
fi # end tree

# ============================================
# SECTION 2: TASK COMPLIANCE CHECKS
# ============================================
if should_run_section "compliance"; then
echo "=== TASK COMPLIANCE CHECKS ==="

# Check each active task (T-955: uses single-pass scan)
task_count=0
valid_task_count=0

if [ -n "$ACTIVE_SCAN" ]; then
    task_count=$(echo "$ACTIVE_SCAN" | python3 -c "import sys,json; print(json.load(sys.stdin)['stats']['total'])" 2>/dev/null || echo "0")
    valid_task_count=$(echo "$ACTIVE_SCAN" | python3 -c "import sys,json; print(json.load(sys.stdin)['stats']['valid'])" 2>/dev/null || echo "0")

    # Emit warnings for compliance issues
    while IFS='|' read -r task_name issue; do
        [ -z "$task_name" ] && continue
        warn "Task $task_name $issue" \
             "Compliance check failed" \
             "Fix $issue in $task_name"
    done < <(echo "$ACTIVE_SCAN" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for item in data['compliance']['issues']:
    print(f\"{item['task']}|{item['issue']}\")
" 2>/dev/null)
fi

if [ "$task_count" -eq 0 ]; then
    warn "No active tasks found" \
         ".tasks/active/ is empty" \
         "Create tasks for ongoing work"
else
    if [ "$valid_task_count" -eq "$task_count" ]; then
        pass_over "$task_count" "active task(s)" "All active tasks are valid"
    else
        echo "       $valid_task_count of $task_count tasks fully valid"
    fi
fi

echo ""
fi # end compliance

# ============================================
# SECTION 2B: TASK QUALITY CHECKS (P-001, P-004)
# ============================================
if should_run_section "quality"; then
echo "=== TASK QUALITY CHECKS ==="

# Quality checks (T-955: uses single-pass scan)
quality_issues=0

if [ -n "$ACTIVE_SCAN" ]; then
    while IFS='|' read -r task_id issue task_file; do
        [ -z "$task_id" ] && continue
        warn "Task $task_id has $issue" \
             "Quality check failed" \
             "Fix in $task_file"
        quality_issues=$((quality_issues + 1))
    done < <(echo "$ACTIVE_SCAN" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for item in data['quality']['issues']:
    print(f\"{item['id']}|{item['issue']}|{item['file']}\")
" 2>/dev/null)
fi

if [ "$quality_issues" -eq 0 ]; then
    pass_over "$task_count" "active task(s)" "All active tasks meet quality thresholds" \
         "" "0 active tasks were scanned for quality — the thresholds asserted nothing this run"
fi

echo ""
fi # end quality

# ============================================
# SECTION 2C: UNCLOSED-BUT-SATISFIED TASKS (T-3061, OBS-316/OBS-317)
# ============================================
# Active tasks where every Agent AC is ticked and no Human AC is left
# unticked, but the task is still sitting in started-work/issues. T-3060
# swept the corpus by hand and found 17 of 43 in-flight tasks in this state —
# this section is the recurring rail. Proposes only: it changes no status,
# ticks no box (A2). A ticked checkbox is a claim the agent that wrote it
# made, not evidence a human or a gate has verified — see CLAUDE.md's Human
# Task Completion Rule, which is exactly why this is a WARN, not a FAIL (A5).
if should_run_section "quality"; then
if [ -n "$ACTIVE_SCAN" ]; then
    UNCLOSED_REPORT_DIR="$AUDITS_DIR/unclosed-satisfied"
    mkdir -p "$UNCLOSED_REPORT_DIR"
    UNCLOSED_REPORT_PATH="$UNCLOSED_REPORT_DIR/LATEST.md"

    _unclosed_summary=$(echo "$ACTIVE_SCAN" | python3 -c "
import json, sys

data = json.load(sys.stdin)
u = data.get('unclosed_satisfied', {})
tasks = u.get('tasks', [])
count = u.get('count', 0)
no_verif = u.get('no_verification_count', 0)

report_path = '$UNCLOSED_REPORT_PATH'
lines = []
lines.append('# Unclosed-but-satisfied active tasks')
lines.append('')
lines.append('_Generated by \`fw audit\` (T-3061). Read-only — no task is closed, no')
lines.append('status changed, no box ticked by this scan._')
lines.append('')
lines.append('## Criterion')
lines.append('')
lines.append('A task in \`.tasks/active/\` qualifies when: frontmatter \`status:\` is')
lines.append('\`started-work\` or \`issues\`; the Acceptance Criteria section has at least')
lines.append('one Agent AC; every Agent AC is ticked \`- [x]\`; zero Human AC checkboxes')
lines.append('are left unticked. Lines inside HTML comment blocks (including the task')
lines.append('template\'s own example ACs) are excluded, so an unedited template never')
lines.append('self-qualifies.')
lines.append('')
lines.append('## Limits — read before acting on this list')
lines.append('')
lines.append('**A ticked box is a claim, not evidence.** This scan reads checkbox')
lines.append('characters; it does not run the task\'s \`## Verification\` block, does not')
lines.append('re-derive whether the described work actually shipped, and cannot tell a')
lines.append('genuinely finished task from one where an agent ticked ahead of itself.')
lines.append('Each row below is a **candidate for close, never a closure** — verify with')
lines.append('\`fw task verify T-XXX\` or a per-task review before touching')
lines.append('\`fw task update --status work-completed\`. Never batch-close on this list')
lines.append('alone (CLAUDE.md Human Task Completion Rule).')
lines.append('')
lines.append(f'Rows with an empty \`## Verification\` block need that scrutiny most —')
lines.append('nothing mechanical would gate their close.')
lines.append('')
lines.append(f'## Qualifying tasks ({count})')
lines.append('')
if tasks:
    lines.append('| Task | Status | Workflow | Name | Agent ACs | Verification cmds? |')
    lines.append('|------|--------|----------|------|----------:|--------------------|')
    for t in tasks:
        name = (t.get('name') or '').replace('|', '\\\\|')
        if len(name) > 55:
            name = name[:52] + '...'
        verif = 'yes' if t.get('has_verification') else '**no**'
        lines.append(f\"| {t['id']} | {t['status']} | {t['workflow_type']} | {name} | {t['agent_ac_count']} | {verif} |\")
else:
    lines.append('None found — every started-work/issues task with satisfied ACs has')
    lines.append('already been closed or has an outstanding box.')
lines.append('')

with open(report_path, 'w') as f:
    f.write('\n'.join(lines) + '\n')

# T-3105: print unconditionally. This line used to fire only when count > 0,
# so an empty summary meant EITHER no-findings OR the-python-above-died (its
# stderr goes to /dev/null) — and the shell below scored both as PASS.
# Emitting the count on every run lets the shell tell the two apart.
capped_ids = [t['id'] for t in tasks[:10]]
overflow = count - len(capped_ids)
id_str = ', '.join(capped_ids)
if overflow > 0:
    id_str += f' (+{overflow} more)'
print(f'{count}|{no_verif}|{id_str}')
" 2>/dev/null)

    if [ -z "$_unclosed_summary" ]; then
        warn_unenumerable "the unclosed-satisfied scan over .tasks/active/" \
             "Satisfied-but-unclosed active tasks" \
             "the python3 pass over ACTIVE_SCAN produced no summary line (its stderr is discarded)" \
             "Re-run the block without 2>/dev/null to see the error; until then this rail asserts nothing"
    else
        IFS='|' read -r _u_count _u_no_verif _u_ids <<< "$_unclosed_summary"
        if [ "${_u_count:-0}" -gt 0 ]; then
            warn "$_u_count active task(s) have every Agent AC ticked and no Human AC outstanding, but are still started-work/issues" \
                 "$_u_ids — $_u_no_verif of these have an empty ## Verification block (no mechanical close gate)" \
                 "Candidates for close, not closures — spot-check with 'fw task verify T-XXX' per task, then 'fw task update T-XXX --status work-completed'. Full list: $UNCLOSED_REPORT_PATH"
        else
            pass_over "$(find "$PROJECT_ROOT/.tasks/active" -maxdepth 1 -name 'T-*.md' -type f 2>/dev/null | wc -l)" \
                 "active task(s)" "No active tasks are satisfied-but-unclosed" \
                 "" ".tasks/active/ holds no task files — the scan had nothing to qualify"
        fi
    fi
fi
echo ""
fi # end unclosed-satisfied

# ============================================
# SECTION 3: GIT TRACEABILITY CHECKS
# ============================================
if should_run_section "traceability"; then
echo "=== GIT TRACEABILITY CHECKS ==="

if git -C "$PROJECT_ROOT" rev-parse --git-dir > /dev/null 2>&1; then
    # T-590: Traceability baseline — only count commits after baseline on imported projects
    TRACE_BASELINE_FILE="$PROJECT_ROOT/.context/project/traceability-baseline"
    trace_range=""
    if [ -f "$TRACE_BASELINE_FILE" ]; then
        trace_base=$(tr -d '[:space:]' < "$TRACE_BASELINE_FILE")
        if git -C "$PROJECT_ROOT" rev-parse --verify "$trace_base" >/dev/null 2>&1; then
            trace_range="${trace_base}..HEAD"
            pass "Traceability baseline active (excluding pre-ingestion commits)"
        fi
    fi

    # shellcheck disable=SC2086 # trace_range intentionally unquoted — empty means no range arg
    total_commits=$(git -C "$PROJECT_ROOT" log --oneline $trace_range 2>/dev/null | wc -l | tr -d ' ')
    # shellcheck disable=SC2086
    task_commits=$(git -C "$PROJECT_ROOT" log --oneline $trace_range 2>/dev/null | grep -cE "T-[0-9]+" || true)

    if [ "$total_commits" -gt 0 ]; then
        pct=$((task_commits * 100 / total_commits))

        if [ "$pct" -ge 80 ]; then
            pass "Git traceability: $pct% ($task_commits/$total_commits commits reference tasks)"
        elif [ "$pct" -ge 50 ]; then
            warn "Git traceability below target: $pct%" \
                 "$task_commits of $total_commits commits reference tasks" \
                 "Reference tasks in commit messages: git commit -m 'T-XXX: description'"
        else
            fail "Git traceability low: $pct%" \
                 "Only $task_commits of $total_commits commits reference tasks" \
                 "Enforce task references in commits"
        fi
    fi

    # Check for uncommitted changes (T-1392: filter session-state noise)
    # Session-state files (watchtower logs/pid, audits, monitors, focus, metrics
    # history, ephemeral approvals, counters) churn under normal operation and
    # would otherwise drown out signal from real source/code changes.
    _SESSION_STATE_FILTER='^\.context/(working/(watchtower\.|session\.yaml|focus\.yaml|\.session-metrics\.yaml|\.tool-counter|\.edit-counter|\.budget-status|\.gate-bypass-log\.yaml|\.approval-notified|\.restart-requested|\.dispatch-approval)|audits/|monitors/|approvals/(pending|resolved)-|project/metrics-history\.yaml|locks/)'
    _ALL_DIRTY=$(git -C "$PROJECT_ROOT" status --porcelain | awk '{print $2}')
    if [ -n "$_ALL_DIRTY" ]; then
        _REAL_DIRTY=$(printf '%s\n' "$_ALL_DIRTY" | grep -Ev "$_SESSION_STATE_FILTER" || true)
        _NOISE_COUNT=$(printf '%s\n' "$_ALL_DIRTY" | grep -Ec "$_SESSION_STATE_FILTER" || true)
        if [ -n "$_REAL_DIRTY" ]; then
            _REAL_COUNT=$(printf '%s\n' "$_REAL_DIRTY" | wc -l | tr -d ' ')
            warn "Uncommitted changes present" \
                 "$_REAL_COUNT real file(s) modified ($_NOISE_COUNT session-state file(s) ignored)" \
                 "Commit changes with task reference or stash"
        else
            pass "Working directory clean ($_NOISE_COUNT session-state file(s) churning, ignored)"
        fi
    else
        pass "Working directory clean"
    fi
    unset _SESSION_STATE_FILTER _ALL_DIRTY _REAL_DIRTY _NOISE_COUNT _REAL_COUNT

    # Quality Check: Verify task refs in commits exist as actual tasks
    #
    # T-3053: a commit subject may name more than one task ("T-A/T-B-side: ...",
    # "T-A: ...; T-B recommendation"). The question this check asks is whether the
    # commit is traceable to a real task, so ANY resolving ref answers it. Reading
    # only the first (`grep -oE "T-[0-9]+" | head -1`) reported a false orphan
    # whenever the leading ref did not resolve but a later one did.
    #
    # The traceability percentage at :2432 already counts a commit as referencing a
    # task when *any* T-ref is present — this loop was the only place that silently
    # narrowed that to the first, so the two measures disagreed about the same
    # commit. Any-resolves is the reading that makes them agree.
    orphan_refs=0
    # shellcheck disable=SC2086 # trace_range intentionally unquoted
    while IFS= read -r commit_line; do
        # Every ref in the subject, de-duplicated, order preserved.
        _refs=$(echo "$commit_line" | grep -oE "T-[0-9]+" | awk '!seen[$0]++')
        [ -n "$_refs" ] || continue

        _any_resolved=0
        _unresolved=""
        while IFS= read -r _ref; do
            [ -n "$_ref" ] || continue
            if [ -n "$(find "$TASKS_DIR" -name "${_ref}-*.md" -type f 2>/dev/null | head -1)" ]; then
                _any_resolved=1
            else
                _unresolved="${_unresolved}${_ref} "
            fi
        done <<< "$_refs"

        # At least one named task exists → the commit is traceable, which is what
        # this check measures. Unresolved siblings are deliberately not reported:
        # warning about them would re-introduce the noise class in the other
        # direction (a real task plus a stale mention is not an orphan commit).
        [ "$_any_resolved" -eq 1 ] && continue

        # Nothing resolved. Both pre-existing escapes still apply below.
        #
        # T-2058: suppress WARN when a later commit explicitly reverted this task
        # (deliberate orphan). Pattern: any commit message containing "revert ... T-NNNN".
        # Capture-then-grep avoids SIGPIPE on truncation (L-387 safe pattern).
        # T-3053: suppress only when EVERY unresolved ref has a revert chain — one
        # reverted task must not hide a genuinely orphaned sibling. For a single-ref
        # commit this is bit-identical to the pre-T-3053 test.
        _revert_log=$(git -C "$PROJECT_ROOT" log --all --format=%s 2>/dev/null)
        _all_reverted=1
        for _ref in $_unresolved; do
            if ! echo "$_revert_log" | grep -qiE "revert[^A-Za-z0-9_].*${_ref}([^0-9]|$)"; then
                _all_reverted=0
                break
            fi
        done
        unset _revert_log
        [ "$_all_reverted" -eq 1 ] && continue

        commit_sha=$(echo "$commit_line" | cut -d' ' -f1)
        # T-2851: a root commit predates every task by construction, so it
        # cannot reference one. `fw init`'s bootstrap commit (lib/init.sh:742)
        # is exactly this case and made every fresh project fail its own
        # traceability audit on day zero. Keyed on parentlessness, not on the
        # `T-000` sentinel — see lib/traceability.sh for why that distinction
        # is what stops this being a general P-002 escape hatch.
        if trace_is_root_commit "$PROJECT_ROOT" "$commit_sha"; then
            continue
        fi
        if [ "$orphan_refs" -eq 0 ]; then
            echo ""
        fi
        _ref_list=$(echo "$_unresolved" | sed 's/ *$//; s/ /, /g')
        warn "Commit $commit_sha references non-existent task $_ref_list" \
             "Task file(s) for $_ref_list not found in .tasks/" \
             "Create task or fix commit reference"
        orphan_refs=$((orphan_refs + 1))
    done < <(git -C "$PROJECT_ROOT" log --oneline $trace_range 2>/dev/null)
    unset _refs _ref _any_resolved _unresolved _all_reverted _ref_list

    if [ "$orphan_refs" -eq 0 ]; then
        pass_over "$task_commits" "task-referencing commit(s) in ${trace_range:-full history}" \
             "All commit task refs resolve to actual tasks" \
             "" "No commit in the traceability range carried a T-XXX reference, so nothing was resolved — check the range and the reference convention"
    fi

    # T-1255 (G-007): mirror drift check — github vs origin HEAD divergence.
    # Only runs when both 'origin' and 'github' remotes are configured.
    if git -C "$PROJECT_ROOT" remote get-url github >/dev/null 2>&1 \
       && git -C "$PROJECT_ROOT" remote get-url origin >/dev/null 2>&1; then
        _origin_head=$(timeout 10 git -C "$PROJECT_ROOT" ls-remote origin main 2>/dev/null | awk '"'"'{print $1}'"'"')
        _github_head=$(timeout 10 git -C "$PROJECT_ROOT" ls-remote github main 2>/dev/null | awk '"'"'{print $1}'"'"')
        if [ -n "$_origin_head" ] && [ -n "$_github_head" ]; then
            if [ "$_origin_head" = "$_github_head" ]; then
                pass "OneDev → GitHub mirror in sync (origin=github=${_origin_head:0:8})"
            else
                warn "OneDev → GitHub mirror drift (G-007): origin=${_origin_head:0:8} github=${_github_head:0:8}" \
                     "Direct push to github (or onedev down at handover time) likely caused divergence" \
                     "Investigate handover.sh push loop; ensure only origin is pushed (T-1255)"
            fi
        fi
    fi
else
    warn "Not a git repository" \
         "Git not initialized" \
         "Run: git init"
fi

echo ""
fi # end traceability

# ============================================
# SECTION: CORPUS HEALTH (T-3013, T-3005 slice 4)
# ============================================
#
# The one check in this file that actually retrieves something. Every other
# signal over the vector index counts rows or reads timestamps, which is why
# T-3004 ran five months green: nothing anywhere exercised embed → chunk →
# store → retrieve end to end.
#
# Its own section, deliberately NOT part of `structure`. `structure` is what
# pre-push runs, and pre-push already exceeds 180s and blocks every push
# (OBS-253); two embed round-trips would make a bad situation worse and would
# couple every push to Ollama being up. This runs on the 6-hourly cron instead.
if should_run_section "corpus-health"; then
echo "=== CORPUS HEALTH ==="

_ch_json=$(cd "$PROJECT_ROOT" && timeout 90 python3 -c '
import json, sys
try:
    from web.embeddings import corpus_health
except Exception as exc:
    print(json.dumps({"status": "unimportable", "detail": type(exc).__name__}))
    sys.exit(0)
try:
    h = corpus_health()
    print(json.dumps({"status": h.get("status"), "detail": h.get("detail", "")}))
except Exception as exc:
    print(json.dumps({"status": "error", "detail": str(exc)[:200]}))
' 2>/dev/null || echo '{"status":"timeout","detail":"corpus_health did not return within 90s"}')

_ch_status=$(echo "$_ch_json" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("status",""))' 2>/dev/null || echo "")
_ch_detail=$(echo "$_ch_json" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("detail",""))' 2>/dev/null || echo "")

case "$_ch_status" in
    ok)
        pass "Corpus canaries: retrieval verified end to end"
        ;;
    fault)
        # A planted document did not come back for its own paraphrase. Either
        # the index is stale, embedding is dead, or chunks are being truncated —
        # the canary cannot tell you which, only that retrieval is broken.
        fail "Corpus canaries: FAULT — $_ch_detail" \
             "A canary document is not the top hit for its own probe" \
             "Rebuild the index (fw serve, then /search), then re-run: fw audit --section corpus-health"
        ;;
    unknown)
        warn "Corpus canaries: index has no manifest — cannot verify" \
             "$_ch_detail" \
             "Index predates T-3011. Rebuild to plant canaries and write a manifest."
        ;;
    unimportable)
        info "Corpus canaries: web.embeddings not importable here — skipped"
        ;;
    timeout|error|"")
        warn "Corpus canaries: check did not complete" \
             "${_ch_detail:-no output from corpus_health}" \
             "Check the embedder: fw doctor, and Config.EMBED_HOST"
        ;;
esac

fi

# ============================================
# SECTION 4: ENFORCEMENT CHECKS
# ============================================
if should_run_section "enforcement"; then
echo "=== ENFORCEMENT CHECKS ==="

# Check for bypass log
if [ -f "$CONTEXT_DIR/bypass-log.yaml" ]; then
    pass "Bypass log exists"
else
    # Only warn if there are commits without task refs (potential bypasses)
    if [ "$total_commits" -gt "$task_commits" ] 2>/dev/null; then
        warn "No bypass log found" \
             "Commits exist without task refs but no bypass log" \
             "Create .context/bypass-log.yaml to document exceptions"
    fi
fi

# T-1573 / F8: Surface .gate-bypass-log.yaml — auth-flag bypasses
# (--skip-sovereignty, --skip-acceptance-criteria, --skip-rca, etc.) are
# logged by update-task.sh:32-42 but nothing read the file before now.
#
# T-1862: split entries into SAFETY bypasses (--skip-* / --scope-reduction-acknowledged)
# vs OPERATIONAL overrides (--switch-focus). The former are correctness-gate skips
# and warrant a low threshold; the latter are routine cross-task work signals
# from T-1730 and should not contribute to the WARN count. Before this split,
# 51 normal --switch-focus events drowned out 3 genuine safety bypasses.
GATE_BYPASS_LOG="$PROJECT_ROOT/.context/working/.gate-bypass-log.yaml"
if [ -f "$GATE_BYPASS_LOG" ]; then
    gb_total=$(grep -c "^- timestamp:" "$GATE_BYPASS_LOG" 2>/dev/null || echo 0)
    cutoff=$(date -u -d "7 days ago" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || \
             date -u -v-7d +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || echo "1970-01-01T00:00:00Z")
    # T-1862: per-class counts. Awk walks entries, classifies by flag.
    read -r gb_safety gb_drift < <(awk -v cutoff="$cutoff" '
        BEGIN { in_window=0; current_flag="" }
        /^- timestamp:/ {
            # New entry: emit prior classification (if any), reset.
            if (in_window && current_flag != "") {
                if (current_flag == "--switch-focus") drift++; else safety++
            }
            ts=$0; gsub(/.*timestamp: ['"'"'"]?/, "", ts); gsub(/['"'"'"]?$/, "", ts);
            in_window = (ts >= cutoff)
            current_flag = ""
        }
        /^  flag:/ {
            f=$0; gsub(/.*flag: ['"'"'"]?/, "", f); gsub(/['"'"'"]?$/, "", f);
            current_flag = f
        }
        END {
            # Tail entry.
            if (in_window && current_flag != "") {
                if (current_flag == "--switch-focus") drift++; else safety++
            }
            print safety+0, drift+0
        }
    ' "$GATE_BYPASS_LOG" 2>/dev/null)
    gb_safety="${gb_safety:-0}"
    gb_drift="${gb_drift:-0}"
    gb_recent=$((gb_safety + gb_drift))
    if [ "$gb_safety" -gt 3 ]; then
        warn "Gate-bypass log: $gb_safety safety bypasses in last 7 days (+ $gb_drift drift overrides)" \
             "$gb_total total entries; safety-bypass-as-pattern signal" \
             "Review .context/working/.gate-bypass-log.yaml — investigate --skip-* / --scope-reduction-acknowledged callers"
    else
        pass "Gate-bypass log: $gb_safety safety + $gb_drift drift in last 7 days ($gb_total total)"
    fi
else
    pass "Gate-bypass log: clean (no bypasses recorded)"
fi

# Check for commit-msg hook (validates task references)
if [ -f "$PROJECT_ROOT/.git/hooks/commit-msg" ]; then
    pass "Commit-msg hook installed"
else
    warn "No commit-msg hook" \
         ".git/hooks/commit-msg not found" \
         "Install hooks: ./agents/git/git.sh install-hooks"
fi

# Tier 0 Checking: Consequential actions must ALWAYS have task refs
# Patterns from 011-EnforcementConfig.md
TIER0_PATTERNS="deploy-to-production|delete-|destroy-|modify-firewall|modify-secrets|database-migrate"

tier0_violations=0

# Check git history for Tier 0 patterns without task refs
if git -C "$PROJECT_ROOT" rev-parse --git-dir > /dev/null 2>&1; then
    while IFS= read -r commit_line; do
        commit_sha=$(echo "$commit_line" | cut -d' ' -f1)
        commit_msg=$(echo "$commit_line" | cut -d' ' -f2-)

        # Check if commit message contains Tier 0 patterns
        if echo "$commit_msg" | grep -qiE "$TIER0_PATTERNS"; then
            # Check if commit has task reference
            if ! echo "$commit_msg" | grep -qE "T-[0-9]+"; then
                fail "Tier 0 action without task ref: $commit_sha" \
                     "Commit '$commit_msg' contains consequential action pattern" \
                     "Tier 0 actions MUST have task refs - document in bypass-log with explanation"
                tier0_violations=$((tier0_violations + 1))
            fi
        fi
    done < <(git -C "$PROJECT_ROOT" log --oneline 2>/dev/null)
fi

# Check bypass log for any Tier 0 patterns (these should never be bypassed)
if [ -f "$CONTEXT_DIR/bypass-log.yaml" ]; then
    while IFS= read -r bypass_action; do
        if echo "$bypass_action" | grep -qiE "$TIER0_PATTERNS"; then
            action_text=$(echo "$bypass_action" | sed 's/.*action: "//' | sed 's/".*//')
            fail "Tier 0 action in bypass log" \
                 "Bypass log contains: $action_text" \
                 "Tier 0 actions should NEVER be bypassed - review and remediate"
            tier0_violations=$((tier0_violations + 1))
        fi
    done < <(grep "action:" "$CONTEXT_DIR/bypass-log.yaml" 2>/dev/null)
fi

if [ "$tier0_violations" -eq 0 ]; then
    pass "No Tier 0 violations detected"
fi

echo ""
fi # end enforcement

# ============================================
# SECTION 5: LEARNING CAPTURE CHECKS
# ============================================
if should_run_section "learning"; then
echo "=== LEARNING CAPTURE CHECKS ==="

# Check practices file (supports both 015-Practices.md and practices.yaml)
PRACTICES_MD="$PROJECT_ROOT/015-Practices.md"
PRACTICES_YAML="$PROJECT_ROOT/.context/project/practices.yaml"

if [ -f "$PRACTICES_MD" ]; then
    practice_count=$(grep -c "^## P-[0-9]" "$PRACTICES_MD" 2>/dev/null || true)
    if [ "$practice_count" -gt 0 ]; then
        pass "Practices documented: $practice_count practice(s) in 015-Practices.md"

        # Check if practices have origins
        practices_with_origin=$(grep -c "Origin:" "$PRACTICES_MD" 2>/dev/null || true)
        if [ "$practices_with_origin" -ge "$practice_count" ]; then
            pass_over "$practice_count" "documented practice(s)" "All practices have traceable origins"

            # Quality Check: Verify practice origins reference existing tasks
            # T-3053 (A3): the same `head -1` shape lived here, but it is the
            # opposite question and so needs the opposite fix. A commit subject
            # naming two tasks is traceable if EITHER resolves; an
            # `Origin: T-A, T-B` line asserts that BOTH are where the practice came
            # from, so every ref must resolve and each failure is its own broken
            # citation. Reading only the first was therefore a false GREEN here —
            # a stale second origin passed silently — where at the commit site it
            # was a false FAIL. No multi-ref Origin line exists in 015-Practices.md
            # today (7 Origin lines, all single-ref), so this closes a latent hole
            # rather than an observed one; the regression test supplies the case
            # the corpus does not.
            orphan_origins=0
            while IFS= read -r origin_line; do
                practice_id=$(echo "$origin_line" | grep -oE "P-[0-9]+" | head -1)
                while IFS= read -r task_ref; do
                    [ -n "$task_ref" ] || continue
                    task_file=$(find "$TASKS_DIR" -name "${task_ref}-*.md" -type f 2>/dev/null | head -1)
                    if [ -z "$task_file" ]; then
                        warn "Practice ${practice_id:-unknown} references non-existent task $task_ref" \
                             "Origin task $task_ref not found in .tasks/" \
                             "Fix origin reference in 015-Practices.md"
                        orphan_origins=$((orphan_origins + 1))
                    fi
                done < <(echo "$origin_line" | grep -oE "T-[0-9]+" | awk '!seen[$0]++')
            done < <(grep "Origin:" "$PRACTICES_MD" 2>/dev/null)

            if [ "$orphan_origins" -eq 0 ]; then
                pass_over "$practices_with_origin" "practice Origin: line(s)" \
                     "All practice origins resolve to actual tasks" \
                     "" "No Origin: line was found to resolve, so this check asserted nothing about 015-Practices.md"
            fi
        else
            warn "Some practices missing origin" \
                 "$practices_with_origin of $practice_count have Origin: field" \
                 "Add 'Origin: T-XXX' to each practice"
        fi
    else
        warn "No practices captured yet" \
             "015-Practices.md exists but no P-XXX entries" \
             "Extract learnings from completed tasks into practices"
    fi
elif [ -f "$PRACTICES_YAML" ]; then
    practice_count=$(python3 -c "
import yaml
with open('$PRACTICES_YAML') as f:
    data = yaml.safe_load(f) or {}
print(len(data.get('practices', [])))
" 2>/dev/null || true)
    if [ "$practice_count" -gt 0 ]; then
        pass "Practices documented: $practice_count practice(s) in practices.yaml"
    else
        pass "Practices file exists (practices.yaml, no entries yet)"
    fi
else
    warn "Practices file missing" \
         "No 015-Practices.md or .context/project/practices.yaml found" \
         "Run: fw init --force (or create practices file manually)"
fi

# Bugfix-learning coverage (G-016 detective control, T-1192 escalation)
LEARNINGS_FILE="$CONTEXT_DIR/project/learnings.yaml"
bugfix_total=0
bugfix_with_learning=0

if [ -d "$TASKS_DIR/completed" ]; then
    # Find completed tasks matching bugfix patterns (T-1192: broadened from anchored match)
    while IFS= read -r task_file; do
        [ -z "$task_file" ] && continue
        task_name=$({ grep "^name:" "$task_file" 2>/dev/null || true; } | head -1 | sed 's/^name:[[:space:]]*"*//;s/"*$//')
        # Match: Fix/Bugfix/Hotfix anywhere, or RCA, or G-0XX gap reference
        echo "$task_name" | grep -qiE '\bfix\b|\bbugfix\b|\bhotfix\b|\bRCA\b|\bG-[0-9]' || continue
        task_id=$({ grep "^id:" "$task_file" 2>/dev/null || true; } | head -1 | sed 's/^id:[[:space:]]*//')
        [ -z "$task_id" ] && continue
        bugfix_total=$((bugfix_total + 1))
        # Check if any learning references this task
        if [ -f "$LEARNINGS_FILE" ] && grep -q "$task_id" "$LEARNINGS_FILE" 2>/dev/null; then
            bugfix_with_learning=$((bugfix_with_learning + 1))
        fi
    done < <(find "$TASKS_DIR/completed" -name "T-*.md" -type f 2>/dev/null)
fi

if [ "$bugfix_total" -gt 0 ]; then
    coverage=$((bugfix_with_learning * 100 / bugfix_total))
    if [ "$coverage" -ge 35 ]; then
        pass "Bugfix-learning coverage: ${coverage}% ($bugfix_with_learning/$bugfix_total bugfixes have learnings)"
    elif [ "$coverage" -ge 10 ]; then
        warn "Bugfix-learning coverage: ${coverage}% ($bugfix_with_learning/$bugfix_total)" \
             "Only ${coverage}% of bugfixes have associated learnings (target: 35%)" \
             "Use: fw fix-learned T-XXX 'what was learned from this fix'"
    else
        # T-1192: Escalate to FAIL below 10% (G-016 structural enforcement)
        fail "Bugfix-learning coverage: ${coverage}% ($bugfix_with_learning/$bugfix_total)" \
             "Critical: below 10% threshold (target: 35%). Bugfix knowledge is being lost." \
             "After each fix: fw fix-learned T-XXX 'root cause and prevention'"
    fi
else
    pass "Bugfix-learning coverage: no completed bugfix tasks found"
fi

echo ""
fi # end learning

# ============================================
# SECTION 6: EPISODIC MEMORY CHECKS
# ============================================
if should_run_section "episodic"; then
echo "=== EPISODIC MEMORY CHECKS ==="

episodic_dir="$CONTEXT_DIR/episodic"

# Check 1: Every completed task should have an episodic summary (T-955: uses single-pass scan)
missing_episodic=0
if [ -n "$COMPLETED_SCAN" ]; then
    while IFS= read -r task_id; do
        [ -z "$task_id" ] && continue
        warn "Completed task $task_id has no episodic summary" \
             "$episodic_dir/${task_id}.yaml not found" \
             "Run: ./agents/context/context.sh generate-episodic $task_id"
        missing_episodic=$((missing_episodic + 1))
    done < <(echo "$COMPLETED_SCAN" | python3 -c "import sys,json; [print(x) for x in json.load(sys.stdin).get('missing_episodic',[])]" 2>/dev/null)
fi

if [ "$missing_episodic" -eq 0 ]; then
    _ep_pop=$(echo "$COMPLETED_SCAN" | python3 -c "import sys,json; print(json.load(sys.stdin).get('stats',{}).get('total',0))" 2>/dev/null || echo "")
    pass_over "$_ep_pop" "completed task(s)" "All completed tasks have episodic summaries" \
         "" "completed-task-scan reported no completed tasks — the coverage claim covers nothing"
    unset _ep_pop
fi

# Check 2: Episodic quality (non-empty required fields, enrichment status)
low_quality_episodic=0
pending_enrichment=0

if [ -d "$episodic_dir" ]; then
    shopt -s nullglob
    for episodic_file in "$episodic_dir"/*.yaml; do
        [ -f "$episodic_file" ] || continue
        filename=$(basename "$episodic_file")
        # Skip template
        [ "$filename" = "TEMPLATE.yaml" ] && continue

        task_id=$(basename "$episodic_file" .yaml)

        # Check enrichment status
        enrichment_status=$(grep "^enrichment_status:" "$episodic_file" 2>/dev/null | sed 's/enrichment_status: //' | tr -d ' ')
        if [ "$enrichment_status" = "pending" ]; then
            pending_enrichment=$((pending_enrichment + 1))
        fi

        # Check summary is not empty/TODO placeholder
        # Only flag if the first content line starts with [TODO (actual unfilled placeholder)
        summary_first_line=$(sed -n '/^summary:/,/^[a-z_]*:/p' "$episodic_file" 2>/dev/null | grep -v "^summary:" | grep -v "^\s*#" | grep -v "^\s*$" | head -1 | sed 's/^[[:space:]]*//')
        if [ -z "$summary_first_line" ] || echo "$summary_first_line" | grep -q "^\[TODO"; then
            low_quality_episodic=$((low_quality_episodic + 1))
        fi
    done
    shopt -u nullglob
fi

if [ "$pending_enrichment" -gt 0 ]; then
    warn "$pending_enrichment episodic summaries pending enrichment" \
         "Files with enrichment_status: pending" \
         "Enrich episodics with actual content, then set enrichment_status: complete"
fi

if [ "$low_quality_episodic" -gt 0 ] && [ "$pending_enrichment" -eq 0 ]; then
    warn "$low_quality_episodic episodics have empty or TODO summaries" \
         "Summary field is empty or contains [TODO]" \
         "Fill in summary field with actual task description"
fi

if [ "$pending_enrichment" -eq 0 ] && [ "$low_quality_episodic" -eq 0 ]; then
    episodic_count=$(find "$episodic_dir" -name "T-*.yaml" -type f 2>/dev/null | wc -l)
    pass_over "$episodic_count" "episodic summary file(s)" "All episodic summaries have quality content" \
         "" "$episodic_dir holds no T-*.yaml — the quality claim covers nothing"
fi

# Check 3: Orphaned episodic files (no matching task)
orphaned_episodic=0
if [ -d "$episodic_dir" ]; then
    shopt -s nullglob
    for episodic_file in "$episodic_dir"/T-*.yaml; do
        [ -f "$episodic_file" ] || continue
        task_id=$(basename "$episodic_file" .yaml)
        task_file=$(find "$TASKS_DIR" -name "${task_id}-*.md" -type f 2>/dev/null | head -1)
        if [ -z "$task_file" ]; then
            warn "Orphaned episodic: $task_id has no matching task file" \
                 "$episodic_file has no corresponding task" \
                 "Remove orphaned episodic or create matching task"
            orphaned_episodic=$((orphaned_episodic + 1))
        fi
    done
    shopt -u nullglob
fi

if [ -d "$episodic_dir" ] && [ "$orphaned_episodic" -eq 0 ]; then
    pass_over "$(find "$episodic_dir" -maxdepth 1 -name "T-*.yaml" -type f 2>/dev/null | wc -l)" \
         "episodic file(s)" "No orphaned episodic files" \
         "" "$episodic_dir exists but holds no T-*.yaml — nothing could be orphaned because nothing is there"
fi

echo ""
fi # end episodic

# ============================================
# SECTION 7: OBSERVATION INBOX CHECKS
# ============================================
if should_run_section "observations"; then
echo "=== OBSERVATION INBOX CHECKS ==="

INBOX_FILE="$CONTEXT_DIR/inbox.yaml"

if [ -f "$INBOX_FILE" ]; then
    # T-2932: parse, do not grep — see handover.sh for the full note. The urgent
    # count below was converted to a YAML parse by T-2514; this line beside it was
    # left on the grep, which is the half-swept shape L-533 describes. It counted
    # the string anywhere in the file, so an observation quoting `status: pending`
    # inflated the total (OBS-233 did exactly that within an hour of being filed).
    pending_obs=$(python3 -c "
import yaml
try:
    d = yaml.safe_load(open('$INBOX_FILE')) or {}
    obs = d.get('observations', []) if isinstance(d, dict) else []
except Exception:
    obs = []
print(sum(1 for o in obs if isinstance(o, dict) and o.get('status') == 'pending'))
" 2>/dev/null) || pending_obs=0
    urgent_obs=0
    stale_obs=0

    if [ "$pending_obs" -gt 0 ]; then
        # Check for urgent pending observations
        # Count blocks that have both status: pending and urgent: true
        # T-2514: parse YAML properly. The prior regex block-split
        # `re.split(r'\n  - ', content)` did NOT match the real inbox format
        # (observations are `- id:` at column 0, not `  - `), producing one
        # mega-block whose first `captured:` (oldest obs) got mis-associated
        # with a `status: pending` bleeding in from a recent obs → phantom
        # "stale"/"urgent" counts. YAML parse is per-observation and exact.
        urgent_obs=$(python3 -c "
import yaml
try:
    d = yaml.safe_load(open('$INBOX_FILE')) or {}
    obs = d.get('observations', []) if isinstance(d, dict) else []
except Exception:
    obs = []
print(sum(1 for o in obs if isinstance(o, dict) and o.get('status') == 'pending' and o.get('urgent') is True))
" 2>/dev/null || true)

        # Check for stale observations (>7 days old)
        stale_obs=$(python3 -c "
import yaml
from datetime import datetime, timedelta, timezone
try:
    d = yaml.safe_load(open('$INBOX_FILE')) or {}
    obs = d.get('observations', []) if isinstance(d, dict) else []
except Exception:
    obs = []
cutoff = datetime.now(timezone.utc) - timedelta(days=7)
stale = 0
for o in obs:
    if not isinstance(o, dict) or o.get('status') != 'pending':
        continue
    c = o.get('captured')
    if c is None:
        continue
    try:
        ts = c if isinstance(c, datetime) else datetime.fromisoformat(str(c).replace('Z', '+00:00'))
        if ts.tzinfo is None:
            ts = ts.replace(tzinfo=timezone.utc)
        if ts < cutoff:
            stale += 1
    except Exception:
        pass
print(stale)
" 2>/dev/null || true)

        if [ "$urgent_obs" -gt 0 ]; then
            warn "$urgent_obs urgent observation(s) still pending" \
                 "Urgent items in .context/inbox.yaml need attention" \
                 "Run: fw note triage"
        fi

        if [ "$stale_obs" -gt 0 ]; then
            warn "$stale_obs observation(s) pending for >7 days" \
                 "Stale observations in .context/inbox.yaml" \
                 "Run: fw note triage — promote or dismiss stale items"
        fi

        if [ "$urgent_obs" -eq 0 ] && [ "$stale_obs" -eq 0 ]; then
            pass "Observation inbox: $pending_obs pending (none stale or urgent)"
        fi
    else
        pass "Observation inbox clean (0 pending)"
    fi
else
    pass "No observation inbox (not yet initialized)"
fi

echo ""
fi # end observations

# ============================================
# SECTION 8: CONCERNS REGISTER CHECKS (T-397: was gaps register)
# ============================================
if should_run_section "gaps"; then
echo "=== CONCERNS REGISTER CHECKS ==="

# T-397: Unified concerns register (was gaps.yaml)
GAPS_FILE="$CONTEXT_DIR/project/concerns.yaml"
[ -f "$GAPS_FILE" ] || GAPS_FILE="$CONTEXT_DIR/project/gaps.yaml"

# T-422: Warn if stale pre-migration files exist
if [ -f "$CONTEXT_DIR/project/gaps.yaml" ] && [ -f "$CONTEXT_DIR/project/concerns.yaml" ]; then
    warn "Stale gaps.yaml exists alongside concerns.yaml — remove gaps.yaml (T-397 migration)"
fi
if [ -f "$CONTEXT_DIR/project/risks.yaml" ]; then
    warn "Stale risks.yaml exists — risks are in concerns.yaml (T-397 migration)"
fi

if [ -f "$GAPS_FILE" ]; then
    watching_count=$(grep -c 'status: watching' "$GAPS_FILE" 2>/dev/null) || watching_count=0
    triggered_gaps=0

    if [ "$watching_count" -gt 0 ]; then
        # Run auto-checkable triggers
        triggered_gaps=$(python3 << PYEOF
import yaml, subprocess, os

project_root = os.environ.get('PROJECT_ROOT', '$PROJECT_ROOT')

with open('$GAPS_FILE') as f:
    data = yaml.safe_load(f)

triggered = 0
# T-397: concerns.yaml uses 'concerns' key, fallback to 'gaps'
items = data.get('concerns', data.get('gaps', []))
for gap in items:
    if gap.get('status') != 'watching':
        continue
    tc = gap.get('trigger_check', {})
    if tc.get('type') != 'auto':
        continue

    check_cmd = tc.get('check', '')
    threshold = tc.get('threshold', '')
    if not check_cmd:
        continue

    # Substitute variables
    check_cmd = check_cmd.replace('$' + 'PROJECT_ROOT', project_root)

    try:
        result = subprocess.run(check_cmd, shell=True, capture_output=True, text=True, timeout=5)
        value = int(result.stdout.strip())

        # Parse threshold
        if threshold.startswith('>= '):
            target = int(threshold.split('>= ')[1].split()[0])
            if value >= target:
                print(f"  TRIGGERED: {gap['id']} — {gap['title']}")
                print(f"    Value: {value}, Threshold: {threshold}")
                print(f"    Action: Review gap and decide — build or simplify")
                triggered += 1
        elif threshold.startswith('> '):
            target = int(threshold.split('> ')[1].split()[0])
            if value > target:
                print(f"  TRIGGERED: {gap['id']} — {gap['title']}")
                print(f"    Value: {value}, Threshold: {threshold}")
                print(f"    Action: Review gap and decide — build or simplify")
                triggered += 1
    except:
        pass

print(triggered)
PYEOF
)
        # Extract just the count (last line)
        trigger_count=$(echo "$triggered_gaps" | tail -1)
        trigger_output=$(echo "$triggered_gaps" | head -n -1)

        if [ -n "$trigger_output" ]; then
            echo "$trigger_output"
            warn "Gap trigger(s) fired — review gaps register" \
                 "Auto-check found trigger conditions met" \
                 "Review .context/project/concerns.yaml and decide: build or simplify"
        fi

        if [ "${trigger_count:-0}" -eq 0 ]; then
            pass "Gaps register: $watching_count watching, no triggers fired"
        fi
    else
        pass "Gaps register: no gaps being watched"
    fi
else
    echo -e "  ${CYAN}SKIP${NC}  No concerns register (.context/project/concerns.yaml)"
fi

echo ""
fi # end gaps

# ============================================
# SECTION 8b: HANDOVER OPEN QUESTIONS (G-002)
# ============================================
if should_run_section "handover"; then
echo "=== HANDOVER OPEN QUESTIONS CHECK ==="

HANDOVER_FILE="$CONTEXT_DIR/handovers/LATEST.md"

if [ -f "$HANDOVER_FILE" ]; then
    # Extract open questions section (between ## Open Questions and next ##)
    open_questions=$(sed -n '/^## Open Questions/,/^## /p' "$HANDOVER_FILE" | grep -v "^## " | grep -v "^\[TODO" | grep -v "^$" | grep -v "^1\. \[Question")

    if [ -n "$open_questions" ]; then
        # Count real items (numbered lines or bullet points with content)
        oq_count=$(echo "$open_questions" | grep -cE "^[0-9]+\.|^- " 2>/dev/null) || oq_count=0

        if [ "$oq_count" -gt 0 ]; then
            # Check how many are tracked in gaps.yaml or tasks
            untracked=0
            while IFS= read -r line; do
                # Extract the question text (strip numbering/bullets)
                question=$(echo "$line" | sed 's/^[0-9]*\.\s*//; s/^- //')
                [ -z "$question" ] && continue

                # Check if any keyword from the question appears in gaps or active tasks
                tracked=false
                for keyword in $(echo "$question" | tr ' ' '\n' | grep -E '^[A-Z]' | head -3); do
                    if grep -qi "$keyword" "$CONTEXT_DIR/project/gaps.yaml" 2>/dev/null; then
                        tracked=true
                        break
                    fi
                    if grep -rqi "$keyword" "$TASKS_DIR/active/" 2>/dev/null; then
                        tracked=true
                        break
                    fi
                done

                if [ "$tracked" = false ]; then
                    untracked=$((untracked + 1))
                fi
            done <<< "$(echo "$open_questions" | grep -E "^[0-9]+\.|^- ")"

            if [ "$untracked" -gt 0 ]; then
                warn "Handover has $untracked open question(s) with no matching gap or task" \
                     "$untracked of $oq_count open questions in LATEST.md appear untracked" \
                     "Register via 'fw gaps add' or 'fw task create' — see LATEST.md Open Questions section"
            else
                pass "Handover open questions: $oq_count tracked in gaps/tasks"
            fi
        else
            pass "Handover open questions: none (section empty or template placeholder)"
        fi
    else
        pass "Handover open questions: none"
    fi
else
    echo -e "  ${CYAN}SKIP${NC}  No handover file found"
fi

echo ""
fi # end handover

# ============================================
# SECTION 9: GRADUATION PIPELINE CHECK
# ============================================
if should_run_section "graduation"; then
echo "=== GRADUATION PIPELINE CHECKS ==="

LEARNINGS_FILE="$CONTEXT_DIR/project/learnings.yaml"
if [ -f "$LEARNINGS_FILE" ]; then
    # T-2677: shape-agnostic count. The old '^  - id: L-' (2-space only) grep
    # returned 0 against the real file (column-0 list items dominant), so the
    # >=20 branch — the ONLY programmatic caller of `fw promote suggest` —
    # never fired in the counter's entire life. Same file-shape-blindness
    # family as T-2676 (harvest) and T-2672 (resolve.sh).
    learning_count=$(grep -cE '^[[:space:]]*(- )?id: P?L-' "$LEARNINGS_FILE" 2>/dev/null) || learning_count=0

    if [ "$learning_count" -ge 20 ]; then
        # Check for promotion candidates using fw promote
        promote_output=$(PROJECT_ROOT="$PROJECT_ROOT" "$FRAMEWORK_ROOT/bin/fw" promote suggest 2>/dev/null) || true
        # shellcheck disable=SC2034 # ready_count/almost_count used for debug logging
        ready_count=$(echo "$promote_output" | grep -c "ready for promotion" 2>/dev/null) || ready_count=0
        # shellcheck disable=SC2034
        almost_count=$(echo "$promote_output" | grep -c "^  " 2>/dev/null) || almost_count=0

        if echo "$promote_output" | grep -q "No learnings currently meet"; then
            pass "Graduation pipeline: $learning_count learnings, no promotions ready yet"
        else
            warn "Learnings ready for promotion — review graduation candidates" \
                 "$learning_count learnings, promotion candidates available" \
                 "Run: fw promote suggest"
        fi
    else
        pass "Graduation pipeline: $learning_count learnings (threshold: 20)"
    fi
else
    echo -e "  ${CYAN}SKIP${NC}  No learnings file"
fi

echo ""
fi # end graduation

# ============================================
# SECTION 10: INCEPTION RESEARCH ARTIFACT CHECK (T-178/T-185)
# ============================================
if should_run_section "research"; then
echo "=== INCEPTION RESEARCH CHECKS ==="

# Check completed inception tasks for research artifacts (T-955: uses single-pass scan)
missing_research=0
if [ -n "$COMPLETED_SCAN" ]; then
    while IFS= read -r task_id; do
        [ -z "$task_id" ] && continue
        warn "Inception task $task_id has no research artifact in docs/reports/" \
             "Completed inception with no persisted research output" \
             "Save research findings: docs/reports/${task_id}-*.md"
        missing_research=$((missing_research + 1))
    done < <(echo "$COMPLETED_SCAN" | python3 -c "import sys,json; [print(x) for x in json.load(sys.stdin).get('missing_research',[])]" 2>/dev/null)
fi

if [ "$missing_research" -eq 0 ]; then
    inception_count=$(echo "$COMPLETED_SCAN" | python3 -c "import sys,json; print(json.load(sys.stdin).get('stats',{}).get('inception_count',0))" 2>/dev/null || echo "")
    # T-3105: "No completed inception tasks to check" used to be a PASS. It is
    # the empty-set case stated out loud and then scored as a success — the
    # exact shape this rule exists to remove.
    pass_over "$inception_count" "completed inception(s)" \
         "All completed inceptions have research artifacts" \
         "" "completed-task-scan reported no completed inceptions — C-001 coverage asserted nothing this run"
fi

echo ""
fi # end research

# ============================================
# SECTION 11: RESEARCH PERSISTENCE OE TESTS (C-001/C-002/C-003, T-194)
# ============================================
if should_run_section "oe-research"; then
echo "=== RESEARCH PERSISTENCE OE CHECKS ==="

# C-001 OE: Inceptions being WORKED (started-work) or being DECIDED (carrying a
# substantive ## Recommendation) should have a docs/reports/ artifact.
# T-955: uses the single-pass scan. T-3073: set widened from started-work-only to
# include recommendation-bearing inceptions at any status — an inception asking the
# operator for a go/no-go has finished researching, whatever its status field says.
# The two populations are counted and reported separately so widening the set does
# not silently inflate a number the operator has learned to read one way.
c001_missing=0
if [ -n "$ACTIVE_SCAN" ]; then
    while IFS='|' read -r task_id issue_type issue_reason artifact_name; do
        [ -z "$task_id" ] && continue
        if [ "$issue_reason" = "recommendation" ]; then
            _c001_population="awaiting decision — carries a substantive ## Recommendation, so research is finished"
        else
            _c001_population="in progress — status started-work"
        fi
        if [ "$issue_type" = "missing" ]; then
            warn "C-001: Inception $task_id ($issue_reason) has no research artifact in docs/reports/" \
                 "Inception $_c001_population, with no persisted research" \
                 "Create docs/reports/${task_id}-*.md — the thinking trail IS the artifact"
            c001_missing=$((c001_missing + 1))
        elif [ "$issue_type" = "unreferenced" ]; then
            warn "C-001: Inception $task_id ($issue_reason) has artifact but task doesn't reference it" \
                 "$artifact_name exists but not linked in task Updates" \
                 "Add artifact reference to ## Updates section of $task_id"
        fi
    done < <(echo "$ACTIVE_SCAN" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for item in data['research']['issues']:
    print(f\"{item['id']}|{item['type']}|{item.get('reason','started-work')}|{item.get('artifact','')}\")
" 2>/dev/null)
fi

# Population breakdown — printed whether or not anything is missing, so the
# operator can always see WHICH set produced the number (T-3073 A4).
_c001_counts=$(echo "$ACTIVE_SCAN" | python3 -c "
import sys, json
r = json.load(sys.stdin).get('research', {})
print('%d|%d|%d|%d' % (
    r.get('inception_active', 0), r.get('c001_missing_started', 0),
    r.get('inception_recommendation', 0), r.get('c001_missing_recommendation', 0)))
" 2>/dev/null || echo "0|0|0|0")
IFS='|' read -r _c001_n_started _c001_miss_started _c001_n_rec _c001_miss_rec <<< "$_c001_counts"

if [ "$c001_missing" -eq 0 ]; then
    if [ $((_c001_n_started + _c001_n_rec)) -gt 0 ]; then
        pass "C-001: All inceptions have research artifacts — $_c001_n_started started-work, $_c001_n_rec awaiting decision"
    else
        pass "C-001: No active inception tasks to check"
    fi
else
    info "C-001 population breakdown: $_c001_miss_started/$_c001_n_started started-work missing an artefact, $_c001_miss_rec/$_c001_n_rec awaiting-decision missing an artefact"
fi

# C-002 OE: Check commit-msg hook has research artifact check installed
if grep -q "inception-research-warnings" "$PROJECT_ROOT/.git/hooks/commit-msg" 2>/dev/null; then
    pass "C-002: commit-msg hook has research artifact check"
else
    warn "C-002: commit-msg hook missing research artifact check" \
         "Hook at .git/hooks/commit-msg doesn't contain C-002 gate" \
         "Reinstall hooks: fw git install-hooks (or manually add C-002)"
fi

# C-002 OE: Check warning log for recent inception commits without research
WARN_LOG="$CONTEXT_DIR/working/.inception-research-warnings"
if [ -f "$WARN_LOG" ]; then
    recent_warns=$(grep -c "$(date +%Y-%m-%d)" "$WARN_LOG" 2>/dev/null || true)
    recent_warns=$(echo "$recent_warns" | tr -d '[:space:]')
    if [ "$recent_warns" -gt 0 ]; then
        warn "C-002: $recent_warns inception commit(s) today without docs/reports/ artifact" \
             "Warnings logged in .inception-research-warnings" \
             "Review commits and ensure research is persisted"
    else
        pass "C-002: No research warnings today"
    fi
else
    pass "C-002: No research warnings logged (clean or first run)"
fi

# C-003 OE: Check checkpoint hook is wired and firing
CHECKPOINT_LOG="$CONTEXT_DIR/working/.inception-checkpoint-log"
if grep -q "inception-research-counter\|INCEPTION_RESEARCH_INTERVAL\|C-003" "$FRAMEWORK_ROOT/agents/context/checkpoint.sh" 2>/dev/null; then
    pass "C-003: Research checkpoint logic present in checkpoint.sh"
else
    warn "C-003: Research checkpoint logic missing from checkpoint.sh" \
         "checkpoint.sh doesn't contain C-003 inception research check" \
         "Add C-003 research checkpoint to checkpoint.sh post-tool handler"
fi

if [ -f "$CHECKPOINT_LOG" ]; then
    today_prompts=$(grep -c "$(date +%Y-%m-%d)" "$CHECKPOINT_LOG" 2>/dev/null || true)
    today_prompts=$(echo "$today_prompts" | tr -d '[:space:]')
    echo "       C-003 checkpoint prompts today: $today_prompts"
fi

# C-006 OE (T-1716): Active inceptions with template-only Recommendation
# Detective for the T-679 rule decay pattern (T-1715 meta-RCA). Catches
# drift between filing-time gate sweeps. See lib/inception_recommendation.sh
# for the extracted check function (testable in isolation).
source "$FRAMEWORK_ROOT/lib/inception_recommendation.sh" 2>/dev/null || true
c006_missing=0
while IFS= read -r task_id; do
    [ -z "$task_id" ] && continue
    warn "C-006: Inception $task_id has template-only Recommendation block" \
         "T-679 rule decay (T-1715 family); agent filed without recommendation" \
         "Retrofit: fill in **Recommendation:** GO|NO-GO|DEFER + rationale + evidence; OR re-file via 'fw inception start --recommendation X --rationale ...' (T-1716 gate)"
    c006_missing=$((c006_missing + 1))
done < <(find_inceptions_without_recommendation "$PROJECT_ROOT/.tasks/active" 2>/dev/null)

if [ "$c006_missing" -eq 0 ]; then
    _c006_pop=$(grep -rl '^workflow_type:[[:space:]]*inception' "$PROJECT_ROOT/.tasks/active" 2>/dev/null | wc -l)
    pass_over "$_c006_pop" "active inception(s)" \
         "C-006: All active inceptions have a real Recommendation block" \
         "" "No active task declares workflow_type: inception — the Recommendation rail covered nothing this run"
    unset _c006_pop
fi

echo ""
fi # end oe-research

# ============================================
# OE-FAST: Controls checked every 30 minutes (T-195)
# CTL-001, CTL-003, CTL-004, CTL-018
# ============================================
if should_run_section "oe-fast"; then
echo "=== OE-FAST: 30-MINUTE CONTROL CHECKS ==="

# CTL-001 OE: Task-First Gate — focus file exists when source commits happen
FOCUS_FILE="$CONTEXT_DIR/working/focus.yaml"
if [ -f "$FOCUS_FILE" ]; then
    focus_task=$({ grep "^current_task:" "$FOCUS_FILE" 2>/dev/null || true; } | head -1 | sed 's/current_task: *//' | tr -d ' "')
    if [ -n "$focus_task" ] && [ "$focus_task" != "null" ] && [ "$focus_task" != "~" ]; then
        pass "CTL-001: Focus file has active task ($focus_task)"
    else
        # Only warn if there's evidence of recent activity
        recent_commits=$(git -C "$PROJECT_ROOT" log --oneline --since="30 minutes ago" 2>/dev/null | wc -l | tr -d ' ')
        if [ "$recent_commits" -gt 0 ]; then
            warn "CTL-001: Focus file empty but $recent_commits commit(s) in last 30min" \
                 "Task-first gate may not be firing" \
                 "Check .claude/settings.json hook configuration for check-active-task"
        else
            pass "CTL-001: Focus file empty (no recent activity — expected)"
        fi
    fi
else
    warn "CTL-001: Focus file missing ($FOCUS_FILE)" \
         "Task-first gate may not be creating focus state" \
         "Run: fw context focus T-XXX"
fi

# CTL-003 OE: Budget Gate — status file is fresh during active session
BUDGET_FILE="$CONTEXT_DIR/working/.budget-status"
if [ -f "$BUDGET_FILE" ]; then
    budget_age=$(find "$BUDGET_FILE" -mmin -5 2>/dev/null)
    if [ -n "$budget_age" ]; then
        pass "CTL-003: Budget status file fresh (< 5min old)"
    else
        # Not necessarily an error — no active session means stale file is fine
        budget_mtime=$(stat -c %Y "$BUDGET_FILE" 2>/dev/null || echo 0)
        now=$(date +%s)
        age_min=$(( (now - budget_mtime) / 60 ))
        if [ "$age_min" -gt 120 ]; then
            pass "CTL-003: Budget status file stale (${age_min}min — no active session)"
        else
            warn "CTL-003: Budget status file stale (${age_min}min old)" \
                 "Budget gate may not be running during active session" \
                 "Check PreToolUse hook wiring for budget-gate.sh"
        fi
    fi
else
    pass "CTL-003: Budget status file absent (no active session)"
fi

# CTL-004 OE: Context Checkpoint — tool counter behavior
TOOL_COUNTER="$CONTEXT_DIR/working/.tool-counter"
if [ -f "$TOOL_COUNTER" ]; then
    counter_val=$(tr -d '[:space:]' < "$TOOL_COUNTER" 2>/dev/null)
    counter_val=${counter_val:-0}
    # After a commit, post-commit hook resets to 0. High values without recent commit = checkpoint working
    last_commit_age=$(git -C "$PROJECT_ROOT" log -1 --format="%cr" 2>/dev/null || echo "unknown")
    pass "CTL-004: Tool counter at $counter_val (last commit: $last_commit_age)"
else
    pass "CTL-004: Tool counter absent (session not active or first run)"
fi

# CTL-018 OE: Token Budget Monitor — status file valid JSON
if [ -f "$BUDGET_FILE" ]; then
    if python3 -c "import json; d=json.load(open('$BUDGET_FILE')); assert 'level' in d" 2>/dev/null; then
        budget_level=$(python3 -c "import json; print(json.load(open('$BUDGET_FILE'))['level'])" 2>/dev/null)
        pass "CTL-018: Budget status valid JSON (level: $budget_level)"
    else
        fail "CTL-018: Budget status file is not valid JSON or missing 'level' field" \
             "$BUDGET_FILE content: $(head -1 "$BUDGET_FILE" 2>/dev/null)" \
             "Investigate budget-gate.sh output format"
    fi
else
    pass "CTL-018: Budget status absent (no active session — expected)"
fi

echo ""
fi # end oe-fast

# ============================================
# OE-HOURLY: Controls checked every hour (T-195)
# CTL-008, CTL-020
# ============================================
if should_run_section "oe-hourly"; then
echo "=== OE-HOURLY: HOURLY CONTROL CHECKS ==="

# CTL-008 OE: Task Reference Gate — recent commits have T-XXX prefix
# T-590: Respect traceability baseline if set
_ctl008_range=""
_ctl008_baseline_file="$PROJECT_ROOT/.context/project/traceability-baseline"
if [ -f "$_ctl008_baseline_file" ]; then
    _ctl008_base=$(tr -d '[:space:]' < "$_ctl008_baseline_file")
    if git -C "$PROJECT_ROOT" rev-parse --verify "$_ctl008_base" >/dev/null 2>&1; then
        _ctl008_range="${_ctl008_base}..HEAD"
    fi
fi
if [ -n "$_ctl008_range" ]; then
    # shellcheck disable=SC2086 # _ctl008_range intentionally unquoted
    total_recent=$(git -C "$PROJECT_ROOT" log --oneline -20 $_ctl008_range 2>/dev/null | wc -l | tr -d ' ')
else
    total_recent=$(git -C "$PROJECT_ROOT" log --oneline -20 2>/dev/null | wc -l | tr -d ' ')
fi
if [ "$total_recent" -gt 0 ]; then
    if [ -n "$_ctl008_range" ]; then
        # shellcheck disable=SC2086
        without_task=$(git -C "$PROJECT_ROOT" log --oneline -20 $_ctl008_range 2>/dev/null | grep -cv '^[a-f0-9]* T-' || true)
    else
        without_task=$(git -C "$PROJECT_ROOT" log --oneline -20 2>/dev/null | grep -cv '^[a-f0-9]* T-' || true)
    fi
    without_task=$(echo "$without_task" | tr -d '[:space:]')
    ratio=$(( (total_recent - without_task) * 100 / total_recent ))
    # shellcheck disable=SC2086 # _ctl008_range intentionally unquoted (empty = no range arg)
    if [ "$ratio" -ge 95 ]; then
        pass "CTL-008: Task reference traceability ${ratio}% ($without_task/$total_recent without T-XXX)"
    elif [ "$ratio" -ge 80 ]; then
        grace_warn "CTL-008: Task reference traceability ${ratio}% ($without_task/$total_recent without T-XXX)" \
             "$(git -C "$PROJECT_ROOT" log --oneline -20 ${_ctl008_range} | grep -v '^[a-f0-9]* T-' | head -3)" \
             "Ensure all commits use T-XXX prefix (commit-msg hook)"
    else
        grace_fail "CTL-008: Task reference traceability ${ratio}% ($without_task/$total_recent without T-XXX)" \
             "Many commits missing task references — hook may not be installed" \
             "Run: fw git install-hooks"
    fi
else
    pass "CTL-008: No commits to check"
fi

# CTL-020 OE: Continuous Audit — cron audit files produced recently
CRON_DIR="$AUDITS_DIR/cron"
if [ -d "$CRON_DIR" ]; then
    recent_cron=$(find "$CRON_DIR" -name '*.yaml' -mmin -60 -not -name 'LATEST*' 2>/dev/null | wc -l | tr -d ' ')
    if [ "$recent_cron" -gt 0 ]; then
        pass "CTL-020: $recent_cron cron audit file(s) in last hour"
    else
        warn "CTL-020: No cron audit files in last hour" \
             "$(find "$CRON_DIR" -maxdepth 1 -name '*.yaml' -type f -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-)" \
             "Check cron schedule: crontab -l | grep agentic; cat /etc/cron.d/agentic-audit"
    fi
else
    grace_warn "CTL-020: Cron audit directory missing ($CRON_DIR)" \
         "Directory not created" \
         "Run: fw audit schedule install"
fi

echo ""
fi # end oe-hourly

# ============================================
# OE-DAILY: Controls checked once per day (T-195)
# CTL-002, CTL-005, CTL-006, CTL-007, CTL-009, CTL-010, CTL-011, CTL-012, CTL-013, CTL-019
# ============================================
if should_run_section "oe-daily"; then
echo "=== OE-DAILY: DAILY CONTROL CHECKS ==="

# CTL-002 OE: Tier 0 Guard — hook script exists + settings wired
if [ -x "$FRAMEWORK_ROOT/agents/context/check-tier0.sh" ]; then
    if grep -q 'check-tier0' "$PROJECT_ROOT/.claude/settings.json" 2>/dev/null; then
        pass "CTL-002: Tier 0 guard installed and wired in settings.json"
    else
        warn "CTL-002: Tier 0 guard script exists but not wired in settings.json" \
             "check-tier0.sh exists but settings.json doesn't reference it" \
             "Add PreToolUse Bash hook for check-tier0.sh in .claude/settings.json"
    fi
else
    fail "CTL-002: Tier 0 guard script missing or not executable" \
         "$FRAMEWORK_ROOT/agents/context/check-tier0.sh" \
         "Restore check-tier0.sh from git"
fi

# CTL-005 OE: Error Watchdog — hook script exists + settings wired
if [ -x "$FRAMEWORK_ROOT/agents/context/error-watchdog.sh" ]; then
    if grep -q 'error-watchdog' "$PROJECT_ROOT/.claude/settings.json" 2>/dev/null; then
        pass "CTL-005: Error watchdog installed and wired in settings.json"
    else
        warn "CTL-005: Error watchdog script exists but not wired in settings.json" \
             "error-watchdog.sh exists but settings.json doesn't reference it" \
             "Add PostToolUse hook for error-watchdog.sh in .claude/settings.json"
    fi
else
    fail "CTL-005: Error watchdog script missing or not executable" \
         "$FRAMEWORK_ROOT/agents/context/error-watchdog.sh" \
         "Restore error-watchdog.sh from git"
fi

# CTL-006 OE: Pre-Compact Handover — handover exists near compaction events
COMPACT_LOG="$CONTEXT_DIR/working/.compact-log"
if [ -f "$COMPACT_LOG" ]; then
    # Check each compaction has a handover within ~5min
    compact_count=$(wc -l < "$COMPACT_LOG" 2>/dev/null | tr -d ' ')
    handover_count=$(find "$CONTEXT_DIR/handovers" -maxdepth 1 -name 'S-*.md' -type f 2>/dev/null | wc -l | tr -d ' ')
    if [ "$handover_count" -ge "$compact_count" ] || [ "$compact_count" -eq 0 ]; then
        pass "CTL-006: Handover coverage for compactions ($handover_count handovers, $compact_count compactions)"
    else
        warn "CTL-006: Fewer handovers ($handover_count) than compactions ($compact_count)" \
             "Some compactions may not have triggered pre-compact handover" \
             "Check pre-compact.sh hook configuration in .claude/settings.json"
    fi
else
    pass "CTL-006: No compact log (no compactions recorded)"
fi

# CTL-007 OE: Post-Compact Resume — settings.json has resume hook
if grep -q 'post-compact-resume\|SessionStart' "$PROJECT_ROOT/.claude/settings.json" 2>/dev/null; then
    pass "CTL-007: Post-compact resume hook configured in settings.json"
else
    warn "CTL-007: Post-compact resume hook not found in settings.json" \
         "SessionStart hook missing" \
         "Add SessionStart:compact hook for post-compact-resume.sh"
fi

# CTL-009 OE: Inception Commit Gate — active inceptions with >2 commits have decision or bypass
shopt -s nullglob
for task_file in "$TASKS_DIR/active"/*.md "$TASKS_DIR/completed"/*.md; do
    [ -f "$task_file" ] || continue
    task_workflow=$({ grep "^workflow_type:" "$task_file" 2>/dev/null || true; } | head -1 | cut -d: -f2 | tr -d ' ')
    [ "$task_workflow" != "inception" ] && continue
    task_id=$({ grep "^id:" "$task_file" 2>/dev/null || true; } | head -1 | sed 's/id: //' | tr -d ' ')
    [ -z "$task_id" ] && continue

    # Count commits for this task
    task_commits=$(git -C "$PROJECT_ROOT" log --oneline --all --grep="$task_id" 2>/dev/null | wc -l | tr -d ' ')
    if [ "$task_commits" -gt 2 ]; then
        # Check for decision
        has_decision=$(grep -c "inception-decision\|fw inception decide\|Decision:.*GO\|Decision:.*NO-GO\|Decision\*\*: DEFER\|Decision: DEFER\|Decision\*\*: SUPERSEDED\|Decision: SUPERSEDED" "$task_file" 2>/dev/null || true)
        has_decision=$(echo "$has_decision" | tr -d '[:space:]')
        # Check for bypass log entries
        has_bypass=$(grep -c "$task_id" "$CONTEXT_DIR/bypass-log.yaml" 2>/dev/null || true)
        has_bypass=$(echo "$has_bypass" | tr -d '[:space:]')
        if [ "$has_decision" -gt 0 ]; then
            pass "CTL-009: Inception $task_id has decision ($task_commits commits)"
        elif [ "$has_bypass" -gt 0 ]; then
            warn "CTL-009: Inception $task_id using bypasses ($task_commits commits, $has_bypass bypasses, no decision)" \
                 "Inception gate bypassed via --no-verify" \
                 "Record decision: fw inception decide $task_id go|no-go"
        else
            fail "CTL-009: Inception $task_id has $task_commits commits but no decision or bypass log" \
                 "Inception commit gate may not be installed" \
                 "Run: fw git install-hooks"
        fi
    fi
done
shopt -u nullglob

# CTL-027 OE: Inception Template Sections — inception tasks must have ## Recommendation and ## Decision (T-1263)
shopt -s nullglob
for task_file in "$TASKS_DIR/active"/*.md; do
    [ -f "$task_file" ] || continue
    task_workflow=$({ grep "^workflow_type:" "$task_file" 2>/dev/null || true; } | head -1 | cut -d: -f2 | tr -d ' ')
    [ "$task_workflow" != "inception" ] && continue
    task_id=$({ grep "^id:" "$task_file" 2>/dev/null || true; } | head -1 | sed 's/id: //' | tr -d ' ')
    [ -z "$task_id" ] && continue

    _missing=""
    grep -qE '^## Recommendation[[:space:]]*$' "$task_file" || _missing="## Recommendation"
    grep -qE '^## Decision[[:space:]]*$' "$task_file" || _missing="${_missing:+$_missing, }## Decision"
    if [ -n "$_missing" ]; then
        fail "CTL-027: Inception $task_id missing required sections: $_missing" \
             "fw inception decide will fail or duplicate decision blocks" \
             "Add missing sections to task file: $task_file"
    else
        pass "CTL-027: Inception $task_id has Recommendation + Decision sections"
    fi
done
shopt -u nullglob

# CTL-010 OE: Bypass Detector — --no-verify commits appear in bypass-log
BYPASS_LOG="$CONTEXT_DIR/bypass-log.yaml"
if [ -f "$BYPASS_LOG" ]; then
    bypass_count=$(grep -c "commit:" "$BYPASS_LOG" 2>/dev/null || true)
    bypass_count=$(echo "$bypass_count" | tr -d '[:space:]')
    if [ "$bypass_count" -gt 0 ]; then
        pass "CTL-010: Bypass log has $bypass_count entries (post-commit detector working)"
    else
        pass "CTL-010: Bypass log exists but empty (no bypasses detected)"
    fi
else
    # Check if any commits lack T-XXX (potential unlogged bypasses)
    no_task=$(git -C "$PROJECT_ROOT" log --oneline -20 2>/dev/null | grep -cv '^[a-f0-9]* T-' || true)
    no_task=$(echo "$no_task" | tr -d '[:space:]')
    if [ "$no_task" -gt 0 ]; then
        grace_warn "CTL-010: No bypass log but $no_task commit(s) without T-XXX prefix" \
             "post-commit hook may not be creating bypass-log.yaml" \
             "Check .git/hooks/post-commit exists and is executable"
    else
        pass "CTL-010: No bypass log needed (all commits have task references)"
    fi
fi

# CTL-011 OE: Audit Push Gate — pre-push hook installed
if [ -x "$PROJECT_ROOT/.git/hooks/pre-push" ]; then
    pass "CTL-011: pre-push hook installed and executable"
else
    warn "CTL-011: pre-push hook missing or not executable" \
         "$PROJECT_ROOT/.git/hooks/pre-push" \
         "Run: fw git install-hooks"
fi

# CTL-013 OE: Verification Gate — spot-check recently completed tasks
# (Full re-run of all verification is expensive; check latest 3)
verify_fail=0
shopt -s nullglob
recent_completed=$(find "$TASKS_DIR/completed" -maxdepth 1 -name '*.md' -type f -print0 2>/dev/null | xargs -r -0 ls -t 2>/dev/null | head -3)
for task_file in $recent_completed; do
    [ -f "$task_file" ] || continue
    task_id=$({ grep "^id:" "$task_file" 2>/dev/null || true; } | head -1 | sed 's/id: //' | tr -d ' ')

    # Extract verification commands (skip HTML comment blocks)
    in_verify=false
    in_comment=false
    verify_cmds=()
    while IFS= read -r line; do
        if echo "$line" | grep -q "^## Verification"; then
            in_verify=true
            continue
        fi
        if echo "$line" | grep -q "^## " && [ "$in_verify" = true ]; then
            break
        fi
        if [ "$in_verify" = true ]; then
            # Track HTML comment blocks (<!-- ... -->)
            if echo "$line" | grep -q '<!--'; then
                if ! echo "$line" | grep -q -- '-->'; then
                    in_comment=true
                fi
                continue
            fi
            if [ "$in_comment" = true ]; then
                if echo "$line" | grep -q -- '-->'; then
                    in_comment=false
                fi
                continue
            fi
            trimmed="${line#"${line%%[![:space:]]*}"}"
            [ -z "$trimmed" ] && continue
            echo "$trimmed" | grep -q '^#' && continue
            verify_cmds+=("$trimmed")
        fi
    done < "$task_file"

    if [ ${#verify_cmds[@]} -gt 0 ]; then
        cmd_pass=0
        cmd_fail=0
        cmd_skipped=0
        cmd_isolated_pass=0
        for cmd in "${verify_cmds[@]}"; do
            # T-1870/L-391: a verification line that invokes `bin/fw audit`
            # (or `fw audit`) cannot run during CTL-013 — we're already inside
            # the audit lock, so the nested call exits "Another audit is
            # already running" and any downstream grep fails. Skip rather
            # than report a false positive. Safe pattern in such tasks:
            # grep the most recent saved audit YAML instead.
            if echo "$cmd" | grep -qE '(\bbin/)?fw +audit\b'; then
                cmd_skipped=$((cmd_skipped + 1))
                continue
            fi
            if [ -n "${FW_AUDIT_VERIFY_DEBUG:-}" ]; then
                # T-1475: capture stderr/stdout so CTL-013 false positives can be
                # diagnosed (OBS-022 — audit reports bats fails, isolated runs pass).
                _aud_out=$(mktemp 2>/dev/null || echo "/tmp/fw-audit-verify-$$")
                # FW_AUDIT_VERIFY_TRACE=1 adds bash xtrace for deepest visibility.
                if [ -n "${FW_AUDIT_VERIFY_TRACE:-}" ]; then
                    _eval_rc=0
                    {
                        echo "PWD=$PWD"
                        echo "BASH_OPTS=$-"
                        echo "PATH=$PATH"
                        env | grep -E '^(BATS|TMPDIR|HOME|SHELL|TERM|TAP)' | sort
                        set -x
                        eval "$cmd"
                        set +x
                    } >"$_aud_out" 2>&1 || _eval_rc=$?
                else
                    # T-1475: brace-grouped redirection (NOT subshell). When the
                    # eval'd command was bats, the prior subshell variant produced
                    # rc=1 with no output (Heisenbug — observable failure with
                    # `( eval "$cmd" ) >X 2>&1`, but a brace-group `{ eval ...; } >X 2>&1`
                    # passes consistently). Root cause unconfirmed (likely bats
                    # parent-shell coupling); brace-group sidesteps it.
                    _eval_rc=0
                    { eval "$cmd"; } >"$_aud_out" 2>&1 || _eval_rc=$?
                fi
                if [ "$_eval_rc" -eq 0 ]; then
                    cmd_pass=$((cmd_pass + 1))
                    rm -f "$_aud_out"
                else
                    cmd_fail=$((cmd_fail + 1))
                    echo "DEBUG ($task_id) FAIL (rc=$_eval_rc): $cmd" >&2
                    echo "DEBUG ($task_id) captured output (first 20 lines):" >&2
                    head -20 "$_aud_out" >&2 || true
                    echo "DEBUG ($task_id) ---" >&2
                    rm -f "$_aud_out"
                fi
            else
                # T-1475 / T-1870: brace-group (not subshell) to sidestep
                # the bats parent-shell coupling Heisenbug. Match the DEBUG
                # path's structure (which already uses brace-group). The
                # earlier implicit subshell variant (`eval ... >/dev/null`)
                # was a known reproducer.
                _eval_rc=0
                { eval "$cmd"; } >/dev/null 2>&1 || _eval_rc=$?
                # T-1870 / OBS-022 retry: a failing bats command often
                # fails inside the audit's polluted env but passes in
                # isolation. Re-run once under `env -i` (clean env). If
                # that passes, treat as OBS-022 isolation noise — PASS with
                # a note recorded in cmd_isolated_pass.
                if [ "$_eval_rc" -ne 0 ] && [[ "$cmd" == bats\ * ]]; then
                    if env -i PATH=/usr/bin:/usr/local/bin:/root/.cargo/bin HOME="$HOME" \
                            bash -c "cd '$PROJECT_ROOT' && $cmd" >/dev/null 2>&1; then
                        _eval_rc=0
                        cmd_isolated_pass=$((cmd_isolated_pass + 1))
                    fi
                fi
                if [ "$_eval_rc" -eq 0 ]; then
                    cmd_pass=$((cmd_pass + 1))
                else
                    cmd_fail=$((cmd_fail + 1))
                    # T-1395: FW_AUDIT_VERIFY_DEBUG=1 dumps captured output (T-1475).
                fi
            fi
        done
        if [ "$cmd_fail" -eq 0 ]; then
            _notes=""
            [ "$cmd_skipped" -gt 0 ] && _notes="${_notes}${_notes:+, }$cmd_skipped skipped — nested-audit invocation"
            [ "$cmd_isolated_pass" -gt 0 ] && _notes="${_notes}${_notes:+, }$cmd_isolated_pass passed only in isolation — OBS-022 bats env-contam"
            if [ -n "$_notes" ]; then
                pass "CTL-013: $task_id verification re-run: $cmd_pass/$((cmd_pass + cmd_fail)) pass ($_notes)"
            else
                pass "CTL-013: $task_id verification re-run: $cmd_pass/$((cmd_pass + cmd_fail)) pass"
            fi
        else
            warn "CTL-013: $task_id verification re-run: $cmd_fail command(s) failing" \
                 "Verification commands that passed at completion now fail" \
                 "Review $task_id — environment may have changed"
            verify_fail=$((verify_fail + 1))
        fi
    fi
done
shopt -u nullglob

# CTL-013b OE (T-2765): Verification Gate — rotating slice of the HUMAN REVIEW QUEUE.
#
# CTL-013 above covers the latest 3 files in completed/. The review queue lives in
# .tasks/active/ (221 tasks at filing) and was outside every rail's population — a
# stored block could rot after completion and stay red until the operator tripped it
# at close (L-539; found by T-2764, where two tasks had been red for a week).
#
# Bounded and ROTATING: `fw verify-queue` picks the least-recently-checked first and
# persists the cursor, so consecutive daily runs advance through the queue instead of
# re-checking the same head — which is precisely how CTL-013's fixed top-3 window let
# the tail rot. Set FW_VERIFY_QUEUE_AUDIT_LIMIT=0 to disable.
vq_limit="${FW_VERIFY_QUEUE_AUDIT_LIMIT:-3}"
if [ "$vq_limit" != "0" ] && [ -f "$FRAMEWORK_ROOT/lib/verify_queue.py" ]; then
    vq_json=$(cd "$PROJECT_ROOT" && PROJECT_ROOT="$PROJECT_ROOT" FRAMEWORK_ROOT="$FRAMEWORK_ROOT" \
        FW_VERIFY_QUEUE_TIMEOUT="${FW_VERIFY_QUEUE_TIMEOUT:-90}" \
        python3 "$FRAMEWORK_ROOT/lib/verify_queue.py" --limit "$vq_limit" --json 2>/dev/null || true)
    vq_red=$(echo "$vq_json" | python3 -c "import json,sys
try: print(json.load(sys.stdin).get('red', 0))
except Exception: print(-1)" 2>/dev/null || echo -1)
    vq_checked=$(echo "$vq_json" | python3 -c "import json,sys
try: print(json.load(sys.stdin).get('checked', 0))
except Exception: print(0)" 2>/dev/null || echo 0)
    if [ "$vq_red" = "-1" ]; then
        info "CTL-013b: review-queue verification re-run produced no verdict (skipped)"
    elif [ "$vq_red" = "0" ]; then
        pass_over "$vq_checked" "review-queue task(s) re-run" \
             "CTL-013b: review-queue verification re-run, 0 red" \
             "" "fw verify-queue reported 0 red out of 0 checked — the rotating cursor covered no task this run"
    else
        vq_ids=$(echo "$vq_json" | python3 -c "import json,sys
d=json.load(sys.stdin)
print(' '.join(r['task'] for r in d.get('results', []) if r.get('status') == 'fail'))" 2>/dev/null || true)
        warn "CTL-013b: review-queue verification re-run: $vq_red of $vq_checked task(s) red" \
             "Awaiting human review with a failing stored block: $vq_ids" \
             "Run: fw verify-queue --task <id> — repair the line or confirm the regression before the human trips it at close"
    fi
fi

# CTL-019 OE: Auto-Restart — claude-fw wrapper exists
if [ -x "$FRAMEWORK_ROOT/bin/claude-fw" ]; then
    pass "CTL-019: claude-fw wrapper installed and executable"
else
    warn "CTL-019: claude-fw wrapper missing or not executable" \
         "$FRAMEWORK_ROOT/bin/claude-fw" \
         "Auto-restart won't work without claude-fw wrapper"
fi

# CTL-025 OE: P-010 Agent/Human AC split — partial-complete tasks have owner:human (T-955: uses scan)
if [ -n "$ACTIVE_SCAN" ]; then
    while IFS='|' read -r task_id owner is_valid; do
        [ -z "$task_id" ] && continue
        if [ "$is_valid" = "True" ]; then
            pass "CTL-025: $task_id partial-complete with owner:human ✓"
        else
            warn "CTL-025: $task_id is work-completed in active/ but owner is '$owner' (expected: human)" \
                 "Partial-complete task without human ownership" \
                 "Run: fw task update $task_id --owner human"
        fi
    done < <(echo "$ACTIVE_SCAN" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for item in data['ownership']['issues']:
    print(f\"{item['id']}|{item['owner']}|{item['valid']}\")
" 2>/dev/null)
fi

# CTL-031 OE: stuck partial-complete after Human-AC re-class (T-1903, L-403)
#
# FORMERLY CTL-029 (renumbered T-3035). This control and the completable-but-not-
# completed detector below both shipped as CTL-029 — T-1903 claimed the id first,
# T-2055 reused it. The id stayed with T-2055's control because every downstream
# reference had attached to it (tests/unit/test_audit_completable_not_completed.bats
# asserts the literal "CTL-029: ... has all Agent ACs ticked", and
# docs/reports/T-2137 cites CTL-029 four times meaning that control). Renumbering
# this one touched only audit.sh. Audit logs and reports predating 2026-08-16 that
# say CTL-029 may mean either — disambiguate on the message text, not the id.
# Detects tasks in active/ with status: work-completed AND zero unchecked
# checkboxes (after HTML-comment strip). These are archive-eligible but
# didn't auto-archive because the partial-complete recheck only re-fires
# on `--status work-completed` re-invocation. Triggered by T-1894/T-1897-
# style re-class operations that drain Human ACs to zero after the first
# work-completed transition.
ARCHIVE_ELIGIBLE_OUT=$(PROJECT_ROOT="$PROJECT_ROOT" python3 - <<'PYAUDIT_ARCHIVE' 2>/dev/null
import os, re, sys
project_root = os.environ.get('PROJECT_ROOT', '.')
active_dir = os.path.join(project_root, '.tasks', 'active')
if not os.path.isdir(active_dir):
    sys.exit(0)
stuck = []
for fn in sorted(os.listdir(active_dir)):
    if not (fn.startswith('T-') and fn.endswith('.md')):
        continue
    path = os.path.join(active_dir, fn)
    try:
        text = open(path).read()
    except OSError:
        continue
    m = re.search(r'^id:\s*(T-\d+)', text, re.MULTILINE)
    task_id = m.group(1) if m else fn
    m = re.search(r'^status:\s*(\S+)', text, re.MULTILINE)
    if not m or m.group(1) != 'work-completed':
        continue
    ac_match = re.search(r'^## Acceptance Criteria\b(.*?)(?=^## )', text, re.MULTILINE | re.DOTALL)
    if not ac_match:
        continue
    ac = re.sub(r'<!--.*?-->', '', ac_match.group(1), flags=re.DOTALL)
    unchecked = len(re.findall(r'^\s*-\s*\[ \]', ac, re.MULTILINE))
    total = len(re.findall(r'^\s*-\s*\[[ x]\]', ac, re.MULTILINE))
    if total > 0 and unchecked == 0:
        stuck.append(task_id)
print('|'.join(stuck))
PYAUDIT_ARCHIVE
)
if [ -z "$ARCHIVE_ELIGIBLE_OUT" ]; then
    pass_over "$(find "$PROJECT_ROOT/.tasks/active" -maxdepth 1 -name 'T-*.md' -type f 2>/dev/null | wc -l)" \
         "active task(s)" "CTL-031: No archive-eligible stuck partial-complete tasks (T-1903/L-403)" \
         "" ".tasks/active/ holds no task files, so nothing could be stuck"
else
    stuck_count=$(echo "$ARCHIVE_ELIGIBLE_OUT" | tr '|' '\n' | wc -l)
    warn "CTL-031: $stuck_count stuck partial-complete task(s) — all ACs ticked, in active/ — run: bin/fw task archive-eligible" \
         "Tasks: $(echo "$ARCHIVE_ELIGIBLE_OUT" | tr '|' ' ')" \
         "Sweep with: bin/fw task archive-eligible (origin: T-1903, L-403)"
fi

echo ""
fi # end oe-daily

# ============================================
# CTL-026: Human Sovereignty Gate present in update-task.sh (T-1884, L-390 third instance)
# Originally lived inside the oe-daily block; promoted by T-1884 to fire on
# `compliance || oe-daily` so the pre-push audit catches a missing/regressed
# sovereignty gate BEFORE the commit ships. Detection class is different from
# CTL-028/CTL-012 (framework-source presence check rather than corpus scan),
# but the detection-window gap is identical — arguably more severe, because
# the gate-source can be regressed by the very commit being pushed.
# ============================================
if should_run_section "compliance" || should_run_section "oe-daily"; then
    if grep -qi 'sovereignty gate.*R-033' "$FRAMEWORK_ROOT/agents/task-create/update-task.sh" 2>/dev/null; then
        if grep -q 'human ownership is protected' "$FRAMEWORK_ROOT/agents/task-create/update-task.sh" 2>/dev/null; then
            pass "CTL-026: Human sovereignty gate present (completion + owner protection)"
        else
            warn "CTL-026: Completion gate present but owner protection missing" \
                 "update-task.sh has sovereignty gate but not owner protection" \
                 "Check update-task.sh for R-033 owner protection logic"
        fi
    else
        fail "CTL-026: Human sovereignty gate missing from update-task.sh" \
             "update-task.sh does not contain sovereignty gate" \
             "Re-implement R-033 gates in update-task.sh"
    fi
fi

# ============================================
# CTL-028: Status-drift detection (T-1870, L-390)
# Originally lived inside the oe-daily block; promoted by T-1882 to fire on
# `compliance || oe-daily` so the pre-push audit (which includes compliance)
# catches the `git mv → completed/` bypass class BEFORE the drift ships,
# rather than waiting up to 24h for the next oe-daily cron run.
# ============================================
if should_run_section "compliance" || should_run_section "oe-daily"; then
    status_desync_fail=0
    if [ -n "$COMPLETED_SCAN" ]; then
        while IFS='|' read -r task_id observed_status; do
            [ -z "$task_id" ] && continue
            warn "CTL-028: $task_id is in .tasks/completed/ but frontmatter status='$observed_status' (expected: work-completed)" \
                 "Likely cause: git mv bypassed the state machine (L-390)" \
                 "Fix: bin/fw task update $task_id --status work-completed — the normal close runs the AC and verification gates and usually passes (832 measured 3 of 4 real drifted tasks closing clean two weeks stale). If a gate legitimately fails, fix the work or re-open it. Only as a last resort: add --force, which BYPASSES those gates and logs a Tier-2 entry. Do not hand-edit frontmatter — that is the git-mv bypass (L-390) this control detects."
            status_desync_fail=$((status_desync_fail + 1))
        done < <(echo "$COMPLETED_SCAN" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for item in data.get('status_desync', []):
    print(f\"{item['id']}|{item['status']}\")
" 2>/dev/null)
    fi
    if [ "$status_desync_fail" -eq 0 ]; then
        pass_over "$(echo "$COMPLETED_SCAN" | python3 -c "import sys,json; print(json.load(sys.stdin).get('stats',{}).get('total',0))" 2>/dev/null || echo "")" \
             "completed task(s)" "CTL-028: All completed/ tasks have frontmatter status: work-completed" \
             "" "completed-task-scan reported no completed tasks — the status-desync rail covered nothing"
    fi
fi

# ============================================
# CTL-030: horizon-drift on completed/ tasks (T-2162, arc-009 Slice 3)
# Stored horizon on completed/ is behaviorally irrelevant after T-2160 (render
# derives `past` from _location), but a non-null value is a YAML lie. T-2161
# nulled the existing pile; this rail catches future drift — typically each
# new task that closes carries `horizon: now` until the migration is re-run.
# Fix: bin/migrate-horizon-null-completed.sh (idempotent).
# ============================================
if should_run_section "compliance" || should_run_section "oe-daily"; then
    horizon_drift_fail=0
    if [ -n "$COMPLETED_SCAN" ]; then
        while IFS='|' read -r task_id observed_horizon; do
            [ -z "$task_id" ] && continue
            fail "CTL-030: $task_id is in .tasks/completed/ but stored horizon='$observed_horizon' (expected: null/absent — render derives 'past' from _location, T-2160)" \
                 "Origin: arc-009 horizon-axis-hardening (T-2160 derived-past, T-2161 migration, T-2162 audit rail)" \
                 "Fix: bin/migrate-horizon-null-completed.sh   (idempotent, only touches completed/ files with non-null horizon)"
            horizon_drift_fail=$((horizon_drift_fail + 1))
        done < <(echo "$COMPLETED_SCAN" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for item in data.get('horizon_drift', []):
    print(f\"{item['id']}|{item['horizon']}\")
" 2>/dev/null)
    fi
    if [ "$horizon_drift_fail" -eq 0 ]; then
        pass_over "$(echo "$COMPLETED_SCAN" | python3 -c "import sys,json; print(json.load(sys.stdin).get('stats',{}).get('total',0))" 2>/dev/null || echo "")" \
             "completed task(s)" "CTL-030: All completed/ tasks have null/absent stored horizon (arc-009)" \
             "" "completed-task-scan reported no completed tasks — the horizon-drift rail covered nothing"
    fi
fi

# ============================================
# CTL-029: completable-but-not-completed detection (T-2055)
# Active-side mirror of CTL-028. Catches tasks where the agent finished the
# work (all Agent ACs ticked) but never ran `--status work-completed`, so the
# task lingers in active/ instead of partial-completing to the human or
# archiving cleanly.
# ============================================
if should_run_section "compliance" || should_run_section "oe-daily"; then
    completable_warn=0
    if [ -d "$PROJECT_ROOT/.tasks/active" ]; then
        while IFS='|' read -r task_id task_status; do
            [ -z "$task_id" ] && continue
            warn "CTL-029: $task_id has all Agent ACs ticked but status='$task_status' — completable, not closed" \
                 "Agent finished the work; task is shipped-but-unclosed (active/-side mirror of CTL-028)" \
                 "Run: bin/fw task update $task_id --status work-completed"
            completable_warn=$((completable_warn + 1))
        done < <(python3 - "$PROJECT_ROOT/.tasks/active" <<'PYEOF' 2>/dev/null
import os, re, sys

active_dir = sys.argv[1]
if not os.path.isdir(active_dir):
    sys.exit(0)

PLACEHOLDER_PAT = re.compile(r"^\s*-\s*\[[ x]\]\s*\[(First|Second|Third|Fourth|Fifth)\s+criterion\]\s*$", re.IGNORECASE)
AC_PAT = re.compile(r"^\s*-\s*\[([ x])\]")

for fname in sorted(os.listdir(active_dir)):
    if not fname.endswith(".md") or not fname.startswith("T-"):
        continue
    fpath = os.path.join(active_dir, fname)
    try:
        with open(fpath, encoding="utf-8") as fh:
            text = fh.read()
    except OSError:
        continue

    fm_match = re.match(r"^---\n(.*?)\n---\n", text, re.DOTALL)
    if not fm_match:
        continue
    fm = fm_match.group(1)
    task_id_m = re.search(r"^id:\s*(T-\d+)", fm, re.MULTILINE)
    status_m = re.search(r"^status:\s*(\S+)", fm, re.MULTILINE)
    if not task_id_m or not status_m:
        continue
    task_id = task_id_m.group(1)
    status = status_m.group(1).strip()
    if status not in ("started-work", "issues"):
        continue

    body = text[fm_match.end():]
    ac_start = re.search(r"^## Acceptance Criteria\s*$", body, re.MULTILINE)
    if not ac_start:
        continue
    after_ac = body[ac_start.end():]
    next_h2 = re.search(r"^## ", after_ac, re.MULTILINE)
    ac_block = after_ac[: next_h2.start()] if next_h2 else after_ac

    # Strip HTML comment blocks before scanning (template examples live there)
    ac_block = re.sub(r"<!--.*?-->", "", ac_block, flags=re.DOTALL)

    # Prefer ### Agent sub-section if present; else use whole AC block
    agent_h = re.search(r"^### Agent\s*$", ac_block, re.MULTILINE)
    if agent_h:
        rest = ac_block[agent_h.end():]
        next_h3 = re.search(r"^### |^## ", rest, re.MULTILINE)
        scan = rest[: next_h3.start()] if next_h3 else rest
    else:
        scan = ac_block

    ticked = 0
    unticked = 0
    real_ac_count = 0
    for line in scan.splitlines():
        m = AC_PAT.match(line)
        if not m:
            continue
        if PLACEHOLDER_PAT.match(line):
            continue
        real_ac_count += 1
        if m.group(1) == "x":
            ticked += 1
        else:
            unticked += 1

    if real_ac_count == 0:
        continue
    if unticked == 0 and ticked > 0:
        print(f"{task_id}|{status}")
PYEOF
)
    fi
    if [ "$completable_warn" -eq 0 ]; then
        pass_over "$(find "$PROJECT_ROOT/.tasks/active" -maxdepth 1 -name 'T-*.md' -type f 2>/dev/null | wc -l)" \
             "active task(s)" "CTL-029: No completable-but-not-completed active tasks" \
             "" ".tasks/active/ holds no task files — the completability scan had nothing to consider"
    fi
fi

# ============================================
# CTL-012: AC-drift detection (T-955, AC-side twin of CTL-028)
# Originally lived inside the oe-daily block (T-955); promoted by T-1883 to
# fire on `compliance || oe-daily` so the pre-push audit catches completed
# tasks with unchecked Agent ACs BEFORE the drift ships. Same detection-window
# class as CTL-028 (was: up to 24h via oe-daily cron); same prevention class
# (L-390 meta-lesson extended to the symmetric twin).
# ============================================
if should_run_section "compliance" || should_run_section "oe-daily"; then
    ac_fail=0
    if [ -n "$COMPLETED_SCAN" ]; then
        # T-2202: 3-class taxonomy.
        # - class=drift           → genuine CTL-012 (real outstanding AC)
        # - class=missing-decide  → CTL-012-MISSING-DECIDE (inception task flipped
        #                            to work-completed without running
        #                            `fw inception decide`; auto-tick never ran)
        # Prose-DEFERRED scope-cut markers are filtered upstream in the scanner.
        while IFS='|' read -r ac_class task_id ac_line; do
            [ -z "$task_id" ] && continue
            case "$ac_class" in
                missing-decide)
                    warn "CTL-012-MISSING-DECIDE: Inception task $task_id flipped without decide ceremony" \
                         "$ac_line" \
                         "Auto-tick markers present but ## Decision section empty — run: fw inception decide $task_id go|no-go|defer --rationale '...' OR backfill the Decision section manually then tick the auto-tick ACs"
                    ;;
                *)
                    warn "CTL-012: Completed task $task_id has unchecked AC" \
                         "$ac_line" \
                         "Review task completion — AC gate may have been bypassed"
                    ;;
            esac
            ac_fail=$((ac_fail + 1))
        done < <(echo "$COMPLETED_SCAN" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for item in data.get('unchecked_ac', []):
    cls = item.get('class', 'drift')
    print(f\"{cls}|{item['id']}|{item['line']}\")
" 2>/dev/null)
    fi
    if [ "$ac_fail" -eq 0 ]; then
        completed_count=$(echo "$COMPLETED_SCAN" | python3 -c "import sys,json; print(json.load(sys.stdin).get('stats',{}).get('total',0))" 2>/dev/null || echo "")
        pass_over "$completed_count" "completed task(s)" "CTL-012: All completed tasks have checked ACs" \
             "" "completed-task-scan reported no completed tasks — the AC-coverage claim covered nothing"
    fi
fi

# ============================================
# DISCOVERY: Omission detection (T-239)
# D1 (episodic quality decay), D2 (human review queue aging),
# D8 (handover quality decay)
# ============================================
if should_run_section "discovery"; then
echo "=== DISCOVERY: OMISSION DETECTION ==="

# D1: Episodic Quality Decay (Score 25)
# Scan episodic files for [TODO] placeholders
ep_dir="$CONTEXT_DIR/episodic"
if [ -d "$ep_dir" ]; then
    d1_total=0
    d1_todo=0
    shopt -s nullglob
    for ep_file in "$ep_dir"/T-*.yaml; do
        [ -f "$ep_file" ] || continue
        [ "$(basename "$ep_file")" = "TEMPLATE.yaml" ] && continue
        d1_total=$((d1_total + 1))
        if grep -qE '^\s*#?\s*\[TODO|: "\[TODO|^- "\[TODO' "$ep_file" 2>/dev/null; then
            d1_todo=$((d1_todo + 1))
        fi
    done
    shopt -u nullglob

    if [ "$d1_total" -gt 0 ]; then
        d1_pct=$((d1_todo * 100 / d1_total))
        if [ "$d1_pct" -gt 50 ]; then
            fail "D1: Episodic quality — $d1_pct% have [TODO] placeholders ($d1_todo/$d1_total)" \
                 "More than half of episodic summaries are unfilled" \
                 "Enrich episodics: fw context generate-episodic T-XXX"
        elif [ "$d1_pct" -gt 20 ]; then
            warn "D1: Episodic quality — $d1_pct% have [TODO] placeholders ($d1_todo/$d1_total)" \
                 "$d1_todo episodic summaries need enrichment" \
                 "Enrich episodics: fw context generate-episodic T-XXX"
        else
            pass "D1: Episodic quality — $d1_pct% [TODO] ($d1_todo/$d1_total)"
        fi
    else
        pass "D1: No episodic files to check"
    fi
else
    pass "D1: No episodic directory"
fi

# D2: Human Review Queue Aging (Score 20) (T-955: uses single-pass scan)
# T-373: Tasks awaiting human review are NORMAL. Only escalate when forgotten (>30 days).
d2_info=0
d2_warn=0
d2_fail=0
d2_details=""
if [ -n "$ACTIVE_SCAN" ]; then
    while IFS='|' read -r t_id age_hours age_days; do
        [ -z "$t_id" ] && continue
        if [ "$age_hours" -ge 720 ]; then
            d2_fail=$((d2_fail + 1))
            d2_details="$d2_details $t_id(${age_days}d)"
        elif [ "$age_hours" -ge 336 ]; then
            d2_warn=$((d2_warn + 1))
            d2_details="$d2_details $t_id(${age_days}d)"
        else
            d2_info=$((d2_info + 1))
        fi
    done < <(echo "$ACTIVE_SCAN" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for item in data['review_queue']['tasks']:
    print(f\"{item['id']}|{item['age_hours']}|{item['age_days']}\")
" 2>/dev/null)
fi

# shellcheck disable=SC2034 # d2_total available for debug/summary
d2_total=$((d2_info + d2_warn + d2_fail))
if [ "$d2_fail" -gt 0 ]; then
    fail "D2: Human review queue — $d2_fail task(s) waiting >30d:$d2_details" \
         "Tasks may be forgotten" \
         "Review with: fw task verify (lists unchecked Human ACs)"
elif [ "$d2_warn" -gt 0 ]; then
    warn "D2: Human review queue — $d2_warn task(s) waiting >14d:$d2_details" \
         "Aging review items" \
         "Review with: fw task verify"
elif [ "$d2_info" -gt 0 ]; then
    pass "D2: Human review queue — $d2_info task(s) awaiting human action (normal)"
else
    pass "D2: Human review queue — no pending items"
fi

# D8: Handover Quality Decay (Score 20)
# Scan LATEST.md for [TODO] strings + check archive for TODO rot (T-393)
HANDOVER_LATEST="$CONTEXT_DIR/handovers/LATEST.md"
if [ -f "$HANDOVER_LATEST" ]; then
    d8_todos=$(grep -c '\[TODO' "$HANDOVER_LATEST" 2>/dev/null || true)
    d8_todos=$(echo "$d8_todos" | tr -d '[:space:]')

    if [ "$d8_todos" -gt 3 ]; then
        fail "D8: Handover quality — LATEST.md has $d8_todos [TODO] sections" \
             "Handover is a stale skeleton" \
             "Fill handover: edit .context/handovers/LATEST.md or run fw handover"
    elif [ "$d8_todos" -gt 0 ]; then
        warn "D8: Handover quality — LATEST.md has $d8_todos [TODO] section(s)" \
             "Some handover sections are unfilled" \
             "Fill remaining [TODO] sections in LATEST.md"
    else
        pass "D8: Handover quality — no [TODO] in LATEST.md"
    fi

    # D8b: Check last 10 handovers for TODO rot (archive check, T-393)
    d8b_stale=0
    d8b_checked=0
    while IFS= read -r hf; do
        [ -n "$hf" ] || continue
        d8b_checked=$((d8b_checked + 1))
        hf_todos=$(grep -c '\[TODO' "$hf" 2>/dev/null || true)
        hf_todos=$(echo "$hf_todos" | tr -d '[:space:]')
        [ "${hf_todos:-0}" -gt 3 ] && d8b_stale=$((d8b_stale + 1))
    done < <(find "$CONTEXT_DIR/handovers" -maxdepth 1 -name 'S-*.md' -type f -print0 2>/dev/null | xargs -r -0 ls -t 2>/dev/null | head -10)
    if [ "$d8b_stale" -gt 5 ]; then
        fail "D8b: Handover archive rot — $d8b_stale/$d8b_checked recent handovers have unfilled [TODO]s" \
             "Auto-generated handovers are not being filled" \
             "Clean stale handovers or fix template to reduce [TODO] generation"
    elif [ "$d8b_stale" -gt 2 ]; then
        warn "D8b: Handover archive — $d8b_stale/$d8b_checked recent handovers have [TODO]s" \
             "Some auto-generated handovers were not filled" \
             "Review and fill recent handovers"
    elif [ "$d8b_checked" -gt 0 ]; then
        pass "D8b: Handover archive — $d8b_stale/$d8b_checked recent handovers have [TODO]s"
    fi
else
    grace_warn "D8: No LATEST.md handover file found" \
         "Missing handover file" \
         "Run: fw handover"
fi

# D10: Decision-Without-Dialogue (Score 15, T-248)
# Tasks with owner:human + inception/specification completed without human AC checks
d10_result=$(python3 << 'D10EOF'
import yaml, glob, os, re

PROJECT_ROOT = os.environ.get("PROJECT_ROOT", ".")
TASKS_DIR = os.path.join(PROJECT_ROOT, ".tasks", "completed")
from datetime import datetime, timedelta, timezone
cutoff = datetime.now(timezone.utc) - timedelta(days=30)

def parse_frontmatter(path):
    try:
        content = open(path).read()
        m = re.match(r'^---\n(.*?)\n---', content, re.DOTALL)
        if m:
            return yaml.safe_load(m.group(1)) or {}
    except Exception:
        pass
    return {}

def parse_ts(s):
    if not s or s == "null":
        return None
    try:
        ts = datetime.fromisoformat(str(s).replace("Z", "+00:00"))
        if ts.tzinfo is None:
            ts = ts.replace(tzinfo=timezone.utc)
        return ts
    except (ValueError, TypeError):
        return None

flagged = []
for f in glob.glob(os.path.join(TASKS_DIR, "T-*.md")):
    fm = parse_frontmatter(f)
    finished = parse_ts(fm.get("date_finished"))
    if not finished or finished < cutoff:
        continue
    owner = fm.get("owner", "")
    wtype = fm.get("workflow_type", "")
    if owner != "human" or wtype not in ("inception", "specification"):
        continue
    # Check if any Human AC section exists and has unchecked boxes
    content = open(f).read()
    # Look for ### Human section with all boxes checked
    human_section = re.search(r'### Human\n(.*?)(?=\n##|\Z)', content, re.DOTALL)
    if not human_section:
        continue  # no human ACs — fine
    human_text = human_section.group(1)
    # T-1889: strip HTML comment blocks before counting — template stubs include
    # example `- [ ] [REVIEW] ...` lines inside <!-- ... --> that previously
    # produced false-positive "Human ACs exist but none checked" flags
    # (origin: T-1455 false-positive during arc-grooming review). Same canonical
    # strip pattern as lib/inception.sh:517.
    human_text = re.sub(r'<!--.*?-->', '', human_text, flags=re.DOTALL)
    checked = human_text.count("[x]")
    unchecked = human_text.count("[ ]")
    if unchecked > 0 and checked == 0:
        # Human ACs exist but none checked — decision without dialogue
        tid = fm.get("id", "?")
        flagged.append(tid)

if flagged:
    shown = flagged[:5]
    print(f"WARN {len(flagged)} {' '.join(shown)}")
else:
    print("PASS 0")
D10EOF
)
d10_level=$(echo "$d10_result" | awk '{print $1}')
d10_count=$(echo "$d10_result" | awk '{print $2}')
d10_detail=$(echo "$d10_result" | cut -d' ' -f3-)
case "$d10_level" in
    WARN)
        warn "D10: Decision-without-dialogue — $d10_count task(s): $d10_detail" \
             "Human-owned inception/spec tasks completed without human AC verification" \
             "Review flagged tasks — human dialogue may have been skipped"
        ;;
    PASS)
        pass "D10: Decision-without-dialogue — none detected"
        ;;
    *)
        # T-3105: the old catch-all `*)` scored an EMPTY detector result as a
        # PASS. The detector's stdout is the only channel, so a python that
        # dies produces "" -> level "" -> the success arm. Did-not-run and
        # ran-clean must not share a branch.
        warn_unenumerable "the D10 decision-without-dialogue detector" \
             "D10: Decision-without-dialogue" \
             "the detector emitted no recognised level (got: '${d10_level:-<empty>}')" \
             "Re-run the D10 python block by hand and read its stderr"
        ;;
esac

# D11: Concerns Register Staleness (Score 15, T-248/T-397)
# Concerns in "watching" status for >30 days with no recent update
GAPS_FILE="$CONTEXT_DIR/project/concerns.yaml"
[ -f "$GAPS_FILE" ] || GAPS_FILE="$CONTEXT_DIR/project/gaps.yaml"
if [ -f "$GAPS_FILE" ]; then
    d11_result=$(python3 << D11EOF
import yaml
from datetime import datetime, timedelta, timezone

cutoff = datetime.now(timezone.utc) - timedelta(days=30)
gaps_file = "$GAPS_FILE"

try:
    with open(gaps_file) as f:
        data = yaml.safe_load(f)
    gaps = data.get("gaps", []) if data else []
except Exception:
    gaps = []

stale = []
for g in gaps:
    status = g.get("status", "")
    if status != "watching":
        continue
    opened = g.get("opened", "")
    try:
        ts = datetime.fromisoformat(str(opened).replace("Z", "+00:00"))
        if ts.tzinfo is None:
            ts = ts.replace(tzinfo=timezone.utc)
        if ts < cutoff:
            stale.append(g.get("id", "?"))
    except (ValueError, TypeError):
        pass

if stale:
    print(f"WARN {len(stale)} {' '.join(stale)}")
else:
    print("PASS 0")
D11EOF
)
    d11_level=$(echo "$d11_result" | awk '{print $1}')
    d11_count=$(echo "$d11_result" | awk '{print $2}')
    d11_detail=$(echo "$d11_result" | cut -d' ' -f3-)
    case "$d11_level" in
        WARN)
            warn "D11: Gap register staleness — $d11_count gap(s) watching >30d: $d11_detail" \
                 "Gaps in watching status for over 30 days" \
                 "Review: fw gaps — close or escalate stale gaps"
            ;;
        PASS)
            pass "D11: Gap register staleness — all gaps fresh"
            ;;
        *)
            # T-3105: the old catch-all `*)` scored an EMPTY detector result
            # as a PASS. The detector's stdout is the only channel, so a
            # python that dies produces "" -> level "" -> the success arm.
            # Did-not-run and ran-clean must not share a branch.
            warn_unenumerable "the D11 gap-register staleness detector" \
                 "D11: Gap register staleness" \
                 "the detector emitted no recognised level (got: '${d11_level:-<empty>}')" \
                 "Re-run the D11 python block by hand and read its stderr"
            ;;
    esac
else
    pass "D11: Gap register — no gaps file"
fi

echo ""
fi # end discovery

# ============================================
# DISCOVERY-TRENDS: Temporal trend detection (T-240)
# D4 (audit trend regression), D5 (task lifecycle anomalies),
# D3 (commit velocity anomalies), D7 (commit bunching)
# D6 (completion velocity trends), D9 (control drift), D12 (bypass growth)
# ============================================
if should_run_section "discovery-trends"; then
echo "=== DISCOVERY: TREND DETECTION ==="

# D4: Audit Trend Regression (Score 20)
# Compare 7-entry rolling average of warn+fail counts against previous 7-entry window
METRICS_HISTORY="$CONTEXT_DIR/project/metrics-history.yaml"
if [ -f "$METRICS_HISTORY" ]; then
    d4_result=$(python3 << 'D4EOF'
import yaml, sys
from pathlib import Path

mf = sys.argv[1] if len(sys.argv) > 1 else ""
try:
    with open(mf or "$METRICS_HISTORY") as f:
        data = yaml.safe_load(f)
    entries = data.get("entries", [])
except Exception:
    entries = []

if len(entries) < 3:
    print("SKIP insufficient_data")
    sys.exit(0)

# Current window (last 7 or fewer)
window = min(7, len(entries))
current = entries[-window:]
cur_wf = [e.get("warn", 0) + e.get("fail", 0) for e in current]
cur_avg = sum(cur_wf) / len(cur_wf)

# Previous window
if len(entries) > window:
    prev_end = len(entries) - window
    prev_start = max(0, prev_end - window)
    previous = entries[prev_start:prev_end]
    prev_wf = [e.get("warn", 0) + e.get("fail", 0) for e in previous]
    prev_avg = sum(prev_wf) / len(prev_wf) if prev_wf else 0

    if prev_avg > 0:
        pct_change = ((cur_avg - prev_avg) / prev_avg) * 100
    else:
        pct_change = 100 if cur_avg > 0 else 0

    # Check for consecutive fails
    fail_streak = 0
    for e in reversed(entries):
        if e.get("fail", 0) > 0:
            fail_streak += 1
        else:
            break

    if fail_streak >= 3:
        print(f"FAIL streak={fail_streak} cur_avg={cur_avg:.1f} prev_avg={prev_avg:.1f}")
    elif pct_change > 50:
        print(f"WARN pct={pct_change:.0f} cur_avg={cur_avg:.1f} prev_avg={prev_avg:.1f}")
    else:
        print(f"PASS pct={pct_change:.0f} cur_avg={cur_avg:.1f} prev_avg={prev_avg:.1f}")
else:
    print(f"PASS single_window cur_avg={cur_avg:.1f}")
D4EOF
)
    d4_level=$(echo "$d4_result" | awk '{print $1}')
    case "$d4_level" in
        FAIL)
            fail "D4: Audit trend regression — $d4_result" \
                 "Consecutive audit failures detected" \
                 "Investigate recurring failures: fw audit"
            ;;
        WARN)
            warn "D4: Audit trend regression — warn+fail avg increased >50% ($d4_result)" \
                 "Audit health trending worse" \
                 "Review recent audit findings: fw audit"
            ;;
        SKIP)
            pass "D4: Audit trend — insufficient history (<3 entries)"
            ;;
        *)
            pass "D4: Audit trend — stable ($d4_result)"
            ;;
    esac
else
    pass "D4: Audit trend — no metrics history yet"
fi

# D5: Task Lifecycle Anomalies (Score 20)
# Detect recently completed tasks with suspiciously fast cycle times (last 30 days)
# Also detect active tasks stuck >7 days without completion
# Refined in T-249: filter by workflow_type, commit count, effective cycle time
d5_result=$(python3 << 'D5EOF'
import yaml, glob, os, re, subprocess
from datetime import datetime, timedelta, timezone

PROJECT_ROOT = os.environ.get("PROJECT_ROOT", ".")
TASKS_DIR = os.path.join(PROJECT_ROOT, ".tasks")
cutoff = datetime.now(timezone.utc) - timedelta(days=30)

# Workflow types expected to complete quickly — not anomalous
FAST_TYPES = {"test", "specification", "decommission"}

anomalies = []

def parse_frontmatter(path):
    """Extract YAML frontmatter from markdown task file."""
    try:
        content = open(path).read()
        m = re.match(r'^---\n(.*?)\n---', content, re.DOTALL)
        if m:
            return yaml.safe_load(m.group(1)) or {}
    except Exception:
        pass
    return {}

def parse_ts(s):
    if not s or s == "null":
        return None
    try:
        ts = datetime.fromisoformat(str(s).replace("Z", "+00:00"))
        if ts.tzinfo is None:
            ts = ts.replace(tzinfo=timezone.utc)
        return ts
    except (ValueError, TypeError):
        return None

def count_commits(tid):
    """Count git commits referencing this task ID."""
    try:
        r = subprocess.run(
            ["git", "log", "--oneline", f"--grep={tid}:"],
            capture_output=True, text=True, timeout=5,
            cwd=PROJECT_ROOT
        )
        return len(r.stdout.strip().split('\n')) if r.stdout.strip() else 0
    except Exception:
        return -1  # unknown

# Check completed tasks for suspiciously fast cycle times
for f in glob.glob(os.path.join(TASKS_DIR, "completed", "T-*.md")):
    fm = parse_frontmatter(f)
    finished = parse_ts(fm.get("date_finished"))
    if not finished or finished < cutoff:
        continue
    created = parse_ts(fm.get("created"))
    if not created:
        continue

    cycle_min = (finished - created).total_seconds() / 60
    owner = fm.get("owner", "?")
    wtype = fm.get("workflow_type", "?")
    tid = fm.get("id", "?")
    name = str(fm.get("name", ""))

    # Only flag human-owned tasks — agent tasks completing fast is normal
    if owner != "human":
        continue

    # Filter 1: skip workflow types expected to be fast
    if wtype in FAST_TYPES:
        continue

    # Filter 2: only flag fast tasks (< 5 min)
    if cycle_min >= 5:
        continue

    # Filter 3: skip tasks with 1+ commits (proves work was captured).
    # Retroactive workflow (work first, task created+closed) produces 1 commit
    # at completion time — legitimate, not an anomaly. Real concern is 0 commits
    # AND fast cycle: work-completed without any captured artifact (T-1263).
    commits = count_commits(tid)
    if commits >= 1:
        continue

    # Filter 4: skip administrative batch-evidence/batch-tick tasks (T-1262)
    if name.startswith("Batch-evidence") or name.startswith("Batch-tick"):
        continue

    # Remaining: human task, fast, 0-1 commits, non-trivial type — flag it
    anomalies.append(f"{tid}({cycle_min:.0f}min,{owner})")

def is_partial_complete(path, fm):
    """T-100122: partial-complete (T-193) is a VALID long-lived state — a
    human-owned task whose Agent ACs are all ticked and >=1 Human AC is
    unticked is awaiting operator review (surfaced via /approvals and
    fw review-queue), not stuck. Excluding it stops D5 re-flagging the
    whole review backlog as lifecycle anomalies every day (22 of the 29
    anomalies in the origin WARN were review-queue entries)."""
    if fm.get("owner") != "human":
        return False
    try:
        content = open(path).read()
    except Exception:
        return False
    body = re.sub(r'^---\n.*?\n---', '', content, count=1, flags=re.DOTALL)
    # T-100189: headings may carry suffixes ("### Human (T-1679 split — ...)")
    # and tasks may hold multiple ### Agent sections — findall + merge, else
    # partial-completes with annotated headings re-flag as anomalies (T-1062).
    agent_blocks = re.findall(r'### Agent[^\n]*\n(.*?)(?=\n### |\n## |\Z)', body, re.DOTALL)
    human_blocks = re.findall(r'### Human[^\n]*\n(.*?)(?=\n### |\n## |\Z)', body, re.DOTALL)
    if not agent_blocks or not human_blocks:
        return False
    agent_text = "\n".join(agent_blocks)
    human_text = "\n".join(human_blocks)
    agent_ticked = len(re.findall(r'- \[x\]', agent_text, re.IGNORECASE))
    agent_unticked = len(re.findall(r'- \[ \]', agent_text))
    human_unticked = len(re.findall(r'- \[ \]', human_text))
    return agent_ticked > 0 and agent_unticked == 0 and human_unticked > 0

# Check active tasks stuck >7 days in started-work (not captured or work-completed)
for f in glob.glob(os.path.join(TASKS_DIR, "active", "T-*.md")):
    fm = parse_frontmatter(f)
    status = fm.get("status", "")
    if status not in ("started-work", "issues"):
        continue  # captured/work-completed are normal states for aging
    created = parse_ts(fm.get("created"))
    if not created:
        continue
    age_days = (datetime.now(timezone.utc) - created).days
    if age_days > 7:
        if is_partial_complete(f, fm):
            continue  # awaiting human review — tracked on /approvals, not an anomaly
        tid = fm.get("id", "?")
        anomalies.append(f"{tid}({age_days}d-active)")

if anomalies:
    # Cap output to 10 items for readability
    shown = anomalies[:10]
    extra = f" (+{len(anomalies)-10} more)" if len(anomalies) > 10 else ""
    print(f"WARN {len(anomalies)} {' '.join(shown)}{extra}")
else:
    print("PASS 0")
D5EOF
)
d5_level=$(echo "$d5_result" | awk '{print $1}')
d5_count=$(echo "$d5_result" | awk '{print $2}')
d5_detail=$(echo "$d5_result" | cut -d' ' -f3-)
case "$d5_level" in
    WARN)
        warn "D5: Task lifecycle — $d5_count anomaly(s): $d5_detail" \
             "Tasks with unusual cycle times detected" \
             "Review flagged tasks for process issues"
        ;;
    PASS)
        pass "D5: Task lifecycle — no anomalies"
        ;;
    *)
        # T-3105: the old catch-all `*)` scored an EMPTY detector result as a
        # PASS. The detector's stdout is the only channel, so a python that
        # dies produces "" -> level "" -> the success arm. Did-not-run and
        # ran-clean must not share a branch.
        warn_unenumerable "the D5 task-lifecycle detector" \
             "D5: Task lifecycle" \
             "the detector emitted no recognised level (got: '${d5_level:-<empty>}')" \
             "Re-run the D5 python block by hand and read its stderr"
        ;;
esac

# D13: Inception Limbo (Score 15, T-1490 / OBS-025)
# Inception tasks where the human decision is recorded but the workflow
# never reached completed/. Two classes — both now sweep-eligible:
#   A) status=work-completed + has Decision + Human AC unchecked
#      (T-1423 sweep ticks AC + moves to completed/ when all ACs check out)
#   B) status=started-work + has GO/NO-GO Decision + all ACs checked
#      (T-1514 sweep promotes started-work→work-completed in place, then
#       runs class A logic. Underlying root cause closed in T-1515:
#       do_inception_decide now propagates update-task.sh exit codes.)
d13_result=$(python3 << 'D13EOF'
import os, glob, re

PROJECT_ROOT = os.environ.get("PROJECT_ROOT", ".")
ACTIVE = os.path.join(PROJECT_ROOT, ".tasks", "active")

DECISION_RE = re.compile(r"^\*\*Decision\*\*:\s*(GO|NO-GO|DEFER)", re.MULTILINE)
HUMAN_HEADER_RE = re.compile(r"^### Human\b", re.MULTILINE)
NEXT_HEADER_RE = re.compile(r"^## ", re.MULTILINE)
UNCHECKED_RE = re.compile(r"^\s*- \[ \]", re.MULTILINE)

def fm_field(text, name):
    m = re.search(rf"^{name}:\s*(\S.*?)\s*$", text, re.MULTILINE)
    return m.group(1).strip() if m else ""

def section(text, header_re):
    m = header_re.search(text)
    if not m:
        return ""
    rest = text[m.end():]
    n = NEXT_HEADER_RE.search(rest)
    return rest[: n.start()] if n else rest

def count_unchecked(text, header_re):
    sec = section(text, header_re)
    return len(UNCHECKED_RE.findall(sec))

class_a = []  # work-completed but Human AC unticked
class_b = []  # started-work but all ACs ticked + decision recorded

for f in sorted(glob.glob(os.path.join(ACTIVE, "T-*.md"))):
    try:
        text = open(f).read()
    except OSError:
        continue
    if fm_field(text, "workflow_type") != "inception":
        continue
    status = fm_field(text, "status")
    if not DECISION_RE.search(text):
        continue
    tid = fm_field(text, "id")
    human_unchecked = count_unchecked(text, HUMAN_HEADER_RE)
    if status == "work-completed" and human_unchecked > 0:
        class_a.append(f"{tid}(A:{human_unchecked}hu)")
    elif status == "started-work" and human_unchecked == 0:
        class_b.append(f"{tid}(B)")

total = len(class_a) + len(class_b)
if total == 0:
    print("PASS 0")
else:
    parts = class_a + class_b
    shown = parts[:8]
    extra = f" (+{total-8} more)" if total > 8 else ""
    a_n, b_n = len(class_a), len(class_b)
    print(f"WARN {total} A={a_n}/B={b_n} {' '.join(shown)}{extra}")
D13EOF
)
d13_level=$(echo "$d13_result" | awk '{print $1}')
d13_count=$(echo "$d13_result" | awk '{print $2}')
d13_detail=$(echo "$d13_result" | cut -d' ' -f3-)
case "$d13_level" in
    WARN)
        warn "D13: Inception limbo — $d13_count task(s): $d13_detail" \
             "Decision recorded but workflow stuck in active/" \
             "Recover both classes with: bin/fw inception sweep (T-1514)"
        ;;
    PASS)
        pass "D13: Inception limbo — no stuck inceptions"
        ;;
    *)
        # T-3105: the old catch-all `*)` scored an EMPTY detector result as a
        # PASS. The detector's stdout is the only channel, so a python that
        # dies produces "" -> level "" -> the success arm. Did-not-run and
        # ran-clean must not share a branch.
        warn_unenumerable "the D13 inception-limbo detector" \
             "D13: Inception limbo" \
             "the detector emitted no recognised level (got: '${d13_level:-<empty>}')" \
             "Re-run the D13 python block by hand and read its stderr"
        ;;
esac

# D3: Commit Velocity Anomalies (Score 16)
# Compare daily commit count against 7-day moving average
d3_result=$(python3 << 'D3EOF'
import subprocess, sys
from datetime import datetime, timedelta, timezone
from collections import Counter

try:
    r = subprocess.run(
        ["git", "log", "--format=%aI", "--since=14 days ago"],
        capture_output=True, text=True, timeout=10,
    )
    if r.returncode != 0 or not r.stdout.strip():
        print("SKIP no_data")
        sys.exit(0)

    # Count commits per day
    daily = Counter()
    for line in r.stdout.strip().split("\n"):
        if not line.strip():
            continue
        try:
            dt = datetime.fromisoformat(line.strip())
            daily[dt.strftime("%Y-%m-%d")] += 1
        except (ValueError, TypeError):
            pass

    if len(daily) < 3:
        print("SKIP insufficient_days")
        sys.exit(0)

    # Sort by date
    dates = sorted(daily.keys())
    today = datetime.now().strftime("%Y-%m-%d")
    today_count = daily.get(today, 0)

    # 7-day average (excluding today)
    past_dates = [d for d in dates if d != today][-7:]
    if not past_dates:
        print(f"PASS today={today_count}")
        sys.exit(0)

    avg = sum(daily[d] for d in past_dates) / len(past_dates)

    if avg > 0:
        ratio = today_count / avg
        # T-100123: "today" is a partial day — compare the drop side against
        # the prorated expectation (avg * fraction-of-day-elapsed), not the
        # full-day average. An audit run at 01:02 with avg=55 fired WARN on
        # 5 commits (ratio 0.09) despite being ~2x ahead of pace. Spike side
        # keeps the full-day average (a spike only grows as the day goes on).
        # Skip the drop check in the first 6h — even prorated, commit
        # patterns are too lumpy for a meaningful drop signal that early.
        now = datetime.now()
        day_frac = (now.hour * 3600 + now.minute * 60 + now.second) / 86400.0
        expected = avg * day_frac
        if ratio > 2:
            print(f"WARN spike today={today_count} avg={avg:.0f} ratio={ratio:.1f}x")
        elif day_frac >= 0.25 and expected > 0 and today_count > 0 and (today_count / expected) < 0.3:
            print(f"WARN drop today={today_count} expected_by_now={expected:.0f} avg={avg:.0f} ratio={today_count / expected:.1f}x")
        else:
            print(f"PASS today={today_count} avg={avg:.0f} ratio={ratio:.1f}x")
    else:
        print(f"PASS today={today_count} avg=0")

except Exception as e:
    print(f"SKIP error={e}")
D3EOF
)
d3_level=$(echo "$d3_result" | awk '{print $1}')
case "$d3_level" in
    WARN)
        warn "D3: Commit velocity — $d3_result" \
             "Unusual commit rate detected" \
             "Check if velocity reflects budget pressure or unusual activity"
        ;;
    SKIP)
        pass "D3: Commit velocity — insufficient data"
        ;;
    *)
        pass "D3: Commit velocity — normal ($d3_result)"
        ;;
esac

# D7: Commit Bunching (Score 16)
# Detect 5+ commits within any 10-minute window in the last 24h
d7_result=$(python3 << 'D7EOF'
import subprocess, sys
from datetime import datetime, timedelta, timezone

try:
    r = subprocess.run(
        ["git", "log", "--format=%aI", "--since=24 hours ago"],
        capture_output=True, text=True, timeout=10,
    )
    if r.returncode != 0 or not r.stdout.strip():
        print("PASS no_recent_commits")
        sys.exit(0)

    timestamps = []
    for line in r.stdout.strip().split("\n"):
        if not line.strip():
            continue
        try:
            timestamps.append(datetime.fromisoformat(line.strip()))
        except (ValueError, TypeError):
            pass

    timestamps.sort()

    if len(timestamps) < 5:
        print(f"PASS {len(timestamps)}_commits_24h")
        sys.exit(0)

    # Sliding window: check every 10-min window
    bunches = 0
    for i in range(len(timestamps)):
        window_end = timestamps[i] + timedelta(minutes=10)
        count = sum(1 for t in timestamps[i:] if t <= window_end)
        if count >= 5:
            bunches += 1
            # Skip ahead to avoid counting overlapping windows
            break

    if bunches > 0:
        print(f"INFO {bunches}_bunch(es) {len(timestamps)}_commits_24h")
    else:
        print(f"PASS {len(timestamps)}_commits_24h_no_bunching")

except Exception as e:
    print(f"PASS error={e}")
D7EOF
)
d7_level=$(echo "$d7_result" | awk '{print $1}')
case "$d7_level" in
    INFO)
        # INFO level — just report, don't warn
        pass "D7: Commit bunching — detected ($d7_result)"
        ;;
    *)
        pass "D7: Commit bunching — none ($d7_result)"
        ;;
esac

# D6: Completion Velocity Trends (Score 15, T-248)
# Detect sustained drops in task completion rate (7-day rolling average)
d6_result=$(python3 << 'D6EOF'
import yaml, glob, os, re
from datetime import datetime, timedelta, timezone
from collections import Counter

PROJECT_ROOT = os.environ.get("PROJECT_ROOT", ".")
TASKS_DIR = os.path.join(PROJECT_ROOT, ".tasks", "completed")

def parse_frontmatter(path):
    try:
        content = open(path).read()
        m = re.match(r'^---\n(.*?)\n---', content, re.DOTALL)
        if m:
            return yaml.safe_load(m.group(1)) or {}
    except Exception:
        pass
    return {}

now = datetime.now(timezone.utc)
cutoff = now - timedelta(days=14)

# Count completions per day (last 14 days)
daily = Counter()
for f in glob.glob(os.path.join(TASKS_DIR, "T-*.md")):
    fm = parse_frontmatter(f)
    finished = fm.get("date_finished")
    if not finished:
        continue
    try:
        ts = datetime.fromisoformat(str(finished).replace("Z", "+00:00"))
        if ts.tzinfo is None:
            ts = ts.replace(tzinfo=timezone.utc)
        if ts >= cutoff:
            day_key = ts.strftime("%Y-%m-%d")
            daily[day_key] = daily.get(day_key, 0) + 1
    except (ValueError, TypeError):
        pass

if len(daily) < 4:
    print("PASS insufficient_data")
else:
    # Compare last 3 days vs previous 7 days
    dates = sorted(daily.keys())
    recent = [daily.get((now - timedelta(days=i)).strftime("%Y-%m-%d"), 0) for i in range(3)]
    earlier = [daily.get((now - timedelta(days=i)).strftime("%Y-%m-%d"), 0) for i in range(3, 10)]
    recent_avg = sum(recent) / max(len(recent), 1)
    earlier_avg = sum(earlier) / max(len(earlier), 1)
    if earlier_avg > 0 and recent_avg < earlier_avg * 0.3:
        print(f"WARN drop recent_avg={recent_avg:.1f} vs earlier_avg={earlier_avg:.1f}")
    else:
        print(f"PASS recent={recent_avg:.1f} earlier={earlier_avg:.1f}")
D6EOF
)
d6_level=$(echo "$d6_result" | awk '{print $1}')
case "$d6_level" in
    WARN)
        d6_detail=$(echo "$d6_result" | cut -d' ' -f2-)
        warn "D6: Completion velocity — sustained drop ($d6_detail)" \
             "Task completion rate dropped >70% vs prior week" \
             "Check for blockers or process issues slowing work"
        ;;
    *)
        pass "D6: Completion velocity — normal ($d6_result)"
        ;;
esac

# D12: Bypass Log Growth (Score 12, T-248)
# Track --no-verify usage and bypass log entries
BYPASS_LOG="$PROJECT_ROOT/.context/project/bypass-log.yaml"
if [ -f "$BYPASS_LOG" ]; then
    d12_result=$(python3 << D12EOF
import yaml
from datetime import datetime, timedelta, timezone

bypass_file = "$BYPASS_LOG"
now = datetime.now(timezone.utc)
cutoff_7d = now - timedelta(days=7)

try:
    with open(bypass_file) as f:
        data = yaml.safe_load(f)
    entries = data.get("bypasses", []) if data else []
except Exception:
    entries = []

recent = 0
for e in entries:
    ts = e.get("timestamp", "")
    try:
        dt = datetime.fromisoformat(str(ts).replace("Z", "+00:00"))
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=timezone.utc)
        if dt >= cutoff_7d:
            recent += 1
    except (ValueError, TypeError):
        pass

total = len(entries)
if recent >= 5:
    print(f"WARN {recent} recent_7d total={total}")
elif recent > 0:
    print(f"INFO {recent} recent_7d total={total}")
else:
    print(f"PASS total={total}")
D12EOF
)
    d12_level=$(echo "$d12_result" | awk '{print $1}')
    case "$d12_level" in
        WARN)
            d12_detail=$(echo "$d12_result" | cut -d' ' -f2-)
            warn "D12: Bypass log growth — $d12_detail bypasses in last 7 days" \
                 "Elevated bypass rate may indicate enforcement friction" \
                 "Review bypass reasons: fw git log --bypasses"
            ;;
        *)
            pass "D12: Bypass log — normal ($d12_result)"
            ;;
    esac
else
    pass "D12: Bypass log — no log file"
fi

# D9: Control Effectiveness Drift (Score 9, T-248)
# Detect controls that never fire or always fire across recent audits
d9_result=$(python3 << 'D9EOF'
import yaml, glob, os, re
from collections import Counter

PROJECT_ROOT = os.environ.get("PROJECT_ROOT", ".")
AUDITS_DIR = os.path.join(PROJECT_ROOT, ".context", "audits", "cron")

# Read last 10 cron audits
audit_files = sorted(glob.glob(os.path.join(AUDITS_DIR, "*.yaml")))[-10:]
if len(audit_files) < 3:
    print("PASS insufficient_audits")
else:
    # Count warn/fail per check across audits
    warn_counts = Counter()
    total_audits = len(audit_files)
    for af in audit_files:
        try:
            with open(af) as f:
                data = yaml.safe_load(f)
            checks = data.get("checks", []) if data else []
            for check in checks:
                if check.get("level") in ("warn", "fail"):
                    warn_counts[check.get("check", "?")] += 1
        except Exception:
            pass

    # Find controls that ALWAYS fire (warn/fail in every audit)
    always_fire = [k for k, v in warn_counts.items() if v >= total_audits and total_audits >= 3]
    if always_fire:
        print(f"INFO {len(always_fire)} always-fire: {' '.join(always_fire[:3])}")
    else:
        print(f"PASS {total_audits}_audits_checked")
D9EOF
)
d9_level=$(echo "$d9_result" | awk '{print $1}')
case "$d9_level" in
    INFO)
        d9_detail=$(echo "$d9_result" | cut -d' ' -f2-)
        pass "D9: Control drift — $d9_detail"
        ;;
    *)
        pass "D9: Control drift — normal ($d9_result)"
        ;;
esac

echo ""

# D14: Empty Recommendation in inception tasks (T-1497)
# Pickup-created inceptions land in the "Awaiting Decision" queue with
# HTML-comment-only Recommendation sections. The do_inception_decide gate
# (lib/inception.sh + lib/task-audit.sh:audit_inception_recommendation)
# now blocks decide-time, but capturing the pre-decide state in the audit
# trail makes the regression visible BEFORE someone tries to decide.
d14_result=$(python3 << 'D14EOF'
import os, re, glob

PROJECT_ROOT = os.environ.get("PROJECT_ROOT", ".")
ACTIVE_DIR = os.path.join(PROJECT_ROOT, ".tasks", "active")

def has_substantive_recommendation(text):
    # Locate ## Recommendation section body (until next ## heading)
    # T-1528: H2+ terminator (L-293) — prevents Updates entries with literal
    # `**Recommendation:**` text from false-positiving the substantive check.
    m = re.search(r'^## Recommendation\s*$(.*?)(?=^#{2,} |\Z)', text, re.MULTILINE | re.DOTALL)
    if not m:
        return True  # no section = different audit concern, not ours
    body = m.group(1)
    # Strip multi-line HTML comments
    body = re.sub(r'<!--.*?-->', '', body, flags=re.DOTALL)
    # T-1510: accept bulleted (`- **Recommendation:**` / `* **Recommendation:**`)
    # AND plain (`**Recommendation:**`) forms. Original \s* pattern only
    # allowed whitespace before the bold marker, so older inception tasks that
    # authored the recommendation as a list item (T-844, T-705) were
    # false-positived as empty.
    return bool(re.search(r'^\s*[-*]?\s*\*\*Recommendation:\*\*\s*\S', body, re.MULTILINE))

empty = []
for f in glob.glob(os.path.join(ACTIVE_DIR, "T-*.md")):
    try:
        with open(f) as fh:
            text = fh.read()
    except Exception:
        continue
    if "workflow_type: inception" not in text:
        continue
    # Only flag tasks where someone could try to decide (started-work or captured)
    fm = re.match(r'^---\n(.*?)\n---', text, re.DOTALL)
    if fm:
        status_m = re.search(r'^status:\s*(\S+)', fm.group(1), re.MULTILINE)
        if status_m and status_m.group(1) not in ("started-work", "captured"):
            continue
    if not has_substantive_recommendation(text):
        empty.append(os.path.basename(f).split("-")[0] + "-" + os.path.basename(f).split("-")[1])

if empty:
    # Cap output length so a long list doesn't blow up the audit yaml
    sample = " ".join(empty[:5])
    suffix = f" (+{len(empty)-5} more)" if len(empty) > 5 else ""
    print(f"WARN {len(empty)}_empty: {sample}{suffix}")
else:
    print("PASS no_empty_recommendations")
D14EOF
)
d14_level=$(echo "$d14_result" | awk '{print $1}')
case "$d14_level" in
    WARN)
        d14_detail=$(echo "$d14_result" | cut -d' ' -f2-)
        warn "D14: Empty inception Recommendation — $d14_detail" \
             "Inception tasks await decision with HTML-comment-only Recommendation" \
             "Fill ## Recommendation block with **Recommendation:** + rationale before decide"
        ;;
    *)
        pass "D14: Empty inception Recommendation — none ($d14_result)"
        ;;
esac

# D15: Inception limbo state (T-1511, OBS-025)
# Inceptions with status=started-work, owner=human, all Human ACs ticked,
# but no **Decision**: line in the body. Operator checked the AC boxes
# intending to complete, then forgot to run `fw inception decide`. The
# task stays in active/ as a ghost — D5 anomaly only fires on age, so
# the bug is invisible until tasks rot. Excludes DEFER decisions
# (intentional keep-active).
d15_result=$(python3 << 'D15EOF'
import os, re, glob
PROJECT_ROOT = os.environ.get("PROJECT_ROOT", ".")
ACTIVE_DIR = os.path.join(PROJECT_ROOT, ".tasks", "active")

def is_limbo(text):
    fm = re.match(r'^---\n(.*?)\n---', text, re.DOTALL)
    if not fm:
        return False
    front = fm.group(1)
    if "workflow_type: inception" not in front:
        return False
    status_m = re.search(r'^status:\s*(\S+)', front, re.MULTILINE)
    owner_m = re.search(r'^owner:\s*(\S+)', front, re.MULTILINE)
    if not status_m or status_m.group(1) != "started-work":
        return False
    if not owner_m or owner_m.group(1) != "human":
        return False
    # Decision check — any **Decision**: line means not in limbo
    if re.search(r'^\*\*Decision\*\*:\s*\S', text, re.MULTILINE):
        return False
    # Human ACs — find ### Human section and check for unchecked items
    human_m = re.search(r'^### Human\s*$(.*?)(?=^### |^## |\Z)', text, re.MULTILINE | re.DOTALL)
    if not human_m:
        return False  # no Human section = different shape, not our concern
    human_body = human_m.group(1)
    # Strip HTML comments so commented-out templates don't count
    human_body = re.sub(r'<!--.*?-->', '', human_body, flags=re.DOTALL)
    unchecked = len(re.findall(r'^- \[ \]', human_body, re.MULTILINE))
    checked = len(re.findall(r'^- \[x\]', human_body, re.MULTILINE | re.IGNORECASE))
    # Limbo only when there ARE Human ACs AND none are unchecked
    return checked > 0 and unchecked == 0

limbo = []
for f in glob.glob(os.path.join(ACTIVE_DIR, "T-*.md")):
    try:
        with open(f) as fh:
            text = fh.read()
    except Exception:
        continue
    if is_limbo(text):
        bn = os.path.basename(f)
        # T-XXXX-slug.md → T-XXXX
        m = re.match(r'^(T-\d+)', bn)
        if m:
            limbo.append(m.group(1))

if limbo:
    sample = " ".join(limbo[:5])
    suffix = f" (+{len(limbo)-5} more)" if len(limbo) > 5 else ""
    print(f"WARN {len(limbo)}_limbo: {sample}{suffix}")
else:
    print("PASS no_limbo")
D15EOF
)
d15_level=$(echo "$d15_result" | awk '{print $1}')
case "$d15_level" in
    WARN)
        d15_detail=$(echo "$d15_result" | cut -d' ' -f2-)
        warn "D15: Inception limbo state — $d15_detail" \
             "Inception with all Human ACs ticked but no decision recorded — operator forgot to run fw inception decide" \
             "Run: fw inception decide T-XXX go|no-go|defer --rationale '...'"
        ;;
    PASS)
        pass "D15: Inception limbo state — none ($d15_result)"
        ;;
    *)
        # T-3105: the old catch-all `*)` scored an EMPTY detector result as a
        # PASS. The detector's stdout is the only channel, so a python that
        # dies produces "" -> level "" -> the success arm. Did-not-run and
        # ran-clean must not share a branch.
        warn_unenumerable "the D15 inception-limbo-state detector" \
             "D15: Inception limbo state" \
             "the detector emitted no recognised level (got: '${d15_level:-<empty>}')" \
             "Re-run the D15 python block by hand and read its stderr"
        ;;
esac

echo ""
fi # end discovery-trends

# ============================================
# OE-WEEKLY: Controls checked once per week (T-195)
# CTL-016
# ============================================
if should_run_section "oe-weekly"; then
echo "=== OE-WEEKLY: WEEKLY CONTROL CHECKS ==="

# CTL-016 OE: Hypothesis Debugging — healing patterns resolved with mitigation
PATTERNS_FILE="$CONTEXT_DIR/project/patterns.yaml"
if [ -f "$PATTERNS_FILE" ]; then
    total_patterns=$(grep -c "^  - type:" "$PATTERNS_FILE" 2>/dev/null || true)
    total_patterns=$(echo "$total_patterns" | tr -d '[:space:]')
    with_mitigation=$(grep -c "mitigation:" "$PATTERNS_FILE" 2>/dev/null || true)
    with_mitigation=$(echo "$with_mitigation" | tr -d '[:space:]')
    if [ "$total_patterns" -gt 0 ]; then
        ratio=$(( with_mitigation * 100 / total_patterns ))
        if [ "$ratio" -ge 80 ]; then
            pass "CTL-016: ${ratio}% of failure patterns have mitigations ($with_mitigation/$total_patterns)"
        else
            warn "CTL-016: Only ${ratio}% of failure patterns have mitigations ($with_mitigation/$total_patterns)" \
                 "Failure patterns without recorded resolutions" \
                 "Run: fw healing patterns — review unmitigated patterns"
        fi
    else
        pass "CTL-016: No failure patterns recorded"
    fi
else
    pass "CTL-016: No patterns file (first run or clean project)"
fi

echo ""
fi # end oe-weekly

# ============================================
# DEPLOYMENT: Pre-deploy quality gates (T-275)
# Only runs when explicitly requested (--section deployment)
# Not included in default full audit or pre-push checks
# ============================================
if [ -n "$SECTIONS" ] && should_run_section "deployment"; then
echo "=== DEPLOYMENT CHECKS ==="

# Check active task exists (must deploy under a task)
FOCUS_FILE="$CONTEXT_DIR/working/focus.yaml"
if [ -f "$FOCUS_FILE" ]; then
    FOCUS_TASK=$(grep -E '^(task_id|current_task):' "$FOCUS_FILE" 2>/dev/null | head -1 | awk '{print $2}' | tr -d '"')
    if [ -n "$FOCUS_TASK" ] && [ "$FOCUS_TASK" != "null" ]; then
        pass "Deploy gate: Active task $FOCUS_TASK"
    else
        fail "Deploy gate: No active task — set focus before deploying" \
             "focus.yaml has no task_id" \
             "Run: fw context focus T-XXX"
    fi
else
    fail "Deploy gate: No focus file — initialize session first" \
         "$FOCUS_FILE not found" \
         "Run: fw context init && fw context focus T-XXX"
fi

# Check git is clean (no uncommitted changes to source files)
DIRTY_SRC=$(cd "$PROJECT_ROOT" && git diff --name-only HEAD -- '*.py' '*.sh' '*.yml' '*.yaml' 'Dockerfile' 2>/dev/null | wc -l | tr -d ' ')
if [ "$DIRTY_SRC" = "0" ]; then
    pass "Deploy gate: Git clean (source files)"
else
    fail "Deploy gate: $DIRTY_SRC uncommitted source file(s)" \
         "$(cd "$PROJECT_ROOT" && git diff --name-only HEAD -- '*.py' '*.sh' '*.yml' '*.yaml' 'Dockerfile' 2>/dev/null | head -3)" \
         "Run: fw git commit -m 'T-XXX: pre-deploy commit'"
fi

# Check HEAD commit has task reference (traceability)
HEAD_MSG=$(cd "$PROJECT_ROOT" && git log -1 --format='%s' 2>/dev/null)
if echo "$HEAD_MSG" | grep -qE '^T-[0-9]+:'; then
    pass "Deploy gate: HEAD commit has task reference"
else
    warn "Deploy gate: HEAD commit lacks T-XXX reference" \
         "HEAD: $HEAD_MSG" \
         "Commit with task prefix: fw git commit -m 'T-XXX: ...'"
fi

# Check deployment files exist
for deploy_file in Dockerfile deploy/docker-compose.swarm.yml deploy/traefik-routes.yml; do
    if [ -f "$PROJECT_ROOT/$deploy_file" ]; then
        pass "Deploy gate: $deploy_file exists"
    else
        fail "Deploy gate: $deploy_file missing" \
             "$deploy_file not found in project root" \
             "Run: fw deploy scaffold --app <name> --pattern swarm --port-prod <N> --port-dev <N>"
    fi
done

# Check health endpoint responds (if server is running)
# F9 (T-2445): gate the health pass on the identity-verified resolver. A bare
# `|| echo http://localhost:PORT` fallback re-points at a FOREIGN service holding
# the default port and curls its /health (any server answers 200) → false pass.
# _watchtower_url returns non-zero when no Watchtower of OURS is reachable (T-1803).
if ! _wt_url=$(_watchtower_url 2>/dev/null); then
    _wt_url=""
fi
_wt_port=$(echo "$_wt_url" | grep -oP ':\K\d+$' || echo "3000")
if [ -n "$_wt_url" ] && curl -sf --max-time 3 "${_wt_url}/health" >/dev/null 2>&1; then
    pass "Deploy gate: Health endpoint responds on :${_wt_port}"
elif curl -sf --max-time 3 http://localhost:5050/health >/dev/null 2>&1; then
    pass "Deploy gate: Health endpoint responds on :5050"
else
    warn "Deploy gate: Health endpoint not reachable" \
         "Neither :${_wt_port} nor :5050 /health responded" \
         "Start server: fw serve (or check if health endpoint exists)"
fi

echo ""
fi # end deployment

# ============================================
# ORCHESTRATOR ARC CHECKS (T-1646 — drift defense for MCP-tool task_id enforcement)
# Origin: T-1641 W10. Probes /opt/termlink, classifies MCP tools, surfaces drift.
# ============================================
if should_run_section "orchestrator"; then
echo "=== ORCHESTRATOR ARC CHECKS ==="

ORCH_SCRIPT="$FRAMEWORK_ROOT/agents/audit/orchestrator-mcp-scan.sh"
ORCH_LATEST="$CONTEXT_DIR/audits/orchestrator-LATEST.yaml"

# T-2384: precondition is existence, not +x. The script is invoked via `bash`
# (line ~4511 below), so the executable bit is never required at runtime — the
# repo convention is non-+x agent scripts run via `bash`/sourced (30+ siblings),
# and the test (test_orchestrator_mcp_classify.py) only read_text()s it. The
# prior `[ ! -x ]` check was stricter than the invocation, so it WARNed on a
# git mode of 100644 that nothing actually breaks on. Relaxing to `[ ! -f ]`
# fixes the check/invocation mismatch at the root and is recurrence-proof
# (a `chmod +x` would re-fire this WARN on the next mode-strip).
if [ ! -f "$ORCH_SCRIPT" ]; then
    warn "Orchestrator scan: $ORCH_SCRIPT not found" \
         "$ORCH_SCRIPT missing" \
         "Restore the file (invoked via 'bash', +x not required)"
elif ! [ -d "${FW_TERMLINK_REPO:-/opt/termlink}/crates/termlink-mcp/src" ] && ! command -v termlink >/dev/null 2>&1; then
    info "Orchestrator scan: skipped — TermLink repo unreachable on this host"
else
    # T-2260 / arc-010 Slice 1B: capture orchestrator exit but always continue
    # to the framework-mcp summary block below — both legs share one scan but
    # each leg has its own pass/warn/fail surface line.
    bash "$ORCH_SCRIPT" >/dev/null 2>&1
    ORCH_EXIT_CAPTURED=$?
    if [ "$ORCH_EXIT_CAPTURED" = "0" ]; then
        ORCH_STATUS=$(grep -oE '^status: [a-z]+' "$ORCH_LATEST" 2>/dev/null | awk '{print $2}')
        ORCH_GATED=$(grep -oE '^gated_current: [0-9]+' "$ORCH_LATEST" 2>/dev/null | awk '{print $2}')
        ORCH_TOTAL=$(grep -oE '^current_count: [0-9]+' "$ORCH_LATEST" 2>/dev/null | awk '{print $2}')
        pass "Orchestrator-arc MCP scan: $ORCH_STATUS — $ORCH_GATED/$ORCH_TOTAL tools gated"
    else
        if [ "$ORCH_EXIT_CAPTURED" = "1" ]; then
            ORCH_WARNS=$(awk '/^warnings:/{flag=1; next} /^errors:/{flag=0} flag' "$ORCH_LATEST" 2>/dev/null | head -1 | sed 's/^- //')
            # T-1649: tag-format drift uses a different remediation path than baseline drift.
            if echo "$ORCH_WARNS" | grep -q "TAG-FORMAT-DRIFT"; then
                warn "Orchestrator-arc tag-format drift: live sessions carry non-canonical prefixes" \
                     "${ORCH_WARNS:-see $ORCH_LATEST}" \
                     "Fix at source: update spawn callers (see /orchestrator) or add validator (T-1649 cross-repo half)"
            else
                warn "Orchestrator-arc MCP scan: drift detected" \
                     "${ORCH_WARNS:-see $ORCH_LATEST}" \
                     "Update .context/audits/orchestrator-mcp-baseline.yaml or investigate ratchet/new-tool"
            fi
        elif [ "$ORCH_EXIT_CAPTURED" = "2" ]; then
            ORCH_ERRS=$(awk '/^errors:/{flag=1; next} /^[a-z]/{flag=0} flag' "$ORCH_LATEST" 2>/dev/null | head -1 | sed 's/^- //')
            fail "Orchestrator-arc MCP scan: regression — gated tool lost its check_task_governance" \
                 "${ORCH_ERRS:-see $ORCH_LATEST}" \
                 "Restore the gate or update baseline if removal was intentional (commit body must explain)"
        elif [ "$ORCH_EXIT_CAPTURED" = "3" ]; then
            # T-2647 (832 G-001/F2): first-run condition — baseline state never
            # established on this install (fresh consumer; .context is excluded
            # from the vendor payload by design). INFO, not FAIL: nothing to
            # diff against is not a regression.
            info "Orchestrator-arc MCP scan: no baseline on this install yet — drift scan skipped (seed from a framework checkout's .context/audits/ to enable)"
        else
            warn "Orchestrator-arc MCP scan: probe failed (exit $ORCH_EXIT_CAPTURED)" \
                 "Cannot reach /opt/termlink via direct read or termlink interact" \
                 "Check FW_TERMLINK_REPO and TermLink session availability"
        fi
    fi

    # T-2260 / arc-010 Slice 1B (OR-2): surface the parallel framework-mcp leg
    # status. Always emitted (independent of orchestrator-leg exit code) — both
    # legs share one scan but each has its own pass/warn/fail surface line.
    if [ -f "$ORCH_LATEST" ]; then
        FW_MCP_LINE=$(python3 -c "
import yaml
d = yaml.safe_load(open('$ORCH_LATEST'))
ff = d.get('framework_findings') or {}
s = ff.get('status', 'missing')
gc = ff.get('gated_current', 0)
cc = ff.get('current_count', 0)
mp = 'present' if ff.get('manifest_present') else 'absent'
print(f'{s}|{gc}|{cc}|{mp}')
" 2>/dev/null)
        if [ -n "$FW_MCP_LINE" ]; then
            FW_MCP_STATUS=$(echo "$FW_MCP_LINE" | awk -F'|' '{print $1}')
            FW_MCP_GATED=$(echo "$FW_MCP_LINE" | awk -F'|' '{print $2}')
            FW_MCP_TOTAL=$(echo "$FW_MCP_LINE" | awk -F'|' '{print $3}')
            FW_MCP_MANIFEST_STATE=$(echo "$FW_MCP_LINE" | awk -F'|' '{print $4}')
            case "$FW_MCP_STATUS" in
                pass) pass "framework-mcp scan: PASS — $FW_MCP_GATED/$FW_MCP_TOTAL tools gated (manifest $FW_MCP_MANIFEST_STATE)" ;;
                warn) warn "framework-mcp scan: WARN — $FW_MCP_GATED/$FW_MCP_TOTAL tools gated (manifest $FW_MCP_MANIFEST_STATE)" \
                          "see framework_findings.warnings in $ORCH_LATEST" \
                          "Update .context/audits/framework-mcp-baseline.yaml or classify the new tool" ;;
                fail) fail "framework-mcp scan: FAIL — gated tool lost its governance call" \
                          "see framework_findings.errors in $ORCH_LATEST" \
                          "Restore the gate or update baseline if removal was intentional" ;;
                *)    info "framework-mcp scan: status=$FW_MCP_STATUS (unexpected)" ;;
            esac
        fi
    fi
fi

# T-2296 / arc-010: MCP manifest drift FAIL (daily-cron backstop to T-2294 pre-push gate).
# Routes `fw mcp check` exit codes into audit verdict:
#   0 → pass  (manifest in sync with tool-set.yaml)
#   1 → fail  (drift — operator/agent forgot `fw mcp emit-manifest` after edit)
#   2 → info  (absent — fresh project hasn't emitted yet; not a failure)
# Sibling to the existing framework-mcp scan block above; that one surfaces
# scan-vs-baseline drift, this one surfaces emitter-vs-source drift.
if [ -x "$PROJECT_ROOT/bin/fw" ] && [ -f "$PROJECT_ROOT/agents/mcp/manifest.py" ]; then
    MCP_DRIFT_OUT=$("$PROJECT_ROOT/bin/fw" mcp check 2>&1)
    MCP_DRIFT_EXIT=$?
    case "$MCP_DRIFT_EXIT" in
        0) pass "framework-mcp manifest: PASS — in sync with tool-set.yaml" ;;
        1) fail "framework-mcp manifest: FAIL — framework-mcp-manifest.json out of sync with tool-set.yaml" \
                "$(echo "$MCP_DRIFT_OUT" | head -1)" \
                "Run: bin/fw mcp emit-manifest && git add agents/mcp/framework-mcp-manifest.json && commit" ;;
        2) info "framework-mcp manifest: ABSENT — run \`bin/fw mcp emit-manifest\` (fresh project)" ;;
        *) info "framework-mcp manifest: status=$MCP_DRIFT_EXIT (unexpected)" ;;
    esac
fi

# T-1798: Workflow → dispatcher coverage check.
# T-1776 surfaced default.yaml → worker_kind: TermLink at *runtime*
# (NotImplementedError). The structural prevention is to flag the gap at
# audit time. lib/workflow_coverage.py cross-references each workflow's
# declared worker_kind against lib/spawn._DISPATCHERS.keys().
COVERAGE_HELPER="$FRAMEWORK_ROOT/lib/workflow_coverage.py"
if [ -f "$COVERAGE_HELPER" ]; then
    # T-1803: extend with recency + stale flag. Exit codes:
    #   0 = PASS (ok and not warn)
    #   1 = FAIL (not ok — unroutable or missing-provider)
    #   2 = WARN (ok but stale)
    COVERAGE_OUT=$(PROJECT_ROOT="$PROJECT_ROOT" python3 -c "
import sys
sys.path.insert(0, '$FRAMEWORK_ROOT/lib')
import workflow_coverage
r = workflow_coverage.check_workflow_dispatcher_coverage()
r = workflow_coverage.enrich_with_dispatch_recency(r)
r = workflow_coverage.flag_stale_workflows(r)
print(workflow_coverage.format_audit_line(r))
if not r['ok']:
    sys.exit(1)
if r.get('warn'):
    sys.exit(2)
sys.exit(0)
" 2>&1)
    COVERAGE_RC=$?
    case "$COVERAGE_RC" in
        0)
            pass "Workflow dispatcher coverage: $COVERAGE_OUT"
            ;;
        2)
            warn "Workflow dispatcher coverage: $COVERAGE_OUT" \
                 "Workflows declared but not recently dispatched — consider deprecating" \
                 "Run: bin/fw resolver workflows ; review which workflows are still relevant"
            ;;
        *)
            fail "Workflow dispatcher coverage: $COVERAGE_OUT" \
                 "Workflow declares worker_kind without a spawn handler — runtime NotImplementedError trap" \
                 "Either add a handler to lib/spawn._DISPATCHERS, or change the workflow's worker_kind to a routable one (pi, ollama-loop, TermLink)"
            ;;
    esac
fi

echo ""
fi # end orchestrator

# ============================================
# ARC-COMPLETION CHECK (T-1656 / G-062 mechanism #2)
# Detect arcs whose constituent tasks are mostly completed but where the arc
# itself was never explicitly closed. Catches the "shipped without three-question
# check" failure mode codified in CLAUDE.md §Arc Completion Discipline.
# ============================================
if should_run_section "arc-completion" || should_run_section "oe-daily"; then
echo "=== ARC-COMPLETION CHECKS ==="

ARC_DIR="$CONTEXT_DIR/arcs"
if [ ! -d "$ARC_DIR" ] || ! ls "$ARC_DIR"/*.yaml >/dev/null 2>&1; then
    info "Arc registry empty — no arcs to evaluate"
else
    threshold="${FW_ARC_COMPLETION_THRESHOLD:-0.80}"
    for arc_yaml in "$ARC_DIR"/*.yaml; do
        # Parse arc fields (id, status, constituent_tasks).
        # Use python to avoid yaml-library coupling — simple line scan suffices.
        eval "$(python3 - "$arc_yaml" "$PROJECT_ROOT" <<'PY'
import re, sys, os, glob
text = open(sys.argv[1]).read()
project_root = sys.argv[2]
def grab(field, default=""):
    m = re.search(rf'^{field}:\s*(.*?)$', text, re.MULTILINE)
    return m.group(1).strip() if m else default
arc_id = grab("id")
# T-1848: dual identity. `id:` is now arc-NNN (immutable); `slug:` (or filename
# stem) is the tag namespace. Tasks tagged `arc:dispatch-safety` won't match
# `arc:arc-001`. Audit must scan by slug.
arc_slug = grab("slug") or os.path.basename(sys.argv[1]).replace(".yaml", "")
status = grab("status")
ct_line = grab("constituent_tasks", "[]")
m = re.match(r'\[(.*?)\]', ct_line)
items = []
if m and m.group(1).strip():
    items = [s.strip().strip('"').strip("'") for s in m.group(1).split(",") if s.strip()]
# Tag-based fallback (T-1813): when constituent_tasks is empty, scan .tasks/ for
# tasks tagged arc:<slug>. Mirrors lib/arc.sh:_arc_tasks_with_tag.
# T-1875 (T-NEW-11): extended to union with arc_id: frontmatter scan — the
# canonical source-of-truth field introduced in T-1849 and populated by the
# T-1850 migration. Without this union, audit was blind to 163 task-arc
# relationships across 5 arcs after migration. Mirrors lib/arc.sh:_arc_tasks_for.
if not items and arc_slug:
    tag_pattern = f"arc:{arc_slug}"
    # arc_id may be either slug form (`arc-grooming`) or arc-NNN form (`arc-005`).
    arc_id_re = re.compile(
        rf'^\s*arc_id:\s*["\']?({re.escape(arc_slug)}|{re.escape(arc_id)})["\']?\s*$',
        re.MULTILINE,
    )
    seen = set()
    for d in ("active", "completed"):
        for f in glob.glob(os.path.join(project_root, ".tasks", d, "T-*.md")):
            try:
                tt = open(f).read()
            except OSError:
                continue
            matched = False
            tags_m = re.search(r'^tags:\s*(.*?)$', tt, re.MULTILINE)
            if tags_m and tag_pattern in tags_m.group(1):
                matched = True
            if not matched and arc_id_re.search(tt):
                matched = True
            if matched:
                id_m = re.search(r'^id:\s*(T-\d+)', tt, re.MULTILINE)
                if id_m:
                    seen.add(id_m.group(1))
    items = sorted(seen)
print(f'ARC_ID={arc_id!r}')
print(f'ARC_STATUS={status!r}')
print(f'ARC_TASKS=({" ".join(items)})')
PY
)"
        # Skip closed arcs and empty arcs.
        if [ "$ARC_STATUS" != "in-progress" ]; then continue; fi
        total="${#ARC_TASKS[@]}"
        if [ "$total" -eq 0 ]; then continue; fi

        # Count tasks at status work-completed across active+completed dirs.
        completed=0
        for tid in "${ARC_TASKS[@]}"; do
            tf=$({ ls "$PROJECT_ROOT"/.tasks/{active,completed}/"$tid"-*.md 2>/dev/null || true; } | head -1)
            if [ -n "$tf" ] && grep -qE "^status:[[:space:]]*work-completed" "$tf"; then
                completed=$((completed+1))
            fi
        done

        # Compute ratio in shell using awk (portable; no bc dependency).
        ratio=$(awk -v c="$completed" -v t="$total" 'BEGIN { printf "%.4f", c/t }')
        # Compare ratio >= threshold (awk again).
        ge=$(awk -v r="$ratio" -v th="$threshold" 'BEGIN { print (r+0 >= th+0) ? "1" : "0" }')

        if [ "$ge" = "1" ]; then
            warn "Arc '${ARC_ID}': ${completed}/${total} tasks completed (${ratio}) but arc still in-progress" \
                 "Threshold ${threshold} reached — code-complete without explicit closure (G-062 signature)" \
                 "Capture wire-evidence of the arc's headline_mechanic firing, then: fw arc close ${ARC_ID} --demo <path|url> --decision \"...\""
        else
            pass "Arc '${ARC_ID}': ${completed}/${total} (${ratio}) — below threshold ${threshold}, no closure pressure"
        fi
    done
fi

echo ""
fi # end arc-completion

# ============================================
# SUMMARY (always runs)
# ============================================
echo "=== SUMMARY ==="
echo -e "${GREEN}Pass:${NC} $PASS_COUNT"
echo -e "${YELLOW}Warn:${NC} $WARN_COUNT"
echo -e "${RED}Fail:${NC} $FAIL_COUNT"
echo ""

# Deduplicate and show priority actions
if [ ${#PRIORITY_ACTIONS[@]} -gt 0 ]; then
    echo "=== PRIORITY ACTIONS ==="
    printf '%s\n' "${PRIORITY_ACTIONS[@]}" | sort -u | head -5 | nl
fi

# ============================================
# YAML OUTPUT (always runs)
# ============================================

# Determine output directory and filename
EFFECTIVE_OUTPUT_DIR="${OUTPUT_DIR:-$AUDITS_DIR}"
mkdir -p "$EFFECTIVE_OUTPUT_DIR"

# Cron audits use datetime filenames (multiple per day); manual audits use date
if [ -n "$OUTPUT_DIR" ]; then
    AUDIT_FILE="$EFFECTIVE_OUTPUT_DIR/$AUDIT_DATETIME.yaml"
else
    AUDIT_FILE="$EFFECTIVE_OUTPUT_DIR/$AUDIT_DATE.yaml"
fi

# Build YAML content
{
    echo "# Audit Results - $AUDIT_DATETIME"
    echo "timestamp: $AUDIT_TIMESTAMP"
    [ -n "$SECTIONS" ] && echo "sections: \"$SECTIONS\""
    echo "summary:"
    echo "  pass: $PASS_COUNT"
    echo "  warn: $WARN_COUNT"
    echo "  fail: $FAIL_COUNT"
    echo "findings:"
    for finding in "${FINDINGS[@]}"; do
        level=$(echo "$finding" | cut -d'|' -f1)
        check=$(echo "$finding" | cut -d'|' -f2)
        mitigation=$(echo "$finding" | cut -d'|' -f3)
        # T-687: Properly escape YAML strings — replace " with \" inside quoted values
        check="${check//\\/\\\\}"   # escape backslashes first
        check="${check//\"/\\\"}"   # then escape quotes
        mitigation="${mitigation//\\/\\\\}"
        mitigation="${mitigation//\"/\\\"}"
        echo "  - level: $level"
        echo "    check: \"$check\""
        if [ -n "$mitigation" ]; then
            echo "    mitigation: \"$mitigation\""
        fi
    done
} > "$AUDIT_FILE"

# Update LATEST-CRON symlink (only in custom output dirs, not default audits)
if [ -n "$OUTPUT_DIR" ]; then
    ln -sf "$(basename "$AUDIT_FILE")" "$EFFECTIVE_OUTPUT_DIR/LATEST-CRON.yaml" 2>/dev/null || true
fi

# Extract discovery findings (D1-D8) to LATEST.yaml
if should_run_section "discovery" || should_run_section "discovery-trends"; then
    DISC_DIR="$AUDITS_DIR/discoveries"
    mkdir -p "$DISC_DIR"
    DISC_PASS=0; DISC_WARN=0; DISC_FAIL=0; DISC_TOTAL=0
    DISC_FINDINGS=""
    for finding in "${FINDINGS[@]}"; do
        level=$(echo "$finding" | cut -d'|' -f1)
        check=$(echo "$finding" | cut -d'|' -f2)
        mitigation=$(echo "$finding" | cut -d'|' -f3)
        # Match D1-D9 prefix
        if echo "$check" | grep -qE '^D[0-9]+:'; then
            disc_id=$(echo "$check" | grep -oE '^D[0-9]+')
            DISC_TOTAL=$((DISC_TOTAL + 1))
            case "$level" in
                PASS) DISC_PASS=$((DISC_PASS + 1)) ;;
                WARN) DISC_WARN=$((DISC_WARN + 1)) ;;
                FAIL) DISC_FAIL=$((DISC_FAIL + 1)) ;;
            esac
            DISC_FINDINGS="${DISC_FINDINGS}  - id: $disc_id
    level: $level
    check: \"${check//\"/\\\"}\"
"
            if [ -n "$mitigation" ]; then
                DISC_FINDINGS="${DISC_FINDINGS}    mitigation: \"${mitigation//\"/\\\"}\"
"
            fi
        fi
    done
    if [ "$DISC_TOTAL" -gt 0 ]; then
        cat > "$DISC_DIR/LATEST.yaml" << DISCEOF
timestamp: $AUDIT_TIMESTAMP
findings:
$DISC_FINDINGS
summary:
  pass: $DISC_PASS
  warn: $DISC_WARN
  fail: $DISC_FAIL
  total: $DISC_TOTAL
DISCEOF
    fi
fi

# Trend detection: Compare with previous audits
echo ""
echo "=== TREND ANALYSIS ==="

# Get previous audit files (excluding today)
shopt -s nullglob
previous_audits=("$AUDITS_DIR"/*.yaml)
shopt -u nullglob

# T-1394: rolling window — exclude audits older than FW_AUDIT_TREND_WINDOW_DAYS
# (default 14). Without this, resolved issues stay flagged forever (e.g.
# "Uncommitted changes present (39 times)" persists after T-1392 fixed it).
TREND_WINDOW_DAYS="${FW_AUDIT_TREND_WINDOW_DAYS:-14}"
TREND_WINDOW_CUTOFF=$(date -d "${TREND_WINDOW_DAYS} days ago" +%Y-%m-%d 2>/dev/null \
    || date -v-${TREND_WINDOW_DAYS}d +%Y-%m-%d 2>/dev/null \
    || echo "1970-01-01")

# Filter to only files before today and within window
past_audits=()
for f in "${previous_audits[@]}"; do
    fname=$(basename "$f" .yaml)
    # Skip cron/, discoveries/ subdir entries — only date-named files
    case "$fname" in
        [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]) ;;
        [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]-*) fname="${fname:0:10}" ;;
        *) continue ;;
    esac
    if [ "$fname" = "$AUDIT_DATE" ]; then continue; fi
    # Lexicographic compare works for YYYY-MM-DD
    if [[ "$fname" < "$TREND_WINDOW_CUTOFF" ]]; then continue; fi
    [ -f "$f" ] && past_audits+=("$f")
done

if [ ${#past_audits[@]} -eq 0 ]; then
    echo "First audit recorded. Trends will appear after multiple audits."
else
    # Count how many times each warning/failure has appeared (temp file, POSIX-safe — no declare -A)
    ISSUE_COUNTS_FILE=$(mktemp)

    for audit_file in "${past_audits[@]}"; do
        while IFS= read -r line; do
            if [[ "$line" =~ ^[[:space:]]+check:[[:space:]]* ]]; then
                check_name=$(echo "$line" | sed 's/.*check: "//' | sed 's/"$//')
                echo "$check_name" >> "$ISSUE_COUNTS_FILE"
            fi
        done < <(grep -A1 "level: WARN\|level: FAIL" "$audit_file" 2>/dev/null)
    done

    # Find repeated issues (appeared 3+ times)
    repeated_issues=()
    if [ -s "$ISSUE_COUNTS_FILE" ]; then
        while IFS= read -r count_line; do
            count=$(echo "$count_line" | awk '{print $1}')
            check=$(echo "$count_line" | cut -d' ' -f2-)
            if [ "$count" -ge 3 ] 2>/dev/null; then
                repeated_issues+=("$check ($count times)")
            fi
        done < <(sort "$ISSUE_COUNTS_FILE" | uniq -c | sort -rn)
    fi
    rm -f "$ISSUE_COUNTS_FILE"

    if [ ${#repeated_issues[@]} -gt 0 ]; then
        echo -e "${YELLOW}Repeated issues detected in last ${TREND_WINDOW_DAYS} days (candidates for practice):${NC}"
        for issue in "${repeated_issues[@]}"; do
            echo "  - $issue"
        done
        echo ""
        echo -e "${CYAN}Consider creating a practice to address these recurring issues.${NC}"
        echo "Run: fw context add-learning \"description\" --task T-XXX"
    else
        echo -e "${GREEN}No repeated issues in last ${TREND_WINDOW_DAYS} days (across ${#past_audits[@]} audits).${NC}"
    fi

    # Show trend summary
    echo ""
    echo "Audit history: ${#past_audits[@]} audit(s) in last ${TREND_WINDOW_DAYS} days + today"
fi

echo ""
echo "Audit saved to: $AUDIT_FILE"

# Retention: prune cron audit files older than 7 days
if [ -n "$OUTPUT_DIR" ] && [ -d "$OUTPUT_DIR" ]; then
    find "$OUTPUT_DIR" -name "*.yaml" -mtime +7 -delete 2>/dev/null || true
fi

# ============================================
# METRICS HISTORY APPEND (T-238)
# Appends summary metrics to time-series store after every audit run.
# Independent of section selection — always computes fresh values.
# ============================================
METRICS_HISTORY="$CONTEXT_DIR/project/metrics-history.yaml"
if [ -d "$CONTEXT_DIR/project" ]; then
    export AUDIT_PASS="$PASS_COUNT" AUDIT_WARN="$WARN_COUNT" AUDIT_FAIL="$FAIL_COUNT"
    export PROJECT_ROOT="$PROJECT_ROOT"
    python3 << 'METRICS_EOF'
import yaml, glob, os, subprocess, re
from datetime import datetime, timedelta, timezone

PROJECT_ROOT = os.environ.get("PROJECT_ROOT", os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
METRICS_FILE = os.path.join(PROJECT_ROOT, ".context", "project", "metrics-history.yaml")
TASKS_DIR = os.path.join(PROJECT_ROOT, ".tasks")
CONTEXT_DIR = os.path.join(PROJECT_ROOT, ".context")

# Compute metrics
active_tasks = len(glob.glob(os.path.join(TASKS_DIR, "active", "T-*.md")))
completed_tasks = len(glob.glob(os.path.join(TASKS_DIR, "completed", "T-*.md")))

# Velocity: commits in last 24h
try:
    r = subprocess.run(
        ["git", "log", "--oneline", "--since=24 hours ago"],
        capture_output=True, text=True, timeout=10, cwd=PROJECT_ROOT,
    )
    velocity = len([l for l in r.stdout.strip().split("\n") if l.strip()]) if r.returncode == 0 else 0
except Exception:
    velocity = 0

# Traceability (T-590: respect baseline if set)
try:
    trace_cmd = ["git", "log", "--oneline", "--format=%s"]
    baseline_file = os.path.join(CONTEXT_DIR, "project", "traceability-baseline")
    if os.path.isfile(baseline_file):
        baseline_sha = open(baseline_file).read().strip()
        trace_cmd.append(f"{baseline_sha}..HEAD")
    else:
        trace_cmd.extend(["-200"])
    r = subprocess.run(
        trace_cmd,
        capture_output=True, text=True, timeout=10, cwd=PROJECT_ROOT,
    )
    lines = [l for l in r.stdout.strip().split("\n") if l.strip()] if r.returncode == 0 else []
    traced = sum(1 for l in lines if re.search(r"T-\d+", l))
    traceability_pct = int(round(traced / len(lines) * 100)) if lines else 0
except Exception:
    traceability_pct = 0

# Episodic quality: % without [TODO] in summary
ep_dir = os.path.join(CONTEXT_DIR, "episodic")
ep_total = 0
ep_good = 0
if os.path.isdir(ep_dir):
    for f in glob.glob(os.path.join(ep_dir, "T-*.yaml")):
        ep_total += 1
        try:
            content = open(f).read()
            if "[TODO" not in content:
                ep_good += 1
        except Exception:
            pass
episodic_quality_pct = int(round(ep_good / ep_total * 100)) if ep_total > 0 else 100

# Open gaps
# T-397: Unified concerns register
gaps_file = os.path.join(CONTEXT_DIR, "project", "concerns.yaml")
if not os.path.exists(gaps_file):
    gaps_file = os.path.join(CONTEXT_DIR, "project", "gaps.yaml")
open_gaps = 0
if os.path.exists(gaps_file):
    try:
        with open(gaps_file) as f:
            gd = yaml.safe_load(f)
        items = (gd or {}).get("concerns", (gd or {}).get("gaps", []))
        open_gaps = sum(1 for g in items if g.get("status") == "watching")
    except Exception:
        pass

# Build entry
entry = {
    "timestamp": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "pass": int(os.environ.get("AUDIT_PASS", "0")),
    "warn": int(os.environ.get("AUDIT_WARN", "0")),
    "fail": int(os.environ.get("AUDIT_FAIL", "0")),
    "active_tasks": active_tasks,
    "completed_tasks": completed_tasks,
    "velocity": velocity,
    "traceability_pct": traceability_pct,
    "episodic_quality_pct": episodic_quality_pct,
    "open_gaps": open_gaps,
}

# Load existing, append, prune >30 days
if os.path.exists(METRICS_FILE):
    try:
        with open(METRICS_FILE) as f:
            data = yaml.safe_load(f) or {}
    except Exception:
        data = {}
else:
    data = {}

entries = data.get("entries", [])
if not isinstance(entries, list):
    entries = []

entries.append(entry)

# Prune entries older than 30 days
cutoff_30d = datetime.now(timezone.utc) - timedelta(days=30)
pruned = []
for e in entries:
    # .get("timestamp", "") returns None when YAML has an explicit null value (T-1402)
    ts_str = e.get("timestamp") or ""
    try:
        ts = datetime.fromisoformat(ts_str.replace("Z", "+00:00"))
        if ts >= cutoff_30d:
            pruned.append(e)
    except (ValueError, TypeError, AttributeError):
        pruned.append(e)  # keep unparseable entries

# Downsample: for entries older than 7 days, keep only 1 per calendar day (T-431/A3)
cutoff_7d = datetime.now(timezone.utc) - timedelta(days=7)
recent = []
old_by_day = {}
for e in pruned:
    ts_str = e.get("timestamp") or ""
    try:
        ts = datetime.fromisoformat(ts_str.replace("Z", "+00:00"))
        if ts >= cutoff_7d:
            recent.append(e)
        else:
            day_key = ts.strftime("%Y-%m-%d")
            if day_key not in old_by_day:
                old_by_day[day_key] = e  # keep first (oldest) per day
    except (ValueError, TypeError, AttributeError):
        recent.append(e)

pruned = sorted(old_by_day.values(), key=lambda x: x.get("timestamp") or "") + recent

data["entries"] = pruned

# T-100190: same-dir temp + os.replace — a kill mid-dump must not truncate the
# live file (L-493 class; a cron audit killed mid-write corrupted this YAML and
# the pre-push gate then blocked all pushes until manual recovery).
tmp_path = METRICS_FILE + ".tmp"
with open(tmp_path, "w") as f:
    # Preserve header comment
    f.write("# Time-series metrics history\n")
    f.write("# Auto-appended by audit.sh on each run\n")
    f.write("# 30-day rolling retention\n")
    yaml.dump({"entries": pruned}, f, default_flow_style=False, sort_keys=False)
os.replace(tmp_path, METRICS_FILE)
METRICS_EOF
fi

echo ""
# T-3126: machine-readable scope partition of FAIL_COUNT, for callers that act on
# a REF rather than on the working tree (agents/git/lib/hooks.sh pre-push).
#
# Emitted unconditionally, including when there are no failures, so a consumer can
# tell "this audit partitions its findings" from "this audit predates T-3126".
# The pre-push gate treats an ABSENT line as ref=unknown and keeps blocking — an
# old vendored audit must not be read as a clean bill of health.
echo "AUDIT-SCOPE: fails=$FAIL_COUNT ref=$FAIL_REF_COUNT worktree=$FAIL_WORKTREE_COUNT"
for _t3126_wt in "${FAIL_WORKTREE_TITLES[@]:-}"; do
    [ -n "$_t3126_wt" ] && echo "AUDIT-SCOPE-WORKTREE: $_t3126_wt"
done
echo "=== END AUDIT ==="

# Restore stdout if quiet mode was active
if [ "$QUIET" = true ]; then
    exec 1>&3
fi

# T-709: Push notification on audit failures
if [ $FAIL_COUNT -gt 0 ] && [ -f "$FRAMEWORK_ROOT/lib/notify.sh" ]; then
    source "$FRAMEWORK_ROOT/lib/notify.sh"
    fw_notify "Audit Failures: $FAIL_COUNT" "Pass: $PASS_COUNT | Warn: $WARN_COUNT | Fail: $FAIL_COUNT" "health_check_failed" "audit"
fi

# Exit code based on findings
if [ $FAIL_COUNT -gt 0 ]; then
    exit 2
elif [ $WARN_COUNT -gt 0 ]; then
    exit 1
else
    exit 0
fi
