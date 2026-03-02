#!/bin/bash
# bus-handler.sh — Process incoming bus messages from inbox
# Triggered by systemd.path when files appear in .context/bus/inbox/
#
# Part of: Agentic Engineering Framework (T-110 spike)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# Resolve PROJECT_ROOT from git toplevel — framework/ is typically a subdirectory,
# not the project root. Fall back to FRAMEWORK_ROOT for standalone installs.
PROJECT_ROOT="${PROJECT_ROOT:-$(git -C "$FRAMEWORK_ROOT" rev-parse --show-toplevel 2>/dev/null || echo "$FRAMEWORK_ROOT")}"
INBOX_DIR="$PROJECT_ROOT/.context/bus/inbox"
LOG_FILE="$PROJECT_ROOT/.context/bus/handler.log"

log() {
    echo "$(date -u +"%Y-%m-%dT%H:%M:%SZ") $*" >> "$LOG_FILE"
}

log "Handler triggered — scanning inbox"

if [ ! -d "$INBOX_DIR" ]; then
    log "Inbox directory not found: $INBOX_DIR"
    exit 0
fi

# Process all files in inbox
processed=0
for msg_file in "$INBOX_DIR"/*; do
    [ -f "$msg_file" ] || continue

    filename=$(basename "$msg_file")
    log "Processing: $filename"

    # For now, just log and move to processed
    mkdir -p "$INBOX_DIR/.processed"
    mv "$msg_file" "$INBOX_DIR/.processed/$filename"
    processed=$((processed + 1))

    log "  Moved to .processed/$filename"
done

if [ "$processed" -eq 0 ]; then
    log "No messages in inbox"
else
    log "Processed $processed message(s)"
fi
