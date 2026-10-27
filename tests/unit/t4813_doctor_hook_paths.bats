#!/usr/bin/env bats
# T-4813: fw doctor 'Hook path validation' printed a false FAIL for two working
# ring20 hooks (field test B-new, be.37):
#   1. "$CLAUDE_PROJECT_DIR"/scripts/x.sh  -- the quote in mid-word survived
#      w.strip(quotes), so the statted path still held a quote character;
#   2. bash -c '[ -n "$(find ...)" ] && python3 ...'  -- after skipping bash the
#      check took the -c argument (inline code) as a script file.
# It then advised 'fw upgrade', which cannot fix a hook upgrade did not generate.
#
# Runs the real `fw doctor` against a temp project root and greps the hook line.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$BATS_TEST_TMPDIR"
    PROJ="$BATS_TEST_TMPDIR/proj"
    mkdir -p "$PROJ/scripts" "$PROJ/.claude" "$PROJ/.context/working"
    echo "framework_root: $FRAMEWORK_ROOT" > "$PROJ/.framework.yaml"
    printf '#!/bin/sh\nexit 0\n' > "$PROJ/scripts/audit-cred-read.sh"
    chmod +x "$PROJ/scripts/audit-cred-read.sh"
}

# write_settings <json-command>...: one PreToolUse hook per JSON string argument
write_settings() {
    local hooks="" c
    for c in "$@"; do
        hooks="${hooks:+$hooks,}{\"type\":\"command\",\"command\":$c}"
    done
    printf '%s\n' "{\"hooks\":{\"PreToolUse\":[{\"matcher\":\"Bash\",\"hooks\":[$hooks]}]}}" \
        > "$PROJ/.claude/settings.json"
}

run_doctor() {
    OUT="$(PROJECT_ROOT="$PROJ" timeout 300 "$FRAMEWORK_ROOT/bin/fw" doctor 2>&1 | sed 's/\x1b\[[0-9;]*m//g')"
}

# The two ring20 commands, JSON-encoded.
QUOTED_MIDWORD='"\"$CLAUDE_PROJECT_DIR\"/scripts/audit-cred-read.sh"'
BASH_INLINE='"bash -c '"'"'[ -n \"$(find /tmp -maxdepth 0 -newer /etc/hostname 2>/dev/null)\" ] && python3 /nonexistent/x.py || true'"'"'"'

@test "T-4813: quoted mid-word CLAUDE_PROJECT_DIR path to an existing script is not broken" {
    write_settings "$QUOTED_MIDWORD"
    run_doctor
    echo "$OUT" | grep -q "Hook config: Expected hook"
    ! echo "$OUT" | grep -q "Hook path validation: .*broken" || false
}

@test "T-4813: bash -c inline-script hook is not file-checked" {
    write_settings "$BASH_INLINE"
    run_doctor
    echo "$OUT" | grep -q "Hook config: Expected hook"
    ! echo "$OUT" | grep -q "Hook path validation: .*broken" || false
}

@test "T-4813: both ring20 hooks together, plus sh -c and python3 -c, are all clean" {
    write_settings "$QUOTED_MIDWORD" "$BASH_INLINE" '"sh -c \"exit 0\""' '"python3 -c \"print(1)\""'
    run_doctor
    ! echo "$OUT" | grep -q "Hook path validation: .*broken" || false
}

@test "T-4813: a genuinely missing quoted script still FAILs, names the path, and does not advise fw upgrade" {
    write_settings "$QUOTED_MIDWORD" '"\"$CLAUDE_PROJECT_DIR\"/scripts/gone.sh"'
    run_doctor
    echo "$OUT" | grep -q "Hook path validation: 1/2 hooks have broken paths"
    echo "$OUT" | grep -q "missing: $PROJ/scripts/gone.sh"
    ! echo "$OUT" | grep -q "Run: fw upgrade (regenerates hooks" || false
}

@test "T-4813: a missing vendored fw binary still advises fw upgrade" {
    write_settings '"${CLAUDE_PROJECT_DIR}/.agentic-framework/bin/fw hook check-tier0"'
    run_doctor
    echo "$OUT" | grep -q "Hook path validation: 1/1 hooks have broken paths"
    echo "$OUT" | grep -q "Run: fw upgrade (regenerates hooks"
}
