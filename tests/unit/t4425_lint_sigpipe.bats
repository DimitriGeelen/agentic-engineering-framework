#!/usr/bin/env bats
# T-4425: `fw test lint` printed each failing file's findings with
# `echo "$_sc_output" | head -5 | sed ...` under `set -euo pipefail`. Once the
# findings outgrew what head read, echo took SIGPIPE, the pipeline returned 141
# and errexit killed fw before the Lint summary, the Silent-Skip lint and the
# Test-Isolation lint ran. The sibling `echo | grep -q "error"` had the same
# shape and could misclassify an error file as WARN.
#
# A fake shellcheck on PATH emits 5000 lines (~190 KB, far over the 64 KB pipe
# buffer) so the old pipe SIGPIPEs deterministically on the first file.

setup() {
    ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    mkdir -p "$BATS_TEST_TMPDIR/bin"
}

_fake_shellcheck() {
    # $1 = first line of the findings, then 5000 filler lines; exit 1 = findings.
    cat > "$BATS_TEST_TMPDIR/bin/shellcheck" <<EOF
#!/bin/sh
echo "$1"
yes "In x line 1: SC2086 (warning): Double quote to prevent globbing." | head -n 5000
exit 1
EOF
    chmod +x "$BATS_TEST_TMPDIR/bin/shellcheck"
}

@test "fw test lint survives >5 lines of findings and reaches every later step" {
    _fake_shellcheck "In x line 1: SC2034 (warning): unused."
    run bash -c "cd '$ROOT' && PATH='$BATS_TEST_TMPDIR/bin':\"\$PATH\" timeout 600 bin/fw test lint 2>&1"
    [ "$status" -ne 141 ]
    [ "$status" -ne 124 ]
    grep -q "Lint:.* warn, 0 fail" <<<"$output"
    grep -q "=== Silent-Skip Lint ===" <<<"$output"
    grep -q "=== Test-Isolation Lint ===" <<<"$output"
}

@test "an error finding on the first line of a large output is classified FAIL" {
    _fake_shellcheck "In x line 1: SC1072 (error): Fix any mentioned problems."
    run bash -c "cd '$ROOT' && PATH='$BATS_TEST_TMPDIR/bin':\"\$PATH\" timeout 600 bin/fw test lint 2>&1"
    [ "$status" -ne 141 ]
    [ "$status" -eq 1 ]
    grep -q "Lint:.* 0 warn, [1-9][0-9]* fail" <<<"$output"
}
