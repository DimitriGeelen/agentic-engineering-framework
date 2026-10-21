#!/usr/bin/env bats
# T-2661: do_vendor ships four ROOT single files (.secret-scan-patterns,
# .secret-scan-allowlist, status-transitions.yaml, metrics.sh) but no
# _self_vendor_* class synced or checked them, and the audit's drift scan did not
# look at them. Field state at filing: .agentic-framework/.secret-scan-allowlist
# 666 bytes behind its source while `fw vendor self --check` said in-sync.
#
#   t1  helper syncs a changed and a missing root data file
#   t2  helper dry-run says "would sync N root data" and mutates nothing
#   t3  consumer-safe: no .agentic-framework/ → no-op
#   t4  --check in a clean clone goes red on planted .secret-scan-allowlist drift
#   t5  audit drift scan names every file in the helper's list (parity)

load ../test_helper

setup() {
    export FRAMEWORK_ROOT
    export NO_COLOR=1
    source "$FRAMEWORK_ROOT/lib/colors.sh"
    source "$FRAMEWORK_ROOT/lib/upgrade.sh"
}

teardown() { :; }   # temp dirs live under BATS_TEST_TMPDIR

_syn_fw() {
    SYN="$BATS_TEST_TMPDIR/syn"
    mkdir -p "$SYN/.agentic-framework"
    printf 'aws\tAKIA[0-9A-Z]{16}\n' > "$SYN/.secret-scan-patterns"
    echo "new-allow" > "$SYN/.secret-scan-allowlist"
    echo "old-allow" > "$SYN/.agentic-framework/.secret-scan-allowlist"
    echo "same" > "$SYN/status-transitions.yaml"
    echo "same" > "$SYN/.agentic-framework/status-transitions.yaml"
}

@test "t2661 t1: _self_vendor_root_data syncs changed + missing root data files" {
    _syn_fw
    FRAMEWORK_ROOT="$SYN" FW_VENDOR_ALL=1 run _self_vendor_root_data false
    [ "$status" -eq 0 ]
    [[ "$output" == *"synced 2 root data file(s)"* ]] || { echo "$output"; return 1; }
    cmp -s "$SYN/.secret-scan-allowlist" "$SYN/.agentic-framework/.secret-scan-allowlist"
    cmp -s "$SYN/.secret-scan-patterns" "$SYN/.agentic-framework/.secret-scan-patterns"
}

@test "t2661 t2: _self_vendor_root_data dry-run reports and never mutates" {
    _syn_fw
    FRAMEWORK_ROOT="$SYN" run _self_vendor_root_data true
    [ "$status" -eq 0 ]
    [[ "$output" == *"would sync 2 root data file(s)"* ]] || { echo "$output"; return 1; }
    grep -qx old-allow "$SYN/.agentic-framework/.secret-scan-allowlist"
    [ ! -e "$SYN/.agentic-framework/.secret-scan-patterns" ]
}

@test "t2661 t3: consumer-safe — no nested .agentic-framework/ means no-op" {
    SYN="$BATS_TEST_TMPDIR/cons"; mkdir -p "$SYN"
    echo a > "$SYN/.secret-scan-patterns"
    FRAMEWORK_ROOT="$SYN" FW_VENDOR_ALL=1 run _self_vendor_root_data false
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    [ ! -e "$SYN/.agentic-framework" ]
}

# Before T-2661 --check stayed 0 here: no class looked at root data files.
@test "t2661 t4: vendor self --check exits 1 on planted .secret-scan-allowlist drift" {
    CL="$BATS_TEST_TMPDIR/fw"
    git clone -q --shared "$FRAMEWORK_ROOT" "$CL"
    # Test the code under edit, not HEAD's: overlay the files this fix touches.
    cp "$FRAMEWORK_ROOT/bin/fw" "$CL/bin/fw"
    cp "$FRAMEWORK_ROOT/lib/upgrade.sh" "$CL/lib/upgrade.sh"
    git -C "$CL" -c user.email=t@t -c user.name=t commit -qm "T-2661: overlay" -- bin/fw lib/upgrade.sh >/dev/null 2>&1 || true
    _cfw() { ( cd "$CL" && env -u PROJECT_ROOT -u FRAMEWORK_ROOT -u CLAUDE_PROJECT_DIR "$CL/bin/fw" "$@" ); }
    _cfw vendor self >/dev/null 2>&1 || true
    git -C "$CL" add -A .agentic-framework
    git -C "$CL" -c user.email=t@t -c user.name=t commit -qm "T-2661: baseline sync" >/dev/null 2>&1 || true
    run _cfw vendor self --check
    [ "$status" -eq 0 ] || { echo "clone not clean after sync: $output"; return 1; }
    printf 't2661-planted-drift\n' >> "$CL/.secret-scan-allowlist"
    git -C "$CL" -c user.email=t@t -c user.name=t commit -qam "T-2661: planted allowlist drift"
    run _cfw vendor self --check
    [ "$status" -eq 1 ] || { echo "$output"; return 1; }
    [[ "$output" == *"root data"* ]]
    [[ "$output" == *"DRIFT"* ]]
    ! grep -q 't2661-planted-drift' "$CL/.agentic-framework/.secret-scan-allowlist" || false
    # ...and a real sync clears it.
    _cfw vendor self >/dev/null 2>&1 || true
    grep -q 't2661-planted-drift' "$CL/.agentic-framework/.secret-scan-allowlist"
}

@test "t2661 t5: audit drift scan covers every root data file the helper syncs" {
    body=$(awk '/^check_self_vendor_drift\(\)/,/^}/' "$FRAMEWORK_ROOT/agents/audit/audit.sh" | sed 's/[[:space:]]*#.*//')
    [ -n "$_SELF_VENDOR_ROOT_DATA" ]
    for f in $_SELF_VENDOR_ROOT_DATA; do
        printf '%s' "$body" | grep -qF -- "$f" || { echo "audit misses $f"; return 1; }
    done
}
