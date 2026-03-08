#!/bin/bash
# Fabric Agent - register and scan commands
# Implements: fw fabric register, fw fabric scan

do_register() {
    ensure_fabric_dirs

    local file_path="${1:-}"
    if [ -z "$file_path" ]; then
        echo -e "${RED}Error: File path required${NC}"
        echo "Usage: fw fabric register <file-path>"
        exit 1
    fi

    # Resolve to relative path from project root
    local rel_path
    rel_path=$(python3 -c "import os; print(os.path.relpath(os.path.abspath('$file_path'), os.path.abspath('$PROJECT_ROOT')))" 2>/dev/null || echo "$file_path")

    if [ ! -f "$PROJECT_ROOT/$rel_path" ]; then
        echo -e "${RED}Error: File not found: $rel_path${NC}"
        exit 1
    fi

    # Generate component slug from path
    local slug
    slug=$(echo "$rel_path" | sed 's|/|-|g; s|\..*$||; s|^\.||')

    local card_file="$COMPONENTS_DIR/${slug}.yaml"
    if [ -f "$card_file" ]; then
        echo -e "${YELLOW}Card already exists: $card_file${NC}"
        echo "Use 'fw fabric get $rel_path' to view it"
        return 0
    fi

    # Infer type from path
    local comp_type="script"
    case "$rel_path" in
        web/blueprints/*.py) comp_type="route" ;;
        web/templates/_*.html) comp_type="fragment" ;;
        web/templates/*.html) comp_type="template" ;;
        .context/project/*.yaml|.context/working/*) comp_type="data" ;;
        .claude/*) comp_type="config" ;;
        *.yaml|*.json) comp_type="config" ;;
    esac

    # Infer subsystem from path
    local subsystem="unknown"
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
    echo -e "  ${YELLOW}Fill in: purpose, depends_on (use {target: path, type: calls} format), tags${NC}"
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
