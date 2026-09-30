#!/usr/bin/env bats
# T-3593 round 4 — fixes for the round-3 reviews (docs/reports/T-3593-T-3594-review.md
# "## Round 3 review", docs/reports/T-3593-round3-codex.md).
#
#   N1  an environment prefix (GIT_CONFIG_GLOBAL=, HOME=, XDG_CONFIG_HOME=,
#       GIT_CONFIG_PARAMETERS=, env ...) was stripped silently and the command was
#       folded into a plain force-push approval — one approval, two forced pushes.
#       Rule now: ANY assignment or env wrapper makes the segment unmapped; git
#       global options other than -C (same repo), -P and --no-pager are unmapped.
#   N2  CDPATH: a relative, non-./-anchored cd with CDPATH in play has no known cwd.
#   N3  the T-1508 5 s same-text window let an approved `git reset --hard HEAD~1`
#       run twice. Dedup is now bound to the tool call (tool_use_id).
#
# SAFETY: fixtures only, under a tmpdir, pushing to a fixture bare remote. The
# hook only DECIDES; the only commands actually executed are pushes inside the
# fixture. Approvals are fixture approvals via the real `fw tier0 approve` with
# CLAUDECODE unset, the way the other tier0 suites make them.

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

setup() {
    FX="$(mktemp -d -t fw-t3593r4-XXXXXX)"
    FX="$(cd "$FX" && pwd -P)"
    REMOTE="$FX/remote.git"
    W="$FX/work"
    git init -q --bare "$REMOTE"
    git init -q -b main "$W"
    cd "$W"
    git config user.email "t3593@local"
    git config user.name "T-3593 fixture"
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
    git commit -q -m "T-3593: fixture init"
    # The real layout the reviewer used: pre-push in .git/hooks, NO local
    # core.hooksPath — so a global/system config file can redirect the hooks.
    PROJECT_ROOT="$W" bash "$FRAMEWORK_ROOT/agents/git/git.sh" install-hooks >/dev/null 2>&1
    [ -x .git/hooks/pre-push ]
    for h in .git/hooks/*; do
        case "$h" in *pre-push|*.sample) ;; *) rm -f "$h" ;; esac
    done
    git remote add origin "$REMOTE"
    git push -q origin main 2>/dev/null
    printf '[core]\n\thooksPath = /dev/null\n' > "$FX/evil.gitconfig"
    unset CLAUDE_PROJECT_DIR TIER0_WATCHTOWER_TTL CDPATH
    export FX REMOTE W NTFY_ENABLED=false
}

teardown() {
    cd /
    [ -n "${FX:-}" ] && [ -d "$FX" ] && rm -rf "${FX:?}"
    return 0
}

# One PreToolUse call. $1 = tool_use_id ("" = field absent), $2 = command.
_gate_id() {
    local json
    json=$(python3 -c "
import json, sys
d = {'tool_input': {'command': sys.argv[1]}, 'cwd': sys.argv[2]}
if sys.argv[3]:
    d['tool_use_id'] = sys.argv[3]
print(json.dumps(d))" "$2" "$W" "$1")
    printf '%s' "$json" | PROJECT_ROOT="$W" bash "$FRAMEWORK_ROOT/agents/context/check-tier0.sh"
}
# A fresh tool call every time.
_gate() { _gate_id "toolu_$RANDOM$RANDOM$RANDOM" "$1"; }

_approve() {
    (cd "$W" && env -u CLAUDECODE -u CLAUDE_PROJECT_DIR PROJECT_ROOT="$W" "$FRAMEWORK_ROOT/bin/fw" tier0 approve "$@")
}
_remote_sha() { git --git-dir="$REMOTE" rev-parse -q --verify "$1" 2>/dev/null; }
_diverge() {
    echo "rewritten $RANDOM" > f.txt
    git add f.txt
    git commit -q --amend -m "T-3593: rewritten tip"
}
_store_has() { grep -q "\"$1\"" "$W/.context/working/tier0-action-approvals.json" 2>/dev/null; }

# ── N1: environment prefixes ────────────────────────────────────────────────

@test "N1 end to end: GIT_CONFIG_GLOBAL prefix is a HOOK BYPASS on the exact-text path, never a reusable force-push action" {
    _diverge
    local typed="GIT_CONFIG_GLOBAL=$FX/evil.gitconfig git push -f origin main"
    # 1. blocked; shown as a hook bypass; NOT offered as a force-push action
    run _gate "$typed"
    [ "$status" -eq 2 ]
    [[ "$output" == *"HOOK BYPASS"* ]]
    [[ "$output" == *"Not mapped to an action"* ]]
    # 2. the operator approves the exact text: no action record is created
    run _approve
    [ "$status" -eq 0 ]
    run _store_has force-push
    [ "$status" -ne 0 ]
    # 3. admitted once; the typed push skips pre-push (git property, the bypass the operator saw)
    run _gate "$typed"
    [ "$status" -eq 0 ]
    run env GIT_CONFIG_GLOBAL="$FX/evil.gitconfig" git push -q -f origin main
    [ "$status" -eq 0 ]
    # 4. a later plain script force-push finds nothing to consume at pre-push
    _diverge
    printf '#!/bin/bash\ngit push -f origin main\n' > "$FX/s.sh"
    run bash "$FX/s.sh"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Push blocked"* ]]
    [ "$(_remote_sha main)" != "$(git rev-parse HEAD)" ]
    # 5. and the exact text is not admitted a second time (a new tool call)
    run _gate "$typed"
    [ "$status" -eq 2 ]
}

@test "N1: every config-carrying prefix is unmapped AND labelled HOOK BYPASS" {
    local c
    for c in "GIT_CONFIG_GLOBAL=$FX/evil.gitconfig git push -f origin main" \
             "GIT_CONFIG_SYSTEM=$FX/evil.gitconfig git push -f origin main" \
             "GIT_CONFIG=$FX/evil.gitconfig git push -f origin main" \
             "HOME=$FX git push -f origin main" \
             "XDG_CONFIG_HOME=$FX git push -f origin main" \
             "GIT_CONFIG_PARAMETERS=\"'core.hooksPath=/dev/null' 'a.b=c'\" git push -f origin main" \
             "GIT_CONFIG_COUNT=1 git push -f origin main" \
             "env HOME=$FX git push -f origin main" \
             "export GIT_CONFIG_GLOBAL=$FX/evil.gitconfig && git push -f origin main" \
             "git -c include.path=$FX/evil.gitconfig push -f origin main"; do
        run _gate "$c"
        [ "$status" -eq 2 ] || { echo "not blocked: $c"; return 1; }
        [[ "$output" == *"HOOK BYPASS"* ]] || { echo "no label: $c"; return 1; }
        [[ "$output" == *"Not mapped to an action"* ]] || { echo "mapped: $c"; return 1; }
    done
}

@test "N1: config-carrying prefix on a NON-force push or commit is labelled too (hooks skipped)" {
    local c
    for c in "HOME=$FX git push origin main" \
             "GIT_CONFIG_GLOBAL=$FX/evil.gitconfig git commit -m x" \
             "GIT_CONFIG_PARAMETERS=\"'core.hooksPath=/dev/null' 'a.b=c'\" git push origin main"; do
        run _gate "$c"
        [ "$status" -eq 2 ] || { echo "not blocked: $c"; return 1; }
        [[ "$output" == *"HOOK BYPASS"* ]] || { echo "no label: $c"; return 1; }
    done
    # control: a read is not a hook-running command
    run _gate "HOME=$FX git status"
    [ "$status" -eq 0 ]
}

@test "N1: ANY assignment or env wrapper makes the segment unmapped (one rule, not a list)" {
    local c
    for c in "LC_ALL=C git push -f origin main" \
             "FOO=1 git push -f origin main" \
             "GIT_DIR=$W/.git git push -f origin main" \
             "CDPATH=/elsewhere git push -f origin main" \
             "env git push -f origin main" \
             "env -u FOO git push -f origin main" \
             "env -i git push -f origin main" \
             "sudo git push -f origin main" \
             "FOO=1; git push -f origin main" \
             "export FOO=1 && git push -f origin main" \
             "LC_ALL=C git reset --hard HEAD" \
             "FOO=1 rm -rf *"; do
        run _gate "$c"
        [ "$status" -eq 2 ] || { echo "not blocked: $c"; return 1; }
        [[ "$output" == *"Not mapped to an action"* ]] || { echo "mapped: $c"; return 1; }
    done
}

@test "N1 CONTROL: without a prefix the same force push maps to the action" {
    run _gate "git push -f origin main"
    [ "$status" -eq 2 ]
    [[ "$output" == *"FORCE-PUSH ref 'main' to remote 'origin'"* ]]
}

@test "global options: -P / --no-pager are seen (blocked) and mapped; --git-dir, --work-tree, --namespace, -p, --no-replace-objects are unmapped" {
    local c
    for c in "git -P push -f origin main" "git --no-pager push -f origin main"; do
        run _gate "$c"
        [ "$status" -eq 2 ] || { echo "not blocked: $c"; return 1; }
        [[ "$output" == *"FORCE-PUSH ref 'main' to remote 'origin'"* ]] || { echo "not mapped: $c"; return 1; }
    done
    for c in "git --git-dir=$W/.git push -f origin main" \
             "git --git-dir $W/.git push -f origin main" \
             "git --work-tree=$W push -f origin main" \
             "git --namespace=x push -f origin main" \
             "git -p push -f origin main" \
             "git --no-replace-objects reset --hard HEAD" \
             "git --bare push -f origin main"; do
        run _gate "$c"
        [ "$status" -eq 2 ] || { echo "not blocked: $c"; return 1; }
        [[ "$output" == *"Not mapped to an action"* ]] || { echo "mapped: $c"; return 1; }
    done
}

@test "global options: -C to the SAME repo stays mapped; -C to a different repo is unmapped" {
    run _gate "git -C $W push -f origin main"
    [ "$status" -eq 2 ]
    [[ "$output" == *"FORCE-PUSH ref 'main' to remote 'origin'"* ]]
    git init -q -b main "$FX/other"
    git -C "$FX/other" -c user.email=t@l -c user.name=t commit -q --allow-empty -m "T-3593: other"
    run _gate "git -C $FX/other push -f origin main"
    [ "$status" -eq 2 ]
    [[ "$output" == *"Not mapped to an action"* ]]
    run _gate "cd $FX/other && git push -f origin main"
    [ "$status" -eq 2 ]
    [[ "$output" == *"Not mapped to an action"* ]]
}

# ── N2: CDPATH ──────────────────────────────────────────────────────────────

@test "N2: CDPATH anywhere in the command — a bare relative cd has no known cwd" {
    mkdir -p "$W/sub"
    local c
    for c in "CDPATH=/elsewhere; cd sub && rm -rf *" \
             "export CDPATH=/elsewhere && cd sub && rm -rf *" \
             "CDPATH=/elsewhere cd sub && rm -rf *"; do
        run _gate "$c"
        [ "$status" -eq 2 ] || { echo "not blocked: $c"; return 1; }
        [[ "$output" != *"RECURSIVELY DELETE $W/sub"* ]] || { echo "mapped: $c"; return 1; }
        [[ "$output" == *"Not mapped to an action"* ]] || { echo "mapped: $c"; return 1; }
    done
}

@test "N2: CDPATH in the hook's environment — a bare relative cd has no known cwd" {
    mkdir -p "$W/sub"
    CDPATH=/elsewhere run _gate "cd sub && rm -rf *"
    [ "$status" -eq 2 ]
    [[ "$output" == *"Not mapped to an action"* ]]
}

@test "N2 CONTROL: ./-anchored cd ignores CDPATH and stays mapped; without CDPATH a bare cd is mapped" {
    mkdir -p "$W/sub"
    CDPATH=/elsewhere run _gate "cd ./sub && rm -rf *"
    [ "$status" -eq 2 ]
    [[ "$output" == *"RECURSIVELY DELETE $W/sub/*"* ]]
    run _gate "cd sub && rm -rf *"
    [ "$status" -eq 2 ]
    [[ "$output" == *"RECURSIVELY DELETE $W/sub/*"* ]]
}

# ── N3: invocation-bound dedup (tool_use_id) ────────────────────────────────

@test "N3: an approved 'git reset --hard HEAD~1' cannot run twice (second tool call refused)" {
    echo two > t.txt && git add t.txt && git commit -q -m "T-3593: second"
    run _gate_id toolu_A "git reset --hard HEAD~1"
    [ "$status" -eq 2 ]
    [[ "$output" == *"HARD-RESET branch 'main'"* ]]
    _approve >/dev/null
    run _gate_id toolu_B "git reset --hard HEAD~1"
    [ "$status" -eq 0 ]
    # the duplicate hook fire of the SAME call is allowed
    run _gate_id toolu_B "git reset --hard HEAD~1"
    [ "$status" -eq 0 ]
    # a second tool call with the identical text, immediately after, is refused
    run _gate_id toolu_C "git reset --hard HEAD~1"
    [ "$status" -eq 2 ]
    # and a call with no id at all gets no grace either
    run _gate_id "" "git reset --hard HEAD~1"
    [ "$status" -eq 2 ]
}

@test "N3: same for the legacy exact-text path (unmapped command)" {
    run _gate_id toolu_A "FOO=1 git reset --hard HEAD"
    [ "$status" -eq 2 ]
    _approve >/dev/null
    run _gate_id toolu_B "FOO=1 git reset --hard HEAD"
    [ "$status" -eq 0 ]
    run _gate_id toolu_B "FOO=1 git reset --hard HEAD"
    [ "$status" -eq 0 ]
    run _gate_id toolu_C "FOO=1 git reset --hard HEAD"
    [ "$status" -eq 2 ]
}

@test "N3: concurrent duplicate fires of one call are both allowed (race-free, under the store lock)" {
    run _gate_id toolu_A "git reset --hard HEAD"
    [ "$status" -eq 2 ]
    _approve >/dev/null
    _gate_id toolu_P "git reset --hard HEAD" 2>/dev/null & local p1=$!
    _gate_id toolu_P "git reset --hard HEAD" 2>/dev/null & local p2=$!
    local r1=0 r2=0
    wait "$p1" || r1=$?
    wait "$p2" || r2=$?
    [ "$r1" -eq 0 ]
    [ "$r2" -eq 0 ]
    run _gate_id toolu_Q "git reset --hard HEAD"
    [ "$status" -eq 2 ]
}

# ── R2 residue: typed self-approval spellings ───────────────────────────────

@test "R2 residue: bash -c / split-word / variable approval spellings are Tier 0 when typed" {
    local c
    for c in "bash -c 'CLAUDECODE= bin/fw tier0 approve'" \
             "sh -c 'unset CLAUDECODE; bin/fw tier0 approve'" \
             "CLAUDECODE= bin/fw tier0 appr\"\"ove" \
             "CLAUDECODE= bin/fw tier0 appro\\ve" \
             "CLAUDECODE= bin/fw tier0 \$V"; do
        run _gate "$c"
        [ "$status" -eq 2 ] || { echo "not blocked: $c"; return 1; }
        [[ "$output" == *"SELF-APPROVAL"* ]] || { echo "no label: $c"; return 1; }
    done
    run _gate "bin/fw tier0 status"
    [ "$status" -eq 0 ]
}

@test "pre-existing: '(cd sub && rm -rf *)' is flagged" {
    run _gate "(cd sub && rm -rf *)"
    [ "$status" -eq 2 ]
    [[ "$output" == *"RECURSIVE DELETE"* ]]
}
