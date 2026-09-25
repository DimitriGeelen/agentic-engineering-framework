#!/bin/bash
# Git Agent - Commit subcommand
# Validates task references before committing
#
# ── Pathspec scoping (T-3090) ────────────────────────────────────────────────
# Everything after `--` is a PATHSPEC and is forwarded to `git commit` after its
# own `--`, so the commit contains only those paths. Without it, `git commit`
# takes the WHOLE INDEX — including anything a concurrent session had staged but
# not yet committed.
#
# That is not hypothetical: commit d3d3e49db ("T-3028: Session handover
# S-2026-0819-2334") absorbed two files belonging to another session's T-3089 and
# emptied that session's index out from under it mid-compose. The handover had
# staged narrowly (`git add <2 files>`) and still swept 4 files, because staging
# is only half the operation — `git add` bounds what goes INTO the index, not
# what comes OUT of it at commit time.
#
# Callers that legitimately want the whole index (the ordinary single-session
# `git add …` then `fw git commit` flow) simply pass no pathspec — unchanged.
# Callers that assemble a specific set of files MUST pass one:
#
#     git.sh commit -m "T-XXX: msg" -- path/one path/two
#
# Two properties of `git commit -- <paths>`, both verified empirically (T-3090)
# and both load-bearing:
#
#   1. It commits the WORKING TREE content of those paths and leaves every other
#      index entry staged and intact. That is what makes the concurrent writer's
#      staged work survive rather than merely be excluded.
#   2. The paths must already be TRACKED. An untracked path fails the whole
#      commit with "pathspec '<p>' did not match any file(s) known to git".
#
# (2) is why the `git add` in a caller like agents/handover/handover.sh is
# REQUIRED and not vestigial: a handover file is new each session, so without
# the add the pathspec commit would error out entirely. Do not "simplify" a
# caller by deleting its add on the theory that the pathspec covers it.

