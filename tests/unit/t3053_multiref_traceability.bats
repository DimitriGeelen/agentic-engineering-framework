#!/usr/bin/env bats
# T-3053 — a commit subject may name more than one task. The traceability check
# read only the first ref, so a commit whose leading ref did not resolve was
# reported orphaned even when a later ref named a real task.
#
# Two sites carried the same `head -1` shape and they ask opposite questions:
#
#   commit subject   "is this commit traceable?"   -> ANY ref resolving suffices
#   practice Origin  "are these citations valid?"  -> EVERY ref must resolve
#
# So one defect was a false FAIL at one site and a false GREEN at the other, and
# the two need opposite fixes. Every test below pins a direction, not just a
# behaviour, and both fixes are mutation-checked against a copy of audit.sh with
# the `head -1` form restored.
#
# The mutant is installed into a SHADOW framework root rather than a bare temp
# file. audit.sh derives FRAMEWORK_ROOT from `dirname $0`, so a mutant dropped in
# /tmp silently loses lib/paths.sh, leaves TASKS_DIR empty, and then reports every
# ref as unresolvable — which looks exactly like "the mutation was detected". That
# false green was live in the first draft of this file.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    export NO_COLOR=1
    REPO="$TEST_TEMP_DIR/proj"
    AUDIT="$FRAMEWORK_ROOT/agents/audit/audit.sh"
}

teardown() {
    rm -rf "${TEST_TEMP_DIR:?}"
}

# A synthetic project: task files for the ids we want to resolve, plus a git repo
# whose subjects exercise each ref shape.
_mkproj() {
    mkdir -p "$REPO"/.tasks/{active,completed,templates} \
             "$REPO"/.context/{working,project,audits}
    : > "$REPO/.tasks/templates/default.md"
    local id
    for id in "$@"; do
        printf -- '---\nid: %s\n---\n' "$id" > "$REPO/.tasks/active/${id}-fixture.md"
    done
    git -C "$REPO" init -q .
    git -C "$REPO" config user.email t@example.com
    git -C "$REPO" config user.name tester
    git -C "$REPO" config commit.gpgsign false
}

_commit() {
    echo "$RANDOM" >> "$REPO/file.txt"
    git -C "$REPO" add -A
    git -C "$REPO" commit -q -m "$1"
}

_mkpractices() {
    cat > "$REPO/015-Practices.md" <<'EOF'
# Practices

## P-001 a practice with two origins
Origin: T-9001, T-9404
EOF
}

# Run the traceability + learning sections against the synthetic project.
# $1 (optional) = path to an alternate audit.sh (the mutant).
_audit() {
    local script="${1:-$AUDIT}"
    PROJECT_ROOT="$REPO" bash "$script" --section traceability,learning 2>&1
}

