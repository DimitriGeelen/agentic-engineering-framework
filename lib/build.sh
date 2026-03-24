#!/usr/bin/env bash
# Compile all TypeScript sources to JavaScript via esbuild
# Called by: fw build, fw update, stale-guard in hooks
set -euo pipefail

FRAMEWORK_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TS_DIR="$FRAMEWORK_ROOT/lib/ts"
SRC_DIR="$TS_DIR/src"
DIST_DIR="$TS_DIR/dist"

# No sources — nothing to build
if [ ! -d "$SRC_DIR" ]; then
    exit 0
fi

# Check if any .ts files exist
shopt -s nullglob
ts_files=("$SRC_DIR"/*.ts)
shopt -u nullglob

if [ ${#ts_files[@]} -eq 0 ]; then
    exit 0
fi

# Stale guard: only compile if source is newer than output
NEEDS_BUILD=0
for src in "${ts_files[@]}"; do
    out="$DIST_DIR/$(basename "${src%.ts}.js")"
    if [ ! -f "$out" ] || [ "$src" -nt "$out" ]; then
        NEEDS_BUILD=1
        break
    fi
done

if [ "$NEEDS_BUILD" -eq 0 ]; then
    [ "${1:-}" = "--verbose" ] && echo "TypeScript: all up to date"
    exit 0
fi

# Check for esbuild
if ! command -v npx >/dev/null 2>&1; then
    echo "ERROR: npx not found — cannot compile TypeScript" >&2
    echo "  Install Node.js 18+ or run: npm install -g esbuild" >&2
    exit 1
fi

# Compile each .ts file with esbuild
mkdir -p "$DIST_DIR"
compiled=0
for src in "${ts_files[@]}"; do
    name="$(basename "${src%.ts}")"
    npx --yes esbuild "$src" \
        --bundle \
        --platform=node \
        --target=node18 \
        --outfile="$DIST_DIR/${name}.js" \
        --format=cjs \
        2>/dev/null
    compiled=$((compiled + 1))
done

echo "TypeScript: compiled $compiled file(s)"
