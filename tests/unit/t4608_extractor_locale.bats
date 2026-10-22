#!/usr/bin/env bats
# T-4608 — the T-3232 extraction-failure contract must not depend on the locale.
#
# With LANG/LC_* unset (or C/POSIX), Python 3.7+ runs in UTF-8 mode (PEP 540)
# and sys.stdin decodes with surrogateescape. lib/comment_strip.py read stdin
# through that, so an undecodable byte in a Verification block passed silently:
# extract_verification_block returned 0 and the P-011 gate's rc-2 refusal never
# fired on such a host (cloud runners, cron, env -i). t3232 was green only where
# the runner happened to export LANG=en_US.UTF-8.
#
# Each test pins the locale itself, so this file measures the same thing on
# every host — the property t3232 silently inherited from its caller.

setup() {
    FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-$(cd "$BATS_TEST_DIRNAME/../.." && pwd)}"
    T="$(mktemp -d)"
    { printf '# T-9999\n\n## Verification\n\ntrue\n'
      printf 'echo h\xffi\n'
      printf '\n## RCA\n'; } > "$T/dirty.md"
    printf '# T-9999\n\n## Verification\n\ntrue\necho h\xc3\xa9\n\n## RCA\n' > "$T/clean.md"
}

teardown() {
    if [ -n "${T:-}" ]; then rm -rf "$T"; fi
    return 0
}

# $1 = file; remaining args = env assignments/unsets for `env`
_extract() {
    local f="$1"; shift
    env "$@" FRAMEWORK_ROOT="$FRAMEWORK_ROOT" bash -c \
        'source "$FRAMEWORK_ROOT/lib/verification-port.sh"; extract_verification_block "$1"' _ "$f"
}

@test "locale unset: an undecodable block returns 2 with empty stdout" {
    run _extract "$T/dirty.md" -u LANG -u LC_ALL -u LC_CTYPE
    [ "$status" -eq 2 ]
    [ -z "$output" ]
}

@test "LC_ALL=C: an undecodable block returns 2" {
    run _extract "$T/dirty.md" LC_ALL=C LANG=C
    [ "$status" -eq 2 ]
}

# C.UTF-8 (the usual container default) is NOT safe either: CPython gives stdin
# surrogateescape for C.UTF-8 as well as for C/POSIX. Only en_US.UTF-8-style
# locales were strict, which is why t3232 passed on the origin host alone.
@test "LC_ALL=C.UTF-8: an undecodable block returns 2" {
    run _extract "$T/dirty.md" LC_ALL=C.UTF-8
    [ "$status" -eq 2 ]
}

@test "locale unset: valid UTF-8 (non-ASCII) still extracts byte-identical" {
    run _extract "$T/clean.md" -u LANG -u LC_ALL -u LC_CTYPE
    [ "$status" -eq 0 ]
    [ "$output" = "$(printf 'true\necho h\xc3\xa9')" ]
}

@test "LC_ALL=C: valid UTF-8 (non-ASCII) still extracts byte-identical" {
    run _extract "$T/clean.md" LC_ALL=C LANG=C
    [ "$status" -eq 0 ]
    [ "$output" = "$(printf 'true\necho h\xc3\xa9')" ]
}
