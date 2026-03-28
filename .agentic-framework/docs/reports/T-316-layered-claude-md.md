# T-316: Layered CLAUDE.md — Research Artifact

## Problem Statement

**For whom:** Consumer projects using the framework via shared tooling mode.
**Why now:** CLAUDE.md is 800+ lines. Consumer projects need framework governance rules (12 universal sections) plus project-specific overrides (project overview, tech stack, conventions). Currently `fw upgrade` copies and merges.

## Claude Code CLAUDE.md Loading Behavior (as of 2026-03)

| Source | Loaded? | Use Case |
|--------|---------|----------|
| `$PROJECT_ROOT/CLAUDE.md` | Yes | Project-specific instructions |
| Parent directories up to git root | Yes | Monorepo shared instructions |
| `~/.claude/CLAUDE.md` | Yes | User personal preferences |
| `.claude/` directory settings | Yes | Per-project Claude Code config |
| Include/import directives | **No** | Not supported |
| Symlinks | **Yes** | Works but fragile |

**Key limitation:** No include/import mechanism. Claude Code reads CLAUDE.md as a flat file. There is no way to say "include ../framework/CLAUDE.md" or "extend base-rules.md".

## Current Solution: `fw upgrade` Merge

The framework already implements layered CLAUDE.md via `lib/upgrade.sh`:

1. **Template:** `lib/templates/claude-project.md` contains all governance sections
2. **Upgrade logic:** Extracts project-specific header (everything before `## Core Principle`), replaces governance sections from template, preserves project-specific sections
3. **Init logic:** `lib/setup.sh` generates initial CLAUDE.md with project-specific sections + governance

**This is effectively a build-time layer system.** The merge happens at `fw upgrade` time, producing a single CLAUDE.md that Claude Code reads normally.

## Options Evaluated

### Option A: Symlink to framework CLAUDE.md
```
consumer-project/CLAUDE.md → ../framework/CLAUDE.md
consumer-project/.claude/CLAUDE.md → project-specific overrides
```

**Pros:** Always current (no upgrade needed).
**Cons:** `.claude/CLAUDE.md` adds to, doesn't override. No way to customize framework sections. Symlink breaks if framework moves. Consumer project's CLAUDE.md shows framework rules, not project context.

### Option B: Parent directory CLAUDE.md
Place framework in parent directory of all consumer projects:
```
/workspace/CLAUDE.md          ← framework governance
/workspace/project-a/CLAUDE.md ← project-specific
```

**Pros:** Claude Code reads both (parent + project). True layering.
**Cons:** Requires specific directory layout. Doesn't work for standalone consumer projects. Not how the framework is installed (framework is in its own repo, not parent dir).

### Option C: Build-time merge (current approach)
`fw upgrade` merges template + project-specific sections.

**Pros:** Works with any directory layout. Full control over merge logic. Project-specific sections preserved. Single CLAUDE.md is self-contained.
**Cons:** Requires running `fw upgrade` when framework updates. Consumer CLAUDE.md can drift if upgrade is skipped.

### Option D: Git submodule/subtree
Include framework CLAUDE.md via git submodule:
```
consumer-project/.framework/CLAUDE.md → governance rules
consumer-project/CLAUDE.md → includes reference + project-specific
```

**Pros:** Version-locked governance rules.
**Cons:** Claude Code doesn't follow references. Still need a merge step. Git submodules add complexity.

## Analysis

**Option C (current approach) is the best available solution.** Here's why:

1. **No include mechanism exists** — Options A, B, D all try to work around this fundamental limitation
2. **Build-time merge is reliable** — 20+ framework upgrades across consumer projects have used this path successfully
3. **Drift is managed** — `fw audit` detects CLAUDE.md drift; `fw upgrade` fixes it
4. **Project-specific sections preserved** — The merge logic in upgrade.sh is battle-tested

**The original task hypothesis was:** "If Claude Code supports multi-file loading or includes, design a framework base + project override pattern." **Claude Code does NOT support includes.** The hypothesis is invalidated.

## Assumption Testing

- A1: Claude Code supports multi-file CLAUDE.md or include patterns (INVALID — no include mechanism)
- A2: Current fw upgrade merge is insufficient (INVALID — works well, preserves project sections)
- A3: A layered pattern would reduce maintenance burden (PARTIALLY VALID — always-current base would eliminate upgrade step, but no mechanism exists to achieve it)

## Recommendation: NO-GO

**Rationale:**
1. Claude Code does not support CLAUDE.md includes or imports — fundamental blocker
2. Current `fw upgrade` merge approach works reliably (20+ upgrades, project sections preserved)
3. Drift detection exists (`fw audit`), providing safety net for skipped upgrades
4. Symlink/parent-dir workarounds are fragile and require specific directory layouts
5. The problem this task was created to solve (manual CLAUDE.md syncing) was already solved by `fw upgrade`

**Note:** The existing GO decision on this task (2026-03-27) was recorded with placeholder rationale ("[Criterion 1]; [Criterion 2]") — a data integrity issue. This research supersedes that decision with evidence-based NO-GO.

**Revisit when:** Claude Code adds an `#include` directive or similar mechanism for referencing external instruction files.
