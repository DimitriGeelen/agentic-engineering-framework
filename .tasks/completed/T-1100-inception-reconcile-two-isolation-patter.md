---
id: T-1100
name: "Inception: reconcile FIVE isolation patterns (widened from 2 after /opt/termlink
  T-909 evidence) (G-031)"
description: >
  Inception task — pick canonical isolation model from FIVE patterns currently in
  production, or document when to use each, then write migration path. Originally
  scoped as 2 patterns (vendored dir vs shim) on 2026-04-11 morning; widened to 5
  same day after /opt/termlink T-909 transcript revealed `fw vendor` and the symlink
  mode. The five patterns: (1) vendored plain .agentic-framework/ dir, files in project
  git, no .git inside (proxmox-ring20-management); (2) `fw vendor` subcommand — explicit
  copy with size exclusions, ~56MB target; (3) project-detecting shim (ring20-dashboard
  after fw upgrade); (4) manual cp -r — bloated ~349MB, wrong; (5) symlinked .agentic-framework
  — current /opt/termlink state, contaminates host install with consumer state. None
  documented as canonical. Origin: G-031.

status: work-completed
workflow_type: inception
owner: human
horizon: null
components: [web/blueprints/inception.py, web/templates/inception_detail.html]
related_tasks: [T-1093, T-1094, T-1099, T-1101, T-1102, T-1103]
created: 2026-04-11T12:16:16Z
last_update: '2026-06-11T22:23:40Z'
date_finished: 2026-04-12T09:29:42Z
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:40Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-ORCH: 2
      F3: 2
      F1: 2
      F2: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-ORCH=2 (no-signal); F3=2 
      (no-signal); F1=2 (no-signal); F2=2 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1100: Inception: reconcile FIVE isolation patterns (G-031, widened)

## Problem Statement

The Agentic Engineering Framework has FIVE distinct isolation/vendoring patterns in production simultaneously, with no documentation of which is canonical, when to use each, or how to migrate between them:

1. **Vendored plain directory** — `<project>/.agentic-framework/` with framework files committed into the project's own git history, no `.git` inside. Visible in `/root/proxmox-ring20-management`. Created by an earlier `fw init` before shim migration was added; has not been re-upgraded since.
2. **`fw vendor`** — explicit subcommand at `bin/fw:3359` with help text "Copy framework into project for full isolation". Uses size exclusions (~56MB target per /opt/termlink transcript). Not in CLAUDE.md Quick Reference.
3. **Project-detecting shim** — global `~/.local/bin/fw` replaced by `fw upgrade` step 4c with a shim that detects cwd, routes per project, reads `.framework.yaml` for version pin. Visible in `ring20-dashboard` after `fw upgrade` 2026-04-11.
4. **Manual `cp -r`** — bloated (~349MB per /opt/termlink transcript), wrong, no exclusions. The path the user explicitly warned against.
5. **Symlinked `.agentic-framework`** — current `/opt/termlink` state. Contaminates host install with consumer state. T-909 in /opt/termlink is "Fix .agentic-framework symlink — replace with vendored copy" (i.e., migration from pattern 5 → pattern 2).

**For whom:** Every consumer project that wants framework governance. Currently three known consumers (proxmox-ring20-management, ring20-dashboard, /opt/termlink) — three different patterns.

**Why now:** Two same-day incidents (ring20-dashboard onboarding morning, /opt/termlink T-909 afternoon) revealed that BOTH consumer-project agents AND this evaluator session had wrong mental models. Five patterns means roughly 25 possible migration paths, none documented. Risk is now: every new consumer project picks a random pattern from whichever sibling it samples first.

## Assumptions

A-1: The five patterns are not all equivalent — some are deprecated, some are layered (e.g. `fw vendor` produces a result similar to pattern 1 but with a different mechanism), some are wrong (cp -r). Testable by running `fw vendor` and inspecting the output.

A-2: A canonical recommendation exists or can be defined — not all five need to live forever. Testable by reading `fw vendor` source, `lib/upgrade.sh`, and `lib/init.sh` to understand the framework's own intent.

A-3: The portability concern is real — consumers want to pin a framework version per project so framework upgrades on the host don't change consumer behavior. Testable by checking whether `.framework.yaml` already encodes a version pin and whether the shim respects it.

A-4: Migration paths between patterns are non-trivial and need documentation — not just "delete one, run the other". Testable by attempting a migration on a sandbox and recording the steps.

## Exploration Plan

