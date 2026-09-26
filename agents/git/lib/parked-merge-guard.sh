#!/bin/bash
# parked-merge-guard.sh — refuse a merge whose source branch's governing task is
# deliberately parked (T-3511, prevention leg of OBS-547).
#
# Usage: parked-merge-guard.sh check     (exit 0 = allow, 1 = block, 2 = usage error)
#
# ORIGIN. On 2026-09-26 a TermLink batch-merge worker merged four unlanded branches
# into bleeding-edge. One was `t3487-remove-bvp-arc-approval-gate`, whose governing
# task T-3487 was `captured` / `horizon: later` on an UNANSWERED Sovereign question.
# The merge took the `fw arc close` identity gate — earned over four repeat
# incidents (T-1670/T-1671) — off by default. No rule was broken and no gate was
# bypassed: three locally-defensible decisions composed, because parking is recorded
# in the TASK and a branch sweeper reads TOPOLOGY. T-3510 stopped the audit
# RECOMMENDING such a merge; this file refuses it.
#
# ── COVERAGE, MEASURED NOT ASSUMED (T-3511 AC 1) ────────────────────────────────
# Which hook git fires depends on the merge shape. Measured on git 2.43.0 in a
# scratch repo, because the whole point of this guard is defeated if it hangs off a
# hook that does not fire for the shape an incident uses (L-573: a gate can be
# green, tested and structurally unreachable at the same time):
#
#   clean merge commit   pre-merge-commit + commit-msg     GUARDED  ← the incident
#                        `.git` holds NOTHING yet (no MERGE_HEAD/MERGE_MSG); the
#                        merged names arrive as GITHEAD_<sha>=<name> in the env,
#                        with GIT_REFLOG_ACTION="merge <name…>" as a second source.
#   conflicted merge     none during merge; then
#                        pre-commit + commit-msg           GUARDED  (via MERGE_HEAD,
#                                                          which git HAS written by
#                                                          the resolving commit)
#   git merge --squash   pre-commit + commit-msg           DETECTED, source branch
#                                                          NOT resolvable — the
#                                                          commit is a separate
#                                                          process, so neither
#                                                          MERGE_HEAD nor GITHEAD_*
#                                                          survives → warns, allows
#   fast-forward         post-merge + reference-transaction NOT GUARDED — no
#                                                          pre-merge/pre-commit hook
#                                                          fires at all, because no
#                                                          commit object is created
#
# The first version of this guard keyed solely on MERGE_HEAD and was therefore inert
# for the clean-merge row — the incident's own shape — while its unit-level checks
# passed. Recorded because reading the code did not reveal it; the end-to-end tests
# did.
#
# The fast-forward gap is REAL and is filed, not implied. Closing it would need the
# `reference-transaction` hook, which fires on every ref update in the repo
# (commits, fetches, resets) — a much larger blast radius than this guard warrants.
# Stated here because an unstated gap reads as coverage, which is the exact defect
# class the session that produced this file spent a day repairing.
#
# Bypass: FW_ALLOW_PARKED_MERGE=1 git merge …     (Tier-2, WARN to stderr)
#     or: git merge --no-verify …                 (Tier-0, skips the hook entirely)
#
# An ENV VAR and not a flag, deliberately: `git merge` rejects unknown options, so a
# `--allow-parked` contract would be unreachable from the very command this guard
# gates. That is L-399 / T-1890 — a bypass contract whose downstream consumer
# rejects it is a silent governance failure, because the agent then reaches for a
# path the gate cannot see.

set -uo pipefail

cmd="${1:-check}"
[ "$cmd" = "check" ] || { echo "usage: parked-merge-guard.sh check" >&2; exit 2; }

PROJECT_ROOT="${PROJECT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null)}"
[ -n "$PROJECT_ROOT" ] || exit 0   # not a git repo → nothing to guard

