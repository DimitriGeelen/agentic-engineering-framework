#!/bin/bash
# Fabric Agent - register and scan commands
# Implements: fw fabric register, fw fabric scan


# Excluded directories for recursive registration
_REGISTER_EXCLUDE_DIRS="node_modules|.git|__pycache__|.venv|venv|.env|dist|build|.next|.nuxt|.cache|.tox|.mypy_cache|.pytest_cache|vendor|target"

# Eligible file extensions for recursive registration
_REGISTER_EXTENSIONS="py|sh|js|ts|jsx|tsx|yaml|yml|md|html|css|scss|json|toml|cfg|ini|sql|go|rs|java|rb|php|c|h|cpp|hpp|vue|svelte"

_register_directory() {
    local dir_path="$1"
    local auto_yes="${2:-false}"
    local abs_dir
    abs_dir=$(cd "$dir_path" 2>/dev/null && pwd) || {
        echo -e "${RED}Error: Directory not found: $dir_path${NC}"
        return 1
    }

    # T-551: Preview phase — scan files and show breakdown before creating cards
    local preview_data
    preview_data=$(python3 -c "
import os, re, json

root = '$abs_dir'
project_root = os.path.abspath('$PROJECT_ROOT')
components_dir = '$COMPONENTS_DIR'
ext_re = re.compile(r'\.($_REGISTER_EXTENSIONS)$')

subsystems = {}
total = 0
new_files = 0
skipped = 0

for dirpath, dirnames, filenames in os.walk(root):
    dirnames[:] = [d for d in dirnames if not re.match(r'^($_REGISTER_EXCLUDE_DIRS)$', d)]
    for f in sorted(filenames):
        if not ext_re.search(f):
            continue
        total += 1
        full = os.path.join(dirpath, f)
        rel = os.path.relpath(full, project_root)
        slug = rel.replace('/', '-').rsplit('.', 1)[0].lstrip('.')
        if os.path.isfile(os.path.join(components_dir, slug + '.yaml')):
            skipped += 1
            continue
        new_files += 1
        # Infer subsystem from path prefix
        parts = rel.split('/')
        ss = parts[0] if len(parts) > 1 else 'root'
        subsystems[ss] = subsystems.get(ss, 0) + 1

print(json.dumps({'total': total, 'new': new_files, 'skipped': skipped, 'subsystems': subsystems}))
" 2>/dev/null)

    if [ -z "$preview_data" ]; then
        echo -e "${RED}Error: Failed to scan directory${NC}"
        return 1
    fi

    local new_count skipped_count total_count
    new_count=$(echo "$preview_data" | python3 -c "import sys,json; print(json.load(sys.stdin)['new'])")
    skipped_count=$(echo "$preview_data" | python3 -c "import sys,json; print(json.load(sys.stdin)['skipped'])")
    total_count=$(echo "$preview_data" | python3 -c "import sys,json; print(json.load(sys.stdin)['total'])")

    echo -e "${BOLD}=== Fabric Register Preview ===${NC}"
    echo "  Directory: $dir_path"
    echo "  Total eligible files: $total_count"
    echo "  Already registered:   $skipped_count"
    echo -e "  ${GREEN}New to register:        $new_count${NC}"

    if [ "$new_count" -eq 0 ]; then
        echo ""
        echo "Nothing new to register."
        return 0
    fi

    echo ""
    echo -e "${BOLD}Subsystem breakdown:${NC}"
    echo "$preview_data" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for ss, count in sorted(data['subsystems'].items(), key=lambda x: -x[1]):
    print(f'  {ss:30s} {count:4d} files')
"

    # Gate: require --yes for directory registration
    if [ "$auto_yes" != "true" ]; then
        echo ""
        echo -e "${YELLOW}Preview only.${NC} To proceed, run:"
        echo "  fw fabric register $dir_path --yes"
        return 0
    fi

    # Proceed with registration
    echo ""
    echo "Registering $new_count components..."

    local created=0
    local excluded=0

    while IFS= read -r file; do
        [ -z "$file" ] && continue
        local rel
        rel=$(python3 -c "import os; print(os.path.relpath('$file', os.path.abspath('$PROJECT_ROOT')))" 2>/dev/null || echo "$file")

        local slug
        slug=$(echo "$rel" | sed 's|/|-|g; s|\..*$||; s|^\.||')
        if [ -f "$COMPONENTS_DIR/${slug}.yaml" ]; then
            continue
        fi

        _do_register_file "$rel" > /dev/null 2>&1 && created=$((created + 1)) || excluded=$((excluded + 1))
    done < <(python3 -c "
import os, re
root = '$abs_dir'
ext_re = re.compile(r'\.($_REGISTER_EXTENSIONS)$')
for dirpath, dirnames, filenames in os.walk(root):
    dirnames[:] = [d for d in dirnames if not re.match(r'^($_REGISTER_EXCLUDE_DIRS)$', d)]
    for f in sorted(filenames):
        if ext_re.search(f):
            print(os.path.join(dirpath, f))
" 2>/dev/null)

    echo -e "${GREEN}Directory registration complete${NC}"
    echo "  Registered: $created new component cards"
    [ "$excluded" -gt 0 ] && echo "  Errors:     $excluded files could not be registered"

    if [ "$created" -gt 0 ]; then
        echo ""
        echo -e "${CYAN}Auto-enriching new cards...${NC}"
        python3 "$LIB_DIR/enrich.py" 2>/dev/null || true
    fi
}

do_register() {
    ensure_fabric_dirs

    local file_path="" auto_yes=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --yes|-y) auto_yes=true; shift ;;
            *) file_path="$1"; shift ;;
        esac
    done

    if [ -z "$file_path" ]; then
        echo -e "${RED}Error: File or directory path required${NC}"
        echo "Usage: fw fabric register <file-or-dir> [--yes]"
        exit 1
    fi

    # If it's a directory, register with preview gate (T-551)
    local abs_path
    abs_path=$(cd "$file_path" 2>/dev/null && pwd || echo "$PROJECT_ROOT/$file_path")
    if [ -d "$abs_path" ] || [ -d "$file_path" ]; then
        _register_directory "${file_path}" "$auto_yes"
        return $?
    fi

    # Single file mode — no gate
    _do_register_file "$file_path"
}

