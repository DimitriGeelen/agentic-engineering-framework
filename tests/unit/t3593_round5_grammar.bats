#!/usr/bin/env bats
# T-3593 round 5 — the classifier is a strict GRAMMAR, not a denylist.
#
# Rounds 1-4 parsed shell and denied the spellings reviewers found; each
# second-family review found one more (`command export`, a quoted 'export',
# `git -C /tmp/a\ b`, `sudo ... approve`, brace expansion, $'..'). Round 5
# inverts it: a command maps to an ACTION only when it is
#
#     ( cd PATH && )*  git [-C PATH | -P | --no-pager]* SUB WORD*
#                   |  rm OPTION* PATH+
#
# with plain words [A-Za-z0-9._/:=@+%,-]+ only and no `..` path component.
# Everything else is unmapped and needs approval of the exact text.
#
# Each reviewer probe is reproduced here FIRST, as the exact string they used.
# Sources: docs/reports/T-3593-round4-codex.md (codex HIGH 1, HIGH 2, MEDIUM x2)
# and docs/reports/T-3593-T-3594-review.md "## Round 4 review" (Claude F1, F2),
# plus T-3610's false positive (the -c must be git's own option).
#
# SAFETY: fixtures only, under a tmpdir, with the git discovery fence. The hook
# only DECIDES. The only commands executed are resets inside the fixture and
# fixture approvals made through the real `fw tier0 approve` with CLAUDECODE
# unset, the way the other tier0 suites make them.

load ../git_fence

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

setup() {
    FX="$(mktemp -d -t fw-t3593r5-XXXXXX)"
    FX="$(cd "$FX" && pwd -P)"
    REMOTE="$FX/remote.git"
    W="$FX/work"
    git init -q --bare "$REMOTE"
    git init -q -b main "$W"
    cd "$W"
    git config user.email "t3593@local"
    git config user.name "T-3593 fixture"
    git config commit.gpgsign false
    mkdir -p .tasks/active .context/working .context/approvals sub agents/audit lib
    # The same minimal project shape as the round-4 suite, so `fw tier0
    # approve` treats the fixture as a project and does not try to vendor.
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
    echo zero > f.txt
    git add -A
    git commit -q -m "T-3593: c0"
    git remote add origin "$REMOTE"
    git push -q origin main 2>/dev/null
    unset CLAUDE_PROJECT_DIR TIER0_WATCHTOWER_TTL CDPATH TIER0_LOCK_TIMEOUT
    export FX REMOTE W NTFY_ENABLED=false
}

teardown() {
    [ -n "${HOLDER:-}" ] && kill "$HOLDER" 2>/dev/null
    cd /
    [ -n "${FX:-}" ] && [ -d "$FX" ] && rm -rf "${FX:?}"
    return 0
}