# Build a shadow FRAMEWORK_ROOT whose only real file is a mutated audit.sh with
# BOTH multi-ref fixes reverted to `head -1`; everything else is symlinked to the
# real tree so path resolution is identical. Prints the mutant's path.
_mutant() {
    local fw="$TEST_TEMP_DIR/fw" e b
    [ -x "$fw/agents/audit/audit.sh" ] && { printf '%s' "$fw/agents/audit/audit.sh"; return 0; }
    mkdir -p "$fw/agents/audit"
    for e in "$FRAMEWORK_ROOT"/* "$FRAMEWORK_ROOT"/.[!.]*; do
        b=$(basename "$e"); [ "$b" = "agents" ] && continue
        ln -s "$e" "$fw/$b" 2>/dev/null || true
    done
    for e in "$FRAMEWORK_ROOT"/agents/*; do
        b=$(basename "$e"); [ "$b" = "audit" ] && continue
        ln -s "$e" "$fw/agents/$b"
    done
    for e in "$FRAMEWORK_ROOT"/agents/audit/*; do
        b=$(basename "$e"); [ "$b" = "audit.sh" ] && continue
        ln -s "$e" "$fw/agents/audit/$b"
    done
    sed "s/| awk '!seen\[\$0\]++')/| head -1)/g" \
        "$AUDIT" > "$fw/agents/audit/audit.sh"
    chmod +x "$fw/agents/audit/audit.sh"
    # the substitution must actually have landed, at both sites
    [ "$(grep -c "| head -1)" "$fw/agents/audit/audit.sh")" \
      -eq "$(( $(grep -c "| head -1)" "$AUDIT") + 2 ))" ]
    # and the shadow root must still resolve its libraries, or the mutant would
    # report every ref unresolvable for reasons that have nothing to do with the
    # mutation (see header note)
    [ -f "$fw/lib/paths.sh" ]
    printf '%s' "$fw/agents/audit/audit.sh"
}

# ─────────────────── commit subjects — ANY ref resolving wins ────────────────

@test "A1 — a later ref resolving is enough; the commit is not orphaned" {
    _mkproj T-9001
    _commit "seed: no task ref"
    _commit "T-9404/T-9001-side: first ref is dead, second is real"
    run _audit
    [[ "$output" != *"references non-existent task"* ]]
}

@test "A4 — the pre-fix head -1 form DOES orphan that commit (mutation)" {
    _mkproj T-9001
    _commit "seed: no task ref"
    _commit "T-9404/T-9001-side: first ref is dead, second is real"
    run _audit "$(_mutant)"
    [[ "$output" == *"references non-existent task T-9404"* ]]
}

@test "A4 — the mutant still resolves a first-ref-good commit (harness sanity)" {
    # Guards the false green described in the header: if the mutant were merely
    # broken, this would report an orphan too and the test above would prove
    # nothing.
    _mkproj T-9001
    _commit "seed: no task ref"
    _commit "T-9001: first ref resolves"
    run _audit "$(_mutant)"
    [[ "$output" != *"references non-existent task"* ]]
    [[ "$output" == *"All commit task refs resolve to actual tasks"* ]]
}

@test "A2 — a commit whose refs ALL fail is still orphaned, and names both" {
    _mkproj T-9001
    _commit "seed: no task ref"
    _commit "T-9404/T-9405: neither of these exists"
    run _audit
    [[ "$output" == *"references non-existent task T-9404, T-9405"* ]]
}

@test "A2 — a resolving first ref does not start reporting the dead sibling" {
    # The over-broad fix in the other direction: warning per-ref would turn every
    # "T-real: ...; T-dead mentioned" commit into new noise.
    _mkproj T-9001
    _commit "seed: no task ref"
    _commit "T-9001: real, and T-9404 is only mentioned"
    run _audit
    [[ "$output" != *"references non-existent task"* ]]
}

@test "A2 — a single dead ref is unaffected by the rewrite" {
    _mkproj T-9001
    _commit "seed: no task ref"
    _commit "T-9404: nothing resolves here"
    run _audit
    [[ "$output" == *"references non-existent task T-9404"* ]]
}

# ──────────────────────────── escapes still fire — A5 ────────────────────────

@test "A5 — the T-2058 revert-chain escape still suppresses" {
    _mkproj T-9001
    _commit "seed: no task ref"
    _commit "T-9404: work that was later reverted"
    _commit "Revert T-9404: backed out"
    run _audit
    [[ "$output" != *"non-existent task T-9404"* ]]
}

@test "A5 — reverting ONE ref does not hide an orphaned sibling" {
    # The escape operated on the single chosen ref. Carrying it over as
    # "any reverted -> suppress" would have silently widened it.
    _mkproj T-9001
    _commit "seed: no task ref"
    _commit "T-9404/T-9405: neither exists"
    _commit "Revert T-9404: backed out only this one"
    run _audit
    [[ "$output" == *"references non-existent task T-9404, T-9405"* ]]
}

@test "A5 — the T-2851 root-commit escape still suppresses" {
    _mkproj T-9001
    # the root commit carries a dead ref and is exempt by parentlessness
    _commit "T-9404: bootstrap commit, predates every task"
    _commit "T-9001: a real one so the section has traffic"
    run _audit
    [[ "$output" != *"non-existent task T-9404"* ]]
}

# ───────────────── practice origins — EVERY ref must resolve — A3 ────────────

@test "A3 — an Origin line naming a dead SECOND task is reported" {
    _mkproj T-9001
    _commit "T-9001: seed"
    _mkpractices
    run _audit
    [[ "$output" == *"references non-existent task T-9404"* ]]
    [[ "$output" == *"Origin task T-9404 not found"* ]]
}

@test "A3 — the pre-fix head -1 form is SILENT about it (mutation)" {
    # The false-green half: reading only the first ref let a stale second origin
    # through, and the check still printed its reassuring PASS underneath.
    _mkproj T-9001
    _commit "T-9001: seed"
    _mkpractices
    run _audit "$(_mutant)"
    [[ "$output" != *"Origin task T-9404 not found"* ]]
    [[ "$output" == *"All practice origins resolve to actual tasks"* ]]
}

@test "A3 — an Origin line whose refs all resolve stays clean" {
    _mkproj T-9001 T-9404
    _commit "T-9001: seed"
    _mkpractices
    run _audit
    [[ "$output" != *"Origin task T-9404 not found"* ]]
    [[ "$output" == *"All practice origins resolve to actual tasks"* ]]
}
