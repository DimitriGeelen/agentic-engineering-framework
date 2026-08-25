#!/bin/bash
# Task-First Enforcement Hook — PreToolUse gate for Write/Edit/Bash tools
# Blocks file modifications when no active task is set in focus.yaml.
#
# Exit codes (Claude Code PreToolUse semantics):
#   0 — Allow tool execution
#   2 — Block tool execution (stderr shown to agent)
#
# Receives JSON on stdin with tool_name and tool_input.
# For Write/Edit: checks tool_input.file_path
# For Bash: checks tool_input.command against safe-command allowlist (T-650)
#
# Exempt paths (framework operations that don't need task context):
#   .context/   — Context fabric management
#   .tasks/     — Task creation/updates
#   .claude/    — Claude Code settings
#
# Part of: Agentic Engineering Framework (P-002: Structural Enforcement)

set -uo pipefail

# --- FW_SAFE_MODE escape hatch (T-650) ---
# Disables task gate only. Tier 0 and boundary check remain active.
if [ "${FW_SAFE_MODE:-0}" = "1" ]; then
    echo "SAFE MODE: Task gate bypassed (FW_SAFE_MODE=1)" >&2
    exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$FRAMEWORK_ROOT/lib/paths.sh"
source "$FRAMEWORK_ROOT/lib/config.sh"
fw_hook_crash_trap "check-active-task"

# T-3038 (OBS-291): resolve focus through the shared helper so this gate reads
# the same file `fw context focus` wrote. Under FW_SESSION_SCOPED_FOCUS=1 that is
# a session-local focus.<key>.yaml; otherwise the shared focus.yaml, unchanged.
#
# The READER falls back to the shared file when the scoped one does not exist yet
# — and that fallback is deliberate, not defensive padding. A dispatched worker
# that never calls `fw work-on` should still be governed by the parent's active
# task rather than being refused for having no focus of its own. Inheriting is
# safe (read-only on the shared file); only WRITING it was ever the hijack.
_resolve_focus_file() {
    local f
    f=$(fw_focus_file "$PROJECT_ROOT")
    if [ ! -f "$f" ] && [ -f "$PROJECT_ROOT/.context/working/focus.yaml" ]; then
        f="$PROJECT_ROOT/.context/working/focus.yaml"
    fi
    printf '%s\n' "$f"
}
FOCUS_FILE=$(_resolve_focus_file)

# Read stdin (JSON from Claude Code)
INPUT=$(cat)

# Extract tool name and inputs
TOOL_NAME=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    print(data.get('tool_name', ''))
except:
    print('')
" 2>/dev/null)

# T-2463/T-2465 (OBS-080): re-anchor PROJECT_ROOT to the per-call stdin `cwd` so a
# worktree session reads the worktree's focus, not main's. In a worktree session
# this gate is invoked as <main>/bin/fw hook and bin/fw resolves PROJECT_ROOT to
# the MAIN repo; the shared resolver re-anchors to the project the tool actually
# ran in. Logic now lives in lib/paths.sh:fw_reanchor_from_cwd (generalized from
# the original inline block so every hook shares one implementation). No-op for
# non-worktree sessions. Recompute FOCUS_FILE after, since it caches PROJECT_ROOT.
fw_reanchor_from_hook_stdin "$INPUT"
FOCUS_FILE=$(_resolve_focus_file)   # T-3038: re-resolve, PROJECT_ROOT just moved

