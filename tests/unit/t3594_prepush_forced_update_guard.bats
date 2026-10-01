#!/usr/bin/env bats
# T-3594 (T-3576 GO): git pre-push refuses a non-fast-forward update or a ref
# deletion unless a matching Tier 0 ACTION approval (T-3593) exists.
#
# SAFETY: everything happens in a fixture work repo pushing to a fixture BARE
# remote, both under a tmpdir. No real repo, branch or remote is touched.
#
# The hook under test is GENERATED into the fixture by the real `install-hooks`
# from agents/git/lib/hooks.sh, so this measures the source, not whatever sits
# in the live repo's .git/hooks. Only pre-push is kept (moved into a private
# core.hooksPath); the fixture's own commits therefore run no commit hooks,
# while every push runs the real pre-push.
#
# Approvals go through the real `fw tier0 approve`, with CLAUDECODE unset,
# acting as the operator inside the fixture only.

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

setup() {
    FX="$(mktemp -d -t fw-t3594-XXXXXX)"
    FX="$(cd "$FX" && pwd -P)"
    REMOTE="$FX/remote.git"
    W="$FX/work"
    git init -q --bare "$REMOTE"
    git init -q -b main "$W"
    cd "$W"
    git config user.email "t3594@local"
    git config user.name "T-3594 fixture"
    git config commit.gpgsign false
    mkdir -p .tasks/active .context/working agents/audit lib
    _install_audit_stub
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
    unset CLAUDE_PROJECT_DIR TIER0_WATCHTOWER_TTL
    export FX REMOTE W
}

teardown() {
    cd /
    [ -n "${FX:-}" ] && [ -d "$FX" ] && rm -rf "${FX:?}"
    return 0
}

_install_audit_stub() {
    cat > agents/audit/audit.sh <<'STUB'
#!/bin/bash
echo "=== STRUCTURE CHECKS ==="
echo "AUDIT-SCOPE: fails=0 ref=0 worktree=0"
exit 0
STUB
    chmod +x agents/audit/audit.sh
}

_remote_sha() { git --git-dir="$REMOTE" rev-parse -q --verify "$1" 2>/dev/null; }

# Rewrite the tip so the next push of main is NOT a fast-forward.
_diverge() {
    echo "rewritten $RANDOM" > f.txt
    git add f.txt
    git commit -q --amend -m "T-3594: rewritten tip"
}

_approve() {
    (cd "$W" && env -u CLAUDECODE -u CLAUDE_PROJECT_DIR PROJECT_ROOT="$W" "$FRAMEWORK_ROOT/bin/fw" tier0 approve "$@")
}

_events() { cat "$W/.context/working/tier0-action-events.jsonl" 2>/dev/null; }

# ── consumer delivery ─────────────────────────────────────────────────────────

@test "install-hooks writes the forced-update guard into pre-push" {
    grep -q "T-3594" "$FX/hooks/pre-push"
    grep -q "merge-base --is-ancestor" "$FX/hooks/pre-push"
    grep -q "^# VERSION=1.9" "$FX/hooks/pre-push"
}

# ── unaffected pushes ─────────────────────────────────────────────────────────

@test "fast-forward push is allowed (same shape as fw handover --commit and mirror sync)" {
    echo more > g.txt; git add g.txt; git commit -q -m "T-3594: ff"
    run git push origin main
    [ "$status" -eq 0 ]
    [ "$(_remote_sha main)" = "$(git rev-parse HEAD)" ]
    [[ "$output" != *"T-3594"* ]]
}

@test "new branch creation (remote sha all zeros) is allowed" {
    git checkout -q -b feature
    echo f > h.txt; git add h.txt; git commit -q -m "T-3594: feature"
    run git push origin feature
    [ "$status" -eq 0 ]
    [ "$(_remote_sha feature)" = "$(git rev-parse HEAD)" ]
}

@test "new annotated tag push is allowed" {
    git tag -a v9.9.9 -m "Release v9.9.9"
    run git push origin v9.9.9
    [ "$status" -eq 0 ]
    [ -n "$(_remote_sha v9.9.9)" ]
}

