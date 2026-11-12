#!/usr/bin/env bats
# T-5092 (GitHub #112) — the task gate's write scan read the `>` of a quoted awk program as
# a redirect: `awk -F: '$2>9' notes.txt` was refused as a file write. On a redirect match the
# rules are now re-read with INERT quoted text blanked. Quoted text that can run as code
# that writes (a shell, an interpreter, an awk print > f, "$(...)") is never blanked.

setup() {
    ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    # shellcheck source=/dev/null
    source "$ROOT/agents/context/lib/safe-commands.sh"
}

read_only() { if has_bash_write_pattern "$1"; then echo "taken as a write: $1"; return 1; fi; }
write()     { if ! has_bash_write_pattern "$1"; then echo "missed write: $1"; return 1; fi; }

@test "T-5092: Mehdi's awk filter and other quoted comparisons are reads" {
    read_only "awk -F: '\$2>9' notes.txt"
    read_only "awk '\$1>3' f"
    read_only "grep -E 'a>b' f"
    read_only 'echo "a > b"'
    read_only "awk -F: '\$2>9' notes.txt 2>/dev/null"
}

@test "T-5092: an awk program that redirects its output is still a write" {
    write "awk '{print > \"out\"}' f"
    write "awk '{printf \"%s\", \$1 > \"out\"}' f"
    write "awk '\$1>3 {print \$1 > \"o\"}' f"
}

@test "T-5092: quoted text that a shell or interpreter runs is still a write" {
    write "bash -c 'echo x > f'"
    write "sh -c 'echo x > f'"
    write "eval 'echo x > f'"
    write "ssh h 'echo x > f'"
    write "perl -e 'print 1>2'"
    write "python3 -c 'a>b'"
    write "sudo awk '\$1>3' f"
    write "git -c 'alias.x=!sh' x 'a>b'"
}

@test "T-5092: a substitution inside double quotes is still a write" {
    write 'echo "$(date > f)"'
    write 'echo "`date > f`"'
}

@test "T-5092: a real redirect beside a quoted comparison is still a write" {
    write "awk '\$1>3' f > out"
    write "grep 'a>b' f 2>err.log"
    write "grep 'a>b' f >> log"
    write "cat a > b"
}

@test "T-5092: an unbalanced quote keeps the match (fail closed)" {
    write "awk '\$1>3 f"
}

@test "T-5092: a command with no > never reaches the helper" {
    python3() { echo "helper called" >&2; return 1; }
    read_only "awk '{print \$1}' notes.txt"
    run has_bash_write_pattern "grep -n foo notes.txt"
    [[ "$output" != *"helper called"* ]]
}
