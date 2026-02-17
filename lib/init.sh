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
    if [ -f "$target_dir/.framework.yaml" ] && [ "${force:-false}" != true ]; then
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
    mkdir -p "$target_dir/.context/scans"

    echo -e "  ${GREEN}OK${NC}  .tasks/{active,completed,templates}"
    echo -e "  ${GREEN}OK${NC}  .context/{working,project,episodic,handovers,scans}"

    # --- .gitignore for volatile working memory files ---
    cat > "$target_dir/.context/working/.gitignore" << 'WGIT'
# Volatile session files — regenerated each session
.tool-counter
.prev-token-reading
session.yaml
focus.yaml
tier0-approval
WGIT
    echo -e "  ${GREEN}OK${NC}  .context/working/.gitignore"

    # --- Copy task templates (all .md files from framework templates) ---
    local template_count=0
    for tmpl in "$FRAMEWORK_ROOT/.tasks/templates/"*.md; do
        [ -f "$tmpl" ] || continue
        cp "$tmpl" "$target_dir/.tasks/templates/$(basename "$tmpl")"
        template_count=$((template_count + 1))
    done
    if [ "$template_count" -gt 0 ]; then
        echo -e "  ${GREEN}OK${NC}  Task templates ($template_count copied)"
    else
        echo -e "  ${YELLOW}WARN${NC}  No task templates found in $FRAMEWORK_ROOT/.tasks/templates/"
    fi

    # --- Create .framework.yaml ---
    local project_name
    project_name=$(basename "$target_dir")
    local init_timestamp
    init_timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    cat > "$target_dir/.framework.yaml" << FYAML
# Agentic Engineering Framework - Project Configuration
project_name: $project_name
framework_path: $FRAMEWORK_ROOT
version: $FW_VERSION
provider: $provider
initialized_at: $init_timestamp
FYAML
    echo -e "  ${GREEN}OK${NC}  .framework.yaml"

    # --- Create empty project memory files ---
    if [ ! -f "$target_dir/.context/project/patterns.yaml" ] || [ "${force:-false}" = true ]; then
        cat > "$target_dir/.context/project/patterns.yaml" << 'PYAML'
# Project Patterns - Learned from experience
# Categories: failure, success, workflow
# Added via: fw context add-pattern <type> "name" --task T-XXX
patterns: []
PYAML
        echo -e "  ${GREEN}OK${NC}  patterns.yaml"
    fi

    if [ ! -f "$target_dir/.context/project/decisions.yaml" ] || [ "${force:-false}" = true ]; then
        cat > "$target_dir/.context/project/decisions.yaml" << 'DYAML'
# Project Decisions - Architectural choices with rationale
# Added via: fw context add-decision "description" --task T-XXX --rationale "why"
decisions: []
DYAML
        echo -e "  ${GREEN}OK${NC}  decisions.yaml"
    fi

    if [ ! -f "$target_dir/.context/project/learnings.yaml" ] || [ "${force:-false}" = true ]; then
        cat > "$target_dir/.context/project/learnings.yaml" << 'LYAML'
# Project Learnings - Knowledge gained during development
# Added via: fw context add-learning "description" --task T-XXX
learnings: []
LYAML
        echo -e "  ${GREEN}OK${NC}  learnings.yaml"
    fi

    if [ ! -f "$target_dir/.context/project/practices.yaml" ] || [ "${force:-false}" = true ]; then
        cat > "$target_dir/.context/project/practices.yaml" << 'PRAML'
# Project Practices - Graduated learnings (3+ applications)
# Promoted via: fw promote L-XXX --name "practice name" --directive D1
practices: []
PRAML
        echo -e "  ${GREEN}OK${NC}  practices.yaml"
    fi

    if [ ! -f "$target_dir/.context/project/assumptions.yaml" ] || [ "${force:-false}" = true ]; then
        cat > "$target_dir/.context/project/assumptions.yaml" << 'AYAML'
