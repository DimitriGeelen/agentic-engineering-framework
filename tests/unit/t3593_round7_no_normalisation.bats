#!/usr/bin/env bats
# T-3593 round 7 — NO NORMALISATION (docs/reports/T-3593-round6-codex.md).
#
# Every round since 4 found two DIFFERENT targets sharing one approval key
# because a name or path was normalised on the way in. Round 7 kills the class:
#   - pushes key on the FULL destination ref, at the text gate and at pre-push
#     (codex R6 HIGH: branch `refs/tags/x` = refs/heads/refs/tags/x vs tag x);
#   - local branch deletes on the literal name, rm on the literal operand;
#   - the exact-text fallback hashes the original bytes (codex R6 HIGH:
#     rm -rf ./ "a  b" vs "a b");
#   - ANSI-C strings end at a decoded NUL, as in bash (codex R6 MEDIUM);
#   - a module path inside an env-assignment value is not "running the module"
#     (the FW_VENDOR_ONLY=... bin/fw vendor self false block).
#
# SAFETY: fixtures only, under a tmpdir, with the git discovery fence. The hook
# only DECIDES; no branch is deleted, nothing is force-pushed, no rm runs.
# Approvals are fixture approvals with CLAUDECODE unset, in the fixture only.

load ../git_fence

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

setup() {
    FX="$(mktemp -d -t fw-t3593r7-XXXXXX)"
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
    echo zero > f.txt
    git add -A
    git commit -q -m "T-3593: c0"
    echo one > f.txt
    git commit -q -am "T-3593: c1"
    git branch x
    git branch X
    git branch victim
    git tag t1
    git remote add origin "$REMOTE"
    git push -q origin main 2>/dev/null
    unset CLAUDE_PROJECT_DIR TIER0_WATCHTOWER_TTL CDPATH TIER0_LOCK_TIMEOUT
    export FX REMOTE W NTFY_ENABLED=false
}

teardown() {
    cd /
    [ -n "${FX:-}" ] && [ -d "$FX" ] && rm -rf "${FX:?}"
    return 0
}

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

_mod() { PROJECT_ROOT="$W" python3 "$W/lib/tier0_action.py" "$@"; }

# $1 approved; $2.. must stay blocked; then $1 itself passes.
_approval_not_shared() {
    local approved="$1"; shift
    run _gate_id "toolu_a$RANDOM$RANDOM" "$approved"
    [ "$status" -eq 2 ] || { echo "not blocked: $approved"; echo "$output"; return 1; }
    _approve >/dev/null
    local c
    for c in "$@"; do
        run _gate_id "toolu_o$RANDOM$RANDOM" "$c"
        [ "$status" -eq 2 ] || { echo "approval for [$approved] admitted [$c]"; echo "$output"; return 1; }
    done
    run _gate_id "toolu_z$RANDOM$RANDOM" "$approved"
    [ "$status" -eq 0 ] || { echo "own approval not used: $approved"; echo "$output"; return 1; }
}

# ── codex R6 HIGH 1: branch refs/tags/x vs tag x ─────────────────────────────

@test "text gate: HEAD:refs/tags/x and HEAD:refs/heads/refs/tags/x key on their full, different refs" {
    run _gate "git push -f origin HEAD:refs/tags/x"
    [ "$status" -eq 2 ]
    [[ "$output" == *"FORCE-PUSH ref 'refs/tags/x' to remote 'origin'"* ]]
    run _gate "git push -f origin HEAD:refs/heads/refs/tags/x"
    [ "$status" -eq 2 ]
    [[ "$output" == *"FORCE-PUSH ref 'refs/heads/refs/tags/x' to remote 'origin'"* ]]
    run _gate "git push origin :refs/tags/x"
    [[ "$output" == *"DELETE ref 'refs/tags/x' on remote 'origin'"* ]]
    run _gate "git push origin :refs/heads/refs/tags/x"
    [[ "$output" == *"DELETE ref 'refs/heads/refs/tags/x' on remote 'origin'"* ]]
}

@test "text gate: an approval for one of the pair does not admit the other (force-push and delete)" {
    _approval_not_shared "git push -f origin HEAD:refs/tags/x" "git push -f origin HEAD:refs/heads/refs/tags/x"
    _approval_not_shared "git push -f origin HEAD:refs/heads/refs/tags/x" "git push -f origin HEAD:refs/tags/x"
    _approval_not_shared "git push origin :refs/tags/x" "git push origin :refs/heads/refs/tags/x"
    _approval_not_shared "git push origin :refs/heads/refs/tags/x" "git push origin :refs/tags/x"
}

