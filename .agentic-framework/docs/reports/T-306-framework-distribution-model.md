# T-306: Framework Distribution Model — Split vs Self-Contained

## Research Artifact

**Task:** T-306 (Inception)
**Created:** 2026-03-04
**Source:** T-294 dialogue finding #4 — "Version mingling is an architectural problem"

---

## Problem Statement

The framework currently serves two roles from one repo:
1. **Self-hosting dev project** — develops itself using its own governance
2. **Shared tooling provider** — other projects reference it via `.framework.yaml → framework_path`

This creates **version mingling**: consumer projects execute live agents/scripts from the framework repo (always at HEAD) but hold frozen copies of CLAUDE.md, settings.json, seeds, and templates (captured at `fw init` time). Half the project runs at init-time version, half at current version.

### The Concrete Problem

```
/opt/framework/          ← at v2.5 (HEAD)
  agents/audit/audit.sh  ← v2.5 (live, always current)
  lib/seeds/practices.yaml ← v2.5 (live)

/opt/my-project/         ← initialized at v2.0
  CLAUDE.md              ← v2.0 (frozen copy from init)
  .claude/settings.json  ← v2.0 (frozen copy from init)
  .context/project/practices.yaml ← v2.0 (frozen seed copy)
```

When the framework adds a new audit check at v2.5 that references a CLAUDE.md section that only exists in v2.5, consumer projects running v2.0 CLAUDE.md get confusing failures.

---

## Current Architecture Analysis

### What Runs Live (from framework repo)
| Component | Path | Versioned? |
|-----------|------|------------|
| Agent scripts | `agents/*/` | No — always HEAD |
| Agent AGENT.md | `agents/*/AGENT.md` | No — always HEAD |
| fw CLI | `bin/fw` | No — always HEAD |
| Lib modules | `lib/*.sh` | No — always HEAD |
| Watchtower | `web/` | Separate deployment |

### What's Frozen (copied at init-time)
| Component | Path in project | Source |
|-----------|----------------|--------|
| CLAUDE.md | `CLAUDE.md` | `lib/templates/claude-project.md` |
| settings.json | `.claude/settings.json` | Generated in `init.sh` |
| Task templates | `.tasks/templates/` | Copied from framework |
| Seed practices | `.context/project/practices.yaml` | `lib/seeds/practices.yaml` |
| Seed decisions | `.context/project/decisions.yaml` | `lib/seeds/decisions.yaml` |
| Seed patterns | `.context/project/patterns.yaml` | `lib/seeds/patterns.yaml` |
| Git hooks | `.git/hooks/` | Installed by git agent |

### What's Generated Fresh
| Component | When |
|-----------|------|
| Session state | `fw context init` |
| Tasks | User creates |
| Handovers | End of session |
| Episodic memory | Task completion |

---

## Assumptions to Test

1. **A-001:** Version mingling causes real breakage (not just theoretical)
2. **A-002:** Consumer projects need all framework agents, not a subset
3. **A-003:** The frozen artifacts diverge meaningfully over time (not just cosmetic)
4. **A-004:** Users can tolerate a "pull + migrate" workflow for updates

---

## Options Under Consideration

### Option 1: Status Quo + Upgrade Command
Keep shared tooling model. Add `fw upgrade` that re-runs the frozen-artifact generation to sync with current framework version.

**Pros:** Minimal change, addresses the real pain (stale frozen artifacts)
**Cons:** Still path-coupled, still requires framework accessible at runtime

### Option 2: Versioned Releases (Git Tags)
Tag framework releases. `fw init` records the version. `fw upgrade` diffs and migrates.

**Pros:** Explicit versioning, reproducible, can test compatibility
**Cons:** Framework evolves fast — release overhead, still path-coupled

### Option 3: Vendored Distribution
`fw vendor /path/to/project` copies a complete runnable subset into `.framework/` inside the project.

**Pros:** Self-contained, offline-capable, no path coupling
**Cons:** Larger projects, divergence risk, update friction

### Option 4: Symlink Runtime + Frozen Seeds (Hybrid)
Runtime components (agents, lib, bin) stay shared. Seeds become symlinks or are regenerated on `fw upgrade`.

