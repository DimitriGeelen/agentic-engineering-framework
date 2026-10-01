#!/usr/bin/env bats
#
# T-3643 — a redirect to /dev/null is not a write, and `curl -o /dev/null` is
# not a download. Ported from 055-agentic-fleet-cockpit (framework:pickup
# offset 224, their task 313, commit f51443f), re-derived against our code.
#
# Before: has_bash_write_pattern('cat a > /dev/null') = WRITE, and
# is_bash_safe_command('curl -sf http://x/ -o /dev/null') = unsafe, so with no
# focus /resume Step 1 was blocked. The T-3344 strip in is_bash_safe_command
# covered the allowlist side only; check-active-task consults the write scan
# FIRST.
#
# The negative corpus is load-bearing: /dev/nullx, /dev/null.bak, /dev/nullish
# and /dev/null/sub are ordinary paths and must stay writes.
#
# `! cmd` at statement position is INERT in bats (L-628) — this file uses
# `if cmd; then false; fi` for negative assertions.

setup() {
    ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    source "$ROOT/agents/context/lib/safe-commands.sh"
}

_not_write() { if has_bash_write_pattern "$1"; then echo "WRITE: $1"; false; fi; }
_write()     { has_bash_write_pattern "$1" || { echo "NOT WRITE: $1"; false; }; }

# ── /dev/null sinks are not writes ───────────────────────────────────────────

@test "T-3643: 'cat a > /dev/null' is not a write" { _not_write "cat a > /dev/null"; }
@test "T-3643: 'cat a >/dev/null' is not a write" { _not_write "cat a >/dev/null"; }
@test "T-3643: 'cat a >/dev/null 2>&1' is not a write" { _not_write "cat a >/dev/null 2>&1"; }
@test "T-3643: 'cat a 1>/dev/null' is not a write" { _not_write "cat a 1>/dev/null"; }
@test "T-3643: 'cat a >> /dev/null' is not a write" { _not_write "cat a >> /dev/null"; }
@test "T-3643: '/dev/null' sink mid-chain is not a write" { _not_write "cat a >/dev/null && echo ok"; }
@test "T-3643: 'grep x f >/dev/null; echo \$?' is not a write" { _not_write 'grep x f >/dev/null; echo $?'; }

# ── negative corpus: ordinary files that merely start with /dev/null ─────────

@test "T-3643 neg: '> /dev/nullx' is a write"     { _write "cat a > /dev/nullx"; }
@test "T-3643 neg: '>/dev/null.bak' is a write"   { _write "cat a >/dev/null.bak"; }
@test "T-3643 neg: '> /dev/nullish' is a write"   { _write "cat a > /dev/nullish"; }
@test "T-3643 neg: '>/dev/null/sub' is a write"   { _write "cat a >/dev/null/sub"; }
@test "T-3643 neg: a second real redirect still bites" { _write "cat a >/dev/null > out.txt"; }
@test "T-3643 neg: real redirect before /dev/null still bites" { _write "cat a > out.txt 2>/dev/null"; }
@test "T-3643 neg: a plain redirect to a file still bites" { _write "cat a > out.txt"; }

# ── curl -o /dev/null ────────────────────────────────────────────────────────

@test "T-3643: 'curl -sf http://x/ -o /dev/null' is SAFE" {
    is_bash_safe_command "curl -sf http://x/ -o /dev/null"
}
@test "T-3643: 'curl -so /dev/null http://x/' is SAFE" {
    is_bash_safe_command "curl -so /dev/null http://x/"
}
@test "T-3643 neg: 'curl -o out.txt http://x/' is NOT-SAFE" {
    if is_bash_safe_command "curl -o out.txt http://x/"; then false; fi
}
@test "T-3643 neg: 'curl -o /dev/nullx http://x/' is NOT-SAFE" {
    if is_bash_safe_command "curl -o /dev/nullx http://x/"; then false; fi
}
@test "T-3643 neg: 'wget -o /dev/null http://x/' is NOT-SAFE (wget -o is the log)" {
    if is_bash_safe_command "wget -o /dev/null http://x/"; then false; fi
}
@test "T-3643 control: 'curl -o - http://x/' stays SAFE" {
    is_bash_safe_command "curl -o - http://x/"
}
