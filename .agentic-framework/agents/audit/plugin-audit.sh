#!/usr/bin/env bash
# ============================================================================
# Plugin Task-Awareness Audit
# T-067: Scans enabled Claude Code plugins for task-system awareness
# ============================================================================
# Classifies each skill/agent/command as:
#   TASK-AWARE    — References task system (task, fw work-on, TaskCreate, etc.)
#   TASK-SILENT   — No task references, no authority claims (informational)
#   TASK-BYPASSING — Authority-claiming language without task gates
#
# Exit codes: 0 = all clear, 1 = bypassing skills found
# ============================================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$FRAMEWORK_ROOT/lib/paths.sh"

# Colors provided by lib/colors.sh (via paths.sh chain)

# Settings locations
USER_SETTINGS="$HOME/.claude/settings.json"
PLUGINS_MARKETPLACE="$HOME/.claude/plugins/marketplaces/claude-plugins-official"
PLUGINS_CACHE="$HOME/.claude/plugins/cache/claude-plugins-official"

# --------------------------------------------------------------------------
# Gather enabled plugins from settings.json
# --------------------------------------------------------------------------
get_enabled_plugins() {
    python3 -c "
import json, sys
try:
    with open('$USER_SETTINGS') as f:
        data = json.load(f)
    plugins = data.get('enabledPlugins', {})
    for key, enabled in plugins.items():
        if enabled:
            # key format: 'name@marketplace'
            name = key.split('@')[0]
            print(name)
except Exception as e:
    print(f'ERROR: {e}', file=sys.stderr)
    sys.exit(1)
" 2>/dev/null
}

# --------------------------------------------------------------------------
# Find plugin content directory (prefer cache, fall back to marketplace)
# --------------------------------------------------------------------------
find_plugin_dir() {
    local plugin_name="$1"

    # Check cache first (versioned subdirs)
    if [ -d "$PLUGINS_CACHE/$plugin_name" ]; then
        # Find the latest version dir (or hash dir)
        local latest
        latest=$(ls -1t "$PLUGINS_CACHE/$plugin_name/" 2>/dev/null | head -1)
        if [ -n "$latest" ] && [ -d "$PLUGINS_CACHE/$plugin_name/$latest" ]; then
            echo "$PLUGINS_CACHE/$plugin_name/$latest"
            return 0
        fi
    fi

    # Check marketplace plugins/
    if [ -d "$PLUGINS_MARKETPLACE/plugins/$plugin_name" ]; then
        echo "$PLUGINS_MARKETPLACE/plugins/$plugin_name"
        return 0
    fi

    # Check marketplace external_plugins/
    if [ -d "$PLUGINS_MARKETPLACE/external_plugins/$plugin_name" ]; then
        echo "$PLUGINS_MARKETPLACE/external_plugins/$plugin_name"
        return 0
    fi

    return 1
}

# --------------------------------------------------------------------------
# Scan a single markdown file for task-awareness
# Returns: AWARE, SILENT, or BYPASSING
# --------------------------------------------------------------------------
classify_file() {
    local filepath="$1"
    python3 - "$filepath" << 'PYEOF'
import re, sys

filepath = sys.argv[1] if len(sys.argv) > 1 else ""
if not filepath:
    print("SILENT")
    sys.exit(0)

try:
    with open(filepath, "r") as f:
        content = f.read()
except Exception:
    print("SILENT")
    sys.exit(0)

# Task-awareness indicators
task_patterns = [
    r'\btask\b.*\b(create|update|system|first|gate)\b',
    r'\bfw\s+(work-on|task|context\s+focus)\b',
    r'\bTaskCreate\b',
    r'\bTaskUpdate\b',
    r'\bTodoWrite\b',
    r'nothing\s+gets\s+done\s+without\s+a\s+task',
    r'\btask-first\b',
    r'\.tasks/',
    r'active.task',
    r'focus\.yaml',
]

for pattern in task_patterns:
    if re.search(pattern, content, re.IGNORECASE):
        print("AWARE")
        sys.exit(0)

# Authority-bypassing indicators (strong language that could override task gates)
bypass_patterns = [
    r'(you\s+)?MUST\s+(use|invoke|call|follow|check).*before\s+(any|all)\b',
    r'before\s+ANY\s+(response|action|implementation)',
    r'DO\s+NOT\s+.*until\s+you\s+have',
    r'EXTREMELY.IMPORTANT',
    r'This\s+is\s+not\s+negotiable',
    r'YOU\s+DO\s+NOT\s+HAVE\s+A\s+CHOICE',
    r'implement\s+now',
    r'HARD.GATE',
    r'BLOCKING\s+REQUIREMENT',
    r'you\s+ABSOLUTELY\s+MUST',
    r'invoke.*skill.*BEFORE\s+ANY',
]

for pattern in bypass_patterns:
    if re.search(pattern, content):
        print("BYPASSING")
        sys.exit(0)

print("SILENT")
PYEOF
}

