#!/bin/bash
# Safe-command allowlist for Bash task gate (T-650, T-630)
#
# is_bash_safe_command() returns 0 if the command is read-only/diagnostic
# and should be allowed without an active task.
#
# Design evidence: 7920 Bash invocations analyzed from real session data.
# Only 1.4% are file-writing operations. This allowlist catches the safe
# 98.6% for fast-path bypass.
#
# Categories (27 patterns):
#   1. Git read-only (8 patterns)
#   2. File reading (7 patterns)
#   3. Searching (4 patterns)
#   4. FW diagnostics (6 patterns)
#   5. System utilities (6 patterns)
#   6. Validation (2 patterns)

# --- T-2834: chain-aware entry point -------------------------------------
#
# _fw_chain_split emits one segment per line, splitting on chain operators that
# are NOT inside quotes: `&&`, `||`, `&`, `|`, `;`, and newline. Quote tracking
# matters — without it `grep -q "a && b"` splits into two bogus segments and a
# read-only command starts blocking.
#
# Deliberately NOT handled: command substitution. `echo $(git commit -m 'T-X: y')`
# still reads as safe. Extracting `$(...)` as a segment would also catch the
# framework's own documented idiom `curl -sf "$(bin/fw watchtower url)/page"` —
# `fw watchtower` is not on the allowlist, so that verification pattern would
# start blocking whenever no task is active, which is exactly the recovery state
# where friction hurts most. Chain operators are the measured, high-frequency
# hole; substitution is narrower and is filed rather than papered over (OBS-185).
_fw_chain_split() {
    local cmd="$1" seg="" q="" ch nxt i n=${#1}
    for (( i=0; i<n; i++ )); do
        ch="${cmd:i:1}"
        if [ -n "$q" ]; then
            seg+="$ch"
            [ "$ch" = "$q" ] && q=""
            continue
        fi
        case "$ch" in
            "'"|'"') q="$ch"; seg+="$ch" ;;
            '\')     seg+="$ch"; i=$((i+1)); [ "$i" -lt "$n" ] && seg+="${cmd:i:1}" ;;
            '&'|'|')
                # T-2879: an `&` that is part of a file-descriptor duplication is NOT a
                # chain separator. `bin/fw note "x" 2>&1` was splitting into
                # `bin/fw note "x" 2>` and `1`; the bare `1` matches nothing in the
                # allowlist, so the compound failed. That neutralised the ENTIRE safe-list
                # for the commonest redirect idiom there is — `fw doctor 2>&1`,
                # `git status 2>&1`, `ls -la 2>&1` all gated — precisely in the no-task and
                # drift states where the safe-list is the only thing preventing a deadlock.
                #
                # Narrow on purpose: require the `&` to sit between a redirect operator and
                # an fd target (digit or `-`), which is the only form that duplicates rather
                # than writes. `cmd >& file` is a genuine write to `file` and MUST keep
                # splitting (and gating) — the next-char test is what preserves that, so do
                # not relax it to "preceded by > or <" alone.
                nxt="${cmd:i+1:1}"
                if [ "$ch" = '&' ] && [[ "${seg: -1}" == [\<\>] ]] && [[ "$nxt" == [0-9-] ]]; then
                    seg+="$ch"
                    continue
                fi
                [ "$nxt" = "$ch" ] && i=$((i+1))
                printf '%s\n' "$seg"; seg="" ;;
            ';'|$'\n') printf '%s\n' "$seg"; seg="" ;;
            *)       seg+="$ch" ;;
        esac
    done
    printf '%s\n' "$seg"
}

# A compound command is safe only if EVERY segment is safe.
#
# The predecessor asserted the opposite in a comment — "for compound commands,
# the first word is still the primary command" — and judged `echo hi && git
# commit -m 'T-X: y'` by `echo` alone, exiting the caller (check-active-task.sh
# :95) before the no-active-task check, the task-is-active check, the G-020
# readiness gate and the T-1730 focus-drift gate ever ran. Everything after `&&`
# was unexamined. OBS-184 has the measured matrix.
#
# Failure direction is asymmetric and this errs the safe way: misjudging a safe
# chain as unsafe merely sends it to the task gate, which allows it whenever a
# task is active; misjudging an unsafe chain as safe skips every gate there is.
is_bash_safe_command() {
    local _cmd="$1" _seg _n=0
    local -a _segs=() _kept=()
    mapfile -t _segs < <(_fw_chain_split "$_cmd")
    for _seg in "${_segs[@]}"; do
        [[ "$_seg" =~ ^[[:space:]]*$ ]] && continue
        _kept+=("$_seg"); _n=$((_n+1))
    done
    if [ "$_n" -gt 1 ]; then
        for _seg in "${_kept[@]}"; do
            _fw_single_command_is_safe "$_seg" || return 1
        done
        return 0
    fi
    _fw_single_command_is_safe "$_cmd"
}

