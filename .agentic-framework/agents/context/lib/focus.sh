#!/bin/bash
# Context Agent - focus command
# Set or show current task focus

do_focus() {
    ensure_context_dirs

    local focus_file="$CONTEXT_DIR/working/focus.yaml"

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

        # Validate task exists
        local task_file=$(find_task_file "$task_id")
        if [ -z "$task_file" ]; then
            echo -e "${RED}Task not found: $task_id${NC}"
            exit 1
        fi

        # Read current session ID for stamping
        local session_file="$CONTEXT_DIR/working/session.yaml"
        local current_session_id=""
        if [ -f "$session_file" ]; then
            current_session_id=$(grep "^session_id:" "$session_file" | head -1 | awk '{print $2}')
        fi

        # Update focus.yaml with task + session stamp (T-560)
        python3 -c "
import yaml, sys
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
with open(focus_file, 'w') as f:
    f.write('# Working Memory - Current Focus\n')
    f.write(f'# Session: {session_id}\n\n')
    yaml.dump(data, f, default_flow_style=False, sort_keys=False)
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
