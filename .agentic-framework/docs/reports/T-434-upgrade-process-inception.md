# T-434: Framework Update/Upgrade Process — Inception Report

**Status:** Complete
**Created:** 2026-03-14
**Task:** T-434 (inception)

## Problem Statement

There is no process to update or upgrade an existing installation of the Agentic Engineering Framework. Users with existing installations have no path to adopt improvements. This is a fundamental gap in the framework's portability story (D4).

## Key Discovery: Infrastructure Already Exists

Before exploring, we found that two of the three upgrade paths already have implementations:

| Path | Exists? | Implementation | Status |
|------|---------|---------------|--------|
| **Framework self-update** | Yes | `install.sh` re-run → `git fetch + reset --hard` | Working (T-481 fixed dirty state) |
| **Consumer project sync** | Yes | `fw upgrade` → 6-step sync (CLAUDE.md, templates, seeds, hooks, settings, commands) | Working, has `--dry-run` |
| **Schema migration** | No | Nothing | Gap |

The real gaps are narrower than the task description suggested:
1. No version tracking between framework releases and consumer projects
2. No migration tooling for breaking schema changes
3. No rollback mechanism if `fw upgrade` breaks something
4. `fw upgrade` doesn't cover all upgradeable artifacts (missing: new agents, new context dirs, VERSION tracking)
5. No `fw update` CLI command (must re-run `install.sh` manually)

---

## Spike 1: File Classification Matrix

| Path | Category | Upgrade Risk | Notes |
|------|----------|-------------|-------|
| `bin/fw`, `bin/claude-fw`, `bin/watchtower.sh` | Framework | Low | CLI entry points. Updated by `install.sh` re-run. Users never edit. |
| `lib/` (all `.sh` files + `seeds/` + `templates/`) | Framework | Low | Core library. `seeds/` are default templates copied at `fw init`. |
| `agents/` (all) | Framework | Low | Agent scripts + AGENT.md. Invoked via `fw`, never edited by users. |
| `web/` (all) | Framework | Low | Watchtower web UI. Deployed but not customized. |
| `tests/` | Framework | Low | Test suite. Framework CI validation. |
| `docs/` | Framework | Low | Documentation and reports. |
| `metrics.sh`, `VERSION`, `LICENSE`, `NOTICE` | Framework | Low | Utilities and metadata. |
| `README.md`, `FRAMEWORK.md`, `CONTRIBUTING.md`, `AGENTS.md` | Framework | Low | Documentation. |
| `install.sh` | Framework | Low | Self-contained installer. Lives in repo. |
| `Dockerfile`, `.dockerignore`, `deploy/` | Framework | Low | Deployment artifacts. |
| `.context/` (all subdirs) | **Project** | **HIGH** | All project memory. NEVER touched by upgrade. |
| `.tasks/` (active, completed) | **Project** | **HIGH** | Task history. NEVER touched by upgrade. |
| `.fabric/` (component cards) | **Project** | Medium | Component topology. Project-populated. |
| `.framework.yaml` | **Project** | Medium | Project config. Created at `fw init`, not synced. |
| `CLAUDE.md` | **Hybrid** | Medium | `fw upgrade` already handles: preserves project header, refreshes governance sections. |
| `.claude/settings.json` | **Hybrid** | Medium | `fw upgrade` already handles: regenerates if hooks < expected count. |
| `.claude/commands/` | **Hybrid** | Medium | `fw upgrade` preserves existing, skips creation. |
| `.tasks/templates/` | **Hybrid** | Low | `fw upgrade` already syncs from `lib/seeds/tasks/`. |

**Key insight:** The framework/project boundary is clean. Only 3 hybrid files need merge logic, and `fw upgrade` already handles all three.

---

## Spike 2: Blast Radius Analysis

