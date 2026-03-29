# T-702: Single-Source-of-Truth Generation Research

## Problem Statement

The framework maintains three coupled artifacts that must stay in sync:

1. **CLAUDE.md** (1024 lines) — Behavioral rules, enforcement tiers, agent protocols, hook documentation
2. **`.claude/settings.json`** — Hook configuration (14 hooks across 4 event types)
3. **`lib/init.sh`** — Generates CLAUDE.md + settings.json for consumer projects (inline heredoc, lines 543-691)

When a hook is added, removed, or changed, all three must be updated. Additionally:
- `lib/upgrade.sh` compares hooks between framework and consumer (lines 494-605)
- `.agentic-framework/` is a vendored copy that must mirror the framework's versions
- CLAUDE.md documents hooks, enforcement tiers, and agent rules — some of which describe what hooks do

**Current sync mechanism:** Manual. When a hook is added (e.g., T-709 ntfy notifications, T-651 agent dispatch gate), the developer updates settings.json, then init.sh heredoc, then CLAUDE.md documentation, then the vendored copy. The `fw upgrade` command detects missing hooks by comparing hook names, but cannot detect documentation drift in CLAUDE.md.

## What "Single Source of Truth" Would Mean

A structured manifest (e.g., `governance.yaml` or `manifest.yaml`) would declare:
- Every hook: event type, matcher, command, description, enforcement tier
- Every behavioral rule: section name, priority, origin task
- Every enforcement tier: what it covers, how it's enforced

Then generators would produce:
- `.claude/settings.json` from the hook declarations
- CLAUDE.md sections from the rule declarations
- `lib/init.sh` would call the generator instead of using inline heredocs
- `lib/upgrade.sh` would compare manifests instead of parsing JSON

## Analysis

### Current State Inventory

**Hooks (14 total):**

| Event | Matcher | Hook | Purpose |
|-------|---------|------|---------|
| PreCompact | (all) | pre-compact | Auto-handover before compaction |
| SessionStart | compact | post-compact-resume | Context recovery |
| SessionStart | resume | post-compact-resume | Context recovery |
| PreToolUse | EnterPlanMode | block-plan-mode | Block built-in plan mode |
| PreToolUse | Write\|Edit | check-active-task | Task gate (Tier 1) |
| PreToolUse | Bash | check-tier0 | Destructive command gate (Tier 0) |
| PreToolUse | Agent | check-agent-dispatch | TermLink-first enforcement |
| PreToolUse | Write\|Edit\|Bash | check-project-boundary | Prevent outside-root edits |
| PreToolUse | Write\|Edit\|Bash | budget-gate | Context budget enforcement |
| PostToolUse | (all) | checkpoint post-tool | Budget monitoring |
| PostToolUse | Bash | error-watchdog | Error pattern detection |
| PostToolUse | Task\|TaskOutput | check-dispatch | Dispatch guard |
| PostToolUse | (all) | loop-detect | Loop detection |
| PostToolUse | Write | check-fabric-new-file | Fabric registration reminder |
| PostToolUse | Write\|Edit | commit-cadence | Commit cadence reminder |

**CLAUDE.md sections that describe hooks:**
- §Enforcement Tiers table
- §Context Budget Management (mentions budget-gate.sh, checkpoint.sh)
- §Plan Mode Prohibition (mentions EnterPlanMode hook)
- §Session Start Protocol (mentions SessionStart hooks)
- §Commit Cadence and Check-In (mentions budget-gate.sh)

**Duplication points:**
- `settings.json` ↔ `init.sh` heredoc: identical JSON, duplicated verbatim
- `settings.json` ↔ `upgrade.sh` hook analysis: upgrade script parses JSON to extract hook names
- `settings.json` ↔ CLAUDE.md: hook behavior described in prose, not linked to config

### What a Manifest Would Look Like

```yaml
# governance-manifest.yaml (hypothetical)
hooks:
  - event: PreToolUse
    matcher: "Write|Edit"
    command: check-active-task
    tier: 1
    description: "Task gate — blocks edits without active task"
    doc_section: enforcement-tiers

  - event: PreToolUse
    matcher: "Bash"
    command: check-tier0
    tier: 0
    description: "Destructive command gate — force push, rm -rf, etc."
    doc_section: enforcement-tiers

rules:
  - section: authority-model
    priority: 1
    content_file: docs/rules/authority-model.md

  - section: task-system
    priority: 2
    content_file: docs/rules/task-system.md
```

