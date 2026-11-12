#!/usr/bin/env bats
# T-5091 (GitHub #111) — `grep -rE '/home/|192\.168\.' docs/` was refused as an outside read:
# Pattern 4b (T-3768) judged the quoted PATTERN as a path. A grep-family pattern is text, so
# it is no longer judged; every other word is, and anything that can make the command read
# a file (-f, --exclude-from, an unknown option) leaves nothing exempt.
#
# The hook is FED each command; nothing here is executed. The outside path is built at run
# time so this file's own text is never a command the live hook sees.

setup() {
    FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    HOOK="$FRAMEWORK_ROOT/agents/context/check-project-boundary.sh"
    R="/$(printf 'ro%s' ot)"
    OUT="$R/.t5091-probe"                  # outside the project, never created
    unset PROJECT_ROOT
    CWD="$FRAMEWORK_ROOT"
}

hook() {
    local json
    json=$(python3 -c 'import json,sys
print(json.dumps({"tool_name":"Bash","tool_input":{"command":sys.argv[1]},"cwd":sys.argv[2]}))' "$1" "$CWD")
    output=$(printf '%s' "$json" | bash "$HOOK" 2>&1)
}

allowed() { local rc=0; hook "$1" || rc=$?; [ "$rc" -eq 0 ] || { echo "refused: $1"; echo "$output"; return 1; }; }
blocked() { local rc=0; hook "$1" || rc=$?; [ "$rc" -eq 2 ] || { echo "allowed: $1"; return 1; }; }

@test "T-5091: Mehdi's command — a quoted regex with | is a pattern, not a path" {
    allowed "grep -rE '/home/|192\\.168\\.' docs/"
}

@test "T-5091: the pattern in its other positions passes" {
    allowed "grep -e '/home/|x' -e y docs"
    allowed "grep -rE '/home/|x' -- docs"
    allowed "grep -A 3 -n '/etc/a|b' docs"
    allowed "grep --include=*.md -r '/etc/a|b' docs"
    allowed "egrep '/home/|x' docs"
    allowed "sudo grep -r '/etc/a|b' docs"
    allowed "find . -name '*.md' | xargs grep '/home/|x'"
    allowed "rg -g '*.md' '/etc/|x' docs"
}

@test "T-5091: an outside file operand after the pattern is still refused" {
    blocked "grep -rE '/home/|x' $OUT"
    blocked "grep -e x -e y $OUT"
    blocked "rg '/etc/|x' $OUT"
}

@test "T-5091: patterns read from a file leave nothing exempt" {
    blocked "grep -f $OUT docs"
    blocked "grep --file=$OUT docs"
    blocked "grep -rf $OUT docs"
}

@test "T-5091: an option whose value can be a file, or an unknown option, leaves nothing exempt" {
    blocked "grep --exclude-from $OUT docs"
    blocked "grep --frobnicate '$OUT' docs"
    blocked "rg --ignore-file $OUT 'x' docs"
}

@test "T-5091: shell bodies and quoted paths are not patterns" {
    # (a sed script that READS a file, `sed '1r <outside>' f`, already passed before this task:
    #  registered as G-131, not part of this fix)
    blocked "sed -n 'p' $OUT"
    blocked "bash -c 'cat $OUT'"
    blocked "cat '$OUT'"
}
