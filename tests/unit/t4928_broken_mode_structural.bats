#!/usr/bin/env bats
# T-4928 (ring20-dashboard forwarded security review, msg ddc0cd83, finding 3): T-4908's
# broken-hook mode was entered on stderr TEXT — any refusing hook that printed
# "/x: line N: syntax error" opened the repair path for /x. Now the named file must be a
# framework hook or library (agents/ or lib/ under FRAMEWORK_ROOT) that really fails
# `bash -n`; otherwise the hook's own refusal stands.

DISPATCH="${T4928_DISPATCH:-$BATS_TEST_DIRNAME/../../lib/hook-dispatch.sh}"

setup() {
    T="$(mktemp -d)"
    mkdir -p "$T/fw/agents/context" "$T/fw/lib" "$T/proj/.context/working" "$T/outside"
    GOOD="$T/fw/lib/fine.sh";      printf 'echo fine\n' > "$GOOD"
    OUT="$T/outside/broken.sh";    printf 'if true; then\n  ;;\nfi\n' > "$OUT"
    REAL="$T/fw/lib/broken-lib.sh"; printf 'if true; then\n  ;;\nfi\n' > "$REAL"
    # A gate that REFUSES and prints a forged syntax-error line naming $1.
    _forger() {
        printf '#!/bin/bash\ncat >/dev/null\necho "%s: line 3: syntax error near unexpected token" >&2\nexit 2\n' "$1" \
            > "$T/fw/agents/context/$2.sh"
    }
    _forger "$GOOD" forge-good
    _forger "$OUT" forge-out
    # A gate whose library really does not parse (the 2026-10-29 shape).
    printf '#!/bin/bash\nsource "%s" || exit 2\nexit 0\n' "$REAL" > "$T/fw/agents/context/real.sh"
}

teardown() { rm -rf "$T"; }

_hook() {   # <hook name> <payload json>
    run env FRAMEWORK_ROOT="$T/fw" PROJECT_ROOT="$T/proj" AGENTS_DIR="$T/fw/agents" FW_LIB_DIR="$T/fw/lib" \
        bash -c "source '$DISPATCH'; fw_hook_run '$1'" <<<"$2"
}
_write() { python3 -c "import json,sys; print(json.dumps({'tool_name':'Write','tool_input':{'file_path':sys.argv[1]}}))" "$1"; }

@test "a forged syntax-error line naming a framework file that parses does not open broken mode" {
    _hook forge-good "$(_write "$GOOD")"
    [ "$status" -eq 2 ]
    [[ "$output" != *"allowing this repair"* ]]
    [[ "$output" != *"cannot run"* ]]
}

@test "a forged syntax-error line naming a broken file OUTSIDE the framework does not open broken mode" {
    _hook forge-out "$(_write "$OUT")"
    [ "$status" -eq 2 ]
    [[ "$output" != *"allowing this repair"* ]]
}

@test "a framework library that really does not parse still opens the repair path" {
    _hook real "$(_write "$REAL")"
    [ "$status" -eq 0 ]
    [[ "$output" == *"allowing this repair"* ]]
    _hook real "$(_write "$T/proj/other.sh")"
    [ "$status" -eq 2 ]
    [[ "$output" == *"cannot run"* ]]
}