# --- Drift-target extraction (T-1730; hoisted out of the gate by T-2880) ---
# Answers ONE purely syntactic question: does this command name a task?
# It reads only $1 — no focus, no filesystem — which is why it can run in the
# Bash fast path far above the point where focus.yaml is parsed (line ~186).
#
# T-2880: that hoist is the whole fix. The fast path used to answer "does this
# need an active task?" with `exit 0`, and that single early return silently
# answered a SECOND, independent question — "is this attributed to the right
# task?" — with "don't care". The two are not the same question:
#
#     needs a task?          about the SESSION state  (is any work in progress)
#     attributed correctly?  about the COMMAND        (does it name another task)
#
# A command can be safe on the first and wrong on the second. `fw context
# add-learning "x" --task T-OTHER` needs no active task (T-2878 — it is what
# the framework prescribes right after completion, which is the exact moment
# focus is null) and is still misattributed if focus points elsewhere.
# Collapsing both into one `exit 0` made drift pattern 2 unreachable the moment
# T-2878 safe-listed the capture verbs — a gate that stopped being consulted
# while every test stayed green (L-555).
#
# Kept as ONE definition on purpose: the gate below consumes this result rather
# than re-deriving it, so the two call sites cannot drift apart.
_fw_extract_drift_target() {
    local c="$1"
    # Pattern 1: fw task update T-NNNN (mutation)
    if [[ "$c" =~ (^|[[:space:]])(bin/)?fw[[:space:]]+task[[:space:]]+update[[:space:]]+(T-[0-9]+) ]]; then
        printf '%s' "${BASH_REMATCH[3]}"; return 0
    fi
    # Pattern 2: fw context add-* --task T-NNNN
    # T-2879: anchored, for the same reason T-2833 anchored pattern 3 below. The prior
    # form was two independent regexes ANDed — "fw context add-" present anywhere AND
    # "--task T-N" present anywhere — so the extracted id need not belong to the
    # add-* invocation at all. `fw context add-learning "x"; fw task list --task T-9`
    # extracted T-9 as the add-*'s target. Requiring the flag to follow the verb with
    # no chain separator (| ; &) between them ties the id to its own command.
    #
    # 832 rail 474 §4 reported this class against their vendored copy and I answered
    # that it did not reproduce here. That answer was wrong, and wrong in an avoidable
    # way: I measured only `fw context add-*` shapes WITHOUT a --task flag, which
    # cannot trip pattern 2 at all. Corrected on the rail.
    #
    # RESIDUAL, unfixed and not fixable with bash regex — identical to the one T-2833
    # documented for pattern 3: a command whose QUOTED PAYLOAD contains a literal
    # `fw context add-learning ... --task T-N` still matches, because the regex cannot
    # see quote nesting. That is how this was hit live (a probe script listing example
    # invocations as test strings). The T-1890 bypass mechanisms cover it, but it means
    # rail posts and doc writes quoting real commands can still trip. Severity revised
    # UP from "low" per 832 rail 478 §4: for agents whose medium is prose-containing-
    # commands this is not an edge case — it blocked them on a rail post and mis-parsed
    # a task name in two consecutive sessions.
    if [[ "$c" =~ (^|[[:space:]])(bin/)?fw[[:space:]]+context[[:space:]]+add-[a-z-]+[^|\;\&]*--task[[:space:]=]+(T-[0-9]+) ]]; then
        printf '%s' "${BASH_REMATCH[3]}"; return 0
    fi
    # Pattern 3: git commit ... -m/--message "T-NNNN: ..." (the canonical
    # T-XXX: prefix marker). T-2833: anchored to the actual -m/--message flag
    # value, not "leftmost T-N: anywhere in the string". The prior form was
    # two independent regexes ANDed together — "git commit" present anywhere
    # AND a T-N: pattern present anywhere — so the extracted id need not
    # belong to the commit's own message at all. That produced a fail-open
    # false negative (prose naming the focused task ahead of a commit that
    # actually targets a different one read as "no drift") and a false
    # positive (a grep pattern or earlier command's text supplying a T-N: the
    # real commit doesn't target). Anchoring to the flag matches the P-002
    # commit-msg convention the id is meant to describe in the first place.
    # Known residual limit, not fixed here: a doc-write whose payload
    # literally contains a working `git commit -m "T-N: ..."` example still
    # matches, since bash regex cannot see quote-nesting. See T-2833.
    if [[ "$c" =~ (^|[[:space:]])git[[:space:]]+commit ]] && \
       [[ "$c" =~ (^|[[:space:]])(-[a-zA-Z]*m[a-zA-Z]*|--message)(=|[[:space:]]+)[\'\"]?(T-[0-9]+): ]]; then
        printf '%s' "${BASH_REMATCH[4]}"; return 0
    fi
    return 0
}

# --- Bash tool: safe-command fast path (T-650) ---
DRIFT_TARGET=""
SAFE_ALLOWED=0
if [ "$TOOL_NAME" = "Bash" ]; then
    BASH_CMD=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    print(data.get('tool_input', {}).get('command', ''))
except:
    print('')
" 2>/dev/null)

    # fw hook commands are always allowed (hooks calling hooks)
    case "$BASH_CMD" in
        "fw hook "*|"bin/fw hook "*)
            exit 0
            ;;
    esac

    # T-2410 case 2: universal --help / --version exemption.
    # Any command with --help or --version is read-only by convention (the flag
    # short-circuits all real work in every fw subcommand and 99% of other
    # tools). Without this, `fw upstream --help` blocked at the work-completed
    # focus gate purely because `upstream` is not in the safe-list — but the
    # user just wanted to read help. Matches at any position so `cd … && fw
    # upstream --help` is also exempt.
    if [[ "$BASH_CMD" =~ (^|[[:space:]])(--help|--version)([[:space:]]|$) ]]; then
        exit 0
    fi

    # Source safe-command allowlist
    source "$SCRIPT_DIR/lib/safe-commands.sh" 2>/dev/null || true

    # T-2880: ask the attribution question BEFORE honouring the safety answer.
    # Purely syntactic, no focus read — see _fw_extract_drift_target above.
    DRIFT_TARGET=$(_fw_extract_drift_target "$BASH_CMD")

    # T-2936: task-bootstrap exemption, decided BEFORE the write-pattern chain.
    #
    # The bootstrap branch further down (~:198, T-2052) is only reachable when no
    # write pattern matched, and its own comment says so. That ordering assumes a
    # write pattern means a write. It does not when the operator is inside a QUOTED
    # PAYLOAD: `fw task create --name "count 11->10"` matches `[^2>&]>[^>&]`, so
    # creating a task is classified as a file write and blocked for having no active
    # task — while the block message names that very command as the way out. With
    # focus null there is then no route back inside the sanctioned path. Hit live
    # filing T-2935; proven by changing one character class (` to ` was allowed).
    #
    # Decided on a QUOTE-STRIPPED view so the exemption cannot swallow a real
    # redirect: `fw task create --name 'x' > /tmp/out` still has its `>` outside
    # quotes after stripping, still matches, still falls through to the gate.
    # Both failure directions of the stripper are safe: under-stripping leaves the
    # metacharacter and blocks (today's behaviour, loud); an unbalanced quote fails
    # to match the strip pattern at all and also blocks. It can only fail toward
    # BLOCKING, which is the direction the T-2880 note above argues for.
    #
    # L-432 (T-2052) is this class keyed on a command's first WORD; this is the
    # same class keyed on its quoted PAYLOAD — the hazard the pattern-3 comments
    # at :102-108 already record for other branches, unfixed for this one.
    if [[ "$BASH_CMD" =~ (^|[[:space:]]|/)fw[[:space:]]+(work-on|task[[:space:]]+create|context[[:space:]]+focus|inception)([[:space:]]|$) ]]; then
        _bootstrap_unquoted=$(printf '%s' "$BASH_CMD" | sed "s/'[^']*'//g; s/\"[^\"]*\"//g")
        if ! { type has_bash_write_pattern &>/dev/null && has_bash_write_pattern "$_bootstrap_unquoted"; }; then
            exit 0
        fi
    fi

    # Check write patterns FIRST — even "safe" commands with redirects are writes
    if type has_bash_write_pattern &>/dev/null && has_bash_write_pattern "$BASH_CMD"; then
        # Command has write patterns — fall through to active-task check
        :
    elif type is_bash_safe_command &>/dev/null && is_bash_safe_command "$BASH_CMD"; then
        # Safe command with no write patterns.
        #
        # T-2880: only take the early return when the command names NO task.
        # When it does, safety is established but attribution is not, so we
        # record the safety verdict and fall through to the drift gate, which
        # needs focus.yaml and therefore cannot run this high in the file.
        #
        # WHICH WAY THE OMISSION FAILS is the reason SAFE_ALLOWED is consumed at
        # exactly ONE checkpoint (the null-focus branch, ~line 300) and not at
        # the stale-focus / G-013 / status checks. A flag honoured at one site
        # fails toward BLOCKING if that site is ever missed — the deadlock comes
        # back loudly, with a remedy in the block message. A flag that three
        # sites must each remember fails toward PERMITTING: one site forgets and
        # the gate silently stops enforcing, which is the exact failure this
        # task exists to repair. Do not widen the flag's reach without inverting
        # that argument first. (832 rail 478 §1 reached the same fork from the
        # other side and named the deciding property; this is the answer.)
        if [ -z "$DRIFT_TARGET" ]; then
            exit 0
        fi
        SAFE_ALLOWED=1
    elif [[ "$BASH_CMD" =~ (^|[[:space:]]|/)fw[[:space:]]+(work-on|task[[:space:]]+create|context[[:space:]]+focus|inception)([[:space:]]|$) ]]; then
        # Task-bootstrap commands always allowed (T-2052) — they ESTABLISH the
        # active task, so gating them on one is a deadlock; the "No active task"
        # block message below even lists them as the unblock path. Whole-command
        # match survives a `cd … && bin/fw …` prefix and multi-line forms, which
        # is_bash_safe_command's first-word base extraction misses (that fragility
        # is what caused the deadlock). Reached only when no write pattern is
        # present — the if-branch above already caught those.
        exit 0
    fi

    # Non-safe or write-pattern Bash commands: fall through to active-task check.
    # FILE_PATH stays empty for Bash — exempt-path check won't match,
    # so we go straight to the task-exists check.
fi

# --- T-2987: explain WHY the advertised remedy did not apply -----------------
#
# Every block below names a bootstrap command (`fw work-on` / `context focus`)
# as the unblock path, and the exemption at :194 and :227 honours exactly that.
# But the exemption is guarded by has_bash_write_pattern, which classifies the
# WHOLE command line while the exemption is about ONE command in it. So a `>`
# anywhere on the line — on an unrelated chained command, or merely capturing
# the bootstrap command's own output — voids it:
#
#     fw work-on T-016                 -> allowed
#     fw work-on T-016 && fw doctor    -> allowed
#     fw work-on T-016 > out.txt 2>&1  -> BLOCKED, and the block re-advertises
#                                         the very command that just failed
#
# That is a loop: identical message, no signal to change SHAPE rather than
# target. Reported from a fresh consumer whose focus pointed at a completed
# T-001 (T-2987), and hit in-session before that.
#
# The guard is NOT the bug and is not relaxed here — :213-222 argues for failing
# toward blocking, and L-547 (T-2834) says a fast-path exemption must classify
# the whole command. Widening it would admit `fw work-on X > .claude/settings.json`.
# The bug is that six sites advertise a remedy without its precondition. This
# emits the precondition; permissions are unchanged.
_bootstrap_shape_hint() {
    local cmd="${1:-}"
    [ -n "$cmd" ] || return 0
    [[ "$cmd" =~ (^|[[:space:]]|/)fw[[:space:]]+(work-on|task[[:space:]]+create|context[[:space:]]+focus|inception)([[:space:]]|$) ]] || return 0
    type has_bash_write_pattern &>/dev/null || return 0
    has_bash_write_pattern "$cmd" || return 0

    echo "" >&2
    echo "  ⚠ Your command already contains that bootstrap command — it was blocked" >&2
    echo "    anyway because the line also has a redirect, 'rm', 'tee', a heredoc or" >&2
    echo "    an in-place sed. The bootstrap exemption is refused for the whole line" >&2
    echo "    when any of those is present, even when it belongs to a different" >&2
    echo "    command on the line (or is just capturing output)." >&2
    echo "" >&2
    echo "    Run the bootstrap command BARE and alone first, then re-run the rest:" >&2
    echo "      $(_fw_cmd) work-on T-XXX          <- nothing else on the line" >&2
    echo "" >&2
    echo "    (Chaining itself is fine — 'fw work-on T-X && fw doctor' is allowed." >&2
    echo "     It is the write pattern that voids the exemption, not the ';' or '&&'.)" >&2
    echo "" >&2
    echo "    This is a message, not a permission: the redirected form stays blocked" >&2
    echo "    by design (T-2987, L-547)." >&2
}

# Bash blocks show an empty "Attempting to modify:" — FILE_PATH is populated only
# for Write/Edit. That blank was load-bearing in the T-2987 loop: the message never
# showed WHICH command was blocked, which is the one datum that makes a stray
# redirect visible. Show the command for Bash, the path otherwise.
_blocked_subject() {
    if [ -n "${BASH_CMD:-}" ]; then
        printf 'Blocked command: %s' "$(printf '%s' "$BASH_CMD" | tr '\n' ' ' | head -c 160)"
        printf '\n%s' "$(_bash_gate_reason)"
    else
        printf 'Attempting to modify: %s' "${FILE_PATH:-}"
    fi
}

# T-3096 / G-084: say which of the gate's TWO questions actually refused.
#
# The Bash arm asks (1) does this match a write pattern, and (2) is its base command on
# the read-only allowlist. Every block message downstream is phrased for question 1 —
# "Cannot modify files under a completed task", "before editing source files" — but most
# real blocks come from question 2. Measured in one session: `sed -n RANGE file`,
# `timeout 30 termlink agent inbox | head` and `./x.sh status | tail` were each told they
# had attempted a modification. None writes.
#
# That is not a cosmetic problem. A gate that names a cause the agent knows to be false
# teaches the agent that the gate's stated contract is unreliable, and the documented
# consequence is that the agent routes around it rather than through the sanctioned
# remedy (L-399 / T-1890 — a bypass contract that fails on one leg produced three weeks
# of silent circumvention). Naming the real reason costs two lines and keeps the gate
# credible on the occasions it is right.
#
# Emitted from _blocked_subject so all eight block sites inherit it with no new call
# site to forget — the same "consume at exactly one checkpoint" argument the SAFE_ALLOWED
# comment at :231 makes, for the same reason.
_bash_gate_reason() {
    [ -z "${BASH_CMD:-}" ] && return 0
    type has_bash_write_pattern &>/dev/null || return 0

    if has_bash_write_pattern "$BASH_CMD"; then
        printf 'Why: it matches a file-write pattern (a redirect, rm, tee, sed -i, or a heredoc).'
        return 0
    fi

    # No write pattern: the refusal came from recognition, not modification. Name the
    # segment that was not recognised — with a chained command that is the one datum
    # that turns "why is my read blocked?" into a one-second answer.
    local _seg _bad=""
    if type _fw_chain_split &>/dev/null && type _fw_single_command_is_safe &>/dev/null; then
        while IFS= read -r _seg; do
            [[ "$_seg" =~ ^[[:space:]]*$ ]] && continue
            if ! _fw_single_command_is_safe "$_seg"; then
                _bad=$(printf '%s' "$_seg" | sed 's/^[[:space:]]*//' | head -c 60)
                break
            fi
        done < <(_fw_chain_split "$BASH_CMD")
    fi

    if [ -n "$_bad" ]; then
        printf 'Why: this command writes nothing the gate can detect. It was gated because\n'
        printf '     "%s" is not on the read-only allowlist\n' "$_bad"
        printf '     (agents/context/lib/safe-commands.sh), so the gate cannot prove it is a read.\n'
        printf '     If it genuinely only reads, that is a gap in the allowlist worth filing.'
    else
        printf 'Why: this command writes nothing the gate can detect, but it is not recognised\n'
        printf '     as read-only (agents/context/lib/safe-commands.sh).'
    fi
}

# Extract file path from tool input (supports file_path and notebook_path for NotebookEdit)
FILE_PATH=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    ti = data.get('tool_input', {})
    print(ti.get('file_path', '') or ti.get('notebook_path', ''))
except:
    print('')
" 2>/dev/null)

# B-005 (T-229): Protect hook enforcement config from agent modification.
# .claude/settings.json controls which hooks run — modifying it can disable all enforcement.
# Block this specifically BEFORE the general exempt-path check.
case "$FILE_PATH" in
    */settings.json)
        # Only block if it's the Claude Code settings file
        if echo "$FILE_PATH" | grep -q '\.claude/settings\.json$'; then
            # T-3050: name the sanctioned route. This refusal used to end at
            # "requires human review" and offer no mechanism, so every agent that
            # tripped it escalated to the operator for a JSON paste-in — for a
            # capability that has shipped since T-1189. A gate with no exit is a
            # gate people route around.
            # Not `local` — this case block is at script top level, not in a
            # function. Consumer projects have no bin/ at their root (T-1257),
            # and the framework repo ALSO vendors itself at .agentic-framework/,
            # so test for the framework repo FIRST or it advertises the consumer
            # path to itself. FRAMEWORK.md + bin/fw at root is the discriminator.
            if [ -f "$PROJECT_ROOT/FRAMEWORK.md" ] && [ -x "$PROJECT_ROOT/bin/fw" ]; then
                _fw="bin/fw"
            elif [ -x "$PROJECT_ROOT/.agentic-framework/bin/fw" ]; then
                _fw=".agentic-framework/bin/fw"
            else
                _fw="fw"
            fi
            echo "" >&2
            echo "BLOCKED: Cannot hand-edit .claude/settings.json — it registers the enforcement hooks." >&2
            echo "" >&2
            echo "Editing it directly could disable task gates, Tier 0 checks, and budget enforcement," >&2
            echo "and a hand-written entry is easy to get subtly wrong (bad event name, absolute path" >&2
            echo "that breaks on the next machine, a duplicate that runs the hook twice)." >&2
            echo "" >&2
            echo "To ADD a hook, use the governed path — it is idempotent, validates the event name," >&2
            echo "writes atomically, and survives regeneration by fw upgrade:" >&2
            echo "" >&2
            echo "  cd $PROJECT_ROOT && $_fw hook-enable --name <hook> --event PreToolUse --matcher 'Write|Edit'" >&2
            echo "  cd $PROJECT_ROOT && $_fw hook-enable --script /abs/path/to/hook.sh --event PreToolUse --matcher 'Bash'" >&2
            echo "" >&2
            echo "  --name   for framework hooks under agents/context/;  --script for project-local ones." >&2
            echo "  Add --dry-run first to print the resulting JSON without writing." >&2
            echo "" >&2
            echo "To REMOVE or REWIRE an existing hook, stop and ask the operator. That is a" >&2
            echo "sovereignty decision, not a configuration change." >&2
            echo "" >&2
            echo "Scope note: B-005 covers Write/Edit on this path only. It does not read the file's" >&2
            echo "content, so it cannot tell an addition from a deletion — which is why additions are" >&2
            echo "routed through the CLI above rather than permitted here." >&2
            echo "" >&2
            echo "Policy: B-005 (Enforcement Config Protection)" >&2
            exit 2
        fi
        ;;
esac

# Exempt paths — framework operations that are part of task management itself
# Anchored to PROJECT_ROOT to prevent matching arbitrary paths (e.g., /root/.claude/)
case "$FILE_PATH" in
    "$PROJECT_ROOT"/.context/*|"$PROJECT_ROOT"/.tasks/*|"$PROJECT_ROOT"/.claude/*|"$PROJECT_ROOT"/.git/*)
        exit 0
        ;;
esac

# T-1431 / T-1274: Claude Code auto-memory writes to
# <home>/.claude/projects/<project>/memory/*.md — outside PROJECT_ROOT.
# Blocking these defeats the mechanism meant to prevent recurrence of
# problems, and does so exactly when it's most needed (mid-onboarding,
# before T-001-T-005 complete). Exempt the auto-memory directory
# globally, regardless of user prefix or task state.
case "$FILE_PATH" in
    */.claude/projects/*/memory/*|*/.gemini/antigravity-cli/brain/*)
        exit 0
        ;;
esac

# If no .context/ directory exists yet (fresh project), allow — bootstrap case
if [ ! -d "$PROJECT_ROOT/.context/working" ]; then
    exit 0
fi

# If no focus file exists: block if project is initialized, allow if bootstrap (T-002)
if [ ! -f "$FOCUS_FILE" ]; then
    if [ -f "$PROJECT_ROOT/.framework.yaml" ]; then
        # Project is initialized but governance not active — block
        echo "BLOCKED: Project initialized but session not active. Run '$(_emit_user_command "context init")' first." >&2
        exit 2
    fi
    # True bootstrap — no .framework.yaml yet, allow
    echo "Note: Context not initialized. Run '$(_emit_user_command "context init")' for task tracking." >&2
    exit 0
fi

# Read current task AND session stamp from focus.yaml.
# T-1858: emit one value per line and read with two separate reads.
# Earlier `print(f'{task} {session}')` + `read -r CURRENT_TASK FOCUS_SESSION`
# collapsed empty task + non-empty session into CURRENT_TASK under default IFS,
# producing misleading "Task <SESSION-ID> is not active" errors.
{ read -r CURRENT_TASK; read -r FOCUS_SESSION; } < <(python3 -c "
import yaml, sys
try:
    with open('$FOCUS_FILE') as f:
        data = yaml.safe_load(f)
    if not data:
        print('')
        print('')
    else:
        task = data.get('current_task', '') or ''
        if task == 'null': task = ''
        session = data.get('focus_session', '') or ''
        print(task)
        print(session)
except:
    print('')
    print('')
" 2>/dev/null)

# Read current session ID for comparison
CURRENT_SESSION=""
SESSION_FILE="$PROJECT_ROOT/.context/working/session.yaml"
if [ -f "$SESSION_FILE" ]; then
    CURRENT_SESSION=$({ grep "^session_id:" "$SESSION_FILE" 2>/dev/null || true; } | head -1 | awk '{print $2}')
fi

# T-2054: post-completion commit deadlock. `--status work-completed` nulls
# focus.yaml current_task AND moves the task active/→completed/, so it can no
# longer be re-focused (G-013 requires the focused task in active/), yet its own
# completion file-move + episodic must still be committed (P-009 commit cadence).
# When focus is null, allow `git commit` so that checkpoint can land. Committing
# persists work already produced under the Write/Edit task gate — it is not new
# work — and the commit-msg hook still enforces P-002 (refuses a message lacking
# T-XXX). `--no-verify`/`-n` is excluded: it would skip that hook, so it falls
# through to the block below (a Tier-2 emergency needing explicit authorisation).
# This lives here, NOT in is_bash_safe_command, on purpose: when focus is NON-null
# git commit must still reach the focus-drift gate (T-1730) — a context-free
# allowlist entry would short-circuit that. `git add` (task-agnostic, no drift)
# stays in is_bash_safe_command.
if [ -z "$CURRENT_TASK" ] && [ "$TOOL_NAME" = "Bash" ] && [ -n "$BASH_CMD" ]; then
    if [[ "$BASH_CMD" =~ (^|[[:space:]])git[[:space:]]+commit($|[[:space:]]) ]] && \
       ! [[ "$BASH_CMD" =~ (^|[[:space:]])(--no-verify|-n)([[:space:]]|$) ]]; then
        echo "NOTE: no active task — allowing 'git commit' to checkpoint completed work (T-2054). commit-msg hook still enforces T-XXX." >&2
        exit 0
    fi
    # T-2880: the SINGLE consumption point for the fast path's safety verdict.
    # Reached only by a command that is safe-listed AND names a task — safety was
    # established above, attribution could not be (focus is null, so there is
    # nothing to be attributed to). This is what keeps T-2878 intact: after
    # `--status work-completed` nulls focus, `fw context add-learning --task T-X`
    # is exactly what the framework prescribes, and it must not deadlock.
    if [ "$SAFE_ALLOWED" = "1" ]; then
        echo "NOTE: no active task — allowing safe-listed '$(printf '%s' "$BASH_CMD" | head -c 60)' (T-2878). Drift not checked: focus is null." >&2
        exit 0
    fi
fi

if [ -z "$CURRENT_TASK" ]; then
    echo "" >&2
    echo "BLOCKED: No active task. Framework rule: nothing gets done without a task." >&2
    echo "" >&2
    echo "To unblock:" >&2
    echo "  1. Create a task:  $(_fw_cmd) task create --name '...' --type build --start" >&2
    echo "  2. Set focus:      $(_fw_cmd) context focus T-XXX" >&2
    _bootstrap_shape_hint "${BASH_CMD:-}"
    echo "" >&2
    echo "$(_blocked_subject)" >&2
    echo "Policy: P-002 (Structural Enforcement Over Agent Discipline)" >&2
    exit 2
fi

# --- Session stamp validation (T-560) ---
# If focus was set in a PREVIOUS session, block and advise.
# This prevents stale focus from granting a free pass to new sessions.
if [ -n "$CURRENT_SESSION" ] && [ -n "$FOCUS_SESSION" ] && [ "$FOCUS_SESSION" != "$CURRENT_SESSION" ]; then
    # Look up task name for advisory
    STALE_TASK_NAME=""
    STALE_FILE=$(find_task_file "$CURRENT_TASK" active 2>/dev/null)
    if [ -n "$STALE_FILE" ]; then
        STALE_TASK_NAME=$({ grep "^name:" "$STALE_FILE" 2>/dev/null || true; } | head -1 | sed 's/name:[[:space:]]*//' | tr -d '"')
    fi

    echo "" >&2
    echo "══════════════════════════════════════════════════════════" >&2
    echo "  STALE FOCUS — Task From Previous Session" >&2
    echo "══════════════════════════════════════════════════════════" >&2
    echo "" >&2
    echo "  Previous task: $CURRENT_TASK" >&2
    [ -n "$STALE_TASK_NAME" ] && echo "  Name:          $STALE_TASK_NAME" >&2
    echo "  Set in session: $FOCUS_SESSION" >&2
    echo "  Current session: $CURRENT_SESSION" >&2
    echo "" >&2
    echo "  Focus was set in a previous session. To continue this task:" >&2
    echo "    $(_fw_cmd) work-on $CURRENT_TASK" >&2
    echo "" >&2
    echo "  To start different work:" >&2
    echo "    $(_fw_cmd) work-on 'New task name' --type build" >&2
    _bootstrap_shape_hint "${BASH_CMD:-}"
    echo "" >&2
    echo "  $(_blocked_subject)" >&2
    echo "  Policy: T-560 (Session-Stamped Focus Enforcement)" >&2
    echo "══════════════════════════════════════════════════════════" >&2
    echo "" >&2
    exit 2
fi

# --- Agent-control detection (T-1739) -------------------------------------
# Multi-signal helper: returns true if any indicator suggests we're under
# agent (Claude Code, etc.) control. Witnessed T-1738 commit: CLAUDECODE was
# unset in the actual PreToolUse env even though the parent shell had it.
# Single-signal CLAUDECODE check would silently degrade the drift gate.
#
# Signals (in preference order — most reliable first):
#   1. CLAUDECODE=1            — Claude Code's documented contract
#   2. AI_AGENT non-empty      — broader agent-runtime convention
# We deliberately do NOT use stdin-shape (TOOL_NAME extracted) as a signal
# because tests/dev environments legitimately pipe JSON to the script and
# would degrade to blocking. If both env vars get stripped by the host
# runtime, the advisory log entry surfaces it via .gate-bypass-log.yaml.
_under_agent_control() {
    [ "${CLAUDECODE:-}" = "1" ] && return 0
    [ -n "${AI_AGENT:-}" ] && return 0
    return 1
}

# --- Focus-target drift detection (T-1730, closes G3 from T-1729 meta-RCA) ---
# When a Bash command targets a specific task that differs from the focused task,
# block under agent control with --switch-focus override (logged).
# Only inspects fw task update / fw context add-* --task / git commit -m "T-X: ...".
# Does NOT gate fw work-on / fw context focus / fw inception decide / fw task review|show
# (those are intentional state transitions or read-only).
if [ "$TOOL_NAME" = "Bash" ] && [ -n "$BASH_CMD" ] && [ -n "$CURRENT_TASK" ]; then
    # T-2880: consume the hoisted result rather than re-deriving it. The three
    # patterns and their residual-limit notes now live in one place
    # (_fw_extract_drift_target, top of file) so the fast-path test and the gate
    # cannot disagree about what counts as naming a task.
    TARGET_TASK="$DRIFT_TARGET"

    # If a target was identified and differs from focused task: drift
    if [ -n "$TARGET_TASK" ] && [ "$TARGET_TASK" != "$CURRENT_TASK" ]; then
        # T-1890: two bypass mechanisms.
        # (a) --switch-focus flag in BASH_CMD — works for fw commands whose
        #     downstream parsers accept the no-op token (update-task.sh,
        #     agents/context/lib/{learning,pattern,decision}.sh).
        # (b) FW_SWITCH_FOCUS=1 env-var prefix — works universally including
        #     `git commit ... T-X: ...` (git rejects unknown flags so the
        #     flag mechanism fundamentally can't cover that pattern).
        _bypass_mechanism=""
        if [[ "$BASH_CMD" =~ (^|[[:space:]])--switch-focus([[:space:]]|=|$) ]]; then
            _bypass_mechanism="--switch-focus"
        elif [[ "$BASH_CMD" =~ (^|[[:space:]])FW_SWITCH_FOCUS=1([[:space:]]|$) ]]; then
            _bypass_mechanism="FW_SWITCH_FOCUS=1"
        fi
        if [ -n "$_bypass_mechanism" ]; then
            BYPASS_LOG="$PROJECT_ROOT/.context/working/.gate-bypass-log.yaml"
            mkdir -p "$(dirname "$BYPASS_LOG")"
            # T-1861: escape embedded single quotes per YAML single-quoted-scalar rule.
            _t1861_esc_task="${CURRENT_TASK//\'/\'\'}"
            _t1861_esc_target="${TARGET_TASK//\'/\'\'}"
            {
                echo "- timestamp: '$(date -u +%Y-%m-%dT%H:%M:%SZ)'"
                echo "  task: '$_t1861_esc_task'"
                echo "  flag: '$_bypass_mechanism'"
                echo "  caller: 'check-active-task focus-drift'"
                echo "  target: '$_t1861_esc_target'"
                echo "  command: '$(echo "$BASH_CMD" | head -c 200 | tr -d "'")'"
            } >> "$BYPASS_LOG" 2>/dev/null || true
            echo "NOTE: focus-drift override ($_bypass_mechanism) — target $TARGET_TASK ≠ focus $CURRENT_TASK. Logged." >&2
        elif _under_agent_control; then
            echo "" >&2
            echo "══════════════════════════════════════════════════════════" >&2
            echo "  FOCUS-DRIFT — Action targets a different task" >&2
            echo "══════════════════════════════════════════════════════════" >&2
            echo "" >&2
            echo "  Current focus: $CURRENT_TASK" >&2
            echo "  Action target: $TARGET_TASK" >&2
            echo "" >&2
            echo "  Framework rule: actions on a task should run with focus on" >&2
            echo "  that task. To proceed, either:" >&2
            echo "" >&2
            # T-2875: only offer "switch focus" when focus CAN actually point there.
            #
            # T-2874 made `fw context focus` refuse a completed task id, so for a
            # completed target this remedy is a command the framework itself refuses —
            # the agent follows the instruction, gets a second refusal, and has to find
            # options 2/3 unaided. The completed target is the COMMON case here: the
            # usual trigger is a follow-up commit attributed to a task that just closed.
            #
            # Not a T-2874 regression. Before T-2874 this remedy appeared to work (exit
            # 0) and then deadlocked every later gated call on "Task X is not active";
            # T-2874 changed it from silently broken to loudly broken. Both wrong, only
            # the second visible.
            #
            # NO REOPEN COMMAND IS OFFERED, deliberately. `fw task update <id> --status
            # started-work` does not move a file from completed/ back to active/ — no
            # such move exists in update-task.sh — so focus would refuse it again. That
            # would be a second dead remedy replacing the first, which is the whole
            # defect. Only mechanisms verified to work are named (L-399 / T-1890).
            #
            # The completed branch prints "2." and "3." with no "1." — deliberate, do not
            # renumber. The digits identify MECHANISMS, not positions: option 3 is
            # FW_SWITCH_FOCUS=1 in both branches, in the bypass log, and in every prior
            # session transcript. Renumbering to 1./2. here would make "option 2" mean
            # --switch-focus in one branch and FW_SWITCH_FOCUS=1 in the other.
            if [ -n "$(find_task_file "$TARGET_TASK" active)" ]; then
                echo "    1. Switch focus first:" >&2
                echo "       $(_fw_cmd) context focus $TARGET_TASK" >&2
                echo "" >&2
            else
                echo "    ($TARGET_TASK is not active, so focus cannot point at it —" >&2
                echo "     'context focus' would refuse it. Use 2 or 3 below; the" >&2
                echo "     action stays attributed to $TARGET_TASK either way.)" >&2
                echo "" >&2
            fi
            echo "    2. Append --switch-focus to a fw command (logged Tier 2)." >&2
            echo "       Works for: fw task update, fw context add-*." >&2
            echo "" >&2
            echo "    3. Prefix FW_SWITCH_FOCUS=1 to any command (logged Tier 2)." >&2
            echo "       Works universally including git commit (where git rejects" >&2
            echo "       unknown flags). Use this when option 2 isn't accepted." >&2
            echo "" >&2
            echo "  Attempting to run: $(echo "$BASH_CMD" | head -c 120)" >&2
            echo "  Policy: T-1730 (Focus-Target Drift Gate, closes G3 from T-1729)" >&2
            echo "  Bypass-mechanism contract: T-1890 (flag + env-var dual path)" >&2
            echo "══════════════════════════════════════════════════════════" >&2
            echo "" >&2
            exit 2
        else
            # No agent-control signal — advisory only (test/dev shell)
            echo "NOTE: focus-drift detected: target $TARGET_TASK ≠ focus $CURRENT_TASK. (Not blocking — no agent-control signal: CLAUDECODE/AI_AGENT/TOOL_NAME all empty.)" >&2
        fi
    fi
fi

# Verify task is actually active (not completed/archived) — G-013
ACTIVE_FILE=$(find_task_file "$CURRENT_TASK" active)
if [ -z "$ACTIVE_FILE" ]; then
    echo "" >&2
    echo "BLOCKED: Task $CURRENT_TASK is not active (may be completed or missing)." >&2
    echo "" >&2
    echo "To unblock:" >&2
    echo "  $(_fw_cmd) work-on T-XXX   (resume an active task)" >&2
    echo "  $(_fw_cmd) work-on 'name'  (create a new task)" >&2
    _bootstrap_shape_hint "${BASH_CMD:-}"
    echo "" >&2
    echo "$(_blocked_subject)" >&2
    echo "Policy: P-002 (Structural Enforcement Over Agent Discipline)" >&2
    exit 2
fi

# --- Status validation (T-354) ---
# Task file exists in active/ but may be captured (not started) or work-completed
# (partial-complete). Only started-work and issues are workable statuses.
TASK_STATUS=$({ grep "^status:" "$ACTIVE_FILE" 2>/dev/null || true; } | head -1 | sed 's/status:[[:space:]]*//')
case "$TASK_STATUS" in
    started-work|issues)
        # Workable statuses — allow
        ;;
    captured)
        echo "" >&2
        echo "BLOCKED: Task $CURRENT_TASK has status 'captured' (work not started)." >&2
        echo "" >&2
        echo "To unblock:" >&2
        echo "  $(_fw_cmd) work-on $CURRENT_TASK   (sets status to started-work)" >&2
        _bootstrap_shape_hint "${BASH_CMD:-}"
        echo "" >&2
        echo "$(_blocked_subject)" >&2
        echo "Policy: P-002 (Task must be started before modifying files)" >&2
        exit 2
        ;;
    work-completed)
        echo "" >&2
        echo "BLOCKED: Task $CURRENT_TASK has status 'work-completed'." >&2
        echo "" >&2
        echo "To unblock:" >&2
        echo "  $(_fw_cmd) work-on T-XXX   (resume another task)" >&2
        echo "  $(_fw_cmd) work-on 'name'  (create a new task)" >&2
        _bootstrap_shape_hint "${BASH_CMD:-}"
        echo "" >&2
        echo "$(_blocked_subject)" >&2
        echo "Policy: P-002 (Cannot modify files under a completed task)" >&2
        exit 2
        ;;
    "")
        # Legacy task without status field — warn but allow
        echo "NOTE: Task $CURRENT_TASK has no status field in task file." >&2
        ;;
