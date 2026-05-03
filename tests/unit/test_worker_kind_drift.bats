#!/usr/bin/env bats
# T-1708 — worker_kind drift regression test.
#
# Origin: 2026-05-04 T-1707. T-1706 added `ollama-loop` to the termlink
# dispatcher's --worker-kind flag and to the ollama-research workflow YAML,
# but missed VALID_WORKER_KINDS in bin/fw's workflow validator. The
# dispatcher and the validator drifted silently — `fw doctor` started
# emitting FAIL on the new workflow file with no visible upstream cause.
#
# These tests pin the invariant: every TermLink-routed kind in
# VALID_WORKER_KINDS has a matching case in termlink.sh's --worker-kind
# acceptor. Adding a kind to one without the other now fails loudly.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    FW_BIN="$FRAMEWORK_ROOT/bin/fw"
    TL_BIN="$FRAMEWORK_ROOT/agents/termlink/termlink.sh"
    [ -x "$FW_BIN" ]
    [ -f "$TL_BIN" ]
}

@test "VALID_WORKER_KINDS in bin/fw includes the documented set" {
    line=$(grep "^VALID_WORKER_KINDS = " "$FW_BIN")
    [ -n "$line" ]
    [[ "$line" == *'"Task"'* ]]
    [[ "$line" == *'"TermLink"'* ]]
    [[ "$line" == *'"pi"'* ]]
    [[ "$line" == *'"ollama-loop"'* ]]
}

@test "termlink.sh --worker-kind accepts claude and ollama-loop" {
    # The case statement allows empty (default), claude (alias), ollama-loop.
    grep -E '""\|claude\|ollama-loop' "$TL_BIN"
}

@test "termlink.sh --worker-kind rejects unknown kinds" {
    # The catch-all branch dies with a clear message naming the allowed set.
    grep -E 'Unknown --worker-kind: \$worker_kind' "$TL_BIN"
}

@test "every TermLink-routed kind in VALID_WORKER_KINDS has a case branch" {
    # Drift detector. Extract the validator set, exclude non-TermLink
    # kinds (Task, pi — they route via Claude Code Task tool and pi RPC
    # respectively), and the umbrella alias TermLink. The remaining set
    # MUST appear in the termlink.sh --worker-kind case statement.
    fw_kinds=$(grep "^VALID_WORKER_KINDS = " "$FW_BIN" \
        | grep -oE '"[a-zA-Z-]+"' | tr -d '"')
    case_line=$(grep -E '^[[:space:]]+""\|.*\)' "$TL_BIN" | head -1)
    [ -n "$case_line" ]

    missing=""
    for kind in $fw_kinds; do
        case "$kind" in
            Task|pi|TermLink) continue ;;
            *) ;;
        esac
        if ! echo "$case_line" | grep -q "$kind"; then
            missing="$missing $kind"
        fi
    done
    if [ -n "$missing" ]; then
        echo "FAIL: VALID_WORKER_KINDS contains TermLink-routed kind(s) not in termlink.sh --worker-kind case:$missing"
        echo "       case line: $case_line"
        return 1
    fi
}

@test "ollama-loop in run.sh dispatch logic (executor present)" {
    # T-1706: WORKER_KIND=ollama-loop in run.sh selects the python
    # ollama-tool-loop.py worker. Pin that the executor branch exists.
    grep -E 'WORKER_KIND.*ollama-loop|ollama-loop.*WORKER_KIND' "$TL_BIN"
}

@test "tools/ollama-tool-loop.py worker exists and is executable-or-readable" {
    # The ollama-loop kind requires this tool. If it disappears, dispatch
    # blows up at runtime instead of at the validator.
    [ -f "$FRAMEWORK_ROOT/tools/ollama-tool-loop.py" ]
}