# One PreToolUse call. $1 = tool_use_id, $2 = command.
_gate_id() {
    local json
    json=$(python3 -c "
import json, sys
print(json.dumps({'tool_input': {'command': sys.argv[1]}, 'cwd': sys.argv[2], 'tool_use_id': sys.argv[3]}))" "$2" "$W" "$1")
    printf '%s' "$json" | PROJECT_ROOT="$W" bash "$FRAMEWORK_ROOT/agents/context/check-tier0.sh"
}
_gate() { _gate_id "toolu_$RANDOM$RANDOM$RANDOM" "$1"; }

_approve() {
    (cd "$W" && env -u CLAUDECODE -u CLAUDE_PROJECT_DIR PROJECT_ROOT="$W" "$FRAMEWORK_ROOT/bin/fw" tier0 approve "$@")
}

_commit() { echo "$1" > f.txt && git add f.txt && git commit -q -m "T-3593: $1"; }

# Every command in "$@": blocked, and NOT mapped to an action.
_all_blocked_unmapped() {
    local c
    for c in "$@"; do
        run _gate "$c"
        [ "$status" -eq 2 ] || { echo "not blocked: $c"; echo "$output"; return 1; }
        [[ "$output" == *"Not mapped to an action"* ]] || { echo "mapped: $c"; echo "$output"; return 1; }
    done
}

# ── The grammar: positive shapes ────────────────────────────────────────────

@test "grammar: plain shapes map to actions (cd prefix, -C project, -P, --no-pager, reset, rm x/.)" {
    local c
    for c in "git push -f origin main" \
             "cd $W && git push -f origin main" \
             "cd $W && cd sub && cd $W && git push --force origin main" \
             "git -C $W push -f origin main" \
             "git -P push origin +main" \
             "git --no-pager push --force-with-lease origin main"; do
        run _gate "$c"
        [ "$status" -eq 2 ] || { echo "not blocked: $c"; return 1; }
        [[ "$output" == *"FORCE-PUSH ref 'main' to remote 'origin'"* ]] || { echo "not mapped: $c"; echo "$output"; return 1; }
    done
    run _gate "cd $W && git reset --hard HEAD"
    [[ "$output" == *"HARD-RESET branch 'main'"* ]]
    run _gate "cd $W/sub && rm -rf ./"
    [[ "$output" == *"RECURSIVELY DELETE $W/sub"* ]]
}

# ── The grammar: everything else is unmapped ────────────────────────────────

@test "grammar: shell outside the grammar is unmapped (pipes, redirections, ; || &, quotes, \$, backticks, braces, globs, ~, newline, subshell, here-doc, wrappers)" {
    _all_blocked_unmapped \
        "git push -f origin main 2>&1 | tail -3" \
        "git push -f origin main 2>&1" \
        "git push -f origin main >/dev/null" \
        "git push -f origin main; true" \
        "true; git push -f origin main" \
        "true || git push -f origin main" \
        "git push -f origin main &" \
        "git push -f origin main && true" \
        "git status && git push -f origin main" \
        "git push -f origin 'main'" \
        "git push -f origin \"main\"" \
        "git push -f origin ma\\in" \
        "git push -f origin \$B" \
        "git push -f origin \`echo main\`" \
        "git push -f origin {main,x}" \
        "git push -f origin \$'main'" \
        "cd sub && rm -rf *" \
        "rm -rf ~/x/." \
        "git push -f origin main # note" \
        $'cd sub\ngit push -f origin main' \
        "(git push -f origin main)" \
        "{ git push -f origin main; }" \
        $'git push -f origin main <<EOF\nx\nEOF' \
        "command git push -f origin main" \
        "nohup git push -f origin main" \
        "time git push -f origin main" \
        "exec git push -f origin main" \
        "sudo git push -f origin main" \
        "\"git\" push -f origin main" \
        "/usr/bin/git push -f origin main" \
        "git push -f origin main && git push -f origin main"
}

@test "grammar: a '..' path component is unmapped (cd, -C, rm), and rm options outside the allowlist" {
    _all_blocked_unmapped \
        "cd .. && cd work && git push -f origin main" \
        "git -C $W/../work push -f origin main" \
        "rm -rf sub/../.." \
        "rm -rf .." \
        "rm -rf --no-preserve-root ./" \
        "rm -rfi ./" \
        "cd - && git push -f origin main"
}

@test "codex round-4 HIGH 1 (exact probes): environment taint behind command / a quoted builtin is unmapped" {
    _all_blocked_unmapped \
        "command export GIT_CONFIG_GLOBAL=/tmp/config && git -C $W push -f origin refs/heads/main" \
        "'export' GIT_CONFIG_GLOBAL=/tmp/config && git -C $W push -f origin refs/heads/main" \
        "command source /tmp/envfile && git -C $W push -f origin refs/heads/main"
    # and the config-carrying ones still say so
    run _gate "command export GIT_CONFIG_GLOBAL=/tmp/config && git -C $W push -f origin refs/heads/main"
    [[ "$output" == *"HOOK BYPASS"* ]]
}

@test "codex round-4 HIGH 2 (exact probes): escaped-space -C arguments are SEEN (were SAFE) and unmapped" {
    _all_blocked_unmapped \
        'git -C /tmp/a\ b push -f origin main' \
        'git -C /tmp/a\ b reset --hard HEAD' \
        'git -C /tmp/a\ b commit -n -m x' \
        'HOME=/tmp git -C /tmp/a\ b push origin main'
    run _gate 'git -C /tmp/a\ b commit -n -m x'
    [[ "$output" == *"HOOK BYPASS"* ]]
    run _gate 'HOME=/tmp git -C /tmp/a\ b push origin main'
    [[ "$output" == *"HOOK BYPASS"* ]]
}

# ── Claude round-4 F1: self-approval through privilege / session wrappers ────

@test "F1 (exact probes): wrapped or reassembled approval spellings are Tier 0 SELF-APPROVAL" {
    local c
    for c in "sudo bin/fw tier0 approve" \
             "sudo -E bin/fw tier0 approve" \
             "su root -c 'bin/fw tier0 approve'" \
             "runuser -u root -- bin/fw tier0 approve" \
             "tmux new -d 'bin/fw tier0 approve'" \
             "screen -dm bin/fw tier0 approve" \
             "setsid bin/fw tier0 approve" \
             "nohup bin/fw tier0 approve" \
             "env -i bin/fw tier0 approve" \
             "bash -c 'bin/fw tier0 approve'" \
             "sh -c \"bin/fw tier0 approve\"" \
             "CLAUDECODE= bin/fw tier0 \`echo approve\`" \
             "CLAUDECODE= bin/fw tier0 appr{o,}ve" \
             "CLAUDECODE= bin/fw tier0 approv\$'e'" \
             "bin/fw tier\"\"0 approve" \
             "bin/fw tier\$'0' approve" \
             "X=tier0; CLAUDECODE= bin/fw \$X approve" \
             "bin/fw tier0 approve" \
             "python3 lib/tier0_action.py approve-pending" \
             "python3 -c 'import tier0_action as t; t._save(\".\", [])'"; do
        run _gate "$c"
        [ "$status" -eq 2 ] || { echo "not blocked: $c"; return 1; }
        [[ "$output" == *"SELF-APPROVAL"* ]] || { echo "no label: $c"; echo "$output"; return 1; }
    done
}

@test "F1 CONTROL: plainly spelled read-only verbs and merely naming the module are not Tier 0" {
    local c
    for c in "bin/fw tier0 status" "fw tier0 list" ".agentic-framework/bin/fw tier0" \
             "cd /opt/x && bin/fw tier0 status" \
             "cat lib/tier0_action.py" "grep -n approve lib/tier0_action.py" \
             "python3 lib/tier0_action.py status" \
             "bats tests/unit/tier0_idempotency.bats" \
             "git commit -m \"T-3593: Tier 0 grammar\""; do
        run _gate "$c"
        [ "$status" -eq 0 ] || { echo "blocked: $c"; echo "$output"; return 1; }
    done
}

# ── Claude round-4 F2: persistent include.path / includeIf ──────────────────

@test "F2: git config include.path / includeIf.* is labelled HOOK BYPASS like core.hooksPath; reads are not" {
    local c
    for c in "git config --global include.path /tmp/x" \
             "git config --system include.path /tmp/x" \
             "git config include.path /tmp/x" \
             "git config --global includeIf.gitdir:/x/.path /tmp/x" \
             "git -C $W config --add include.path /tmp/x"; do
        run _gate "$c"
        [ "$status" -eq 2 ] || { echo "not blocked: $c"; return 1; }
        [[ "$output" == *"HOOK BYPASS"* ]] || { echo "no label: $c"; return 1; }
    done
    run _gate "git config --get include.path"
    [ "$status" -eq 0 ]
    run _gate "git config --list"
    [ "$status" -eq 0 ]
}

# ── T-3610 false positive: the -c must be git's own option ──────────────────

@test "T-3610: stat -c / bash -c after a .git/hooks path are not a -c core.hooksPath bypass (reproduced, then fixed)" {
    local c
    for c in $'git -C /tmp/x status\nstat -c \'%y %n\' /.git/hooks/commit-msg' \
             $'ls /x/.git/hooks/pre-push\nbash -c \'echo a b\'\ngit -C /tmp log' \
             "stat -c '%y %n' /.git/config /.git/hooks/commit-msg" \
             "git log --stat -c '%y %n' -- .git"; do
        run _gate "$c"
        [ "$status" -eq 0 ] || { echo "blocked: $c"; echo "$output"; return 1; }
    done
}

@test "T-3610 CONTROL: git's own -c core.hooksPath / include.path / blanked value is still labelled" {
    local c
    for c in "git -c core.hooksPath=/dev/null push origin main" \
             "git -C $W -c core.hookspath=/dev/null push origin main" \
             "git -c include.path=/tmp/x push origin main" \
             "git -c 'a b' push origin main" \
             "git --config-env=core.hooksPath=V push origin main"; do
        run _gate "$c"
        [ "$status" -eq 2 ] || { echo "not blocked: $c"; return 1; }
        [[ "$output" == *"HOOK BYPASS"* ]] || { echo "no label: $c"; return 1; }
    done
}

# ── rm -rf sub/../.. (round-4 pre-existing gap: no control at all) ──────────

@test "rm with . or .. as the last component is Tier 0 now (was SAFE); ordinary relative deletes are not" {
    local c
    for c in "rm -rf sub/../.." "rm -rf .." "rm -rf ../" "rm -rf x/.." "rm -rf ./"; do
        run _gate "$c"
        [ "$status" -eq 2 ] || { echo "not blocked: $c"; return 1; }
        [[ "$output" == *"RECURSIVE DELETE"* ]] || { echo "no label: $c"; return 1; }
    done
    for c in "rm -rf ../build" "rm -rf .venv" "rm -rf sub/build" "rm -rf ./build"; do
        run _gate "$c"
        [ "$status" -eq 0 ] || { echo "blocked: $c"; return 1; }
    done
}

# ── codex MEDIUM: the legacy path fails closed without the lock ─────────────

@test "lock: a held approval lock makes the legacy path fail closed — nothing consumed, block says why" {
    local typed="FOO=1 git reset --hard HEAD"
    run _gate "$typed"
    [ "$status" -eq 2 ]
    _approve >/dev/null
    [ -f "$W/.context/working/.tier0-approval" ]
    python3 -c '
import fcntl, sys, time
f = open(sys.argv[1], "a")
fcntl.flock(f, fcntl.LOCK_EX)
open(sys.argv[2], "w").close()
time.sleep(60)' "$W/.context/working/.tier0-approval.lock" "$FX/held" &
    HOLDER=$!
    local i=0
    while [ ! -f "$FX/held" ] && [ "$i" -lt 100 ]; do sleep 0.05; i=$((i + 1)); done
    [ -f "$FX/held" ]
    TIER0_LOCK_TIMEOUT=1 run _gate "$typed"
    [ "$status" -eq 2 ]
    [[ "$output" == *"approval lock could not be taken"* ]]
    # the approval was neither consumed nor cleaned up
    [ -f "$W/.context/working/.tier0-approval" ]
    kill "$HOLDER"; wait "$HOLDER" 2>/dev/null || true; HOLDER=""
    run _gate "$typed"
    [ "$status" -eq 0 ]
    [ ! -f "$W/.context/working/.tier0-approval" ]
}

@test "lock: no dependency on util-linux flock — a failing flock on PATH changes nothing" {
    mkdir -p "$FX/bin"
    printf '#!/bin/sh\nexit 1\n' > "$FX/bin/flock"
    chmod +x "$FX/bin/flock"
    local typed="FOO=1 git reset --hard HEAD"
    PATH="$FX/bin:$PATH" run _gate "$typed"
    [ "$status" -eq 2 ]
    _approve >/dev/null
    PATH="$FX/bin:$PATH" run _gate "$typed"
    [ "$status" -eq 0 ]
    PATH="$FX/bin:$PATH" run _gate "$typed"
    [ "$status" -eq 2 ]
}

# ── codex MEDIUM: a reset that ACTUALLY runs, then a second attempt ─────────

@test "real reset (exact-text path): approved 'git reset --hard HEAD~1' runs once; a fresh call is refused; the branch moved once" {
    _commit one; local c1; c1=$(git rev-parse HEAD)
    _commit two; local c2; c2=$(git rev-parse HEAD)
    local typed="git reset --hard HEAD~1"
    run _gate_id toolu_A "$typed"
    [ "$status" -eq 2 ]
    [[ "$output" == *"Not mapped to an action"* ]]     # ~ is outside the grammar
    _approve >/dev/null
    run _gate_id toolu_B "$typed"
    [ "$status" -eq 0 ]
    git reset -q --hard HEAD~1                          # the admitted call runs
    [ "$(git rev-parse HEAD)" = "$c1" ]
    run _gate_id toolu_C "$typed"
    [ "$status" -eq 2 ]                                 # refused: not run
    [ "$(git rev-parse HEAD)" = "$c1" ]
    [ "$(git rev-parse HEAD)" != "$c2" ]
}

@test "real reset (action path): approved reset to a commit runs once; after a new commit the same reset is refused" {
    _commit one; local c1; c1=$(git rev-parse HEAD)
    _commit two
    local typed="git reset --hard $c1"
    run _gate_id toolu_A "$typed"
    [ "$status" -eq 2 ]
    [[ "$output" == *"HARD-RESET branch 'main'"* ]]
    _approve >/dev/null
    run _gate_id toolu_B "$typed"
    [ "$status" -eq 0 ]
    git reset -q --hard "$c1"
    [ "$(git rev-parse HEAD)" = "$c1" ]
    _commit three; local c3; c3=$(git rev-parse HEAD)
    run _gate_id toolu_C "$typed"
    [ "$status" -eq 2 ]
    [ "$(git rev-parse HEAD)" = "$c3" ]
}
