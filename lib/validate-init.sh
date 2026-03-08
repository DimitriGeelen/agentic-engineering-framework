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
