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
#   behind-threshold <branch> behind=<n> days=<d> (threshold <t>)
#                                                live (unmerged) branch more than
#                                                FW_BRANCH_BEHIND_WARN (default 50)
#                                                commits behind TARGET, NOT ahead
#                                                (pure lag — land with `fw integrate
#                                                run`), AND untouched for at least
#                                                FW_BRANCH_STALE_DAYS days (T-3094).
#                                                Both conditions are required: the
#                                                behind-count alone crosses 50 in
#                                                ~1.2 days on a busy repo and fires
#                                                on every healthy branch.
#   diverged-fork <branch> ahead=<a> behind=<b> days=<d> (threshold <t>)
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
#   worktree-unlanded <path> branch=<branch> ahead=<n> days=<d>
#                                                linked worktree whose branch
#                                                carries <n> commits NOT reachable
#                                                from TARGET, last touched <d> days
#                                                ago. The strand class: a worktree
#                                                that still holds work nobody has
#                                                landed. Judged against the same
#                                                TARGET as every other class, so a
#                                                worktree is never both merged and
#                                                unlanded (T-3101).
#   remote-contained origin/<branch>             remote ref fully contained in
#                                                TARGET (ahead:0 — deletable)
#   remote-unlanded origin/<branch> ahead=<n>    remote ref carrying <n> commits
#                                                that are NOT in TARGET. Judged
#                                                independently of any local branch
#                                                of the same name — the two can be
#                                                in opposite states (T-3092).
#                                                Excludes the current branch's own
#                                                upstream: that is where you are
#                                                standing, not a strand.
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

# T-3094 (T-3093 slice 1): days since the last commit ON a ref, or "" if unknown.
# Staleness has to be measured on the branch, not on the target. The behind-count
# answers "how much happened elsewhere", which on this repo is ~41 commits/day and
# 88% governance churn — it crosses a 50-commit threshold in ~1.2 days and fires on
# every healthy branch. "Nobody has touched this in N days" is the question that
# actually separates a strand from work in progress. Same unit and default as
# FW_STALE_ARC_DAYS (T-1855).
_bh_days_since_commit() {
    local repo="$1" ref="$2" last now
    last=$(git -C "$repo" log -1 --format=%ct "$ref" 2>/dev/null) || return 0
    [ -z "$last" ] && return 0
    now=$(date +%s 2>/dev/null) || return 0
    echo $(( (now - last) / 86400 ))
}