**Phase 1 — Pattern enumeration with mechanism details**
- For each of the five patterns, document: what it produces on disk, what `.framework.yaml` looks like, how `fw` resolves to framework code, what `fw upgrade` does to it, what breaks
- Read `bin/fw` vendor case (line 3359), `lib/upgrade.sh`, `lib/init.sh`
- Inspect each known consumer (proxmox-ring20-management, ring20-dashboard, /opt/termlink) and confirm which pattern they're on

**Phase 2 — Migration matrix**
- 5 patterns = 20 possible non-trivial migrations
- Identify which migrations actually happen in practice (forward only, or two-way?)
- For each likely migration, sketch the steps and identify what breaks

**Phase 3 — Canonical recommendation**
- Pick one (or two complementary) as canonical
- Justify with: simplicity, isolation strength, version-pinning, portability
- Identify which patterns to deprecate and how

**Phase 4 — Recommendation**
- GO Pattern X (and migration plan for the other four) / GO complementary X+Y / NO-GO (no canonical possible) / DEFER

## Technical Constraints

<!-- What platform, browser, network, or hardware constraints apply?
     For web apps: HTTPS requirements, browser API restrictions, CORS, device support.
     For hardware APIs (mic, camera, GPS, Bluetooth): access requirements, permissions model.
     For infrastructure: network topology, firewall rules, latency bounds.
     Fill this BEFORE building. Discovering constraints after implementation wastes sessions. -->

## Scope Fence

<!-- What's IN scope for this exploration? What's explicitly OUT? -->

## Acceptance Criteria

### Agent
- [x] Problem statement validated
- [x] Assumptions tested
- [x] Recommendation written with rationale

### Human
- [x] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Run: `fw task review T-XXX` (opens Watchtower with recommendation, assumptions, research artifacts)
  2. Review the Agent Recommendation section and go/no-go criteria evaluation
  3. Record decision via the Watchtower form or the command shown alongside the QR code
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

**GO if:**
- A single canonical isolation mechanism exists and is already correct (fw vendor / do_vendor)
- All working consumer projects are already on the canonical pattern (no forced migration)
- The shim composes correctly with the vendored dir (additive, not competing)
- Gaps are documentation + guard additions, not architectural rewrites

