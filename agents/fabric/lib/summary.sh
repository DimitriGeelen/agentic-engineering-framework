#!/bin/bash
# Fabric Agent - summary and onboarding commands
# Implements: fw fabric overview, fw fabric subsystem, fw fabric stats

do_overview() {
    ensure_fabric_dirs

    local subsystems_file="$FABRIC_DIR/subsystems.yaml"
    local compact="${1:-}"

    if [ ! -f "$subsystems_file" ]; then
        echo -e "${YELLOW}No subsystems.yaml found${NC}"
        echo "Create .fabric/subsystems.yaml to enable onboarding overview"
        return 1
    fi

    # Count components and edges
    local comp_count=0
    local edge_count=0
    for card in "$COMPONENTS_DIR"/*.yaml; do
        [ -f "$card" ] || continue
        comp_count=$((comp_count + 1))
        local deps
        deps=$(grep -c "^[[:space:]]*- target:" "$card" 2>/dev/null || true)
        deps=$(echo "$deps" | tr -d '[:space:]')
        [ -z "$deps" ] && deps=0
        edge_count=$((edge_count + deps))
    done

    python3 -c "
import yaml, os, glob

with open('$subsystems_file') as f:
    data = yaml.safe_load(f)

subsystems = data.get('subsystems', [])

# Derive actual counts from component cards
actual_counts = {}
for card_path in glob.glob('$COMPONENTS_DIR/*.yaml'):
    try:
        with open(card_path) as cf:
            card = yaml.safe_load(cf)
        sid = card.get('subsystem', 'unknown')
        actual_counts[sid] = actual_counts.get(sid, 0) + 1
    except Exception:
        pass

# Add missing subsystems discovered from cards
registered_ids = {s['id'] for s in subsystems}
for sid in sorted(actual_counts):
    if sid not in registered_ids:
        subsystems.append({
            'id': sid,
            'name': sid.replace('-', ' ').title(),
            'summary': '(auto-discovered)',
        })

sub_count = len(subsystems)
print(f'## System Topology')
print(f'{sub_count} subsystems, $comp_count components, $edge_count edges')
print()

for s in subsystems:
    name = s.get('name', '?')
    count = actual_counts.get(s['id'], 0)
    summary = s.get('summary', '')
    print(f'**{name}** ({count} components): {summary}')
" 2>/dev/null

    return 0
}

do_subsystem() {
    ensure_fabric_dirs

    local sub_id="${1:-}"
    if [ -z "$sub_id" ]; then
        echo -e "${RED}Error: Subsystem ID required${NC}"
        echo "Usage: fw fabric subsystem <id>"
        echo ""
        echo "Available subsystems:"
        python3 -c "
import yaml
with open('$FABRIC_DIR/subsystems.yaml') as f:
    data = yaml.safe_load(f)
for s in data.get('subsystems', []):
    print(f\"  {s['id']}: {s['name']}\")
" 2>/dev/null
        return 1
    fi

    # Show subsystem detail
    python3 -c "
import yaml
with open('$FABRIC_DIR/subsystems.yaml') as f:
    data = yaml.safe_load(f)
for s in data.get('subsystems', []):
    if s['id'] == '$sub_id':
        print(f\"Subsystem: {s['name']}\")
        print(f\"Purpose: {s['purpose']}\")
        print(f\"Summary: {s['summary']}\")
        print()
        print('Components:')
        for c in s.get('components', []):
            print(f'  - {c}')
        if s.get('entry_points'):
            print()
            print('Entry points:')
            for ep in s['entry_points']:
                print(f'  - {ep}')
        break
else:
    print(f'Subsystem not found: $sub_id')
" 2>/dev/null

    return 0
}

do_stats() {
    ensure_fabric_dirs

    local comp_count=0
    local edge_count=0
    local types=""

    for card in "$COMPONENTS_DIR"/*.yaml; do
        [ -f "$card" ] || continue
        comp_count=$((comp_count + 1))
        local deps
        deps=$(grep -c "^[[:space:]]*- target:" "$card" 2>/dev/null || true)
        deps=$(echo "$deps" | tr -d '[:space:]')
        [ -z "$deps" ] && deps=0
        edge_count=$((edge_count + deps))
        local t
        t=$(grep "^type:" "$card" | head -1 | sed 's/^type: //')
        types="$types $t"
    done

    echo -e "${BOLD}Fabric Stats${NC}"
    echo ""
    echo "  Components: $comp_count"
    echo "  Edges: $edge_count"

    # Type breakdown
    echo "  Types:"
    echo "$types" | tr ' ' '\n' | sort | uniq -c | sort -rn | while read count typ; do
        [ -z "$typ" ] && continue
        echo "    $typ: $count"
    done

    # Watch pattern coverage
    if [ -f "$FABRIC_DIR/watch-patterns.yaml" ]; then
        local watch_total=0
        local watch_registered=0
        local registered
        registered=$(grep "^location:" "$COMPONENTS_DIR"/*.yaml 2>/dev/null | sed 's/.*location: //' | sort -u)

        while IFS= read -r glob_pattern; do
            [ -z "$glob_pattern" ] && continue
            for file in $glob_pattern; do
                [ -f "$file" ] || continue
                watch_total=$((watch_total + 1))
                local rel_path
                rel_path=$(realpath --relative-to="$PROJECT_ROOT" "$file" 2>/dev/null || echo "$file")
                if echo "$registered" | grep -qx "$rel_path" 2>/dev/null; then
                    watch_registered=$((watch_registered + 1))
                fi
            done
        done < <(python3 -c "
import yaml
with open('$FABRIC_DIR/watch-patterns.yaml') as f:
    data = yaml.safe_load(f)
for p in data.get('patterns', []):
    print(p['glob'])
" 2>/dev/null)

        local pct=0
        [ "$watch_total" -gt 0 ] && pct=$((watch_registered * 100 / watch_total))
        echo ""
        echo "  Coverage: $watch_registered/$watch_total watched files ($pct%)"
    fi

    return 0
}