**Pros:** Best of both — always-current runtime, explicit seed management
**Cons:** Symlinks can break, two upgrade paths to explain

### Option 5: Clean CLI Separation
Split framework into: (a) CLI package (`fw` binary + agents + lib), (b) project scaffold (seeds, templates, CLAUDE.md). CLI is installed system-wide, scaffold is per-project.

**Pros:** Clean boundary, standard distribution, independent versioning
**Cons:** Significant refactoring, self-hosting becomes complex

---

## Dialogue Log

(To be filled during inception dialogue with human)

---

## Spike 1 Findings: Version-Sensitive Touchpoints

### BREAKING Risk (functional failure if framework changes)

| Frozen Artifact | What It References | Break Scenario |
|---|---|---|
| CLAUDE.md | All agent paths (`agents/task-create/`, etc.) | Framework renames/moves agent → docs reference dead paths |
| CLAUDE.md | Gate IDs (P-002, P-010, P-011) | Framework removes gate → frozen CLAUDE.md still instructs agent to use it |
| CLAUDE.md | `fw` subcommands (`fw task create`, `fw inception decide`) | CLI interface change → frozen instructions reference nonexistent commands |
| settings.json | Hook script paths (`check-active-task.sh`, `budget-gate.sh`, etc.) | Framework moves/renames hook scripts → hooks silently fail |
| commit-msg hook | `.tasks/active/${TASK_REF}-*.md` pattern | Task directory renamed → hook can't find tasks |
| commit-msg hook | `docs/reports/${TASK_REF}-*` pattern | Research artifact path changed → inception gate breaks |
| commit-msg hook | Decision format `**Decision**: (GO|NO-GO|DEFER)` | Decision format changed → inception commit gate breaks |
| resume.md | `.context/handovers/LATEST.md`, `.context/working/.tool-counter` | Context paths renamed → resume skill can't find state |

### WARNING Risk (confusing but functional)

| Frozen Artifact | What It References | Break Scenario |
|---|---|---|
| .framework.yaml | `version` field | No version-checking on hook mismatch — stale hooks run silently |
| Task templates | Frontmatter schema (id, workflow_type, status) | New fields added → mixed schema across projects |
| commit-msg hook | bypass-log.yaml path | Path wrong → bypass logging lost but commits still work |

### COSMETIC Risk (no functional impact)

| Frozen Artifact | What It References | Break Scenario |
|---|---|---|
| Seed files | Initial practices, decisions, patterns | Seeds go stale but user content accumulates independently |
| resume.md | Suggested commands | Instructions outdated but non-critical |

### Key Insight: The Stability Contract

The framework implicitly guarantees backward compatibility on:
- Agent directory paths (`agents/{name}/`)
- Context directory structure (`.tasks/active/`, `.context/working/`, `.context/handovers/`)
- Task file naming (`T-NNN-slug.md`) and YAML keys (`id`, `status`, `workflow_type`, `owner`)
- Inception magic strings (decision format, research artifact path)

**Gap identified:** No version-checking mechanism exists. If framework version increases but project hooks aren't reinstalled, projects run stale hooks silently with no warning.

---

## Spike 2 Analysis: fw upgrade Feasibility

### What `fw upgrade` Would Need to Do

From `init.sh`, the frozen artifacts fall into clear categories:

| Category | Files | Upgrade Strategy |
|----------|-------|-----------------|
| **Regeneratable** | CLAUDE.md, settings.json, resume.md | Re-run generator, diff, show user changes |
| **Copyable** | Task templates | Re-copy from framework, preserve user additions |
| **Seed-only** | practices.yaml, decisions.yaml, patterns.yaml | DO NOT overwrite — merge new universal items by ID |
| **Static** | directives.yaml, gaps.yaml, learnings.yaml | Leave alone (user-owned) |
| **Re-installable** | Git hooks | Re-run `fw git install-hooks` |
| **Config** | .framework.yaml | Update `version` field |

### Complexity: Low-Medium

The only genuinely hard part is seed file merging (YAML merge by ID). Everything else reuses existing generator functions. Version check for `fw doctor` is trivial.

---

## Assumption Validation

