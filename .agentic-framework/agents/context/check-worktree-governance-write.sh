#!/bin/bash
# T-3098 — Refuse governance writes from a linked git worktree.
#
# Executes slice 1 of T-2822's GO (operator, 2026-08-06). The mechanism, in
# T-2822's words: governance state is TRACKED CONTENT, so a worktree is by
# construction a fork of the governance state, and it begins diverging the
# moment either side writes. Source-only therefore cannot be implemented by
# keeping state OUT of a worktree — git puts it there — only by refusing to
# WRITE to the copy git put there.
#
# Scope, and why the blast radius is bounded by construction: a PreToolUse hook
# governs AGENT TOOL CALLS, not writes performed inside scripts (the Tier 0
# scope boundary, CLAUDE.md §Enforcement Tiers). `fw integrate`, `fw worktree`,
# `fw handover` and friends are untouched when they run as scripts. What is
# governed is an agent authoring governance state into a fork of it — the shape
# that lost T-2505, G-083 and 43 commits for five weeks.
#
# Detection: git-dir vs git-common-dir, via lib/paths.sh:fw_is_linked_worktree
# (verified in both directions by T-2822 S2). NEVER a substring test for
# ".claude/worktrees" — that is a naming convention, not an invariant, and
# re-implementing the primitive here is the L-399 producer/consumer split this
# whole defect class is about.
#
# Bypass: FW_ALLOW_WORKTREE_GOVERNANCE_WRITE=1 — an ENV VAR, not a flag, because
# the Write tool has no flag surface (same constraint as T-2205's producer 4).
# Every bypass writes a Tier-2 entry naming the PATH to
# .context/working/.gate-bypass-log.yaml. That is deliberate instrumentation,
# not an escape hatch: T-2822 shipped it so that "does any real workflow need
# governance writes from a worktree?" is answerable from the register in weeks
# instead of guessed at now.
#
# Exit codes (Claude Code PreToolUse semantics):
#   0 — allow (main checkout, non-git cwd, non-governance path, bypass, human)
#   2 — block (linked worktree + governance path, under agent control)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
source "$FRAMEWORK_ROOT/lib/paths.sh"
source "$FRAMEWORK_ROOT/lib/config.sh"
fw_hook_crash_trap "check-worktree-governance-write"

INPUT=$(cat)

# One python3 pass: tool name, the tool call's cwd, and the target path resolved
# to an absolute, normalised form (relative file_path is joined against cwd).
_PARSED=$(printf '%s' "$INPUT" | python3 -c '
import sys, json, os
try:
    d = json.load(sys.stdin)
except Exception:
    print(); print(); print(); raise SystemExit(0)
if not isinstance(d, dict):
    d = {}
cwd = d.get("cwd") or ""
ti = d.get("tool_input") or {}
if not isinstance(ti, dict):
    ti = {}
fp = ti.get("file_path") or ti.get("notebook_path") or ""
if fp and not os.path.isabs(fp) and cwd:
    fp = os.path.join(cwd, fp)
if fp:
    fp = os.path.normpath(fp)
print(d.get("tool_name") or "")
print(cwd)
print(fp)
' 2>/dev/null)

TOOL_NAME=$(printf '%s\n' "$_PARSED" | sed -n '1p')
CALL_CWD=$(printf '%s\n' "$_PARSED" | sed -n '2p')
FILE_PATH=$(printf '%s\n' "$_PARSED" | sed -n '3p')

case "$TOOL_NAME" in
    Write|Edit|MultiEdit|NotebookEdit) ;;
    *) exit 0 ;;
esac
[ -n "$FILE_PATH" ] || exit 0

# The tool call's cwd is the checkout being written from. Falling back to $PWD
# rather than $PROJECT_ROOT is deliberate: under `fw hook`, PROJECT_ROOT can
# resolve to the MAIN repo even when the tool ran in a worktree (T-2463/T-2465).
WT_DIR="${CALL_CWD:-$PWD}"
[ -d "$WT_DIR" ] || exit 0

# ── AC #1/#2: the whole discrimination, in one shared primitive ──
# fw_is_linked_worktree returns 1 for the main checkout (git-dir and
# git-common-dir collapse to the same path there, by definition) and 1 for a
# non-git directory. Both fall through to allow. The main checkout is never
# blocked — a false positive here would break every session in the repo.
fw_is_linked_worktree "$WT_DIR" || exit 0

# ── Governance-path filter ──
# Anchored to the worktree's own toplevel, not a bare "*/.tasks/*" glob: an
# absolute write that targets the MAIN checkout's .tasks/ from a worktree shell
# is the correct move this gate recommends, and must not be blocked by it.
WT_TOP=$(git -C "$WT_DIR" rev-parse --show-toplevel 2>/dev/null) || exit 0
[ -n "$WT_TOP" ] || exit 0

