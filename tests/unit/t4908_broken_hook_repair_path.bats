#!/usr/bin/env bats
# T-4908: a gate hook that cannot run because it (or a file it sources) has a bash syntax
# error must not lock the repo. On 2026-10-29 a half-finished edit of check-active-task.sh
# refused every write, including `git checkout` of the broken file; the operator had to
# repair it from outside the hooks. lib/hook-dispatch.sh now allows exactly the repair.

DISPATCH="${T4908_DISPATCH:-$BATS_TEST_DIRNAME/../../lib/hook-dispatch.sh}"

setup() {
    T="$(mktemp -d)"
    mkdir -p "$T/fw/agents/context" "$T/fw/lib" "$T/proj/.context/working"
    BROKEN="$T/fw/agents/context/gate.sh"
    # the shape of 2026-10-29: an unmatched ';;' left by a half-finished edit
    printf '#!/bin/bash\ncat >/dev/null\nif true; then\n    echo x\n            ;;\nfi\nexit 0\n' > "$BROKEN"
    # a healthy gate that sources a broken library
    printf 'if true; then\n  ;;\nfi\n' > "$T/fw/lib/broken-lib.sh"
    # (a gate fails closed when its library will not load — the lockout shape)
    printf '#!/bin/bash\nsource "%s/fw/lib/broken-lib.sh" || exit 2\nexit 0\n' "$T" > "$T/fw/agents/context/sourcing.sh"
    # healthy gates that refuse / allow, to show exit codes pass through
    printf '#!/bin/bash\ncat >/dev/null\necho "refused" >&2\nexit 2\n' > "$T/fw/agents/context/refuser.sh"
    printf '#!/bin/bash\ncat >/dev/null\nexit 0\n' > "$T/fw/agents/context/allower.sh"
}

teardown() { rm -rf "$T"; }

_hook() {   # <hook name> <payload json>
    run env FRAMEWORK_ROOT="$T/fw" PROJECT_ROOT="$T/proj" AGENTS_DIR="$T/fw/agents" FW_LIB_DIR="$T/fw/lib" \
        bash -c "source '$DISPATCH'; fw_hook_run '$1'" <<<"$2"
}
_bash_payload() { python3 -c "import json,sys; print(json.dumps({'tool_name':'Bash','tool_input':{'command':sys.argv[1]}}))" "$1"; }
_tool_payload() { python3 -c "import json,sys; print(json.dumps({'tool_name':sys.argv[1],'tool_input':{'file_path':sys.argv[2]}}))" "$1" "$2"; }

@test "broken gate: an ordinary write is refused, loudly, with the repair named" {
    _hook gate "$(_tool_payload Write "$T/proj/x.sh")"
    [ "$status" -eq 2 ]
    [[ "$output" == *"cannot run"* ]]
    [[ "$output" == *"git checkout -- $BROKEN"* ]]
    grep -q "broken-hook gate" "$T/proj/.context/working/.hook-crashes.log"
}

@test "broken gate: git checkout -- <the broken file> is allowed" {
    _hook gate "$(_bash_payload "git checkout -- $BROKEN")"
    [ "$status" -eq 0 ]
    [[ "$output" == *"allowing this repair"* ]]
}

@test "broken gate: cd <dir> && git restore --source=HEAD -- <relative path> is allowed" {
    _hook gate "$(_bash_payload "cd $T/fw && git restore --source=HEAD -- agents/context/gate.sh")"
    [ "$status" -eq 0 ]
}

@test "broken gate: an Edit of the broken file itself is allowed" {
    _hook gate "$(_tool_payload Edit "$BROKEN")"
    [ "$status" -eq 0 ]
}

@test "broken gate: checking out a different file is refused" {
    _hook gate "$(_bash_payload "git checkout -- $T/fw/lib/other.sh")"
    [ "$status" -eq 2 ]
}

@test "broken gate: a repair chained with anything else is refused" {
    _hook gate "$(_bash_payload "git checkout -- $BROKEN && rm -rf $T/proj")"
    [ "$status" -eq 2 ]
}

@test "a hook whose sourced library is broken gets the same repair path, naming the library" {
    _hook sourcing "$(_tool_payload Write "$T/proj/x.sh")"
    [ "$status" -eq 2 ]
    [[ "$output" == *"$T/fw/lib/broken-lib.sh"* ]]
    _hook sourcing "$(_bash_payload "git checkout -- $T/fw/lib/broken-lib.sh")"
    [ "$status" -eq 0 ]
}

@test "healthy gates: a refusal (2) and an allow (0) pass through unchanged" {
    _hook refuser "$(_tool_payload Write "$T/proj/x.sh")"
    [ "$status" -eq 2 ]
    [[ "$output" == *"refused"* ]]
    [[ "$output" != *"cannot run"* ]]
    _hook allower "$(_tool_payload Write "$T/proj/x.sh")"
    [ "$status" -eq 0 ]
}
