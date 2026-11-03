#!/usr/bin/env bats
#
# T-5039: read-only commands refused with no task in focus. 055 (msg 29facb2a) and
# 003 (msg 930eb9dc) reported them; AEF hit `gh run view` itself on 2026-11-03.
# Measured on current code, curl to /dev/null, sed -n, git grep and awk ranges
# already pass (pinned below so they stay that way); `termlink main am-i|status`
# and every `gh` read did not.
#
# Fix: agents/context/lib/safe-commands.sh — a `main` sub-arm in the termlink arm,
# and a `gh` arm of read-only verb pairs. Classification only: nothing is executed.
#
# `! cmd` at statement position is INERT in bats (L-628), so NOT-SAFE assertions use
# `if cmd; then false; fi`.

load helpers/known_cwd

setup() {
    ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    known_cwd_setup
    cd "$ROOT"
    source "$ROOT/agents/context/lib/safe-commands.sh"
}

teardown() { known_cwd_teardown; }

_refused() {
    local c
    for c in "$@"; do
        if is_bash_safe_command "$c"; then echo "SAFE (expected gated): $c"; return 1; fi
    done
}

_safe() {
    local c
    for c in "$@"; do
        is_bash_safe_command "$c" || { echo "gated (expected SAFE): $c"; return 1; }
    done
}

@test "T-5039: termlink main status and am-i are read-only" {
    _safe "termlink main am-i" "termlink main status"
}

@test "T-5039: termlink main claim, renew, release and pin stay gated" {
    _refused "termlink main claim" "termlink main renew" "termlink main release" "termlink main pin s1"
}

@test "T-5039: gh read verbs pass, including a quoted --jq expression" {
    _safe "gh run view 41709589836 --json status,jobs --jq '.status, (.jobs[] | \"\(.name): \(.conclusion)\")'" \
        "gh run list --limit 3" "gh run watch 1 --exit-status" \
        "gh pr view 5" "gh pr list --state open" "gh pr diff 5" "gh pr checks 5" "gh pr status" \
        "gh issue view 114" "gh issue list --limit 5" "gh issue status" \
        "gh release view v1.8.15" "gh release list" "gh repo view" \
        "gh workflow list" "gh workflow view test.yml" "gh auth status"
}

@test "T-5039: gh writes and gh api stay gated" {
    _refused "gh api repos/x/y" "gh api -X POST repos/x/y/issues" \
        "gh pr merge 5" "gh pr create --fill" "gh pr checkout 5" "gh pr comment 5 --body x" \
        "gh pr review 5 --approve" "gh pr close 5" "gh pr edit 5 --title x" \
        "gh issue create --title x" "gh issue comment 5 --body x" "gh issue close 5" \
        "gh run download 1" "gh run rerun 1" "gh run cancel 1" \
        "gh release create v9" "gh release upload v9 f" "gh release delete v9" \
        "gh repo clone x/y" "gh workflow run test.yml" "gh auth login" \
        "gh -R x/y pr merge 5"
}

@test "T-5039: forms already passing stay passing (curl to /dev/null, sed -n, git grep, awk range)" {
    _safe "curl -s -o /dev/null -w '%{http_code}' http://localhost:1/x" \
        "sed -n 1,5p README.md" "git grep foo" "awk '/a/,/b/' README.md"
}

@test "T-5039: their write forms stay gated (curl -o file, sed w and e commands)" {
    _refused "curl -s -o out.html http://x" "sed -n '/a/w /tmp/x' README.md" "sed -n 'e touch /tmp/q' README.md"
}
