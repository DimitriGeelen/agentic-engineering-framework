#!/usr/bin/env bash
# lib/branch-hygiene.sh — T-100143 (C2 of T-100139 branch/worktree lifecycle GO)
#
# WARN-only branch hygiene scan. Prints one finding per line to stdout and
# prints NOTHING when the repo is tidy — callers (fw doctor) wrap findings in
# their own WARN formatting and count lines. Always exits 0: this is an
# advisory rail, never a gate.
#
# Judged against TARGET = origin/master when present, else master. Repos with
# no master lineage produce no findings (nothing to judge against).
#
# Finding classes (one token-prefixed line each):
#   merged-undeleted <branch>                    local branch tip contained in TARGET
#   behind-threshold <branch> behind=<n> (threshold <t>)
#                                                live (unmerged) branch more than
#                                                FW_BRANCH_BEHIND_WARN (default 50)
#                                                commits behind TARGET, and NOT
#                                                ahead (pure lag — land with
#                                                `fw integrate run`)
#   diverged-fork <branch> ahead=<a> behind=<b> (threshold <t>)
#                                                live branch ahead of TARGET by MORE
#                                                than the threshold AND behind by more
#                                                than the threshold — a genuine
#                                                bidirectional fork, not a lag. A
#                                                bare go-live `git merge` conflicts;
#                                                reconcile while small (see T-100195).
#                                                (A small-ahead branch stays
#                                                behind-threshold: it lands cleanly.)
#   worktree-merged <path> branch=<branch>       linked worktree parked on an
#                                                already-merged branch
#   remote-contained origin/<branch>             remote ref fully contained in
#                                                TARGET (ahead:0 — deletable)
#
# Origin: T-100139 inception measured 29 merged-but-undeleted branches and live
# strands 215-248 commits behind master, all invisible. C1 (T-100142) deletes
# branches on verified `fw integrate run` landings; this scan surfaces the
# remaining debris. FW_BRANCH_BEHIND_WARN is shared with C3 (T-100144).
#
# T-100195 (RCA T-100194): the behind-only reading could not distinguish a
# bidirectional fork (host ALSO ahead) from a pure lag — the exact state that
# made a go-live `git merge origin/master` explode into 100+ conflicts. The
# `diverged-fork` class separates the two so the WARN can name the right remedy.

fw_branch_hygiene() {
    local repo="${1:-.}"
    local behind_warn="${FW_BRANCH_BEHIND_WARN:-50}"

    local target
    if git -C "$repo" rev-parse --verify -q origin/master >/dev/null 2>&1; then
        target=origin/master
    elif git -C "$repo" rev-parse --verify -q master >/dev/null 2>&1; then
        target=master
    else
        return 0
    fi

    local br behind ahead
    # ── local branches: merged-undeleted, else behind-threshold ──
    while IFS= read -r br; do
        [ -z "$br" ] && continue
        [ "$br" = "master" ] && continue
        if git -C "$repo" merge-base --is-ancestor "refs/heads/$br" "$target" 2>/dev/null; then
            echo "merged-undeleted $br"
        else
            behind=$(git -C "$repo" rev-list --count "refs/heads/$br..$target" 2>/dev/null || echo 0)
            ahead=$(git -C "$repo" rev-list --count "$target..refs/heads/$br" 2>/dev/null || echo 0)
            if [ "${behind:-0}" -gt "$behind_warn" ] && [ "${ahead:-0}" -gt "$behind_warn" ]; then
                # Bidirectional fork (T-100195): BOTH directions past threshold.
                # An unmerged branch behind master always has >=1 unique commit
                # (else it'd be an ancestor → merged-undeleted), so "any ahead"
                # would mislabel every landable feature branch. The dangerous case
                # — the T-100194 199/287 go-live explosion — is when the branch is
                # ALSO substantially ahead: a `git merge` conflicts and even a
                # one-way `fw integrate` cannot absorb what master has. Distinct
                # finding so the WARN names the reconcile-while-small remedy.
                echo "diverged-fork $br ahead=$ahead behind=$behind (threshold $behind_warn)"
            elif [ "${behind:-0}" -gt "$behind_warn" ]; then
                # Pure lag (small ahead): landable with a one-way `fw integrate`.
                echo "behind-threshold $br behind=$behind (threshold $behind_warn)"
            fi
        fi
    done < <(git -C "$repo" for-each-ref --format='%(refname:short)' refs/heads/)

    # ── linked worktrees parked on merged branches ──
    # First porcelain block is the main worktree — skip it; the branch findings
    # above already cover MAIN's checkout.
    local first_wt=1 wt_path="" wtb=""
    while IFS= read -r line; do
        case "$line" in
            "worktree "*) wt_path="${line#worktree }" ;;
            "branch refs/heads/"*)
                wtb="${line#branch refs/heads/}"
                if [ "$first_wt" = "1" ]; then
                    first_wt=0
                elif [ "$wtb" != "master" ] && \
                     git -C "$repo" merge-base --is-ancestor "refs/heads/$wtb" "$target" 2>/dev/null; then
                    echo "worktree-merged $wt_path branch=$wtb"
                fi
                ;;
        esac
    done < <(git -C "$repo" worktree list --porcelain 2>/dev/null)

    # ── remote refs fully contained in TARGET (ahead:0) ──
    while IFS= read -r br; do
        [ -z "$br" ] && continue
        case "$br" in origin/master|origin/HEAD*) continue ;; esac
        ahead=$(git -C "$repo" rev-list --count "$target..refs/remotes/$br" 2>/dev/null || echo 1)
        if [ "${ahead:-1}" = "0" ]; then
            echo "remote-contained $br"
        fi
    done < <(git -C "$repo" for-each-ref --format='%(refname:short)' refs/remotes/origin/)

    return 0
}

