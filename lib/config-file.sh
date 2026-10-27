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
# T-2365 (T-2158 S3): keys prefixed `continuous-mode.` route to a dedicated
# config-plus-state file under .context/working/ instead of .framework.yaml.
# Keeps continuous-mode runtime state (current_iteration) out of the project
# config, while the config-shaped fields (enabled, max_iterations, etc.) are
# still settable via the standard `fw config set/get` verb.
_continuous_mode_yaml="${PROJECT_ROOT:-.}/.context/working/.continuous-mode.yaml"
_continuous_mode_prefix="continuous-mode."

# Default schema for .continuous-mode.yaml — conservative caps.
_continuous_mode_defaults() {
    cat <<DEFAULTS
enabled: false
max_iterations: 10
tier_ceiling: 1
expires_after_seconds: 86400
current_iteration: 0
DEFAULTS
}

# Initialise .continuous-mode.yaml with defaults if absent.
_continuous_mode_init_if_absent() {
    if [ ! -f "$_continuous_mode_yaml" ]; then
        mkdir -p "$(dirname "$_continuous_mode_yaml")"
        _continuous_mode_defaults > "$_continuous_mode_yaml"
    fi
}

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
    echo "                             Registry keys are matched case-insensitively and"
    echo "                             written in canonical case; unknown keys need --force"
    echo "  fw config get KEY          Get the effective value (FW_KEY env, then file)"
    echo "  fw config get --file KEY   Get the value stored in the file only"
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

# Top-level keys that are not in FW_CONFIG_REGISTRY but are legitimately written
# to .framework.yaml: fw init/upgrade's lowercase fields (read by key, verbatim),
# and uppercase settings read without being registered. T-3924.
_config_known_extra_keys=" project_name project_id version provider initialized_at upgraded_from last_upgrade upstream_repo PROTECT_MASTER WATCHTOWER_URL CONTINUOUS_SESSION UPSTREAM_URL PEER_LEARNING_CRON "