fw_branch_hygiene() {
    local repo="${1:-.}"
    local behind_warn="${FW_BRANCH_BEHIND_WARN:-50}"
    local stale_days="${FW_BRANCH_STALE_DAYS:-30}"

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
            # T-3094: a branch someone is actively working on is not a strand,
            # however far behind it has fallen. Recency gates BOTH staleness
            # classes; an unknown date (shallow clone, broken ref) is treated as
            # stale so the rail fails loud rather than silent.
            local _days
            _days=$(_bh_days_since_commit "$repo" "refs/heads/$br")
            if [ -n "$_days" ] && [ "$_days" -lt "$stale_days" ]; then
                continue
            fi
            local _dtag="days=${_days:-unknown}"
            if [ "${behind:-0}" -gt "$behind_warn" ] && [ "${ahead:-0}" -gt "$behind_warn" ]; then
                # Bidirectional fork (T-100195): BOTH directions past threshold.
                # An unmerged branch behind master always has >=1 unique commit
                # (else it'd be an ancestor → merged-undeleted), so "any ahead"
                # would mislabel every landable feature branch. The dangerous case
                # — the T-100194 199/287 go-live explosion — is when the branch is
                # ALSO substantially ahead: a `git merge` conflicts and even a
                # one-way `fw integrate` cannot absorb what master has. Distinct
                # finding so the WARN names the reconcile-while-small remedy.
                echo "diverged-fork $br ahead=$ahead behind=$behind $_dtag (threshold $behind_warn)"
            elif [ "${behind:-0}" -gt "$behind_warn" ]; then
                # Pure lag (small ahead): landable with a one-way `fw integrate`.
                echo "behind-threshold $br behind=$behind $_dtag (threshold $behind_warn)"
            fi
        fi
    done < <(git -C "$repo" for-each-ref --format='%(refname:short)' refs/heads/)

    # ── linked worktrees: parked on a merged branch, or holding unlanded work ──
    # First porcelain block is the main worktree — skip it; the branch findings
    # above already cover MAIN's checkout.
    #
    # T-3101 (slice 2 of T-2822 F5). This loop asked one question — "is this
    # worktree parked on something already landed?" — and said nothing about the
    # opposite, far more expensive, state: a worktree holding work that is NOT on
    # master. Two linked worktrees in this repo held 43 unlanded commits (6 + 37)
    # dormant from 2026-07-01 and no surface reported a count or an age for five
    # weeks. `worktree-merged` is the deletable case; `worktree-unlanded` is the
    # lossy one.
    #
    # PRECEDENCE: merged wins, and is tested first. This is not a tie-break — the
    # two classes are mutually exclusive by construction. A branch that is an
    # ancestor of TARGET has, by definition, zero commits in `TARGET..branch`, so
    # the `ahead > 0` guard can never fire for a merged branch. The if/else plus
    # the guard is belt-and-braces: if a future edit loosens the ancestor test
    # (e.g. to content-equality, the way `fw worktree gc` compares), the ordering
    # still keeps a single verdict per worktree. Never emit both for one path —
    # "delete this" and "you will lose 37 commits" are opposite instructions.
    #
    # An empty rev-list result is a sentinel, not a zero: a failed count must stay
    # silent rather than manufacture a strand out of an error (same reasoning as
    # the remote loop below).
    local first_wt=1 wt_path="" wtb=""
    while IFS= read -r line; do
        case "$line" in
            "worktree "*) wt_path="${line#worktree }" ;;
            "branch refs/heads/"*)
                wtb="${line#branch refs/heads/}"
                if [ "$first_wt" = "1" ]; then
                    first_wt=0
                elif [ "$wtb" != "master" ]; then
                    if git -C "$repo" merge-base --is-ancestor "refs/heads/$wtb" "$target" 2>/dev/null; then
                        echo "worktree-merged $wt_path branch=$wtb"
                    else
                        local _wt_ahead _wt_days
                        _wt_ahead=$(git -C "$repo" rev-list --count "$target..refs/heads/$wtb" 2>/dev/null || echo "")
                        if [ -n "$_wt_ahead" ] && [ "$_wt_ahead" -gt 0 ]; then
                            # Age is measured on the branch's own last commit, the
                            # same question `_bh_days_since_commit` answers for the
                            # local-branch classes (T-3094). No recency gate here:
                            # unlanded work is a strand on day 0 as much as on day
                            # 50 — the count is the risk, the age is the context.
                            _wt_days=$(_bh_days_since_commit "$repo" "refs/heads/$wtb")
                            echo "worktree-unlanded $wt_path branch=$wtb ahead=$_wt_ahead days=${_wt_days:-unknown}"
                        fi
                    fi
                fi
                ;;
        esac
    done < <(git -C "$repo" worktree list --porcelain 2>/dev/null)

    # ── remote refs: contained (deletable) vs carrying unlanded commits ──
    #
    # T-3092. This loop originally asked one question — "which remote refs can I
    # delete?" — and emitted nothing for the complement. A remote ref carrying
    # UNLANDED commits matched no arm: not reported as risky, not reported at all.
    #
    # The live miss that produced this fix: origin/t2416-fw-safe-mode-hook-timing
    # held 202 unlanded commits — two test files, five research artefacts and six
    # unread .pickup/ messages that existed nowhere else — and was invisible here,
    # while its LOCAL namesake (an ancestor of origin/master) was reported
    # `merged-undeleted`. Same name, opposite states. An operator reading the scan
    # concluded t2416 was landed and deletable. Local and remote are judged
    # independently on purpose: neither verdict may suppress the other.
    #
    # The current branch's own upstream is excluded. It is not a strand — it is
    # where you are standing, fw_branch_divergence below reports it in detail, and
    # a permanent WARN for your own working branch is exactly the noise that
    # trains people to stop reading this section.
    local remote_ahead upstream=""
    upstream=$(git -C "$repo" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null || echo "")
    while IFS= read -r br; do
        [ -z "$br" ] && continue
        case "$br" in origin/master|origin/HEAD*) continue ;; esac
        [ -n "$upstream" ] && [ "$br" = "$upstream" ] && continue
        # An empty sentinel, not the old `|| echo 1`. That fallback was harmless
        # while ahead!=0 was the silent case; now that it emits, a failed rev-list
        # would manufacture a finding out of an error. Stay silent instead.
        remote_ahead=$(git -C "$repo" rev-list --count "$target..refs/remotes/$br" 2>/dev/null || echo "")
        [ -z "$remote_ahead" ] && continue
        if [ "$remote_ahead" = "0" ]; then
            echo "remote-contained $br"
        else
            echo "remote-unlanded $br ahead=$remote_ahead"
        fi
    done < <(git -C "$repo" for-each-ref --format='%(refname:short)' refs/remotes/origin/)

    return 0
}

