#!/usr/bin/env bats
# T-3594 round 4 — fixes for the round-3 reviews (Claude AMBER 1 and 3, codex AMBER).
#
#   1  tag deletes (`--delete v1`, `:v1`) and `src:dst` pushes keyed `v1` at the
#      text gate but `refs/tags/v1` at pre-push: the approval did nothing, and the
#      stranded record could authorize deleting a BRANCH named v1.
#   3  `git commit -n -m x` / `git commit -anm x` passed the bash fast path.
#
# SAFETY: fixture work repo + fixture bare remote under a tmpdir; only fixture
# pushes run. Approvals are fixture approvals (real `fw tier0 approve`, CLAUDECODE
# unset), made the way the other tier0 suites make them.

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

setup() {
    FX="$(mktemp -d -t fw-t3594r4-XXXXXX)"
    FX="$(cd "$FX" && pwd -P)"
    REMOTE="$FX/remote.git"
    W="$FX/work"
    git init -q --bare "$REMOTE"
    git init -q -b main "$W"
    cd "$W"
    git config user.email "t3594@local"
    git config user.name "T-3594 fixture"
    git config commit.gpgsign false
    mkdir -p .tasks/active .context/working .context/approvals agents/audit lib
    cat > agents/audit/audit.sh <<'STUB'
#!/bin/bash
echo "=== STRUCTURE CHECKS ==="
echo "AUDIT-SCOPE: fails=0 ref=0 worktree=0"
exit 0
STUB
    chmod +x agents/audit/audit.sh
    cp "$FRAMEWORK_ROOT/lib/tier0_action.py" lib/
    echo "1.0.0" > VERSION
    printf '.context/\n' > .gitignore
    git add -A
    git commit -q -m "T-3594: fixture init"
    PROJECT_ROOT="$W" bash "$FRAMEWORK_ROOT/agents/git/git.sh" install-hooks >/dev/null 2>&1
    [ -x .git/hooks/pre-push ]
    mkdir -p "$FX/hooks"
    mv .git/hooks/pre-push "$FX/hooks/pre-push"
    git config core.hooksPath "$FX/hooks"
    git remote add origin "$REMOTE"
    git push -q origin main 2>/dev/null
    git tag -a v1 -m "fixture v1"
    git push -q origin v1 2>/dev/null
    git fetch -q origin
    unset CLAUDE_PROJECT_DIR TIER0_WATCHTOWER_TTL CDPATH
    export FX REMOTE W NTFY_ENABLED=false
}

teardown() {
    cd /
    [ -n "${FX:-}" ] && [ -d "$FX" ] && rm -rf "${FX:?}"
    return 0
}

_gate() {
    local json
    json=$(python3 -c "import json,sys; print(json.dumps({'tool_input':{'command':sys.argv[1]},'cwd':sys.argv[2],'tool_use_id':sys.argv[3]}))" "$1" "$W" "toolu_$RANDOM$RANDOM$RANDOM")
    printf '%s' "$json" | PROJECT_ROOT="$W" bash "$FRAMEWORK_ROOT/agents/context/check-tier0.sh"
}
_approve() {
    (cd "$W" && env -u CLAUDECODE -u CLAUDE_PROJECT_DIR PROJECT_ROOT="$W" "$FRAMEWORK_ROOT/bin/fw" tier0 approve "$@")
}
_remote_sha() { git --git-dir="$REMOTE" rev-parse -q --verify "$1" 2>/dev/null; }
_events() { cat "$W/.context/working/tier0-action-events.jsonl" 2>/dev/null; }

# ── 1: one key at both layers ───────────────────────────────────────────────

@test "tag delete ':v1' — text gate and pre-push use ONE key; the approval is consumed and the tag is gone" {
    run _gate "git push origin :v1"
    [ "$status" -eq 2 ]
    [[ "$output" == *"DELETE tag 'v1' on remote 'origin'"* ]]
    run _approve
    [ "$status" -eq 0 ]
    run _gate "git push origin :v1"
    [ "$status" -eq 0 ]
    run git push origin :v1
    [ "$status" -eq 0 ]
    [ -z "$(_remote_sha refs/tags/v1)" ]
    _events | grep '"event": "consumed"' | grep '"layer": "pre-push"' | grep -q 'refs/tags/v1'
}