GOV_REL=""
case "$FILE_PATH" in
    "$WT_TOP"/.context/*) GOV_REL=".context/" ;;
    "$WT_TOP"/.tasks/*)   GOV_REL=".tasks/" ;;
    *) exit 0 ;;
esac

# Main checkout path, for the block message's "correct move". git-common-dir is
# <main>/.git in the linked-worktree case, so its parent is the main root.
_GCD=$(git -C "$WT_DIR" rev-parse --git-common-dir 2>/dev/null || echo "")
case "$_GCD" in
    /*) ;;
    "") _GCD="$WT_DIR/.git" ;;
    *)  _GCD="$WT_DIR/$_GCD" ;;
esac
MAIN_ROOT=$(cd "$(dirname "$_GCD")" 2>/dev/null && pwd) || MAIN_ROOT="<main checkout>"
REL_PATH="${FILE_PATH#"$WT_TOP"/}"

# ── Bypass (AC #4/#5) ──
# Logged only when it actually bypassed a real refusal, so the register answers
# "does any real workflow need this" without noise from calls that were never
# going to block. The entry records the PATH, per AC #5.
if [ "${FW_ALLOW_WORKTREE_GOVERNANCE_WRITE:-0}" = "1" ]; then
    LOG_DIR="${PROJECT_ROOT:-$WT_DIR}/.context/working"
    mkdir -p "$LOG_DIR" 2>/dev/null || true
    LOG_FILE="$LOG_DIR/.gate-bypass-log.yaml"
    # L-392: double embedded single quotes for YAML single-quoted-scalar safety.
    _esc() { printf '%s' "${1//\'/\'\'}"; }
    {
        echo "- timestamp: '$(date -u +%Y-%m-%dT%H:%M:%SZ)'"
        echo "  task: '$(_esc "${FW_TASK_ID:-unknown}")'"
        echo "  flag: 'FW_ALLOW_WORKTREE_GOVERNANCE_WRITE'"
        echo "  caller: 'check-worktree-governance-write'"
        echo "  file: '$(_esc "$FILE_PATH")'"
        echo "  worktree: '$(_esc "$WT_TOP")'"
        echo "  main_checkout: '$(_esc "$MAIN_ROOT")'"
    } >> "$LOG_FILE" 2>/dev/null || true
    echo "NOTE: governance write to $REL_PATH from linked worktree $WT_TOP allowed via FW_ALLOW_WORKTREE_GOVERNANCE_WRITE=1 — logged Tier-2." >&2
    exit 0
fi

# T-1739 detection mirror: agent control = CLAUDECODE=1 OR AI_AGENT non-empty.
_under_agent_control() {
    [ "${CLAUDECODE:-}" = "1" ] && return 0
    [ -n "${AI_AGENT:-}" ] && return 0
    return 1
}

if ! _under_agent_control; then
    echo "NOTE: $REL_PATH is governance state inside linked worktree $WT_TOP — this write would block under agent control (T-3098)." >&2
    exit 0
fi

# ── Block message (AC #3) — written for the agent that trips it, per T-2139/T-2143.
# Names the correct move AND the bypass mechanism.
{
    echo ""
    echo "══════════════════════════════════════════════════════════"
    echo "  GOVERNANCE WRITE FROM A LINKED WORKTREE — refused (T-3098)"
    echo "══════════════════════════════════════════════════════════"
    echo ""
    echo "  Target:        $REL_PATH"
    echo "  Worktree:      $WT_TOP"
    echo "  Main checkout: $MAIN_ROOT"
    echo ""
    echo "  Why: governance state ($GOV_REL) is tracked content, so this"
    echo "  worktree holds a FORK of it. Writing here diverges the fork from"
    echo "  master and nothing reconciles the two — that is what stranded 43"
    echo "  commits, gap G-083 and task T-2505 for five weeks (T-2822, T-3097)."
    echo ""
    echo "  The correct move — make the edit on master, not here:"
    echo ""
    echo "    cd $MAIN_ROOT && \\"
    echo "      <re-run the same Write/Edit against $MAIN_ROOT/$REL_PATH>"
    echo ""
    echo "  Keep using this worktree for SOURCE. Build here, then land with"
    echo "  \`fw integrate run master --push\` from the main checkout. Only"
    echo "  .context/ and .tasks/ writes are refused."
    echo ""
    echo "  If this write genuinely belongs in the worktree, bypass with the"
    echo "  env var (the Write tool has no flag surface, so it must be env):"
    echo ""
    echo "    FW_ALLOW_WORKTREE_GOVERNANCE_WRITE=1"
    echo ""
    echo "  Every bypass is logged Tier-2 with the path to"
    echo "  .context/working/.gate-bypass-log.yaml — on purpose. T-2822 shipped"
    echo "  it so a legitimate worktree-governance workflow shows up as DATA"
    echo "  rather than as a silent workaround. Use it if you need it; do not"
    echo "  route around it."
    echo ""
} >&2
exit 2