esac

# --- Onboarding gate (T-535) ---
# If incomplete onboarding tasks exist, only allow work on onboarding tasks.
# Detection: tasks with tags containing "onboarding" in .tasks/active/.
# Fast path: .context/working/.onboarding-complete marker means all done.
#
# T-2815: owner:human onboarding tasks are exempt from the block. An agent
# session can never satisfy fw inception decide (blocked under CLAUDECODE=1,
# T-1259/T-1260) nor tick a ### Human AC — so an owner:human task in this set
# is a structural deadlock, not a checklist item. "readable but never
# blocking": the task still exists, still carries the onboarding tag, still
# shows up in `fw task list --tag onboarding` / `fw onboarding status` — it
# just doesn't gate the agent's other work. The complementary case (an
# onboarding task claiming owner:agent that is still agent-unresolvable) is
# refused at write-time by check-onboarding-gate.py so this exemption cannot
# be used to smuggle a real deadlock past the scan.
ONBOARDING_MARKER="$PROJECT_ROOT/.context/working/.onboarding-complete"
if [ ! -f "$ONBOARDING_MARKER" ]; then
    # Check if any active tasks have onboarding tag and are not completed
    INCOMPLETE_ONBOARDING=""
    for tf in "$PROJECT_ROOT"/.tasks/active/T-*.md; do
        [ -f "$tf" ] || continue
        # T-2881: element-wise, not substring. The prior form was
        # `grep -q '^tags:.*onboarding'`, which matched inside
        # `arc:onboarding-curriculum` — so every task tagged into the
        # onboarding-curriculum ARC counted as a member of the gated onboarding
        # SET, and its mere existence in active/ blocked all other work. Sibling
        # of the same conflation in check-onboarding-gate.py:has_onboarding_tag;
        # both call sites are fixed together per L-399 producer/consumer parity,
        # because a task refused by one and admitted by the other is worse than
        # either behaviour alone.
        #
        # Latent rather than observed HERE only because `.onboarding-complete`
        # short-circuits the whole block on this repo. In a project without that
        # marker it fires, and the block message names onboarding tasks the
        # operator does not have.
        if head -20 "$tf" | grep -qE '^tags:[[:space:]]*\[?([^]]*,)?[[:space:]]*onboarding[[:space:]]*(,|\]|$)' 2>/dev/null; then
            tf_owner=$({ grep "^owner:" "$tf" 2>/dev/null || true; } | head -1 | sed 's/owner:[[:space:]]*//')
            [ "$tf_owner" = "human" ] && continue
            tf_status=$({ grep "^status:" "$tf" 2>/dev/null || true; } | head -1 | sed 's/status:[[:space:]]*//')
            if [ "$tf_status" != "work-completed" ]; then
                tf_id=$({ grep "^id:" "$tf" 2>/dev/null || true; } | head -1 | sed 's/id:[[:space:]]*//')
                tf_name=$({ grep "^name:" "$tf" 2>/dev/null || true; } | head -1 | sed 's/name:[[:space:]]*//' | tr -d '"')
                INCOMPLETE_ONBOARDING="${INCOMPLETE_ONBOARDING}  ${tf_id}: ${tf_name} (${tf_status})\n"
            fi
        fi
    done

    if [ -n "$INCOMPLETE_ONBOARDING" ]; then
        # Check if current task is an onboarding task
        CURRENT_IS_ONBOARDING=false
        if [ -n "$ACTIVE_FILE" ] && head -20 "$ACTIVE_FILE" | grep -q '^tags:.*onboarding' 2>/dev/null; then
            CURRENT_IS_ONBOARDING=true
        fi

        if [ "$CURRENT_IS_ONBOARDING" = false ]; then
            echo "" >&2
            echo "BLOCKED: Onboarding tasks incomplete. Complete setup before starting other work." >&2
            echo "" >&2
            echo "Remaining onboarding tasks:" >&2
            echo -e "$INCOMPLETE_ONBOARDING" >&2
            echo "To work on onboarding:" >&2
            echo "  $(_fw_cmd) work-on T-001" >&2
            echo "" >&2
            echo "To skip onboarding (not recommended):" >&2
            echo "  $(_fw_cmd) onboarding skip" >&2
            _bootstrap_shape_hint "${BASH_CMD:-}"
            echo "" >&2
            echo "$(_blocked_subject)" >&2
            echo "Policy: T-532 (Onboarding Enforcement Gate)" >&2
            exit 2
        fi
    else
        # All onboarding tasks done (or none exist) — write marker for fast path
        mkdir -p "$(dirname "$ONBOARDING_MARKER")"
        echo "completed: $(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$ONBOARDING_MARKER"
    fi