# ── T-100144 (C3 of T-100139): divergence summary for handover ──
# Prints machine-parseable lines for the current checkout vs origin/master:
#   divergence <branch> ahead=<n> behind=<n>     (any non-master branch)
#   fork ahead=<a> behind=<b> threshold=<t>      (T-100195: behind > threshold AND ahead > threshold —
#                                                bidirectional fork; a go-live `git merge` conflicts)
#   nudge behind=<n> threshold=<t>               (behind > FW_BRANCH_BEHIND_WARN AND ahead <= threshold —
#                                                pure/small lag; land with `fw integrate run`)
# Silent (no output, exit 0) on master, detached HEAD, or no origin/master —
# the handover stays neutral on a tidy checkout. Threshold shared with the
# fw_branch_hygiene doctor scan above. `fork` and `nudge` are mutually exclusive:
# a fork needs reconcile-while-small, a lag needs a one-way land — never both.
fw_branch_divergence() {
    local repo="${1:-.}"
    local br behind ahead warn
    br=$(git -C "$repo" branch --show-current 2>/dev/null)
    if [ -z "$br" ] || [ "$br" = "master" ]; then
        return 0
    fi
    git -C "$repo" rev-parse --verify -q origin/master >/dev/null 2>&1 || return 0
    set -- $(git -C "$repo" rev-list --left-right --count origin/master...HEAD 2>/dev/null)
    behind="${1:-0}"; ahead="${2:-0}"
    warn="${FW_BRANCH_BEHIND_WARN:-50}"
    echo "divergence $br ahead=$ahead behind=$behind"
    if [ "$behind" -gt "$warn" ] && [ "$ahead" -gt "$warn" ]; then
        echo "fork ahead=$ahead behind=$behind threshold=$warn"
    elif [ "$behind" -gt "$warn" ]; then
        echo "nudge behind=$behind threshold=$warn"
    fi
    return 0
}

# ── T-2516 (T-2121 prong 3): untracked .tasks/ files ──
# Prints one repo-relative path per line for each untracked (not tracked, not
# gitignored) file under .tasks/active/ or .tasks/completed/. Empty output +
# exit 0 on a clean tree. This is the early-detection rail for the active↔
# completed divergence class (T-2091): an orphaned untracked completion copy
# that never got committed was invisible for ~7 days because nothing surfaced
# untracked files under .tasks/. Read-only `git status --porcelain` scan.
fw_untracked_tasks() {
    local repo="${1:-.}"
    git -C "$repo" rev-parse --git-dir >/dev/null 2>&1 || return 0
    git -C "$repo" status --porcelain -- .tasks/active/ .tasks/completed/ 2>/dev/null \
        | sed -n 's/^?? //p'
    return 0
}
