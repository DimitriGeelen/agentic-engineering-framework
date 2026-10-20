#!/usr/bin/env bats
# T-4462 — the line claude-fw injects into a TermLink PTY must reach the claude
# BINARY, not a user's claude() function or `claude` alias.
#
# The PTY runs an interactive bash that sources the user's rc, so a bare `claude`
# resolves alias → function → PATH. 055-agentic-fleet-cockpit (T-580) had a
# claude() front door that caught every fleet start (rc=1). The test builds the
# exact injected line from bin/claude-fw's own `termlink_inject "…"` call and runs
# it in `bash -i` whose rc defines both, with a stand-in binary on PATH.

setup() {
    REPO="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    T="$(mktemp -d)"
    mkdir -p "$T/bin"
    cat > "$T/bin/claude" <<EOF
#!/bin/bash
printf '%s\n' "\$@" > "$T/binary-args"
exit 0
EOF
    chmod +x "$T/bin/claude"
    cat > "$T/rc" <<EOF
PATH="$T/bin:\$PATH"
claude() { : > "$T/function-ran"; return 1; }
alias claude='touch "$T/alias-ran"; false'
EOF
    # The injected line, taken from the source rather than restated here.
    INJECT_SRC=$(grep -E '^[[:space:]]*termlink_inject "[^"]*claude\$\{_tl_args\}' "$REPO/bin/claude-fw")
    [ -n "$INJECT_SRC" ]
}

teardown() { rm -rf "$T"; }

# Render the injected text for CLAUDE_ARGS ("$@"), the way claude-fw builds it.
_injected_line() {
    local CLAUDE_ARGS=("$@") restart_count=0 _tl_args="" _tl_tok
    [ "${#CLAUDE_ARGS[@]}" -gt 0 ] && _tl_args=$(printf ' %q' "${CLAUDE_ARGS[@]}")
    _tl_tok="r0p1e1"
    termlink_inject() { printf '%s\n' "$1"; }
    eval "$INJECT_SRC"
}

@test "T-4462: a bare relaunch reaches the binary past a claude() function and alias" {
    line=$(_injected_line)
    out=$(printf '%s\nexit\n' "$line" | env -i HOME="$T" PATH=/usr/bin:/bin bash --rcfile "$T/rc" -i 2>/dev/null)
    [ -f "$T/binary-args" ]
    [ ! -e "$T/function-ran" ]
    [ ! -e "$T/alias-ran" ]
    printf '%s\n' "$out" | grep -q '__CLAUDE_FW_EXIT_r0p1e1_0__'
}

@test "T-4462: arguments still arrive as one word each through the bypass" {
    line=$(_injected_line --resume "two words")
    printf '%s\nexit\n' "$line" | env -i HOME="$T" PATH=/usr/bin:/bin bash --rcfile "$T/rc" -i >/dev/null 2>&1
    [ ! -e "$T/function-ran" ]
    [ "$(sed -n 1p "$T/binary-args")" = "--resume" ]
    [ "$(sed -n 2p "$T/binary-args")" = "two words" ]
}