# ── T-3092: class-representative truncation for callers with a display cap ──
#
# fw_doctor prints at most 12 findings. That cap was positional (`head -12`), and
# the emission order is local branches → worktrees → remote refs, so on a repo
# with 12+ local findings the remote classes were cut off ENTIRELY. On this repo
# at the time of writing: 19 findings, and 0 of the 4 `remote-unlanded` lines
# survived the cap. A finding class that is always truncated has not shipped.
#
# Reads findings on stdin, writes at most $1 of them to stdout: first one line
# per distinct class (so every class that fired is visible), then the remainder
# in original order until the cap. Fewer findings than the cap passes through
# unchanged. Order within the output is not contractual; coverage is.
fw_branch_hygiene_head() {
    local cap="${1:-12}"
    awk -v cap="$cap" '
        { line[NR] = $0; cls[NR] = $1 }
        END {
            n = 0
            for (i = 1; i <= NR; i++) {
                if (!(cls[i] in seen) && n < cap) { seen[cls[i]] = 1; pick[i] = 1; n++ }
            }
            for (i = 1; i <= NR; i++) {
                if (!pick[i] && n < cap) { pick[i] = 1; n++ }
            }
            for (i = 1; i <= NR; i++) if (pick[i]) print line[i]
        }'
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

# ── T-100196 (Leg 2 of T-100195/T-100194): safe go-live routing ──
# Consumes the same ahead/behind classification as fw_branch_divergence and
# takes the SAFE action for the current checkout instead of leaving the
# operator to run a bare `git merge origin/master` (the T-100194 explosion:
# 100+ conflicts from a genuine bidirectional fork). This is the "lightweight
# fw go-live guard" recorded as defense-in-depth in T-100196's Decisions
# (mechanism (c) — session-on-master — is the primary fix; this guard covers
# the case where a branch drifts anyway).
#
# Routing (threshold shared with FW_BRANCH_BEHIND_WARN, default 50):
#   up to date (ahead=0 behind=0)         → report, no-op
#   ahead-only (ahead>0 behind=0)         → report, no-op (nothing to absorb)
#   diverged-fork (ahead>t AND behind>t)  → REFUSE. Never merges. Names the
#                                            reconcile-while-small remedy.
#   ff-clean (ahead=0 behind>0)           → safe fast-forward
#                                            (`git merge --ff-only`, cannot conflict)
#   nudge (0<ahead<=t, behind>t)          → advise landing the unique commits
#                                            via `fw integrate run` (one-way)
#                                            rather than merging origin/master in
#   minor (0<ahead<=t, 0<behind<=t)       → advise `fw sync` (rebase+push)
#
# Exit codes: 0 = no action needed / safely reconciled / advisory printed.
#             1 = refused (fork) or an attempted fast-forward failed.
#             2 = usage error (not a repo / no origin / no origin/master).
fw_go_live() {
    local repo="${1:-.}"
    local warn="${FW_BRANCH_BEHIND_WARN:-50}"

    git -C "$repo" rev-parse --git-dir >/dev/null 2>&1 || {
        echo "not a git repository: $repo" >&2
        return 2
    }
    git -C "$repo" remote 2>/dev/null | grep -qx 'origin' || {
        echo "no 'origin' remote — nothing to reconcile" >&2
        return 2
    }
    git -C "$repo" fetch origin master >/dev/null 2>&1
    git -C "$repo" rev-parse --verify -q origin/master >/dev/null 2>&1 || {
        echo "origin/master not found — nothing to reconcile against" >&2
        return 2
    }

    local branch ahead behind
    branch=$(git -C "$repo" branch --show-current 2>/dev/null)
    set -- $(git -C "$repo" rev-list --left-right --count origin/master...HEAD 2>/dev/null)
    behind="${1:-0}"; ahead="${2:-0}"

    if [ "$ahead" -eq 0 ] && [ "$behind" -eq 0 ]; then
        echo "up to date with origin/master."
        return 0
    fi

    if [ "$ahead" -gt "$warn" ] && [ "$behind" -gt "$warn" ]; then
        echo "REFUSED: diverged-fork (ahead=$ahead behind=$behind, threshold $warn)." >&2
        echo "A bare 'git merge origin/master' will conflict (see T-100194) — not doing that." >&2
        echo "Reconcile while small instead:" >&2
        echo "  - merge origin/master INTO ${branch:-HEAD} and resolve by hand, or" >&2
        echo "  - reset ${branch:-HEAD} if its unique commits already landed elsewhere, or" >&2
        echo "  - route through the T-2473 union resolver once it lands." >&2
        echo "See T-100195 (detection) / T-100194 (RCA)." >&2
        return 1
    fi

    if [ "$ahead" -eq 0 ]; then
        echo "ff-clean (ahead=0 behind=$behind) — fast-forwarding."
        if git -C "$repo" merge --ff-only origin/master; then
            echo "fast-forwarded to origin/master."
            return 0
        fi
        echo "fast-forward failed unexpectedly — investigate before retrying." >&2
        return 1
    fi

    if [ "$behind" -eq 0 ]; then
        echo "ahead of origin/master (ahead=$ahead) — nothing to reconcile; push when ready (fw sync / fw push)."
        return 0
    fi

    if [ "$behind" -gt "$warn" ]; then
        echo "behind-threshold (ahead=$ahead behind=$behind, threshold $warn) — a lag with unique commits, not a fork."
        echo "Land your unique commits with 'fw integrate run master --push' (one-way) rather than merging origin/master in."
        return 0
    fi

    echo "minor divergence (ahead=$ahead behind=$behind, threshold $warn) — reconcile with 'fw sync' (rebase+push) when ready."
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
