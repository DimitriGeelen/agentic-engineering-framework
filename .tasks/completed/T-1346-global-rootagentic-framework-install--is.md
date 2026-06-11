---
id: T-1346
name: "Global /root/.agentic-framework install — isolation leak risk, deprecation
  path"
description: >
  Inception: Global /root/.agentic-framework install — isolation leak risk, deprecation
  path

status: work-completed
workflow_type: inception
owner: human
horizon:
tags: []
components: [bin/fw, tests/playwright/conftest.py]
related_tasks: []
created: 2026-04-20T07:50:36Z
last_update: '2026-06-11T22:23:46Z'
date_finished: 2026-04-26T09:32:26Z
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:46Z'
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

# T-1346: Global /root/.agentic-framework install — isolation leak risk, deprecation path

## Problem Statement

<!-- What problem are we exploring? For whom? Why now? -->

## Assumptions

<!-- Key assumptions to test. Register with: fw assumption add "Statement" --task T-XXX -->

## Exploration Plan

<!-- How will we validate assumptions? Spikes, prototypes, research? Time-box each. -->

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
- [x] Problem statement validated (`docs/reports/T-1346-global-install-isolation.md` §Problem statement)
- [x] Assumptions tested (A1 confirmed via code inspection of `bin/fw:57,77-100`; A2 confirmed via 10+ vendored consumers found)
- [x] Recommendation written with rationale (## Recommendation section: GO Option B++ with B1/B2/B3 decomposition)

### Human
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

## Recommendation

**Recommendation:** GO — Option B++ (harden `resolve_framework` + visible mode signal).

**Rationale:** A1 is confirmed as a silent code-isolation leak. `bin/fw:57` resolves `$0` via `readlink -f`, which follows symlinks. That makes `resolve_framework` rule 1 (fw-inside-framework-repo) match the global `/root/.agentic-framework/` **before** rule 2 (project-vendored) has a chance to run. Every bare `fw` in a consumer project runs the global framework code against consumer state. The user cannot tell — `fw version` does not disclose which copy is active.

**Evidence:**
- Code inspection: `bin/fw:57` (`readlink -f`) + `bin/fw:77-94` (rule 1 matches global after symlink resolution) + `bin/fw:96-100` (rule 2 vendored-check, unreachable in the leak case).
- On this machine alone: 10+ consumer projects with vendored `.agentic-framework/` directories (e.g., `/opt/052-KCP`, `/opt/050-email-archive`, `/opt/termlink`, `/opt/053-ntfy`, `/opt/002-Claude-Partner-Network`, `/opt/051-Vinix24`, `/opt/150-skills-manager`, etc.) all subject to the leak when invoked via bare `fw`.
- User observation: `/root/.agentic-framework` is the symlink target; the installer itself labels it "legacy" but links unconditionally.
- No empirical mode disclosure: `fw version` and `fw doctor` do not print which framework copy resolved.

**Decomposition (see docs/reports/T-1346-global-install-isolation.md):**
- B1 — Flip rule order in `resolve_framework`: project-vendored before fw-inside-framework-repo. Add bats test that asserts vendored wins when invoked via symlink to global.
- B2 — `fw doctor` and `fw version` disclose active mode: `vendored`, `global`, `framework-repo`, with path and version pin.
- B3 — `install.sh` pre-install check: list vendored consumer projects and prompt before re-linking the legacy global shim.

B1 lands first (correctness); B2+B3 are usability. Risk of B1: cron jobs or scripts that rely on the global path may see a vendored-pin mismatch — acceptable trade-off since pin-mismatch is the correct signal.

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

**Rationale**: Recommendation: GO — Option B++ (harden `resolve_framework` + visible mode signal).

Rationale: A1 is confirmed as a silent code-isolation leak. `bin/fw:57` resolves `$0` via `readlink -f`, which follows symlinks. That makes `resolve_framework` rule 1 (fw-inside-framework-repo) match the global `/root/.agentic-framework/` before rule 2 (project-vendored) has a chance to run. Every bare `fw` in a consumer project runs the global framework code against consumer state. The user cannot tell — `fw version` does not disclose which copy is active.

Evidence:
- Code inspection: `bin/fw:57` (`readlink -f`) + `bin/fw:77-94` (rule 1 matches global after symlink resolution) + `bin/fw:96-100` (rule 2 vendored-check, unreachable in the leak case).
- On this machine alone: 10+ consumer projects with vendored `.agentic-framework/` directories (e.g., `/opt/052-KCP`, `/opt/050-email-archive`, `/opt/termlink`, `/opt/053-ntfy`, `/opt/002-Claude-Partner-Network`, `/opt/051-Vinix24`, `/opt/150-skills-manager`, etc.) all subject to the leak when invoked via bare `fw`.
- User observation: `/root/.agentic-framework` is the symlink target; the installer itself labels it "legacy" but links unconditionally.
- No empirical mode disclosure: `fw version` and `fw doctor` do not print which framework copy resolved.

Decomposition (see docs/reports/T-1346-global-install-isolation.md):
- B1 — Flip rule order in `resolve_framework`: project-vendored before fw-inside-framework-repo. Add bats test that asserts vendored wins when invoked via symlink to global.
- B2 — `fw doctor` and `fw version` disclose active mode: `vendored`, `global`, `framework-repo`, with path and version pin.
- B3 — `install.sh` pre-install check: list vendored consumer projects and prompt before re-linking the legacy global shim.

B1 lands first (correctness); B2+B3 are usability. Risk of B1: cron jobs or scripts that rely on the global path may see a vendored-pin mismatch — acceptable trade-off since pin-mismatch is the correct signal.

**Date**: 2026-04-20T09:41:31Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-04-20T07:51:26Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-04-20T09:40:52Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO — Option B++ (harden `resolve_framework` + visible mode signal).

Rationale: A1 is confirmed as a silent code-isolation leak. `bin/fw:57` resolves `$0` via `readlink -f`, which follows symlinks. That makes `resolve_framework` rule 1 (fw-inside-framework-repo) match the global `/root/.agentic-framework/` before rule 2 (project-vendored) has a chance to run. Every bare `fw` in a consumer project runs the global framework code against consumer state. The user cannot tell — `fw version` does not disclose which copy is active.

Evidence:
- Code inspection: `bin/fw:57` (`readlink -f`) + `bin/fw:77-94` (rule 1 matches global after symlink resolution) + `bin/fw:96-100` (rule 2 vendored-check, unreachable in the leak case).
- On this machine alone: 10+ consumer projects with vendored `.agentic-framework/` directories (e.g., `/opt/052-KCP`, `/opt/050-email-archive`, `/opt/termlink`, `/opt/053-ntfy`, `/opt/002-Claude-Partner-Network`, `/opt/051-Vinix24`, `/opt/150-skills-manager`, etc.) all subject to the leak when invoked via bare `fw`.
- User observation: `/root/.agentic-framework` is the symlink target; the installer itself labels it "legacy" but links unconditionally.
- No empirical mode disclosure: `fw version` and `fw doctor` do not print which framework copy resolved.

Decomposition (see docs/reports/T-1346-global-install-isolation.md):
- B1 — Flip rule order in `resolve_framework`: project-vendored before fw-inside-framework-repo. Add bats test that asserts vendored wins when invoked via symlink to global.
- B2 — `fw doctor` and `fw version` disclose active mode: `vendored`, `global`, `framework-repo`, with path and version pin.
- B3 — `install.sh` pre-install check: list vendored consumer projects and prompt before re-linking the legacy global shim.

B1 lands first (correctness); B2+B3 are usability. Risk of B1: cron jobs or scripts that rely on the global path may see a vendored-pin mismatch — acceptable trade-off since pin-mismatch is the correct signal.

### 2026-04-20T09:40:58Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO — Option B++ (harden `resolve_framework` + visible mode signal).

Rationale: A1 is confirmed as a silent code-isolation leak. `bin/fw:57` resolves `$0` via `readlink -f`, which follows symlinks. That makes `resolve_framework` rule 1 (fw-inside-framework-repo) match the global `/root/.agentic-framework/` before rule 2 (project-vendored) has a chance to run. Every bare `fw` in a consumer project runs the global framework code against consumer state. The user cannot tell — `fw version` does not disclose which copy is active.

Evidence:
- Code inspection: `bin/fw:57` (`readlink -f`) + `bin/fw:77-94` (rule 1 matches global after symlink resolution) + `bin/fw:96-100` (rule 2 vendored-check, unreachable in the leak case).
- On this machine alone: 10+ consumer projects with vendored `.agentic-framework/` directories (e.g., `/opt/052-KCP`, `/opt/050-email-archive`, `/opt/termlink`, `/opt/053-ntfy`, `/opt/002-Claude-Partner-Network`, `/opt/051-Vinix24`, `/opt/150-skills-manager`, etc.) all subject to the leak when invoked via bare `fw`.
- User observation: `/root/.agentic-framework` is the symlink target; the installer itself labels it "legacy" but links unconditionally.
- No empirical mode disclosure: `fw version` and `fw doctor` do not print which framework copy resolved.

Decomposition (see docs/reports/T-1346-global-install-isolation.md):
- B1 — Flip rule order in `resolve_framework`: project-vendored before fw-inside-framework-repo. Add bats test that asserts vendored wins when invoked via symlink to global.
- B2 — `fw doctor` and `fw version` disclose active mode: `vendored`, `global`, `framework-repo`, with path and version pin.
- B3 — `install.sh` pre-install check: list vendored consumer projects and prompt before re-linking the legacy global shim.

B1 lands first (correctness); B2+B3 are usability. Risk of B1: cron jobs or scripts that rely on the global path may see a vendored-pin mismatch — acceptable trade-off since pin-mismatch is the correct signal.

### 2026-04-20T09:41:16Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO — Option B++ (harden `resolve_framework` + visible mode signal).

Rationale: A1 is confirmed as a silent code-isolation leak. `bin/fw:57` resolves `$0` via `readlink -f`, which follows symlinks. That makes `resolve_framework` rule 1 (fw-inside-framework-repo) match the global `/root/.agentic-framework/` before rule 2 (project-vendored) has a chance to run. Every bare `fw` in a consumer project runs the global framework code against consumer state. The user cannot tell — `fw version` does not disclose which copy is active.

Evidence:
- Code inspection: `bin/fw:57` (`readlink -f`) + `bin/fw:77-94` (rule 1 matches global after symlink resolution) + `bin/fw:96-100` (rule 2 vendored-check, unreachable in the leak case).
- On this machine alone: 10+ consumer projects with vendored `.agentic-framework/` directories (e.g., `/opt/052-KCP`, `/opt/050-email-archive`, `/opt/termlink`, `/opt/053-ntfy`, `/opt/002-Claude-Partner-Network`, `/opt/051-Vinix24`, `/opt/150-skills-manager`, etc.) all subject to the leak when invoked via bare `fw`.
- User observation: `/root/.agentic-framework` is the symlink target; the installer itself labels it "legacy" but links unconditionally.
- No empirical mode disclosure: `fw version` and `fw doctor` do not print which framework copy resolved.

Decomposition (see docs/reports/T-1346-global-install-isolation.md):
- B1 — Flip rule order in `resolve_framework`: project-vendored before fw-inside-framework-repo. Add bats test that asserts vendored wins when invoked via symlink to global.
- B2 — `fw doctor` and `fw version` disclose active mode: `vendored`, `global`, `framework-repo`, with path and version pin.
- B3 — `install.sh` pre-install check: list vendored consumer projects and prompt before re-linking the legacy global shim.

B1 lands first (correctness); B2+B3 are usability. Risk of B1: cron jobs or scripts that rely on the global path may see a vendored-pin mismatch — acceptable trade-off since pin-mismatch is the correct signal.

### 2026-04-20T09:41:31Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO — Option B++ (harden `resolve_framework` + visible mode signal).

Rationale: A1 is confirmed as a silent code-isolation leak. `bin/fw:57` resolves `$0` via `readlink -f`, which follows symlinks. That makes `resolve_framework` rule 1 (fw-inside-framework-repo) match the global `/root/.agentic-framework/` before rule 2 (project-vendored) has a chance to run. Every bare `fw` in a consumer project runs the global framework code against consumer state. The user cannot tell — `fw version` does not disclose which copy is active.

Evidence:
- Code inspection: `bin/fw:57` (`readlink -f`) + `bin/fw:77-94` (rule 1 matches global after symlink resolution) + `bin/fw:96-100` (rule 2 vendored-check, unreachable in the leak case).
- On this machine alone: 10+ consumer projects with vendored `.agentic-framework/` directories (e.g., `/opt/052-KCP`, `/opt/050-email-archive`, `/opt/termlink`, `/opt/053-ntfy`, `/opt/002-Claude-Partner-Network`, `/opt/051-Vinix24`, `/opt/150-skills-manager`, etc.) all subject to the leak when invoked via bare `fw`.
- User observation: `/root/.agentic-framework` is the symlink target; the installer itself labels it "legacy" but links unconditionally.
- No empirical mode disclosure: `fw version` and `fw doctor` do not print which framework copy resolved.

Decomposition (see docs/reports/T-1346-global-install-isolation.md):
- B1 — Flip rule order in `resolve_framework`: project-vendored before fw-inside-framework-repo. Add bats test that asserts vendored wins when invoked via symlink to global.
- B2 — `fw doctor` and `fw version` disclose active mode: `vendored`, `global`, `framework-repo`, with path and version pin.
- B3 — `install.sh` pre-install check: list vendored consumer projects and prompt before re-linking the legacy global shim.

B1 lands first (correctness); B2+B3 are usability. Risk of B1: cron jobs or scripts that rely on the global path may see a vendored-pin mismatch — acceptable trade-off since pin-mismatch is the correct signal.

## Reviewer Verdict (v1.5)

- **Scan ID:** R-d51cb69d
- **Timestamp:** 2026-06-02T14:56:51Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-04-26T09:32:26Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO recorded 2026-04-20