@test "pre-push: an approval for tag refs/tags/x is not consumed by branch refs/heads/refs/tags/x (and back)" {
    python3 -c "
import sys; sys.path.insert(0, '$W/lib'); import tier0_action as t
t.approve('$W', [t.action('force-push', remote='origin', ref='refs/tags/x'),
                 t.action('branch-delete', remote='origin', ref='refs/heads/refs/tags/x')], 300)"
    run _mod prepush origin force-push refs/heads/refs/tags/x
    [ "$status" -eq 1 ]
    run _mod prepush origin branch-delete refs/tags/x
    [ "$status" -eq 1 ]
    # Each approval is still there for its own ref.
    run _mod prepush origin force-push refs/tags/x
    [ "$status" -eq 0 ]
    run _mod prepush origin branch-delete refs/heads/refs/tags/x
    [ "$status" -eq 0 ]
}

@test "pre-push keys exactly what git reports: refs/heads/main, never a stripped 'main'" {
    python3 -c "
import sys; sys.path.insert(0, '$W/lib'); import tier0_action as t
t.approve('$W', [t.action('force-push', remote='origin', ref='main')], 300)"
    run _mod prepush origin force-push refs/heads/main
    [ "$status" -eq 1 ]
    python3 -c "
import sys; sys.path.insert(0, '$W/lib'); import tier0_action as t
t.approve('$W', [t.action('force-push', remote='origin', ref='refs/heads/main')], 300)"
    run _mod prepush origin force-push refs/heads/main
    [ "$status" -eq 0 ]
    [[ "$output" == *"FORCE-PUSH ref 'refs/heads/main' to remote 'origin'"* ]]
}

# ── codex R6 HIGH 2: quoted whitespace in the exact-text hash ───────────────

@test "exact text: rm -rf ./ \"a  b\" approval does not admit rm -rf ./ \"a b\" (raw-byte hash)" {
    # A mismatched exact-text approval is discarded on sight (pre-existing
    # policy), so each pairing gets its own fresh approval.
    local other
    for other in 'rm -rf ./ "a b"' "rm -rf ./ 'a  b'" 'rm -rf  ./ "a  b"'; do
        run _gate 'rm -rf ./ "a  b"'
        [ "$status" -eq 2 ]
        _approve >/dev/null
        run _gate "$other"
        [ "$status" -eq 2 ] || { echo "admitted: $other"; return 1; }
    done
    run _gate 'rm -rf ./ "a  b"'
    [ "$status" -eq 2 ]
    _approve >/dev/null
    run _gate 'rm -rf ./ "a  b"'
    [ "$status" -eq 0 ]
}

# ── codex R6 MEDIUM: NUL truncation in $'..' ────────────────────────────────

@test "ANSI-C NUL truncation: \$'tier\\0junk'0 and \$'tier\\x00junk'0 spell tier0 and are blocked" {
    local c
    for c in "env -u CLAUDECODE bin/fw \$'tier\\0junk'0 approve" \
             "env -u CLAUDECODE bin/fw \$'tier\\x00junk'0 approve" \
             "bin/fw \$'tier\\0'0 approve" \
             "bin/fw \$'tier\\u0000zz'0 approve" \
             "bin/fw \$'tier\\c@zz'0 approve" \
             "bin/fw \$'tier\\000'0 approve"; do
        run _gate "$c"
        [ "$status" -eq 2 ] || { echo "SAFE: $c"; return 1; }
        [[ "$output" == *"SELF-APPROVAL"* ]] || { echo "wrong risk: $c"; echo "$output"; return 1; }
    done
}

@test "ANSI-C NUL truncation: bash itself really does truncate (the premise)" {
    [ "$(printf '%s' $'tier\0junk'0)" = "tier0" ]
    [ "$(printf '%s' $'tier\x00junk'0)" = "tier0" ]
}

@test "ANSI-C with NUL but no tier0 word stays SAFE" {
    run _gate "printf %s \$'abc\\0def'"
    [ "$status" -eq 0 ]
}

# ── Process: FW_VENDOR_ONLY path list is not running the module ─────────────

@test "FW_VENDOR_ONLY naming lib/tier0_action.py in a quoted list is SAFE (was a false block)" {
    local c
    for c in 'FW_VENDOR_ONLY="lib/tier0_action.py agents/context/check-tier0.sh" bin/fw vendor self' \
             'FW_VENDOR_ONLY="agents/x lib/tier0_action.py lib/y" bin/fw vendor self' \
             "FW_VENDOR_ONLY='lib/tier0_action.py lib/y' bin/fw vendor self --check" \
             'git commit -m "T-3593: x" -- lib/tier0_action.py agents/context/check-tier0.sh'; do
        run _gate "$c"
        [ "$status" -eq 0 ] || { echo "blocked: $c"; echo "$output"; return 1; }
    done
}

@test "the module EXECUTED in command position is still blocked, with or without leading assignments" {
    local c
    for c in './lib/tier0_action.py use text-gate x' \
             'X=1 ./lib/tier0_action.py use text-gate x' \
             'A=1 B="x y" lib/tier0_action.py prepush origin force-push refs/heads/main' \
             'true && ./lib/tier0_action.py write-pending a b' \
             'exec ./lib/tier0_action.py use a b' \
             "./lib/tier0_action\".py\" use a b"; do
        run _gate "$c"
        [ "$status" -eq 2 ] || { echo "SAFE: $c"; return 1; }
    done
    run _gate './lib/tier0_action.py status'
    [ "$status" -eq 0 ]
}

