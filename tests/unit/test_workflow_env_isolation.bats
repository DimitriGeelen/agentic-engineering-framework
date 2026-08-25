#!/usr/bin/env bats
# T-1700 AC6 — workflow env: plumb-through isolation invariants.
#
# Pins the structural guarantees that prevent workflow-declared env vars
# (ANTHROPIC_BASE_URL, ANTHROPIC_API_KEY, etc) from leaking into:
#   1. The parent shell that ran `fw termlink dispatch`.
#   2. A second worker spawned without `--env` (must not inherit A's env).
#   3. The captured envelope (meta.json records keys, NOT values — possible secrets).
#
# Approach: static-analysis checks against the implementation in
# agents/termlink/termlink.sh. The structural shape of env handling is what
# guarantees isolation — any change that breaks it should break a test here.
# A live spawn test is intentionally avoided (slow, requires hub running).

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    TL_BIN="$FRAMEWORK_ROOT/agents/termlink/termlink.sh"
    [ -f "$TL_BIN" ]
}

@test "--env validates KEY shape ([A-Z_][A-Z0-9_]*=) at parse time" {
    # Pre-spawn rejection: malformed key (lowercase) must die before any side effects.
    grep -qE '\[\[ ! "\$2" =~ \^\[A-Z_\]\[A-Z0-9_\]\*= \]\]' "$TL_BIN"
    grep -q 'die "--env expects KEY=VALUE with KEY matching' "$TL_BIN"
}

@test "env.sh is written ONLY to the per-worker dir (\$wdir), never absolute or parent" {
    # The write path MUST be \$wdir/env.sh — anything else would leak between workers
    # or mutate the parent.
    grep -qE '"\$wdir/env\.sh"' "$TL_BIN"
    # No write to absolute /tmp or HOME paths from cmd_dispatch's env block.
    ! grep -E ':\s*>\s*"?(/tmp|\$HOME|~)' "$TL_BIN" | grep -q "env\.sh"
}

@test "env.sh entries use printf %q shell-quoting (not raw interpolation)" {
    # %q ensures values with spaces, $, \, etc don't break the export line — and
    # don't allow injection of additional commands into env.sh.
    grep -qE "printf 'export %s=%q.*\"\\\$wdir/env\\.sh\"" "$TL_BIN"
}

@test "meta.json records env_keys list but NEVER env_values" {
    # Privacy guarantee: env values may be secrets (API keys). Only key names land
    # in meta.json so log shipping / Watchtower display can't accidentally exfiltrate.
    grep -q '"env_keys": \$env_keys_json' "$TL_BIN"
    if grep -q "env_values" "$TL_BIN"; then false; fi
    # The construction loop appends keys only, not values, to env_keys_json.
    grep -qE '_key_list\+="\\"\$k\\"' "$TL_BIN"
}

@test "run.sh sources env.sh from \$WDIR (per-worker), not a shared path" {
    # The sourcing line in run.sh must be the per-worker WDIR — not /etc, not HOME,
    # not a project-shared file. Any other path would let workers cross-contaminate.
    grep -qE '\[ -f "\$WDIR/env\.sh" \] && \. "\$WDIR/env\.sh"' "$TL_BIN"
}

@test "cmd_dispatch never invokes 'export' on the parent shell — env stays in env.sh" {
    # Inside cmd_dispatch (between the func opener and its closing brace), any
    # bare `export` would mutate the parent. The only `export` should be inside
    # the printf string written to env.sh — that's quoted, so awk with the dispatch
    # function body must show no unquoted export.
    body=$(awk '/^cmd_dispatch\(\)/,/^}$/' "$TL_BIN")
    # Allowed: the literal string 'export %s=%q' in printf — that's content for env.sh.
    # Disallowed: any standalone `export FOO=` line outside printf.
    bad=$(echo "$body" | grep -E "^[[:space:]]*export[[:space:]]+[A-Z_]" || true)
    if [ -n "$bad" ]; then
        echo "FAIL: cmd_dispatch contains direct 'export' calls (would mutate parent shell):"
        echo "$bad"
        return 1
    fi
}

@test "second worker without --env starts with empty env.sh (no inheritance)" {
    # The init line `: > "$wdir/env.sh"` truncates to empty. Only the if-branch
    # writes export lines. A second worker invoked without --env therefore gets
    # an empty (and immediately sourced no-op) env.sh.
    grep -qE ':\s*>\s*"\$wdir/env\.sh"' "$TL_BIN"
    # The append path is gated behind the envs[@] count > 0 check.
    grep -qE 'if \[ "\$\{#envs\[@\]\}" -gt 0 \]; then' "$TL_BIN"
}

@test "env_keys_json starts as empty array '[]'" {
    # Default for no --env: meta.json reports env_keys: [] not null, not omitted.
    grep -qE 'local env_keys_json="\[\]"' "$TL_BIN"
}
