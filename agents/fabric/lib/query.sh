#!/bin/bash
# Fabric Agent - query commands
# Implements: fw fabric search, fw fabric get, fw fabric deps

do_search() {
    ensure_fabric_dirs

    local keyword="${1:-}"
    if [ -z "$keyword" ]; then
        echo -e "${RED}Error: Search keyword required${NC}"
        echo "Usage: fw fabric search <keyword>"
        exit 1
    fi

    local found=0
    echo -e "${BOLD}Search: \"$keyword\"${NC}"
    echo ""

    for card in "$COMPONENTS_DIR"/*.yaml; do
        [ -f "$card" ] || continue
        if grep -qi "$keyword" "$card" 2>/dev/null; then
            local name loc purpose comp_type subsystem
            name=$(grep "^name:" "$card" | head -1 | sed 's/^name: //')
            loc=$(grep "^location:" "$card" | head -1 | sed 's/^location: //')
            purpose=$(grep "^purpose:" "$card" | head -1 | sed 's/^purpose: //' | tr -d '"')
            comp_type=$(grep "^type:" "$card" | head -1 | sed 's/^type: //')
            subsystem=$(grep "^subsystem:" "$card" | head -1 | sed 's/^subsystem: //')
            echo -e "  ${GREEN}$name${NC} ($comp_type, $subsystem)"
            echo "    $loc"
            echo "    $purpose"
            echo ""
            found=$((found + 1))
        fi
    done

    if [ "$found" -eq 0 ]; then
        echo "  No components match \"$keyword\""
    else
        echo "$found component(s) found"
    fi
    return 0
}

do_get() {
    ensure_fabric_dirs

    local query="${1:-}"
    if [ -z "$query" ]; then
        echo -e "${RED}Error: Component name or path required${NC}"
        echo "Usage: fw fabric get <name-or-path>"
        exit 1
    fi

    # Find card by name, id, or location
    local card_file=""
    for card in "$COMPONENTS_DIR"/*.yaml; do
        [ -f "$card" ] || continue
        if grep -q "^name: $query" "$card" 2>/dev/null || \
           grep -q "^id: $query" "$card" 2>/dev/null || \
           grep -q "^location: $query" "$card" 2>/dev/null; then
            card_file="$card"
            break
        fi
    done

    if [ -z "$card_file" ]; then
        echo -e "${RED}No component found matching: $query${NC}"
        echo "Try: fw fabric search $query"
        return 1
    fi

    cat "$card_file"
    return 0
}

do_deps() {
    ensure_fabric_dirs

    local file_path="${1:-}"
    if [ -z "$file_path" ]; then
        echo -e "${RED}Error: File path required${NC}"
        echo "Usage: fw fabric deps <file-path>"
        exit 1
    fi

    # Normalize path
    local rel_path
    rel_path=$(realpath --relative-to="$PROJECT_ROOT" "$file_path" 2>/dev/null || echo "$file_path")

    # Find the component card
    local card_file=""
    local comp_name=""
    for card in "$COMPONENTS_DIR"/*.yaml; do
        [ -f "$card" ] || continue
        if grep -q "^location: $rel_path" "$card" 2>/dev/null || \
           grep -q "^id: $rel_path" "$card" 2>/dev/null; then
            card_file="$card"
            comp_name=$(grep "^name:" "$card" | head -1 | sed 's/^name: //')
            break
        fi
    done

    if [ -z "$card_file" ]; then
        echo -e "${YELLOW}No card found for: $rel_path${NC}"
        echo "Register it: fw fabric register $rel_path"
        return 1
    fi

    echo -e "${BOLD}Dependencies for: $comp_name${NC} ($rel_path)"
    echo ""

    # Forward deps (what this component depends on)
    echo -e "${CYAN}Depends on:${NC}"
    python3 -c "
import yaml
with open('$card_file') as f:
    data = yaml.safe_load(f)
deps = data.get('depends_on', [])
if not deps:
    print('  (none)')
else:
    for d in deps:
        target = d.get('target', '?')
        dtype = d.get('type', '?')
        loc = d.get('location', '')
        print(f'  {dtype} → {target}' + (f'  ({loc})' if loc else ''))
" 2>/dev/null

    echo ""

    # Reverse deps (what depends on this component)
    echo -e "${CYAN}Depended by:${NC}"
    local comp_id
    comp_id=$(grep "^id:" "$card_file" | head -1 | sed 's/^id: //')

    local reverse_found=0
    for card in "$COMPONENTS_DIR"/*.yaml; do
        [ -f "$card" ] || continue
        [ "$card" = "$card_file" ] && continue
        if grep -q "target:.*$comp_id\|target:.*$comp_name\|target:.*$rel_path" "$card" 2>/dev/null; then
            local dep_name dep_type
            dep_name=$(grep "^name:" "$card" | head -1 | sed 's/^name: //')
            dep_type=$(grep -A1 "target:.*$comp_id\|target:.*$comp_name\|target:.*$rel_path" "$card" | grep "type:" | head -1 | sed 's/.*type: //')
            echo "  ${dep_type:-uses} ← $dep_name"
            reverse_found=$((reverse_found + 1))
        fi
    done
    [ "$reverse_found" -eq 0 ] && echo "  (none found — may need card enrichment)"

    return 0
}