fi

# --- Inception awareness ---
# If the active task is inception type with no decision, warn (don't block)
# ACTIVE_FILE already resolved above
if [ -n "$ACTIVE_FILE" ] && grep -q "^workflow_type: inception" "$ACTIVE_FILE" 2>/dev/null; then
    if ! grep -q '^\*\*Decision\*\*: \(GO\|NO-GO\|DEFER\)' "$ACTIVE_FILE" 2>/dev/null; then
        echo "NOTE: Active task $CURRENT_TASK is inception (no decision yet)." >&2
        echo "  Ensure you are doing exploration, not building." >&2
    fi
fi

# --- Inception Open Questions readiness gate (T-2194, G-067) ---
# Filing-time mirror of G-020 for inceptions: if the active inception has a
# ## Open Questions section but ZERO filed `- **IW-N:**` entries, source-file
# Write/Edit is blocked. The task file itself is `.tasks/*` exempt above, so
# the agent can still add questions to unblock. Grandfather: inceptions with
# no Open Questions section at all pass through (older inceptions pre-T-2190).
# Bypass: FW_ALLOW_INCEPTION_OPEN_QUESTIONS_DRIFT=1 (logged Tier-2).
if [ -n "$ACTIVE_FILE" ] && grep -q "^workflow_type: inception" "$ACTIVE_FILE" 2>/dev/null; then
    # Only check if the section exists at all (grandfather older inceptions)
    if grep -q "^## Open Questions" "$ACTIVE_FILE" 2>/dev/null; then
        # Extract Open Questions section content (between header and next ## heading)
        OQ_SECTION=$(awk '/^## Open Questions/{f=1; next} /^## /{f=0} f' "$ACTIVE_FILE" 2>/dev/null)
        # Strip HTML comments so the template guidance does not count.
        # T-2554: minimal match to first '-->' — tolerates '>' inside the comment.
        OQ_STRIPPED=$(echo "$OQ_SECTION" | sed -E 's/<!--([^-]|-[^-]|--[^>])*-->//g' | sed '/<!--/,/-->/d')
        # Count real IW-N entries
        HAS_IW=$(echo "$OQ_STRIPPED" | grep -cE '^\s*-\s*\*\*IW-[0-9]+:' 2>/dev/null || true)
        if [ "${HAS_IW:-0}" -eq 0 ]; then
            if [ "${FW_ALLOW_INCEPTION_OPEN_QUESTIONS_DRIFT:-0}" = "1" ]; then
                # Bypass — log Tier-2
                LOG_DIR="$PROJECT_ROOT/.context/working"
                mkdir -p "$LOG_DIR" 2>/dev/null || true
                LOG_FILE="$LOG_DIR/.gate-bypass-log.yaml"
                _ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
                {
                    echo "- timestamp: '$_ts'"
                    echo "  task: '$CURRENT_TASK'"
                    echo "  flag: 'FW_ALLOW_INCEPTION_OPEN_QUESTIONS_DRIFT'"
                    echo "  caller: 'check-active-task:inception-open-questions'"
                    echo "  file: '$FILE_PATH'"
                } >> "$LOG_FILE" 2>/dev/null || true
                echo "NOTE: Inception $CURRENT_TASK has no filed Open Questions; write allowed via FW_ALLOW_INCEPTION_OPEN_QUESTIONS_DRIFT=1 — logged." >&2
            else
                echo "" >&2
                echo "BLOCKED: Inception $CURRENT_TASK has '## Open Questions' but zero filed questions." >&2
                echo "" >&2
                echo "Filing-time mirror of G-020 — inception build-readiness." >&2
                echo "Inception work cannot edit source files until at least one Open Question is declared." >&2
                echo "" >&2
                echo "To unblock:" >&2
                echo "  1. Edit $CURRENT_TASK and add at least one entry under '## Open Questions':" >&2
                echo "       - **IW-1: <question text>**" >&2
                echo "         confidence: 0-3" >&2
                echo "         disposition: answered|deferred|dissolved   # filled later" >&2
                echo "         rationale: <one-line evidence>              # filled later" >&2
                echo "" >&2
                echo "  2. Or remove the '## Open Questions' section entirely (grandfathered)." >&2
                echo "" >&2
                echo "  3. Override (logged Tier 2):  FW_ALLOW_INCEPTION_OPEN_QUESTIONS_DRIFT=1 <command>" >&2
                echo "" >&2
                echo "$(_blocked_subject)" >&2
                echo "Policy: T-2194 / G-067 (Inception Open Questions readiness gate)" >&2
                echo "See: 050-Inceptions.md §Disposition Gate, CLAUDE.md §Inception Discipline" >&2
                exit 2
            fi
        fi
    fi