# Single (non-compound) command classification. This is the original
# is_bash_safe_command body, unchanged apart from the name.
_fw_single_command_is_safe() {
    local cmd="$1"

    # T-2834: trim surrounding whitespace. Chain segments arrive with the space
    # that followed the operator (`ls && FW_X=1 fw work-on T-1` → segment 2 is
    # " FW_X=1 fw work-on T-1"), and the T-1908 env-prefix regex below is
    # ^-anchored — a leading space defeats it, the base extracts as the env
    # assignment, nothing matches, and the segment reads unsafe. Caught by
    # tests/unit/safe_commands_chain.bats "env-var prefix is stripped per
    # segment", which failed on the first run of this very fix.
    cmd="${cmd#"${cmd%%[![:space:]]*}"}"
    cmd="${cmd%"${cmd##*[![:space:]]}"}"

    # T-1908: strip leading env-var prefixes (`KEY=val [KEY2=val2 ...] cmd args`).
    # Without this, the L-399 / T-1890 bypass-mechanism contract that promises
    # `FW_SWITCH_FOCUS=1 fw work-on T-XXX` works actually fails — the awk
    # extraction below returns `FW_SWITCH_FOCUS=1` as the base, no case
    # matches, the safe-command path is skipped, and the downstream
    # captured-status check blocks the very command the focus-drift block
    # message recommended. Strip one prefix at a time until none remain.
    while [[ "$cmd" =~ ^[A-Za-z_][A-Za-z0-9_]*=[^[:space:]]+[[:space:]]+(.*)$ ]]; do
        cmd="${BASH_REMATCH[1]}"
    done

    # Extract the base command (first word, strip path).
    # Callers must pass a SINGLE command — is_bash_safe_command splits compound
    # commands into segments before reaching here (T-2834). The previous version
    # of this comment claimed the first word was still the primary command for
    # compound commands; it is not, and that assumption was the whole defect.
    local base
    base=$(echo "$cmd" | awk '{print $1}' | sed 's|.*/||')

    case "$base" in
        # Category 1: Git read-only
        git)
            local git_sub
            git_sub=$(echo "$cmd" | awk '{print $2}')
            case "$git_sub" in
                # T-2888 added the second line. The first had grown one verb per
                # incident — T-2052, T-2054, T-2462 and T-2878 each patched this
                # function after an agent hit the null-focus deadlock live — so
                # the sweep was done against a DERIVED set instead of a
                # remembered one: every git sub-verb appearing in this repo's own
                # .sh/.py/.bats, intersected with `git --list-cmds=main` to drop
                # prose, then run through the predicate. Six read-only verbs our
                # own tooling uses came back GATED. Table in the task file.
                #
                # `symbolic-ref` is deliberately NOT here despite being in that
                # residue: `git symbolic-ref HEAD refs/heads/x` writes. Same
                # reason `config` stays out — a verb whose read and write forms
                # differ only by an argument cannot be decided on the verb alone.
                status|log|diff|show|branch|remote|describe|rev-parse|tag|stash|shortlog|blame|ls-files|ls-tree|cat-file|name-rev|reflog)
                    return 0
                    ;;
                rev-list|ls-remote|merge-base|grep|for-each-ref|count-objects|check-ignore|verify-commit|var|whatchanged|cherry|diff-tree|show-ref|help)
                    return 0
                    ;;
                # T-2054: `git add` is task-agnostic — it stages already-produced
                # content (the Write/Edit gate ensured that content was created
                # under a task) and carries no T-XXX reference, so it cannot drift.
                # Safe with no active task. `git commit` is deliberately NOT here:
                # it must reach the focus-drift gate (T-1730) in check-active-task.sh
                # when a focus exists, so its post-completion (null-focus) allow is
                # handled there instead — see the T-2054 block in check-active-task.sh.
                add)
                    return 0
                    ;;
                # T-2462: `git push` / `git fetch` are task-agnostic. Push only
                # PUBLISHES commits that already passed the commit-msg T-XXX gate
                # (P-002) — it creates no work artifact, mutates no working tree,
                # and is not inspected by the focus-drift detector (T-1730 only
                # looks at fw task update / fw context add / git commit -m T-X:).
                # Fetch is pure network read. Gating either on an active task adds
                # zero governance and manufactures a deadlock that fires whenever
                # focus is null: (1) post-completion — `--status work-completed`
                # nulls focus, but "never end a session with unpushed commits"
                # still requires the push (T-2054 exempted commit+add but stopped
                # before push — this closes that 3rd leg of the commit→push
                # pipeline, L-399 producer/consumer parity); (2) worktree sessions
                # where the Bash hook resolves PROJECT_ROOT to the main repo (null
                # focus). This does NOT weaken the pre-push hooks (self-vendor
                # drift, secret scan) — those run inside git, independently of this
                # active-task gate. `pull` is deliberately EXCLUDED: it merges into
                # the working tree (a write), so it stays gated.
                push|fetch)
                    return 0
                    ;;
            esac
            ;;

        # Category 2: File reading
        cat|head|tail|ls|wc|file|stat|realpath|readlink|basename|dirname|test|\[)
            return 0
            ;;

        # Category 3: Searching
        grep|rg|find|which|where|type|command)
            return 0
            ;;

        # Category 4: FW diagnostics
        fw|bin/fw)
            local fw_sub
            fw_sub=$(echo "$cmd" | awk '{print $2}')
            case "$fw_sub" in
                doctor|metrics|audit|version|resume|help|status|fabric|gaps|promote)
                    return 0
                    ;;
                context)
                    local ctx_sub
                    ctx_sub=$(echo "$cmd" | awk '{print $3}')
                    case "$ctx_sub" in
                        # T-2878: the four capture verbs are allowed with no
                        # active task for the same reason `task create` is
                        # (T-2052) — they are what the framework PRESCRIBES
                        # after completing work, and completion is the exact
                        # transition that nulls focus. Verb-scoped, not a
                        # blanket `context)` allowance: a mutating context
                        # sub-verb must still fall through to the task check.
                        status|focus|init|add-learning|add-pattern|add-decision|generate-episodic)
                            return 0
                            ;;
                    esac
                    ;;
                task)
                    local task_sub
                    task_sub=$(echo "$cmd" | awk '{print $3}')
                    case "$task_sub" in
                        # T-2052: `create` is task-bootstrap (writes only to the
                        # exempt .tasks/ dir) — must be allowed with no active task,
                        # else the gate deadlocks its own "create a task" advice.
                        list|verify|review|create)
                            return 0
                            ;;
                    esac
                    ;;
                note)
                    # T-2878: observation capture. Same class as the context
                    # add-* verbs above — the gate must not block the record
                    # of why it fired.
                    return 0
                    ;;
                handover)
                    # T-2878: session handover is the Session End Protocol's
                    # mandatory step; it runs precisely when no task is active.
                    return 0
                    ;;
                work-on|inception)
                    # work-on and inception commands are task bootstrap — always allowed
                    return 0
                    ;;
                upstream)
                    # T-2410 case 2: `fw upstream` has read-only sub-verbs
                    # (status, list, info) — exempt these from the active-task
                    # gate so consumers can inspect upstream pin state under
                    # any focus condition. Mutating sub-verbs (pin, set, sync)
                    # are NOT exempt; they fall through to the task check.
                    local ups_sub
                    ups_sub=$(echo "$cmd" | awk '{print $3}')
                    case "$ups_sub" in
                        status|list|info|show|help|--help|-h|--version|"")
                            return 0
                            ;;
                    esac
                    ;;
                hook)
                    # fw hook * — hooks calling hooks, always allowed
                    return 0
                    ;;
                integrate)
                    # T-2471: `fw integrate {check,classify}` are read-only; `fw
                    # integrate run` is the mutating merge-back verb. All three are
                    # task-agnostic meta-operations on git history: the merge
                    # commits run creates are --no-ff --no-edit (no T-XXX work
                    # artifact — the commit-msg hook already exempts MERGE_HEAD),
                    # and gating them on an active task manufactures a deadlock —
                    # integration runs from a worktree whose Bash-hook PROJECT_ROOT
                    # resolves to the main repo (null focus). This verb-scoped
                    # exemption is the EFFECTIVE focus-gate bypass; it deliberately
                    # does NOT use an FW_INTEGRATION_IN_PROGRESS env honor, which
                    # would reintroduce the T-2446 inherited-env poison class this
                    # arc exists to eliminate. Same category as git push/add/commit
                    # (T-2054/T-2462). run sets FW_INTEGRATION_IN_PROGRESS=1 only
                    # for the python subprocess's own internal git calls.
                    return 0
                    ;;
            esac
            ;;

        # Category 5: System utilities
        curl|wget|date|uname|ps|ss|id|whoami|hostname|env|printenv|df|du|free|uptime|lsb_release|nproc)
            return 0
            ;;

        # Category 6: Validation
        python3|python)
            # Only safe if it's a parse/check command (no file writes)
            if echo "$cmd" | grep -qE '^\s*(python3?)\s+-c\s'; then
                # Check for write indicators in the inline script
                if echo "$cmd" | grep -qE "(open\(.*, *['\"]w|\.write\(|shutil\.|os\.(rename|remove|unlink|makedirs|system))"; then
                    return 1
                fi
                return 0
            fi
            ;;
        bash|sh)
            # bash -n (syntax check only) is safe
            if echo "$cmd" | grep -qE '^\s*(ba)?sh\s+-n\b'; then
                return 0
            fi
            ;;

        # Special: echo without redirect is safe (diagnostic output)
        #
        # T-2887: this branch used to carry its OWN copy of the redirect regex,
        # `[^>]>[^>]|>>`. has_bash_write_pattern's copy below grew the `2` and `&`
        # exemptions that distinguish a file write from a file-descriptor
        # redirect; this copy never did. So the two disagreed on exactly the
        # fd forms — `echo x 2>&1` and `echo x 2>/dev/null` read as file writes
        # here and as no-write there. Measured, both directions:
        #
        #   echo hi 2>&1          echo-branch:MATCH   has_write:no
        #   echo hi 2>/dev/null   echo-branch:MATCH   has_write:no
        #   echo hi > f           echo-branch:MATCH   has_write:MATCH
        #
        # Delegate instead of re-deriving (L-399: N copies of a predicate can
        # disagree and nothing makes them agree — the same shape as T-2883's
        # six git-identity probes). Reported by 832 as their rail 489 defect;
        # L-518 says sweep our equivalent, and ours had it.
        #
        # Delegating is strictly more conservative than the old copy on the
        # non-fd shapes (it also catches rm / sed -i / tee / heredoc text), and
        # that costs nothing in production: check-active-task.sh:173 already runs
        # has_bash_write_pattern over the WHOLE command before consulting this
        # function at all. The private copy could therefore never contribute a
        # true positive the outer check had not already caught — only the two
        # false positives above.
        echo|printf)
            if ! has_bash_write_pattern "$cmd"; then
                return 0
            fi
            ;;

        # Special: cd is always safe
        cd)
            return 0
            ;;

        # Special: npm/cargo/brew read operations
        npm|npx|cargo|brew)
            local pkg_sub
            pkg_sub=$(echo "$cmd" | awk '{print $2}')
            case "$pkg_sub" in
                list|ls|info|show|search|view|outdated|audit|help|version|--version|-v|-V)
                    return 0
                    ;;
            esac
            ;;
    esac

    # Not in allowlist — caller should check for active task
    return 1
}

# Check if a command contains file-write patterns
has_bash_write_pattern() {
    local cmd="$1"

    # Redirect operators (but not comparison operators like 2>&1)
    if echo "$cmd" | grep -qE '[^2>&]>[^>&]|>>'; then
        return 0
    fi

    # In-place sed
    if echo "$cmd" | grep -qE '\bsed\b.*-i'; then
        return 0
    fi

    # Destructive file operations (already caught by Tier 0 but belt-and-suspenders)
    if echo "$cmd" | grep -qE '\b(rm|rmdir)\b'; then
        return 0
    fi

    # Heredoc
    if echo "$cmd" | grep -qE '<<\s*['"'"'"]?EOF'; then
        return 0
    fi

    # tee (writes to file)
    if echo "$cmd" | grep -qE '\btee\b'; then
        return 0
    fi

    return 1
}
