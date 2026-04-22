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
matcher=""
event=""
settings_file=""
dry_run=0

usage() {
    cat <<EOF
Usage: fw hook-enable --name <hook> --matcher <pat> --event <evt> [--file <path>] [--dry-run]

Options:
  --name     Hook name (resolved to \$AGENTS_DIR/context/<name>.sh at runtime)
  --matcher  Claude Code tool matcher pattern (e.g. "Bash", "Write|Edit", "")
  --event    Claude Code hook event. One of: $VALID_EVENTS
  --file     Settings file path (default: \$PROJECT_ROOT/.claude/settings.json)
  --dry-run  Print resulting JSON to stdout, do not write
  -h, --help Show this help

Exit: 0 on success (including idempotent no-op), non-zero on argument or JSON errors.
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        --name)     name="$2"; shift 2 ;;
        --matcher)  matcher="$2"; shift 2 ;;
        --event)    event="$2"; shift 2 ;;
        --file)     settings_file="$2"; shift 2 ;;
        --dry-run)  dry_run=1; shift ;;
        -h|--help)  usage; exit 0 ;;
        *)          echo "ERROR: unknown arg: $1" >&2; usage >&2; exit 2 ;;
    esac
done

if [ -z "$name" ] || [ -z "$event" ]; then
    echo "ERROR: --name and --event are required" >&2
    usage >&2
    exit 2
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

command_str=".agentic-framework/bin/fw hook $name"

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