| Assumption | Result | Evidence |
|---|---|---|
| A-001: Version mingling causes real breakage | **VALIDATED** | 8 BREAKING touchpoints. Agent renames break CLAUDE.md. Hook script moves break settings.json. |
| A-002: Consumer projects need all agents | **PARTIAL** | All referenced in CLAUDE.md, but some unused. Still needed for completeness. |
| A-003: Frozen artifacts diverge meaningfully | **VALIDATED** | CLAUDE.md changed significantly (T-193 AC split, T-139 budget mgmt, T-179 auto-restart). |
| A-004: Users tolerate pull + migrate | **PLAUSIBLE** | Comparable to `terraform init -upgrade`. Sovereignty pattern (diff, consent) makes it safe. |

---

## Recommendation

**GO with Option 1+2 hybrid: `fw upgrade` command with version tracking.**

1. Shared tooling model is fine for single-machine usage (current reality)
2. Real problem is stale frozen artifacts, not the distribution model itself
3. `fw upgrade` with sovereignty pattern (diff, show changes, ask consent) solves the pain
4. Version check in `fw doctor` catches drift early
5. Vendored/package distribution is premature

**Build tasks if GO:**
1. Add `fw upgrade` command (regenerate frozen artifacts with diff + consent)
2. Add version check to `fw doctor` (compare .framework.yaml vs fw --version)
3. Add seed merge logic (YAML merge by ID for practices/decisions/patterns)

---

## Agent Investigation (10 agents, batch 1+2)

### Agent Results Summary

| # | Agent | Key Finding |
|---|-------|-------------|
| 1 | Live vs frozen inventory | 46 live, 9 frozen, 15 generated — clear separation |
| 2 | Other frameworks' upgrade patterns | Helm layered overrides + Rails interactive diff best fit |
| 3 | Runtime generation feasibility | **2/10** — Claude Code snapshots hooks at start, no extends/include |
| 4 | Settings.json hook drift | Consumer gets **5 of 10 hooks** — missing budget-gate, plan blocker, pre-compact, dispatch, resume |
| 5 | CLAUDE.md drift | **~70% governance loss** — 7 of 18 sections missing |
| 6 | Seed file merge complexity | Tractable — all have unique IDs, merge-by-ID works |
| 7 | Git hook version coupling | Hooks are **frozen inline copies** (164-776 lines), not delegating wrappers — 8 breaking touchpoints |
| 8 | Helm-style layered override design | 12 universal sections (auto-update) + 5 project-specific. Recommends fw upgrade given no Claude Code include support |
| 9 | Version check for fw doctor | 4 checks designed: version mismatch (WARN), hook count (WARN), template count (INFO), CLAUDE.md staleness (INFO) |
| 10 | Synthesis | GO — Phase 1 fixes generator bugs, Phase 2 builds fw upgrade, Phase 3 spikes layered config |

Full agent output files: `/tmp/fw-agent-t306-*.md`

### Key Reframe

The original framing ("version mingling — split vs self-contained") conflated three separable problems:
1. **Hook generation drift (CRITICAL)** — generator bug, not architecture
2. **CLAUDE.md governance loss (~70%)** — template gap, not architecture
3. **Frozen artifact drift (9 files)** — needs upgrade tool, but scope is bounded

The distribution model (live agents + frozen config) is sound. The bug is that frozen config generation was never maintained as the framework grew.

## Dialogue Log

- Human asked to revisit Phase 1-3 work before discussing options
- Agent dispatched 10 investigation agents (2 batches of 5)
- Findings reframed the problem from architectural to generator maintenance
- Human approved GO decision

## Decision

**Decision:** GO (2026-03-04)

**Rationale:** Three separable problems found. Distribution model is sound; generators need fixing. Phase 1 (fix generators) is bugs not features. Phase 2 (fw upgrade) is well-scoped. Phase 3 (layered config) is a future spike.

**Build Tasks:**
- Phase 1: Fix settings.json hook generation + Fix CLAUDE.md template completeness
- Phase 2: Build `fw upgrade` command (audit → propose → apply)
- Phase 3: Spike layered CLAUDE.md (contingent on Claude Code capabilities)
