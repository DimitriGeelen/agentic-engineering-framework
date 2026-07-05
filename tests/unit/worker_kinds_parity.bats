#!/usr/bin/env bats
# T-1735: Worker-kinds parity (bin/fw ↔ lib/resolver.py) — unit tests
#
# Closes the structural gap exposed by T-1734: bin/fw and lib/resolver.py
# both held VALID_WORKER_KINDS sets and silently drifted for 5 months
# (G-064's zero-consumer rule hid the bug). The fw doctor parity check is
# the runtime witness; these tests pin its detection contract.

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

@test "parity drift: doctor reports WARN when bin/fw set differs from resolver" {
    # Stage a temporary bin/fw with a perturbed VALID_WORKER_KINDS literal,
    # invoke the doctor's parity python directly against it, assert WARN.
    TMP_FW="$(mktemp -d)/bin"
    mkdir -p "$TMP_FW"
    # Keep only the marker line; the python parser only needs that line in
    # bin/fw and a working resolver import path.
    cat > "$TMP_FW/fw" <<'BASH'
#!/usr/bin/env bash
# T-1735 test fixture — perturbed VALID_WORKER_KINDS:
#     VALID_WORKER_KINDS = {"Task","TermLink","pi","ollama-loop","DRIFT-ONLY-IN-FW"}
BASH
    chmod +x "$TMP_FW/fw"
    # Run the same parity-check python with TMP_FW as the bin/fw under test.
    # Using the resolver from the real framework (parity = false because TMP_FW has DRIFT).
    output=$(python3 - "$TMP_FW/fw" <<PYEOF
import re, sys
sys.path.insert(0, "$FRAMEWORK_ROOT/lib")
from resolver import VALID_WORKER_KINDS as resolver_set
fw_path = sys.argv[1]
fw_set = None
with open(fw_path) as fh:
    for line in fh:
        m = re.match(r'\s*#?\s*VALID_WORKER_KINDS\s*=\s*\{([^}]+)\}', line)
        if m:
            fw_set = {s.strip().strip('"').strip("'") for s in m.group(1).split(',') if s.strip()}
            break
only_fw = fw_set - resolver_set
only_resolver = resolver_set - fw_set
if only_fw or only_resolver:
    parts = []
    if only_fw: parts.append(f"only in bin/fw: {sorted(only_fw)}")
    if only_resolver: parts.append(f"only in lib/resolver.py: {sorted(only_resolver)}")
    print("WARN|drift detected — " + "; ".join(parts))
else:
    print(f"OK|{sorted(fw_set)}")
PYEOF
)
    [[ "$output" == WARN\|* ]]
    echo "$output" | grep -q "DRIFT-ONLY-IN-FW"
    rm -rf "$(dirname "$TMP_FW")"
}

@test "parity literal exists at expected location in lib/workflow_lint.py" {
    # T-2388: T-1946 extracted the bin/fw inline heredoc to lib/worker_kinds_parity.py —
    # bin/fw no longer holds a literal. The two real sources are lib/resolver.py and
    # lib/workflow_lint.py; bin/fw delegates to the parity module.
    grep -E "VALID_WORKER_KINDS\s*=\s*\{" "$FRAMEWORK_ROOT/lib/workflow_lint.py"
}

@test "bin/fw delegates parity check to lib/worker_kinds_parity.py (post-T-1946 shape)" {
    grep -q "worker_kinds_parity.py" "$FRAMEWORK_ROOT/bin/fw"
    [ -f "$FRAMEWORK_ROOT/lib/worker_kinds_parity.py" ]
}

@test "parity literal exists at expected location in lib/resolver.py" {
    grep -E "VALID_WORKER_KINDS\s*=\s*\{" "$FRAMEWORK_ROOT/lib/resolver.py"
}

@test "parity literal in both files is identical (source-of-truth check)" {
    # T-2388: compare the two real sources (lib/workflow_lint.py ↔ lib/resolver.py);
    # bin/fw dropped its literal in the T-1946 heredoc extraction.
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
    [ -n "$lint_set" ]
    [ "$lint_set" = "$resolver_set" ]
}

@test "doctor parity check exits without crashing in fresh shell" {
    run bash -c "cd $FRAMEWORK_ROOT && bin/fw doctor 2>&1 | grep 'Worker-kinds parity'"
    [ "$status" -eq 0 ]
    [ -n "$output" ]
}
