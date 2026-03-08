#!/bin/bash
# fw init - Bootstrap a new project with the Agentic Engineering Framework
#
# Creates the directory structure, config files, and git hooks needed
# for a project to use the framework.

do_init() {
    local target_dir=""
    local provider="generic"
    local force=false
    local first_run=true

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --provider) provider="$2"; shift 2 ;;
            --force) force=true; shift ;;
            --no-first-run) first_run=false; shift ;;
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
                echo "  --no-first-run    Skip guided walkthrough after init"
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

    local project_display
    project_display=$(basename "$target_dir")
    echo -e "${BOLD}Setting up agentic governance for ${project_display}...${NC}"
    echo ""

    # --- Preflight check (T-303) — quiet mode, only fails on missing required deps ---
    source "$FW_LIB_DIR/preflight.sh" 2>/dev/null || source "$(dirname "${BASH_SOURCE[0]}")/preflight.sh" 2>/dev/null || true
    if type do_preflight >/dev/null 2>&1; then
        if ! do_preflight --quiet; then
            echo ""
            echo -e "${RED}Preflight failed. Run 'fw preflight' for details.${NC}"
            return 1
        fi
    fi

    # --- Create directory structure ---
    mkdir -p "$target_dir/.tasks/active"
    mkdir -p "$target_dir/.tasks/completed"
    mkdir -p "$target_dir/.tasks/templates"
    mkdir -p "$target_dir/.context/working"
    mkdir -p "$target_dir/.context/project"
    mkdir -p "$target_dir/.context/episodic"
    mkdir -p "$target_dir/.context/handovers"
    mkdir -p "$target_dir/.context/scans"
    mkdir -p "$target_dir/.context/bus/results"
    mkdir -p "$target_dir/.context/bus/blobs"
    mkdir -p "$target_dir/.context/audits/cron"

    # Create bypass-log.yaml if missing (T-302: prevents CTL-010 day-1 warning)
    if [ ! -f "$target_dir/.context/bypass-log.yaml" ]; then
        cat > "$target_dir/.context/bypass-log.yaml" << 'BYPASSEOF'
# Git hook bypass log
# Entries auto-added by post-commit hook when --no-verify is detected
bypasses: []
BYPASSEOF
    fi

    # .gitignore for volatile working memory files
    cat > "$target_dir/.context/working/.gitignore" << 'WGIT'
# Volatile session files — regenerated each session
.tool-counter
.prev-token-reading
session.yaml
focus.yaml
tier0-approval
WGIT

    echo -e "  ${GREEN}✓${NC}  Task system (.tasks/)"
    echo -e "  ${GREEN}✓${NC}  Context fabric (.context/)"

    # --- Copy task templates (all .md files from framework templates) ---
    local template_count=0
    for tmpl in "$FRAMEWORK_ROOT/.tasks/templates/"*.md; do
        [ -f "$tmpl" ] || continue
        cp "$tmpl" "$target_dir/.tasks/templates/$(basename "$tmpl")"
        template_count=$((template_count + 1))
    done
    if [ "$template_count" -eq 0 ]; then
        echo -e "  ${YELLOW}⚠${NC}   No task templates found"
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
    # .framework.yaml created

    # --- Seed governance files ---

    if [ ! -f "$target_dir/.context/project/practices.yaml" ] || [ "${force:-false}" = true ]; then
        if [ -f "$FRAMEWORK_ROOT/lib/seeds/practices.yaml" ]; then
            cp "$FRAMEWORK_ROOT/lib/seeds/practices.yaml" "$target_dir/.context/project/practices.yaml"
        else
            cat > "$target_dir/.context/project/practices.yaml" << 'PRAML'
# Project Practices - Graduated learnings (3+ applications)
# Promoted via: fw promote L-XXX --name "practice name" --directive D1
practices: []
PRAML
        fi
    fi

    if [ ! -f "$target_dir/.context/project/decisions.yaml" ] || [ "${force:-false}" = true ]; then
        if [ -f "$FRAMEWORK_ROOT/lib/seeds/decisions.yaml" ]; then
            cp "$FRAMEWORK_ROOT/lib/seeds/decisions.yaml" "$target_dir/.context/project/decisions.yaml"
        else
            cat > "$target_dir/.context/project/decisions.yaml" << 'DYAML'