fi

# --- Build readiness gate (G-020, T-471) ---
# Build/refactor/test tasks must have real ACs before modifying source files.
# Placeholder ACs ([First criterion]) indicate the task was created from template
# but never scoped. This prevents building without acceptance criteria.
# Inception tasks have their own gate above; skip them here.
if [ -n "$ACTIVE_FILE" ]; then
    WORKFLOW_TYPE=$({ grep "^workflow_type:" "$ACTIVE_FILE" 2>/dev/null || true; } | head -1 | sed 's/workflow_type:[[:space:]]*//')
    case "$WORKFLOW_TYPE" in
        build|refactor|test|decommission)
            AC_SECTION=$(sed -n '/^## Acceptance Criteria/,/^## [^A]/p' "$ACTIVE_FILE" 2>/dev/null | sed '$d')
            # T-2944: strip HTML comments before counting, exactly as the G-067
            # inception gate does at :700 in this same file. Without this, the two
            # illustrative `- [ ] [REVIEW]` / `- [ ] [REVIEWER]` examples inside the
            # shipped template's Human-guidance comment block count as real ACs — so
            # deleting the two placeholders, which is *literally what this gate's own
            # block message instructs*, clears both conditions below and leaves a
            # build task with ZERO acceptance criteria able to write source.
            # Measured against this hook before the fix: placeholders present → exit 2
            # (positive control), placeholders deleted → exit 0, write allowed.
            #
            # The strip is correct HERE and would be a defect in P-011's extractor
            # (T-2921, and 832's T-456 independently): this text is prose being
            # COUNTED, not commands being handed to eval. Same regex, opposite
            # correctness — the question is whether the span is discarded or executed.
            #
            # Reported by 832 as their T-453 (rail 564 §4), confirmed here by T-2943.
            # The count reproduced exactly; the severity did not. Their report said the
            # gate passes over zero ACs — the sharper statement is that the gate
            # instructs you into that state.
            AC_SECTION=$(echo "$AC_SECTION" | sed -E 's/<!--([^-]|-[^-]|--[^>])*-->//g' | sed '/<!--/,/-->/d')
            HAS_PLACEHOLDER=$(echo "$AC_SECTION" | grep -ciE '\[(First|Second|Third|Fourth|Fifth) criterion\]' 2>/dev/null || true)
            REAL_AC_COUNT=$(echo "$AC_SECTION" | grep -cE '^\s*-\s*\[[ x]\]' 2>/dev/null || true)
            if [ "${HAS_PLACEHOLDER:-0}" -gt 0 ] || [ "${REAL_AC_COUNT:-0}" -eq 0 ]; then
                echo "" >&2
                echo "BLOCKED: Task $CURRENT_TASK is a $WORKFLOW_TYPE task with placeholder/missing ACs." >&2
                echo "" >&2
                echo "Build tasks require real acceptance criteria before editing source files." >&2
                echo "This prevents unscoped building. (G-020: Scope-Aware Task Gate)" >&2
                echo "" >&2
                echo "To unblock:" >&2
                echo "  1. Edit the task file: replace [First criterion] with real ACs" >&2
                echo "  2. Or change to inception:" >&2
                echo "     $(_fw_cmd) task update $CURRENT_TASK --type inception" >&2
                _bootstrap_shape_hint "${BASH_CMD:-}"
                echo "" >&2
                echo "$(_blocked_subject)" >&2
                echo "Policy: G-020 (Pickup message governance bypass prevention)" >&2
                exit 2
            fi
            ;;
    esac
