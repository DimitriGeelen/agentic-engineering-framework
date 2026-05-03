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
        # T-1320: enable recursive ** matching to align with fw audit (Python glob).
        shopt -s globstar nullglob 2>/dev/null || true
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
        loc=$({ grep "^location:" "$card" 2>/dev/null || true; } | head -1 | sed 's/^location: //')
        # T-1673: handle absolute paths (cross-repo cards from T-1652) — don't
        # join with PROJECT_ROOT when the location is already absolute.
        local resolved
        if [ -n "$loc" ] && [ "${loc:0:1}" = "/" ]; then
            resolved="$loc"
        else
            resolved="$PROJECT_ROOT/$loc"
        fi
        if [ -n "$loc" ] && [ ! -f "$resolved" ]; then
            local name
            name=$({ grep "^name:" "$card" 2>/dev/null || true; } | head -1 | sed 's/^name: //')
            echo "  ! $name → $loc (file missing)"
            orphaned=$((orphaned + 1))
        fi
    done
    [ "$orphaned" -eq 0 ] && echo "  (none)"

    echo ""

    # 3. Check for stale edges (depends_on targets that don't resolve)
    # T-1674: single python3 pass instead of 2 spawns × N cards (was ~11min on
    # 508 cards). Stdout = unresolved lines for the operator. The count comes
    # back via a final ##STALE_COUNT=N## sentinel which we strip before
    # printing. Output lines preserved byte-for-byte vs the prior impl.
    echo -e "${CYAN}Stale edges:${NC}"
    local _stale_raw _stale_count=0
    _stale_raw=$(python3 - "$COMPONENTS_DIR" <<'PYEOF' 2>/dev/null
import glob, sys, yaml

components_dir = sys.argv[1]
SKIP = {'fw-cli', 'cron-audit', 'transcript',
        'check-active-task', 'check-tier0', 'error-watchdog'}

cards = []
known = set()
for cp in sorted(glob.glob(f"{components_dir}/*.yaml")):
    try:
        with open(cp) as cf:
            cd = yaml.safe_load(cf)
    except Exception:
        continue
    if not cd:
        continue
    cards.append(cd)
    known.add(cd.get('id', ''))
    known.add(cd.get('name', ''))
    known.add(cd.get('location', ''))

count = 0
for cd in cards:
    name = cd.get('name', '')
    for dep in cd.get('depends_on', []) or []:
        target = (dep or {}).get('target', '') if isinstance(dep, dict) else ''
        if not target or target in known or target.startswith('all ') or target in SKIP:
            continue
        print(f"  ! {name} → {target} (unresolved)")
        count += 1
print(f"##STALE_COUNT={count}##")
PYEOF
    )
    if [ -n "$_stale_raw" ]; then
        # Last line is the sentinel; everything before is operator output.
        local _stale_lines
        _stale_lines=$(printf '%s\n' "$_stale_raw" | sed '$d')
        _stale_count=$(printf '%s\n' "$_stale_raw" | tail -1 | sed -n 's/^##STALE_COUNT=\([0-9]*\)##$/\1/p')
        : "${_stale_count:=0}"
        if [ -n "$_stale_lines" ]; then
            printf '%s\n' "$_stale_lines"
        fi
    fi
    stale=$((stale + _stale_count))
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
            name=$({ grep "^name:" "$card" 2>/dev/null || true; } | head -1 | sed 's/^name: //')
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