| Component | Depended By | Breaking Change Risk | Current Mitigation |
|-----------|-------------|---------------------|-------------------|
| `bin/fw` | 42 subcommands, all users | HIGH — new subcommands OK, renamed/removed break | Case statement is additive |
| `agents/task-create/` | P-010 gate, all task ops | HIGH — AC format change breaks completion | Format stable since T-193 |
| `agents/git/git.sh` | P-002 gate, all commits | HIGH — commit-msg format change blocks git | Format stable (`T-XXX:`) |
| `.claude/settings.json` | All Write/Edit/Bash ops | CRITICAL — malformed JSON silently disables hooks | `fw upgrade` regenerates |
| `agents/context/context.sh` | All memory ops | HIGH — schema change affects episodic | Schema stable |
| `web/app.py` | Dashboard users | MEDIUM — route changes break bookmarks | Routes are additive |
| `install.sh` | New users, re-installers | CRITICAL — first impression | Tested on Ubuntu/macOS |
| `lib/init.sh` | `fw init`, `fw upgrade` | HIGH — init structure change affects all | Additive (creates missing dirs) |
| `CLAUDE.md` template | All Claude Code sessions | MEDIUM — governance section format | `fw upgrade` already merges |
| `metrics.sh` | `fw metrics`, dashboard | LOW — reporting only | JSON output stable |

**Safe upgrade order:** Low-risk additive changes (new commands, new agents, new routes) → medium-risk structural changes (templates, seeds) → high-risk schema changes (context YAML formats).

---

## Spike 3: Prior Art Summary

Researched 9 frameworks: Oh My Zsh, Homebrew, Doom Emacs, nvm/rbenv/pyenv, rustup, ESLint, chezmoi, Kustomize, Ansible.

**Top 3 applicable patterns:**

1. **Protected User Directory** (OMZ model) — gitignored `custom/` dir. User content physically separated from framework. Already implemented: `.context/`, `.tasks/`, `.fabric/` are project-owned.

2. **Base + Overlay YAML** (Kustomize/Ansible model) — framework ships `defaults.yaml`, user creates `local.yaml`. Runtime merge with user precedence. Applicable to future config system, not urgently needed now.

3. **Git pull + SHA tracking + post-update reconciliation** (OMZ + Doom model) — stash, pull, restore, doctor. Already implemented in `install.sh` (fetch + reset) and `fw upgrade` (6-step sync + `fw doctor` recommendation).

**Universal finding:** Every successful framework separates framework-owned files from user-owned files physically. Our framework already does this.

---

## Spike 4: Upgrade Strategy Options

### Current State (Already Working)

| Capability | How | Missing |
|-----------|-----|---------|
| Update framework installation | Re-run `install.sh` or `git pull` in `~/.agentic-framework/` | No `fw update` command |
| Sync improvements to consumer project | `fw upgrade [--dry-run]` | Missing: new agents, new context dirs, VERSION tracking |
| Rollback framework | `git checkout <old-sha>` in install dir | No `fw rollback` command |
| Rollback consumer project | `git checkout` (if committed before upgrade) | No automatic backup |

### Strategy Options

**Option A: Polish Existing (Recommended)**
- Add `fw update` command that wraps `install.sh` logic (fetch + reset in install dir)
- Expand `fw upgrade` to cover missing artifacts (new agents, new context dirs)
- Add VERSION file tracking to `.framework.yaml` on upgrade
- Add `--backup` flag to `fw upgrade` that creates a git stash before changes
- Directive scores: Antifragility 8, Reliability 9, Usability 8, Portability 9

**Option B: Full Migration System**
- Everything in Option A, plus:
- Version manifest with migration scripts per version pair
- `fw migrate` command for breaking schema changes
- Automated rollback on failure
- Directive scores: Antifragility 9, Reliability 9, Usability 7 (complexity), Portability 8

**Option C: Defer (Do Nothing)**
- Document manual upgrade steps in README
- Directive scores: Antifragility 3, Reliability 3, Usability 2, Portability 5

### Recommendation: Option A

Option B is overengineered for current state — we have had zero breaking schema changes since inception. The framework's YAML schemas are additive (new fields with defaults). Option A gives us a working upgrade path with minimal complexity. If breaking changes arise later, we add migration scripts incrementally.

---

## Spike 5: Migration Path Design

**Current situation:** No breaking schema changes have occurred. All changes have been additive:
- New YAML fields added with defaults (e.g., `horizon` field on tasks — defaults to `now`)
- New context subdirs added (e.g., `.context/bus/`) — `fw init` creates if missing
- New hooks added — `fw upgrade` detects missing hooks by count

**Proposed migration approach (for when breaking changes eventually happen):**

1. **VERSION file** in framework root (already exists) — tracks framework version
2. **`.framework.yaml` version field** — tracks version the project was last synced to
3. **Migration scripts** in `lib/migrations/` — named `v0.9-to-v1.0.sh`, run by `fw upgrade` if version gap detected
4. **Migration scripts are idempotent** — safe to re-run, check before modifying

