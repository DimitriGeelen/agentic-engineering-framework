# T-586 Q1: TypeScript Compilation Research

**Date:** 2026-03-23
**Environment:** Node v22.22.1, Python 3.12.3, Linux 6.8.0-88-generic
**Tool versions:** tsc 6.0.2, esbuild 0.27.4, tsx 4.21.0

## Test Setup

- 68-line TypeScript utility that reads YAML-frontmatter task files (mirrors framework hook behavior)
- Equivalent Python implementation for baseline comparison
- 10 test task files as workload
- All times in seconds, median of 5 runs unless noted

## 1. Compilation Times

| Tool | Time (median) | Output size | Notes |
|------|--------------|-------------|-------|
| tsc | 0.95s | 2,239 bytes (61 lines) | Full type checking, CJS output |
| esbuild | 0.24s (3ms internal) | 1,896 bytes (51 lines) | Type stripping only, bundled |

**esbuild is ~4x faster** but 0.21s is npx overhead; internal time is 3ms.
tsc produces CJS (`exports.__esModule`), esbuild produces self-contained bundle.

## 2. Startup/Runtime Performance

| Execution method | Startup time (median) | Notes |
|-----------------|----------------------|-------|
| `node dist/file.js` (tsc output) | 0.02s | Fastest possible |
| `node dist/file.js` (esbuild output) | 0.02s | Identical to tsc |
| `node --experimental-strip-types file.ts` | 0.06s | Node 22+ native, no build step |
| `python3 equivalent.py` | 0.04s | Baseline comparison |
| `./node_modules/.bin/tsx file.ts` | 0.21s | Direct invocation |
| `npx tsx file.ts` | 0.45s | npx adds ~0.24s overhead |

**Key finding:** Compiled JS (20ms) is 3x faster than Python (40ms) and 10x faster than tsx (210ms).
Node's `--experimental-strip-types` (60ms) is close to Python and requires zero build tooling.

## 3. Minimal tsconfig.json for Node 18+

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "Node16",
    "moduleResolution": "Node16",
    "outDir": "./dist",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "types": ["node"]
  },
  "include": ["src/**/*.ts"]
}
```

**Required dependencies:** `typescript`, `@types/node` (dev).
`module: "Node16"` enables `node:` protocol imports and proper ESM/CJS resolution.

## 4. Node --experimental-strip-types (Node 22+)

Native TS execution without any npm dependencies. Caveats:
- Requires `"type": "module"` in package.json (or warns + re-parses)
- Strips types only -- no type checking, no enums, no decorators, no `import =`
- 60ms startup vs 20ms compiled -- 3x slower but acceptable for hooks
- Flag name suggests instability; may change in future Node versions

## 5. Failure Modes

| Failure mode | Severity | Description |
|-------------|----------|-------------|
| **Stale builds** | HIGH | Source changes after `tsc`; `dist/` silently runs old code. No built-in staleness check. |
| **esbuild skips type errors** | HIGH | `const x: number = "hello"` compiles fine with esbuild. Only tsc catches type errors. |
| **CJS/ESM mismatch** | MEDIUM | tsc emits CJS by default; adding `"type":"module"` to package.json breaks old dist/ output with `ReferenceError: exports is not defined`. |
| **@types/node missing** | MEDIUM | tsc fails immediately without it. esbuild/tsx work fine (they strip, not check). |
| **npx resolution overhead** | LOW | npx adds 240ms per invocation. Use direct `node_modules/.bin/` paths in hooks. |
| **node_modules bloat** | LOW | 38MB for typescript+esbuild+tsx+@types/node (8 packages). Acceptable for dev. |

## 6. Recommendations for Framework Hooks

| Strategy | Build overhead | Runtime | Type safety | Complexity |
|----------|---------------|---------|-------------|------------|
| **A: esbuild compile** | 3ms per file | 20ms | None (add tsc --noEmit in CI) | Makefile/script needed |
| **B: tsc compile** | ~1s per file | 20ms | Full | Makefile/script + stale guard |
| **C: node --strip-types** | 0 | 60ms | None | Simplest; Node 22+ only |
| **D: tsx runtime** | 0 | 210ms | None | Simple; 38MB dep |

**For framework hooks (called on every tool use):**
- Strategy A (esbuild + tsc --noEmit in CI) is optimal: 3ms build, 20ms runtime, type safety in CI
- Strategy C is viable if Node 22+ is guaranteed and 60ms is acceptable
- Strategy D (tsx) is too slow at 210ms per hook invocation
- Strategy B (tsc only) works but 1s compile per change adds friction

**Stale build mitigation:** Use a `Makefile` or `package.json` script that checks mtimes:
```bash
# In hook: compile only if source newer than output
[[ src/hook.ts -nt dist/hook.js ]] && npx esbuild src/hook.ts --outfile=dist/hook.js
```

## 7. npm Install Overhead

Fresh install of all four packages: **1.3s** (from cache), **38MB** on disk, 8 top-level packages.
This is a one-time cost per project clone. Acceptable.