# Project Assumptions - Tracked via inception workflow
# Added via: fw assumption add "description" --task T-XXX
# Validated via: fw assumption validate A-XXX --evidence "..."
assumptions: []
AYAML
        echo -e "  ${GREEN}OK${NC}  assumptions.yaml"
    fi

    # --- Generate provider config ---
    echo ""
    echo -e "${YELLOW}Generating provider config...${NC}"

    case "$provider" in
        claude)
            generate_claude_md "$target_dir"
            echo -e "  ${GREEN}OK${NC}  CLAUDE.md"
            generate_claude_code_config "$target_dir"
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
        PROJECT_ROOT="$target_dir" "$FRAMEWORK_ROOT/agents/git/git.sh" install-hooks && \
            echo -e "  ${GREEN}OK${NC}  Git hooks installed" || \
            echo -e "  ${YELLOW}WARN${NC}  Git hook installation failed (run manually: fw git install-hooks)"
    else
        echo -e "  ${CYAN}SKIP${NC}  Git hooks (not a git repository)"
    fi

    # --- Ensure fw is in PATH (symlink to /usr/local/bin) ---
    echo ""
    if ! command -v fw >/dev/null 2>&1; then
        echo -e "${YELLOW}Setting up fw command...${NC}"
        if [ -w /usr/local/bin ]; then
            ln -sf "$FRAMEWORK_ROOT/bin/fw" /usr/local/bin/fw
            echo -e "  ${GREEN}OK${NC}  Symlinked fw → /usr/local/bin/fw"
        else
            echo -e "  ${YELLOW}WARN${NC}  Cannot create symlink in /usr/local/bin (no write access)"
            echo -e "         Add to PATH manually: export PATH=\"$FRAMEWORK_ROOT/bin:\$PATH\""
        fi
    else
        echo -e "  ${GREEN}OK${NC}  fw already in PATH ($(which fw))"
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

    if [ -f "$config_file" ] && [ "${force:-false}" != true ]; then
        echo -e "  ${YELLOW}SKIP${NC}  CLAUDE.md already exists (use --force to overwrite)"
        return
    fi

    local project_name
    project_name=$(basename "$dir")

    local template_file="$FRAMEWORK_ROOT/lib/templates/claude-project.md"

    if [ -f "$template_file" ]; then
        # Use comprehensive template with placeholder substitution
        sed \
            -e "s|__PROJECT_NAME__|$project_name|g" \
            -e "s|__FRAMEWORK_ROOT__|$FRAMEWORK_ROOT|g" \
            "$template_file" > "$config_file"
    else
        # Fallback: inline minimal CLAUDE.md if template missing
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
    fi
}

generate_claude_code_config() {
    local dir="$1"

    # --- .claude/settings.json (PostToolUse hook for context protection) ---
    mkdir -p "$dir/.claude/commands"

    if [ ! -f "$dir/.claude/settings.json" ] || [ "${force:-false}" = true ]; then
        cat > "$dir/.claude/settings.json" << 'SJSON'
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "PROJECT_ROOT=__PROJECT_ROOT__ __FRAMEWORK_ROOT__/agents/context/check-active-task.sh"
          }
        ]
      },
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "PROJECT_ROOT=__PROJECT_ROOT__ __FRAMEWORK_ROOT__/agents/context/check-tier0.sh"
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "PROJECT_ROOT=__PROJECT_ROOT__ __FRAMEWORK_ROOT__/agents/context/checkpoint.sh post-tool"
          }
        ]
      }
    ]
  }
}
SJSON
        # Replace placeholders with actual paths
        sed -i "s|__FRAMEWORK_ROOT__|$FRAMEWORK_ROOT|g" "$dir/.claude/settings.json"
        sed -i "s|__PROJECT_ROOT__|$dir|g" "$dir/.claude/settings.json"
        echo -e "  ${GREEN}OK${NC}  .claude/settings.json (Tier 0 + Tier 1 + checkpoint hooks)"
    else
        echo -e "  ${YELLOW}SKIP${NC}  .claude/settings.json already exists"
    fi

    # --- .claude/commands/resume.md (project-specific /resume) ---
    if [ ! -f "$dir/.claude/commands/resume.md" ] || [ "${force:-false}" = true ]; then
        cat > "$dir/.claude/commands/resume.md" << 'RESUME'
# /resume - Context Recovery for Agentic Engineering Framework

When the user says `/resume`, "pick up", or "continue", execute this workflow.

## Step 1: Gather State

Run these in parallel:

1. Read `.context/handovers/LATEST.md`
2. Run `git status --short` and `git log --oneline -5`
3. List `.tasks/active/` and extract task IDs, names, and statuses from frontmatter
4. Check tool counter: `cat .context/working/.tool-counter`
5. Check web server: `curl -sf http://localhost:3000/ > /dev/null && echo "running" || echo "stopped"`

## Step 2: Summarize

Present this format (fill from gathered data):

```
## Context Restored

**Last Handover:** {session_id} ({timestamp})
**Last Commit:** {hash} - {message}
**Branch:** {branch}

### Where We Are
{paste the "Where We Are" section from LATEST.md}

### Active Tasks
- {T-XXX}: {name} ({status})

### Current State
- Git: {clean/N uncommitted files}
- Web UI: {running on :3000 / stopped}
- Tool counter: {N} (P-009)

### Suggested Action
{paste from LATEST.md "Suggested First Action" section}
```

## Step 3: Offer Next Steps

List the logical next actions as plain text (numbered). Derive from:
- The handover's "Suggested First Action"
- Any tasks with status `started-work`
- Uncommitted changes that need attention

Then ask: "What would you like to work on?"

## Rules

- Do NOT use AskUserQuestion (may be blocked in dontAsk mode) — use plain text
- Keep output concise — no commentary
- If LATEST.md has unfilled `[TODO]` sections, warn about stale handover
- If tool counter > 0 at session start, the PostToolUse hook is working
RESUME
        echo -e "  ${GREEN}OK${NC}  .claude/commands/resume.md"
    else
        echo -e "  ${YELLOW}SKIP${NC}  .claude/commands/resume.md already exists"
    fi
}

generate_cursorrules() {
    local dir="$1"
    local config_file="$dir/.cursorrules"

    if [ -f "$config_file" ] && [ "${force:-false}" != true ]; then
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
