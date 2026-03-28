# T-586 Phase 3: Migration Path — Incremental TypeScript Adoption

**Date:** 2026-03-23
**Prerequisite:** Phase 1 (language audit) + Phase 2 (prototype comparison)
**Goal:** Design the incremental migration strategy — what stays bash, what moves to TS, how the build pipeline works.

## 1. The Boundary: What Stays Bash Forever

These components **must remain bash** — they are entry points, glue, or constrained by external tools:

| Component | Reason |
|-----------|--------|
| `bin/fw` (CLI entry point) | Shell PATH resolution, no compilation needed to start |
| `agents/git/hooks/commit-msg` | Git invokes hooks as shell scripts directly |
| `agents/git/hooks/post-commit` | Same — git hook interface is shell |
| `agents/git/hooks/pre-push` | Same |
| `install.sh` | Must work on bare machines before Node.js is validated |
| `lib/init.sh` | Called during `fw init` before any build tooling exists |
| `lib/update.sh` | Handles the update itself — chicken-and-egg if it requires what it installs |
| `lib/setup.sh` | Interactive wizard, runs before project is configured |
| Simple glue scripts | Scripts that only call other commands (<20 lines, no data processing) |

**The rule:** If it's an entry point, a git hook, or runs before the framework is fully set up — it stays bash.

## 2. The Boundary: What Moves to TypeScript

These components **should migrate** — they do data processing that's currently done via `python3 -c`:

### Tier 1: New Components (write in TS from the start)

| Component | Task | Rationale |
|-----------|------|-----------|
| Loop detector | T-578 | Phase 2 proved TS version is 2x faster, immune to escaping |
| Idempotency/dedup | T-579 | Hash-based dedup — same pattern as loop detector |
| Error classification | T-580 | Pattern matching + JSON — TS excels |
| Session isolation | T-582 | State management — types catch key name errors |
| Health check | T-583 | JSON aggregation, HTTP calls — better in TS |
| Token budget | T-585 | Numeric computation, JSON parsing |
| Structured logging | T-584 | Shared library — exactly what TS modules are for |

### Tier 2: Existing Python Blocks (migrate when touched)

| Pattern | Count | Migration |
|---------|-------|-----------|
| YAML parsing (`python3 -c "import yaml..."`) | ~130 | Replace with `fw-util yaml-get` TS binary |
| JSON parsing (`python3 -c "import json..."`) | ~74 | Replace with `fw-util json-get` TS binary |
| Path operations (`python3 -c "import os.path..."`) | ~87 | Replace with `fw-util path-resolve` TS binary |
| Date/time (`python3 -c "from datetime..."`) | ~43 | Replace with `fw-util date-fmt` TS binary |

**The rule:** Any new data processing goes in TS. Existing Python blocks migrate when the file is touched for other reasons — no dedicated rewrite tasks.

### Tier 3: Never Migrate

| Component | Reason |
|-----------|--------|
| Watchtower (`web/`) | Flask/Jinja ecosystem, optional, decoupled. Stays Python. |
| `enrich.py` | 900+ LOC Python, deep semantic analysis. Rewrite not justified. |
| `discovery.py` | Ollama/embedding integration. Python ML ecosystem. |

## 3. Build Pipeline

### When Does TS Compile?

| Trigger | What happens | Tool |
|---------|-------------|------|
| `fw update` | Compiles all `.ts` in `lib/ts/` → `lib/ts/dist/` | esbuild (3ms per file) |
| `fw init --vendor` | Pre-compiled `.js` is vendored (no compilation needed) | rsync |
| Developer saves `.ts` | Optional: `fw build` or stale-guard in hook | esbuild |
| CI push | `tsc --noEmit` (type check only, no output) | tsc |
| Git pre-push hook | Optional: `tsc --noEmit` for type safety | tsc |

### Build Implementation

**New file: `lib/build.sh`**

```bash
#!/usr/bin/env bash
# Compile all TypeScript sources to JavaScript
set -euo pipefail

FRAMEWORK_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TS_DIR="$FRAMEWORK_ROOT/lib/ts"
DIST_DIR="$TS_DIR/dist"

if [ ! -d "$TS_DIR/src" ]; then
    exit 0  # No TS sources — nothing to build
fi

# Stale guard: only compile if source is newer than output
NEEDS_BUILD=0
for src in "$TS_DIR/src/"*.ts; do
    [ -f "$src" ] || continue
    out="$DIST_DIR/$(basename "${src%.ts}.js")"
    if [ ! -f "$out" ] || [ "$src" -nt "$out" ]; then
        NEEDS_BUILD=1
        break
    fi
done

if [ "$NEEDS_BUILD" -eq 0 ]; then
    exit 0  # All up to date
fi

# Compile with esbuild (3ms per file)
mkdir -p "$DIST_DIR"
for src in "$TS_DIR/src/"*.ts; do
    [ -f "$src" ] || continue
    npx esbuild "$src" --bundle --platform=node --outfile="$DIST_DIR/$(basename "${src%.ts}.js")" --format=cjs 2>/dev/null
done
```

