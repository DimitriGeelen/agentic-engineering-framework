# T-586 Q2: Vendoring TypeScript Components Without Requiring Node.js

**Date:** 2026-03-23
**Task:** T-586 -- Can `fw init --vendor` ship pre-compiled JS so consumer projects skip Node.js?

## Q1: What Gets Copied During Vendoring?

`do_vendor()` in `bin/fw` (line 92-213) copies these directories via rsync:

```
bin/ lib/ agents/ web/ docs/ .tasks/templates/ FRAMEWORK.md metrics.sh
```

Excludes: `__pycache__`, `*.pyc`, `.DS_Store`. No file-type filtering -- everything in those
dirs is copied wholesale. A VERSION file is written. Total size ~7MB.

## Q2: Can Vendoring Copy .js But Skip .ts Source?

**Yes, with minor changes.** Two approaches:

1. **Build step in `fw update`**: Compile `.ts` to `.js` before vendoring. Add `*.ts` and
   `node_modules/` to the rsync excludes list (line 133-137). Vendor ships only the `.js` output.
2. **Pre-built in repo**: Check compiled `.js` into the repo alongside `.ts`. Add `*.ts` to
   vendor excludes. Consumer gets `.js` only. Framework developers keep both.

Option 2 is simpler -- no build step required during vendoring. The exclude change is one line:

```bash
local excludes=( __pycache__ "*.pyc" ".DS_Store" "*.ts" "tsconfig.json" )
```

## Q3: Can Hooks Detect Node.js and Fall Back to Python?

**Yes -- pattern already exists.** `lib/preflight.sh:114` checks `command -v python3`.
`lib/validate-init.sh:58` does the same. A runtime detection function is trivial:

```bash
if command -v node >/dev/null 2>&1; then
    node "$FRAMEWORK_ROOT/lib/fw-util.js" yaml-get "$file" "$field"
else
    python3 -c "import yaml; print(yaml.safe_load(open('$file'))['$field'])"
fi
```

This can be a shared helper in `lib/runtime.sh`, sourced by all hooks. Cost: one `command -v`
check per invocation (~1ms), cacheable in an env var for the session.

## Q4: Is a Dual-Mode Pattern Feasible?

**Yes. Three tiers of feasibility:**

| Tier | Pattern | Complexity | Recommendation |
|------|---------|-----------|----------------|
| A | `.js` present -> use node; else -> python3 fallback | Low | Start here |
| B | Compiled single binary (esbuild bundle) -> no runtime detection needed | Medium | Target state |
| C | Full polyglot (bash/python/node all coexist per-component) | High | Avoid |

**Tier A** works today: vendor ships `.js` files, hooks check for node, fall back to python3.
Both runtimes produce identical output for YAML/JSON/path operations.

**Tier B** is the end state: `esbuild --bundle --platform=node` produces a single `.js` file
with zero npm dependencies (js-yaml inlined). The vendored artifact is one file, ~50KB.

**Tier C** is what NOT to do -- maintaining three implementations per operation is unsustainable.

## Q5: Impact on .framework.yaml

Minimal. Current fields: `project_name`, `version`, `provider`, `initialized_at`, `upstream_repo`.
No runtime or language configuration exists. Suggested addition:

```yaml
runtime_preference: auto    # auto | node | python
```

`auto` (default): framework detects available runtime. `node`: require Node.js, fail if absent.
`python`: force Python path even if Node.js is available. This is optional -- the detection
helper can work without it.

## Recommendation

1. Add `*.ts` and `tsconfig.json` to vendor excludes in `do_vendor()`
2. Pre-compile `.ts` to `.js` and check both into the repo
3. Create `lib/runtime.sh` with a `fw_exec()` helper that prefers node, falls back to python3
4. No `.framework.yaml` changes needed initially -- runtime detection is automatic
5. Consumer projects without Node.js continue working via Python fallback with zero config change
