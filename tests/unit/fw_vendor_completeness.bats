#!/usr/bin/env bats
# T-2805 — a partial vendor must not capture the router, and FRAMEWORK.md must be
# the last thing a vendor writes.
#
# The defect: bin/fw-router accepted `-x .agentic-framework/bin/fw` as proof of a
# usable vendor, while bin/fw itself resolves FRAMEWORK_ROOT by FRAMEWORK.md
# (bin/fw:96,128,155) and install.sh scans for the same file (install.sh:210).
# Two implementations of one predicate, disagreeing — so the router would hand
# over to a CLI that was about to reject the very directory it was handed.
#
# What that cost: a directory with a half-copied .agentic-framework/ could not be
# repaired by `fw init`, because that call routed into the broken copy and died
# "Cannot find framework installation" — whose own advice is "Run 'fw init' in
# your project directory". Only `rm -rf` recovered it. Reported from the field as
# /opt/2345-test-install, reproduced 2026-08-05.
#
# T-2801 shipped a .fw-init-incomplete MARKER for this class. A marker is a
# DECLARED signal: it cannot cover a vendor that predates it, nor a crash before
# the write. Its absence was being read as evidence of completeness, which it
# never was. FRAMEWORK.md is the OBSERVED signal, and do_vendor now writes it
# last so that presence means the copy finished. Both are kept — see the router.

bats_require_minimum_version 1.5.0

ROUTER() { echo "$BATS_TEST_DIRNAME/../../bin/fw-router"; }
FW() { echo "$BATS_TEST_DIRNAME/../../bin/fw"; }

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    PROJ="$TEST_TEMP_DIR/proj"
    GLOBAL="$TEST_TEMP_DIR/global"

    # A stub global install. The router only requires bin/fw to be executable.
    mkdir -p "$GLOBAL/bin"
    printf '#!/bin/sh\necho STUB_GLOBAL\n' > "$GLOBAL/bin/fw"
    chmod +x "$GLOBAL/bin/fw"

    # A vendored consumer, deliberately WITHOUT FRAMEWORK.md — the shape
    # do_vendor leaves behind if it is interrupted, since `bin` is copied first.
    mkdir -p "$PROJ/.agentic-framework/bin"
    printf '#!/bin/sh\necho STUB_VENDOR\n' > "$PROJ/.agentic-framework/bin/fw"
    chmod +x "$PROJ/.agentic-framework/bin/fw"
}