do_commit() {
    local message=""
    local task_id=""
    local bypass=false
    local bypass_reason=""
    local git_args=()
    local pathspec=()
    local in_pathspec=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        # T-3090: once `--` is seen, everything after it is a pathspec. Held in
        # its own array rather than falling through to the `*)` catch-all so a
        # future refactor of that branch cannot silently un-scope the commit —
        # which is the exact regression this task exists to close.
        if [ "$in_pathspec" = true ]; then
            pathspec+=("$1")
            shift
            continue
        fi
        case $1 in
            --)
                in_pathspec=true
                shift
                ;;
            -m)
                message="$2"
                shift 2
                ;;
            -t|--task)
                task_id="$2"
                shift 2
                ;;
            --bypass)
                bypass=true
                shift
                ;;
            --reason)
                bypass_reason="$2"
                shift 2
                ;;
            -h|--help)
                show_commit_help
                exit 0
                ;;
            *)
                # Pass through to git
                git_args+=("$1")
                shift
                ;;
        esac
    done

    check_git_repo

    # If task ID provided separately, prepend to message
    if [ -n "$task_id" ] && [ -n "$message" ]; then
        message="$task_id: $message"
    fi

    # Check if we have a message
    if [ -z "$message" ]; then
        echo -e "${RED}ERROR: Commit message required${NC}"
        echo "Use: git.sh commit -m \"T-XXX: your message\""
        exit 1
    fi

    # F-17 (T-3466): stage the task-file `last_update:` bump BEFORE the commit is
    # created, not after. The old order (commit, then update_task_timestamp) meant
    # the bump was NEVER in the commit it described — it sat as a trailing dirty
    # diff that only the NEXT commit would pick up, by which point that commit's
    # own post-commit bump had already re-dirtied the tree. "Is the working tree
    # clean?" could never be true immediately after `fw git commit`, which is
    # exactly the signal the consuming project's audit (uncommitted-changes /
    # G-004) fires on — a framework-manufactured false positive, not real drift.
    #
    # Scoped to the NON-bypass, NO-PATHSPEC path only:
    #
    #   * `--bypass` never touched the task timestamp before this fix (it is the
    #     escape hatch for commits with no task reference at all, or none yet
    #     created) and still doesn't.
    #
    #   * A pathspec-scoped commit (T-3090) is a caller EXPLICITLY asking for
    #     "exactly these paths, no more, no fewer" — that guarantee is what
    #     T-3090 exists to protect (a concurrent writer's staged-but-uncommitted
    #     file must never ride along), and it is pinned by
    #     tests/unit/handover_commit_scope.bats with exact-file-count assertions.
    #     Auto-adding the task file to a scoped pathspec would silently violate
    #     that contract — measured: it broke 2 of that suite's tests when tried.
    #     Pathspec-scoped commits keep the ORIGINAL post-commit-timestamp
    #     behaviour further down (still dirties the tree afterwards), which is a
    #     narrower, already-accepted cost for a narrower, already-deliberate
    #     caller — not the "everyday `git add -A && git commit` flow" this
    #     finding's symptom and CLAUDE.md's documented post-completion form
    #     describe. Widening the fix into every pathspec-scoped call was not the
    #     described symptom and is out of this finding's scope.
    #
    # `git add` first is what makes an as-yet-untracked task file (a brand new
    # task, first commit) committable at all.
    local commit_task_id commit_task_file=""
    commit_task_id=$(extract_task_id "$message")
    if [ "$bypass" != true ] && [ ${#pathspec[@]} -eq 0 ] && [ -n "$commit_task_id" ]; then
        commit_task_file=$(find "$TASKS_DIR/active" -name "${commit_task_id}-*.md" -type f 2>/dev/null | head -1)
        if [ -n "$commit_task_file" ]; then
            update_task_timestamp "$commit_task_id"
            git -C "$PROJECT_ROOT" add -- "$commit_task_file"
        fi
    fi

    # T-3090: assemble the final argv once, for BOTH the bypass and the normal
    # call site below — two call sites drifting apart is how the missing
    # pathspec survived in the first place. The `--` is emitted ONLY when a
    # pathspec was actually given, so the no-pathspec case (commit the whole
    # index) stays byte-identical to pre-T-3090 behaviour and no existing caller
    # changes meaning.
    local commit_argv=(-m "$message" "${git_args[@]}")
    if [ ${#pathspec[@]} -gt 0 ]; then
        commit_argv+=(-- "${pathspec[@]}")
    fi

    # Handle bypass mode
    if [ "$bypass" = true ]; then
        if [ -z "$bypass_reason" ]; then
            echo -e "${YELLOW}WARNING: You are bypassing task enforcement.${NC}"
            echo ""
            read -p "Reason for bypass (required): " bypass_reason
            if [ -z "$bypass_reason" ]; then
                echo -e "${RED}ERROR: Bypass requires a reason${NC}"
                exit 1
            fi
        fi

        # Do the commit
        if git -C "$PROJECT_ROOT" commit "${commit_argv[@]}"; then
            local commit_sha
            commit_sha=$(git -C "$PROJECT_ROOT" rev-parse --short HEAD)

            # Log the bypass
            source "$LIB_DIR/bypass.sh"
            log_bypass_entry "$commit_sha" "$message" "$bypass_reason"

            echo ""
            echo -e "${YELLOW}REMINDER: Create a retroactive task for this work.${NC}"
            echo "Run: ./agents/task-create/create-task.sh --name \"Retroactive: $message\""
        else
            exit 1
        fi
        return
    fi

    # Extract task reference from message. Already computed above (as
    # commit_task_id) for the timestamp bump; re-derive found_task from it
    # rather than a second extract_task_id call so the two cannot drift.
    local found_task="$commit_task_id"

    if [ -z "$found_task" ]; then
        echo ""
        echo -e "${RED}ERROR: No task reference found in commit message${NC}"
        echo ""
        echo "Your message: $message"
        echo ""
        echo "To fix:"
        echo "  1. Add task reference: git.sh commit -m \"T-XXX: $message\""
        echo "  2. Create a task: ./agents/task-create/create-task.sh"
        echo "  3. Emergency bypass: git.sh commit --bypass -m \"$message\""
        echo ""
        exit 1
    fi

    # Optionally validate task exists (warn only, don't block)
    if ! task_exists "$found_task"; then
        echo -e "${YELLOW}WARNING: Task $found_task not found in .tasks/${NC}"
        echo "Consider creating it: ./agents/task-create/create-task.sh"
        echo ""
    fi

    # Do the commit.
    #
    # F-17 (T-3466): for the common no-pathspec flow, commit_task_file is
    # already set and the timestamp bump already happened and was staged above,
    # BEFORE this commit — reused here rather than re-run so "did we bump it"
    # and "did we report it" can't disagree.
    #
    # For a pathspec-scoped commit, commit_task_file is still empty at this
    # point by construction (the block above skips it when pathspec is
    # non-empty) — fall back to the pre-fix ORDER (bump after, per the T-3090
    # scope note above) so a scoped caller's exact path set is never widened.
    if git -C "$PROJECT_ROOT" commit "${commit_argv[@]}"; then
        if [ ${#pathspec[@]} -gt 0 ] && [ -n "$found_task" ]; then
            commit_task_file=$(find "$TASKS_DIR/active" -name "${found_task}-*.md" -type f 2>/dev/null | head -1)
            [ -n "$commit_task_file" ] && update_task_timestamp "$found_task"
        fi
        if [ -n "$commit_task_file" ]; then
            local task_name
            task_name=$(get_task_name "$found_task")
            echo ""
            echo -e "${GREEN}Task $found_task updated${NC} ($task_name)"
        fi
    else
        exit 1
    fi
}

show_commit_help() {
    cat << EOF
Git Agent - Commit Command

Usage: git.sh commit [options] [-- <pathspec>...]

Options:
  -m MESSAGE      Commit message (must include T-XXX)
  -t, --task ID   Explicitly specify task (prepends to message)
  --bypass        Emergency bypass (prompts for reason, logs to bypass-log)
  --reason TEXT   Bypass reason (use with --bypass)
  -- PATH...      Commit ONLY these paths (T-3090). Without it the whole index
                  is committed, which absorbs anything a concurrent session
                  staged but has not yet committed.
  -h, --help      Show this help

Examples:
  git.sh commit -m "T-003: Add bypass log"
  git.sh commit -t T-003 -m "Add bypass log"
  git.sh commit --bypass --reason "Production P1" -m "Emergency fix"
  git.sh commit -m "T-003: handover" -- .context/handovers/LATEST.md

Note: Commits without task references are blocked unless --bypass is used.
      All bypasses are logged in .context/bypass-log.yaml

      If you assembled a specific set of files, pass them after --. Staging
      them with 'git add' does NOT scope the commit: git add bounds what goes
      into the index, not what comes out of it. Origin: T-3090.
EOF
}
