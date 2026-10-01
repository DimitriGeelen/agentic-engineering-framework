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
    # T-3624: the workflow validator left bin/fw for lib/workflow_lint.py in
    # T-1807 (85a876aa9); `fw doctor` now checks its parity with
    # lib/resolver.py. Reading bin/fw found no line at all, which also made the
    # drift detector below pass vacuously over an empty set.
    LINT_PY="$FRAMEWORK_ROOT/lib/workflow_lint.py"
    TL_BIN="$FRAMEWORK_ROOT/agents/termlink/termlink.sh"
    [ -f "$LINT_PY" ]
    [ -f "$TL_BIN" ]
}

@test "VALID_WORKER_KINDS in lib/workflow_lint.py includes the documented set" {
    line=$(grep "^VALID_WORKER_KINDS = " "$LINT_PY")
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
    # respectively; ollama-thin-loop — routed by lib/spawn.py's own
    # _spawn_ollama_thin_loop, T-2592; ollama-direct — spawns nothing, T-1719),
    # and the umbrella alias TermLink. The remaining set MUST appear in the
    # termlink.sh --worker-kind case statement.
    fw_kinds=$(grep "^VALID_WORKER_KINDS = " "$LINT_PY" \
        | grep -oE '"[a-zA-Z-]+"' | tr -d '"')
    [ -n "$fw_kinds" ]
    case_line=$(grep -E '^[[:space:]]+""\|.*\)' "$TL_BIN" | head -1)
    [ -n "$case_line" ]

    missing=""
    for kind in $fw_kinds; do
        case "$kind" in
            Task|pi|TermLink|ollama-thin-loop|ollama-direct) continue ;;
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
