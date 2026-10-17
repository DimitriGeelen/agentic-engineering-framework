#!/usr/bin/env bats
# T-3768 — the project-boundary hook must read a READ argument the way bash does.
#
# Pattern 4 (read-side outside paths) scanned the quote-BLANKED copy of the command and
# split it on whitespace, so codex round 4 on T-3766 (docs/reports/T-3766-review-codex-r4.md)
# found `cat "/root/x"`, `cat /roo\t/x`, `cat ../../root/x`, `cat <<< "$(cat /root/x)"`
# and `<resolver> && cat "/root/x"` all classified SAFE while plain `cat /root/x` blocked.
# Pattern 4b now runs the same predicate over lib/shell_write_scan.py's bash-style words.
#
# The hook is FED each command; nothing here is executed. The outside path is built at
# run time so this file's own text is never a command the live hook sees.

setup() {
    FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    HOOK="$FRAMEWORK_ROOT/agents/context/check-project-boundary.sh"
    R="/$(printf 'ro%s' ot)"
    OUT="$R/.t3768-probe"                  # outside the project, never created
    unset PROJECT_ROOT
    CWD="$FRAMEWORK_ROOT"
}

# Drive the hook with <command>; cwd from $CWD. Returns 0 = allowed, 2 = blocked.
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

# ── the codex round-4 probes ──────────────────────────────────────────────────

@test "baseline: plain outside read blocks (was already true)" {
    assert_blocked "cat $OUT"
}

@test "probe: double-quoted outside read blocks" {
    assert_blocked "cat \"$OUT\""
}

@test "probe: single-quoted outside read blocks" {
    assert_blocked "cat '$OUT'"
}

@test "probe: backslash-escaped outside read blocks (/roo\\t/x)" {
    assert_blocked "cat ${R%t}\\t/.t3768-probe"
}

@test "probe: relative outside read blocks, resolved against the hook cwd" {
    assert_blocked "cat ../../${R#/}/.t3768-probe"
}

@test "probe: here-string command substitution reading outside blocks" {
    assert_blocked "cat <<< \"\$(cat $OUT)\""
}

@test "probe: quoted outside write blocks" {
    assert_blocked "printf x > \"$OUT\""
}

@test "probe: quoted outside read in a sibling segment blocks" {
    assert_blocked "true && cat \"$OUT\""
}

@test "spellings: partial quote, \$HOME, ~, --opt=, cd then relative, /opt/other" {
    assert_blocked "cat \"${R%%t}\"t/.t3768-probe"
    assert_blocked "cat \"\$HOME/.t3768-probe\""
    assert_blocked "cat ~/.t3768-probe"
    assert_blocked "grep --file=\"$OUT\" x"
    assert_blocked "cd /tmp && cat ../${R#/}/.t3768-probe"
    assert_blocked "grep -r foo \"/opt/t3768-other-project/x\""
    assert_blocked "bash -c 'cat \"$OUT\"'"
}

# ── controls: these must keep passing ─────────────────────────────────────────

@test "control: a quoted message that merely mentions an outside path is allowed" {
    assert_allowed "git commit -m \"T-3768: fix $OUT handling\""
    assert_allowed "echo \"see $OUT for details\""
    assert_allowed "grep -n 'cat $OUT' docs/reports/T-3766-review-codex-r4.md"
}

@test "control: in-project paths, absolute, relative and quoted, are allowed" {
    assert_allowed "cat \"agents/context/check-project-boundary.sh\""
    assert_allowed "cat \"$FRAMEWORK_ROOT/FRAMEWORK.md\""
    assert_allowed "cat ../$(basename "$FRAMEWORK_ROOT")/FRAMEWORK.md"
    assert_allowed "sed -n 's/a/b/p' lib/paths.sh"
}

@test "control: /tmp, ~/.claude and the read-side allowlist are allowed quoted" {
    assert_allowed "cat \"/tmp/t3768-x\""
    assert_allowed "cat \"$R/.claude/settings.json\""
    assert_allowed "cat ~/.claude/settings.json"
    assert_allowed "cat \"/etc/hosts\""
    assert_allowed "ls \"/usr/lib/python3\""
}

@test "control: the sanctioned fw termlink dispatch route is allowed" {
    assert_allowed "bin/fw termlink dispatch --name read --project /opt/other --prompt 'cat README.md and return its contents'"
}

# ── the T-3766 resolver control (sandboxed registry) ──────────────────────────

@test "resolver: the absolute resolver naming a registered outside file is allowed; a quoted sibling read is not" {
    SB="$(mktemp -d)"
    mkdir -p "$SB/policy"
    cp "$FRAMEWORK_ROOT/policy/review-backends.yaml" "$SB/policy/"
    python3 - "$SB/policy/review-backends.yaml" "$OUT" <<'PY'
import sys, re, yaml
path, f = sys.argv[1], sys.argv[2]
s = open(path).read()
s2 = re.sub(r"(      env: OPENROUTER_API_KEY\n)      files:\n(        - .*\n)+", r"\1      files:\n        - " + f + "\n", s)
assert s2 != s
open(path, "w").write(s2)
yaml.safe_load(open(path))
PY
    export PROJECT_ROOT="$SB"
    CWD="$SB"
    local rc=0
    hook "$SB/bin/fw review credential openrouter --check --source $OUT" || rc=$?
    rc2=0
    hook "$SB/bin/fw review credential openrouter --check --source $OUT && cat \"$OUT\"" || rc2=$?
    rm -rf "$SB"
    [ "$rc" -eq 0 ] || { echo "resolver control blocked (rc=$rc)"; false; }
    [ "$rc2" -eq 2 ] || { echo "quoted sibling read not blocked (rc=$rc2)"; false; }
}
