#!/usr/bin/env bash
# run-me.sh — the pending operator actions that are mechanical, in one place.
#
# Written 2026-09-24 for the operator, who asked for a script rather than
# copy-paste commands. Safe to run more than once: every step checks first and
# skips work already done.
#
# It does the MECHANICAL things only. Anything that is a decision — closing a
# task, ruling on an inception, changing a host binary — is printed at the end
# with its link, never done for you.
#
#   ./run-me.sh              do the mechanical steps, then list what needs you
#   ./run-me.sh --dry-run    show what would happen, change nothing
#   ./run-me.sh --list       skip the work, just list what needs you

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
DRY=0
LIST_ONLY=0
for a in "$@"; do
    case "$a" in
        --dry-run) DRY=1 ;;
        --list)    LIST_ONLY=1 ;;
        -h|--help) sed -n '2,14p' "$0"; exit 0 ;;
        *) echo "unknown option: $a (try --help)" >&2; exit 2 ;;
    esac
done

RED=$'\033[0;31m'; GRN=$'\033[0;32m'; YEL=$'\033[0;33m'; BLD=$'\033[1m'; NC=$'\033[0m'
ok()   { echo "  ${GRN}ok${NC}    $*"; }
skip() { echo "  ${YEL}skip${NC}  $*"; }
fail() { echo "  ${RED}FAIL${NC}  $*" >&2; }
step() { echo; echo "${BLD}$*${NC}"; }

rc_overall=0

# ─────────────────────────────────────────────────────────────────────────────
# STEP 1 — T-3389: bring the two external review documents into this repo.
#
# Why this is not automated: the two projects are separate governance domains.
# The framework's project-boundary gate (T-559) refuses cross-project reads from
# an agent session, by design, and two attempts to move the files by dispatched
# worker failed — one worker declined on an authorisation it could not verify
# (reasonable), and the model API's safeguard classifier blocked the second
# before it ran. You own both projects, so for you it is a copy.
#
# The files exist at named paths with published hashes (832 on the DM rail,
# offset 2; 0503's own docs/reports/T-047-aef-refusal-matrix-disposition.md).
# ─────────────────────────────────────────────────────────────────────────────
SRC_DIR="/opt/0503-codex-cli-playground/docs/reports"
DST_DIR="$ROOT/docs/research/executable-workflow/reviews"

# name → expected sha256
FILES=(
    "T-032-deepseek-review-response.md:4dae4098b2602b2794525292e1aa3053e0c486b23a67d9c3292ce80dc3a4d8a9"
    "T-032-mistral-review-response.md:0eecb8af7be56ba045581167ef66b73fd9d2aa17fcd241f84defc0e7d17bfb0e"
)

step "STEP 1 — T-3389: transfer the DeepSeek and Mistral review documents"

if [ "$LIST_ONLY" = 1 ]; then
    skip "--list given"
else
    if [ ! -d "$SRC_DIR" ]; then
        fail "source directory not found: $SRC_DIR"
        echo "        Is 0503-codex-cli-playground at a different path on this host?"
        echo "        Edit SRC_DIR at the top of this script and re-run."
        rc_overall=1
    else
        [ "$DRY" = 1 ] || mkdir -p "$DST_DIR"
        for entry in "${FILES[@]}"; do
            name="${entry%%:*}"; want="${entry##*:}"
            src="$SRC_DIR/$name"; dst="$DST_DIR/$name"

            if [ ! -f "$src" ]; then
                fail "$name — not at $src"
                rc_overall=1
                continue
            fi

            got_src="$(sha256sum "$src" | cut -d' ' -f1)"

            if [ -f "$dst" ]; then
                got_dst="$(sha256sum "$dst" | cut -d' ' -f1)"
                if [ "$got_dst" = "$want" ]; then
                    skip "$name — already here, hash matches"
                    continue
                fi
                fail "$name — already here but hash DIFFERS; not overwriting"
                echo "        on disk: $got_dst"
                echo "        expected: $want"
                rc_overall=1
                continue
            fi

            if [ "$DRY" = 1 ]; then
                ok "would copy $name  (source hash $got_src)"
                [ "$got_src" = "$want" ] || echo "        ${YEL}note${NC}  source hash differs from the published one"
                continue
            fi

            cp -- "$src" "$dst"
            got="$(sha256sum "$dst" | cut -d' ' -f1)"
            if [ "$got" = "$want" ]; then
                ok "$name  ($got)"
            else
                fail "$name — copied, but hash does NOT match the published value"
                echo "        got:      $got"
                echo "        expected: $want"
                echo "        The bytes differ from what 832 published. Do not build the"
                echo "        refusal matrix on these until that is explained."
                rc_overall=1
            fi
        done
    fi
fi

# ─────────────────────────────────────────────────────────────────────────────
# WHAT NEEDS YOU — decisions, not chores. Listed, never done.
# ─────────────────────────────────────────────────────────────────────────────
WT="$(cd "$ROOT" && bin/fw watchtower url 2>/dev/null || echo 'http://localhost:3000')"

step "WHAT NEEDS YOU — these are decisions; this script will not make them"

cat <<EOF

  1. T-2770 — read-only fw verbs auto-init into the caller's directory
     $WT/inception/T-2770
     Exploration is complete and the evidence reversed the original framing.
     Recommendation: GO, narrow rather than remove. The decisive finding is that
     our own documented \`curl | bash\` install once seeded a whole project into a
     user's directory behind a green checkmark; the fix went to the caller, not
     the branch, so every other caller still hits it.

  2. T-3449 — sixteen tasks are finished but stranded
     $WT/review/T-3449
     Each is owned by you, has no criterion left to verify, and cannot close
     without you. The task lists them with per-task evidence and a one-command
     close each. Deliberately NOT scripted here: the framework forbids
     batch-closing human-owned tasks, and each one deserves its own look.

  3. T-3445 — the delegation verb your ruling created
     $WT/review/T-3445
     One review criterion open, about a render surface that nets to zero.

  4. T-3358 — the stale claude-fw on this host
     /usr/bin/claude-fw is an unowned copy from 2026-08-01 with the old prompt
     regex and no exit marker. Root's shell PATH reaches the good one first, so
     it only bites launchers with a minimal PATH (cron, systemd, bare tmux).
     Reversible, and yours to run because it changes the host, not the repo:

       sudo mv /usr/bin/claude-fw /usr/bin/claude-fw.pre-T3346.bak && \\
       sudo ln -s /root/.local/bin/claude-fw /usr/bin/claude-fw

  5. Still open, no command attached: T-1820 (close as superseded, or keep),
     T-3441 (widen pickup's dedupe cooldown), the shared EWCR correlation
     ratification with 832, and continuous-run (disarm or re-arm).

EOF

step "NEXT"
if [ "$rc_overall" -eq 0 ] && [ "$LIST_ONLY" = 0 ] && [ "$DRY" = 0 ]; then
    echo "  Step 1 is done. Tell the session \"files are in\" and T-3389 gets"
    echo "  re-promoted and the refusal-matrix worker dispatched — its prompt is"
    echo "  already written."
else
    echo "  Nothing was changed."
fi
echo
exit "$rc_overall"