# ── refusals ──────────────────────────────────────────────────────────────────

@test "typed forced push is refused and the remote is unchanged" {
    before="$(_remote_sha main)"
    _diverge
    run git push --force origin main
    [ "$status" -ne 0 ]
    [[ "$output" == *"Push blocked"* ]]
    [[ "$output" == *"force-push: refs/heads/main on remote 'origin'"* ]]
    [ "$(_remote_sha main)" = "$before" ]
}

@test "forced push launched from a SCRIPT is refused the same way" {
    before="$(_remote_sha main)"
    _diverge
    printf '#!/bin/bash\ngit push --force origin main\n' > "$FX/push.sh"
    run bash "$FX/push.sh"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Push blocked"* ]]
    [ "$(_remote_sha main)" = "$before" ]
}

@test "the same script succeeds after an operator approval, which is consumed once" {
    _diverge
    printf '#!/bin/bash\ngit push --force origin main\n' > "$FX/push.sh"
    bash "$FX/push.sh" 2>/dev/null || true
    run _approve
    [ "$status" -eq 0 ]
    [[ "$output" == *"FORCE-PUSH ref 'refs/heads/main' to remote 'origin'"* ]]
    run bash "$FX/push.sh"
    [ "$status" -eq 0 ]
    [ "$(_remote_sha main)" = "$(git rev-parse HEAD)" ]
    _events | grep '"event": "consumed"' | grep -q '"layer": "pre-push"'
    # single use: the next forced update needs a fresh approval
    _diverge
    run bash "$FX/push.sh"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Push blocked"* ]]
}

@test "an approval for a DIFFERENT ref does not admit the push" {
    git push -q origin main:other 2>/dev/null
    _diverge
    run git push --force origin main:other      # refused; records the request for 'other'
    [ "$status" -ne 0 ]
    [[ "$output" == *"refs/heads/other"* ]]
    _approve >/dev/null
    run git push --force origin main
    [ "$status" -ne 0 ]
    [[ "$output" == *"Push blocked"* ]]
}

@test "remote branch deletion is refused, then allowed once approved" {
    git push -q origin main:old 2>/dev/null
    run git push origin --delete old
    [ "$status" -ne 0 ]
    [[ "$output" == *"branch-delete: refs/heads/old on remote 'origin'"* ]]
    [ -n "$(_remote_sha old)" ]
    run _approve
    [[ "$output" == *"DELETE ref 'refs/heads/old' on remote 'origin'"* ]]
    run git push origin --delete old
    [ "$status" -eq 0 ]
    [ -z "$(_remote_sha old)" ]
}

@test "text-gate admission then pre-push consumption: one approval, both layers" {
    _diverge
    git push --force origin main 2>/dev/null || true
    _approve >/dev/null
    # simulate the PreToolUse gate admitting the typed command
    json=$(python3 -c "import json,sys; print(json.dumps({'tool_input':{'command':'git push origin main --force'},'cwd':sys.argv[1]}))" "$W")
    run bash -c "printf '%s' '$json' | PROJECT_ROOT='$W' bash '$FRAMEWORK_ROOT/agents/context/check-tier0.sh'"
    [ "$status" -eq 0 ]
    run git push --force origin main
    [ "$status" -eq 0 ]
    _events | grep -q '"event": "admitted"'
    _events | grep '"event": "consumed"' | grep -q '"layer": "pre-push"'
}

@test "fail closed: with no approval module a forced push is refused" {
    rm -f lib/tier0_action.py
    _diverge
    run git push --force origin main
    [ "$status" -ne 0 ]
    [[ "$output" == *"was not found"* ]]
}

@test "consumer layout: the module is found under .agentic-framework/lib" {
    mkdir -p .agentic-framework/lib
    mv lib/tier0_action.py .agentic-framework/lib/
    _diverge
    run git push --force origin main
    [ "$status" -ne 0 ]
    [[ "$output" == *"tier0 approve"* ]]
    _approve >/dev/null
    run git push --force origin main
    [ "$status" -eq 0 ]
}

