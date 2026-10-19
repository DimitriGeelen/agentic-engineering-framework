#!/usr/bin/env bats
# T-2244: audit self-vendor drift FAIL (F2 N×M daily-cron backstop).
# Mirror of t2243 (doctor leg) but at the audit surface — daily cron
# catches anything that slipped past the developer-facing gates.
#
# Audit's structure section runs `check_self_vendor_drift`. These tests drift
# one vendored file and assert the FAIL line names the affected class.
#
# T-4385: the tests used to mutate the LIVE .agentic-framework/ and run the
# whole live `fw audit --section structure` twice. That section takes ~690 s
# on this repo (timing ledger 2026-10-19, timed_out: true), so the file never
# finished inside the suite's per-file cap and was red in 20/20 reports — and
# while it ran, every concurrent audit on the host saw the planted drift. They
# now run the real function body, extracted from audit.sh (same technique as
# t2298), against a synthetic framework root: seconds, and nothing live is
# touched. A static check pins that the structure section still calls it.
#
# T-4385 also follows T-2436: the libs-class mitigation is `fw vendor self`
# again (it syncs every vendored class since T-2264/T-2266/T-2267). T-2247's
# "must NOT say fw vendor self" assertion pinned the wording T-2436 reversed.

load ../test_helper

AUDIT_SH="$FRAMEWORK_ROOT/agents/audit/audit.sh"

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    SYN="$TEST_TEMP_DIR/fw"
    mkdir -p "$SYN/lib" "$SYN/.tasks/templates" \
             "$SYN/.agentic-framework/lib" "$SYN/.agentic-framework/.tasks/templates"
    printf '#!/usr/bin/env bash\necho upgrade\n' > "$SYN/lib/upgrade.sh"
    printf '# default template\n' > "$SYN/.tasks/templates/default.md"
    cp "$SYN/lib/upgrade.sh" "$SYN/.agentic-framework/lib/upgrade.sh"
    cp "$SYN/.tasks/templates/default.md" "$SYN/.agentic-framework/.tasks/templates/default.md"
    export SYN
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# Runs the real check_self_vendor_drift body from audit.sh on $SYN. pass/fail
# are stubbed to print what audit's own pass()/fail() print (title, Evidence,
# Mitigation); _t3126_git_ok reports "no git", which the function treats as
# "every pair drifts in HEAD" (its fail-safe branch).
_run_check() {
    local fn
    fn="$(awk '/^check_self_vendor_drift\(\) \{/,/^}/' "$AUDIT_SH")"
    [ -n "$fn" ] || { echo "check_self_vendor_drift() not found in audit.sh"; return 1; }
    FRAMEWORK_ROOT="$SYN" PROJECT_ROOT="$SYN" bash -c '
        pass() { echo "[PASS] $1"; }
        fail() { echo "[FAIL] $1"; echo "       Evidence: $2"; echo "       Mitigation: $3"; }
        _t3126_git_ok() { return 1; }
        eval "$1"
        check_self_vendor_drift
    ' _ "$fn"
}

@test "t2244 t0: the structure section still calls check_self_vendor_drift" {
    grep -q '^check_self_vendor_drift$' "$AUDIT_SH"
    sec_start=$(grep -n '^if should_run_section "structure"; then' "$AUDIT_SH" | head -1 | cut -d: -f1)
    call=$(grep -n '^check_self_vendor_drift$' "$AUDIT_SH" | head -1 | cut -d: -f1)
    [ -n "$sec_start" ] && [ "$call" -gt "$sec_start" ]
}

@test "t2244 t1: no drift → PASS, no FAIL (control)" {
    run _run_check
    [ "$status" -eq 0 ]
    [[ "$output" == *"[PASS] Self-vendor drift"* ]]
    [[ "$output" != *"[FAIL]"* ]]
}

@test "t2244 t2: libs-only drift → FAIL line names libs class" {
    echo "# T-2244 audit libs drift sentinel" >> "$SYN/.agentic-framework/lib/upgrade.sh"
    run _run_check
    [[ "$output" == *"Self-vendor drift: libs class"* ]] || { echo "$output"; return 1; }
    [[ "$output" == *"upgrade.sh"* ]] || { echo "$output"; return 1; }
    [[ "$output" == *"Run: fw vendor self"* ]] || { echo "$output"; return 1; }
    [[ "$output" != *"templates class"* ]] || { echo "$output"; return 1; }
}

@test "t2244 t3: templates-only drift → FAIL line names templates class" {
    echo "<!-- T-2244 audit templates drift sentinel -->" >> "$SYN/.agentic-framework/.tasks/templates/default.md"
    run _run_check
    [[ "$output" == *"Self-vendor drift: templates class"* ]] || { echo "$output"; return 1; }
    [[ "$output" == *".tasks/templates/default.md"* ]] || { echo "$output"; return 1; }
    [[ "$output" == *"fw vendor self"* ]] || { echo "$output"; return 1; }
    [[ "$output" != *"libs class"* ]] || { echo "$output"; return 1; }
}
