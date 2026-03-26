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
    echo -e "${YELLOW}[1/8] CLAUDE.md governance sections${NC}"

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
                project_header=$(echo "$project_header" | sed "s|__PROJECT_NAME__|$project_name|g")
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
    echo -e "${YELLOW}[2/8] Task templates${NC}"

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
    echo -e "${YELLOW}[3/8] Seed files (universal governance)${NC}"

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

    # ── 4. Git hooks ──
    echo -e "${YELLOW}[4/8] Git hooks${NC}"

    if [ -d "$target_dir/.git" ]; then
        if [ "$dry_run" = true ]; then
            echo -e "  ${CYAN}WOULD REINSTALL${NC}  Git hooks"
            changes=$((changes + 1))
        else
            PROJECT_ROOT="$target_dir" "$FRAMEWORK_ROOT/agents/git/git.sh" install-hooks > /dev/null 2>&1 && {
                echo -e "  ${GREEN}UPDATED${NC}  Git hooks reinstalled"
                changes=$((changes + 1))
            } || {
                echo -e "  ${YELLOW}WARN${NC}  Git hook installation failed"
                skipped=$((skipped + 1))
            }
        fi
    else
        echo -e "  ${CYAN}SKIP${NC}  Not a git repository"
    fi

    # ── 4b. Vendored framework scripts (.agentic-framework/) ──
    echo -e "${YELLOW}[4b/9] Vendored framework scripts${NC}"

    local vendored_dir="$target_dir/.agentic-framework"
    if [ -d "$vendored_dir" ]; then
        local script_updated=0
        # Sync agents/context/*.sh (hook scripts)
        for src_script in "$FRAMEWORK_ROOT/agents/context/"*.sh; do
            [ -f "$src_script" ] || continue
            local sname
            sname=$(basename "$src_script")
            local dst_script="$vendored_dir/agents/context/$sname"
            if [ ! -f "$dst_script" ] || ! diff -q "$src_script" "$dst_script" > /dev/null 2>&1; then
                script_updated=$((script_updated + 1))
                if [ "$dry_run" != true ]; then
                    mkdir -p "$vendored_dir/agents/context"
                    cp "$src_script" "$dst_script"
                    chmod +x "$dst_script"
                fi
            fi
        done
        # Sync agents/context/lib/ (shared libraries)
        if [ -d "$FRAMEWORK_ROOT/agents/context/lib" ]; then
            for src_lib in "$FRAMEWORK_ROOT/agents/context/lib/"*; do
                [ -f "$src_lib" ] || continue
                local lname
                lname=$(basename "$src_lib")
                local dst_lib="$vendored_dir/agents/context/lib/$lname"
                if [ ! -f "$dst_lib" ] || ! diff -q "$src_lib" "$dst_lib" > /dev/null 2>&1; then
                    script_updated=$((script_updated + 1))
                    if [ "$dry_run" != true ]; then
                        mkdir -p "$vendored_dir/agents/context/lib"
                        cp "$src_lib" "$dst_lib"
                        [ -x "$src_lib" ] && chmod +x "$dst_lib"
                    fi
                fi
            done
        fi
        # Sync bin/fw (consumer's vendored fw binary)
        if [ -f "$FRAMEWORK_ROOT/bin/fw" ]; then
            local dst_fw="$vendored_dir/bin/fw"
            if [ ! -f "$dst_fw" ] || ! diff -q "$FRAMEWORK_ROOT/bin/fw" "$dst_fw" > /dev/null 2>&1; then
                script_updated=$((script_updated + 1))
                if [ "$dry_run" != true ]; then
                    mkdir -p "$vendored_dir/bin"
                    cp "$FRAMEWORK_ROOT/bin/fw" "$dst_fw"
                    chmod +x "$dst_fw"
                fi
            fi
        fi

        if [ "$script_updated" -gt 0 ]; then
            changes=$((changes + 1))
            if [ "$dry_run" = true ]; then
                echo -e "  ${CYAN}WOULD UPDATE${NC}  $script_updated vendored script(s)"
            else
                echo -e "  ${GREEN}UPDATED${NC}  $script_updated vendored script(s) synced"
            fi
        else
            echo -e "  ${GREEN}OK${NC}  All vendored scripts current"
        fi
    else
        echo -e "  ${CYAN}SKIP${NC}  No .agentic-framework/ directory"
    fi

    # ── 4c. Global install sync ($HOME/.agentic-framework/) ──
    echo -e "${YELLOW}[4c/9] Global install sync${NC}"

    local global_dir="$HOME/.agentic-framework"
    if [ -d "$global_dir/agents/context" ]; then
        local global_updated=0
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
    echo -e "${YELLOW}[5/9] Claude Code hooks (.claude/settings.json)${NC}"

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
    try:
        with open(path) as f:
            data = json.load(f)
        for event, entries in data.get('hooks', {}).items():
            for entry in entries:
                for hook in entry.get('hooks', []):
                    cmd = hook.get('command', '')
                    if '/agents/context/' in cmd or 'PROJECT_ROOT=' in cmd:
                        stale += 1
    except (json.JSONDecodeError, FileNotFoundError):
        pass
    return stale

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

    # ── 6. .claude/commands/resume.md ──
    echo -e "${YELLOW}[6/9] Claude Code commands${NC}"

    local resume_file="$target_dir/.claude/commands/resume.md"
    local framework_resume="$FRAMEWORK_ROOT/lib/templates/resume-command.md"

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

    # ── 7. Context subdirectories (create missing) ──
    echo -e "${YELLOW}[7/9] Context subdirectories${NC}"

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

    # ── 8. Version tracking (.framework.yaml) ──
    echo -e "${YELLOW}[8/9] Version tracking${NC}"

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
