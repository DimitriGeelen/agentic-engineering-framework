#!/bin/bash
# fw validate-init — Verify fw init produced correct and complete output
# Reads #@init: tags from lib/init.sh and validates each against target directory
#
# Tag format in init.sh:
#   #@init: <type>-<key> <path> [check_args] [?condition]
#   # Human-readable description
#
# Check types: dir, file, yaml, json, exec, hookpaths
# Conditions: ?git (requires .git), ?claude,generic (provider match)

do_validate_init() {
    local target_dir=""
    local provider=""
    local quiet=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            --provider) provider="$2"; shift 2 ;;
            --quiet) quiet=true; shift ;;
            -h|--help)
                echo -e "${BOLD}fw validate-init${NC} — Verify fw init output"
                echo ""
                echo "Usage: fw validate-init [target-dir] [--provider NAME] [--quiet]"
                echo ""
                echo "Reads #@init: tags from init.sh and validates each unit."
                echo "Called automatically at the end of fw init."
                return 0
                ;;
            -*) echo -e "${RED}Unknown option: $1${NC}" >&2; return 1 ;;
            *) target_dir="$1"; shift ;;
        esac
    done

    target_dir="${target_dir:-$PWD}"
    target_dir="$(cd "$target_dir" 2>/dev/null && pwd)" || {
        echo -e "${RED}ERROR: Directory does not exist: $target_dir${NC}" >&2
        return 1
    }

    # Locate init.sh
    local init_script="${FRAMEWORK_ROOT:-$(dirname "$(dirname "${BASH_SOURCE[0]}")")}/lib/init.sh"
    if [ ! -f "$init_script" ]; then
        echo -e "${RED}ERROR: Cannot find lib/init.sh${NC}" >&2
        return 1
    fi

    # Auto-detect provider from .framework.yaml
    if [ -z "$provider" ] && [ -f "$target_dir/.framework.yaml" ]; then
        provider=$(grep "^provider:" "$target_dir/.framework.yaml" 2>/dev/null | sed 's/provider:[[:space:]]*//')
    fi
    provider="${provider:-generic}"

    local is_git=false
    [ -d "$target_dir/.git" ] && is_git=true

    local has_python=false
    command -v python3 >/dev/null 2>&1 && has_python=true

    local total=0 passed=0 failed=0 skipped=0

    # Extract tag + description pairs using awk
    local pairs
    pairs=$(awk '/#@init:/ { tag=$0; getline; desc=$0; print tag "|||" desc }' "$init_script")

    while IFS= read -r pair; do
        [ -z "$pair" ] && continue

        local tag_line="${pair%%|||*}"
        local desc_line="${pair##*|||}"

        # Strip leading whitespace and comment markers
        tag_line="${tag_line#*#@init: }"
        desc_line="${desc_line#*# }"
        # Trim leading spaces
        desc_line="$(echo "$desc_line" | sed 's/^[[:space:]]*//')"

        # Parse: <type>-<key> <path> [args] [?condition]
        local type_key path check_args condition

        # Split into tokens
        read -r type_key path check_args <<< "$tag_line"

        # Extract condition if present (last token starting with ?)
        condition=""
        if [[ "$check_args" == "?"* ]]; then
            condition="${check_args#\?}"
            check_args=""
        elif [[ "$check_args" == *" ?"* ]]; then
            condition="${check_args##* \?}"
            check_args="${check_args% \?*}"
        fi
        # Also check if path has condition appended (no args case)
        if [[ "$path" == *" ?"* ]]; then
            condition="${path##* \?}"
            path="${path% \?*}"
        fi

        local check_type="${type_key%-*}"

        # Evaluate conditions
        if [ -n "$condition" ]; then
            case "$condition" in
                git)
                    if [ "$is_git" = false ]; then
                        skipped=$((skipped + 1))
                        total=$((total + 1))
                        [ "$quiet" = false ] && echo -e "  ${CYAN}-${NC} ${type_key}  ${desc_line} (skipped: not a git repo)"
                        continue
                    fi
                    ;;
                *)
                    local match=false
                    IFS=',' read -ra cond_list <<< "$condition"
                    for c in "${cond_list[@]}"; do
                        [ "$c" = "$provider" ] && match=true
                    done
                    if [ "$match" = false ]; then
                        skipped=$((skipped + 1))
                        total=$((total + 1))
                        continue
                    fi
                    ;;
            esac
        fi

        total=$((total + 1))
        local full_path="$target_dir/$path"
        local result="fail"
        local detail=""

        case "$check_type" in
            dir)
                if [ -d "$full_path" ]; then
                    result="pass"
                else
                    detail="directory missing"
                fi
                ;;

            file)
                if [ -f "$full_path" ] && [ -s "$full_path" ]; then
                    result="pass"
                elif [ -f "$full_path" ]; then
                    detail="file is empty"
                else
                    detail="file missing"
                fi
                ;;

            yaml)
                if [ ! -f "$full_path" ]; then
                    detail="file missing"
                elif [ "$has_python" = true ]; then
                    if ! python3 -c "import yaml; yaml.safe_load(open('$full_path'))" 2>/dev/null; then
                        detail="invalid YAML"
                    elif [ -n "$check_args" ]; then
                        local missing=""
                        IFS=',' read -ra keys <<< "$check_args"
                        for key in "${keys[@]}"; do
                            if ! grep -q "^${key}[[:space:]]*:" "$full_path" 2>/dev/null; then
                                missing="${missing:+$missing, }$key"
                            fi
                        done
                        if [ -n "$missing" ]; then
                            detail="missing keys: $missing"
                        else
                            result="pass"
                        fi
                    else
                        result="pass"
                    fi
                else
                    # No python3 — check file exists and has expected keys via grep
                    if [ -n "$check_args" ]; then
                        local missing=""
                        IFS=',' read -ra keys <<< "$check_args"
                        for key in "${keys[@]}"; do
                            if ! grep -q "^${key}[[:space:]]*:" "$full_path" 2>/dev/null; then
                                missing="${missing:+$missing, }$key"
                            fi
                        done
                        if [ -n "$missing" ]; then
                            detail="missing keys: $missing"
                        else
                            result="pass"
                        fi
                    else
                        result="pass"
                    fi
                fi
                ;;

            json)
                if [ ! -f "$full_path" ]; then
                    detail="file missing"
                elif [ "$has_python" = true ]; then
                    if ! python3 -c "import json; json.load(open('$full_path'))" 2>/dev/null; then
                        detail="invalid JSON"
                    elif [ -n "$check_args" ]; then
                        local missing=""
                        IFS=',' read -ra keys <<< "$check_args"
                        for key in "${keys[@]}"; do
                            if ! python3 -c "import json; d=json.load(open('$full_path')); assert '$key' in d" 2>/dev/null; then
                                missing="${missing:+$missing, }$key"
                            fi
                        done
                        if [ -n "$missing" ]; then
                            detail="missing keys: $missing"
                        else
                            result="pass"
                        fi
                    else
                        result="pass"
                    fi
                else
                    # No python3 — basic file check only
                    if grep -q '{' "$full_path" 2>/dev/null; then
                        result="pass"
                    else
                        detail="does not look like JSON (no python3 for full check)"
                    fi
                fi
                ;;

            exec)
                if [ ! -f "$full_path" ]; then
                    detail="file missing"
                elif [ ! -x "$full_path" ]; then
                    detail="not executable"
                else
                    local search_str="${check_args//\"/}"
                    if [ -n "$search_str" ] && ! grep -q "$search_str" "$full_path" 2>/dev/null; then
                        detail="missing expected content: $search_str"
                    else
                        result="pass"
                    fi
                fi
                ;;

            hookpaths)
                if [ ! -f "$full_path" ]; then
                    detail="file missing"
                elif [ "$has_python" = false ]; then
                    skipped=$((skipped + 1))
                    total=$((total - 1))  # Don't count as checked
                    [ "$quiet" = false ] && echo -e "  ${CYAN}-${NC} ${type_key}  ${desc_line} (skipped: no python3)"
                    continue
                else
                    local broken
                    broken=$(python3 -c "
import json, os
with open('$full_path') as f:
    data = json.load(f)
for event, entries in data.get('hooks', {}).items():
    for entry in entries:
        for hook in entry.get('hooks', []):
            cmd = hook.get('command', '')
            parts = cmd.split()
            script = next((p for p in parts if '=' not in p), '')
            if script and not os.path.exists(script):
                print(f'missing: {os.path.basename(script)}')
            elif script and '/Cellar/' in script:
                print(f'cellar: {os.path.basename(script)}')
" 2>/dev/null)
                    if [ -n "$broken" ]; then
                        local missing_count cellar_count
                        missing_count=$(echo "$broken" | grep -c "^missing:" || true)
                        cellar_count=$(echo "$broken" | grep -c "^cellar:" || true)
                        if [ "$missing_count" -gt 0 ]; then
                            detail="$missing_count hook script(s) not found"
                        elif [ "$cellar_count" -gt 0 ]; then
                            detail="$cellar_count hook(s) use Cellar path (breaks on brew upgrade)"
                        fi
                    else
                        result="pass"
                    fi
                fi
                ;;

            *)
                skipped=$((skipped + 1))
                [ "$quiet" = false ] && echo -e "  ${YELLOW}?${NC} ${type_key}  Unknown check type" >&2
                continue
                ;;
        esac

        if [ "$result" = "pass" ]; then
            passed=$((passed + 1))
            [ "$quiet" = false ] && echo -e "  ${GREEN}✓${NC} ${type_key}  ${desc_line}"
        else
            failed=$((failed + 1))
            [ "$quiet" = false ] && echo -e "  ${RED}✗${NC} ${type_key}  ${desc_line} — ${detail}"
        fi

    done <<< "$pairs"

    # --- Tier 2: Functional Checks (T-461) ---
    # Beyond "file exists" → "file works"
    [ "$quiet" = false ] && echo "" && echo -e "  ${BOLD}Tier 2: Functional checks${NC}"

    # 2a. Installed git hooks pass bash -n (syntax valid)
    if [ "$is_git" = true ]; then
        for hook in commit-msg post-commit pre-push; do
            local hook_path="$target_dir/.git/hooks/$hook"
            total=$((total + 1))
            if [ ! -f "$hook_path" ]; then
                skipped=$((skipped + 1))
                [ "$quiet" = false ] && echo -e "  ${CYAN}-${NC} func-hook  $hook (not installed)"
            elif bash -n "$hook_path" 2>/dev/null; then
                passed=$((passed + 1))
                [ "$quiet" = false ] && echo -e "  ${GREEN}✓${NC} func-hook  $hook passes bash -n"
            else
                failed=$((failed + 1))
                [ "$quiet" = false ] && echo -e "  ${RED}✗${NC} func-hook  $hook has syntax errors"
            fi
        done
    fi

    # 2b. Settings.json hook paths all resolve to existing scripts
    local settings_file="$target_dir/.claude/settings.json"
    if [ -f "$settings_file" ] && [ "$has_python" = true ]; then
        total=$((total + 1))
        local broken_hooks
        broken_hooks=$(python3 -c "
import json, os
with open('$settings_file') as f:
    data = json.load(f)
broken = []
for event, entries in data.get('hooks', {}).items():
    for entry in entries:
        for hook in entry.get('hooks', []):
            cmd = hook.get('command', '')
            parts = cmd.split()
            script = next((p for p in parts if '=' not in p), '')
            if script and not os.path.exists(script):
                broken.append(os.path.basename(script))
print(','.join(broken))
" 2>/dev/null)
        if [ -z "$broken_hooks" ]; then
            passed=$((passed + 1))
            [ "$quiet" = false ] && echo -e "  ${GREEN}✓${NC} func-paths  All hook script paths resolve"
        else
            failed=$((failed + 1))
            [ "$quiet" = false ] && echo -e "  ${RED}✗${NC} func-paths  Missing hook scripts: $broken_hooks"
        fi
    fi

    # 2c. CLAUDE.md has key governance sections
    local claude_md="$target_dir/CLAUDE.md"
    if [ -f "$claude_md" ]; then
        total=$((total + 1))
        local missing_sections=""
        for section in "Core Principle" "Task System" "Enforcement Tiers" "Session Start Protocol"; do
            if ! grep -q "$section" "$claude_md" 2>/dev/null; then
                missing_sections="${missing_sections:+$missing_sections, }$section"
            fi
        done
        if [ -z "$missing_sections" ]; then
            passed=$((passed + 1))
            [ "$quiet" = false ] && echo -e "  ${GREEN}✓${NC} func-claude  CLAUDE.md has key governance sections"
        else
            failed=$((failed + 1))
            [ "$quiet" = false ] && echo -e "  ${RED}✗${NC} func-claude  Missing sections: $missing_sections"
        fi
    fi

    # 2d. Onboarding tasks have valid frontmatter
    local active_tasks
    active_tasks=$(ls "$target_dir/.tasks/active/"T-*.md 2>/dev/null | wc -l)
    if [ "$active_tasks" -gt 0 ] && [ "$has_python" = true ]; then
        total=$((total + 1))
        local bad_tasks
        bad_tasks=$(python3 -c "
import yaml, glob
bad = []
for f in glob.glob('$target_dir/.tasks/active/T-*.md'):
    try:
        content = open(f).read()
        parts = content.split('---')
        if len(parts) < 3:
            bad.append(f.split('/')[-1])
            continue
        data = yaml.safe_load(parts[1])
        for key in ['id', 'name', 'status']:
            if key not in data:
                bad.append(f.split('/')[-1])
                break
    except:
        bad.append(f.split('/')[-1])
print(','.join(bad))
" 2>/dev/null)
        if [ -z "$bad_tasks" ]; then
            passed=$((passed + 1))
            [ "$quiet" = false ] && echo -e "  ${GREEN}✓${NC} func-tasks  $active_tasks onboarding tasks have valid frontmatter"
        else
            failed=$((failed + 1))
            [ "$quiet" = false ] && echo -e "  ${RED}✗${NC} func-tasks  Invalid task files: $bad_tasks"
        fi
    fi

    # --- Tier 3: Semantic Checks (T-462) ---
    # Catch knowledge leakage — framework-specific content in consumer projects
    # Only runs when target has .framework.yaml (consumer project, not the framework itself)
    if [ -f "$target_dir/.framework.yaml" ]; then
        [ "$quiet" = false ] && echo "" && echo -e "  ${BOLD}Tier 3: Semantic checks${NC}"

        # 3a. No __PROJECT_NAME__ literals remaining (template substitution worked)
        total=$((total + 1))
        local unsubstituted
        unsubstituted=$(grep -rl '__PROJECT_NAME__' "$target_dir/.tasks/" "$target_dir/CLAUDE.md" 2>/dev/null | wc -l)
        if [ "$unsubstituted" -eq 0 ]; then
            passed=$((passed + 1))
            [ "$quiet" = false ] && echo -e "  ${GREEN}✓${NC} sem-subst  No __PROJECT_NAME__ literals remaining"
        else
            failed=$((failed + 1))
            [ "$quiet" = false ] && echo -e "  ${RED}✗${NC} sem-subst  $unsubstituted file(s) still have __PROJECT_NAME__ placeholder"
        fi

        # 3b. Seeded governance files have no scope: project items
        if [ "$has_python" = true ]; then
            for govfile in decisions.yaml patterns.yaml practices.yaml; do
                local govpath="$target_dir/.context/project/$govfile"
                [ -f "$govpath" ] || continue
                total=$((total + 1))
                local leaked
                leaked=$(python3 -c "
import yaml
with open('$govpath') as f:
    data = yaml.safe_load(f) or {}
leaked = []
for key, items in data.items():
    if not isinstance(items, list):
        continue
    for item in items:
        if isinstance(item, dict) and item.get('scope') == 'project':
            leaked.append(item.get('id', 'unknown'))
print(','.join(leaked))
" 2>/dev/null)
                if [ -z "$leaked" ]; then
                    passed=$((passed + 1))
                    [ "$quiet" = false ] && echo -e "  ${GREEN}✓${NC} sem-scope  $govfile has no scope: project items"
                else
                    failed=$((failed + 1))
                    [ "$quiet" = false ] && echo -e "  ${RED}✗${NC} sem-scope  $govfile has leaked project items: $leaked"
                fi
            done
        fi

        # 3c. .framework.yaml provider matches actual config
        total=$((total + 1))
        local fw_provider
        fw_provider=$(grep "^provider:" "$target_dir/.framework.yaml" 2>/dev/null | sed 's/provider:[[:space:]]*//')
        if [ -n "$fw_provider" ]; then
            local has_config=false
            case "$fw_provider" in
                claude|generic)
                    [ -f "$target_dir/CLAUDE.md" ] && has_config=true
                    ;;
                cursor)
                    [ -f "$target_dir/.cursorrules" ] && has_config=true
                    ;;
            esac
            if [ "$has_config" = true ]; then
                passed=$((passed + 1))
                [ "$quiet" = false ] && echo -e "  ${GREEN}✓${NC} sem-prov   Provider '$fw_provider' matches config files"
            else
                failed=$((failed + 1))
                [ "$quiet" = false ] && echo -e "  ${RED}✗${NC} sem-prov   Provider '$fw_provider' but config file missing"
            fi
        else
            failed=$((failed + 1))
            [ "$quiet" = false ] && echo -e "  ${RED}✗${NC} sem-prov   No provider in .framework.yaml"
        fi

        # 3d. Fabric is clean (no framework internals)
        total=$((total + 1))
        local fabric_count
        fabric_count=$(ls "$target_dir/.fabric/components/"*.yaml 2>/dev/null | wc -l)
        if [ "$fabric_count" -eq 0 ]; then
            passed=$((passed + 1))
            [ "$quiet" = false ] && echo -e "  ${GREEN}✓${NC} sem-fabric Fabric is clean (0 pre-registered components)"
        else
            # Warn, not fail — user may have already registered components
            passed=$((passed + 1))
            [ "$quiet" = false ] && echo -e "  ${YELLOW}!${NC} sem-fabric $fabric_count component(s) in fabric (OK if user-registered)"
        fi
    fi

    # Summary
    if [ "$quiet" = false ]; then
        echo ""
        if [ "$failed" -eq 0 ]; then
            echo -e "  ${GREEN}Validation passed${NC}: $passed/$total checks OK${skipped:+ ($skipped skipped)}"
        else
            echo -e "  ${RED}Validation: $failed error(s)${NC} out of $total checks"
            echo -e "  Run ${BOLD}fw doctor${NC} for detailed diagnostics"
        fi
    fi

    [ "$failed" -eq 0 ]
}