GIT_DIR_PATH="$(git rev-parse --git-dir 2>/dev/null)" || exit 0
case "$GIT_DIR_PATH" in
    /*) ;;
    *)  GIT_DIR_PATH="$PROJECT_ROOT/$GIT_DIR_PATH" ;;
esac

# ── is a merge in progress, and of WHAT? ────────────────────────────────────────
#
# MEASURED, and the first version of this file got it wrong. During
# `pre-merge-commit` on a CLEAN merge git has written NOTHING to `.git` yet — no
# MERGE_HEAD, no MERGE_MSG, no SQUASH_MSG (probed on 2.43.0). A guard keyed on
# MERGE_HEAD is therefore a silent no-op for precisely the shape the 2026-09-26
# incident used, which is the same "guard narrower than the thing it guards" defect
# this whole repair exists to fix. It was caught by the end-to-end tests, not by
# reading the code.
#
# What git DOES provide at that moment is the environment:
#   GITHEAD_<sha>=<name>       one per merged head, value as named on the CLI
#   GIT_REFLOG_ACTION=merge <name…>
#
# Two independent sources, so a future git that drops the GITHEAD_* convention
# degrades to the reflog string rather than to silence.
in_merge=no
candidates=""

# (a) Conflicted-merge resolve path: git DID write MERGE_HEAD, and the guard is
#     reached from pre-commit on the resolving `git commit`.
if [ -f "$GIT_DIR_PATH/MERGE_HEAD" ]; then
    in_merge=yes
    if [ -f "$GIT_DIR_PATH/MERGE_MSG" ]; then
        # MERGE_MSG records the NAME git was asked to merge. Preferred over
        # resolving the sha, because --points-at also returns unrelated branches
        # that happen to share a tip, which would over-block.
        candidates=$(head -1 "$GIT_DIR_PATH/MERGE_MSG" 2>/dev/null \
                     | grep -o "'[^']*'" | tr -d "'" || true)
    fi
    if [ -z "$candidates" ]; then
        while IFS= read -r _sha; do
            [ -n "$_sha" ] || continue
            candidates="$candidates
$(git for-each-ref --format='%(refname:short)' --points-at "$_sha" refs/heads refs/remotes 2>/dev/null || true)"
        done < "$GIT_DIR_PATH/MERGE_HEAD"
    fi
fi

# (b) Clean-merge path: pre-merge-commit, nothing on disk, names in the env.
if [ "$in_merge" = no ]; then
    _gh=$(env | sed -n 's/^GITHEAD_[0-9a-f]\{7,40\}=//p' || true)
    if [ -n "$_gh" ]; then
        in_merge=yes
        candidates="$_gh"
    fi
fi

# (c) Fallback if GITHEAD_* is ever absent: the reflog action git is about to write.
if [ "$in_merge" = no ]; then
    case "${GIT_REFLOG_ACTION:-}" in
        "merge "*)
            in_merge=yes
            candidates=$(printf '%s\n' "${GIT_REFLOG_ACTION#merge }" | tr ' ' '\n')
            ;;
    esac
fi

if [ "$in_merge" = no ]; then
    if [ -f "$GIT_DIR_PATH/SQUASH_MSG" ]; then
        # Detected, honestly incomplete: `git merge --squash` stages the source
        # content and then a SEPARATE `git commit` process creates the commit — so
        # neither MERGE_HEAD nor GITHEAD_* is available by then, and SQUASH_MSG
        # lists commits rather than the branch. Say so rather than pass silently.
        echo "NOTE: parked-merge-guard cannot check a --squash merge (T-3511)." >&2
        echo "  The commit happens in a separate process with no MERGE_HEAD and no" >&2
        echo "  GITHEAD_* env, so the source branch is not recoverable here." >&2
        echo "  If you are squashing a branch whose task is parked, verify it yourself." >&2
    fi
    exit 0
fi

# ── the shared parked-ness predicate (one implementation, T-3511) ───────────────
FRAMEWORK_ROOT="$PROJECT_ROOT"
if [ -f "$PROJECT_ROOT/.framework.yaml" ]; then
    _fw_path=$(grep "^framework_path:" "$PROJECT_ROOT/.framework.yaml" 2>/dev/null | sed 's/framework_path:[[:space:]]*//')
    [ -n "$_fw_path" ] && [ -d "$_fw_path" ] && FRAMEWORK_ROOT="$_fw_path"
fi
[ ! -f "$FRAMEWORK_ROOT/lib/task-parked.sh" ] \
    && [ -f "$PROJECT_ROOT/.agentic-framework/lib/task-parked.sh" ] \
    && FRAMEWORK_ROOT="$PROJECT_ROOT/.agentic-framework"

TP="$FRAMEWORK_ROOT/lib/task-parked.sh"
if [ ! -f "$TP" ]; then
    # Degrade to ALLOW — a guard that failed closed on its own missing dependency
    # would block every merge in the repo. But never silently (T-2647: a control
    # that no-ops is indistinguishable from one that passed).
    echo "WARNING: parked-merge-guard is NOT running (T-3511) — predicate not found at:" >&2
    echo "  $TP" >&2
    echo "Merges of deliberately-parked branches are unguarded." >&2
    echo "Fix: cd $PROJECT_ROOT && bin/fw upgrade   (framework repo: bin/fw vendor self)" >&2
    exit 0
fi
# shellcheck source=lib/task-parked.sh
. "$TP"

parked_hits=""
seen=""
while IFS= read -r br; do
    [ -n "$br" ] || continue
    case " $seen " in *" $br "*) continue ;; esac
    seen="$seen $br"
    gov=$(fw_branch_governing_task "$PROJECT_ROOT" "$br" 2>/dev/null || true)
    [ -n "$gov" ] || continue                      # unresolvable → not this guard's business
    [ "${gov##* }" = "parked" ] || continue
    parked_hits="$parked_hits
  $br  →  ${gov%% *}"
done <<EOF
$candidates
EOF

[ -n "${parked_hits// /}" ] || exit 0

# ── bypass, checked only once the guard would actually have blocked ─────────────
# Ordered this way so a merge that was never going to be refused does not emit a
# Tier-2 bypass warning, which would train people to ignore the warning.
if [ "${FW_ALLOW_PARKED_MERGE:-0}" = "1" ]; then
    echo "WARN: parked-merge-guard bypassed via FW_ALLOW_PARKED_MERGE=1 (Tier-2) — merging:$parked_hits" >&2
    exit 0
fi

cat >&2 <<MSG

BLOCKED: this merge lands a branch whose governing task is PARKED.
$parked_hits

A parked task means unlanded ON PURPOSE — status \`captured\` or \`horizon: later\`,
usually with an open question in the task body. Topology cannot tell that apart
from "nobody got to it yet", which is how the arc-close sovereignty gate came off
by default on 2026-09-26 (OBS-547).

Read the task before deciding. Then pick one:

  1. The task should proceed — unpark it first, so the record matches the tree:
       bin/fw task update ${parked_hits##*→  } --horizon now
  2. It genuinely should land while parked (rare — say why):
       FW_ALLOW_PARKED_MERGE=1 git merge <branch>          # Tier-2, logged
  3. It should NOT land — drop it from this merge. If you are batch-landing
     several branches, merge them one at a time so one parked branch does not
     ride in with three ready ones. That is exactly what happened.

If the task carries a Sovereign question, option 1 is NOT yours to take: surface
it to the operator rather than unparking to clear the block.
MSG
exit 1