# Project Decisions - Architectural choices with rationale
# Added via: fw context add-decision "description" --task T-XXX --rationale "why"
decisions:
DYAML
        fi
    fi

    if [ ! -f "$target_dir/.context/project/patterns.yaml" ] || [ "${force:-false}" = true ]; then
        if [ -f "$FRAMEWORK_ROOT/lib/seeds/patterns.yaml" ]; then
            cp "$FRAMEWORK_ROOT/lib/seeds/patterns.yaml" "$target_dir/.context/project/patterns.yaml"
        else
            cat > "$target_dir/.context/project/patterns.yaml" << 'PYAML'
# Project Patterns - Learned from experience
# Categories: failure, success, workflow
# Added via: fw context add-pattern <type> "name" --task T-XXX
failure_patterns: []
success_patterns: []
workflow_patterns: []
PYAML
        fi
    fi

    if [ ! -f "$target_dir/.context/project/learnings.yaml" ] || [ "${force:-false}" = true ]; then
        cat > "$target_dir/.context/project/learnings.yaml" << 'LYAML'
# Project Learnings - Knowledge gained during development
# Added via: fw context add-learning "description" --task T-XXX
learnings:
LYAML
    fi

    if [ ! -f "$target_dir/.context/project/assumptions.yaml" ] || [ "${force:-false}" = true ]; then
        cat > "$target_dir/.context/project/assumptions.yaml" << 'AYAML'
# Project Assumptions - Tracked via inception workflow
# Added via: fw assumption add "description" --task T-XXX
# Validated via: fw assumption validate A-XXX --evidence "..."
assumptions: []
AYAML
    fi

    if [ ! -f "$target_dir/.context/project/directives.yaml" ] || [ "${force:-false}" = true ]; then
        cat > "$target_dir/.context/project/directives.yaml" << 'DRYAML'
# Project Directives - Constitutional principles (priority order)
# These are stable anchors — changes require human sovereignty approval

directives:
  - id: D1
    name: "Antifragility"
    statement: "The system must get stronger under stress, not merely survive it."
    priority: 1

  - id: D2
    name: "Reliability"
    statement: "The system must behave predictably and consistently under known conditions."
    priority: 2

  - id: D3
    name: "Usability"
    statement: "The framework must be a joy to use, extend, and debug."
    priority: 3

  - id: D4
    name: "Portability"
    statement: "The framework must not be captive to any single provider, language, or environment."
    priority: 4
DRYAML
    fi

    if [ ! -f "$target_dir/.context/project/gaps.yaml" ] || [ "${force:-false}" = true ]; then
        cat > "$target_dir/.context/project/gaps.yaml" << 'GYAML'