### Tradeoffs

**Benefits:**
1. **One change = one file** — add a hook in manifest.yaml, run `fw generate`, all outputs update
2. **Drift detection** — `fw audit` can compare generated vs actual
3. **Consumer project parity** — init.sh and upgrade.sh read manifest instead of duplicating
4. **Self-documenting** — manifest shows all hooks with descriptions, not just JSON config

**Costs:**
1. **CLAUDE.md is not fully generatable** — ~60% of CLAUDE.md is hand-written prose (behavioral rules, protocols, examples). Only the hook configuration tables and enforcement tier descriptions could be generated. The rest is hand-authored
2. **Complexity shift** — trades "update 3 files" for "maintain a generator + manifest schema + template engine"
3. **Template maintenance** — CLAUDE.md template needs to accommodate both generated sections and hand-authored sections. Jinja/mustache? Section markers? Includes? Each has its own maintenance burden
4. **Existing `fw upgrade` works** — the current hook diffing in upgrade.sh already catches missing hooks. The drift that T-702 targets is primarily documentation drift in CLAUDE.md, which is low-frequency
5. **T-316 NO-GO context** — layered CLAUDE.md was rejected because there's no include mechanism. Generating CLAUDE.md from sections faces the same fundamental problem: the file must be one contiguous markdown file that Claude Code loads

### Scoping the Actual Problem

The real pain points, ranked:

1. **`init.sh` heredoc duplication** — 150 lines of JSON duplicated from settings.json. This is the worst offender. When a hook changes, init.sh must be manually updated.
   - **Fix without manifest:** `init.sh` can just copy `$FRAMEWORK_ROOT/.claude/settings.json` and do string replacement for `fw_prefix`. This is ~5 lines of code.

2. **CLAUDE.md hook documentation drift** — when hooks are added/removed, CLAUDE.md prose may not be updated.
   - **Fix without manifest:** `fw audit` could compare settings.json hooks against CLAUDE.md mentions (grep). This is a new audit check, ~20 lines.

3. **Vendored copy sync** — `.agentic-framework/` must mirror framework files.
   - **Fix without manifest:** Already handled by `fw upgrade` copy step. Low friction.

## Recommendation

**NO-GO** — the problem is real but the solution is over-engineered for the actual pain.

### Rationale

The single-source-of-truth manifest solves a coordination problem that has simpler fixes:

1. **init.sh heredoc → copy + sed** — replace 150 lines of duplicated JSON with: `cp $FRAMEWORK_ROOT/.claude/settings.json $target && sed -i "s|bin/fw|$fw_prefix|g" $target/.claude/settings.json`. This eliminates the worst duplication in ~5 lines.

2. **CLAUDE.md drift → audit check** — add a check to `fw audit` that greps CLAUDE.md for each hook name in settings.json. If a hook exists but isn't mentioned in CLAUDE.md, emit WARN. ~20 lines of bash.

3. **The generator + manifest + template engine** would be at least 200-300 lines of new infrastructure to maintain, for a problem that affects ~5 hooks/year. The ROI doesn't justify the complexity.

4. **CLAUDE.md is 60% prose** — the generated portions would be small islands in hand-authored text. Maintaining section markers and ensuring the generator doesn't clobber edits is itself a maintenance burden.

### Evidence

- Hook change frequency: ~5 hooks added in T-650 through T-709 (last ~30 tasks). Average: 1 hook per 6 tasks
- CLAUDE.md last changed hooks section: T-577 (CLAUDE.md TermLink orphan warning), T-596 (context window update). Low frequency
- init.sh heredoc is a verbatim copy of settings.json — measurable via `diff <(python3 -c "...extract json from heredoc...") .claude/settings.json`
- T-316 (layered CLAUDE.md) NO-GO: no include mechanism, fw upgrade merge works

### Alternative: Two Targeted Fixes

Instead of a manifest system, two bounded tasks would address the actual pain:

1. **T-702a: init.sh settings.json generation via copy+sed** — replace heredoc with file copy. ~1 session, bounded
2. **T-702b: audit hook-documentation consistency check** — WARN if settings.json hook not mentioned in CLAUDE.md. ~1 session, bounded

These are incremental improvements (Error Escalation Ladder level C) that address the real friction without introducing new infrastructure.
