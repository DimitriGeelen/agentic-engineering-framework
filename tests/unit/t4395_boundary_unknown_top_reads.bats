#!/usr/bin/env bats
# T-4395 — the boundary read check skipped every path under a top-level directory not
# in KNOWN_TOPS (`cat /<nas-mount>/x`, `/work/x`, `/data/x`): `_read_outside` commented
# "at least 2 slashes OR a known top-level dir" but only implemented the second clause.
#
# Fix: a path with >= 2 slashes is judged when its top-level directory EXISTS on the
# host. A top that does not exist has nothing to read, and skipping it keeps sed/awk
# regex words (`/^## X/,/^## /p`, `/foo/p`) from becoming false positives.
#
# The hook is FED each command; nothing here is executed. The probe top-level dir is
# created for the run (and removed after) so the test never depends on host layout.

setup_file() {
    export T4395_TOP="/t4395-probe-$$"
    mkdir -p "$T4395_TOP"
}

teardown_file() {
    rmdir "$T4395_TOP" 2>/dev/null || true
}

setup() {
    FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    HOOK="$FRAMEWORK_ROOT/agents/context/check-project-boundary.sh"
    P="$T4395_TOP/other/x"                 # under an existing, unknown top; never created
    GONE="/t4395-absent-$$"                # a top-level dir that does not exist
    unset PROJECT_ROOT
    CWD="$FRAMEWORK_ROOT"
}

hook() {
    local json
    json=$(python3 -c 'import json,sys
print(json.dumps({"tool_name":"Bash","tool_input":{"command":sys.argv[1]},"cwd":sys.argv[2]}))' "$1" "$CWD")
    output=$(printf '%s' "$json" | bash "$HOOK" 2>&1)
    return $?
}

assert_blocked() {
    local rc=0
    hook "$1" || rc=$?
    [ "$rc" -eq 2 ] || { echo "expected BLOCKED (rc 2), got rc=$rc for: $1" >&2; echo "$output" >&2; return 1; }
}

assert_allowed() {
    local rc=0
    hook "$1" || rc=$?
    [ "$rc" -eq 0 ] || { echo "expected ALLOWED (rc 0), got rc=$rc for: $1" >&2; echo "$output" >&2; return 1; }
}

# ── the reported shape: an existing top-level dir outside KNOWN_TOPS ────────────

@test "cat under an unknown existing top is refused" {
    assert_blocked "cat $P"
}

@test "grep under an unknown existing top is refused" {
    assert_blocked "grep -n foo $P"
}

@test "head under an unknown existing top is refused" {
    assert_blocked "head -5 $P"
}

@test "sed -n under an unknown existing top is refused" {
    assert_blocked "sed -n 1,5p $P"
}

@test "quoted path under an unknown existing top is refused (Pattern 4b)" {
    assert_blocked "cat \"$P\""
}

@test "single-quoted path under an unknown existing top is refused" {
    assert_blocked "cat '$P'"
}

@test "relative path that resolves under an unknown existing top is refused" {
    local up rel
    up=$(python3 -c 'import os,sys;print(os.path.relpath("/", sys.argv[1]))' "$CWD")
    rel="$up${T4395_TOP}/other/x"
    assert_blocked "cat $rel"
}

@test "the real NAS mount on this host is refused when present" {
    local nas="/Nas$(printf 'Ring%s' 20)"
    [ -d "$nas" ] || return 0               # host-specific; the probe tests carry the claim
    assert_blocked "cat $nas/x"
}

# ── unchanged: allowed paths ─────────────────────────────────────────────────

@test "in-project absolute path is allowed" {
    assert_allowed "cat $FRAMEWORK_ROOT/README.md"
}

@test "in-project relative path is allowed" {
    assert_allowed "cat ./README.md"
}

@test "/tmp path is allowed" {
    assert_allowed "cat /tmp/t4395-x"
}

@test "/usr path is allowed" {
    assert_allowed "head /usr/share/dict/words"
}

@test "/etc path is allowed" {
    assert_allowed "grep root /etc/hostname"
}

# ── unchanged: KNOWN_TOPS still refused ──────────────────────────────────────

@test "known top (/srv/other) is still refused" {
    assert_blocked "cat /srv/other/x"
}

# ── false-positive pins: regex words and absent tops ─────────────────────────

@test "sed range regex with slashes is not flagged" {
    assert_allowed "sed -n '/^## Verification/,/^## /p' README.md"
}

@test "unquoted sed address regex is not flagged" {
    assert_allowed "sed -n /foo/p README.md"
}

@test "awk regex pattern is not flagged" {
    assert_allowed "awk '/start/,/end/' README.md"
}

@test "grep for a slash-y literal is not flagged" {
    assert_allowed "grep -n '/api/v1/tasks' README.md"
}

@test "single-slash token is not flagged" {
    assert_allowed "grep -n /foo README.md"
}

@test "path under a top-level dir that does not exist is not flagged" {
    assert_allowed "cat $GONE/x/y"
}
