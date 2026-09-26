#!/bin/bash
# task-parked.sh — the SINGLE reader for "is this task deliberately parked?"
#
# T-3511 (OBS-547). Extracted from lib/branch-hygiene.sh:_bh_governing_task, which
# T-3510 introduced one commit earlier, rather than writing a second copy for the
# pre-merge gate.
#
# Why extraction and not a second copy: arc membership reached FIVE independent
# implementations of one predicate in this repo, three of which disagreed about the
# legacy tag form, and the audit rail meant to catch that could only see the shell
# ones (OBS-546). The cost of that divergence was a full day of repair on
# 2026-09-26. Parked-ness is now read in two places — a reporting rail and a
# blocking gate — which is exactly the moment the second implementation usually
# appears.
#
# Parking is a TASK property, deliberately not a branch property:
#   status: captured   — filed, not started
#   horizon: later     — shelved (CLAUDE.md §Horizon)
# Both mean "unlanded on purpose". A `work-completed` task whose branch never
# landed is a genuine strand and is NOT parked.
#
# Functions:
#   fw_task_parked_state <repo> <task-id>   → "parked" | "live" | "" (no such task)
#   fw_branch_governing_task <repo> <branch> → "<task-id> parked|live" | "" (unresolvable)
#
# The empty return is load-bearing in both. A caller that cannot resolve a task
# must fall through to its prior behaviour, never to an assumed verdict: a default
# of "live" would read as coverage the predicate does not have, and a default of
# "parked" would silence real strands and block legitimate merges.

# Frontmatter only. A task body that DISCUSSES `status: captured` in prose is not
# itself captured — mention-vs-instance (L-576), which this repo has hit in four
# separate predicates including two written while measuring the class.
fw_task_parked_state() {
    local repo="$1" id="$2" f tf="" fm st hz
    [ -n "$repo" ] && [ -n "$id" ] || return 0
    id="${id#T-}"
    for f in "$repo/.tasks/active/T-$id-"*.md "$repo/.tasks/completed/T-$id-"*.md; do
        [ -f "$f" ] && { tf="$f"; break; }
    done
    [ -z "$tf" ] && return 0
    fm=$(awk 'NR==1 && $0!="---" {exit} NR>1 && $0=="---" {exit} NR>1 {print}' "$tf")
    st=$(printf '%s\n' "$fm" | sed -n 's/^status:[[:space:]]*//p'  | head -1 | tr -d "\"' ")
    hz=$(printf '%s\n' "$fm" | sed -n 's/^horizon:[[:space:]]*//p' | head -1 | tr -d "\"' ")
    case "$st:$hz" in
        captured:*|*:later) echo "parked" ;;
        *)                  echo "live" ;;
    esac
}

# Resolve a branch NAME to its governing task and that task's state.
#
# The branch→task link is the naming convention (`t3487-…` → T-3487) because no
# task in the corpus declares a branch: `grep -l "^branch:" .tasks/active/*.md`
# returned 0 of 487 on 2026-09-26. That makes this resolution a heuristic over a
# convention, which is precisely why an unresolvable name returns empty rather
# than a guess. Two of the four branches in the incident that produced this file
# — `dispatch-f25`, `dispatch-f21-f24` — carry no task id at all.
fw_branch_governing_task() {
    local repo="$1" br="${2#origin/}" id state
    [ -n "$repo" ] && [ -n "$br" ] || return 0
    # The digit class is what keeps `test-foo` and `tooling-x` out. Ids in this
    # corpus run 3-6 digits (T-332 … T-100201).
    case "$br" in
        [Tt][0-9][0-9][0-9]*|[Tt]-[0-9][0-9][0-9]*) : ;;
        *) return 0 ;;
    esac
    id=$(printf '%s\n' "$br" | sed -n 's/^[Tt]-\{0,1\}\([0-9]\{3,6\}\).*$/\1/p')
    [ -z "$id" ] && return 0
    state=$(fw_task_parked_state "$repo" "$id")
    [ -z "$state" ] && return 0
    echo "T-$id $state"
}
