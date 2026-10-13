#!/usr/bin/env bats
# T-4149 — the project-boundary hook must read a write target the way bash does.
#
# Pattern 3 used to scan a QUOTE-BLANKED copy of the command with regexes, so its
# reading differed from bash wherever quoting, path normalisation, redirection position
# or option clustering mattered. Verified 2026-10-13 (repro .context/scratch/t4125-repro.py):
# plain `touch /etc/X` was blocked, but `touch "/etc/X"`, `to""uch /etc/X`,
# `touch /tmp/../etc/X`, `> /tmp/x touch /etc/X` and `sed -ibak s/a/b/ /etc/X` were not.
#
# The hook is FED each command; nothing here is executed. The outside target is built at
# run time so this file's own text is never a command the live hook sees.
# Every leg drives the real hook end-to-end, both directions in one suite.

setup() {
    FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    HOOK="$FRAMEWORK_ROOT/agents/context/check-project-boundary.sh"
    OUT="/$(printf 'e%s' tc)/t4149-probe"      # outside the project, never created
    OUTDIR="$(dirname "$OUT")"
    NL=$'\n'
}

# Drive the hook with <command> [cwd]. Returns 0 = allowed, 2 = blocked.
hook() {
    local json
    json=$(python3 -c 'import json,sys
d={"tool_name":"Bash","tool_input":{"command":sys.argv[1]}}
if len(sys.argv)>2: d["cwd"]=sys.argv[2]
print(json.dumps(d))' "$@")
    output=$(printf '%s' "$json" | bash "$HOOK" 2>&1)
    return $?
}

assert_blocked() {
    local rc=0
    hook "$@" || rc=$?
    if [ "$rc" -ne 2 ]; then
        echo "expected BLOCKED (rc 2), got rc=$rc for: $1" >&2
        echo "$output" >&2
        return 1
    fi
}

assert_allowed() {
    local rc=0
    hook "$@" || rc=$?
    if [ "$rc" -ne 0 ]; then
        echo "expected ALLOWED, got rc=$rc for: $1" >&2
        echo "$output" >&2
        return 1
    fi
}

# ── The five verified cases (each was ALLOWED on HEAD) ───────────────────────

@test "t4149: control — plain touch of an outside path is blocked" {
    assert_blocked "touch $OUT"
}

@test "t4149: quoted target is blocked" {
    assert_blocked "touch \"$OUT\""
    assert_blocked "touch '$OUT'"
}

@test "t4149: quote-split verb is blocked" {
    assert_blocked "to\"\"uch $OUT"
    assert_blocked "t\\ouch $OUT"
}

@test "t4149: .. traversal out of an allowed zone is blocked" {
    assert_blocked "touch /tmp/..$OUT"
    assert_blocked "echo x > /tmp/..$OUT"
    assert_blocked "touch $FRAMEWORK_ROOT/../..$OUT"
}

@test "t4149: leading redirection before the verb is blocked" {
    assert_blocked "> /tmp/x touch $OUT"
    assert_blocked "2>/dev/null touch $OUT"
}

@test "t4149: sed -i with a bundled suffix is blocked" {
    assert_blocked "sed -ibak s/a/b/ $OUT"
    assert_blocked "sed -ni.orig s/a/b/p $OUT"
    assert_blocked "sed -i -e s/a/b/ $OUT"
}

# ── Same class: bash executes text the old scan blanked ──────────────────────

@test "t4149: command substitution inside double quotes is blocked" {
    assert_blocked "echo \"\$(touch $OUT)\""
    assert_blocked "echo \"\`touch $OUT\`\""
}

@test "t4149: process substitution is blocked" {
    assert_blocked "git status > >(touch $OUT)"
}

@test "t4149: substitution in an UNQUOTED heredoc body is blocked" {
    assert_blocked "cat > /tmp/t4149 <<EOF${NL}\$(touch $OUT)${NL}EOF"
}

@test "t4149: a fake heredoc marker in a comment does not hide the next line" {
    assert_blocked "git status # <<EOF${NL}touch $OUT${NL}EOF"
}

@test "t4149: a fake heredoc marker in a quoted string does not hide the next line" {
    assert_blocked "echo \"<<EOF\"${NL}touch $OUT${NL}EOF"
}

@test "t4149: brace expansion that produces an outside path is blocked" {
    assert_blocked "touch /tmp/{a,..$OUT}"
    assert_blocked "{touch,$OUT}"
}

@test "t4149: sh -c and eval with a static script are read" {
    assert_blocked "bash -c 'touch $OUT'"
    assert_blocked "sh -ec \"echo hi > $OUT\""
    assert_blocked "eval 'touch $OUT'"
}

@test "t4149: quoted cd target to another project is blocked" {
    assert_blocked "cd \"/opt/t4149-other-project\" && ls"
    assert_blocked "cd /tmp/../opt/t4149-other-project"
}

@test "t4149: tilde and bare cd resolve to HOME, outside the project" {
    assert_blocked "touch ~/t4149-probe"
    assert_blocked "cd && touch t4149-probe"
}

@test "t4149: relative traversal out of the project (cwd = project root) is blocked" {
    assert_blocked "touch ../../t4149-probe" "$FRAMEWORK_ROOT"
}

@test "t4149: rm/mv-source/chmod of an outside path are blocked" {
    assert_blocked "rm -f \"$OUT\""
    assert_blocked "mv \"$OUT\" /tmp/x"
    assert_blocked "chmod 600 \"$OUT\""
}

@test "t4149: \$'\\c' swallows the next character (a quote) as bash does" {
    # bash: `$'\c''` is one string, `touch` runs, `\'` is a literal quote. Reading `\c`
    # as a two-character escape quoted the whole `'; touch …; : \'` tail instead.
    assert_blocked ": \$'\\c''; touch $OUT; : \\'"
}

@test "t4149: fail closed — an unterminated quote is refused" {
    assert_blocked "touch \"$OUT"
}

# ── Controls: must stay allowed ──────────────────────────────────────────────

@test "t4149 control: in-project writes (quoted, relative, inner ..)" {
    assert_allowed "touch \"$FRAMEWORK_ROOT/.context/scratch/t4149-x\""
    assert_allowed "touch .context/scratch/t4149-x" "$FRAMEWORK_ROOT"
    assert_allowed "echo x > \"$FRAMEWORK_ROOT/lib/../.context/scratch/t4149-x\""
    assert_allowed "sed -i.bak s/a/b/ .context/scratch/t4149-x" "$FRAMEWORK_ROOT"
    assert_allowed "cd \"$FRAMEWORK_ROOT/lib\" && touch ../.context/scratch/t4149-x"
}

@test "t4149 control: /tmp and /dev targets" {
    assert_allowed "echo x > /tmp/t4149-x"
    assert_allowed "ls 2>/dev/null >/dev/stderr"
    assert_allowed "cd /tmp && touch t4149-x"
}

@test "t4149 control: reading an outside path into the project" {
    assert_allowed "cp $OUTDIR/hostname .context/scratch/t4149-x" "$FRAMEWORK_ROOT"
    assert_allowed "sed -n 1p $OUTDIR/hostname"
    assert_allowed "awk '{print \$1, \$2}' $OUTDIR/hostname"
}

@test "t4149 control: prose that MENTIONS an outside write is not a write" {
    assert_allowed "git commit -m \"fix: touch $OUT is now blocked\""
    assert_allowed "echo '\$(touch $OUT)'"
    assert_allowed "cat > /tmp/t4149 <<'EOF'${NL}\$(touch $OUT)${NL}touch $OUT; don't${NL}EOF"
    assert_allowed "git commit -m \"\$(cat <<'EOF'${NL}T-4149: \`touch $OUT\` was allowed; it isn't now${NL}EOF${NL})\""
}

@test "t4149 control: heredoc delimiter forms and arithmetic shift" {
    assert_allowed "cat <<-\"END\" > /tmp/t4149${NL}${NL}	\$(touch $OUT)${NL}	END"
    assert_allowed "(( x = 1 << 2 ))${NL}echo ok > /tmp/t4149"
}
