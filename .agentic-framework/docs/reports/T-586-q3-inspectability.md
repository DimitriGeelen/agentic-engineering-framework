# T-586 Q3: TypeScript Inspectability in the Agentic Engineering Framework

**Date:** 2026-03-23
**Method:** Compiled a 65-line TS utility (YAML parsing, path resolution) with `tsc` targeting ES2022/commonjs, no minification.

## 1. Compiled JS Is Human-Readable

The business logic in compiled output is nearly identical to the source:

```typescript
// SOURCE (.ts, line 20-35)
function parseSimpleYaml(content: string): RawYamlLike {
  const result: RawYamlLike = {};
  for (const line of content.split("\n")) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#")) continue;
    const colonIdx = trimmed.indexOf(":");
    if (colonIdx === -1) continue;
    const key = trimmed.slice(0, colonIdx).trim();
    let val: string | boolean | null = trimmed.slice(colonIdx + 1).trim();
    if (val === "true") val = true;
```

```javascript
// OUTPUT (.js, line 44-56) — only type annotations removed
function parseSimpleYaml(content) {
    const result = {};
    for (const line of content.split("\n")) {
        const trimmed = line.trim();
        if (!trimmed || trimmed.startsWith("#"))
            continue;
        const colonIdx = trimmed.indexOf(":");
        if (colonIdx === -1)
            continue;
        const key = trimmed.slice(0, colonIdx).trim();
        let val = trimmed.slice(colonIdx + 1).trim();
        if (val === "true")
            val = true;
```

**Verdict:** With ES2022 target and no minification, `tsc` output is a 1:1 readable translation. The only additions are a 34-line CJS module preamble (`__importStar`, `__createBinding`) and removal of type annotations. Variable names, comments, and control flow are preserved exactly. 65 lines TS became 92 lines JS (41% growth, all from the module boilerplate).

## 2. Inspectability Comparison: Inline Python vs Separate .ts File

| Factor | `python3 -c "import yaml; ..."` in bash | Separate `.ts` file compiled to `.js` |
|--------|------------------------------------------|---------------------------------------|
| Visible in one place | Yes (inline in hook script) | No (separate file, must open it) |
| Syntax highlighting | No (string inside bash) | Yes (proper file with extension) |
| Testable in isolation | No | Yes (import and unit test) |
| Debuggable | Print statements only | Node inspector, source maps |
| Grep-able | Harder (embedded in string) | Easy (standalone file) |
| Dependency transparency | Implicit (`python3` must exist) | Explicit (`package.json`) |

**Verdict:** For 1-3 line checks (the framework's current pattern), inline python is *more* inspectable — everything in one file, no build step. For anything over ~10 lines, a separate TS/JS file wins on testability and readability. The framework's hooks are all in the 1-5 line range, so inline python remains the right choice there.

## 3. Can .ts and .js Coexist? Convention?

Yes. Standard convention: commit both `.ts` source and compiled `.js` output (or only `.ts` with a build step). Three patterns exist:

| Pattern | Ships | Inspectable | Build needed to contribute |
|---------|-------|-------------|---------------------------|
| **Source-only** (.ts, build on install) | .ts | Yes | Yes |
| **Dual** (.ts + .js committed) | Both | Yes (.ts is canonical) | No (js works directly) |
| **Output-only** (.js from .ts, source not shipped) | .js | Depends on minification | No |

For the framework, **dual** is safest: `.ts` is the source of truth, `.js` is committed alongside for zero-build-step usage. A `tsconfig.json` with `outDir` keeps them separated (`src/` vs `dist/`).

## 4. What Does Claude Code Ship?

- **npm package (v2.1.27):** Single minified `cli.js` — 11MB, 6429 lines, completely unreadable. Header says: *"Want to see the unminified source? We're hiring!"* Variable names like `FNq`, `uNq`, `BNq`. This is an **opaque compiled bundle** — the exact thing the framework constraint prohibits.
- **Native binary (v2.1.74):** 235MB ELF executable. Not JS at all — compiled to native code. Even less inspectable.
- **Neither version ships .ts source or source maps.**

## 5. Conclusion

`tsc` with ES2022 target and no minification produces human-readable JS that satisfies the "no opaque compiled bundles" constraint. The compiled output preserves variable names, comments, and structure — an agent or human can read `dist/resolve-config.js` and understand what it does without access to the `.ts` source. The framework could adopt TypeScript for complex utilities (>10 lines) while keeping inline bash+python for simple hook checks, provided: (a) no minification/bundling in the build, and (b) compiled `.js` is committed alongside `.ts` source.
