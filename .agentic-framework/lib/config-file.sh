#!/bin/bash
# lib/config-file.sh — Read/write persistent settings in .framework.yaml
#
# Provides fw config set/get/list for project-level configuration.
# Uses Python + ruamel.yaml for round-trip YAML editing (preserves comments).
#
# Usage:
#   source "$FRAMEWORK_ROOT/lib/config-file.sh"
#   do_config set watchtower.port 3001
#   do_config get watchtower.port
#   do_config list
#
# Origin: T-889 (foundation for T-885 service registry)

[[ -n "${_FW_CONFIG_FILE_LOADED:-}" ]] && return 0
_FW_CONFIG_FILE_LOADED=1

_config_yaml="${PROJECT_ROOT:-.}/.framework.yaml"

do_config() {
    local subcmd="${1:-help}"
    shift 2>/dev/null || true

    case "$subcmd" in
        set)   _config_set "$@" ;;
        get)   _config_get "$@" ;;
        list)  _config_list "$@" ;;
        overrides) _config_overrides "$@" ;;
        help|--help|-h) _config_help ;;
        *)
            echo -e "${RED:-}Unknown config subcommand: $subcmd${NC:-}" >&2
            _config_help
            exit 1
            ;;
    esac
}

_config_help() {
    echo "fw config — Read/write persistent settings in .framework.yaml"
    echo ""
    echo "Usage:"
    echo "  fw config set KEY VALUE    Set a config value (dot-notation for nesting)"
    echo "  fw config get KEY          Get a config value"
    echo "  fw config list             Show all custom settings"
    echo "  fw config overrides        Show all non-default settings (env + file)"
    echo ""
    echo "Examples:"
    echo "  fw config set watchtower.port 3001"
    echo "  fw config get watchtower.port"
    echo "  fw config set project_name my-app"
    echo ""
    echo "Config file: $_config_yaml"
}

_config_set() {
    local key="${1:-}"
    local value="${2:-}"

    if [ -z "$key" ] || [ -z "$value" ]; then
        echo -e "${RED:-}Usage: fw config set KEY VALUE${NC:-}" >&2
        exit 1
    fi

    if [ ! -f "$_config_yaml" ]; then
        echo -e "${RED:-}No .framework.yaml found at $_config_yaml${NC:-}" >&2
        echo "Run 'fw init' first to create a project configuration." >&2
        exit 1
    fi

    python3 - "$_config_yaml" "$key" "$value" << 'PYSET'
import sys

yaml_file = sys.argv[1]
key = sys.argv[2]
value = sys.argv[3]

# Try numeric conversion
try:
    value = int(value)
except ValueError:
    try:
        value = float(value)
    except ValueError:
        # Boolean conversion
        if value.lower() in ('true', 'yes'):
            value = True
        elif value.lower() in ('false', 'no'):
            value = False

try:
    from ruamel.yaml import YAML
    yaml = YAML()
    yaml.preserve_quotes = True
except ImportError:
    # Fallback to PyYAML (no comment preservation)
    import yaml as pyyaml

    class FallbackYAML:
        def load(self, f):
            return pyyaml.safe_load(f)
        def dump(self, data, f):
            pyyaml.dump(data, f, default_flow_style=False, sort_keys=False)

    yaml = FallbackYAML()
    print("WARNING: ruamel.yaml not installed — comments may not be preserved", file=sys.stderr)

with open(yaml_file, 'r') as f:
    data = yaml.load(f)

if data is None:
    data = {}

# Handle dot-notation (e.g., watchtower.port → data['watchtower']['port'])
parts = key.split('.')
current = data
for part in parts[:-1]:
    if part not in current or not isinstance(current[part], dict):
        current[part] = {}
    current = current[part]

current[parts[-1]] = value

with open(yaml_file, 'w') as f:
    yaml.dump(data, f)

print(f"Set {key} = {value}")

# Validate known integer settings
INTEGER_SETTINGS = {
    'PORT', 'CONTEXT_WINDOW', 'DISPATCH_LIMIT', 'BUDGET_RECHECK_INTERVAL',
    'BUDGET_STATUS_MAX_AGE', 'TOKEN_CHECK_INTERVAL', 'HANDOVER_COOLDOWN',
    'STALE_TASK_DAYS', 'MAX_RESTARTS', 'SAFE_MODE', 'CALL_WARN',
    'CALL_URGENT', 'CALL_CRITICAL', 'BASH_TIMEOUT', 'KEYLOCK_TIMEOUT',
    'TERMLINK_WORKER_TIMEOUT', 'HANDOVER_DEDUP_COOLDOWN',
}
# Check the last segment of dotted keys (e.g., watchtower.port → port)
check_key = key.split('.')[-1].upper()
if check_key in INTEGER_SETTINGS and not isinstance(value, (int, float)):
    print(f"WARNING: {key} is typically a numeric setting", file=sys.stderr)
PYSET
}

