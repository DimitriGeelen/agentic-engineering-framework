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

VERBOSE=0
case "${1:-}" in --verbose|-v) VERBOSE=1 ;; esac

if [ "$NEEDS_BUILD" -eq 0 ]; then
    [ "$VERBOSE" -eq 1 ] && echo "TypeScript: all up to date"
    exit 0
fi

# Check for esbuild
if ! command -v npx >/dev/null 2>&1; then
    echo "ERROR: npx not found — cannot compile TypeScript" >&2
    echo "  Install Node.js 18+ or run: npm install -g esbuild" >&2
    exit 1
fi

# T-4572: esbuild bundles, so every package a source imports (js-yaml) must be
# resolvable from lib/ts/node_modules. That directory is gitignored, so on a
# clean machine nothing is there until the declared dependencies are installed.
# List declared packages absent from node_modules (one per line).
_missing_deps() {
    [ -f "$TS_DIR/package.json" ] || return 0
    node -e '
        const fs = require("fs"), path = require("path");
        const dir = process.argv[1];
        const pkg = JSON.parse(fs.readFileSync(path.join(dir, "package.json"), "utf8"));
        const deps = Object.assign({}, pkg.dependencies, pkg.devDependencies);
        for (const name of Object.keys(deps)) {
            if (!fs.existsSync(path.join(dir, "node_modules", name, "package.json"))) console.log(name);
        }
    ' "$TS_DIR"
}

missing="$(_missing_deps)"
if [ -n "$missing" ]; then
    [ "$VERBOSE" -eq 1 ] && echo "TypeScript: installing lib/ts dependencies ($(echo $missing))"
    if command -v npm >/dev/null 2>&1; then
        if [ -f "$TS_DIR/package-lock.json" ]; then
            (cd "$TS_DIR" && npm ci --no-audit --no-fund --loglevel=error) >&2 \
                || (cd "$TS_DIR" && npm install --no-audit --no-fund --loglevel=error) >&2 \
                || true
        else
            (cd "$TS_DIR" && npm install --no-audit --no-fund --loglevel=error) >&2 || true
        fi
    fi
    missing="$(_missing_deps)"
    if [ -n "$missing" ]; then
        echo "ERROR: missing TypeScript build dependencies in $TS_DIR/node_modules:" >&2
        for dep in $missing; do echo "  - $dep" >&2; done
        if command -v npm >/dev/null 2>&1; then
            echo "  npm install failed — run: (cd $TS_DIR && npm ci)" >&2
        else
            echo "  npm not found — install Node.js 18+ (with npm), then run: (cd $TS_DIR && npm ci)" >&2
        fi
        exit 1
    fi
fi

# Compile each .ts file with esbuild (from TS_DIR, so npx uses the local esbuild)
mkdir -p "$DIST_DIR"
compiled=0
for src in "${ts_files[@]}"; do
    name="$(basename "${src%.ts}")"
    if ! err="$(cd "$TS_DIR" && npx --yes esbuild "$src" \
        --bundle \
        --platform=node \
        --target=node18 \
        --outfile="$DIST_DIR/${name}.js" \
        --format=cjs \
        --log-level=error 2>&1)"; then
        echo "ERROR: esbuild failed on ${src#"$FRAMEWORK_ROOT"/}" >&2
        [ -n "$err" ] && echo "$err" >&2
        exit 1
    fi
    compiled=$((compiled + 1))
done

echo "TypeScript: compiled $compiled file(s)"