@test "tag delete '--delete v1' — same single key end to end" {
    run _gate "git push --delete origin v1"
    [ "$status" -eq 2 ]
    [[ "$output" == *"DELETE tag 'v1' on remote 'origin'"* ]]
    _approve >/dev/null
    run _gate "git push origin --delete v1"
    [ "$status" -eq 0 ]
    run git push origin --delete v1
    [ "$status" -eq 0 ]
    [ -z "$(_remote_sha refs/tags/v1)" ]
}

@test "branch delete keeps the short branch key and is consumed at pre-push" {
    git push -q origin main:feat 2>/dev/null
    git fetch -q origin
    run _gate "git push origin --delete feat"
    [ "$status" -eq 2 ]
    [[ "$output" == *"DELETE branch 'feat' on remote 'origin'"* ]]
    _approve >/dev/null
    run _gate "git push origin :feat"
    [ "$status" -eq 0 ]
    run git push origin :feat
    [ "$status" -eq 0 ]
    [ -z "$(_remote_sha refs/heads/feat)" ]
}

@test "a stranded tag-delete approval never authorizes deleting a same-named BRANCH" {
    # The operator is shown and approves a TAG delete (local evidence: tag v1).
    run _gate "git push origin :v1"
    [ "$status" -eq 2 ]
    [[ "$output" == *"DELETE tag 'v1'"* ]]
    _approve >/dev/null
    run _gate "git push origin :v1"               # admitted, never pushed: stranded
    [ "$status" -eq 0 ]
    # Another client creates a BRANCH v1 on the remote (not fetched here).
    run git push -q origin main:refs/heads/v1
    [ "$status" -eq 0 ]
    printf '#!/bin/bash\ngit push origin :refs/heads/v1\n' > "$FX/s.sh"
    run bash "$FX/s.sh"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Push blocked"* ]]
    [ -n "$(_remote_sha refs/heads/v1)" ]
}

@test "an ambiguous short name (local tag AND branch evidence) is unmapped, not guessed" {
    git push -q origin main:refs/heads/v1 2>/dev/null
    git fetch -q origin
    run _gate "git push origin :v1"
    [ "$status" -eq 2 ]
    [[ "$output" == *"Not mapped to an action"* ]]
}

@test "a short delete name with no local evidence of what it is is unmapped" {
    run _gate "git push origin :nosuchref"
    [ "$status" -eq 2 ]
    [[ "$output" == *"Not mapped to an action"* ]]
}

@test "src:dst force-push to a TAG ('HEAD:v1') keys refs/tags/v1 at both layers" {
    echo n > n.txt && git add n.txt && git commit -q -m "T-3594: next"
    run _gate "git push -f origin HEAD:v1"
    [ "$status" -eq 2 ]
    [[ "$output" == *"FORCE-PUSH ref 'refs/tags/v1' to remote 'origin'"* ]]
    _approve >/dev/null
    run _gate "git push -f origin HEAD:v1"
    [ "$status" -eq 0 ]
    run git push -f origin HEAD:v1
    [ "$status" -eq 0 ]
    _events | grep '"event": "consumed"' | grep '"layer": "pre-push"' | grep -q 'refs/tags/v1'
}

@test "src:dst force-push to a BRANCH keeps the short key" {
    run _gate "git push -f origin HEAD:main"
    [ "$status" -eq 2 ]
    [[ "$output" == *"FORCE-PUSH ref 'main' to remote 'origin'"* ]]
}

# ── 3: git commit -n ────────────────────────────────────────────────────────

@test "git commit -n in every spelling git accepts is HOOK BYPASS" {
    local c
    for c in "git commit -n -m x" "git commit -anm x" "git commit -nm x" "git commit -an -m x" \
             "git commit -m x -n" "git commit -n" "git -P commit -n -m x" \
             "git commit --no-verify -m x" "git commit --no-verif -m x" "git commit --no-veri -m x"; do
        run _gate "$c"
        [ "$status" -eq 2 ] || { echo "not blocked: $c"; return 1; }
        [[ "$output" == *"HOOK BYPASS"* ]] || { echo "no label: $c"; return 1; }
    done
}

@test "CONTROL: ordinary commits pass" {
    local c
    for c in "git commit -m x" "git commit -am x" "git commit --amend --no-edit" "git commit -m 'fix -n handling'"; do
        run _gate "$c"
        [ "$status" -eq 0 ] || { echo "blocked: $c"; return 1; }
    done
}
