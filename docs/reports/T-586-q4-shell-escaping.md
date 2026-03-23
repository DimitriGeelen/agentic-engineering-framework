# T-586 Q4: Shell-Escaping Fragility in Inline Python Blocks

**Date:** 2026-03-23
**Scope:** All `python3 -c` and `python3 <<` invocations in `.sh` files (excluding `.agentic-framework/` mirror)

## Summary

120 `python3 -c` and 24 `python3 <<` invocations across 49 shell files.
**84 invocations (58%) use double-quoted `python3 -c` with shell variable interpolation** — the pattern most vulnerable to breakage from quotes, newlines, or special characters in input.

## Categorization

| Category | Count | Risk | Description |
|----------|-------|------|-------------|
| **F: `python3 -c "...$VAR..."`** | **84** | **UNSAFE** | Shell vars interpolated directly into Python source |
| D: Unquoted heredoc `python3 << TAG` | 11 | MODERATE | Shell vars interpolated but multi-line (easier to read/audit) |
| A: Piped stdin `echo "$X" \| python3 -c` | 34 | LOW | Data via stdin, Python reads `sys.stdin` |
| B: Quoted heredoc `python3 << 'TAG'` | 13 | SAFE | No shell interpolation |
| C: Single-quoted `python3 -c '...'` | 2 | SAFE | No shell interpolation |
| E: `python3 -c "..."` no vars | 6 | SAFE | Import checks only (`import yaml`, `import flask`) |

**Total: 150 invocations. 95 (63%) involve shell variable interpolation into Python.**

## Risk Breakdown of the 84 Unsafe Invocations

### Tier 1 — File paths only (lower risk, but still breaks on paths with quotes/spaces)

~22 invocations use vars only inside `open('$VAR')` for file parsing. These break if a path contains single quotes.

**Examples:**
- `lib/validate-init.sh:155` — `python3 -c "import yaml; yaml.safe_load(open('$full_path'))"`
- `lib/validate-init.sh:198` — `python3 -c "import json; json.load(open('$full_path'))"`
- `agents/audit/audit.sh:1487` — `python3 -c "import json; d=json.load(open('$BUDGET_FILE'))..."`
- `tests/test-knowledge-capture.sh:69-178` — 13 instances with `open('$TEST_PROJECT/...')`

### Tier 2 — File paths + key names / simple vars

~30 invocations interpolate controlled vars (task IDs, timestamps, file paths) into Python string literals.

**Examples:**
- `lib/validate-init.sh:204` — `assert '$key' in d` (key from YAML frontmatter)
- `agents/audit/audit.sh:1892` — `datetime.fromisoformat('$t_date'.replace('Z'...))` (date from task file)
- `agents/fabric/lib/register.sh:27` — `os.path.relpath('$file', '$PROJECT_ROOT')`
- `agents/fabric/lib/register.sh:114` — `fnmatch.fnmatch('$rel_path', r.get('pattern',''))`
- `agents/context/lib/focus.sh:49-62` — `'$task_id'`, `'$session_id'` into YAML writer

### Tier 3 — User-controlled content (HIGHEST RISK)

~10 invocations inject content that could contain arbitrary characters (quotes, backslashes, newlines).

**Critical examples:**
- `agents/context/check-tier0.sh:183-184` — `'risk': '$DESCRIPTION'` and `'command_preview': '''${COMMAND:0:120}'''` — bash command text injected into Python dict literal. A command containing `'''` breaks the triple-quote.
- `agents/task-create/create-task.sh:161-179` — Multiple `$TAGS_YAML`, `$RELATED_YAML`, `$FILEPATH` interpolated. Task names passed via `sys.argv` (safe) but paths and YAML arrays via interpolation (unsafe).
- `agents/handover/handover.sh:324-353` — `'$PROJECT_ROOT'` in `git -C` subprocess call.

### Unquoted Heredocs (11 instances — moderate risk)

These interpolate shell vars but are easier to audit. All in:
- `agents/audit/audit.sh` (4 instances: lines 1099, 2056, 2529)
- `agents/handover/handover.sh` (4 instances: lines 360, 511, 537)
- `agents/observe/observe.sh:125`
- `lib/harvest.sh:204`
- `lib/bus.sh` (2 instances: lines 238, 274, 334)

## What Percentage Would Break?

**On paths with single quotes:** ~22 file-path-only invocations break immediately (e.g., `/tmp/user's file.yaml`).

**On content with quotes/backslashes:** ~10 Tier 3 invocations break. The `check-tier0.sh` bypass logger is the highest-impact — a destructive command containing quotes would corrupt the audit log.

**On content with newlines:** Most multiline `python3 -c` blocks would survive (Python handles embedded newlines in triple-quoted strings). But single-quoted `open('$VAR')` patterns break if the path contains a newline.

**Estimate: 32 of 84 unsafe invocations (38%) would break on input containing quotes.** The remaining 52 use vars that are structurally constrained (task IDs like `T-123`, ISO timestamps, known directory paths).

## Safe Patterns Already in Use (follow these)

1. **Piped stdin** (34 instances) — `echo "$INPUT" | python3 -c "import json,sys; json.load(sys.stdin)"` — data never touches Python source.
2. **Quoted heredoc** (13 instances) — `python3 << 'EOF'` — no interpolation at all; vars passed via env or files.
3. **sys.argv** — `create-task.sh` passes `$NAME` and `$DESCRIPTION` via `sys.argv[1]`/`sys.argv[2]` (safe), but mixes this with direct interpolation of other vars (unsafe).

## Recommended Remediation Priority

1. **check-tier0.sh:176-184** — Audit-log writer injects `$COMMAND` into Python. Replace with heredoc + `os.environ`.
2. **create-task.sh:161-199** — Replace interpolated vars with `sys.argv` or env vars.
3. **validate-init.sh:155,198,204** — Replace `open('$VAR')` with stdin or `sys.argv[1]`.
4. **All 22 `open('$path')` patterns** — Systematic replacement: pass path via `sys.argv[1]`.
5. **Unquoted heredocs (11)** — Convert to quoted heredocs with env var passing.