_do_register_file() {
    local rel_path="$1"

    if [ ! -f "$PROJECT_ROOT/$rel_path" ]; then
        return 1
    fi

    # Generate component slug from path
    local slug
    slug=$(echo "$rel_path" | sed 's|/|-|g; s|\..*$||; s|^\.||')

    local card_file="$COMPONENTS_DIR/${slug}.yaml"
    if [ -f "$card_file" ]; then
        echo -e "${YELLOW}Card already exists: $card_file${NC}"
        return 0
    fi

    # Check for project-specific subsystem rules (T-369)
    local rules_file="$FABRIC_DIR/subsystem-rules.yaml"
    local comp_type=""
    local subsystem=""
    if [ -f "$rules_file" ]; then
        local rule_result
        rule_result=$(python3 -c "
import yaml, fnmatch
with open('$rules_file') as f:
    data = yaml.safe_load(f)
rules = data.get('rules', []) if data else []
for r in rules:
    if fnmatch.fnmatch('$rel_path', r.get('pattern', '')):
        print(r.get('type', ''), r.get('subsystem', ''))
        break
else:
    print('')
" 2>/dev/null || echo "")
        if [ -n "$rule_result" ]; then
            comp_type=$(echo "$rule_result" | awk '{print $1}')
            subsystem=$(echo "$rule_result" | awk '{print $2}')
        fi
    fi

    # Infer type from path (fallback if no rule matched)
    if [ -z "$comp_type" ]; then
        comp_type="script"
        case "$rel_path" in
            web/blueprints/*.py) comp_type="route" ;;
            web/templates/_*.html) comp_type="fragment" ;;
            web/templates/*.html) comp_type="template" ;;
            .context/project/*.yaml|.context/working/*) comp_type="data" ;;
            .claude/*) comp_type="config" ;;
            *.yaml|*.json) comp_type="config" ;;
        esac
    fi

    # Infer subsystem from path (fallback if no rule matched)
    if [ -z "$subsystem" ]; then
        subsystem="unknown"
        case "$rel_path" in
            agents/context/*) subsystem="context-fabric" ;;
            agents/audit/*) subsystem="audit" ;;
            agents/git/*) subsystem="git-traceability" ;;
            agents/handover/*) subsystem="handover" ;;
            agents/healing/*) subsystem="healing" ;;
            agents/fabric/*) subsystem="component-fabric" ;;
            agents/task-create/*) subsystem="task-management" ;;
            web/*) subsystem="watchtower" ;;
            lib/*) subsystem="framework-core" ;;
            bin/*) subsystem="framework-core" ;;
        esac
    fi

    # Infer name from filename
    local name
    name=$(basename "$rel_path" | sed 's/\.[^.]*$//')

    # Create skeleton card
    cat > "$card_file" << EOF
id: $rel_path
name: $name
type: $comp_type
subsystem: $subsystem
location: $rel_path
tags: []

purpose: "TODO: describe what this component does"

depends_on:
  # Format: - target: <relative-path>
  #          type: calls|reads|writes|triggers|renders
  []

depended_by:
  # Same format as depends_on — filled by enrich.py or manually
  []

last_verified: $(date -u +%Y-%m-%d)
created_by: ${CURRENT_TASK:-unknown}
EOF

    echo -e "${GREEN}Card created: $card_file${NC}"
    echo "  Type: $comp_type"
    echo "  Subsystem: $subsystem"
    return 0
}

do_scan() {
    ensure_fabric_dirs

    local watch_file="$FABRIC_DIR/watch-patterns.yaml"
    if [ ! -f "$watch_file" ]; then
        echo -e "${RED}Error: No watch-patterns.yaml found${NC}"
        echo "Create .fabric/watch-patterns.yaml first"
        exit 1
    fi

    # Get all registered locations
    local registered
    registered=$(grep "^location:" "$COMPONENTS_DIR"/*.yaml 2>/dev/null | sed 's/.*location: //' | sort -u)

    # Parse watch patterns and find unregistered files
    local created=0
    local skipped=0

    while IFS= read -r glob_pattern; do
        [ -z "$glob_pattern" ] && continue
        for file in $glob_pattern; do
            [ -f "$file" ] || continue
            local rel_path
            rel_path=$(python3 -c "import os; print(os.path.relpath(os.path.abspath('$file'), os.path.abspath('$PROJECT_ROOT')))" 2>/dev/null || echo "$file")
            if echo "$registered" | grep -qx "$rel_path" 2>/dev/null; then
                skipped=$((skipped + 1))
            else
                # Create skeleton via register
                do_register "$rel_path" > /dev/null 2>&1 && created=$((created + 1)) || true
            fi
        done
    done < <(python3 -c "
import yaml
with open('$watch_file') as f:
    data = yaml.safe_load(f)
for p in data.get('patterns', []):
    print(p['glob'])
")

    echo -e "${GREEN}Scan complete${NC}"
    echo "  Created: $created skeleton cards"
    echo "  Skipped: $skipped already registered"
    if [ "$created" -gt 0 ]; then
        echo ""
        echo -e "${CYAN}Auto-enriching new cards...${NC}"
        python3 "$LIB_DIR/enrich.py"
    fi
    return 0
}
