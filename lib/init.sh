#!/bin/bash
# fw init - Bootstrap a new project with the Agentic Engineering Framework
#
# Creates the directory structure, config files, and git hooks needed
# for a project to use the framework.

do_init() {
    local target_dir=""
    local provider="generic"
    local force=false
    # shellcheck disable=SC2034  # reserved for future use
    local first_run=true

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        # shellcheck disable=SC2034
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

    # --- Git init if needed (T-521: hooks and traceability require git) ---
    if ! git -C "$target_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        echo -e "  ${GREEN}✓${NC}  Initializing git repository"
        git init -q "$target_dir"
    fi

    # --- Git identity inheritance (T-880/F4: inherit from global if not set) ---
    if ! git -C "$target_dir" config user.email >/dev/null 2>&1; then
        local global_email
        global_email=$(git config --global user.email 2>/dev/null || true)
        if [ -n "$global_email" ]; then
            local global_name
            global_name=$(git config --global user.name 2>/dev/null || echo "Developer")
            git -C "$target_dir" config user.email "$global_email"
            git -C "$target_dir" config user.name "$global_name"
            echo -e "  ${GREEN}✓${NC}  Git identity inherited from global config ($global_email)"
        else
            echo -e "  ${YELLOW}⚠${NC}   Git identity not configured (commits will fail)"
            echo "       git config user.email 'you@example.com' && git config user.name 'Your Name'"
        fi
    fi

    # --- Vendor framework (T-498: full project isolation) ---
    if [ ! -d "$target_dir/.agentic-framework" ] || [ "${force:-false}" = true ]; then
        echo -e "${BOLD}Vendoring framework into project...${NC}"
        do_vendor --target "$target_dir"
        echo ""
    else
        echo -e "  ${YELLOW}SKIP${NC}  .agentic-framework/ already exists (use --force to re-vendor)"
    fi

    # --- Create directory structure ---
    #@init: dir-4mf .tasks/active
    # Active tasks directory
    mkdir -p "$target_dir/.tasks/active"
    #@init: dir-7hn .tasks/completed
    # Completed tasks archive
    mkdir -p "$target_dir/.tasks/completed"
    #@init: dir-2pw .tasks/templates
    # Task templates
    mkdir -p "$target_dir/.tasks/templates"
    #@init: dir-9kc .context/working
    # Working memory (session state)
    mkdir -p "$target_dir/.context/working"
    #@init: dir-3xe .context/project
    # Project memory (patterns, decisions, learnings)
    mkdir -p "$target_dir/.context/project"
    #@init: dir-6ja .context/episodic
    # Episodic memory (task histories)
    mkdir -p "$target_dir/.context/episodic"
    #@init: dir-1rv .context/handovers
    # Session handover documents
    mkdir -p "$target_dir/.context/handovers"
    #@init: dir-8qb .context/scans
    # Codebase scan results
    mkdir -p "$target_dir/.context/scans"
    #@init: dir-5wd .context/bus/results
    # Sub-agent result bus
    mkdir -p "$target_dir/.context/bus/results"
    #@init: dir-0tg .context/bus/blobs
    # Sub-agent blob storage
    mkdir -p "$target_dir/.context/bus/blobs"
    #@init: dir-3yn .context/audits/cron
    # Cron audit results
    mkdir -p "$target_dir/.context/audits/cron"
    #@init: dir-7cr .context/cron
    # Git-tracked cron definitions
    mkdir -p "$target_dir/.context/cron"

    #@init: yaml-8cr .context/cron-registry.yaml jobs
    # Cron registry — structured source of truth for scheduled jobs (T-448)
    if [ ! -f "$target_dir/.context/cron-registry.yaml" ]; then
        cat > "$target_dir/.context/cron-registry.yaml" << 'CRONREGEOF'
# Cron Registry — Structured source of truth for scheduled jobs (T-448)
# Read by web/blueprints/cron.py and fw cron generate.
# Editable by humans, controllable via Watchtower web UI.
jobs: []
CRONREGEOF
    fi

    #@init: yaml-5rc .context/bypass-log.yaml bypasses
    # Git hook bypass log
    if [ ! -f "$target_dir/.context/bypass-log.yaml" ]; then
        cat > "$target_dir/.context/bypass-log.yaml" << 'BYPASSEOF'
# Git hook bypass log
# Entries auto-added by post-commit hook when --no-verify is detected
bypasses: []
BYPASSEOF
    fi

    #@init: file-2nb .context/working/.gitignore
    # Volatile file exclusions
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
    #@init: file-8cz .tasks/templates/default.md
    # Default task template
    local template_count=0
    for tmpl in "$FRAMEWORK_ROOT/.tasks/templates/"*.md; do
        [ -f "$tmpl" ] || continue
        cp "$tmpl" "$target_dir/.tasks/templates/$(basename "$tmpl")"
        template_count=$((template_count + 1))
    done
    if [ "$template_count" -eq 0 ]; then
        echo -e "  ${YELLOW}⚠${NC}   No task templates found"
    fi

    #@init: yaml-8kj .framework.yaml project_name,version,provider
    # Project configuration
    local project_name
    project_name=$(basename "$target_dir")
    local init_timestamp
    init_timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # Auto-detect upstream repo from framework's git remotes
    # T-575: Accept any git remote, not just GitHub
    local upstream_repo=""
    if [ -d "$FRAMEWORK_ROOT/.git" ]; then
        local remote_url
        remote_url=$(git -C "$FRAMEWORK_ROOT" remote get-url origin 2>/dev/null) || true
        # If no origin, try first available push remote
        if [ -z "$remote_url" ]; then
            remote_url=$(git -C "$FRAMEWORK_ROOT" remote -v 2>/dev/null | grep "(push)" | head -1 | awk '{print $2}') || true
        fi
        if [ -n "$remote_url" ]; then
            # GitHub URLs: extract owner/repo for compact display
            if echo "$remote_url" | grep -q "github.com"; then
                upstream_repo=$(echo "$remote_url" | sed -E 's|.*github\.com[:/]||;s|\.git$||')
            else
                # Non-GitHub: store full URL (OneDev, GitLab, Gitea, etc.)
                upstream_repo="${remote_url%.git}"
            fi
        fi
    fi

    cat > "$target_dir/.framework.yaml" << FYAML
# Agentic Engineering Framework - Project Configuration
# framework_path removed (T-498) — fw resolves from .agentic-framework/bin/fw location
project_name: $project_name
version: $FW_VERSION
provider: $provider
initialized_at: $init_timestamp
${upstream_repo:+upstream_repo: $upstream_repo}
FYAML
    # .framework.yaml created

    # --- Seed governance files ---

    #@init: yaml-7dg .context/project/practices.yaml practices
    # Graduated practices
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

    #@init: yaml-4fs .context/project/decisions.yaml decisions
    # Architectural decisions
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

    #@init: yaml-1qm .context/project/patterns.yaml failure_patterns
    # Failure/success/workflow patterns
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

    #@init: yaml-6wt .context/project/learnings.yaml learnings
    # Project learnings
    if [ ! -f "$target_dir/.context/project/learnings.yaml" ] || [ "${force:-false}" = true ]; then
        cat > "$target_dir/.context/project/learnings.yaml" << 'LYAML'
# Project Learnings - Knowledge gained during development
# Added via: fw context add-learning "description" --task T-XXX
learnings:
LYAML
    fi

    #@init: yaml-9he .context/project/assumptions.yaml assumptions
    # Tracked assumptions
    if [ ! -f "$target_dir/.context/project/assumptions.yaml" ] || [ "${force:-false}" = true ]; then
        cat > "$target_dir/.context/project/assumptions.yaml" << 'AYAML'
# Project Assumptions - Tracked via inception workflow
# Added via: fw assumption add "description" --task T-XXX
# Validated via: fw assumption validate A-XXX --evidence "..."
assumptions: []
AYAML
    fi

    #@init: yaml-3bp .context/project/directives.yaml directives
    # Constitutional directives
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

    #@init: yaml-0vk .context/project/concerns.yaml concerns
    # Unified concerns register (T-397: gaps + risks)
    if [ ! -f "$target_dir/.context/project/concerns.yaml" ] || [ "${force:-false}" = true ]; then
        cat > "$target_dir/.context/project/concerns.yaml" << 'CYAML'
# Concerns Register — Unified gap and risk tracking (T-397)
# Type: gap (spec-reality) | risk (forward-looking)
# Status: watching | decided-build | decided-simplify | decided-defer | closed
concerns: []
CYAML
    fi

    echo -e "  ${GREEN}✓${NC}  Seeded: 10 practices, 18 decisions, 12 patterns"
    echo -e "  ${GREEN}✓${NC}  Initialized: learnings, assumptions, directives, gaps"

    # --- Generate provider config ---
    case "$provider" in
        claude)
            #@init: file-7xr CLAUDE.md ?claude,generic
            # Agent instruction file
            generate_claude_md "$target_dir" >/dev/null
            #@init: json-3fz .claude/settings.json hooks ?claude,generic
            # Claude Code hooks configuration
            #@init: hookpaths-6vc .claude/settings.json ?claude,generic
            # Hook script paths all resolve
            #@init: file-4ej .claude/commands/resume.md ?claude,generic
            # Resume slash command
            generate_claude_code_config "$target_dir" >/dev/null
            echo -e "  ${GREEN}✓${NC}  CLAUDE.md generated"
            echo -e "  ${GREEN}✓${NC}  Claude Code hooks (10 configured)"
            ;;
        cursor)
            #@init: file-6qs .cursorrules ?cursor
            # Cursor rules file
            generate_cursorrules "$target_dir" >/dev/null
            echo -e "  ${GREEN}✓${NC}  .cursorrules generated"
            ;;
        generic)
            # Tags declared in claude branch with ?claude,generic condition
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

    # --- Git hooks (T-880/F3: auto-install for commit traceability) ---
    local git_sh="$target_dir/.agentic-framework/agents/git/git.sh"
    if [ -x "$git_sh" ]; then
        if PROJECT_ROOT="$target_dir" "$git_sh" install-hooks 2>/dev/null; then
            echo -e "  ${GREEN}✓${NC}  Git hooks installed (commit traceability active)"
        else
            echo -e "  ${YELLOW}⚠${NC}   Git hooks install failed — run 'fw git install-hooks' manually"
        fi
    fi

    # --- Enforcement baseline (T-880/F5: auto-create for drift detection) ---
    if [ ! -f "$target_dir/.context/project/enforcement-baseline.sha256" ]; then
        local fw_bin="$target_dir/.agentic-framework/bin/fw"
        if [ -x "$fw_bin" ] && [ -f "$target_dir/.claude/settings.json" ]; then
            if PROJECT_ROOT="$target_dir" "$fw_bin" enforcement baseline >/dev/null 2>&1; then
                echo -e "  ${GREEN}✓${NC}  Enforcement baseline created"
            fi
        fi
    fi

    # --- Post-init validation (T-461: Tier 1 structural + Tier 2 functional) ---
    echo ""
    echo -e "${BOLD}Validating...${NC}"
    source "$FW_LIB_DIR/validate-init.sh" 2>/dev/null || \
        source "$(dirname "${BASH_SOURCE[0]}")/validate-init.sh" 2>/dev/null || true
    if type do_validate_init >/dev/null 2>&1; then
        if ! do_validate_init "$target_dir" --provider "$provider"; then
            echo ""
            echo -e "${YELLOW}Init completed with validation errors — check output above${NC}"
        fi
    fi

    # --- Activate governance: initialize session context (T-002) ---
    echo ""
    echo -e "Activating governance..."
    local context_init_script="$FRAMEWORK_ROOT/agents/context/context.sh"
    if [ -x "$context_init_script" ]; then
        PROJECT_ROOT="$target_dir" "$context_init_script" init 2>/dev/null && \
            echo -e "  ${GREEN}✓${NC}  Session initialized (governance active)" || \
            echo -e "  ${YELLOW}⚠${NC}  Session init failed — run 'fw context init' manually"
    fi

    # --- Copy onboarding task templates (T-460) ---
    local has_existing_tasks=false
    local has_code=false

    # Skip if tasks already exist (idempotent on --force re-init)
    if [ -d "$target_dir/.tasks/active" ] && ls "$target_dir/.tasks/active/"T-*.md >/dev/null 2>&1; then
        has_existing_tasks=true
    fi

    if [ "$has_existing_tasks" = false ]; then
        # Detect if project has existing code
        for manifest in package.json requirements.txt pyproject.toml go.mod Cargo.toml pom.xml setup.py; do
            if [ -f "$target_dir/$manifest" ]; then
                has_code=true
                break
            fi
        done
        if [ "$has_code" = false ]; then
            for codedir in src lib app; do
                if [ -d "$target_dir/$codedir" ]; then
                    has_code=true
                    break
                fi
            done
        fi

        local seed_dir
        if [ "$has_code" = true ]; then
            seed_dir="$FRAMEWORK_ROOT/lib/seeds/tasks/existing-project"
        else
            seed_dir="$FRAMEWORK_ROOT/lib/seeds/tasks/greenfield"
        fi

        if [ -d "$seed_dir" ]; then
            local task_count=0
            local init_date
            init_date=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
            for tmpl in "$seed_dir"/T-*.md; do
                [ -f "$tmpl" ] || continue
                local dest
                dest="$target_dir/.tasks/active/$(basename "$tmpl")"
                sed \
                    -e "s|__PROJECT_NAME__|$project_display|g" \
                    -e "s|__DATE__|$init_date|g" \
                    "$tmpl" > "$dest"
                task_count=$((task_count + 1))
            done
            if [ "$task_count" -gt 0 ]; then
                local mode_label="existing project"
                [ "$has_code" = false ] && mode_label="greenfield"
                echo -e "  ${GREEN}✓${NC}  $task_count onboarding tasks ($mode_label mode)"
            fi
        fi
    fi

    # --- Done ---
    echo ""
    echo -e "${GREEN}Done!${NC} Governance is active."
    echo ""
    echo -e "  ${BOLD}Next step:${NC} Start your AI agent (e.g. Claude Code) in this directory."
    if [ "$has_existing_tasks" = false ] && [ -d "$target_dir/.tasks/active" ] && ls "$target_dir/.tasks/active/"T-*.md >/dev/null 2>&1; then
        local onboard_count
        onboard_count=$(ls "$target_dir/.tasks/active/"T-*.md 2>/dev/null | wc -l)
        echo -e "  Onboarding tasks are ready — ${BOLD}$onboard_count tasks${NC} will guide you through setup."
    fi
    echo ""
    echo -e "  ${BOLD}Dashboard${NC}: fw serve"
    echo -e "  ${BOLD}All commands${NC}: fw help"
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
        # T-572: removed __FRAMEWORK_ROOT__ substitution (G-021 path isolation — no absolute paths in committed files)
        sed \
            -e "s|__PROJECT_NAME__|$project_name|g" \
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

    # T-663/T-662: Detect framework-mode vs consumer-mode for fw path
    # T-1364 (G-053-A): Emit ABSOLUTE paths — Claude Code resolves hook commands
    # against CWD, and CWD drift (test fixtures, subdir navigation) otherwise
    # cascades into hook-cannot-find-fw tool-blocks. $dir is canonicalized by
    # the caller (init.sh line 58, upgrade.sh line 58 via `cd && pwd`).
    local fw_prefix="$dir/.agentic-framework/bin/fw"
    if [ -x "$dir/bin/fw" ] && [ -f "$dir/FRAMEWORK.md" ]; then
        fw_prefix="$dir/bin/fw"
    fi

    if [ ! -f "$dir/.claude/settings.json" ] || [ "${force:-false}" = true ]; then
        # Use unquoted heredoc so $fw_prefix expands (T-663: framework-aware hook paths)
        cat > "$dir/.claude/settings.json" << SJSON
{
  "hooks": {
    "PreCompact": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "$fw_prefix hook pre-compact"
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
            "command": "$fw_prefix hook post-compact-resume"
          }
        ]
      },
      {
        "matcher": "resume",
        "hooks": [
          {
            "type": "command",
            "command": "$fw_prefix hook post-compact-resume"
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
            "command": "$fw_prefix hook block-plan-mode"
          }
        ]
      },
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "$fw_prefix hook check-active-task"
          }
        ]
      },
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "$fw_prefix hook check-tier0"
          }
        ]
      },
      {
        "matcher": "Agent",
        "hooks": [
          {
            "type": "command",
            "command": "$fw_prefix hook check-agent-dispatch"
          }
        ]
      },
      {
        "matcher": "Write|Edit|Bash",
        "hooks": [
          {
            "type": "command",
            "command": "$fw_prefix hook check-project-boundary"
          }
        ]
      },
      {
        "matcher": "Write|Edit|Bash",
        "hooks": [
          {
            "type": "command",
            "command": "$fw_prefix hook budget-gate"
          }
        ]
      },
      {
        "matcher": "TodoWrite|TaskCreate|TaskUpdate|TaskList|TaskGet",
        "hooks": [
          {
            "type": "command",
            "command": "$fw_prefix hook block-task-tools"
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
            "command": "$fw_prefix hook checkpoint post-tool"
          }
        ]
      },
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "$fw_prefix hook error-watchdog"
          }
        ]
      },
      {
        "matcher": "Task|TaskOutput",
        "hooks": [
          {
            "type": "command",
            "command": "$fw_prefix hook check-dispatch"
          }
        ]
      },
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "$fw_prefix hook loop-detect"
          }
        ]
      },
      {
        "matcher": "Write",
        "hooks": [
          {
            "type": "command",
            "command": "$fw_prefix hook check-fabric-new-file"
          }
        ]
      },
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "$fw_prefix hook commit-cadence"
          }
        ]
      },
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "$fw_prefix hook audit-task-tools"
          }
        ]
      }
    ]
  }
}
SJSON
        echo -e "  ${GREEN}OK${NC}  .claude/settings.json (all hooks: task gate, tier0, budget, plan blocker, agent dispatch, compact, resume, checkpoint, error-watchdog, dispatch guard, loop-detect, fabric new-file, project-boundary, commit-cadence)"
    else
        # T-677: Pre-existing settings.json — back up and overwrite with framework hooks
        # The framework's governance hooks are authoritative; project-specific hooks from
        # other systems (vnx, etc.) are not compatible and reference non-local paths.
        cp "$dir/.claude/settings.json" "$dir/.claude/settings.json.pre-fw"
        local save_force="${force:-false}"
        force=true
        generate_claude_code_config "$dir"
        force="$save_force"
        echo -e "  ${GREEN}REPLACED${NC}  .claude/settings.json — framework hooks applied (original backed up to settings.json.pre-fw)"
    fi

    # --- .mcp.json (MCP server configuration for Claude Code) ---
    if [ ! -f "$dir/.mcp.json" ] || [ "${force:-false}" = true ]; then
        cat > "$dir/.mcp.json" << 'MCPJSON'
{
  "mcpServers": {
    "context7": {
      "command": "npx",
      "args": ["-y", "@upstash/context7-mcp"]
    },
    "playwright": {
      "command": "npx",
      "args": ["@playwright/mcp@latest", "--no-sandbox"]
    },
    "termlink": {
      "command": "termlink",
      "args": ["mcp", "serve"]
    }
  }
}
MCPJSON
        echo -e "  ${GREEN}OK${NC}  .mcp.json (MCP servers: context7, playwright, termlink)"
    else
        echo -e "  ${YELLOW}SKIP${NC}  .mcp.json already exists"
    fi

    # --- .claude/commands/resume.md (project-specific /resume) ---
    # T-1383 (closes G-056): prefer shared template at lib/templates/resume-md.md
    # so upgrade.sh can detect drift and refresh existing consumers.
    local resume_tmpl="$FRAMEWORK_ROOT/lib/templates/resume-md.md"
    if [ ! -f "$dir/.claude/commands/resume.md" ] || [ "${force:-false}" = true ]; then
        if [ -f "$resume_tmpl" ]; then
            cp "$resume_tmpl" "$dir/.claude/commands/resume.md"
            echo -e "  ${GREEN}OK${NC}  .claude/commands/resume.md"
        else
        cat > "$dir/.claude/commands/resume.md" << 'RESUME'
# /resume - Context Recovery for Agentic Engineering Framework

When the user says `/resume`, "pick up", or "continue", execute this workflow.

## Step 1: Gather State

Run these in parallel:

1. Read `.context/handovers/LATEST.md`
2. Run `git status --short` and `git log --oneline -5`
3. List `.tasks/active/` and extract task IDs, names, and statuses from frontmatter
4. Check tool counter: `cat .context/working/.tool-counter`
5. Check web server: `WURL=$(cat .context/working/watchtower.url 2>/dev/null || echo "http://localhost:$(bin/fw config get PORT 2>/dev/null || echo 3000)"); curl -sf "$WURL/" > /dev/null && echo "running at $WURL" || echo "stopped"`
   (Never hard-code `:3000` — the triple file `.context/working/watchtower.{pid,port,url}` is the single source of truth for Watchtower's current port. See `bin/fw doctor` for diagnostics.)

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
- Web UI: {running at {URL from .context/working/watchtower.url} / stopped}
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
        fi
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
