#!/bin/bash
# Fabric Agent - UI query commands
# Implements: fw fabric ui

do_ui() {
    ensure_fabric_dirs

    local route="${1:-}"
    local action_flag="${1:-}"
    local action_val="${2:-}"

    if [ "$action_flag" = "--action" ] && [ -n "$action_val" ]; then
        # Search by data-action
        echo -e "${BOLD}UI elements with action: $action_val${NC}"
        echo ""
        for card in "$COMPONENTS_DIR"/*.yaml; do
            [ -f "$card" ] || continue
            if grep -q "data_action:.*$action_val" "$card" 2>/dev/null; then
                python3 -c "
import yaml
with open('$card') as f:
    data = yaml.safe_load(f)
name = data.get('name', '?')
loc = data.get('location', '?')
for el in data.get('interactive_elements', []):
    if '$action_val' in el.get('data_action', ''):
        print(f\"  [{el.get('data_component', '?')}] action={el['data_action']}\")
        print(f\"    htmx: {el.get('htmx', '?')}\")
        print(f\"    endpoint: {el.get('api_endpoint', '?')}\")
        print(f\"    effect: {el.get('backend_effect', '?')}\")
        print(f\"    in: {loc}\")
        print()
" 2>/dev/null
            fi
        done
        return 0
    fi

    if [ -z "$route" ]; then
        echo -e "${RED}Error: Route or --action required${NC}"
        echo "Usage: fw fabric ui <route>"
        echo "       fw fabric ui --action <data-action>"
        return 1
    fi

    # Search by route
    echo -e "${BOLD}UI elements on: $route${NC}"
    echo ""
    for card in "$COMPONENTS_DIR"/*.yaml; do
        [ -f "$card" ] || continue
        if grep -q "url:.*$route" "$card" 2>/dev/null; then
            python3 -c "
import yaml
with open('$card') as f:
    data = yaml.safe_load(f)
name = data.get('name', '?')
print(f\"Component: {name}\")
route = data.get('route', {})
if route:
    print(f\"  Route: {route.get('method', '?')} {route.get('url', '?')}\")
    print(f\"  Handler: {route.get('handler', '?')}\")
    print(f\"  Template: {route.get('template', '?')}\")
    print()
for el in data.get('interactive_elements', []):
    print(f\"  [{el.get('data_component', '?')}] action={el.get('data_action', '?')}\")
    print(f\"    htmx: {el.get('htmx', '?')}\")
    print(f\"    endpoint: {el.get('api_endpoint', '?')}\")
    print(f\"    effect: {el.get('backend_effect', '?')}\")
    print()
if not data.get('interactive_elements'):
    print('  No interactive elements documented')
" 2>/dev/null
            return 0
        fi
    done

    echo "  No component found for route: $route"
    return 1
}