**Not needed now.** Build when first breaking change arrives. The infrastructure (`fw upgrade` already runs in sequence) supports adding migration steps.

---

## Spike 6: Safety Mechanisms

| Mechanism | Status | Implementation |
|-----------|--------|---------------|
| **Dry-run** | EXISTS | `fw upgrade --dry-run` shows what would change |
| **Backup before upgrade** | PARTIAL | `fw upgrade` creates `.bak` files for CLAUDE.md and settings.json |
| **Pre-upgrade validation** | EXISTS | `fw doctor` runs post-upgrade, verifiable |
| **Rollback (framework)** | MANUAL | `git checkout <sha>` in install dir. Could add `fw update --rollback` |
| **Rollback (consumer)** | MANUAL | `git stash pop` or `git checkout` if committed. Could add `--backup` flag |
| **Version tracking** | MISSING | Need to record framework version in `.framework.yaml` on upgrade |
| **Post-upgrade health check** | EXISTS | `fw doctor` recommended in upgrade output |

**Gap:** Only version tracking is truly missing. Dry-run, backup, and validation already exist.

---

## Spike 7: Test Plan

**Test with `fw self-test`:**
Add an upgrade phase to the existing E2E test (T-491/T-492):
1. `fw init` a temp project at version N
2. Simulate framework update (modify a seed file, add a template)
3. Run `fw upgrade --dry-run` → verify changes detected
4. Run `fw upgrade` → verify changes applied
5. Run `fw doctor` → verify health

**Test matrix:**

| Scenario | Method |
|----------|--------|
| Clean install → upgrade | `fw init` + `fw upgrade` (no-op expected) |
| Old templates → upgrade | Modify a template, run `fw upgrade` |
| Customized CLAUDE.md → upgrade | Add project sections, run `fw upgrade`, verify preserved |
| Custom hooks in settings.json → upgrade | Add custom hook, run `fw upgrade`, verify preserved |
| Missing context dirs → upgrade | Delete `.context/bus/`, run `fw upgrade`, verify recreated |

---

## Spike 8: Decomposition

Given Option A (polish existing), the work decomposes into 3 tasks:

### Task 1: `fw update` command (framework self-update)
- Add `update` subcommand to `bin/fw` that wraps `install.sh` logic
- Show before/after version, changelog summary
- `fw update --check` to check without applying
- **Depends on:** Nothing
- **Estimate:** Small (1-2 hours)

### Task 2: Expand `fw upgrade` coverage
- Add VERSION tracking in `.framework.yaml` on upgrade
- Sync new context subdirs (create if missing)
- Sync new agents (copy agent dirs that don't exist in project — wait, agents live in framework install, not project)
- Actually: agents are in framework install dir, not copied to projects. So this is already handled by `fw update`.
- Real gap: sync new `.context/` subdirs and update version field
- **Depends on:** Nothing
- **Estimate:** Small (1-2 hours)

### Task 3: E2E upgrade test
- Add upgrade phase to `fw self-test`
- Test `fw upgrade --dry-run` and `fw upgrade` on temp project
- **Depends on:** Tasks 1 and 2
- **Estimate:** Small (1-2 hours)

---

## Go/No-Go Assessment

| Criterion | Result |
|-----------|--------|
| File classification reveals clean boundary | **YES** — framework/project separation is physical, not conventional |
| At least one strategy scores well on all directives | **YES** — Option A scores 8-9 across all four |
| Safety mechanisms (dry-run, rollback) are feasible | **YES** — dry-run already exists, rollback is git-native |
| Work can be phased into ≤5 build tasks | **YES** — 3 small tasks, no dependencies except task 3 on 1+2 |

### Additional Go Signal

The biggest surprise: **most of the upgrade infrastructure already works.** `install.sh` handles framework self-update. `fw upgrade` handles consumer project sync with dry-run, backup, and 6-step coverage. The gaps are small:
- Missing `fw update` CLI command (wraps existing `install.sh` logic)
- Missing version tracking in `.framework.yaml`
- Missing new context dir sync in `fw upgrade`
- Missing E2E test coverage

## Decision

**Recommendation: GO** — Option A (polish existing). The work is small (3 tasks, ~4-6 hours total), the infrastructure exists, and the gaps are well-defined. Risk is low because we're extending working code, not building from scratch.