# ── The sweep: distinct targets → distinct keys, or unmapped ────────────────

@test "sweep: every verb, every spelling — the key is the literal fully-qualified target, or unmapped" {
    run python3 - "$W" <<'PY'
import sys, os
W = sys.argv[1]
sys.path.insert(0, W + "/lib")
import tier0_action as t
flag = lambda text: True
def key(cmd):
    a = t.classify(cmd, flag, W, W)
    return None if a is None else [t.action_key(x) for x in a]
fail = []
def expect(cmd, want):
    got = key(cmd)
    if got != want:
        fail.append(f"{cmd!r}: got {got}, want {want}")

# Push: (dst spelling, the full ref it is, or None = unmapped)
push = [("x", "refs/heads/x"), ("refs/heads/x", "refs/heads/x"),
        ("X", "refs/heads/X"), ("refs/heads/X", "refs/heads/X"),
        ("t1", "refs/tags/t1"), ("refs/tags/t1", "refs/tags/t1"),
        ("refs/tags/x", "refs/tags/x"), ("refs/heads/refs/tags/x", "refs/heads/refs/tags/x"),
        ("refs/heads/refs/heads/x", "refs/heads/refs/heads/x"),
        ("x/", None), ("./x", None), ("refs/heads//x", None), ("refs/heads/./x", None),
        ("refs/heads/x/", None), ("refs//heads/x", None), ("refs/heads/x.lock", None),
        ('"refs/heads/a b"', None), ("'x'", None), ("+x", None), ("nosuch", None)]
for dst, full in push:
    expect(f"git push -f origin HEAD:{dst}",
           None if full is None else [f"force-push|ref={full}|remote=origin"])
    expect(f"git push origin :{dst}",
           None if full is None else [f"branch-delete|ref={full}|remote=origin"])
expect("git push -f origin HEAD", ["force-push|ref=refs/heads/main|remote=origin"])
expect("git push -f origin +main", ["force-push|ref=refs/heads/main|remote=origin"])

# Local branch -D: the literal name, never rewritten; invalid names unmapped.
repo = os.path.realpath(W)
for name, ok in [("victim", True), ("+victim", True), ("refs/heads/victim", True),
                 ("heads/victim", True), ("Victim", True), ("victim.x", True),
                 ("./victim", False), ("a//b", False), ("victim/", False),
                 ("'a b'", False), ("victim.lock", False)]:
    expect(f"git branch -D {name}",
           [f"branch-delete|ref={name}|remote=(local)|repo={repo}"] if ok else None)

# rm: the literal operand (relative ones after the cwd), never collapsed.
ops = ["d", "d/", "./d", "d//e", "d/e", "d/./e", "D", "d/.", ".", "./", "/abs/d",
       "/abs//d", "/abs/d/", "/abs/./d"]
keys = {}
for op in ops:
    p = op if op.startswith("/") else W + "/" + op
    expect(f"rm -rf {op}", [f"recursive-delete|path={p}"])
    keys[op] = p
if len(set(keys.values())) != len(ops):
    fail.append(f"rm keys collide: {keys}")
for op in ['"a b"', "'a  b'", "a\\ b"]:
    expect(f"rm -rf {op}", None)

# hard-reset: the branch fully qualified, the target the full commit id.
import subprocess
c0 = subprocess.run(["git", "-C", W, "rev-parse", "HEAD~1"], capture_output=True, text=True).stdout.strip()
c1 = subprocess.run(["git", "-C", W, "rev-parse", "HEAD"], capture_output=True, text=True).stdout.strip()
expect(f"git reset --hard {c0}", [f"hard-reset|branch=refs/heads/main|repo={repo}|target={c0}"])
expect("git reset --hard", [f"hard-reset|branch=refs/heads/main|repo={repo}|target={c1}"])

print("\n".join(fail) or "SWEEP-OK")
sys.exit(1 if fail else 0)
PY
    echo "$output"
    [ "$status" -eq 0 ]
    [[ "$output" == *"SWEEP-OK"* ]]
}

@test "display shows exactly the key (push, local delete, rm, reset)" {
    run _gate "git push -f origin HEAD:x"
    [[ "$output" == *"FORCE-PUSH ref 'refs/heads/x' to remote 'origin'"* ]]
    run _gate "git branch -D +victim"
    [[ "$output" == *"DELETE local branch '+victim'"* ]]
    run _gate "rm -rf d//e ./"
    [[ "$output" == *"RECURSIVELY DELETE $W/d//e"* ]]
    [[ "$output" == *"RECURSIVELY DELETE $W/./"* ]]
    run _gate "git reset --hard"
    [[ "$output" == *"HARD-RESET branch 'refs/heads/main' in $W to commit $(git rev-parse HEAD)"* ]]
}
