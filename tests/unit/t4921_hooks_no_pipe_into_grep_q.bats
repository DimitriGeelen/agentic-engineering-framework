#!/usr/bin/env bats
# T-4921 (T-4920 class, 832 T-1341): a pipe into `grep -q` under `set -o pipefail` reads a
# match as "no match" when grep exits before the writer finishes (SIGPIPE, rc 141). In a
# gate that allows on "no match", that fails OPEN. Found and fixed here:
#   - check-project-boundary.sh: a write outside the project padded past ~128 KB, or
#     spread over many lines, was ALLOWED. Two defects: (1) the matcher got the command in
#     an env var, which Linux caps at 128 KB, so python3 never started; (2) the degraded
#     fallback in lib/hook-degraded.sh — meant to fail closed (T-4652) — used printf | grep -q.
#   - lib/hook-degraded.sh's Tier 0 fallback had the exact T-4920 pipe.
#   - pipes into grep -q in 8 more pipefail hooks, now here-strings.

setup() {
    ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
}

# Run a hook in place on one payload; python builds it, so no argv/env carries the value.
# $1 hook (relative), $2 tool, $3 field, $4 value, $5 pad bytes, $6 comment|lines
_judge() {
    run bash -c '
        python3 - "$2" "$3" "$4" "$5" "$6" <<'"'"'PY'"'"' | PROJECT_ROOT="$7" bash "$7/$1" >/dev/null 2>&1
import json, sys
tool, field, value, pad, mode = sys.argv[1], sys.argv[2], sys.argv[3], int(sys.argv[4]), sys.argv[5]
if pad:
    value += (" # " + "x" * pad) if mode == "comment" else ("\n" + "\n".join("echo filler %d" % i for i in range(pad)))
print(json.dumps({"tool_name": tool, "tool_input": {field: value}, "tool_use_id": "t4921", "cwd": sys.argv[0] and "/tmp"}))
PY' _ "$1" "$2" "$3" "$4" "${5:-0}" "${6:-comment}" "$ROOT"
}

B=agents/context/check-project-boundary.sh

@test "boundary: a write to /etc is blocked short, padded past 128 KB, and spread over 20k lines" {
    _judge "$B" Bash command 'cp notes.txt /etc/t4921-never' 0
    [ "$status" -eq 2 ]
    _judge "$B" Bash command 'cp notes.txt /etc/t4921-never' 300000
    [ "$status" -eq 2 ]
    _judge "$B" Bash command 'cp notes.txt /etc/t4921-never' 20000 lines
    [ "$status" -eq 2 ]
}

@test "boundary: a harmless command still passes, padded or not, and leaves no temp file" {
    # A private TMPDIR: a shared /tmp count races with other suites under `bats -j`.
    export TMPDIR="$BATS_TEST_TMPDIR/tmp"
    mkdir -p "$TMPDIR"
    _judge "$B" Bash command 'ls -la' 0
    [ "$status" -eq 0 ]
    _judge "$B" Bash command 'ls -la' 300000
    [ "$status" -eq 0 ]
    [ "$(ls "$TMPDIR"/fw-boundary-cmd.* 2>/dev/null | wc -l)" -eq 0 ]
}

@test "boundary matcher reads the command from a file, never from an env var" {
    ! grep -qE '^[[:space:]]*export _BOUNDARY_CMD=' "$ROOT/$B" || false
    grep -q '_BOUNDARY_CMD_FILE' "$ROOT/$B"
}

@test "degraded fallbacks fail closed on a long matching payload (they used printf | grep -q)" {
    run bash -c '
        set -uo pipefail
        source "$1/lib/hook-degraded.sh"
        PROJECT_ROOT=/opt/t4921-proj
        # The match is on the first line and 300 KB more follow: grep -q exits early while
        # printf is still writing (one long LINE does not show it: grep must read it all).
        pad=$(for i in $(seq 1 30000); do echo "echo filler $i"; done)
        payload="cp a /etc/x
$pad"
        ( hook_degraded_boundary "$payload" "t4921 probe" ) >/dev/null 2>&1
        echo "boundary=$?"' _ "$ROOT"
    [[ "$output" == *"boundary=2"* ]]
}

@test "no pipe into grep -q in any hook or gate library that runs under pipefail" {
    local f bad=""
    for f in "$ROOT"/agents/context/*.sh "$ROOT"/agents/git/lib/*.sh "$ROOT"/lib/hook-degraded.sh; do
        grep -qE 'set -[a-z]*o pipefail|set -o pipefail' "$f" || [ "$f" = "$ROOT/lib/hook-degraded.sh" ] || continue
        # Code lines only; a real pipe is a lone `|`, not `||`.
        if grep -vE '^[[:space:]]*#' "$f" | grep -qE '(^|[^|])\|[[:space:]]*grep[[:space:]]+-[a-zA-Z]*q'; then
            bad="$bad ${f#"$ROOT"/}"
        fi
    done
    [ -z "$bad" ] || { echo "pipe into grep -q under pipefail in:$bad"; false; }
}
