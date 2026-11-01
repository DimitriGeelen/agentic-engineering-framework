#!/usr/bin/env bats
# T-4920 (SECURITY; 832-Workflow-designer T-1347, msg 6810a67d): the Tier 0 fast-path
# pre-filter in agents/context/check-tier0.sh was `! printf '%s\n%s\n' … | grep -qEi …`
# under `set -o pipefail`. grep -q exits at the first matching line; printf then takes
# SIGPIPE writing the second, the pipeline returns 141, and `!` read that as "no dangerous
# pattern" — exit 0, command unchecked. Rare for short commands (832: ~1 in 80,000);
# DETERMINISTIC past the 64 KB pipe buffer: a padded `git push --force` was allowed 50/50.
# The filter now reads a here-string.

HOOK_REL="agents/context/check-tier0.sh"

setup() {
    ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    HOOK="$ROOT/$HOOK_REL"
    # T-4964: the hook runs in place, but judges for a THROWAWAY project. With the live
    # checkout as PROJECT_ROOT every block filed a real approval card on /approvals.
    PROJ="$(mktemp -d -t fw-t4920-XXXXXX)"
    mkdir -p "$PROJ/.context/working" "$PROJ/.context/approvals"
    export NTFY_ENABLED=false
    unset CLAUDE_PROJECT_DIR
}

teardown() {
    [ -n "${PROJ:-}" ] && [ -d "$PROJ" ] && rm -rf "${PROJ:?}"
    return 0
}

_live_surface() {
    { ls -la --time-style=full-iso "$ROOT/.context/approvals" 2>/dev/null | grep 'pending-' || true
      ls -la --time-style=full-iso "$ROOT/.context/working"/.tier0-approval* 2>/dev/null || true; } | sha256sum
}

# Run the real hook (in place: it finds its helpers next to itself) on one Bash payload.
# Nothing is executed — the hook only judges the command text. $2 = bytes of padding
# appended as a comment; python builds it, so no argv carries it (MAX_ARG_STRLEN is 128 KB,
# and an argv that is too long yields an EMPTY payload, which the hook allows — a false
# "bypass" that misled the first measurement).
_judge() {
    run bash -c 'python3 -c "import json,sys; c=sys.argv[1]+(\" # \"+\"x\"*int(sys.argv[2]) if int(sys.argv[2]) else \"\"); print(json.dumps({\"tool_name\":\"Bash\",\"tool_input\":{\"command\":c},\"tool_use_id\":\"t4920\",\"cwd\":\"/tmp\"}))" "$1" "$2" | PROJECT_ROOT="$3" bash "$4" >/dev/null 2>&1' _ "$1" "${2:-0}" "$PROJ" "$HOOK"
}

@test "a destructive command padded past the pipe buffer is still blocked (old hook: allowed)" {
    # Measured on the old hook: blocked at 100 KB of padding, ALLOWED at 120 KB and above.
    for i in 1 2 3; do
        _judge "git push --force origin main" 300000
        [ "$status" -eq 2 ]
        # A second class with no pre-push backstop (rm -rf on an ordinary path is not Tier 0).
        _judge "git clean -fdx" 300000
        [ "$status" -eq 2 ]
    done
}

@test "the short destructive command is blocked and a plain command still takes the fast path" {
    local before
    before="$(_live_surface)"
    _judge "git push --force origin main"
    [ "$status" -eq 2 ]
    # T-4964: the block was filed in the throwaway project, and nowhere else.
    [ -s "$PROJ/.context/working/.tier0-approval.pending" ]
    [ "$(_live_surface)" = "$before" ]
    _judge "ls -la"
    [ "$status" -eq 0 ]
}

@test "the pre-filter feeds grep from a here-string; no pipe into grep -q in the hook's code" {
    # Code lines only (comments may name the old form to explain it).
    ! grep -vE '^[[:space:]]*#' "$HOOK" | grep -qE '\|[[:space:]]*grep[[:space:]]+-[a-zA-Z]*q' || false
    grep -q '<<<"$COMMAND"$'"'"'\\n'"'"'"$T0_DEQUOTED"' "$HOOK"
}

@test "the pre-filter block, run 2000 times under the hook's options, never fails open" {
    pat=$(grep -A1 'grep -qEi \\$' "$HOOK" | tail -1 | sed -E "s/^[[:space:]]*'//; s/' \\\\$//")
    [ -n "$pat" ]
    run bash -c '
        set -uo pipefail
        COMMAND="git push --force origin main"
        T0_DEQUOTED=$(printf "%s" "$COMMAND" | tr -d "\"'"'"'\\\\\$")
        open=0
        for ((i = 0; i < 2000; i++)); do
            if ! grep -qEi "$1" <<<"$COMMAND"$'"'"'\n'"'"'"$T0_DEQUOTED"; then open=$((open + 1)); fi
        done
        echo "$open"' _ "$pat"
    [ "$status" -eq 0 ]
    [ "$output" = "0" ]
}
