#!/usr/bin/env bats
# T-2711: the self-vendor PRODUCER and the audit GATE must cover the same files.
#
# agents/audit/audit.sh check_self_vendor_drift scans
# .agentic-framework/{bin,lib,agents,web} for *.sh, *.py, fw, claude-fw, *.md and
# blocks the push on any mismatch. Four helpers in lib/upgrade.sh are supposed to
# be able to clear it. Three of them (_self_vendor_libs/_agents/_web) ENUMERATE
# their tree. _self_vendor_shim NAMED two files — `for _shim in fw claude-fw`.
#
# So bin/hook-enable.sh, bin/integrate-go-live.sh, bin/watchtower.sh and
# bin/migrate-horizon-null-completed.sh were gated by the audit and synced by
# nobody: `fw vendor self` said success, `--check` said in-sync, the push gate
# still refused, and its remediation line pointed at the verb that could not fix it.
#
# Third instance of the shape (T-2266 agents/, T-2502 claude-fw, T-2711 bin/*.sh).
# The first two were closed by adding the missing NAME, which is why there was a
# third. Test 3 is the one that matters: it asserts the two SETS are equal, so a
# future bin/ addition cannot re-open the hole without failing here.

load ../test_helper

# The audit's filter, verbatim from agents/audit/audit.sh:1752.
audit_scan() {   # audit_scan <root> <subdir>
    find "$1/$2" \
        \( -path '*/node_modules/*' -o -path '*/__pycache__/*' -o -path '*/.git/*' \) -prune -o \
        -type f \( -name "*.sh" -o -name "*.py" -o -name "fw" -o -name "claude-fw" -o -name "*.md" \) \
        -print 2>/dev/null | sed "s|^$1/$2/||" | sort
}

@test "T-2711: _self_vendor_shim enumerates bin/ instead of naming files" {
    # The hardcoded list is the defect. Its absence is the fix.
    # STRIP COMMENTS FIRST (L-519): the fix's own comment quotes the old loop
    # verbatim to explain it, so a naive grep matches the explanation and the
    # test "fails" on prose. Hit this exact way twice before.
    run bash -c "sed 's/#.*//' '$FRAMEWORK_ROOT/lib/upgrade.sh' | grep -n 'for _shim in fw claude-fw'"
    [ "$status" -ne 0 ]
    # ...and it must select via find, like its three siblings.
    run bash -c "awk '/^_self_vendor_shim\\(\\)/,/^}/' '$FRAMEWORK_ROOT/lib/upgrade.sh' | grep -c 'find '"
    [ "$output" -ge 1 ]
}

@test "T-2711: the four previously-unsyncable bin/ scripts are in the helper's set" {
    helper_set=$(awk '/^_self_vendor_shim\(\)/,/^}/' "$FRAMEWORK_ROOT/lib/upgrade.sh")
    # A name-based helper would have to mention them; an enumerating one need not.
    # So assert behaviourally: the find covers bin/ with the audit's filter.
    echo "$helper_set" | grep -q '\-name "\*\.sh"'
    echo "$helper_set" | grep -q '\-name "\*\.py"'
    echo "$helper_set" | grep -q '\-name "\*\.md"'
    echo "$helper_set" | grep -q '\-name "claude-fw"'
}

@test "T-2711: producer and gate scan sets are IDENTICAL for bin/" {
    src=$(audit_scan "$FRAMEWORK_ROOT" "bin")
    vend=$(audit_scan "$FRAMEWORK_ROOT/.agentic-framework" "bin")
    [ -n "$src" ]
    # Every file the gate can flag in the vendored tree must exist in source, and
    # every source file in scope must have a vendored counterpart. A file in one
    # set but not the other is precisely the T-2711 hole.
    only_src=$(comm -23 <(echo "$src") <(echo "$vend"))
    only_vend=$(comm -13 <(echo "$src") <(echo "$vend"))
    [ -z "$only_src" ] || { echo "in source, never vendored: $only_src"; false; }
    [ -z "$only_vend" ] || { echo "vendored, no source: $only_vend"; false; }
}

@test "T-2711: every in-scope bin/ file is byte-identical to source" {
    while IFS= read -r rel; do
        [ -n "$rel" ] || continue
        cmp -s "$FRAMEWORK_ROOT/bin/$rel" "$FRAMEWORK_ROOT/.agentic-framework/bin/$rel" || {
            echo "DRIFT: bin/$rel"
            false
        }
    done <<< "$(audit_scan "$FRAMEWORK_ROOT" "bin")"
}

@test "T-2711: sync count is computed, not hardcoded" {
    # It printed "1 file(s)" unconditionally — right only by coincidence.
    # Comments stripped (L-519) — the fix documents the old hardcoded string.
    body=$(awk '/^_self_vendor_shim\(\)/,/^}/' "$FRAMEWORK_ROOT/lib/upgrade.sh" | sed 's/[[:space:]]*#.*//')
    run bash -c "printf '%s' \"\$body\" | grep -c 'sync 1 file(s)'"
    [ "$output" = "0" ]
    echo "$body" | grep -q 'sync \$_svs_updated file(s)'
}

@test "T-2711: BEHAVIOURAL — fw vendor self actually re-syncs a drifted bin/*.sh" {
    # The decisive test. The set-equality checks above compare the two TREES and
    # would stay green under the old name-list helper, because both trees already
    # contained all six files. Only running the producer against real drift shows
    # whether it can clear what the gate flags.
    target="$FRAMEWORK_ROOT/.agentic-framework/bin/hook-enable.sh"
    [ -f "$target" ]
    cp "$target" "$TEST_TEMP_DIR/hook-enable.orig"

    printf '\n# T-2711 drift probe\n' >> "$target"
    run cmp -s "$FRAMEWORK_ROOT/bin/hook-enable.sh" "$target"
    [ "$status" -ne 0 ]   # confirm we really did create drift

    run bash -c "cd '$FRAMEWORK_ROOT' && bin/fw vendor self 2>&1"
    [ "$status" -eq 0 ]

    if ! cmp -s "$FRAMEWORK_ROOT/bin/hook-enable.sh" "$target"; then
        cp "$TEST_TEMP_DIR/hook-enable.orig" "$target"   # restore before failing
        echo "fw vendor self did NOT re-sync bin/hook-enable.sh — the T-2711 hole is open"
        false
    fi
}

@test "T-2711: NEGATIVE CONTROL — a new bin/*.sh is picked up without editing the helper" {
    # The whole point of enumerating. Build the helper's set against a fixture
    # tree containing a file no helper could possibly name.
    fake="$TEST_TEMP_DIR/bin"
    mkdir -p "$fake"
    printf '#!/bin/sh\n' > "$fake/brand-new-tool.sh"
    printf '#!/bin/sh\n' > "$fake/fw"

    found=$(find "$fake" \
        \( -path '*/node_modules/*' \) -prune -o \
        -type f \( -name "*.sh" -o -name "*.py" -o -name "fw" -o -name "claude-fw" -o -name "*.md" \) \
        -print 2>/dev/null | sed "s|^$fake/||" | sort)

    echo "$found" | grep -qx 'brand-new-tool.sh'
    echo "$found" | grep -qx 'fw'
    # And confirm the OLD approach would have missed it — this is what makes the
    # control meaningful rather than decorative.
    old_set="fw claude-fw"
    case " $old_set " in
        *" brand-new-tool.sh "*) echo "old name-list would have caught it — control is void"; false ;;
    esac
}
