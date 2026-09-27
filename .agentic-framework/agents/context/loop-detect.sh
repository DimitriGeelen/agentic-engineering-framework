#!/usr/bin/env bash
# PostToolUse loop detector — shell wrapper for TypeScript implementation
# Called via: fw hook loop-detect
# Reads PostToolUse JSON from stdin, outputs additionalContext on stderr
# Exit: 0=ok/warning, 2=block
set -euo pipefail

FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
JS_PATH="$FRAMEWORK_ROOT/lib/ts/dist/loop-detect.js"
TS_SRC="$FRAMEWORK_ROOT/lib/ts/src/loop-detect.ts"

# Stale-guard: recompile if source is newer than output
if [ -f "$TS_SRC" ] && [ -f "$JS_PATH" ] && [ "$TS_SRC" -nt "$JS_PATH" ]; then
    npx --yes esbuild "$TS_SRC" \
        --bundle --platform=node --target=node18 \
        --outfile="$JS_PATH" --format=cjs 2>/dev/null || true
fi

if [ -f "$JS_PATH" ] && command -v node >/dev/null 2>&1; then
    exec node "$JS_PATH"
else
    # No node or no compiled JS — fail open (allow)
    cat > /dev/null  # consume stdin
    exit 0
fi