_config_load_registry() {
    declare -F fw_config_canonical_key >/dev/null && return 0
    local fw_root="${FRAMEWORK_ROOT:-$(cd "${BASH_SOURCE[0]%/*}/.." && pwd)}"
    source "$fw_root/lib/config.sh"
}

# _config_closest_key KEY — the registry key closest to KEY (for a refusal hint).
_config_closest_key() {
    local names
    names="$(printf '%s\n' "${FW_CONFIG_REGISTRY[@]}" | cut -d'|' -f1)"
    python3 -c '
import difflib, sys
m = difflib.get_close_matches(sys.argv[1].upper(), sys.argv[2].split(), n=1, cutoff=0.6)
print(m[0] if m else "")' "$1" "$names"
}

_config_set() {
    local force=0 args=() a
    for a in "$@"; do
        if [ "$a" = "--force" ]; then force=1; else args+=("$a"); fi
    done
    local key="${args[0]:-}"
    local value="${args[1]:-}"

    if [ -z "$key" ] || [ -z "$value" ]; then
        echo -e "${RED:-}Usage: fw config set KEY VALUE [--force]${NC:-}" >&2
        exit 1
    fi

    # T-3924: a flat key is resolved against FW_CONFIG_REGISTRY before it is
    # written. fw_config reads .framework.yaml by the exact registry key, so a
    # key in any other case was written, echoed back as "Set", and never read.
    if [[ "$key" != *.* ]]; then
        _config_load_registry
        local canon
        canon="$(fw_config_canonical_key "$key")"
        if [ -n "$canon" ]; then
            if [ "$canon" != "$key" ]; then
                echo "Note: '$key' is the registry key '$canon' — writing '$canon' (fw_config reads that exact key)." >&2
                key="$canon"
            fi
        elif [ "$force" != "1" ] && [[ "$_config_known_extra_keys" != *" $key "* ]] \
             && ! grep -q "^${key}:" "$_config_yaml" 2>/dev/null; then
            local near
            near="$(_config_closest_key "$key")"
            echo -e "${RED:-}Unknown config key: $key${NC:-}" >&2
            echo "  It is not in the config registry, so nothing reads it (see: fw config overrides)." >&2
            [ -n "$near" ] && echo "  Did you mean: fw config set $near $value" >&2
            echo "  To write it anyway: fw config set $key $value --force" >&2
            exit 1
        fi
    fi

    # T-2365 (T-2158 S3): keys under `continuous-mode.` write to the
    # dedicated continuous-mode file under .context/working/. Trim the
    # prefix before passing to the python writer.
    local target_yaml="$_config_yaml"
    local effective_key="$key"
    if [[ "$key" == "$_continuous_mode_prefix"* ]]; then
        _continuous_mode_init_if_absent
        target_yaml="$_continuous_mode_yaml"
        effective_key="${key#$_continuous_mode_prefix}"
    fi

    if [ ! -f "$target_yaml" ]; then
        echo -e "${RED:-}No config file found at $target_yaml${NC:-}" >&2
        echo "Run 'fw init' first to create a project configuration." >&2
        exit 1
    fi

    python3 - "$target_yaml" "$effective_key" "$value" << 'PYSET'
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

import os
import re


def _roundtrip_set(yaml_file, key, value):
    """Dotted keys: ruamel round-trip (nested mapping edit)."""
    try:
        from ruamel.yaml import YAML
        yaml = YAML()
        yaml.preserve_quotes = True
        # T-3735: the default width (80) folds a long scalar onto a continuation
        # line; line-wise shell readers (lib/update.sh grep+sed on upstream_repo)
        # then read ''. Keep every scalar on its own key line.
        yaml.width = 4096
    except ImportError:
        # Fallback to PyYAML (no comment preservation)
        import yaml as pyyaml

        class FallbackYAML:
            def load(self, f):
                return pyyaml.safe_load(f)
            def dump(self, data, f):
                pyyaml.dump(data, f, default_flow_style=False, sort_keys=False, width=4096)

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

    # T-100191: same-dir temp + os.replace — a kill mid-dump must not truncate
    # the live config (L-493 non-atomic-YAML-write class).
    tmp_path = yaml_file + '.tmp'
    with open(tmp_path, 'w') as f:
        yaml.dump(data, f)
    os.replace(tmp_path, yaml_file)


def _line_set(yaml_file, key, value):
    """T-4847: a flat key is edited in place. A load + re-dump rewrote every
    other line it could not round-trip — a plain scalar wrapped onto a
    continuation line came back collapsed (832, be.43). Only KEY's own lines
    change: its key line plus any continuation lines, or one appended line."""
    import yaml as pyyaml
    rendered = pyyaml.safe_dump({key: value}, default_flow_style=False,
                                sort_keys=False, allow_unicode=True,
                                width=float('inf'))
    with open(yaml_file, 'r') as f:
        lines = f.read().splitlines(keepends=True)
    key_re = re.compile(r'^' + re.escape(key) + r'[ \t]*:([ \t]|$)')
    start = next((n for n, l in enumerate(lines) if key_re.match(l)), None)
    if start is None:
        if lines and not lines[-1].endswith('\n'):
            lines[-1] += '\n'
            rendered = rendered.rstrip('\n')
        lines.append(rendered)
    else:
        # The value runs on while lines are indented, blank, or top-level
        # sequence items; trailing blank/comment lines stay with what follows.
        end = start + 1
        while end < len(lines) and (not lines[end].strip()
                                    or lines[end][0] in ' \t'
                                    or re.match(r'-([ \t]|$)', lines[end])):
            end += 1
        while end > start + 1 and (not lines[end - 1].strip()
                                   or lines[end - 1].lstrip().startswith('#')):
            end -= 1
        if not lines[end - 1].endswith('\n'):
            rendered = rendered.rstrip('\n')
        lines[start:end] = [rendered]
    # T-100191: same-dir temp + os.replace (L-493 non-atomic-YAML-write class).
    tmp_path = yaml_file + '.tmp'
    with open(tmp_path, 'w') as f:
        f.writelines(lines)
    os.replace(tmp_path, yaml_file)


if '.' in key:
    _roundtrip_set(yaml_file, key, value)
else:
    _line_set(yaml_file, key, value)

print(f"Set {key} = {value}")

# Validate known integer settings
INTEGER_SETTINGS = {
    'PORT', 'CONTEXT_WINDOW', 'DISPATCH_LIMIT', 'BUDGET_RECHECK_INTERVAL',
    'BUDGET_STATUS_MAX_AGE', 'TOKEN_CHECK_INTERVAL', 'HANDOVER_COOLDOWN',
    'STALE_TASK_DAYS', 'MAX_RESTARTS', 'SAFE_MODE', 'CALL_WARN',
    'CALL_URGENT', 'CALL_CRITICAL', 'BASH_TIMEOUT', 'KEYLOCK_TIMEOUT',
    'TERMLINK_WORKER_TIMEOUT', 'HANDOVER_DEDUP_COOLDOWN', 'TERMLINK_MAX_WORKERS',
}
# Check the last segment of dotted keys (e.g., watchtower.port → port)
check_key = key.split('.')[-1].upper()
if check_key in INTEGER_SETTINGS and not isinstance(value, (int, float)):
    print(f"WARNING: {key} is typically a numeric setting", file=sys.stderr)
PYSET
}

_config_get() {
    # T-4807: --file reads .framework.yaml only; the default answers the
    # effective value, as fw_config resolves it (FW_* env before the file).
    local file_only=0
    if [ "${1:-}" = "--file" ]; then
        file_only=1
        shift
    fi
    local key="${1:-}"

    if [ -z "$key" ]; then
        echo -e "${RED:-}Usage: fw config get [--file] KEY${NC:-}" >&2
        exit 1
    fi

    # T-3924: same resolution as set — a registry key in any case reads the
    # canonical key, the one fw_config reads.
    if [[ "$key" != *.* ]]; then
        _config_load_registry
        local canon
        canon="$(fw_config_canonical_key "$key")"
        [ -n "$canon" ] && key="$canon"
        # T-4807: env tier for registry keys, the same FW_<KEY> fw_config reads.
        if [ -n "$canon" ] && [ "$file_only" -eq 0 ]; then
            local env_var="FW_${canon}"
            if [ -n "${!env_var:-}" ]; then
                echo "${!env_var}"
                return 0
            fi
        fi
    fi

    # T-2365 (T-2158 S3): keys under `continuous-mode.` read from the
    # dedicated continuous-mode file. Auto-init with defaults on first read.
    local target_yaml="$_config_yaml"
    local effective_key="$key"
    if [[ "$key" == "$_continuous_mode_prefix"* ]]; then
        _continuous_mode_init_if_absent
        target_yaml="$_continuous_mode_yaml"
        effective_key="${key#$_continuous_mode_prefix}"
    fi

    if [ ! -f "$target_yaml" ]; then
        echo -e "${RED:-}No config file found at $target_yaml${NC:-}" >&2
        exit 1
    fi

    python3 - "$target_yaml" "$effective_key" << 'PYGET'
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