fi

# --- Fabric awareness advisory (T-244) ---
# If the file is a registered fabric component with dependents, show a note.
# Advisory only — never blocks. Runs only for non-exempt paths.
if [ -n "$FILE_PATH" ] && [ -d "$FRAMEWORK_ROOT/.fabric/components" ]; then
    # Resolve relative path
    REL_PATH=$(realpath --relative-to="$PROJECT_ROOT" "$FILE_PATH" 2>/dev/null || echo "$FILE_PATH")
    # Quick count: how many other cards reference this file?
    DEP_COUNT=$(python3 -c "
import os, glob, re
root = '$PROJECT_ROOT'
rel = '$REL_PATH'
cards_dir = os.path.join(root, '.fabric', 'components')
# Find this file's card to get its id/name
comp_id = comp_name = ''
for card in glob.glob(os.path.join(cards_dir, '*.yaml')):
    with open(card) as f:
        text = f.read()
    if f'location: {rel}' in text or f'id: {rel}' in text:
        for line in text.split('\n'):
            if line.startswith('id: '): comp_id = line[4:].strip()
            if line.startswith('name: '): comp_name = line[6:].strip()
        break
if not comp_id:
    print(0)
else:
    # Count cards that reference this component
    count = 0
    patterns = [comp_id, comp_name, rel]
    for card in glob.glob(os.path.join(cards_dir, '*.yaml')):
        with open(card) as f:
            text = f.read()
        if f'id: {comp_id}' in text:
            continue  # skip self
        if any(f'target: {p}' in text or f'target: \"{p}\"' in text for p in patterns if p):
            count += 1
    print(count)
" 2>/dev/null || echo 0)
    if [ "$DEP_COUNT" -gt 0 ]; then
        echo "FABRIC: $REL_PATH has $DEP_COUNT downstream dependent(s). Consider: $(_fw_cmd) fabric blast-radius after commit." >&2
    fi
fi

# Active task exists — allow
exit 0
