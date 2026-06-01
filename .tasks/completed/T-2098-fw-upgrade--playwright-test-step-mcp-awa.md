---
id: T-2098
name: "fw upgrade — playwright test step: MCP-aware fallback (check MCP, offer install
  y/n)"
description: >
  fw test playwright (and upgrade flow) SKIPs silently when tests/playwright/ absent.
  Doesn't probe the Playwright MCP every consumer already has. Goal: probe MCP first;
  if absent, offer y/n install; only SKIP as last resort.

status: work-completed
workflow_type: inception
owner: agent
horizon: null
tags: [fw-upgrade, reliability, inception, T-2078-cluster, playwright, mcp]
components: []
related_tasks: [T-2078, T-2097]
created: 2026-05-29T14:02:48Z
last_update: 2026-05-30T07:38:08Z
date_finished: 2026-05-30T07:38:08Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
bvp_scores_proposed:
  - ts: '2026-05-29T14:15:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 3
      D2: 0
      D3: 4
      D4: 3
    rationale: D1=3 (body:test-or-audit-check); D2=0 (no-signal); D3=4 
      (body:framework-level-ux); D4=3 (body:portability-abstraction)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-05-29T14:15:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 4
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=4 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2098: fw upgrade — playwright test step: MCP-aware fallback (check MCP, offer install y/n)

## Problem Statement

`fw test playwright` (`bin/fw:6267`) emits `SKIP: no tests/playwright/ found in project or framework` when neither location has tests. The pip-package-missing branch (`bin/fw:6262-6266`) is actionable ("Install: pip install playwright pytest-playwright"); the tests-missing branch is dead-silent. Result: consumers with Playwright MCP installed (every consumer in the fleet has it — `.mcp.json` includes `playwright` by default since T-866) **silently skip UI regression testing** because the framework never probes what they DO have.

User intent (verbatim): "we know they all have playwright MCP, and if not should install playwright (check mcp first if not suggests to install y/n)".

Full research artifact: `docs/reports/T-2098-playwright-mcp-aware-fallback.md`

## Assumptions

- All fleet consumers have Playwright MCP installed (since T-866 default). Invalidates to strategy C if many consumers strip it.
- `npx @playwright/mcp@latest --version` is a safe probe (3s timeout). Invalidates to .mcp.json-only probe if npx is slow/blocked.
- Interactive y/n prompt is acceptable in interactive sessions; CI/cron is non-TTY → diagnostic SKIP.

## Exploration Plan

Research complete in `docs/reports/T-2098-playwright-mcp-aware-fallback.md`. Three strategies evaluated (A: probe-then-prompt, B: auto-scaffold, C: diagnostic-only SKIP). Recommendation: A.

## Technical Constraints

- Must work in non-TTY contexts (CI, cron) — falls through to diagnostic SKIP, never prompts.
- Probe must time-bound (3s on npx) — never blocks a test run.
- Scaffold must be idempotent (`tests/playwright/` may already partially exist).
- No external dependencies beyond what the framework already requires (bash + python3 + npx).

## Scope Fence

**In:** MCP probe (.mcp.json + optional npx version-check); y/n prompt in TTY for scaffold or install; minimal `tests/playwright/` scaffold helper; diagnostic SKIP in non-TTY.

**Out:** browser binary management (already in pip-missing branch); MCP server lifecycle; generalising y/n install pattern to all `bin/fw test` SKIP paths.

## Acceptance Criteria

### Agent
<!-- @auto-tick-on-decide -->
- [x] Problem statement validated
<!-- @auto-tick-on-decide -->
- [x] Assumptions tested
<!-- @auto-tick-on-decide -->
- [x] Recommendation written with rationale

### Human
<!-- @auto-tick-on-decide -->
- [x] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Run: `fw task review T-XXX` (opens Watchtower with recommendation, assumptions, research artifacts)
  2. Review the Agent Recommendation section and go/no-go criteria evaluation
  3. Record decision via the Watchtower form or the command shown alongside the QR code
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

<!-- Fill these BEFORE writing the recommendation. The placeholder detector will block review/decide if left empty. -->
**GO if:**
- Root cause identified with bounded fix path
- Fix is scoped, testable, and reversible

**NO-GO if:**
- Problem requires fundamental redesign or unbounded scope
- Fix cost exceeds benefit given current evidence

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# For inception tasks, verification is often not needed (decisions, not code).
#
# Toolchain hint (L-291): if a GO decision will mean editing *.vbproj/*.csproj/*.xaml,
# *.go, Cargo.toml, tsconfig.json, or pom.xml in the build task, plan to add the
# matching build command (dotnet build / go build / cargo check / tsc --noEmit /
# mvn compile) to that build task's ## Verification — P-011 only runs what you write.

## Recommendation

**Recommendation:** GO with **Strategy A — probe-then-prompt** plus explicit non-TTY handling (diagnostic SKIP).

**Rationale:** Matches user intent verbatim ("check mcp first if not suggests to install y/n"). Asks before writing files — respects consumer's project layout. Non-TTY case (CI) falls through to diagnostic SKIP, so automated contexts stay current — only interactive sessions get the upgrade. Probe logic is ~30 lines, self-contained in `bin/fw:6252-6272`.