_config_get() {
    local key="${1:-}"

    if [ -z "$key" ]; then
        echo -e "${RED:-}Usage: fw config get KEY${NC:-}" >&2
        exit 1
    fi

    if [ ! -f "$_config_yaml" ]; then
        echo -e "${RED:-}No .framework.yaml found at $_config_yaml${NC:-}" >&2
        exit 1
    fi

    python3 - "$_config_yaml" "$key" << 'PYGET'
import sys, yaml

yaml_file = sys.argv[1]
key = sys.argv[2]

with open(yaml_file) as f:
    data = yaml.safe_load(f) or {}

parts = key.split('.')
current = data
for part in parts:
    if isinstance(current, dict) and part in current:
        current = current[part]
    else:
        sys.exit(1)  # Key not found

print(current)
PYGET
}

_config_list() {
    if [ ! -f "$_config_yaml" ]; then
        echo -e "${RED:-}No .framework.yaml found at $_config_yaml${NC:-}" >&2
        exit 1
    fi

    echo -e "${BOLD:-}Project config:${NC:-} $_config_yaml"
    echo ""

    python3 - "$_config_yaml" << 'PYLIST'
import sys, yaml

with open(sys.argv[1]) as f:
    data = yaml.safe_load(f) or {}

# Standard fields (skip these in "custom" display)
standard = {'project_name', 'version', 'provider', 'initialized_at',
            'upgraded_from', 'last_upgrade', 'upstream_repo'}

def print_tree(d, prefix=""):
    for k, v in d.items():
        if prefix == "" and k in standard:
            continue
        full_key = f"{prefix}{k}" if not prefix else f"{prefix}.{k}"
        if isinstance(v, dict):
            print_tree(v, full_key)
        else:
            print(f"  {full_key} = {v}")

# Print standard fields first
for k in ['project_name', 'version', 'provider']:
    if k in data:
        print(f"  {k} = {data[k]}")

# Then custom fields
custom_found = False
for k in data:
    if k not in standard:
        if not custom_found:
            print("")
            print("  Custom settings:")
            custom_found = True
        if isinstance(data[k], dict):
            print_tree({k: data[k]})
        else:
            print(f"  {k} = {data[k]}")

if not custom_found:
    print("  (no custom settings)")
PYLIST
}

_config_overrides() {
    # Source config.sh to get the registry function
    local fw_root="${FRAMEWORK_ROOT:-$(cd "${BASH_SOURCE[0]%/*}/.." && pwd)}"
    source "$fw_root/lib/config.sh" 2>/dev/null

    echo -e "${BOLD:-}Active Overrides${NC:-}"
    echo ""

    local found=0
    local line
    while IFS='|' read -r key default current source desc; do
        if [ "$source" != "default" ]; then
            found=$((found + 1))
            printf "  %-30s = %-15s (source: %s)\n" "$key" "$current" "$source"
        fi
    done <<< "$(fw_config_registry)"

    if [ "$found" -eq 0 ]; then
        echo "  (no overrides — all settings at default)"
    else
        echo ""
        echo "  $found override(s) active"
    fi
}