@test "block message names the limit (every hook-skipping path) and the stronger server-side control" {
    _diverge
    run git push --force origin main
    [ "$status" -ne 0 ]
    [[ "$output" == *"any path that skips client-side hooks"* ]]
    [[ "$output" == *"--no-verify"* ]]
    [[ "$output" == *"core.hooksPath"* ]]
    [[ "$output" == *"send-pack"* ]]
    [[ "$output" == *"Server-side branch and tag"* ]]
    [[ "$output" == *"operator decision"* ]]
}

@test "LIMIT (characterization): --no-verify skips the hook — a git property" {
    _diverge
    run git push --force --no-verify origin main
    [ "$status" -eq 0 ]
    [ "$(_remote_sha main)" = "$(git rev-parse HEAD)" ]
}

# ── Review fixes (docs/reports/T-3593-T-3594-review.md) ──────────────────────

_gate() {
    local json
    json=$(python3 -c "import json,sys; print(json.dumps({'tool_input':{'command':sys.argv[1]},'cwd':sys.argv[2]}))" "$1" "$W")
    printf '%s' "$json" | PROJECT_ROOT="$W" bash "$FRAMEWORK_ROOT/agents/context/check-tier0.sh"
}

@test "A1: a release tag moved FORWARD by force is refused without approval" {
    git tag -a v1 -m "T-3594: v1"
    git push -q origin v1 2>/dev/null
    local old; old=$(_remote_sha refs/tags/v1)
    echo "next $RANDOM" > g.txt && git add g.txt && git commit -q -m "T-3594: descendant"
    git tag -f -a v1 -m "T-3594: v1 moved" >/dev/null
    run git push -f origin v1
    [ "$status" -ne 0 ]
    [[ "$output" == *"force-push: refs/tags/v1"* ]]
    [ "$(_remote_sha refs/tags/v1)" = "$old" ]
    # control: approved, the same move goes through once
    run _approve
    [ "$status" -eq 0 ]
    [[ "$output" == *"FORCE-PUSH ref 'refs/tags/v1'"* ]]
    run git push -f origin v1
    [ "$status" -eq 0 ]
    [ "$(_remote_sha refs/tags/v1)" != "$old" ]
}

@test "A1 CONTROL: a NEW annotated tag still passes with no approval" {
    git tag -a v2 -m "T-3594: v2"
    run git push origin v2
    [ "$status" -eq 0 ]
    [ -n "$(_remote_sha refs/tags/v2)" ]
}

@test "A2: the text gate matches git -C / git -c pushes that force, +ref or delete" {
    run _gate "git -C $W push -f origin main"
    [ "$status" -eq 2 ]
    [[ "$output" == *"FORCE-PUSH ref 'refs/heads/main' to remote 'origin'"* ]]
    run _gate "git -C $W push origin +main"
    [ "$status" -eq 2 ]
    run _gate "git -C $W push origin --delete old"
    [ "$status" -eq 2 ]
    run _gate "git -c push.default=current push --force origin main"
    [ "$status" -eq 2 ]
    [[ "$output" == *"Not mapped to an action"* ]]
    # control: a plain -C push is not touched
    run _gate "git -C $W push origin main"
    [ "$status" -eq 0 ]
}

@test "A2: the text gate blocks a core.hooksPath override, and lets a read pass" {
    run _gate "git -c core.hooksPath=/dev/null push origin main"
    [ "$status" -eq 2 ]
    [[ "$output" == *"core.hooksPath"* ]]
    run _gate "git config core.hooksPath /dev/null"
    [ "$status" -eq 2 ]
    run _gate "git config --get core.hooksPath"
    [ "$status" -eq 0 ]
}

@test "A2 LIMIT (characterization): a core.hooksPath override from a script skips pre-push" {
    _diverge
    printf '#!/bin/bash\ngit -c core.hooksPath=/dev/null push -f origin main\n' > "$FX/push.sh"
    run bash "$FX/push.sh"
    [ "$status" -eq 0 ]
    [ "$(_remote_sha main)" = "$(git rev-parse HEAD)" ]
}