**Evidence:**
- Every consumer in the fleet has Playwright MCP installed (`.mcp.json` defaults since T-866) — the gap is **MCP-present-but-no-tests**, the most common quadrant.
- pip-missing block (`bin/fw:6262-6266`) already proves the actionable-SKIP pattern with a copy-pasteable install line.
- Inverse case (tests but no MCP) is already correctly handled by the existing path.
- Full research: `docs/reports/T-2098-playwright-mcp-aware-fallback.md`

**Suggested follow-ups (on GO):**
- T-2098-V1: MCP probe helper — parse `.mcp.json` + optional 3s `npx @playwright/mcp@latest --version`.
- T-2098-V2: scaffold helper — `tests/playwright/conftest.py` + `tests/playwright/test_smoke.py` (health-check against project's web URL). Idempotent.
- T-2098-V3: wire probe + scaffold into `bin/fw test playwright`. Non-TTY → diagnostic SKIP; TTY → y/n prompt.
- T-2098-V4: bats coverage — MCP-present-tests-absent fixture confirms scaffold offered; non-TTY fixture confirms diagnostic SKIP.

**Rejected:** B (auto-scaffold without consent — writes files without consent), C (diagnostic SKIP only — preserves the silent-SKIP root failure).
     **Rationale:** Why (cite evidence from exploration)
     **Evidence:**
     - Finding 1
     - Finding 2
-->

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Decision

**Decision**: GO

**Rationale**: Recommendation: GO with Strategy A — probe-then-prompt plus explicit non-TTY handling (diagnostic SKIP).

Rationale: Matches user intent verbatim ("check mcp first if not suggests to install y/n"). Asks before writing files — respects consumer's project layout. Non-TTY case (CI) falls through to diagnostic SKIP, so automated contexts stay current — only interactive sessions get the upgrade. Probe logic is ~30 lines, self-contained in `bin/fw:6252-6272`.

Evidence:
- Every consumer in the fleet has Playwright MCP installed (`.mcp.json` defaults since T-866) — the gap is MCP-present-but-no-tests, the most common quadrant.
- pip-missing block (`bin/fw:6262-6266`) already proves the actionable-SKIP pattern with a copy-pasteable install line.
- Inverse case (tests but no MCP) is already correctly handled by the existing path.
- Full research: `docs/reports/T-2098-playwright-mcp-aware-fallback.md`

Suggested follow-ups (on GO):
- T-2098-V1: MCP probe helper — parse `.mcp.json` + optional 3s `npx @playwright/mcp@latest --version`.
- T-2098-V2: scaffold helper — `tests/playwright/conftest.py` + `tests/playwright/test_smoke.py` (health-check against project's web URL). Idempotent.
- T-2098-V3: wire probe + scaffold into `bin/fw test playwright`. Non-TTY → diagnostic SKIP; TTY → y/n prompt.
- T-2098-V4: bats coverage — MCP-present-tests-absent fixture confirms scaffold offered; non-TTY fixture confirms diagnostic SKIP.

Rejected: B (auto-scaffold without consent — writes files without consent), C (diagnostic SKIP only — preserves the silent-SKIP root failure).
     Rationale: Why (cite evidence from exploration)
     Evidence:
     - Finding 1
     - Finding 2
-->

**Date**: 2026-05-30T07:38:08Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-05-30T07:38:08Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO with Strategy A — probe-then-prompt plus explicit non-TTY handling (diagnostic SKIP).

Rationale: Matches user intent verbatim ("check mcp first if not suggests to install y/n"). Asks before writing files — respects consumer's project layout. Non-TTY case (CI) falls through to diagnostic SKIP, so automated contexts stay current — only interactive sessions get the upgrade. Probe logic is ~30 lines, self-contained in `bin/fw:6252-6272`.

Evidence:
- Every consumer in the fleet has Playwright MCP installed (`.mcp.json` defaults since T-866) — the gap is MCP-present-but-no-tests, the most common quadrant.
- pip-missing block (`bin/fw:6262-6266`) already proves the actionable-SKIP pattern with a copy-pasteable install line.
- Inverse case (tests but no MCP) is already correctly handled by the existing path.
- Full research: `docs/reports/T-2098-playwright-mcp-aware-fallback.md`

Suggested follow-ups (on GO):
- T-2098-V1: MCP probe helper — parse `.mcp.json` + optional 3s `npx @playwright/mcp@latest --version`.
- T-2098-V2: scaffold helper — `tests/playwright/conftest.py` + `tests/playwright/test_smoke.py` (health-check against project's web URL). Idempotent.
- T-2098-V3: wire probe + scaffold into `bin/fw test playwright`. Non-TTY → diagnostic SKIP; TTY → y/n prompt.
- T-2098-V4: bats coverage — MCP-present-tests-absent fixture confirms scaffold offered; non-TTY fixture confirms diagnostic SKIP.

Rejected: B (auto-scaffold without consent — writes files without consent), C (diagnostic SKIP only — preserves the silent-SKIP root failure).
     Rationale: Why (cite evidence from exploration)
     Evidence:
     - Finding 1
     - Finding 2
-->

## Reviewer Verdict (v1.5)

- **Scan ID:** R-cea30c92
- **Timestamp:** 2026-05-30T07:38:08Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-05-30T07:38:08Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