teardown() {
    [ -n "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
    return 0
}

# Run the router from inside $PROJ with a controlled global.
_route() {
    ( cd "$PROJ" && env FW_GLOBAL_ROOT="$GLOBAL" HOME="$TEST_TEMP_DIR" "$(ROUTER)" "$@" )
}

@test "a vendor with no FRAMEWORK.md does not capture the router" {
    # T-2856: this test used to assert the router fell back to the GLOBAL install
    # (STUB_GLOBAL in output, exit 0). T-2854 removed that fallback to complete
    # D-377 — nothing consults $HOME/.agentic-framework anymore — so the expected
    # outcome changed from "hands over to global" to "refuses with a recovery
    # path". The property T-2805 wrote this test to protect is unchanged and still
    # asserted: a partial vendor must not capture the router.
    run _route ignored-arg
    [ "$status" -eq 127 ]
    ! echo "$output" | grep -q 'STUB_VENDOR'
    # And it must not reach a global either — there is no longer any to reach.
    ! echo "$output" | grep -q 'STUB_GLOBAL'
}

@test "the refusal names the directory and says what to run" {
    run _route ignored-arg
    echo "$output" | grep -q "$PROJ"
    echo "$output" | grep -q 'is incomplete'
    # The old failure sent the user back to the command that had just failed, so
    # the replacement has to be actionable from where they are standing. Post
    # T-2854 that action is the installer pointed at this project (`fw init`
    # cannot repair a copy it would have to route through), plus a discard path.
    echo "$output" | grep -q 'install.sh'
    echo "$output" | grep -q 'rm -rf'
}

@test "non-vacuity — a COMPLETE vendor is still routed to" {
    # Without this, the fix could be "always fall back to global" and every test
    # above would still pass.
    touch "$PROJ/.agentic-framework/FRAMEWORK.md"
    run _route ignored-arg
    [ "$status" -eq 0 ]
    echo "$output" | grep -q 'STUB_VENDOR'
    ! echo "$output" | grep -q 'STUB_GLOBAL'
}

@test "T-2801 marker still wins even when FRAMEWORK.md is present" {
    # The observed signal is added, not substituted: a vendor interrupted after
    # FRAMEWORK.md lands is still caught by the declared one.
    touch "$PROJ/.agentic-framework/FRAMEWORK.md"
    touch "$PROJ/.fw-init-incomplete"
    run _route ignored-arg
    [ "$status" -eq 127 ]
    ! echo "$output" | grep -q 'STUB_VENDOR'
}

@test "a marker-triggered refusal says it was the marker, not a missing FRAMEWORK.md" {
    # T-2856. Both signals reached one refusal that only ever described the
    # sentinel, so this case told the operator ".agentic-framework/ has a bin/fw
    # but no FRAMEWORK.md" while FRAMEWORK.md was sitting right there. The refusal
    # was right and its stated reason was false — the kind of message that sends
    # someone looking for the wrong thing.
    touch "$PROJ/.agentic-framework/FRAMEWORK.md"
    touch "$PROJ/.fw-init-incomplete"
    run _route ignored-arg
    [ "$status" -eq 127 ]
    echo "$output" | grep -q '.fw-init-incomplete marker is present'
    ! echo "$output" | grep -q 'no FRAMEWORK.md'
}

@test "NEGATIVE CONTROL: the sentinel case still gets the sentinel diagnosis" {
    # Guards the test above from being satisfied by making every refusal say
    # "marker". No marker here — only a missing FRAMEWORK.md.
    run _route ignored-arg
    [ "$status" -eq 127 ]
    echo "$output" | grep -q 'no FRAMEWORK.md'
    ! echo "$output" | grep -q 'marker is present'
}

@test "no global and an incomplete vendor exits 127 with a recovery path" {
    rm -rf "$GLOBAL"
    run -127 _route ignored-arg
    echo "$output" | grep -q 'incomplete'
    echo "$output" | grep -q 'install.sh'
    echo "$output" | grep -q 'rm -rf'
}

@test "do_vendor writes FRAMEWORK.md last, not eighth of twelve" {
    # Ordering invariant, checked structurally: FRAMEWORK.md must NOT sit in the
    # includes[] array (which is copied in order, `bin` first), and its copy must
    # appear after the loop that consumes that array.
    #
    # A behavioural version of this test would have to kill a vendor mid-copy and
    # race the filesystem; this pins the same property deterministically.
    local src; src="$(FW)"
    local inc_start inc_end fmd_line
    inc_start=$(grep -n 'local includes=(' "$src" | head -1 | cut -d: -f1)
    inc_end=$(awk -v s="$inc_start" 'NR>=s && /^    \)$/ {print NR; exit}' "$src")
    [ -n "$inc_start" ] && [ -n "$inc_end" ]

    # Not inside the array.
    run bash -c "sed -n '${inc_start},${inc_end}p' '$src' | grep -E '^[[:space:]]+FRAMEWORK\.md[[:space:]]*$'"
    [ "$status" -ne 0 ]

    # Copied after the array ends.
    fmd_line=$(grep -n 'cp "\$vendor_source/FRAMEWORK.md" "\$dest/FRAMEWORK.md"' "$src" | head -1 | cut -d: -f1)
    [ -n "$fmd_line" ]
    [ "$fmd_line" -gt "$inc_end" ]
}
