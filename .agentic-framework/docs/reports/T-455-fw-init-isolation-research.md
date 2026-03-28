# T-455: fw init — Isolation, Onboarding Modes, Knowledge Separation

**Research Date:** 2026-03-12
**Status:** Spikes complete, awaiting design decisions
**Spikes:** 5 parallel research agents

---

## Problem Statement

When `fw init` initializes a consumer project, the framework's own governance data (441 tasks, 58 decisions, 100 learnings, 15 patterns) bleeds into the project. The consumer sees framework-specific decisions, patterns, and controls that have nothing to do with their project. Simultaneously, the onboarding experience is incomplete — few starter tasks, no validation that the framework actually works, and no distinction between greenfield and existing-project modes.

## Core Tension

**Framework knowledge is functional, not just historical.** The audit system, healing loop, and CLAUDE.md rules reference specific decisions and patterns. Stripping all framework data breaks governance. Keeping all of it pollutes the consumer project.

---

## Spike 1: fw init Audit — What It Does, What Breaks

### Current Init Steps (11 total, lib/init.sh)
1. Parse arguments (--provider, --force, --no-first-run)
2. Create 17 directories (.tasks/, .context/, etc.)
3. Copy task templates from framework
4. Create .framework.yaml (project_name, framework_path, version, provider)
5. **Seed 6 project memory files** ← THE PROBLEM
6. Generate provider-specific config (CLAUDE.md, settings.json with 10 hooks)
7. Install git hooks (commit-msg, post-commit, pre-push)
8. Ensure fw in PATH
9. Post-init validation (validate-init.sh)
10. Activate governance (context init)
11. Auto-create onboarding tasks (3 for existing, 1 for greenfield)

### Path Isolation: CORRECT
All agents use lib/paths.sh → PROJECT_ROOT resolves to git toplevel. All 19 agents, all 10 hooks, all budget/checkpoint scripts correctly scoped. G-007 (budget gate bug) fixed in T-149.

### The Real Problem: Step 5 — Knowledge Seeding
| File | Source | What Gets Copied |
|------|--------|-----------------|
| practices.yaml | lib/seeds/ | 10 framework practices |
| decisions.yaml | lib/seeds/ | 18 framework decisions |
| patterns.yaml | lib/seeds/ | 12 framework patterns |
| learnings.yaml | inline | Empty (clean) |
| assumptions.yaml | inline | Empty (clean) |
| directives.yaml | inline | 4 constitutional directives (universal) |
| concerns.yaml | inline | Empty (clean) |

Three files (practices, decisions, patterns) contain framework-specific data that pollutes consumer projects.

---

## Spike 2: Knowledge Taxonomy — Universal vs Pollution

| Category | Total | Universal | Framework-Specific | Universal % |
|----------|-------|-----------|-------------------|-------------|
| Decisions | 58 | 24 | 34 | 41% |
| Learnings | 100 | 64 | 36 | 64% |
| Patterns | 15 | 15 | 0 | 100% |
| Concerns | 19 | 11 | 8 | 58% |
| **TOTAL** | **192** | **114** | **78** | **59%** |

### What's Universal (needed for governance)
- **Decisions:** D-001 (commit-msg hook), D-004 (Tier 0 = FAIL), D-013 (files as source of truth), D-014 (4-status lifecycle), D-027 (disable compaction), D-029 (sovereignty gate)
- **Learnings:** L-002 (structural enforcement > agent discipline), L-005 (fail visibly), L-025 (sub-agent result management), L-038 (verification gate > advisory skills)
- **Patterns:** ALL patterns are universal (failure modes, success patterns, workflow patterns)

### What's Pollution (framework-specific)
- D-012 (Flask + htmx), D-022–D-048 (Watchtower UI, deployment, CI/CD)
- L-068–L-076 (production deployment patterns)
- G-015–G-019 (framework development workflow gaps)

### Audit Dependencies
Only ~5 audit checks directly depend on specific decision IDs. Most checks verify mechanism presence, not which decision created them. CLAUDE.md references D-027 and P-009/P-010/P-011 explicitly.

---

## Spike 3: Onboarding Tasks — What Should Be Auto-Created

### Current State
- **Existing project:** 3 tasks (ingest codebase, register fabric, create handover)
- **Greenfield:** 1 task (define goals/architecture inception)

### Gaps
1. No framework orientation task (user hits jargon wall)
2. No `fw doctor` validation task (T-294 O-009: audit fails on fresh projects)
3. No first-commit proof (proves the governance loop works)
4. No handover cycle task (proves session continuity)

### Proposed: Mode A (Existing Project) — 7 Tasks
| Phase | Task | Type | Owner | Purpose |
|-------|------|------|-------|---------|
| 1. Orientation | Framework overview | inception | human | Understand concepts |
| 2. Health | Run fw doctor | build | agent | Fix any issues |
| 2. Health | Establish audit baseline | build | human | Understand metrics |
| 3. Hands-on | First governed commit | build | agent | Prove task system |
| 3. Hands-on | Complete task cycle | build | human | Learn workflow |
| 3. Hands-on | Generate first handover | build | human | Prove continuity |
| (existing) | Ingest codebase | build | agent | Understand project |

