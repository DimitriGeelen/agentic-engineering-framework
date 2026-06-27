#!/usr/bin/env bats
# T-1735: Worker-kinds parity (lib/resolver.py ↔ lib/workflow_lint.py) — unit tests
#
# Closes the structural gap exposed by T-1734: two tables held VALID_WORKER_KINDS
# sets and silently drifted for 5 months (G-064's zero-consumer rule hid the bug).
# The fw doctor parity check is the runtime witness; these tests pin its contract.
#
# T-2388 (2026-06-27): retargeted from "bin/fw ↔ resolver.py" to
# "resolver.py ↔ workflow_lint.py". T-1946 extracted the VALID_WORKER_KINDS
# literal OUT of bin/fw (heredoc → lib/worker_kinds_parity.py) per L-332/L-408,
# so the two source-of-truth tables are now the two python modules; bin/fw holds
# no literal to grep. The "literal exists in bin/fw" + "identical vs bin/fw"
# assertions failed because they pinned the pre-T-1946 location.

setup() {
    FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-/opt/999-Agentic-Engineering-Framework}"
    [ -f "$FRAMEWORK_ROOT/bin/fw" ] || skip "bin/fw not found"
    [ -f "$FRAMEWORK_ROOT/lib/resolver.py" ] || skip "lib/resolver.py not found"
}

@test "parity OK: doctor reports green Worker-kinds parity line in current repo" {
    run bash -c "$FRAMEWORK_ROOT/bin/fw doctor 2>&1"
    # Doctor exits 2 on failures (other unrelated failures may be present), so
    # we don't gate on exit code; we only assert the parity line is present.
    echo "$output" | grep -q "Worker-kinds parity"
    echo "$output" | grep -q "OK.*Worker-kinds parity"
}

@test "parity drift: worker_kinds_parity.py reports WARN when the two tables differ" {
    # T-2388: exercise the REAL shipped helper (lib/worker_kinds_parity.py) against
    # stub modules in a temp lib dir, instead of an inline reimplementation that can
    # itself drift. The helper imports `from resolver import VALID_WORKER_KINDS` and
    # `from workflow_lint import VALID_WORKER_KINDS` from argv[1] (sys.path[0]).
    TMP_LIB="$(mktemp -d)"
    printf 'VALID_WORKER_KINDS = {"Task", "TermLink", "pi", "ollama-loop"}\n' > "$TMP_LIB/resolver.py"
    printf 'VALID_WORKER_KINDS = {"Task", "TermLink", "pi", "ollama-loop", "DRIFT-ONLY-IN-LINT"}\n' > "$TMP_LIB/workflow_lint.py"
    output=$(python3 "$FRAMEWORK_ROOT/lib/worker_kinds_parity.py" "$TMP_LIB")
    rm -rf "$TMP_LIB"
    [[ "$output" == WARN\|* ]]
    echo "$output" | grep -q "DRIFT-ONLY-IN-LINT"
}

@test "parity OK: worker_kinds_parity.py reports OK when the two tables agree" {
    # T-2388: positive case for the real helper — identical stub tables → OK|<list>.
    TMP_LIB="$(mktemp -d)"
    printf 'VALID_WORKER_KINDS = {"Task", "TermLink", "pi", "ollama-loop"}\n' > "$TMP_LIB/resolver.py"
    printf 'VALID_WORKER_KINDS = {"Task", "TermLink", "pi", "ollama-loop"}\n' > "$TMP_LIB/workflow_lint.py"
    output=$(python3 "$FRAMEWORK_ROOT/lib/worker_kinds_parity.py" "$TMP_LIB")
    rm -rf "$TMP_LIB"
    [[ "$output" == OK\|* ]]
}

@test "parity literal exists at expected location in lib/workflow_lint.py" {
    # T-2388: post-T-1946 the second source-of-truth table is lib/workflow_lint.py
    # (bin/fw no longer holds the literal — it was extracted to
    # lib/worker_kinds_parity.py). Pin the literal where it now lives.
    grep -E "VALID_WORKER_KINDS\s*=\s*\{" "$FRAMEWORK_ROOT/lib/workflow_lint.py"
}

@test "parity literal exists at expected location in lib/resolver.py" {
    grep -E "VALID_WORKER_KINDS\s*=\s*\{" "$FRAMEWORK_ROOT/lib/resolver.py"
}

@test "parity literal in both files is identical (source-of-truth check)" {
    # T-2388: compare the two python source-of-truth tables directly — this is
    # exactly what lib/worker_kinds_parity.py / fw doctor check at runtime.
    lint_set=$(python3 -c "
import sys
sys.path.insert(0, '$FRAMEWORK_ROOT/lib')
from workflow_lint import VALID_WORKER_KINDS
print(','.join(sorted(VALID_WORKER_KINDS)))
")
    resolver_set=$(python3 -c "
import sys
sys.path.insert(0, '$FRAMEWORK_ROOT/lib')
from resolver import VALID_WORKER_KINDS
print(','.join(sorted(VALID_WORKER_KINDS)))
")
    [ "$lint_set" = "$resolver_set" ]
}

@test "doctor parity check exits without crashing in fresh shell" {
    run bash -c "cd $FRAMEWORK_ROOT && bin/fw doctor 2>&1 | grep 'Worker-kinds parity'"
    [ "$status" -eq 0 ]
    [ -n "$output" ]
}
