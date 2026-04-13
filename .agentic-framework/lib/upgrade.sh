#!/bin/bash
# fw upgrade - Sync framework improvements to a consumer project
#
# Runs in a consumer project directory, reads .framework.yaml to find the
# framework, then updates governance sections, templates, hooks, and seeds.
# Project-specific content is preserved.

do_upgrade() {
    local target_dir=""
    local dry_run=false
    local force=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run) dry_run=true; shift ;;
            --force) force=true; shift ;;
            -h|--help)
                echo -e "${BOLD}fw upgrade${NC} - Sync framework improvements to consumer project"
                echo ""
                echo "Usage: fw upgrade [target-dir] [options]"
                echo ""
                echo "Arguments:"
                echo "  target-dir        Project to upgrade (default: current directory)"
                echo ""
                echo "Options:"
                echo "  --dry-run         Show what would change without modifying files"
                echo "  --force           Overwrite even if project files are newer"
                echo "  -h, --help        Show this help"
                echo ""
                echo "What gets upgraded:"
                echo "  - CLAUDE.md governance sections (project-specific sections preserved)"
                echo "  - Task templates"
                echo "  - Seed files (practices, decisions, patterns — universal items only)"
                echo "  - Git hooks"
                echo "  - .claude/settings.json (hook config)"
                echo "  - .claude/commands/resume.md"
                echo "  - lib/*.sh (fw subcommands: inception, upgrade, init, etc.)"
                echo "  - Agent scripts (task-create, handover, git, healing, fabric, etc.)"
                echo "  - bin/fw (CLI entry point)"
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

    # Default to PROJECT_ROOT or current directory
    if [ -z "$target_dir" ]; then
        target_dir="${PROJECT_ROOT:-$PWD}"
    fi

    # Resolve to absolute path
    target_dir="$(cd "$target_dir" 2>/dev/null && pwd)" || {
        echo -e "${RED}ERROR: Directory does not exist: $target_dir${NC}" >&2
        return 1
    }

    # Must have .framework.yaml
    if [ ! -f "$target_dir/.framework.yaml" ]; then
        echo -e "${RED}ERROR: Not a framework project — no .framework.yaml found in $target_dir${NC}" >&2
        echo "Run 'fw init $target_dir' first."
        return 1
    fi

    # Don't upgrade the framework itself
    if [ "$target_dir" = "$FRAMEWORK_ROOT" ]; then
        echo -e "${RED}ERROR: Cannot upgrade the framework project itself${NC}" >&2
        return 1
    fi

    # T-1217: Self-vendor — refresh framework's own .agentic-framework/ before pushing to consumers.
    # Without this, new lib/*.sh files (e.g., watchtower.sh from T-1154) go stale in the vendored
    # copy, causing pre-push audit errors for the framework repo itself.
    local _self_vendor="$FRAMEWORK_ROOT/.agentic-framework"
    if [ -d "$_self_vendor/lib" ]; then
        local _sv_updated=0
        for _sv_src in "$FRAMEWORK_ROOT/lib/"*.sh; do
            [ -f "$_sv_src" ] || continue
            local _sv_name
            _sv_name=$(basename "$_sv_src")
            local _sv_dst="$_self_vendor/lib/$_sv_name"
            if [ ! -f "$_sv_dst" ] || ! diff -q "$_sv_src" "$_sv_dst" > /dev/null 2>&1; then
                if [ "$dry_run" != true ]; then
                    cp "$_sv_src" "$_sv_dst"
                    [ -x "$_sv_src" ] && chmod +x "$_sv_dst"
                fi
                _sv_updated=$((_sv_updated + 1))
            fi
        done
        if [ "$_sv_updated" -gt 0 ]; then
            echo -e "  ${GREEN}Self-vendor:${NC} synced $_sv_updated file(s) to .agentic-framework/lib/"
        fi
    fi

    local project_name
    project_name=$(basename "$target_dir")
    local changes=0
    local skipped=0

    # Version comparison
    local fw_version="${FW_VERSION:-unknown}"
    local project_version=""
    if [ -f "$target_dir/.framework.yaml" ]; then
        project_version=$(grep "^version:" "$target_dir/.framework.yaml" 2>/dev/null | sed 's/^version:[[:space:]]*//' || true)
    fi

    echo -e "${BOLD}fw upgrade${NC} - Syncing framework improvements"
    echo ""
    echo "  Project:   $target_dir ($project_name)"
    echo "  Framework: $FRAMEWORK_ROOT (v${fw_version})"
    if [ -n "$project_version" ]; then
        if [ "$project_version" = "$fw_version" ]; then
            echo -e "  Pinned:    v${project_version} ${GREEN}(current)${NC}"
        else
            echo -e "  Pinned:    v${project_version} ${YELLOW}(behind v${fw_version})${NC}"
        fi
    else
        echo -e "  Pinned:    ${YELLOW}<none>${NC} (version tracking will be added)"
    fi
    if [ "$dry_run" = true ]; then
        echo -e "  Mode:      ${YELLOW}DRY RUN${NC} (no changes will be made)"
    fi
    echo ""

    # ── 1. CLAUDE.md — preserve project sections, update governance ──
    echo -e "${YELLOW}[1/10] CLAUDE.md governance sections${NC}"

    local project_claude="$target_dir/CLAUDE.md"
    local template_file="$FRAMEWORK_ROOT/lib/templates/claude-project.md"

    if [ -f "$project_claude" ] && [ -f "$template_file" ]; then
        # Extract project-specific sections (everything before "## Core Principle")
        local project_header
        project_header=$(sed -n '1,/^## Core Principle$/{ /^## Core Principle$/d; p; }' "$project_claude")

        # Extract governance sections from template (from "## Core Principle" onwards)
        local governance
        governance=$(sed -n '/^## Core Principle$/,$ p' "$template_file")

        if [ -z "$project_header" ]; then
            # No project header found — file might be the raw template or custom
            project_header="# CLAUDE.md

