#!/usr/bin/env bash
# fw hook-enable — register a framework hook in .claude/settings.json
#
# Usage: fw hook-enable --name <hook> --matcher <pat> --event <evt> [--file <path>] [--dry-run]
#
# Adds a { type: "command", command: ".agentic-framework/bin/fw hook <name>" } entry
# under the specified event/matcher in .claude/settings.json. Idempotent — if the exact
# (event, matcher, command) tuple already exists, exits 0 with "already registered".
#
# Written 2026-04-22 under T-1189 to repair T-977 false-complete (G-015 Hit #2).

set -euo pipefail

VALID_EVENTS="PostToolUse PreToolUse SessionStart PreCompact Stop SubagentStop UserPromptSubmit"

name=""
script=""
matcher=""
event=""
settings_file=""
dry_run=0

usage() {
    cat <<EOF
Usage: fw hook-enable (--name <hook> | --script <abs-path>) --matcher <pat> --event <evt> [--file <path>] [--dry-run]

Options:
  --name     Hook name (resolved to \$AGENTS_DIR/context/<name>.sh at runtime)
  --script   Absolute path to a project-local hook script (registered directly, not via fw hook)
  --matcher  Claude Code tool matcher pattern (e.g. "Bash", "Write|Edit", "")
  --event    Claude Code hook event. One of: $VALID_EVENTS
  --file     Settings file path (default: \$PROJECT_ROOT/.claude/settings.json)
  --dry-run  Print resulting JSON to stdout, do not write
  -h, --help Show this help

Use --name for framework-managed hooks under agents/context/.
Use --script for project-local hook scripts that live outside the framework tree.
--name and --script are mutually exclusive.

Exit: 0 on success (including idempotent no-op), non-zero on argument or JSON errors.
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        --name)     name="$2"; shift 2 ;;
        --script)   script="$2"; shift 2 ;;
        --matcher)  matcher="$2"; shift 2 ;;
        --event)    event="$2"; shift 2 ;;
        --file)     settings_file="$2"; shift 2 ;;
        --dry-run)  dry_run=1; shift ;;
        -h|--help)  usage; exit 0 ;;
        *)          echo "ERROR: unknown arg: $1" >&2; usage >&2; exit 2 ;;
    esac
done

if [ -n "$name" ] && [ -n "$script" ]; then
    echo "ERROR: use --name or --script, not both" >&2
    usage >&2
    exit 2
fi

if [ -z "$name" ] && [ -z "$script" ]; then
    echo "ERROR: --name or --script is required" >&2
    usage >&2
    exit 2
fi

if [ -z "$event" ]; then
    echo "ERROR: --event is required" >&2
    usage >&2
    exit 2
fi

if [ -n "$script" ]; then
    case "$script" in
        /*) ;;
        *) echo "ERROR: --script must be an absolute path: $script" >&2; exit 2 ;;
    esac
    if [ ! -f "$script" ]; then
        echo "ERROR: script not found: $script" >&2
        exit 2
    fi
    if [ ! -x "$script" ]; then
        echo "ERROR: script not executable: $script" >&2
        exit 2
    fi
fi

if ! printf '%s\n' $VALID_EVENTS | grep -Fxq "$event"; then
    echo "ERROR: --event must be one of: $VALID_EVENTS" >&2
    exit 2
fi

if [ -z "$settings_file" ]; then
    if [ -z "${PROJECT_ROOT:-}" ]; then
        PROJECT_ROOT="$(pwd)"
    fi
    settings_file="$PROJECT_ROOT/.claude/settings.json"
fi

if [ ! -f "$settings_file" ]; then
    echo "ERROR: settings file not found: $settings_file" >&2
    exit 3
fi

# T-1504: emit ABSOLUTE path. Claude Code's hook runner (POSIX sh -c) does
# not chdir to the project root, so a relative path like
# `.agentic-framework/bin/fw` only resolves when the parent shell happens
# to be at project root — rarely true after any cd/subshell/pipeline.
# Downstream 003-NTB-ATC-Plugin observed 680 silent failures in one session.
# Mirrors init.sh:584 (T-1364 G-053-A) which already emits absolute paths
# at init/upgrade time; this closes the second code path used by custom
# `fw hook-enable` registrations.
project_dir="$(cd "$(dirname "$settings_file")/.." && pwd)"
fw_prefix="$project_dir/.agentic-framework/bin/fw"
if [ -x "$project_dir/bin/fw" ] && [ -f "$project_dir/FRAMEWORK.md" ]; then
    fw_prefix="$project_dir/bin/fw"
fi
if [ -n "$script" ]; then
    command_str="$script"
else
    command_str="$fw_prefix hook $name"
fi

python3 - "$settings_file" "$event" "$matcher" "$command_str" "$dry_run" <<'PY'
import json, os, sys, tempfile

settings_file, event, matcher, command_str, dry_run = sys.argv[1:6]
dry_run = int(dry_run)

with open(settings_file) as f:
    data = json.load(f)

hooks = data.setdefault("hooks", {})
event_list = hooks.setdefault(event, [])

# Find matcher block (matcher field may be absent or == matcher)
target_block = None
for block in event_list:
    if block.get("matcher", "") == matcher:
        target_block = block
        break

if target_block is None:
    target_block = {"matcher": matcher, "hooks": []}
    event_list.append(target_block)

entries = target_block.setdefault("hooks", [])

# Idempotency: exact (type, command) match => no-op
for entry in entries:
    if entry.get("type") == "command" and entry.get("command") == command_str:
        print(f"already registered: {event}/{matcher!r} -> {command_str}", file=sys.stderr)
        if dry_run:
            json.dump(data, sys.stdout, indent=2)
            sys.stdout.write("\n")
        sys.exit(0)

entries.append({"type": "command", "command": command_str})

if dry_run:
    json.dump(data, sys.stdout, indent=2)
    sys.stdout.write("\n")
    sys.exit(0)

# Atomic write: tmpfile + rename
dir_ = os.path.dirname(os.path.abspath(settings_file))
fd, tmp = tempfile.mkstemp(prefix=".settings.json.", dir=dir_)
try:
    with os.fdopen(fd, "w") as f:
        json.dump(data, f, indent=2)
        f.write("\n")
    os.replace(tmp, settings_file)
except Exception:
    try: os.unlink(tmp)
    except OSError: pass
    raise

print(f"registered: {event}/{matcher!r} -> {command_str}", file=sys.stderr)
PY
