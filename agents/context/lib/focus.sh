#!/bin/bash
# Context Agent - focus command
# Set or show current task focus

do_focus() {
    ensure_context_dirs

    # T-3038 (OBS-291): under FW_SESSION_SCOPED_FOCUS=1 this resolves to a
    # session-local focus.<key>.yaml so a dispatched worker cannot overwrite the
    # parent's task + focus_session stamp and lock it out of its own work.
    # Unset/0 returns the shared focus.yaml — default behaviour is unchanged.
    # The reader (check-active-task.sh) calls the SAME helper; keeping one
    # implementation is what makes producer/consumer parity structural (L-399)
    # rather than a convention two files are trusted to remember.
    local focus_file
    if declare -F fw_focus_file >/dev/null 2>&1; then
        focus_file=$(fw_focus_file "$PROJECT_ROOT")
    else
        focus_file="$CONTEXT_DIR/working/focus.yaml"
    fi

    if [ $# -eq 0 ]; then
        # Show current focus
        if [ -f "$focus_file" ]; then
            local current=$(grep "^current_task:" "$focus_file" | cut -d' ' -f2)
            if [ "$current" = "null" ] || [ -z "$current" ]; then
                echo "No current focus set"
                echo ""
                echo "To set focus: $0 focus T-XXX"
            else
                echo "Current focus: $current"

                # Show task name if we can find it
                local task_file=$(find_task_file "$current")
                if [ -n "$task_file" ]; then
                    local task_name=$(get_task_name "$task_file")
                    echo "Task: $task_name"
                fi
            fi
        else
            echo "Working memory not initialized. Run: $0 init"
        fi
    else
        local task_id="$1"

        # Validate task exists AND is active (T-2874).
        #
        # The `active` scope is load-bearing, not defensive. find_task_file's scope
        # parameter is OPTIONAL with a permissive default: unscoped it resolves active/
        # and then falls back to completed/. The gate that reads this value back requires
        # `find_task_file "$CURRENT_TASK" active` (check-active-task.sh:401). Omit the
        # scope here and the writer's accepted set becomes a strict SUPERSET of the
        # reader's usable set — every id in the difference writes a state that is
        # writable but unusable: `fw context focus <completed-id>` exits 0, and then
        # every gated Write/Edit/Bash dies on "Task X is not active".
        #
        # T-2054's comment already asserts this state is impossible (--status
        # work-completed nulls current_task AND moves the file), but nothing enforced it
        # on the one path that could still write it. A rule stated in a comment on one
        # side of a seam is not enforced on the other. Origin: 832 rail 461 (their
        # 8842cedb); both call sites verified in our tree before adopting.
        # T-3537: workflow-management tasks resolve from .tasks/workflow/, not
        # active/. They never close, so the completed/-fallback reasoning above does
        # not apply to them — but the same producer/consumer parity rule does, and
        # this is where it nearly broke. The gate (check-active-task.sh) was taught
        # to accept WM focus BEFORE this writer was taught to set it, which made the
        # whole fence green, fully tested, and structurally unreachable: the third
        # instance of L-573 in one day, found only by running `fw context focus
        # WM-001` on the live path instead of testing the predicate.
        local task_file=""
        local _wm_lib="${FRAMEWORK_ROOT:-$PROJECT_ROOT}/lib/wm_tasks.sh"
        if [ -f "$_wm_lib" ]; then
            # shellcheck disable=SC1090
            . "$_wm_lib"
            if fw_is_wm_task "$task_id"; then
                if ! fw_is_known_wm_task "$task_id"; then
                    echo -e "${RED}Unknown workflow-management task: $task_id${NC}" >&2
                    echo "  Known: $FW_WM_IDS (files in .tasks/workflow/)." >&2
                    echo "  Adding another is an operator decision, not a convenience (T-3537)." >&2
                    exit 1
                fi
                task_file=$(fw_find_wm_task "$task_id" "$PROJECT_ROOT")
                if [ -z "$task_file" ]; then
                    echo -e "${RED}Workflow task $task_id has no file in .tasks/workflow/${NC}" >&2
                    exit 1
                fi
            fi
        fi
        # `|| true` is load-bearing under context.sh's `set -euo pipefail`.
        # find_task_file ends with `[[ -n "$result" ]] && echo "$result"`, so it
        # RETURNS 1 when the task is not found. The original line was
        # `local task_file=$(find_task_file …)`, and `local` always exits 0 — it
        # was masking that non-zero. Dropping `local` to allow the WM branch above
        # to pre-set the variable also removed the mask, so `set -e` killed the
        # script at this line and T-2874's "completed, not active" refusal never
        # printed: exit 1, zero output, three tests red. Measured, then fixed here
        # rather than by restoring `local`, because the masking was accidental and
        # the next person to touch this line would have hit it again.
        if [ -z "$task_file" ]; then
            task_file=$(find_task_file "$task_id" active) || true
        fi
        if [ -z "$task_file" ]; then
            # Distinguish the two causes. They exit identically but need different
            # recoveries, and "not found" sends the operator hunting for a typo in an
            # id that exists.
            if [ -n "$(find_task_file "$task_id")" ]; then
                echo -e "${RED}Cannot focus ${task_id}: it is completed, not active.${NC}" >&2
                echo "" >&2
                echo "  Focus must name a task the gates can still work under. Setting it to" >&2
                echo "  a completed id would succeed here and then block every Write/Edit/Bash" >&2
                echo "  after it, because the gate resolves focus against active/ only." >&2
                echo "" >&2
                echo "  To resume this task:    bin/fw work-on ${task_id}" >&2
                echo "  To start something new: bin/fw work-on \"<name>\" --type build" >&2
            else
                echo -e "${RED}Task not found: $task_id${NC}" >&2
                echo "  No task with that id in .tasks/active/ or .tasks/completed/." >&2
            fi
            exit 1
        fi

        # Read current session ID for stamping
        local session_file="$CONTEXT_DIR/working/session.yaml"
        local current_session_id=""
        if [ -f "$session_file" ]; then
            current_session_id=$({ grep "^session_id:" "$session_file" 2>/dev/null || true; } | head -1 | awk '{print $2}')
        fi

        # Update focus.yaml with task + session stamp (T-560)
        python3 -c "
import yaml, sys, os
focus_file = '$focus_file'
task_id = '$task_id'
session_id = '${current_session_id:-unknown}'
defaults = {
    'current_task': None,
    'priorities': [],
    'blockers': [],
    'pending_decisions': [],
    'reminders': ['Run audit before pushing', 'Create handover before ending session'],
    'focus_session': None,
}
try:
    with open(focus_file) as f:
        data = yaml.safe_load(f) or {}
except:
    data = {}
# Ensure all default fields exist
for k, v in defaults.items():
    if k not in data:
        data[k] = v
data['current_task'] = task_id
data['focus_session'] = session_id
# T-100191: same-dir temp + os.replace — atomic write (L-493 class)
tmp_path = focus_file + '.tmp'
with open(tmp_path, 'w') as f:
    f.write('# Working Memory - Current Focus\n')
    f.write(f'# Session: {session_id}\n\n')
    yaml.dump(data, f, default_flow_style=False, sort_keys=False)
os.replace(tmp_path, focus_file)
" 2>/dev/null || {
            # Fallback if Python fails
            _sed_i "s/^current_task:.*/current_task: $task_id/" "$focus_file"
        }

        # Update session.yaml tasks_touched
        local session_file="$CONTEXT_DIR/working/session.yaml"
        if [ -f "$session_file" ]; then
            # Check if already in tasks_touched
            if ! grep -q "$task_id" "$session_file"; then
                # Add to tasks_touched (simplified - just note the touch)
                local touched=$(grep "^tasks_touched:" "$session_file" | sed 's/tasks_touched: //' | tr -d '[]')
                if [ -z "$touched" ]; then
                    touched="$task_id"
                else
                    touched="$touched, $task_id"
                fi
                _sed_i "s/^tasks_touched:.*/tasks_touched: [$touched]/" "$session_file"
            fi
        fi

        # T-1063: Write .termlink-task for MCP governance integration
        # TermLink MCP tools read this file when TERMLINK_TASK_GOVERNANCE=1
        echo "$task_id" > "$PROJECT_ROOT/.termlink-task"

        local task_name=$(grep "^name:" "$task_file" | sed 's/name: //')
        echo -e "${GREEN}Focus set: $task_id${NC}"
        echo "Task: $task_name"

        # Memory recall — surface relevant prior knowledge (T-246)
        # Timeout: 10s to prevent hanging when Ollama/Qdrant is slow (T-323)
        local recall_script="$FRAMEWORK_ROOT/agents/context/lib/memory-recall.py"
        if [ -f "$recall_script" ]; then
            echo ""
            timeout 10 python3 "$recall_script" --task "$task_id" --limit 5 2>/dev/null || true
        fi

        # Task briefing via semantic search (T-270)
        # Timeout: 15s to prevent hanging when Ollama/Qdrant is slow (T-323)
        local ask_script="$FRAMEWORK_ROOT/lib/ask.py"
        if [ -f "$ask_script" ]; then
            local briefing
            briefing=$(timeout 15 python3 "$ask_script" --concise --no-think \
                "Brief me on task $task_id: $task_name. What prior work, patterns, and decisions are relevant? What should I watch out for?" \
                2>/dev/null) || true
            if [ -n "$briefing" ]; then
                echo ""
                echo -e "${CYAN}=== Task Briefing ===${NC}"
                echo "$briefing"
            fi
        fi
    fi
}