Claude Code integration for the Agentic Engineering Framework.
For the provider-neutral framework guide, see \`FRAMEWORK.md\`.

This file is auto-loaded by Claude Code. It contains the full operating guide
plus Claude Code-specific integration notes.

## Project Overview

**Project:** $project_name

<!-- Add your project description, tech stack, and conventions below -->

## Tech Stack and Conventions

<!-- Define your project's tech stack, coding standards, and conventions here -->

## Project-Specific Rules

<!-- Add any project-specific rules that agents must follow -->

"
        fi

        # Fix any leftover placeholders in existing file
        if grep -q "__PROJECT_NAME__" "$project_claude" 2>/dev/null; then
            if [ "$dry_run" != true ]; then
                _sed_i "s|__PROJECT_NAME__|$project_name|g" "$project_claude"
                echo -e "  ${GREEN}FIXED${NC}  Replaced __PROJECT_NAME__ placeholder"
                changes=$((changes + 1))
            else
                echo -e "  ${CYAN}WOULD FIX${NC}  __PROJECT_NAME__ placeholder"
                changes=$((changes + 1))
            fi
        fi

        # Compare current governance with template
        local current_governance
        current_governance=$(sed -n '/^## Core Principle$/,$ p' "$project_claude")

        if [ "$current_governance" = "$governance" ]; then
            echo -e "  ${GREEN}OK${NC}  Already up to date"
        else
            changes=$((changes + 1))
            if [ "$dry_run" = true ]; then
                local current_lines new_lines
                current_lines=$(echo "$current_governance" | wc -l)
                new_lines=$(echo "$governance" | wc -l)
                echo -e "  ${CYAN}WOULD UPDATE${NC}  Governance sections ($current_lines → $new_lines lines)"
            else
                # Backup before overwriting
                cp "$project_claude" "${project_claude}.bak"
                # Write combined file, fix any leftover placeholders
                project_header="${project_header//__PROJECT_NAME__/$project_name}"
                printf '%s\n%s\n' "$project_header" "$governance" > "$project_claude"
                echo -e "  ${GREEN}UPDATED${NC}  Governance sections refreshed from framework template. Backup: CLAUDE.md.bak"
            fi
        fi
    elif [ ! -f "$project_claude" ]; then
        changes=$((changes + 1))
        if [ "$dry_run" = true ]; then
            echo -e "  ${CYAN}WOULD CREATE${NC}  CLAUDE.md from template"
        else
            sed "s|__PROJECT_NAME__|$project_name|g" "$template_file" > "$project_claude"
            echo -e "  ${GREEN}CREATED${NC}  CLAUDE.md from template"
        fi
    else
        echo -e "  ${YELLOW}SKIP${NC}  Template not found at $template_file"
        skipped=$((skipped + 1))
    fi

    # ── 2. Task templates ──
    echo -e "${YELLOW}[2/10] Task templates${NC}"

    local tmpl_updated=0
    for tmpl in "$FRAMEWORK_ROOT/.tasks/templates/"*.md; do
        [ -f "$tmpl" ] || continue
        local tmpl_name
        tmpl_name=$(basename "$tmpl")
        local target_tmpl="$target_dir/.tasks/templates/$tmpl_name"

        if [ ! -f "$target_tmpl" ] || ! diff -q "$tmpl" "$target_tmpl" > /dev/null 2>&1; then
            tmpl_updated=$((tmpl_updated + 1))
            if [ "$dry_run" != true ]; then
                mkdir -p "$target_dir/.tasks/templates"
                cp "$tmpl" "$target_tmpl"
            fi
        fi
    done

    if [ "$tmpl_updated" -gt 0 ]; then
        changes=$((changes + 1))
        if [ "$dry_run" = true ]; then
            echo -e "  ${CYAN}WOULD UPDATE${NC}  $tmpl_updated template(s)"
        else
            echo -e "  ${GREEN}UPDATED${NC}  $tmpl_updated template(s)"
        fi
    else
        echo -e "  ${GREEN}OK${NC}  All templates current"
    fi

    # ── 3. Seed files (universal governance items) ──
    echo -e "${YELLOW}[3/10] Seed files (universal governance)${NC}"

    local seed_updated=0
    for seed_name in practices decisions patterns; do
        local seed_file="$FRAMEWORK_ROOT/lib/seeds/${seed_name}.yaml"
        local project_file="$target_dir/.context/project/${seed_name}.yaml"

        [ -f "$seed_file" ] || continue

        if [ ! -f "$project_file" ]; then
            seed_updated=$((seed_updated + 1))
            if [ "$dry_run" != true ]; then
                cp "$seed_file" "$project_file"
            fi
        elif ! diff -q "$seed_file" "$project_file" > /dev/null 2>&1; then
            # File differs — check if project has added project-specific items
            # Count items in each
            local seed_count project_count
            seed_count=$(grep -c "^  - " "$seed_file" 2>/dev/null || true)
            project_count=$(grep -c "^  - " "$project_file" 2>/dev/null || true)
            seed_count=${seed_count:-0}
            project_count=${project_count:-0}

            if [ "$project_count" -gt "$seed_count" ]; then
                # Project has more items — has been customized, skip
                echo -e "  ${YELLOW}SKIP${NC}  ${seed_name}.yaml (has project-specific items — manual merge recommended)"
                skipped=$((skipped + 1))
            else
                seed_updated=$((seed_updated + 1))
                if [ "$dry_run" != true ]; then
                    cp "$seed_file" "$project_file"
                fi
            fi
        fi
    done

    if [ "$seed_updated" -gt 0 ]; then
        changes=$((changes + 1))
        if [ "$dry_run" = true ]; then
            echo -e "  ${CYAN}WOULD UPDATE${NC}  $seed_updated seed file(s)"
        else
            echo -e "  ${GREEN}UPDATED${NC}  $seed_updated seed file(s)"
        fi
    elif [ "$skipped" -eq 0 ]; then
        echo -e "  ${GREEN}OK${NC}  All seeds current"
    fi

    # ── 3b. Cron registry (T-448/T-653) ──
    local cron_seeded=0
    if [ ! -d "$target_dir/.context/cron" ]; then
        cron_seeded=$((cron_seeded + 1))
        if [ "$dry_run" != true ]; then
            mkdir -p "$target_dir/.context/cron"
        fi
    fi
    if [ ! -f "$target_dir/.context/cron-registry.yaml" ]; then
        cron_seeded=$((cron_seeded + 1))
        if [ "$dry_run" != true ]; then
            cat > "$target_dir/.context/cron-registry.yaml" << 'CRONREGEOF'
# Cron Registry — Structured source of truth for scheduled jobs (T-448)
# Read by web/blueprints/cron.py and fw cron generate.
jobs: []
CRONREGEOF
        fi
    fi
    if [ "$cron_seeded" -gt 0 ]; then
        changes=$((changes + 1))
        if [ "$dry_run" = true ]; then
            echo -e "  ${CYAN}WOULD SEED${NC}  Cron registry + directory"
        else
            echo -e "  ${GREEN}SEEDED${NC}  Cron registry + directory"
        fi
    fi

    # ── 4. Git hooks ──
    echo -e "${YELLOW}[4/10] Git hooks${NC}"

    if [ -d "$target_dir/.git" ]; then
        if [ "$dry_run" = true ]; then
            echo -e "  ${CYAN}WOULD REINSTALL${NC}  Git hooks"
            changes=$((changes + 1))
        else
            if PROJECT_ROOT="$target_dir" "$FRAMEWORK_ROOT/agents/git/git.sh" install-hooks > /dev/null 2>&1; then
                echo -e "  ${GREEN}UPDATED${NC}  Git hooks reinstalled"
                changes=$((changes + 1))
            else
                echo -e "  ${YELLOW}WARN${NC}  Git hook installation failed"
                skipped=$((skipped + 1))
            fi
        fi
    else
        echo -e "  ${CYAN}SKIP${NC}  Not a git repository"
    fi

    # ── 4b. Vendored framework scripts (.agentic-framework/) ──
    # T-1157: Collapsed from 120-line handcrafted per-file sync into single do_vendor call.
    # do_vendor (bin/fw:118) maintains the canonical includes list (bin lib agents web docs
    # .tasks/templates FRAMEWORK.md metrics.sh). This eliminates the enumeration-divergence
    # bug that caused fw upgrade to silently skip web/ (T-1109 RCA).
    echo -e "${YELLOW}[4b/9] Vendored framework scripts${NC}"

    local vendored_dir="$target_dir/.agentic-framework"
    if [ -d "$vendored_dir" ]; then
        if [ "$dry_run" = true ]; then
            do_vendor --target "$target_dir" --source "$FRAMEWORK_ROOT" --dry-run 2>&1 | sed 's/^/  /'
        else
            do_vendor --target "$target_dir" --source "$FRAMEWORK_ROOT" 2>&1 | sed 's/^/  /'
        fi
        changes=$((changes + 1))
    else
        echo -e "  ${CYAN}SKIP${NC}  No .agentic-framework/ directory"
    fi

    # ── 4c. Shim migration + global install sync ──
    echo -e "${YELLOW}[4c/9] Shim migration + global install sync${NC}"

    # T-665: Migrate ~/.local/bin/fw from global symlink to project-detecting shim
    local local_bin="$HOME/.local/bin"
    local shim_src="$FRAMEWORK_ROOT/bin/fw-shim"
    if [ -f "$shim_src" ] && [ -d "$local_bin" ]; then
        local current_fw="$local_bin/fw"
        if [ -L "$current_fw" ]; then
            # Current fw is a symlink (old style) — replace with shim
            local link_target
            link_target=$(readlink -f "$current_fw" 2>/dev/null || echo "")
            if [[ "$link_target" == *".agentic-framework/bin/fw"* ]] || [[ "$link_target" == *"/bin/fw" ]]; then
                if [ "$dry_run" = true ]; then
                    echo -e "  ${CYAN}WOULD MIGRATE${NC}  Replace symlink with project-detecting shim"
                else
                    cp "$shim_src" "$current_fw"
                    chmod +x "$current_fw"
                    changes=$((changes + 1))
                    echo -e "  ${GREEN}MIGRATED${NC}  Replaced global symlink with project-detecting shim"
                    echo -e "  ${CYAN}INFO${NC}  Shim migration: fw now routes to the project you're standing in"
                    echo -e "  ${CYAN}INFO${NC}  Each project uses its own framework version (no global install dependency)"
                fi
            fi
        elif [ -f "$current_fw" ] && ! grep -q 'find_fw' "$current_fw" 2>/dev/null; then
            # fw exists but isn't the shim — leave it alone (manual install)
            echo -e "  ${CYAN}SKIP${NC}  $current_fw exists but is not a symlink or shim"
        else
            echo -e "  ${GREEN}OK${NC}  fw shim already installed"
        fi
    fi

    # T-660: Global install sync (fallback for users who still use global install)
    local global_dir="$HOME/.agentic-framework"
    if [ -d "$global_dir/agents/context" ]; then
        local global_updated=0
        # Sync bin/fw (T-660: main CLI entry point — stale global fw causes deadlock)
        local src_fw="$FRAMEWORK_ROOT/bin/fw"
        local dst_fw="$global_dir/bin/fw"
        if [ -f "$src_fw" ]; then
            if [ ! -f "$dst_fw" ] || ! diff -q "$src_fw" "$dst_fw" > /dev/null 2>&1; then
                global_updated=$((global_updated + 1))
                if [ "$dry_run" != true ]; then
                    mkdir -p "$global_dir/bin"
                    cp "$src_fw" "$dst_fw"
                    chmod +x "$dst_fw"
                fi
            fi
        fi
        # Sync lib/*.sh (T-660: subcommand implementations invoked by bin/fw)
        if [ -d "$FRAMEWORK_ROOT/lib" ]; then
            for src_lib_file in "$FRAMEWORK_ROOT/lib/"*.sh; do
                [ -f "$src_lib_file" ] || continue
                local lib_name
                lib_name=$(basename "$src_lib_file")
                local dst_lib_file="$global_dir/lib/$lib_name"
                if [ ! -f "$dst_lib_file" ] || ! diff -q "$src_lib_file" "$dst_lib_file" > /dev/null 2>&1; then
                    global_updated=$((global_updated + 1))
                    if [ "$dry_run" != true ]; then
                        mkdir -p "$global_dir/lib"
                        cp "$src_lib_file" "$dst_lib_file"
                        [ -x "$src_lib_file" ] && chmod +x "$dst_lib_file"
                    fi
                fi
            done
        fi
        # Sync agents/context/*.sh
        for src_script in "$FRAMEWORK_ROOT/agents/context/"*.sh; do
            [ -f "$src_script" ] || continue
            local sname
            sname=$(basename "$src_script")
            local dst_script="$global_dir/agents/context/$sname"
            if [ ! -f "$dst_script" ] || ! diff -q "$src_script" "$dst_script" > /dev/null 2>&1; then
                global_updated=$((global_updated + 1))
                if [ "$dry_run" != true ]; then
                    cp "$src_script" "$dst_script"
                    chmod +x "$dst_script"
                fi
            fi
        done
        # Sync agents/context/lib/
        if [ -d "$FRAMEWORK_ROOT/agents/context/lib" ]; then
            for src_lib in "$FRAMEWORK_ROOT/agents/context/lib/"*; do
                [ -f "$src_lib" ] || continue
                local lname
                lname=$(basename "$src_lib")
                local dst_lib="$global_dir/agents/context/lib/$lname"
                if [ ! -f "$dst_lib" ] || ! diff -q "$src_lib" "$dst_lib" > /dev/null 2>&1; then
                    global_updated=$((global_updated + 1))
                    if [ "$dry_run" != true ]; then
                        mkdir -p "$global_dir/agents/context/lib"
                        cp "$src_lib" "$dst_lib"
                        [ -x "$src_lib" ] && chmod +x "$dst_lib"
                    fi
                fi
            done
        fi

        if [ "$global_updated" -gt 0 ]; then
            changes=$((changes + 1))
            if [ "$dry_run" = true ]; then
                echo -e "  ${CYAN}WOULD UPDATE${NC}  $global_updated global script(s)"
            else
                echo -e "  ${GREEN}UPDATED${NC}  $global_updated global script(s) synced to $global_dir"
            fi
        else
            echo -e "  ${GREEN}OK${NC}  Global install scripts current"
        fi
    else
        echo -e "  ${CYAN}SKIP${NC}  No global install at $global_dir"
    fi

    # ── 5. .claude/settings.json (hooks config) ──
    echo -e "${YELLOW}[5/10] Claude Code hooks (.claude/settings.json)${NC}"

    local settings_file="$target_dir/.claude/settings.json"
    local fw_settings="$FRAMEWORK_ROOT/.claude/settings.json"
    if [ -f "$settings_file" ]; then
        # Compare hooks by TYPE enumeration (T-615: not count)
        # Source of truth: framework's own .claude/settings.json
        local hook_analysis
        hook_analysis=$(FW_FILE="$fw_settings" CONSUMER_FILE="$settings_file" python3 -c "
import json, os

def extract_hooks(path):
    hooks = set()
    try:
        with open(path) as f:
            data = json.load(f)
        for event, entries in data.get('hooks', {}).items():
            for entry in entries:
                for hook in entry.get('hooks', []):
                    cmd = hook.get('command', '')
                    if 'fw hook' in cmd:
                        name = cmd.split('fw hook ')[-1].strip()
                    else:
                        name = cmd.strip().split('/')[-1]
                    hooks.add((event, name))
    except (json.JSONDecodeError, FileNotFoundError):
        pass
    return hooks

def check_stale_paths(path):
    stale = 0
    non_framework = 0
    try:
        with open(path) as f:
            data = json.load(f)
        for event, entries in data.get('hooks', {}).items():
            for entry in entries:
                for hook in entry.get('hooks', []):
                    cmd = hook.get('command', '')
                    if '/agents/context/' in cmd or 'PROJECT_ROOT=' in cmd:
                        stale += 1
                    # T-679: Detect non-framework hooks (e.g., pre-existing project hooks)
                    # Framework hooks always contain 'fw hook' or '.agentic-framework'
                    elif cmd and 'fw hook' not in cmd and '.agentic-framework' not in cmd:
                        non_framework += 1
    except (json.JSONDecodeError, FileNotFoundError):
        pass
    return stale + non_framework

fw_hooks = extract_hooks(os.environ['FW_FILE'])
consumer_hooks = extract_hooks(os.environ['CONSUMER_FILE'])
stale = check_stale_paths(os.environ['CONSUMER_FILE'])

missing = fw_hooks - consumer_hooks
missing_names = '; '.join(f'{e}:{n}' for e, n in sorted(missing)) if missing else ''
print(f'{len(fw_hooks)}|{len(consumer_hooks)}|{len(missing)}|{stale}|{missing_names}')
" 2>/dev/null || echo "0|0|0|0|parse-error")
        local fw_total consumer_total missing_count stale_hooks missing_names
        fw_total=$(echo "$hook_analysis" | cut -d'|' -f1)
        consumer_total=$(echo "$hook_analysis" | cut -d'|' -f2)
        missing_count=$(echo "$hook_analysis" | cut -d'|' -f3)
        stale_hooks=$(echo "$hook_analysis" | cut -d'|' -f4)
        missing_names=$(echo "$hook_analysis" | cut -d'|' -f5)

        local needs_regen=false
        [ "$missing_count" -gt 0 ] && needs_regen=true
        [ "${stale_hooks:-0}" -gt 0 ] && needs_regen=true

        if [ "$needs_regen" = true ]; then
            changes=$((changes + 1))
            local reason=""
            if [ "$missing_count" -gt 0 ]; then
                reason="missing $missing_count hook(s): $missing_names"
            fi
            if [ "${stale_hooks:-0}" -gt 0 ]; then
                [ -n "$reason" ] && reason="$reason + "
                reason="${reason}${stale_hooks} hardcoded paths"
            fi
            if [ "$dry_run" = true ]; then
                echo -e "  ${CYAN}WOULD UPDATE${NC}  $reason"
            else
                cp "$settings_file" "${settings_file}.bak"
                local save_force="${force:-false}"
                force=true
                generate_claude_code_config "$target_dir"
                force="$save_force"
                echo -e "  ${GREEN}UPDATED${NC}  Hooks regenerated ($reason). Backup: settings.json.bak"
            fi
        else
            echo -e "  ${GREEN}OK${NC}  $consumer_total/$fw_total hooks present (all types matched)"
        fi
    else
        local fw_hook_count=0
        if [ -f "$fw_settings" ]; then
            fw_hook_count=$(python3 -c "
import json
with open('$fw_settings') as f:
    data = json.load(f)
print(sum(len(v) for v in data.get('hooks', {}).values()))
" 2>/dev/null || echo "0")
        fi
        changes=$((changes + 1))
        if [ "$dry_run" = true ]; then
            echo -e "  ${CYAN}WOULD CREATE${NC}  .claude/settings.json ($fw_hook_count hooks)"
        else
            force=true
            generate_claude_code_config "$target_dir"
            force=false
            echo -e "  ${GREEN}CREATED${NC}  .claude/settings.json ($fw_hook_count hooks)"
        fi
    fi

    # ── 6. .mcp.json (MCP server configuration) ──
    echo -e "${YELLOW}[6/10] MCP server configuration (.mcp.json)${NC}"

    local mcp_file="$target_dir/.mcp.json"
    # Framework-recommended MCP servers
    local recommended_servers='{"context7":1,"playwright":1,"termlink":1}'

    if [ -f "$mcp_file" ]; then
        # Check for missing recommended servers
        local mcp_analysis
        mcp_analysis=$(RECOMMENDED="$recommended_servers" MCP_FILE="$mcp_file" python3 -c "
import json, os, sys
recommended = json.loads(os.environ['RECOMMENDED'])
try:
    with open(os.environ['MCP_FILE']) as f:
        existing = json.load(f)
except (json.JSONDecodeError, FileNotFoundError):
    existing = {}
missing = [k for k in recommended if k not in existing]
print(f'{len(existing)}|{len(missing)}|{\",\".join(missing)}')
" 2>/dev/null || echo "0|0|parse-error")
        local existing_count missing_mcp_count missing_mcp_names
        existing_count=$(echo "$mcp_analysis" | cut -d'|' -f1)
        missing_mcp_count=$(echo "$mcp_analysis" | cut -d'|' -f2)
        missing_mcp_names=$(echo "$mcp_analysis" | cut -d'|' -f3)

        if [ "$missing_mcp_count" -gt 0 ] && [ "$missing_mcp_names" != "parse-error" ]; then
            changes=$((changes + 1))
            if [ "$dry_run" = true ]; then
                echo -e "  ${CYAN}WOULD ADD${NC}  Missing MCP servers: $missing_mcp_names"
            else
                # Merge missing servers into existing config (preserves custom servers)
                RECOMMENDED="$recommended_servers" MCP_FILE="$mcp_file" python3 -c "
import json, os
recommended_keys = json.loads(os.environ['RECOMMENDED'])
mcp_file = os.environ['MCP_FILE']
with open(mcp_file) as f:
    existing = json.load(f)
defaults = {
    'context7': {'command': 'npx', 'args': ['-y', '@upstash/context7-mcp']},
    'playwright': {'command': 'npx', 'args': ['@playwright/mcp@latest', '--no-sandbox']},
    'termlink': {'command': 'termlink', 'args': ['mcp', 'serve']},
}
for key in recommended_keys:
    if key not in existing and key in defaults:
        existing[key] = defaults[key]
with open(mcp_file, 'w') as f:
    json.dump(existing, f, indent=2)
    f.write('\n')
" 2>/dev/null
                echo -e "  ${GREEN}UPDATED${NC}  Added missing MCP servers: $missing_mcp_names (preserved $existing_count existing)"
            fi
        else
            echo -e "  ${GREEN}OK${NC}  $existing_count MCP server(s) configured (all recommended present)"
        fi
    else
        changes=$((changes + 1))
        if [ "$dry_run" = true ]; then
            echo -e "  ${CYAN}WOULD CREATE${NC}  .mcp.json (context7, playwright, termlink)"
        else
            cat > "$mcp_file" << 'MCPJSON'
{
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
MCPJSON
            echo -e "  ${GREEN}CREATED${NC}  .mcp.json (MCP servers: context7, playwright, termlink)"
        fi
    fi

    # ── 7. .claude/commands/resume.md ──
    echo -e "${YELLOW}[7/10] Claude Code commands${NC}"

    local resume_file="$target_dir/.claude/commands/resume.md"

    # Use the version from init.sh if no separate template exists
    if [ -f "$resume_file" ]; then
        echo -e "  ${GREEN}OK${NC}  resume.md exists"
    else
        changes=$((changes + 1))
        if [ "$dry_run" = true ]; then
            echo -e "  ${CYAN}WOULD CREATE${NC}  .claude/commands/resume.md"
        else
            mkdir -p "$target_dir/.claude/commands"
            # Copy from init function logic
            echo -e "  ${YELLOW}SKIP${NC}  resume.md — run 'fw init --force' to regenerate"
            skipped=$((skipped + 1))
        fi
    fi

    # ── 8. Context subdirectories (create missing) ──
    echo -e "${YELLOW}[8/10] Context subdirectories${NC}"

    local ctx_created=0
    for ctx_subdir in audits bus episodic handovers inbox project qa scans working; do
        local ctx_path="$target_dir/.context/$ctx_subdir"
        if [ ! -d "$ctx_path" ]; then
            ctx_created=$((ctx_created + 1))
            if [ "$dry_run" != true ]; then
                mkdir -p "$ctx_path"
            fi
        fi
    done

    if [ "$ctx_created" -gt 0 ]; then
        changes=$((changes + 1))
        if [ "$dry_run" = true ]; then
            echo -e "  ${CYAN}WOULD CREATE${NC}  $ctx_created missing subdirectory(ies)"
        else
            echo -e "  ${GREEN}CREATED${NC}  $ctx_created missing subdirectory(ies)"
        fi
    else
        echo -e "  ${GREEN}OK${NC}  All context subdirectories present"
    fi

    # ── 9. Version tracking (.framework.yaml) ──
    echo -e "${YELLOW}[9/10] Version tracking${NC}"

    local fw_version="${FW_VERSION:-unknown}"
    local yaml_file="$target_dir/.framework.yaml"

    if [ -f "$yaml_file" ]; then
        local current_pinned
        current_pinned=$(grep "^version:" "$yaml_file" 2>/dev/null | sed 's/^version:[[:space:]]*//' || true)

        if [ "$current_pinned" = "$fw_version" ]; then
            echo -e "  ${GREEN}OK${NC}  Version $fw_version already recorded"
        else
            changes=$((changes + 1))
            if [ "$dry_run" = true ]; then
                echo -e "  ${CYAN}WOULD UPDATE${NC}  version: ${current_pinned:-<none>} → $fw_version"
            else
                # Record upgraded_from before overwriting version
                if [ -n "$current_pinned" ]; then
                    if grep -q "^upgraded_from:" "$yaml_file" 2>/dev/null; then
                        _sed_i "s/^upgraded_from:.*/upgraded_from: $current_pinned/" "$yaml_file"
                    else
                        echo "upgraded_from: $current_pinned" >> "$yaml_file"
                    fi
                fi
                if grep -q "^version:" "$yaml_file" 2>/dev/null; then
                    _sed_i "s/^version:.*/version: $fw_version/" "$yaml_file"
                else
                    echo "version: $fw_version" >> "$yaml_file"
                fi
                # Record last_upgrade timestamp
                local upgrade_ts
                upgrade_ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
                if grep -q "^last_upgrade:" "$yaml_file" 2>/dev/null; then
                    _sed_i "s/^last_upgrade:.*/last_upgrade: $upgrade_ts/" "$yaml_file"
                else
                    echo "last_upgrade: $upgrade_ts" >> "$yaml_file"
                fi
                echo -e "  ${GREEN}UPDATED${NC}  version: ${current_pinned:-<none>} → $fw_version"
            fi
        fi
    else
        echo -e "  ${YELLOW}SKIP${NC}  No .framework.yaml found"
        skipped=$((skipped + 1))
    fi

    # ── 8b. Upgrade audit trail (.context/audits/upgrades.yaml) ──
    if [ "$dry_run" != true ] && [ -n "${current_pinned:-}" ] && [ "${current_pinned:-}" != "$fw_version" ]; then
        local audit_file="$target_dir/.context/audits/upgrades.yaml"
        mkdir -p "$(dirname "$audit_file")"
        if [ ! -f "$audit_file" ]; then
            echo "# Upgrade audit trail (T-617)" > "$audit_file"
            echo "upgrades:" >> "$audit_file"
        fi
        local upgrade_ts
        upgrade_ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
        cat >> "$audit_file" <<EOF
  - timestamp: $upgrade_ts
    from_version: "${current_pinned:-unknown}"
    to_version: "$fw_version"
    framework_root: "$FRAMEWORK_ROOT"
EOF
        echo -e "  ${GREEN}LOGGED${NC}  Upgrade trail → .context/audits/upgrades.yaml"
    fi

    # ── 10. Enforcement baseline (T-884: auto-create if missing) ──
    echo -e "${YELLOW}[10/10] Enforcement baseline${NC}"
    local ef_baseline="$target_dir/.context/project/enforcement-baseline.sha256"
    local ef_settings="$target_dir/.claude/settings.json"
    if [ -f "$ef_baseline" ]; then
        echo -e "  ${GREEN}OK${NC}  Enforcement baseline exists"
    elif [ -f "$ef_settings" ]; then
        if [ "$dry_run" = true ]; then
            echo -e "  ${CYAN}WOULD CREATE${NC}  Enforcement baseline"
            changes=$((changes + 1))
        else
            if PROJECT_ROOT="$target_dir" "$FRAMEWORK_ROOT/bin/fw" enforcement baseline >/dev/null 2>&1; then
                echo -e "  ${GREEN}CREATED${NC}  Enforcement baseline"
                changes=$((changes + 1))
            else
                echo -e "  ${YELLOW}SKIP${NC}  Could not create enforcement baseline"
                skipped=$((skipped + 1))
            fi
        fi
    else
        echo -e "  ${YELLOW}SKIP${NC}  No settings.json — enforcement baseline not applicable"
        skipped=$((skipped + 1))
    fi

    # ── Summary ──
    echo ""
    if [ "$dry_run" = true ]; then
        echo -e "${CYAN}=== Dry Run Complete ===${NC}"
        echo ""
        echo "  $changes change(s) would be made"
        echo "  $skipped item(s) skipped (manual review needed)"
        echo ""
        echo "Run without --dry-run to apply changes."
    else
        if [ "$changes" -gt 0 ]; then
            echo -e "${GREEN}=== Upgrade Complete ===${NC}"
        else
            echo -e "${GREEN}=== Already Up To Date ===${NC}"
        fi
        echo ""
        echo "  $changes change(s) applied"
        echo "  $skipped item(s) skipped"

        if [ "$changes" -gt 0 ]; then
            echo ""
            echo -e "${BOLD}Next steps:${NC}"
            echo "  1. Review changes: cd $target_dir && git diff"
            echo "  2. Commit: fw git commit -m 'T-012: fw upgrade — sync framework improvements'"
            echo "  3. Run: fw doctor  # Verify health"
        fi
    fi
}