# Gaps Register — Spec-Reality gaps with decision triggers
# Status: watching | decided-build | decided-simplify | decided-defer | closed
gaps: []
GYAML
    fi

    echo -e "  ${GREEN}✓${NC}  Seeded: 10 practices, 18 decisions, 12 patterns"
    echo -e "  ${GREEN}✓${NC}  Initialized: learnings, assumptions, directives, gaps"

    # --- Generate provider config ---
    case "$provider" in
        claude)
            generate_claude_md "$target_dir" >/dev/null
            generate_claude_code_config "$target_dir" >/dev/null
            echo -e "  ${GREEN}✓${NC}  CLAUDE.md generated"
            echo -e "  ${GREEN}✓${NC}  Claude Code hooks (10 configured)"
            ;;
        cursor)
            generate_cursorrules "$target_dir" >/dev/null
            echo -e "  ${GREEN}✓${NC}  .cursorrules generated"
            ;;
        generic)
            generate_claude_md "$target_dir" >/dev/null
            generate_claude_code_config "$target_dir" >/dev/null
            echo -e "  ${GREEN}✓${NC}  CLAUDE.md generated"
            echo -e "  ${GREEN}✓${NC}  Claude Code hooks (10 configured)"
            ;;
        *)
            echo -e "  ${YELLOW}⚠${NC}   Unknown provider '$provider', using generic"
            generate_claude_md "$target_dir" >/dev/null
            generate_claude_code_config "$target_dir" >/dev/null
            ;;
    esac

    # --- Install git hooks (if git repo) ---
    if [ -d "$target_dir/.git" ]; then
        PROJECT_ROOT="$target_dir" "$FRAMEWORK_ROOT/agents/git/git.sh" install-hooks >/dev/null 2>&1 && \
            echo -e "  ${GREEN}✓${NC}  Git hooks installed" || \
            echo -e "  ${YELLOW}⚠${NC}   Git hook install failed (run: fw git install-hooks)"
    else
        echo -e "  ${YELLOW}⚠${NC}   Not a git repo — run ${BOLD}git init${NC} first for full traceability"
    fi

    # --- Ensure fw is in PATH (silent unless action needed) ---
    if ! command -v fw >/dev/null 2>&1; then
        if [ -w /usr/local/bin ]; then
            ln -sf "$FRAMEWORK_ROOT/bin/fw" /usr/local/bin/fw
            echo -e "  ${GREEN}✓${NC}  fw added to PATH"
        else
            echo -e "  ${YELLOW}⚠${NC}   Add fw to PATH: export PATH=\"$FRAMEWORK_ROOT/bin:\$PATH\""
        fi
    fi

    # --- Done ---
    echo ""
    echo -e "${GREEN}Done!${NC} Start working:"
    echo -e "  ${BOLD}fw work-on \"your first task\" --type build${NC}"
    echo ""
    echo -e "All commands: ${BOLD}fw help${NC}"
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
        cat > "$dir/.claude/settings.json" << SJSON
{
  "hooks": {
    "PreCompact": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "PROJECT_ROOT=$dir $FRAMEWORK_ROOT/agents/context/pre-compact.sh"
          }
        ]
      }
    ],
    "SessionStart": [
      {
        "matcher": "compact",
        "hooks": [
          {
            "type": "command",
            "command": "PROJECT_ROOT=$dir $FRAMEWORK_ROOT/agents/context/post-compact-resume.sh"
          }
        ]
      },
      {
        "matcher": "resume",
        "hooks": [
          {
            "type": "command",
            "command": "PROJECT_ROOT=$dir $FRAMEWORK_ROOT/agents/context/post-compact-resume.sh"
          }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "EnterPlanMode",
        "hooks": [
          {
            "type": "command",
            "command": "$FRAMEWORK_ROOT/agents/context/block-plan-mode.sh"
          }
        ]
      },
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "PROJECT_ROOT=$dir $FRAMEWORK_ROOT/agents/context/check-active-task.sh"
          }
        ]
      },
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "PROJECT_ROOT=$dir $FRAMEWORK_ROOT/agents/context/check-tier0.sh"
          }
        ]
      },
      {
        "matcher": "Write|Edit|Bash",
        "hooks": [
          {
            "type": "command",
            "command": "PROJECT_ROOT=$dir $FRAMEWORK_ROOT/agents/context/budget-gate.sh"
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
            "command": "PROJECT_ROOT=$dir $FRAMEWORK_ROOT/agents/context/checkpoint.sh post-tool"
          }
        ]
      },
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "$FRAMEWORK_ROOT/agents/context/error-watchdog.sh"
          }
        ]
      },
      {
        "matcher": "Task|TaskOutput",
        "hooks": [
          {
            "type": "command",
            "command": "$FRAMEWORK_ROOT/agents/context/check-dispatch.sh"
          }
        ]
      }
    ]
  }
}
SJSON
        echo -e "  ${GREEN}OK${NC}  .claude/settings.json (all 10 hooks: task gate, tier0, budget, plan blocker, compact, resume, checkpoint, error-watchdog, dispatch guard)"
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
