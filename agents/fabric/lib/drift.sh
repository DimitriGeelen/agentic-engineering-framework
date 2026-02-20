#!/bin/bash
# Fabric Agent - drift detection commands
# Implements: fw fabric drift, fw fabric validate

do_drift() {
    ensure_fabric_dirs

    local watch_file="$FABRIC_DIR/watch-patterns.yaml"
    local summary_flag="${1:-}"

    echo -e "${BOLD}Fabric Drift Report${NC}"
    echo ""

    # 1. Check for unregistered files
    local unregistered=0
    local orphaned=0
    local stale=0

    if [ -f "$watch_file" ]; then
        local registered
        registered=$(grep "^location:" "$COMPONENTS_DIR"/*.yaml 2>/dev/null | sed 's/.*location: //' | sort -u)

        echo -e "${CYAN}Unregistered components:${NC}"
        while IFS= read -r glob_pattern; do
            [ -z "$glob_pattern" ] && continue
            for file in $glob_pattern; do
                [ -f "$file" ] || continue
                local rel_path
                rel_path=$(realpath --relative-to="$PROJECT_ROOT" "$file" 2>/dev/null || echo "$file")
                if ! echo "$registered" | grep -qx "$rel_path" 2>/dev/null; then
                    echo "  ! $rel_path"
                    unregistered=$((unregistered + 1))
                fi
            done
        done < <(python3 -c "
import yaml
with open('$watch_file') as f:
    data = yaml.safe_load(f)
for p in data.get('patterns', []):
    print(p['glob'])
" 2>/dev/null)
        [ "$unregistered" -eq 0 ] && echo "  (none)"
    fi

    echo ""

    # 2. Check for orphaned cards (file referenced doesn't exist)
    echo -e "${CYAN}Orphaned cards:${NC}"
    for card in "$COMPONENTS_DIR"/*.yaml; do
        [ -f "$card" ] || continue
        local loc
        loc=$(grep "^location:" "$card" | head -1 | sed 's/^location: //')
        if [ -n "$loc" ] && [ ! -f "$PROJECT_ROOT/$loc" ]; then
            local name
            name=$(grep "^name:" "$card" | head -1 | sed 's/^name: //')
            echo "  ! $name → $loc (file missing)"
            orphaned=$((orphaned + 1))
        fi
    done
    [ "$orphaned" -eq 0 ] && echo "  (none)"

    echo ""

    # 3. Check for stale edges (depends_on targets that don't resolve)
    echo -e "${CYAN}Stale edges:${NC}"
    for card in "$COMPONENTS_DIR"/*.yaml; do
        [ -f "$card" ] || continue
        local card_name
        card_name=$(grep "^name:" "$card" | head -1 | sed 's/^name: //')

        python3 -c "
import yaml, glob, os
with open('$card') as f:
    data = yaml.safe_load(f)
# Collect all known IDs
known = set()
for cp in glob.glob('$COMPONENTS_DIR/*.yaml'):
    with open(cp) as cf:
        cd = yaml.safe_load(cf)
    if cd:
        known.add(cd.get('id', ''))
        known.add(cd.get('name', ''))
        known.add(cd.get('location', ''))
# Check depends_on targets
for dep in data.get('depends_on', []):
    target = dep.get('target', '')
    if target and target not in known and not target.startswith('all ') and target not in ('fw-cli', 'cron-audit', 'transcript', 'check-active-task', 'check-tier0', 'error-watchdog'):
        print(f'  ! $card_name → {target} (unresolved)')
" 2>/dev/null && stale=$((stale + $(python3 -c "
import yaml, glob
with open('$card') as f:
    data = yaml.safe_load(f)
known = set()
for cp in glob.glob('$COMPONENTS_DIR/*.yaml'):
    with open(cp) as cf:
        cd = yaml.safe_load(cf)
    if cd:
        known.add(cd.get('id', ''))
        known.add(cd.get('name', ''))
        known.add(cd.get('location', ''))
count = 0
for dep in data.get('depends_on', []):
    target = dep.get('target', '')
    if target and target not in known and not target.startswith('all ') and target not in ('fw-cli', 'cron-audit', 'transcript', 'check-active-task', 'check-tier0', 'error-watchdog'):
        count += 1
print(count)
" 2>/dev/null || echo 0)))
    done
    [ "$stale" -eq 0 ] && echo "  (none)"

    echo ""
    echo -e "${BOLD}Summary:${NC} unregistered: $unregistered, orphaned: $orphaned, stale: $stale"

    if [ "$summary_flag" = "--summary" ]; then
        echo "unregistered: $unregistered"
        echo "orphaned: $orphaned"
        echo "stale: $stale"
    fi

    return 0
}

do_validate() {
    ensure_fabric_dirs

    local component="${1:-}"
    if [ -z "$component" ]; then
        echo "Validating all components..."
        for card in "$COMPONENTS_DIR"/*.yaml; do
            [ -f "$card" ] || continue
            local name
            name=$(grep "^name:" "$card" | head -1 | sed 's/^name: //')
            echo -e "${CYAN}$name${NC}: checking..."
            # TODO: deep validation per card
        done
    else
        echo "Validating: $component"
        # TODO: deep validation for specific component
    fi
    echo -e "${YELLOW}Deep validation not yet implemented — use 'fw fabric drift' for basic checks${NC}"
    return 0
}