### Stale Build Protection

Every hook that calls compiled JS checks freshness first:

```bash
# In hook wrapper (2 lines added to each hook)
TS_SRC="$FRAMEWORK_ROOT/lib/ts/src/loop-detect.ts"
JS_OUT="$FRAMEWORK_ROOT/lib/ts/dist/loop-detect.js"
[[ -f "$TS_SRC" && "$TS_SRC" -nt "$JS_OUT" ]] && npx esbuild "$TS_SRC" --bundle --platform=node --outfile="$JS_OUT" --format=cjs 2>/dev/null
node "$JS_OUT"
```

Cost: one `stat()` call per invocation (~0ms). Recompile only when source changes (3ms).

## 4. Directory Layout

```
lib/
  ts/
    src/                    # TypeScript sources (canonical)
      loop-detect.ts
      fw-util.ts            # Multi-subcommand utility
      yaml-parse.ts         # Shared: YAML frontmatter parser
      state.ts              # Shared: state file management
    dist/                   # Compiled JavaScript (committed)
      loop-detect.js
      fw-util.js
      yaml-parse.js
      state.js
    tsconfig.json           # Type checking config
    package.json            # Dev deps: typescript, @types/node, esbuild
  init.sh                   # Stays bash
  update.sh                 # Stays bash (calls build.sh after update)
  build.sh                  # NEW: compilation trigger
  harvest.sh                # Stays bash
```

**Why `lib/ts/` not `src/`?** Consistent with existing `lib/` convention. The framework's bash libraries are in `lib/*.sh` — TypeScript libraries go in `lib/ts/`.

**Why commit `dist/`?** Zero-build-step usage: `node lib/ts/dist/fw-util.js yaml-get file.yaml key`. No npm install needed for basic operation. The committed JS is the fallback when esbuild isn't available.

## 5. Developer Experience

### Adding a New TS Component

1. Create `lib/ts/src/my-component.ts`
2. Run `fw build` (or let stale-guard auto-compile on first use)
3. Call from bash: `node "$FRAMEWORK_ROOT/lib/ts/dist/my-component.js" "$@"`
4. Type-check: `cd lib/ts && npx tsc --noEmit`

### The `fw-util` Pattern

Instead of many small binaries, a single compiled entry point with subcommands:

```bash
# Replace: python3 -c "import yaml; print(yaml.safe_load(open('$file'))['$key'])"
# With:    node "$FW_TS/dist/fw-util.js" yaml-get "$file" "$key"

# Replace: python3 -c "import json; print(json.load(open('$file'))['$key'])"
# With:    node "$FW_TS/dist/fw-util.js" json-get "$file" "$key"

# Replace: python3 -c "import os.path; print(os.path.relpath('$a', '$b'))"
# With:    node "$FW_TS/dist/fw-util.js" path-rel "$a" "$b"
```

This replaces ~130 YAML + ~74 JSON + ~87 path operations with one binary. Compilation: one esbuild call, one JS file, ~50KB.

### Shared Module Pattern

TypeScript modules import from each other:

```typescript
// lib/ts/src/state.ts — shared state management
export function loadJsonState<T>(path: string, fallback: T): T { ... }
export function saveJsonState(path: string, data: unknown): void { ... }

// lib/ts/src/loop-detect.ts — imports shared module
import { loadJsonState, saveJsonState } from "./state.js";
```

esbuild bundles dependencies into each output file — no `node_modules` needed at runtime.

## 6. Impact on Vendoring

### Current Vendoring (rsync in `bin/fw`)

```bash
# Current excludes (bin/fw ~line 133-137):
rsync_excludes="--exclude=__pycache__ --exclude=*.pyc --exclude=.DS_Store"
```

### Required Changes

```bash
# Add to rsync excludes:
rsync_excludes="$rsync_excludes --exclude=lib/ts/src --exclude=lib/ts/tsconfig.json --exclude=lib/ts/package.json --exclude=lib/ts/node_modules"
```

**What gets vendored:** `lib/ts/dist/*.js` (compiled output only)
**What gets excluded:** `.ts` source, `tsconfig.json`, `package.json`, `node_modules/`

**Consumer impact:** Zero. Consumer projects get pre-compiled `.js` files that `node` runs directly. No npm install, no compilation, no TypeScript toolchain needed.

**Rollback:** If Node.js isn't available, `fw doctor` warns and hooks fall back to Python equivalents (same pattern as current TermLink optional check).

## 7. Impact on CI

### Current CI (`.github/workflows/test.yml`)

Two jobs: bats unit tests + E2E tests. No Node.js setup.

### Required Changes

```yaml
# Add to test job:
- name: Setup Node.js
  uses: actions/setup-node@v4
  with:
    node-version: '22'

# Add type-checking step:
- name: Type check TypeScript
  run: |
    cd lib/ts
    npm ci
    npx tsc --noEmit
```

