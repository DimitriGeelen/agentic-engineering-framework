#!/bin/bash
# fw init - Bootstrap a new project with the Agentic Engineering Framework
#
# Creates the directory structure, config files, and git hooks needed
# for a project to use the framework.

do_init() {
    local target_dir=""
    local provider="generic"
    local force=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --provider) provider="$2"; shift 2 ;;
            --force) force=true; shift ;;
            -h|--help)
                echo -e "${BOLD}fw init${NC} - Bootstrap a new project"
                echo ""
                echo "Usage: fw init [target-dir] [options]"
                echo ""
                echo "Arguments:"
                echo "  target-dir        Directory to initialize (default: current directory)"
                echo ""
                echo "Options:"
                echo "  --provider NAME   Generate provider-specific config: claude, cursor, generic (default: generic)"
                echo "  --force           Overwrite existing files"
                echo "  -h, --help        Show this help"
                echo ""
                echo "Examples:"
                echo "  fw init                          # Initialize current directory"
                echo "  fw init /path/to/project         # Initialize specific directory"
                echo "  fw init --provider claude        # Generate CLAUDE.md"
                echo "  fw init --provider cursor        # Generate .cursorrules"
                return 0
                ;;
            -*)
                echo -e "${RED}Unknown option: $1${NC}" >&2
                return 1
                ;;
            *)
                target_dir="$1"; shift
                ;;
        esac
    done

    # Default to current directory
    if [ -z "$target_dir" ]; then
        target_dir="$PWD"
    fi

    # Resolve to absolute path
    target_dir="$(cd "$target_dir" 2>/dev/null && pwd)" || {
        echo -e "${RED}ERROR: Directory does not exist: $target_dir${NC}" >&2
        return 1
    }

    # Check if already initialized
    if [ -f "$target_dir/.framework.yaml" ] && [ "$force" != true ]; then
        echo -e "${YELLOW}Project already initialized at $target_dir${NC}"
        echo "Use --force to reinitialize"
        return 1
    fi

    echo -e "${BOLD}fw init${NC} - Bootstrapping project"
    echo ""
    echo "  Target:    $target_dir"
    echo "  Framework: $FRAMEWORK_ROOT"
    echo "  Provider:  $provider"
    echo ""

    # --- Create directory structure ---
    echo -e "${YELLOW}Creating directory structure...${NC}"

    mkdir -p "$target_dir/.tasks/active"
    mkdir -p "$target_dir/.tasks/completed"
    mkdir -p "$target_dir/.tasks/templates"
    mkdir -p "$target_dir/.context/working"
    mkdir -p "$target_dir/.context/project"
    mkdir -p "$target_dir/.context/episodic"
    mkdir -p "$target_dir/.context/handovers"

    echo -e "  ${GREEN}OK${NC}  .tasks/{active,completed,templates}"
    echo -e "  ${GREEN}OK${NC}  .context/{working,project,episodic,handovers}"

    # --- Copy task template ---
    if [ -f "$FRAMEWORK_ROOT/.tasks/templates/default.md" ]; then
        cp "$FRAMEWORK_ROOT/.tasks/templates/default.md" "$target_dir/.tasks/templates/default.md"
        echo -e "  ${GREEN}OK${NC}  Task template"
    fi

    # --- Create .framework.yaml ---
    cat > "$target_dir/.framework.yaml" << FYAML
# Agentic Engineering Framework - Project Configuration
framework_path: $FRAMEWORK_ROOT
version: $FW_VERSION
FYAML
    echo -e "  ${GREEN}OK${NC}  .framework.yaml"

    # --- Create empty project memory files ---
    if [ ! -f "$target_dir/.context/project/patterns.yaml" ] || [ "$force" = true ]; then
        cat > "$target_dir/.context/project/patterns.yaml" << 'PYAML'
# Project Patterns - Learned from experience
# Categories: failure, success, workflow
# Added via: fw context add-pattern <type> "name" --task T-XXX
patterns: []
PYAML
        echo -e "  ${GREEN}OK${NC}  patterns.yaml"
    fi

    if [ ! -f "$target_dir/.context/project/decisions.yaml" ] || [ "$force" = true ]; then
        cat > "$target_dir/.context/project/decisions.yaml" << 'DYAML'
# Project Decisions - Architectural choices with rationale
# Added via: fw context add-decision "description" --task T-XXX --rationale "why"
decisions: []
DYAML
        echo -e "  ${GREEN}OK${NC}  decisions.yaml"
    fi

    if [ ! -f "$target_dir/.context/project/learnings.yaml" ] || [ "$force" = true ]; then
        cat > "$target_dir/.context/project/learnings.yaml" << 'LYAML'
