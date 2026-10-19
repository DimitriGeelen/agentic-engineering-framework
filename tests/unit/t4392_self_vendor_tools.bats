#!/usr/bin/env bats
# T-4392: `fw vendor self` neither synced nor checked tools/, so the tracked
# .agentic-framework/tools/ copies went stale behind a green --check (corpus_spec.py,
# bpmn_to_tasks.py after T-4387..T-4389). `fw corpus explain` reads that copy wherever
# the vendored fw runs (T-2942), and do_vendor ships tools/ whole to consumers.
#
#   t1  helper syncs a changed and a missing tools/ file, skips __pycache__
#   t2  helper dry-run says "would sync N tools/" and mutates nothing
#   t3  consumer-safe: no .agentic-framework/tools/ → no-op
#   t4  --check in a clean clone goes red (exit 1, names tools/) on planted tools/ drift
#   t5  the audit's self-vendor drift scan enumerates .agentic-framework/tools

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
    mkdir -p "$SYN/tools/sub" "$SYN/tools/__pycache__" "$SYN/.agentic-framework/tools"
    echo "same" > "$SYN/tools/same.py";     echo "same" > "$SYN/.agentic-framework/tools/same.py"
    echo "new"  > "$SYN/tools/changed.py";  echo "old"  > "$SYN/.agentic-framework/tools/changed.py"
    echo "x"    > "$SYN/tools/sub/added.md"
    echo "c"    > "$SYN/tools/__pycache__/junk.pyc"
}

@test "t4392 t1: _self_vendor_tools syncs changed + missing files, skips __pycache__" {
    _syn_fw
    FRAMEWORK_ROOT="$SYN" FW_VENDOR_ALL=1 run _self_vendor_tools false
    [ "$status" -eq 0 ]
    [[ "$output" == *"synced 2 tools/ file(s)"* ]] || { echo "$output"; return 1; }
    cmp -s "$SYN/tools/changed.py" "$SYN/.agentic-framework/tools/changed.py"
    [ -f "$SYN/.agentic-framework/tools/sub/added.md" ]
    [ ! -e "$SYN/.agentic-framework/tools/__pycache__" ]
}

@test "t4392 t2: _self_vendor_tools dry-run reports and never mutates" {
    _syn_fw
    FRAMEWORK_ROOT="$SYN" run _self_vendor_tools true
    [ "$status" -eq 0 ]
    [[ "$output" == *"would sync 2 tools/ file(s)"* ]] || { echo "$output"; return 1; }
    grep -qx old "$SYN/.agentic-framework/tools/changed.py"
    [ ! -e "$SYN/.agentic-framework/tools/sub" ]
}

@test "t4392 t3: consumer-safe — no vendored tools/ dir means no-op" {
    SYN="$BATS_TEST_TMPDIR/cons"; mkdir -p "$SYN/tools" "$SYN/.agentic-framework"
    echo a > "$SYN/tools/a.py"
    FRAMEWORK_ROOT="$SYN" FW_VENDOR_ALL=1 run _self_vendor_tools false
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    [ ! -e "$SYN/.agentic-framework/tools" ]
}

# Clone HEAD, make it clean with a real sync, then plant committed tools/ drift.
# Before T-4392 --check stayed 0 here: no class looked at tools/.
@test "t4392 t4: vendor self --check exits 1 and names tools/ on planted tools/ drift" {
    CL="$BATS_TEST_TMPDIR/fw"
    git clone -q --shared "$FRAMEWORK_ROOT" "$CL"
    # Test the code under edit, not HEAD's: overlay the files this fix touches.
    cp "$FRAMEWORK_ROOT/bin/fw" "$CL/bin/fw"
    cp "$FRAMEWORK_ROOT/lib/upgrade.sh" "$CL/lib/upgrade.sh"
    # Committed first: a real sync withholds uncommitted source (T-3165).
    git -C "$CL" -c user.email=t@t -c user.name=t commit -qm "T-4392: overlay" -- bin/fw lib/upgrade.sh >/dev/null 2>&1 || true
    _cfw() { ( cd "$CL" && env -u PROJECT_ROOT -u FRAMEWORK_ROOT -u CLAUDE_PROJECT_DIR "$CL/bin/fw" "$@" ); }
    _cfw vendor self >/dev/null 2>&1 || true
    git -C "$CL" add -A .agentic-framework
    git -C "$CL" -c user.email=t@t -c user.name=t commit -qm "T-4392: baseline sync" >/dev/null 2>&1 || true
    run _cfw vendor self --check
    [ "$status" -eq 0 ] || { echo "clone not clean after sync: $output"; return 1; }
    printf '# t4392 planted drift\n' >> "$CL/tools/corpus_spec.py"
    git -C "$CL" -c user.email=t@t -c user.name=t commit -qam "T-4392: planted tools drift"
    run _cfw vendor self --check
    [ "$status" -eq 1 ] || { echo "$output"; return 1; }
    [[ "$output" == *"tools/"* ]]
    [[ "$output" == *"DRIFT"* ]]
    ! grep -q 't4392 planted drift' "$CL/.agentic-framework/tools/corpus_spec.py"
}

@test "t4392 t5: audit self-vendor drift scan covers .agentic-framework/tools" {
    awk '/^check_self_vendor_drift\(\)/,/^}/' "$FRAMEWORK_ROOT/agents/audit/audit.sh" \
        | grep -q '\.agentic-framework/tools'
}
