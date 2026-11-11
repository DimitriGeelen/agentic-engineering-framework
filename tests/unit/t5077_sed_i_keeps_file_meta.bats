#!/usr/bin/env bats
# T-5077 (832 T-1393) — _sed_i rewrote a file through mktemp (0600) + mv, so every
# file it edited became 0600. On a repo reached through a POSIX ACL, 0600 also
# zeroes the ACL mask: named users lost all access (832: 634 task files; AEF:
# 1,639). `fw task update` writes task files through _sed_i.

ROOT() { echo "$BATS_TEST_DIRNAME/../.."; }

setup() {
    T="$(mktemp -d)"
    F="$T/file.md"
    printf 'status: a\n' > "$F"
}

teardown() { rm -rf "$T"; }

sed_i() { bash -c 'source "$1/lib/compat.sh"; _sed_i "$2" "$3"' _ "$(ROOT)" "$@"; }

@test "T-5077: _sed_i keeps a 0664 file at 0664" {
    chmod 0664 "$F"
    sed_i 's/: a/: b/' "$F"
    [ "$(cat "$F")" = "status: b" ]
    [ "$(stat -c %a "$F")" = "664" ]
}

@test "T-5077: _sed_i keeps a 0644 file at 0644 (no widening either)" {
    chmod 0644 "$F"
    sed_i 's/: a/: b/' "$F"
    [ "$(stat -c %a "$F")" = "644" ]
}

@test "T-5077: _sed_i keeps a named-user ACL entry effective" {
    command -v setfacl >/dev/null 2>&1 && command -v getfacl >/dev/null 2>&1 || skip "no ACL tools"
    chmod 0664 "$F"
    setfacl -m u:nobody:rw "$F" 2>/dev/null || skip "file system without ACL support"
    sed_i 's/: a/: b/' "$F"
    run getfacl -p "$F"
    [[ "$output" == *"user:nobody:rw-"* ]]
    [[ "$output" != *"#effective:---"* ]]
    [[ "$output" == *"mask::rw"* ]]
}

@test "T-5077: _sed_i keeps the owner when run as root" {
    [ "$(id -u)" = "0" ] || skip "needs root to own a file as someone else"
    chown nobody "$F"
    sed_i 's/: a/: b/' "$F"
    [ "$(stat -c %U "$F")" = "nobody" ]
}

@test "T-5077: a failed sed leaves the file and no temp file behind" {
    chmod 0664 "$F"
    run sed_i 's/: a/: b' "$F"
    [ "$status" -ne 0 ]
    [ "$(cat "$F")" = "status: a" ]
    [ "$(ls "$T" | wc -l)" -eq 1 ]
}