# Project Learnings - Knowledge gained during development
# Added via: fw context add-learning "description" --task T-XXX
learnings: []
LYAML
        echo -e "  ${GREEN}OK${NC}  learnings.yaml"
    fi

    # --- Generate provider config ---
    echo ""
    echo -e "${YELLOW}Generating provider config...${NC}"

    case "$provider" in
        claude)
            generate_claude_md "$target_dir"
            echo -e "  ${GREEN}OK${NC}  CLAUDE.md"
            ;;
        cursor)
            generate_cursorrules "$target_dir"
            echo -e "  ${GREEN}OK${NC}  .cursorrules"
            ;;
        generic)
            generate_claude_md "$target_dir"
            echo -e "  ${GREEN}OK${NC}  CLAUDE.md (generic — works with any provider)"
            ;;
        *)
            echo -e "  ${YELLOW}WARN${NC}  Unknown provider '$provider', using generic"
            generate_claude_md "$target_dir"
            ;;
    esac

    # --- Install git hooks (if git repo) ---
    echo ""
    if [ -d "$target_dir/.git" ]; then
        echo -e "${YELLOW}Installing git hooks...${NC}"
        PROJECT_ROOT="$target_dir" "$FRAMEWORK_ROOT/agents/git/git.sh" install-hooks 2>/dev/null && \
            echo -e "  ${GREEN}OK${NC}  Git hooks installed" || \
            echo -e "  ${YELLOW}WARN${NC}  Git hook installation failed (run manually: fw git install-hooks)"
    else
        echo -e "  ${CYAN}SKIP${NC}  Git hooks (not a git repository)"
    fi

    # --- Summary ---
    echo ""
    echo -e "${GREEN}=== Project Initialized ===${NC}"
    echo ""
    echo "Directory: $target_dir"
    echo ""
    echo -e "${BOLD}Next steps:${NC}"
    echo "  1. cd $target_dir"
    echo "  2. fw doctor                    # Verify setup"
    echo "  3. fw context init              # Start first session"
    echo "  4. fw task create --name '...'  # Create your first task"
    echo ""
    echo -e "${BOLD}Framework commands:${NC}"
    echo "  fw help                         # See all commands"
    echo "  fw audit                        # Check compliance"
    echo "  fw handover --commit            # End-of-session handover"
}

# --- Provider Config Generators ---

generate_claude_md() {
    local dir="$1"
    local config_file="$dir/CLAUDE.md"

    if [ -f "$config_file" ] && [ "$force" != true ]; then
        echo -e "  ${YELLOW}SKIP${NC}  CLAUDE.md already exists (use --force to overwrite)"
        return
    fi

    local project_name
    project_name=$(basename "$dir")

    cat > "$config_file" << CMDEOF
# CLAUDE.md

Project configuration for the Agentic Engineering Framework.

## Project Overview

**Project:** $project_name

## Core Principle

**Nothing gets done without a task.** This is enforced structurally by the framework.

## Framework Integration

This project uses the Agentic Engineering Framework as shared tooling.

\`\`\`bash
# All operations go through fw
fw help                              # See all commands
fw task create --name "..." --type build --owner human
fw git commit -m "T-XXX: description"
fw audit                             # Check compliance
fw context status                    # View context state
fw handover --commit                 # End-of-session handover
\`\`\`

## Quick Reference

| Action | Command |
|--------|---------|
| Create task | \`fw task create\` |
| Commit | \`fw git commit -m "T-XXX: ..."\` |
| Audit | \`fw audit\` |
| Initialize session | \`fw context init\` |
| Set focus | \`fw context focus T-XXX\` |
| Handover | \`fw handover --commit\` |
| Health check | \`fw doctor\` |
| Metrics | \`fw metrics\` |

## Session Protocol

**Start:** \`fw context init\` → read handover → \`fw context focus T-XXX\`
**End:** session capture → \`fw handover --commit\`
CMDEOF
}

generate_cursorrules() {
    local dir="$1"
    local config_file="$dir/.cursorrules"

    if [ -f "$config_file" ] && [ "$force" != true ]; then
        echo -e "  ${YELLOW}SKIP${NC}  .cursorrules already exists (use --force to overwrite)"
        return
    fi

    local project_name
    project_name=$(basename "$dir")

    cat > "$config_file" << CREOF
# Cursor Rules - Agentic Engineering Framework

## Project: $project_name

## Core Rule
Nothing gets done without a task. Every commit must reference a task ID (T-XXX).

## Framework Commands
All operations go through the \`fw\` CLI:
- \`fw task create --name "..." --type build --owner human\`
- \`fw git commit -m "T-XXX: description"\`
- \`fw audit\` — Check compliance
- \`fw handover --commit\` — End-of-session handover

## Session Protocol
Start: \`fw context init\` → read handover → \`fw context focus T-XXX\`
End: session capture → \`fw handover --commit\`
CREOF
}
