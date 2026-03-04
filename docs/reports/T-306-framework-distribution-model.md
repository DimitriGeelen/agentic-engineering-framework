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

## Findings

(To be filled after research spikes)

---

## Decision

(Filled at completion via `fw inception decide`)