### Proposed: Mode B (Greenfield) — 6 Tasks
| Phase | Task | Type | Owner | Purpose |
|-------|------|------|-------|---------|
| 1. Orientation | Framework overview | inception | human | Same as Mode A |
| 2. Planning | Outline first 3-5 tasks | inception | human | Bridge inception→build |
| 3. Skeleton | Create project structure | build | agent | Minimal setup |
| 3. Skeleton | Set up build/tooling | build | human | Tech stack proof |
| 4. Hands-on | Complete task cycle | build | human | Learn workflow |
| 4. Hands-on | Generate first handover | build | human | Prove continuity |

### Implementation: ~50-100 lines in init.sh, no new templates needed.

---

## Spike 4: Post-Init Validation — What Fails

### Validation Tiers
| Tier | Scope | Current Coverage |
|------|-------|-----------------|
| 1. Structural | Files, dirs, YAML parse | 90% (validate-init.sh) |
| 2. Functional | Hooks callable, first task works | **0%** |
| 3. Semantic | No framework leakage, correct isolation | **0%** |

### Critical Bugs Found
1. **commit-msg hook calls undefined `find_task_file()`** — inception gate silently fails
2. **Framework knowledge leakage** — practices/decisions/patterns copied from framework
3. **Onboarding task context confusion** — tasks mention "the framework" not the project

### Proposed Functional Checks (Tier 2)
- Hook scripts pass `bash -n` (syntax valid)
- All sourced dependencies exist
- `find_task_file()` defined before use
- First task creation succeeds
- First commit with task ref succeeds
- `fw doctor` passes
- `fw audit` structure section passes

### Proposed Semantic Checks (Tier 3)
- Governance files empty or properly scoped (not inherited framework)
- Component fabric empty (no framework internals)
- Onboarding tasks reference project, not framework
- No framework task IDs (T-XXX) in project governance files

---

## Spike 5: Prior Decisions — Historical Context

### Decision Thread: T-032 → T-033 → T-034 → T-101 → T-103
Established the shared tooling model: agents live in central framework, projects reference via .framework.yaml, PROJECT_ROOT env var.

### T-306: Version Mingling (March 4, 2026)
- Framework runs live agents (always at HEAD)
- Projects hold frozen copies of CLAUDE.md, settings.json, seeds (captured at init)
- 5/10 hooks missing in consumer projects (hook generation never maintained)
- 70% of governance guidance missing from generated CLAUDE.md
- GO decision: use `fw upgrade` command (T-169), not vendoring

### T-294: Onboarding Bugs (March 4-5, 2026)
- 9 bugs found in live simulation (O-001 through O-009)
- All fixed in T-295 through T-303
- Key insight: `fw work-on` is the only end-to-end working path

### Unresolved
- T-306 Phase 1-3: Hook generation fixes, fw upgrade sync, layered CLAUDE.md
- T-455 (this inception): First to tackle multi-mode initialization

---

## Design Questions for Decision

### Q1: How to handle framework knowledge?

| Option | Description | Pros | Cons |
|--------|-------------|------|------|
| A. Empty slate | Projects start with empty governance files | Clean, no confusion | Lose universal patterns/decisions |
| B. Curated universal seed | Ship only the 59% universal items | Best of both worlds | Needs maintenance (curation) |
| C. Two modes | `--seed-framework` opt-in, empty by default | User chooses | Complexity |
| D. Reference, don't copy | Project queries framework knowledge at runtime | Always current | Runtime dependency, complexity |

### Q2: What to call the two init modes?

| Option | Existing Project | New Project |
|--------|-----------------|-------------|
| A | `fw init --adopt` | `fw init --new` |
| B | `fw init --existing` | `fw init --greenfield` |
| C | `fw init` (auto-detect) | `fw init` (auto-detect) |
| D | `fw adopt` | `fw new` |

### Q3: Should seeded knowledge be updatable?

| Option | Description |
|--------|-------------|
| A | One-shot copy, diverges forever (current) |
| B | `fw upgrade` syncs seeds (already partially built, T-169) |
| C | Layered: framework base + project overlay (T-316 spike) |

### Q4: How to scope the fix?

| Option | Scope | Effort |
|--------|-------|--------|
| A | Fix hook bug + clean seeds only | 1-2 sessions |
| B | A + onboarding tasks + validation tiers | 3-4 sessions |
| C | B + runtime knowledge reference + fw upgrade sync | 5-8 sessions |

---

## Spike Detail Files

- Spike 1: `/tmp/fw-agent-t455-spike1-init-audit.md` (423 lines)
- Spike 2: `/tmp/fw-agent-t455-spike2-knowledge-taxonomy.md` (283 lines)
- Spike 3: `/tmp/fw-agent-t455-spike3-onboarding-tasks.md` (417 lines)
- Spike 4: `/tmp/fw-agent-t455-spike4-post-init-validation.md` (325 lines)
- Spike 5: (inline — prior decisions search, T-032→T-306→T-294 history)