**Cost:** ~10s added to CI (Node setup + npm ci + tsc). The E2E job already sets up Rust/Cargo for TermLink — adding Node is less overhead than that.

## 8. Impact on `fw doctor`

### New Check: TypeScript Build Health

```bash
# Add to fw doctor (after TermLink check):
echo -n "  TypeScript build... "
if [ -d "$FRAMEWORK_ROOT/lib/ts/src" ]; then
    if command -v node >/dev/null 2>&1; then
        # Check for stale builds
        STALE=0
        for src in "$FRAMEWORK_ROOT/lib/ts/src/"*.ts; do
            [ -f "$src" ] || continue
            out="$FRAMEWORK_ROOT/lib/ts/dist/$(basename "${src%.ts}.js")"
            if [ ! -f "$out" ] || [ "$src" -nt "$out" ]; then
                STALE=1
                break
            fi
        done
        if [ "$STALE" -eq 1 ]; then
            echo "WARN: stale build (run 'fw build')"
        else
            echo "ok"
        fi
    else
        echo "WARN: node not found (TS hooks will use Python fallback)"
    fi
else
    echo "skip (no TS sources)"
fi
```

## 9. Impact on `install.sh`

### Current Prerequisites

```bash
# install.sh checks: bash 4.4+, git 2.20+, python3 3.8+
```

### Required Change

```bash
# Add Node.js check (WARN, not FAIL — Node is recommended, not required)
if command -v node >/dev/null 2>&1; then
    NODE_VERSION=$(node --version | sed 's/v//')
    # ... version check
    echo "  Node.js:  $NODE_VERSION (recommended: 18+)"
else
    echo "  Node.js:  not found (optional — Python fallback for hooks)"
fi
```

**Node.js is NOT a hard requirement.** The framework works without it — hooks fall back to Python. But Claude Code users always have Node (Claude Code requires it), so in practice 100% of the target audience has it.

## 10. Runtime Fallback Pattern

For the transition period, hooks detect available runtime:

```bash
# lib/runtime.sh — runtime detection (new file)
fw_run_ts() {
    local script="$1"; shift
    local js_path="$FRAMEWORK_ROOT/lib/ts/dist/${script}.js"

    if [ -f "$js_path" ] && command -v node >/dev/null 2>&1; then
        node "$js_path" "$@"
    else
        # Fallback to Python equivalent
        python3 "$FRAMEWORK_ROOT/lib/py/${script}.py" "$@"
    fi
}
```

**Phase out plan:** Once all framework hooks use TS and Python fallbacks are never triggered (tracked by `fw doctor` telemetry), remove the fallbacks. Target: when 100% of `fw doctor` runs show Node.js present (estimated: immediately, since Claude Code requires Node).

## 11. Migration Timeline

| Phase | Scope | When |
|-------|-------|------|
| **Now** | Add `lib/ts/` structure, `package.json`, `tsconfig.json`, `build.sh` | T-586 Phase 5 (if GO) |
| **Week 1** | Port loop detector (T-578) as first real TS hook | After T-586 GO |
| **Week 2** | Build `fw-util` with `yaml-get`, `json-get`, `path-rel` subcommands | New task |
| **Week 3-4** | Port highest-risk inline Python blocks (Tier 3 from q4 report) | Per-file as touched |
| **Ongoing** | New components in TS; existing Python migrates when file is touched | No deadline |
| **Never** | Watchtower stays Python. `enrich.py`/`discovery.py` stay Python. | Permanent |

## 12. Language Count Analysis

**Before:** bash + Python (2 languages in core)
**During transition:** bash + Python + TypeScript (3 — temporarily worse)
**After Tier 2 migration:** bash + TypeScript (2 languages in core) + Python (Watchtower only, optional)

**The NO-GO criterion says:** "Incremental adoption creates a THREE-language codebase (bash+Python+TS) worse than current TWO (bash+Python)."

**Assessment:** The three-language phase is transient. TS replaces Python for the same job (data processing in hooks). The steady state is bash+TS core + optional Python Watchtower. Python doesn't leave during transition — it attrites as files are touched. At no point do contributors need to know all three: hook contributors need bash+TS, Watchtower contributors need Python. The domains don't overlap.

## 13. Open Questions for Phase 4/5

1. **Should `fw-util` be the first TS component instead of loop detector?** It has higher ROI — replaces ~290 inline Python calls vs one new hook.
2. **esbuild bundling vs separate modules?** Bundling means each `.js` is self-contained (simpler). Separate modules mean shared code isn't duplicated (smaller total size). For <10 files, bundling wins on simplicity.
3. **Should we use Node 22 strip-types in development?** 77ms vs 28ms compiled. Acceptable for dev, but compiled for production/vendored.
4. **When do we drop Python as a hard dependency?** After Watchtower is the only Python user AND Watchtower is truly optional, `install.sh` can make Python a WARN instead of a hard check.
