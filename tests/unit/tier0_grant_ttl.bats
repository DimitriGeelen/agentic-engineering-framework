#!/usr/bin/env bats
# T-3080 — the Tier 0 grant TTL is one window, resolved once, for BOTH approval legs.
#
# Before T-3080, check-tier0.sh carried two independent TTL literals: a bare `300`
# on the `fw tier0 approve` leg and `${TIER0_WATCHTOWER_TTL:-3600}` on the
# Watchtower leg. The path that takes one CLICK pre-authorised a destructive
# command for 12x as long as the path that takes a TYPED command — and a misclick
# is the easier mistake to make, so it must carry the SHORTER window. Unified at
# the tight leg: 300s, one resolution point, `TIER0_APPROVAL_TTL` in the registry.
#
# What a grant actually is, and why the window matters: approving does not run the
# command. It writes the command's hash into a grant record, and this hook then
# admits ANY command whose whitespace-normalised text hashes to that value, once.
# So the window is the interval during which a destructive command is live and
# pre-authorised. These tests assert the interval, not the arithmetic.
#
# ── Fixture choice ───────────────────────────────────────────────────────────
# The destructive command used throughout is `git push --force origin master`
# (FORCE PUSH). It is deliberately NOT `rm -rf /`: these tests file real grant
# records, and a fixture that reads `rm -rf /` in a log, a card or a stray file
# is alarming to whoever finds it — which is exactly what happened when the
# governance suite leaked such a card onto the operator's live Watchtower queue
# for four months (T-3077). Any Tier 0 pattern exercises the same code path.
#
# ── Isolation (T-3077, applying L-256/T-1428) ────────────────────────────────
# check-tier0.sh writes into PROJECT_ROOT whenever it blocks:
#     .context/working/.tier0-approval.pending
#     .context/approvals/pending-<hash12>.yaml   (the Watchtower /approvals card)
# Run against the live project, these tests would file genuine approval requests.
# Isolation is by CONSTRUCTION — a sandbox PROJECT_ROOT per test — not cleanup,
# because bats teardown does not run when the process is killed.
#
# Both sandbox directories below are REQUIRED, measured not assumed:
#   .tasks/           bin/fw's _project_root_is_stale() treats a markerless dir as
#                     stale and silently re-resolves to the live project, so the
#                     PROJECT_ROOT export is ignored and the card leaks anyway.
#   .context/working/ check-tier0.sh writes ${APPROVAL_FILE}.pending with a bare
#                     redirect and no mkdir -p.

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
HOOK_BIN="$FRAMEWORK_ROOT/bin/fw"

# A Tier 0 command that is a string in a test and nothing more.
DESTRUCTIVE_CMD='git push --force origin master'
BENIGN_CMD='git status --short'

setup() {
    SANDBOX="$BATS_TEST_TMPDIR/fw-sandbox"
    mkdir -p "$SANDBOX/.tasks/active" "$SANDBOX/.context/working" "$SANDBOX/.context/approvals"
    export SANDBOX
}

# _cmd_hash COMMAND — reproduce check-tier0.sh's hash exactly (T-1500 normalisation:
# squeeze whitespace, strip leading/trailing). Computed here rather than imported so
# a change to the hashing rule shows up as a test failure instead of tracking silently.
_cmd_hash() {
    printf '%s' "$1" | tr -s '[:space:]' ' ' | sed 's/^ //; s/ $//' | sha256sum | awk '{print $1}'
}

# _run_hook COMMAND — drive the REAL hook the way Claude Code does, in the sandbox.
_run_hook() {
    local cmd="$1"
    local payload
    payload=$(printf '{"tool_name":"Bash","tool_input":{"command":"%s"}}' "$cmd")
    run env PROJECT_ROOT="$SANDBOX" bash -c "printf '%s' '$payload' | '$HOOK_BIN' hook check-tier0"
}

# _grant_cli COMMAND AGE_SECONDS — write the CLI-leg grant record at a chosen age.
_grant_cli() {
    local hash; hash=$(_cmd_hash "$1")
    local ts=$(( $(date +%s) - $2 ))
    printf '%s %s\n' "$hash" "$ts" > "$SANDBOX/.context/working/.tier0-approval"
}

# _grant_watchtower COMMAND AGE_SECONDS — write the Watchtower-leg grant record.
_grant_watchtower() {
    local hash; hash=$(_cmd_hash "$1")
    local ts; ts=$(date -u -d "@$(( $(date +%s) - $2 ))" +%Y-%m-%dT%H:%M:%SZ)
    cat > "$SANDBOX/.context/approvals/resolved-${hash:0:12}.yaml" <<EOF
status: approved
command_hash: $hash
command_preview: $1
response:
  responded_at: '$ts'
  approved_by: test-fixture
EOF
}