# --------------------------------------------------------------------------
# Main audit logic
# --------------------------------------------------------------------------
main() {
    echo -e "${BOLD}=== Plugin Task-Awareness Audit ===${NC}"
    echo ""

    local plugins
    plugins=$(get_enabled_plugins)
    if [ -z "$plugins" ]; then
        echo -e "${YELLOW}No enabled plugins found in $USER_SETTINGS${NC}"
        exit 0
    fi

    local total_aware=0
    local total_silent=0
    local total_bypassing=0
    local bypassing_details=""

    # Per-plugin summary
    while IFS= read -r plugin_name; do
        local plugin_dir
        if ! plugin_dir=$(find_plugin_dir "$plugin_name"); then
            printf "  ${CYAN}%-24s${NC} %s\n" "$plugin_name" "not installed"
            continue
        fi

        local aware=0
        local silent=0
        local bypassing=0
        local file_count=0

        # Scan skills, agents, and commands
        local scan_files=()
        while IFS= read -r -d '' f; do
            scan_files+=("$f")
        done < <(find "$plugin_dir" \( -path "*/skills/*/SKILL.md" -o -path "*/agents/*.md" -o -path "*/commands/*.md" \) -not -name "README.md" -print0 2>/dev/null)

        for filepath in "${scan_files[@]}"; do
            file_count=$((file_count + 1))
            local classification
            classification=$(classify_file "$filepath")

            case "$classification" in
                AWARE)
                    aware=$((aware + 1))
                    total_aware=$((total_aware + 1))
                    ;;
                BYPASSING)
                    bypassing=$((bypassing + 1))
                    total_bypassing=$((total_bypassing + 1))
                    # Extract relative path for detail
                    local rel_path="${filepath#$plugin_dir/}"
                    local skill_name
                    skill_name=$(basename "$(dirname "$filepath")")
                    [ "$skill_name" = "commands" ] || [ "$skill_name" = "agents" ] && skill_name=$(basename "$filepath" .md)
                    bypassing_details+="  ${RED}BYPASSING${NC}  ${plugin_name}:${skill_name}\n"
                    bypassing_details+="            ${filepath}\n"
                    ;;
                *)
                    silent=$((silent + 1))
                    total_silent=$((total_silent + 1))
                    ;;
            esac
        done

        if [ "$file_count" -eq 0 ]; then
            printf "  ${CYAN}%-24s${NC} no skills/agents/commands (MCP-only)\n" "$plugin_name"
        else
            local status_color="$GREEN"
            [ "$bypassing" -gt 0 ] && status_color="$RED"

            printf "  ${CYAN}%-24s${NC} %2d files  " "$plugin_name" "$file_count"
            [ "$aware" -gt 0 ] && printf "${GREEN}%d AWARE${NC}  " "$aware"
            [ "$silent" -gt 0 ] && printf "%d SILENT  " "$silent"
            [ "$bypassing" -gt 0 ] && printf "${RED}%d BYPASSING${NC}" "$bypassing"
            echo ""
        fi
    done <<< "$plugins"

    # Summary
    echo ""
    echo -e "${BOLD}--- Summary ---${NC}"
    echo -e "  TASK-AWARE:     ${GREEN}${total_aware}${NC}"
    echo -e "  TASK-SILENT:    ${total_silent}"
    echo -e "  TASK-BYPASSING: ${RED}${total_bypassing}${NC}"
    echo ""

    # Detail on bypassing skills
    if [ "$total_bypassing" -gt 0 ]; then
        echo -e "${BOLD}--- BYPASSING Details ---${NC}"
        echo ""
        echo -e "$bypassing_details"
        echo -e "${YELLOW}Recommendation:${NC} These skills use authority-claiming language that can"
        echo "override the task-first principle. The PreToolUse hook (check-active-task.sh)"
        echo "provides structural enforcement. Review CLAUDE.md Instruction Precedence section."
        echo ""
        exit 1
    else
        echo -e "${GREEN}All plugin content is task-aware or task-silent. No action needed.${NC}"
        exit 0
    fi
}

# --------------------------------------------------------------------------
# Quick check for fw doctor integration (returns 0/1/count)
# --------------------------------------------------------------------------
doctor_check() {
    local plugins
    plugins=$(get_enabled_plugins 2>/dev/null)
    [ -z "$plugins" ] && echo "0" && return 0

    local bypassing=0
    while IFS= read -r plugin_name; do
        local plugin_dir
        plugin_dir=$(find_plugin_dir "$plugin_name" 2>/dev/null) || continue
        while IFS= read -r -d '' filepath; do
            local classification
            classification=$(classify_file "$filepath")
            [ "$classification" = "BYPASSING" ] && bypassing=$((bypassing + 1))
        done < <(find "$plugin_dir" \( -path "*/skills/*/SKILL.md" -o -path "*/agents/*.md" -o -path "*/commands/*.md" \) -not -name "README.md" -print0 2>/dev/null)
    done <<< "$plugins"

    echo "$bypassing"
    [ "$bypassing" -eq 0 ] && return 0 || return 1
}

# Route
case "${1:-}" in
    --doctor-check)
        doctor_check
        ;;
    *)
        main
        ;;
esac
