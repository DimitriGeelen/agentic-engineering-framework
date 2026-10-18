#!/usr/bin/env bats
#
# T-4264 (F-26, greenfield run): git takes its global options BEFORE the sub-verb.
# The git arm read the word after `git` as the verb, so `git -C DIR status` saw
# `-C` and was gated. _fw_git_skip_globals strips the globals first.
#
# `! cmd` at statement position is INERT in bats (L-628) — this file uses
# `if cmd; then false; fi` for NOT-SAFE assertions.

setup() {
    ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    LIB="$ROOT/agents/context/lib/safe-commands.sh"
    source "$LIB"
    # T-4343: -C / --git-dir / --work-tree are SAFE only inside PROJECT_ROOT, so the
    # SAFE cases below use the project itself. The /tmp cases stay as NOT-SAFE controls.
    export PROJECT_ROOT="$ROOT"
    export _FW_PAYLOAD_CWD="$ROOT"
}

# ── read verbs behind value-taking globals ───────────────────────────────────

@test "T-4264: git -C DIR status is SAFE" {
    is_bash_safe_command "git -C $ROOT status"
}

@test "T-4264: git -C DIR log is SAFE" {
    is_bash_safe_command "git -C $ROOT log --oneline -3"
}

@test "T-4264: git --git-dir=X log is SAFE" {
    is_bash_safe_command "git --git-dir=.git log"
}

@test "T-4264: git --work-tree=X diff is SAFE" {
    is_bash_safe_command "git --work-tree=. diff"
}

@test "T-4264: git -C DIR rev-parse is SAFE" {
    is_bash_safe_command "git -C $ROOT rev-parse --show-toplevel"
}

# ── flag-only globals ────────────────────────────────────────────────────────

@test "T-4264: git --no-pager log is SAFE" {
    is_bash_safe_command "git --no-pager log -1"
}

@test "T-4264: git -P log is SAFE" {
    is_bash_safe_command "git -P log -1"
}

# ── -c k=v: never read-only (fails closed; a key denylist cannot be complete) ──

@test "T-4264 control: git -c user.name=x status is NOT-SAFE (-c fails closed, even an ordinary key)" {
    if is_bash_safe_command "git -c user.name=x status"; then false; fi
}

@test "T-4264 control: git -c diff.x.textconv=CMD log -p is NOT-SAFE (textconv runs CMD)" {
    if is_bash_safe_command "git -c diff.x.textconv=touch log -p"; then false; fi
}

@test "T-4264 control: git -c core.pager=CMD log is NOT-SAFE (pager runs CMD)" {
    if is_bash_safe_command "git -c core.pager=touch log"; then false; fi
}

@test "T-4264 control: git -c core.fsmonitor=CMD status is NOT-SAFE (runs CMD)" {
    if is_bash_safe_command "git -c core.fsmonitor=touch status"; then false; fi
}

# ── control cases: write verbs behind the same globals stay refused ──────────

@test "T-4264 control: git -C DIR commit is NOT-SAFE" {
    if is_bash_safe_command "git -C /tmp commit -m x"; then false; fi
}

@test "T-4264 control: git --git-dir=X commit is NOT-SAFE" {
    if is_bash_safe_command "git --git-dir=.git commit -m x"; then false; fi
}

@test "T-4264 control: git -C DIR branch -D x is NOT-SAFE (ref delete)" {
    if is_bash_safe_command "git -C /tmp branch -D x"; then false; fi
}

@test "T-4264 control: git -C DIR tag -d x is NOT-SAFE (ref delete)" {
    if is_bash_safe_command "git -C /tmp tag -d x"; then false; fi
}

@test "T-4264 control: git -C DIR with no sub-verb is NOT-SAFE" {
    if is_bash_safe_command "git -C /tmp"; then false; fi
}

@test "T-4264 control: unknown global option before the verb is NOT-SAFE (fail closed)" {
    if is_bash_safe_command "git --exec-path=/x status"; then false; fi
}

# ── F-26 '2>&1' compound form ────────────────────────────────────────────────
# Bare `git status 2>&1` was already SAFE before this fix; the form that
# reproduced F-26 is the one with a global option in front of the verb.

@test "T-4264: git -C DIR status 2>&1 is SAFE (F-26 compound form)" {
    is_bash_safe_command "git -C $ROOT status 2>&1"
}

@test "T-4264 control: git -C DIR commit 2>&1 is NOT-SAFE" {
    if is_bash_safe_command "git -C /tmp commit -m x 2>&1"; then false; fi
}