# ============================================================================
# A2/A3 — Watchtower leg: expires at the unified window, both directions
# ============================================================================

@test "T-3080: Watchtower grant older than the window is refused" {
    _grant_watchtower "$DESTRUCTIVE_CMD" 400      # 400s > 300s
    _run_hook "$DESTRUCTIVE_CMD"
    [ "$status" -eq 2 ]
}

@test "T-3080: Watchtower grant inside the window is admitted (positive control, L-616)" {
    # Without this, a hook that blocks unconditionally is indistinguishable from
    # one that expires correctly. Two empty sets are equal.
    _grant_watchtower "$DESTRUCTIVE_CMD" 30       # 30s < 300s
    _run_hook "$DESTRUCTIVE_CMD"
    [ "$status" -eq 0 ]
}

@test "T-3080: Watchtower grant at 1800s is refused — the old 3600 default is gone" {
    # This is the regression the task exists for. Pre-T-3080 this grant was live:
    # 1800s sits inside the old 1h Watchtower window and outside the 5m CLI one.
    _grant_watchtower "$DESTRUCTIVE_CMD" 1800
    _run_hook "$DESTRUCTIVE_CMD"
    [ "$status" -eq 2 ]
}

# ============================================================================
# A2/A3 — CLI leg: the same window, from the same resolution point
# ============================================================================

@test "T-3080: CLI grant older than the window is refused" {
    _grant_cli "$DESTRUCTIVE_CMD" 400
    _run_hook "$DESTRUCTIVE_CMD"
    [ "$status" -eq 2 ]
}

@test "T-3080: CLI grant inside the window is admitted (positive control, L-616)" {
    _grant_cli "$DESTRUCTIVE_CMD" 30
    _run_hook "$DESTRUCTIVE_CMD"
    [ "$status" -eq 0 ]
}

@test "T-3080: both legs expire at the same age — parity, not two windows" {
    # The whole point of the task. Same age, one side each, same verdict.
    _grant_cli "$DESTRUCTIVE_CMD" 1800
    _run_hook "$DESTRUCTIVE_CMD"
    local cli_status="$status"

    rm -f "$SANDBOX/.context/working/.tier0-approval"
    _grant_watchtower "$DESTRUCTIVE_CMD" 1800
    _run_hook "$DESTRUCTIVE_CMD"
    local wt_status="$status"

    [ "$cli_status" -eq 2 ]
    [ "$wt_status" -eq 2 ]
    [ "$cli_status" -eq "$wt_status" ]
}

# ============================================================================
# A4 — the legacy override still works
# ============================================================================

@test "T-3080: TIER0_WATCHTOWER_TTL set explicitly still widens the window" {
    # Any operator or test pinning the legacy name keeps working. A grant at
    # ~1h is refused by default (previous test) and admitted with the override.
    _grant_watchtower "$DESTRUCTIVE_CMD" 1800
    local payload
    payload=$(printf '{"tool_name":"Bash","tool_input":{"command":"%s"}}' "$DESTRUCTIVE_CMD")
    run env PROJECT_ROOT="$SANDBOX" TIER0_WATCHTOWER_TTL=7200 \
        bash -c "printf '%s' '$payload' | '$HOOK_BIN' hook check-tier0"
    [ "$status" -eq 0 ]
}

# ============================================================================
# Sanity: the gate still gates, and the sandbox still contains it
# ============================================================================

@test "T-3080: with no grant at all, the destructive command is blocked" {
    _run_hook "$DESTRUCTIVE_CMD"
    [ "$status" -eq 2 ]
}

@test "T-3080: a benign command is allowed (positive control on the gate itself)" {
    _run_hook "$BENIGN_CMD"
    [ "$status" -eq 0 ]
}

@test "T-3080: the live approvals surface is untouched by this suite" {
    # The T-3077 invariant, re-asserted here so this file cannot become the next
    # suite that files real Tier 0 cards on the operator's queue.
    _run_hook "$DESTRUCTIVE_CMD"          # blocks, and files its request…
    [ "$status" -eq 2 ]

    local hash; hash=$(_cmd_hash "$DESTRUCTIVE_CMD")
    # …in the sandbox…
    [ -f "$SANDBOX/.context/approvals/pending-${hash:0:12}.yaml" ]
    # …and nowhere near the live project.
    [ ! -e "$FRAMEWORK_ROOT/.context/approvals/pending-${hash:0:12}.yaml" ]
    [ ! -e "$FRAMEWORK_ROOT/.context/working/.tier0-approval" ]
}
