#!/usr/bin/env bats
# T-3954 — an installed COPY of claude-fw must still find its framework.
#
# The operator's launchers are copies in /usr/bin and ~/.local/bin. claude-fw looked up
# lib/ beside itself ("$(dirname "$(readlink -f "$0")")/../lib"), which for a copy is
# /usr/lib — nothing there — so the T-3890 guard that refuses a second copy of a live
# conversation passed silently, and a 13-hour duplicate session followed (G-111).
# Here the functions are loaded through a process substitution, so "beside the script" is
# /dev/fd — exactly as empty as beside an installed copy.

setup() {
    FRAMEWORK_ROOT_REPO="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    T="$(mktemp -d)"
    P="$T/proj"
    mkdir -p "$P/.agentic-framework/lib" "$P/.agentic-framework/bin" "$T/empty"
    cp "$FRAMEWORK_ROOT_REPO/lib/conversation-holder.sh" "$P/.agentic-framework/lib/"
    printf '#!/bin/bash\nexit 0\n' > "$P/.agentic-framework/bin/fw"
    chmod +x "$P/.agentic-framework/bin/fw"
    unset FRAMEWORK_ROOT
}

teardown() { rm -rf "$T"; }

_load() {   # the helper + the guard, as an installed copy would see them
    source <(awk '/^_cfw_framework_dir\(\) \{/,/^}/; /^_cfw_lib\(\) \{/,/^}/; /^_conversation_guard\(\) \{/,/^}/' \
        "$FRAMEWORK_ROOT_REPO/bin/claude-fw")
}

@test "T-3984 (SECURITY): a copy run inside a directory NEVER sources that directory's lib/" {
    # Replaces T-3954's "finds .agentic-framework in PWD": that lookup sourced code from
    # whatever directory the operator happened to start in (ring20-dashboard).
    for d in "$P/.agentic-framework" "$P"; do
        mkdir -p "$d/lib" "$d/bin"
        printf 'touch %q\n' "$T/PWNED" > "$d/lib/conversation-holder.sh"
        printf '#!/bin/bash\nexit 0\n' > "$d/bin/fw"; chmod +x "$d/bin/fw"
    done
    _load
    cd "$P"
    [ -z "$(_cfw_framework_dir)" ]
    CLAUDE_ARGS=(-c)
    run _conversation_guard
    [ ! -e "$T/PWNED" ]
    [[ "$output" == *"WARNING: duplicate-conversation guard unavailable"* ]]
}

@test "T-3984/control: an explicit FRAMEWORK_ROOT still resolves" {
    _load
    cd "$T/empty"
    FRAMEWORK_ROOT="$P/.agentic-framework" run _cfw_framework_dir
    [ "$output" = "$P/.agentic-framework" ]
}

@test "T-3954/control: the old beside-the-script lookup finds nothing for a copy" {
    mkdir -p "$T/usr/bin"
    cp "$FRAMEWORK_ROOT_REPO/bin/claude-fw" "$T/usr/bin/claude-fw"
    old="$(dirname "$(readlink -f "$T/usr/bin/claude-fw")")/../lib/conversation-holder.sh"
    [ ! -f "$old" ]
}

@test "T-3954: with no framework anywhere the guard WARNS instead of passing silently" {
    _load
    cd "$T/empty"
    CLAUDE_ARGS=(-c)
    run _conversation_guard
    [ "$status" -eq 0 ]
    [[ "$output" == *"WARNING: duplicate-conversation guard unavailable"* ]]
}

@test "T-3954: no claude-fw lookup resolves lib/ beside the script any more (except the helper)" {
    n=$(grep -c 'readlink -f "${BASH_SOURCE\[0\]}"' "$FRAMEWORK_ROOT_REPO/bin/claude-fw")
    [ "$n" -eq 1 ]
    grep -q '_cfw_lib conversation-holder.sh' "$FRAMEWORK_ROOT_REPO/bin/claude-fw"
}