# ── Round 3 (re-review "## Re-review after fixes") ───────────────────────────

@test "R1 round 3 end to end: 'git push -f --no-verif' approval is not a reusable force-push action" {
    _diverge
    # 1. blocked, and shown as a hook bypass, not as a bare force-push action
    run _gate "git push -f --no-verif origin main"
    [ "$status" -eq 2 ]
    [[ "$output" == *"HOOK BYPASS"* ]]
    [[ "$output" != *"FORCE-PUSH ref 'refs/heads/main'"* ]]
    # 2. the operator approves: it lands on the exact-text path, no action record
    run _approve
    [ "$status" -eq 0 ]
    run bash -c "cat '$W/.context/working/tier0-action-approvals.json' 2>/dev/null | grep -q '\"force-push\"'"
    [ "$status" -ne 0 ]
    # 3. the text gate admits that exact text once; the typed push then skips pre-push (git property)
    run _gate "git push -f --no-verif origin main"
    [ "$status" -eq 0 ]
    run git push -q -f --no-verif origin main
    [ "$status" -eq 0 ]
    # 4. a later script force-push finds nothing to consume at pre-push
    _diverge
    printf '#!/bin/bash\ngit push --force origin main\n' > "$FX/push.sh"
    run bash "$FX/push.sh"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Push blocked"* ]]
    # 5. and the typed text is not admitted a second time. Since T-3593 round 4
    #    the T-1508 duplicate-fire grace is bound to the tool call (tool_use_id),
    #    not to a 5 s same-text window; this payload carries no id, so there is
    #    no grace at all and no sentinel ageing is needed.
    run _gate "git push -f --no-verif origin main"
    [ "$status" -eq 2 ]
}

@test "round 3 (a): a typed tag move approved at the TEXT GATE is consumed by pre-push (one key)" {
    git tag -a v1 -m "fixture v1"
    git push -q origin v1 2>/dev/null
    local old; old=$(_remote_sha refs/tags/v1)
    echo "next $RANDOM" > g.txt && git add g.txt && git commit -q -m "fixture: descendant"
    git tag -f -a v1 -m "fixture v1 moved" >/dev/null
    run _gate "git push -f origin v1"
    [ "$status" -eq 2 ]
    [[ "$output" == *"FORCE-PUSH ref 'refs/tags/v1' to remote 'origin'"* ]]
    run _approve
    [ "$status" -eq 0 ]
    run _gate "git push -f origin v1"
    [ "$status" -eq 0 ]
    run git push -f origin v1
    [ "$status" -eq 0 ]
    [ "$(_remote_sha refs/tags/v1)" != "$old" ]
    _events | grep '"event": "consumed"' | grep -q 'refs/tags/v1'
}

@test "round 3 (a) CONTROL: a branch push keeps the short branch key" {
    run _gate "git push -f origin main"
    [ "$status" -eq 2 ]
    [[ "$output" == *"FORCE-PUSH ref 'refs/heads/main' to remote 'origin'"* ]]
}

@test "round 3 (b): core.hooksPath overrides are caught in any case and via --config-env / GIT_CONFIG_*" {
    local c
    for c in "git -c core.hookspath=/dev/null push origin main" \
             "git -c CORE.HOOKSPATH=/dev/null push origin main" \
             "git --config-env=core.hooksPath=HP push origin main" \
             "GIT_CONFIG_PARAMETERS=\"'core.hooksPath=/dev/null'\" git push origin main" \
             "GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=core.hookspath GIT_CONFIG_VALUE_0=/dev/null git push origin main" \
             "git config core.HooksPath /dev/null"; do
        run _gate "$c"
        [ "$status" -eq 2 ]
        [[ "$output" == *"HOOK BYPASS"* ]]
    done
    run _gate "git config --get core.hookspath"
    [ "$status" -eq 0 ]
}