**NO-GO if:**
- The five patterns require different codepaths for the same use case (they don't)
- Migration would require modifying all consumer projects (it wouldn't — they're already correct)

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# For inception tasks, verification is often not needed (decisions, not code).

## Recommendation

**Recommendation:** GO — Pattern 2 (fw vendor / fw init) as canonical isolation, Pattern 3 (shim) as dispatch

**Rationale:** The five patterns collapse to two correct mechanisms (vendored dir + shim) that are orthogonal and already compose correctly in all working consumer projects. Patterns 1 and 2 are mechanically identical (both call do_vendor()). Pattern 4 (manual cp) is a bloated legacy global install at /root/.agentic-framework (327MB, unused). Pattern 5 (symlink) was fixed in T-909. A sixth undocumented pattern (nested .agentic-framework) was discovered in 3 projects. No rewrite required — documentation + fw doctor checks + one fw init guard cover all gaps.

**Evidence:**
- `lib/init.sh:110` calls `do_vendor --target "$target_dir"` — fw init and fw vendor use identical code
- `bin/fw-shim:find_fw()` requires `.agentic-framework/bin/fw` to exist — shim is dispatch, not isolation
- Disk survey: all 9 working consumer projects in /opt/ use Pattern 2 (56MB vendored dirs)
- `/root/.agentic-framework` = 327MB (Pattern 4 bloat; 6× expected), VERSION=1.4.520 (stale), unused by shim
- `/opt/termlink/.agentic-framework` = real directory post-T-909 (Pattern 5 eliminated)
- 3 projects have nested `.agentic-framework` inside their vendored dir (Pattern 6 — new bug)
- `/opt/025-WokrshopDesigner`: vendored VERSION=1.1.14 but .framework.yaml version=1.5.246 (upgrade gap)
- Full RCA: `docs/reports/T-1100-isolation-patterns-rca.md`

## Structural Upgrade (added 2026-04-11 — chokepoint+test discipline pass per T-1105)

The worker's "Pattern 2 canonical + Pattern 3 orthogonal + init guard for Pattern 6" is half tactical (docs rot) and half structural (init guard). Upgrade by making the canonical state machine-checkable and the wrong patterns impossible to create:

**Chokepoint (single mutation path):**
- All writes to `<project>/.agentic-framework/` go through `do_vendor()`. No other function may create, modify, or merge contents. `fw upgrade` calls `do_vendor()` for the sync; `fw init` calls `do_vendor()` for the create. Manual `cp -r` (Pattern 4), symlink (Pattern 5), and nested vendoring (Pattern 6) become unauthorized states.
- `do_vendor()` becomes atomic-replace (not merge). Existing contents are removed; the new vendor is written cleanly. Eliminates the nested-`.agentic-framework` regression class.

**Type the project state:**
- Add `isolation_mode` field to `.framework.yaml`: `vendored | shim | hybrid`. Written by `do_vendor()` and `fw upgrade`. `fw doctor` validates the declared mode matches actual disk state and refuses to operate on inconsistent state.

**Invariant tests:**
- `tests/lint/isolation-state-consistency.bats` — for every `.framework.yaml` carrying `isolation_mode: vendored`, assert `.agentic-framework/bin/fw` exists, `.agentic-framework/.git` does NOT exist, and `.agentic-framework/.agentic-framework/` does NOT exist (Pattern 6 guard).
- `tests/lint/no-rogue-vendor-paths.bats` — greps `lib/ agents/` for any function other than `do_vendor()` that writes to `.agentic-framework/`. Allowlist: `do_vendor()` itself.

**Migration:**
- Existing consumers in unrecognized state get a one-shot `fw migrate-isolation` that converts to `vendored` mode. Pattern 4 (327MB bloat) detected by size check; Pattern 5 (symlink) by `test -L`; Pattern 6 (nested) by recursive find.

**Why this is more reliable:** the worker's plan documents the canonical pattern but doesn't make the wrong ones impossible. The chokepoint+state+test trio makes "be on a non-canonical pattern" structurally unrepresentable — `fw doctor` will refuse, the test will fail CI, and `do_vendor()` is the only legal mutation.

## Decisions

**Decision**: GO

**Rationale**: Recommendation: GO — Pattern 2 (fw vendor / fw init) as canonical isolation, Pattern 3 (shim) as dispatch

Rationale: The five patterns collapse to two correct mechanisms (vendored dir + shim) that are orthogonal and already compose correctly in all working consumer projects. Patterns 1 and 2 are mechanically identical (both call do_vendor()). Pattern 4 (manual cp) is a bloated legacy global install at /root/.agentic-framework (327MB, unused). Pattern 5 (symlink) was fixed in T-909. A sixth undocumented pattern (nested .agentic-framework) was discovered in 3 projects. No rewrite required — documentation + fw doctor checks + one fw init guard cover all gaps.

Evidence:
- `lib/init.sh:110` calls `do_vendor --target "$target_dir"` — fw init and fw vendor use identical code
- `bin/fw-shim:find_fw()` requires `.agentic-framework/bin/fw` to exist — shim is dispatch, not isolation
- Disk survey: all 9 working consumer projects in /opt/ use Pattern 2 (56MB vendored dirs)
- `/root/.agentic-framework` = 327MB (Pattern 4 bloat; 6× expected), VERSION=1.4.520 (stale), unused by shim
- `/opt/termlink/.agentic-framework` = real directory post-T-909 (Pattern 5 eliminated)
- 3 projects have nested `.agentic-framework` inside their vendored dir (Pattern 6 — new bug)
- `/opt/025-WokrshopDesigner`: vendored VERSION=1.1.14 but .framework.yaml version=1.5.246 (upgrade gap)
- Full RCA: `docs/reports/T-1100-isolation-patterns-rca.md`

**Date**: 2026-04-11T20:07:05Z
## Decision

**Decision**: GO

**Rationale**: Recommendation: GO — Pattern 2 (fw vendor / fw init) as canonical isolation, Pattern 3 (shim) as dispatch

Rationale: The five patterns collapse to two correct mechanisms (vendored dir + shim) that are orthogonal and already compose correctly in all working consumer projects. Patterns 1 and 2 are mechanically identical (both call do_vendor()). Pattern 4 (manual cp) is a bloated legacy global install at /root/.agentic-framework (327MB, unused). Pattern 5 (symlink) was fixed in T-909. A sixth undocumented pattern (nested .agentic-framework) was discovered in 3 projects. No rewrite required — documentation + fw doctor checks + one fw init guard cover all gaps.

Evidence:
- `lib/init.sh:110` calls `do_vendor --target "$target_dir"` — fw init and fw vendor use identical code
- `bin/fw-shim:find_fw()` requires `.agentic-framework/bin/fw` to exist — shim is dispatch, not isolation
- Disk survey: all 9 working consumer projects in /opt/ use Pattern 2 (56MB vendored dirs)
- `/root/.agentic-framework` = 327MB (Pattern 4 bloat; 6× expected), VERSION=1.4.520 (stale), unused by shim
- `/opt/termlink/.agentic-framework` = real directory post-T-909 (Pattern 5 eliminated)
- 3 projects have nested `.agentic-framework` inside their vendored dir (Pattern 6 — new bug)
- `/opt/025-WokrshopDesigner`: vendored VERSION=1.1.14 but .framework.yaml version=1.5.246 (upgrade gap)
- Full RCA: `docs/reports/T-1100-isolation-patterns-rca.md`

**Date**: 2026-04-11T20:07:05Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-04-11T20:06:57Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO — Pattern 2 (fw vendor / fw init) as canonical isolation, Pattern 3 (shim) as dispatch

Rationale: The five patterns collapse to two correct mechanisms (vendored dir + shim) that are orthogonal and already compose correctly in all working consumer projects. Patterns 1 and 2 are mechanically identical (both call do_vendor()). Pattern 4 (manual cp) is a bloated legacy global install at /root/.agentic-framework (327MB, unused). Pattern 5 (symlink) was fixed in T-909. A sixth undocumented pattern (nested .agentic-framework) was discovered in 3 projects. No rewrite required — documentation + fw doctor checks + one fw init guard cover all gaps.

Evidence:
- `lib/init.sh:110` calls `do_vendor --target "$target_dir"` — fw init and fw vendor use identical code
- `bin/fw-shim:find_fw()` requires `.agentic-framework/bin/fw` to exist — shim is dispatch, not isolation
- Disk survey: all 9 working consumer projects in /opt/ use Pattern 2 (56MB vendored dirs)
- `/root/.agentic-framework` = 327MB (Pattern 4 bloat; 6× expected), VERSION=1.4.520 (stale), unused by shim
- `/opt/termlink/.agentic-framework` = real directory post-T-909 (Pattern 5 eliminated)
- 3 projects have nested `.agentic-framework` inside their vendored dir (Pattern 6 — new bug)
- `/opt/025-WokrshopDesigner`: vendored VERSION=1.1.14 but .framework.yaml version=1.5.246 (upgrade gap)
- Full RCA: `docs/reports/T-1100-isolation-patterns-rca.md`

### 2026-04-11T20:07:05Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO — Pattern 2 (fw vendor / fw init) as canonical isolation, Pattern 3 (shim) as dispatch

Rationale: The five patterns collapse to two correct mechanisms (vendored dir + shim) that are orthogonal and already compose correctly in all working consumer projects. Patterns 1 and 2 are mechanically identical (both call do_vendor()). Pattern 4 (manual cp) is a bloated legacy global install at /root/.agentic-framework (327MB, unused). Pattern 5 (symlink) was fixed in T-909. A sixth undocumented pattern (nested .agentic-framework) was discovered in 3 projects. No rewrite required — documentation + fw doctor checks + one fw init guard cover all gaps.

Evidence:
- `lib/init.sh:110` calls `do_vendor --target "$target_dir"` — fw init and fw vendor use identical code
- `bin/fw-shim:find_fw()` requires `.agentic-framework/bin/fw` to exist — shim is dispatch, not isolation
- Disk survey: all 9 working consumer projects in /opt/ use Pattern 2 (56MB vendored dirs)
- `/root/.agentic-framework` = 327MB (Pattern 4 bloat; 6× expected), VERSION=1.4.520 (stale), unused by shim
- `/opt/termlink/.agentic-framework` = real directory post-T-909 (Pattern 5 eliminated)
- 3 projects have nested `.agentic-framework` inside their vendored dir (Pattern 6 — new bug)
- `/opt/025-WokrshopDesigner`: vendored VERSION=1.1.14 but .framework.yaml version=1.5.246 (upgrade gap)
- Full RCA: `docs/reports/T-1100-isolation-patterns-rca.md`

### 2026-04-12T09:29:04Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-04-12T09:29:42Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

### 2026-04-12T09:41:08Z — status-update [task-update-agent]
- **Change:** horizon: now → next

## Reviewer Verdict (v1.5)

- **Scan ID:** R-2f2c2a95
- **Timestamp:** 2026-06-02T14:55:10Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
