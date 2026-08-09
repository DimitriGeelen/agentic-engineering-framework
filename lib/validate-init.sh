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
    local has_node=false
    command -v node >/dev/null 2>&1 && has_node=true
    local fw_util="$FRAMEWORK_ROOT/lib/ts/dist/fw-util.js"

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
        desc_line="${desc_line#"${desc_line%%[![:space:]]*}"}"

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
                        # T-2726: this skip is legitimate (the check is scoped to
                        # another provider) but it used to print nothing at all,
                        # so the summary counted 42 while only 41 rows were
                        # visible and no reader could tell which check was
                        # absent. A skip that leaves no row makes an absence
                        # unrepresentable (L-525); the git-condition branch above
                        # already prints one.
                        [ "$quiet" = false ] && echo -e "  ${CYAN}-${NC} ${type_key}  ${desc_line} (skipped: provider '${provider}' not in ${condition})"
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

            # T-2726: `md` was declared in the manifest (md-3bv
            # policy/bvp-scoring-rubric.md) with no evaluator, so it fell to the
            # `*)` fallthrough and was counted-but-never-run. A markdown artifact
            # wants exactly the file contract — exists and is non-empty — so it
            # is served here rather than by an alias branch that would add a type
            # without adding behaviour.
            file|md)
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
                elif [ "$has_node" = true ] && [ -f "$fw_util" ]; then
                    if ! node "$fw_util" yaml-get "$full_path" __validate 2>/dev/null >/dev/null; then
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
                elif [ "$has_node" = true ] && [ -f "$fw_util" ]; then
                    if ! node "$fw_util" json-get "$full_path" __validate 2>/dev/null >/dev/null; then
                        detail="invalid JSON"
                    elif [ -n "$check_args" ]; then
                        local missing=""
                        IFS=',' read -ra keys <<< "$check_args"
                        for key in "${keys[@]}"; do
                            if ! node "$fw_util" json-get "$full_path" "$key" 2>/dev/null >/dev/null; then
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
                    broken=$(VALIDATE_FILE="$full_path" VALIDATE_ROOT="$target_dir" python3 -c "
import json, os, shutil
# T-2724: hook commands are written by fw init as
# '\${CLAUDE_PROJECT_DIR}/.agentic-framework/bin/fw hook <event>'. Without expansion,
# os.path.exists() is handed that literal and every correct install reports 19 broken
# hooks named 'fw' (the basename of the unexpanded string). expandvars handles both
# \$VAR and \${VAR}, and deliberately leaves UNKNOWN variables untouched so an
# unresolvable path still fails rather than silently passing.
os.environ['CLAUDE_PROJECT_DIR'] = os.environ['VALIDATE_ROOT']
with open(os.environ['VALIDATE_FILE']) as f:
    data = json.load(f)
for event, entries in data.get('hooks', {}).items():
    for entry in entries:
        for hook in entry.get('hooks', []):
            cmd = hook.get('command', '')
            parts = cmd.split()
            script = next((p for p in parts if '=' not in p), '')
            script = os.path.expandvars(script) if script else script
            # T-2725: a bare command with no '/' is an interpreter/wrapper
            # ('bash \${CLAUDE_PROJECT_DIR}/x.sh'), not a path. Resolve it on PATH —
            # os.path.exists('bash') is False and would report a valid hook broken,
            # the same false positive T-2724 fixed for the \${CLAUDE_PROJECT_DIR} form
            # surviving under a different carrier shape. Unoccupied in this repo today
            # but reachable, so this is an occupancy zero, not a capability one.
            if script and '/' not in script:
                script = shutil.which(script) or script
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
                # T-2726: a declared check the evaluator cannot serve is a defect
                # in the manifest/evaluator join — not a property of the target
                # tree, and not a condition-based skip. Absorbing it into
                # `skipped` left the verdict green (the function returns
                # `[ "$failed" -eq 0 ]`) while `total` had already been
                # incremented, so the run reported success about a check it never
                # ran. Falling through with the default result="fail" turns it red
                # and prints it on stdout with the other verdict lines; it used to
                # go to stderr, invisible in any captured log.
                detail="unknown check type '${check_type}' — no evaluator in validate-init.sh"
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
        broken_hooks=$(VALIDATE_FILE="$settings_file" VALIDATE_ROOT="$target_dir" python3 -c "
import json, os, shutil
# T-2724: see the matching comment on the hookpaths check above — same unexpanded
# \${CLAUDE_PROJECT_DIR} defect, same fix. Both sites must stay in step; a fix to one
# alone leaves the other reporting 19 phantom 'fw' entries.
os.environ['CLAUDE_PROJECT_DIR'] = os.environ['VALIDATE_ROOT']
with open(os.environ['VALIDATE_FILE']) as f:
    data = json.load(f)
broken = []
for event, entries in data.get('hooks', {}).items():
    for entry in entries:
        for hook in entry.get('hooks', []):
            cmd = hook.get('command', '')
            parts = cmd.split()
            script = next((p for p in parts if '=' not in p), '')
            script = os.path.expandvars(script) if script else script
            # T-2725: a bare command with no '/' is an interpreter/wrapper
            # ('bash \${CLAUDE_PROJECT_DIR}/x.sh'), not a path. Resolve it on PATH —
            # os.path.exists('bash') is False and would report a valid hook broken,
            # the same false positive T-2724 fixed for the \${CLAUDE_PROJECT_DIR} form
            # surviving under a different carrier shape. Unoccupied in this repo today
            # but reachable, so this is an occupancy zero, not a capability one.
            if script and '/' not in script:
                script = shutil.which(script) or script
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

    # 2b-bis. Vendored framework is complete (T-2805)
    #
    # Nothing here validated the framework copy itself, so `fw init` over a partial
    # vendor printed "Validation passed: 42/43" while .agentic-framework/ held no
    # FRAMEWORK.md and no VERSION. 43 green checks, every one of them about files
    # init writes, none about the ~90MB of framework they depend on — the checks
    # were all true and the project was broken.
    #
    # FRAMEWORK.md is the sentinel do_vendor writes last and bin/fw resolves
    # FRAMEWORK_ROOT by; the rest are the pieces whose absence produces a
    # confusing failure rather than a clear one.
    if [ -d "$target_dir/.agentic-framework" ]; then
        total=$((total + 1))
        local missing_vendor=""
        for _part in FRAMEWORK.md VERSION bin/fw lib agents; do
            [ -e "$target_dir/.agentic-framework/$_part" ] || \
                missing_vendor="${missing_vendor:+$missing_vendor, }$_part"
        done
        if [ -z "$missing_vendor" ]; then
            passed=$((passed + 1))
            [ "$quiet" = false ] && echo -e "  ${GREEN}✓${NC} func-vendor Vendored framework is complete"
        else
            failed=$((failed + 1))
            [ "$quiet" = false ] && {
                echo -e "  ${RED}✗${NC} func-vendor Vendored framework INCOMPLETE — missing: $missing_vendor"
                echo -e "       Re-vendor with: fw init --force  (or: fw vendor)"
            }
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
    active_tasks=$(find "$target_dir/.tasks/active" -maxdepth 1 -name 'T-*.md' -type f 2>/dev/null | wc -l)
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

    # 2f. Git identity resolves (T-2818 / OBS-170)
    #
    # Without one, `git commit` dies RC=128 "Author identity unknown" before any
    # framework hook runs, so onboarding task T-003 ("First governed commit") cannot
    # be completed. The tally is the line operators read as the verdict, and on a
    # fresh machine it said "Validation passed: 43/44" about a project that could not
    # commit — 44 checks, none of them about the one condition blocking the next step.
    #
    # Warn-shaped, counted as passed, following the sem-fabric precedent below: this
    # is HOST state, not project state (`fw doctor` scopes it [host] for the same
    # reason). Re-running after `git config user.email` flips it green with no
    # re-init, and failing here would redden every CI job that legitimately runs
    # without an identity — training people to ignore validation output, which is
    # the exact failure mode this check exists to prevent.
    total=$((total + 1))
    passed=$((passed + 1))
    # T-2883: "resolves" now means what the word says — `git var GIT_COMMITTER_IDENT`,
    # the same resolution `git commit` performs. The old `git config user.email` read
    # called an env-supplied identity missing and told a machine that commits fine
    # that its commits would fail.
    source "$(dirname "${BASH_SOURCE[0]}")/git-identity.sh"
    if fw_git_identity_ok "$target_dir"; then
        [ "$quiet" = false ] && echo -e "  ${GREEN}✓${NC} func-identity Git identity resolves"
    else
        [ "$quiet" = false ] && {
            echo -e "  ${YELLOW}!${NC} func-identity Git identity not set — commits will fail (host, not project)"
            echo -e "       $(fw_git_identity_remedy "$target_dir")"
        }
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
                leaked=$(VALIDATE_FILE="$govpath" python3 -c "
import yaml, os
with open(os.environ['VALIDATE_FILE']) as f:
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
        fabric_count=$(find "$target_dir/.fabric/components" -maxdepth 1 -name '*.yaml' -type f 2>/dev/null | wc -l)
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
