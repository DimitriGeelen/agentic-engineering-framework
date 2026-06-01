---
id: T-1268
name: "Cross-machine update propagation friction — global install boundary + binary cargo dep"
description: >
  Inception: structural fix for agent-driven update propagation across boundaries we cannot cross (global install gate, TermLink binary toolchain)

status: work-completed
workflow_type: inception
owner: agent
horizon: null
tags: []
components: [bin/fw, lib/pending.sh, web/blueprints/__init__.py, web/blueprints/pending.py, web/shared.py, web/templates/pending.html]
related_tasks: []
created: 2026-04-15T21:03:24Z
last_update: 2026-04-23T15:15:49Z
date_finished: 2026-04-23T15:15:49Z
---

# T-1268: Cross-machine update propagation friction — global install boundary + binary cargo dep

**Research artifact:** [docs/reports/T-1268-cross-machine-update-friction.md](../../docs/reports/T-1268-cross-machine-update-friction.md) — full spike findings, dialogue log, recommendation.

## Problem Statement

Agents cannot self-heal update drift on artefacts that sit outside their current project boundary. Two concrete recurrences in session 2026-04-15:

1. **Global `/root/.agentic-framework` install** — an agent in `/opt/999-...` could not run `fw update` against the global install because the project-boundary gate blocked the cross-repo edit. The agent had to hand a copy-pasteable `cd /root && /root/.agentic-framework/bin/fw update` back to the human.
2. **TermLink binary** — updating TermLink required `cargo` on the target host. The host lacked cargo, so the agent could only pull source (0.9.400 → 0.9.872), not rebuild the binary. The workaround was "build elsewhere, scp in."

Both leave the environment in a known-stale state with no structural mechanism to close the loop. The boundary gate is correct; the question is what affordance replaces the blocked action so drift actually gets fixed instead of handed off indefinitely.

## Assumptions

- A1: Boundary gate must stay strict — weakening it to allow cross-repo update commands creates worse incidents than the drift it would fix
- A2: Humans consistently run copy-pasteable update commands when presented (≥80% completion within 24h)
- A3: TermLink binary distribution can be solved with prebuilt artefacts (GitHub Releases / cargo install-from-url / Homebrew bottle) without requiring cargo on every target
- A4: The friction from both cases compounds — drift in global install degrades hook behavior; stale TermLink loses cross-session features
- A5: Both issues are symptomatic of a broader class: "agent can diagnose drift but cannot fix it in place"

## Exploration Plan

- Spike A: Measure completion rate of copy-pasteable commands across last 30 days (handover logs, bypass log, doctor diff-over-time)
- Spike B: Enumerate all boundary-blocked actions surfaced in fw doctor / fw audit — is this a 2-instance problem or 20-instance?
- Spike C: Evaluate TermLink binary distribution options — cargo install --git, Homebrew bottle, GitHub Releases prebuild matrix
- Spike D: Design a "pending updates" registry — when agent detects drift it cannot fix, append to a machine-readable inbox that surfaces in subsequent `fw doctor` and in Watchtower with one-click copy
- Spike E: Evaluate a cross-machine dispatch pattern where an agent on host A triggers an update on host B via TermLink remote exec (rather than scp)

## Technical Constraints

- Project-boundary gate at `agents/context/check-project-boundary.sh` must keep blocking unauthorized cross-repo writes
- TermLink binary install currently assumes `cargo` on target; Homebrew path exists on macOS only
- Global install at `/root/.agentic-framework` is opt-in legacy; the shim-based dispatch pattern is the successor (doctor already warns to `rm -rf` it)
- No SSO for `/etc/cron.d` writes — cron updates need root, so some friction is load-bearing
- Cross-machine dispatch requires termlink running on both sides

## Scope Fence

**IN:**
- RCA of the two recurrences with timestamps and root-cause chain
- Option space for "drift I can't fix" (better command affordance, pending-updates inbox, binary distribution channels, cross-machine dispatch)
- Recommendation with bounded build decomposition if GO

**OUT:**
- Actual build of any option (post-GO tasks)
- Modifying the boundary gate itself (A1 — that's a separate inception if ever needed)
- Solving /root/.agentic-framework specifically (user can `rm -rf` per doctor recommendation — the interesting problem is the general case)

## Acceptance Criteria

### Agent
- [x] Problem statement validated
- [x] Assumptions tested
- [x] Recommendation written with rationale
- [x] B1-B4 (pending-updates registry) shipped: T-1397 (CLI), T-1398 (fw doctor), T-1399 (remind+ntfy), T-1400 (Watchtower `/pending`), T-1401 (nav link)
- [x] B5 (TermLink prebuild matrix) verified shipped upstream: `/opt/termlink/.github/workflows/release.yml` — 5-target matrix, sha256 checksums, gh-release integration (tag v0.9.1)
- [x] B6 (TermLink curl-bash installer) verified shipped upstream: `/opt/termlink/install.sh` — detects host target, downloads binary, verifies sha256

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

bin/fw pending --help >/dev/null
test -f /opt/termlink/.github/workflows/release.yml
test -f /opt/termlink/install.sh
grep -q "tags:" /opt/termlink/.github/workflows/release.yml
grep -q "softprops/action-gh-release" /opt/termlink/.github/workflows/release.yml

## Recommendation

**Recommendation:** GO (partial scope) — build C1+C4 (TermLink prebuild matrix + curl installer) and D (pending-updates registry). Defer E (cross-machine dispatch) to a follow-up inception once residual friction is measured.

**Rationale:** The two T-1268 recurrences are symptomatic of the broader class A5 ("agent can diagnose drift but cannot fix in place"), but the right structural answer differs by class. For boundary-blocked updates, the answer is *not* to weaken the gate (A1 holds) — it's to give the agent a write-able registry that surfaces the intent to the human / target session. For toolchain-missing binary updates, the answer is to remove the toolchain dependency, not to ship cargo to every host. C1+C4 and D are scoped, testable, reversible, and address measurable friction.

**Evidence:**
- Boundary gate is centralized (one file, one allowlist) — a single registry primitive serves all 4 observed blocked-action classes (Spike B in research artifact).
- Pending-updates registry is the missing telemetry: Spike A could not measure copy-paste completion rate because there's no instrumentation today (0 explicit "copy-pasteable" markers in 30 handovers + bypass log).
- TermLink binary supports `cargo install --git`; adding GitHub Releases prebuilds is mechanical (Spike C: C1+C4 chosen over Homebrew/OCI on cost+reach).
- Half-session cost for D; ~1-day for C1+C4 release matrix.
- Reversible: pending-updates entries are append-only; release matrix doesn't remove cargo install.

**Build decomposition (after GO):**
- B1: `.context/working/pending-updates.yaml` schema + `fw pending {register,list,resolve}` CLI
- B2: `fw doctor` integration (surface unresolved entries)
- B3: Watchtower `/pending` page with one-click copy
- B4: Optional `fw pending remind` cron (24h ping for stale entries)
- B5: TermLink GitHub Releases matrix (`/opt/termlink/.github/workflows/release.yml`)
- B6: TermLink `install.sh` curl-bash installer

Each <1 session. B1+B2 close case 1 (boundary-blocked). B5+B6 close case 2 (toolchain-missing). B3+B4 are QoL.

**Reversibility:** Every B-unit is additive. No existing surface is removed. Can ship B1+B2+B5 first and stop if B3/B4/B6 prove unnecessary.

**Alternative (NO-GO):** Status quo — agent hands copy-pasteable commands; human follows through ad-hoc. Costs nothing to build but 24+ months of accumulated drift across consumer projects suggests the loop doesn't reliably close.

See `docs/reports/T-1268-cross-machine-update-friction.md` for full spike findings (A-E), trade-off matrix, and design sketches.
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

**Rationale**: Recommendation: GO (partial scope) — build C1+C4 (TermLink prebuild matrix + curl installer) and D (pending-updates registry). Defer E (cross-machine dispatch) to a follow-up inception once residual friction is measured.

Rationale: The two T-1268 recurrences are symptomatic of the broader class A5 ("agent can diagnose drift but cannot fix in place"), but the right structural answer differs by class. For boundary-blocked updates, the answer is not to weaken the gate (A1 holds) — it's to give the agent a write-able registry that surfaces the intent to the human / target session. For toolchain-missing binary updates, the answer is to remove the toolchain dependency, not to ship cargo to every host. C1+C4 and D are scoped, testable, reversible, and address measurable friction.

Evidence:
- Boundary gate is centralized (one file, one allowlist) — a single registry primitive serves all 4 observed blocked-action classes (Spike B in research artifact).
- Pending-updates registry is the missing telemetry: Spike A could not measure copy-paste completion rate because there's no instrumentation today (0 explicit "copy-pasteable" markers in 30 handovers + bypass log).
- TermLink binary supports `cargo install --git`; adding GitHub Releases prebuilds is mechanical (Spike C: C1+C4 chosen over Homebrew/OCI on cost+reach).
- Half-session cost for D; ~1-day for C1+C4 release matrix.
- Reversible: pending-updates entries are append-only; release matrix doesn't remove cargo install.

Build decomposition (after GO):
- B1: `.context/working/pending-updates.yaml` schema + `fw pending {register,list,resolve}` CLI
- B2: `fw doctor` integration (surface unresolved entries)
- B3: Watchtower `/pending` page with one-click copy
- B4: Optional `fw pending remind` cron (24h ping for stale entries)
- B5: TermLink GitHub Releases matrix (`/opt/termlink/.github/workflows/release.yml`)
- B6: TermLink `install.sh` curl-bash installer

Each <1 session. B1+B2 close case 1 (boundary-blocked). B5+B6 close case 2 (toolchain-missing). B3+B4 are QoL.

Reversibility: Every B-unit is additive. No existing surface is removed. Can ship B1+B2+B5 first and stop if B3/B4/B6 prove unnecessary.

Alternative (NO-GO): Status quo — agent hands copy-pasteable commands; human follows through ad-hoc. Costs nothing to build but 24+ months of accumulated drift across consumer projects suggests the loop doesn't reliably close.

See `docs/reports/T-1268-cross-machine-update-friction.md` for full spike findings (A-E), trade-off matrix, and design sketches.
-->

**Date**: 2026-04-23T12:09:55Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-04-23T10:56:47Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-04-23T12:09:55Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO (partial scope) — build C1+C4 (TermLink prebuild matrix + curl installer) and D (pending-updates registry). Defer E (cross-machine dispatch) to a follow-up inception once residual friction is measured.

Rationale: The two T-1268 recurrences are symptomatic of the broader class A5 ("agent can diagnose drift but cannot fix in place"), but the right structural answer differs by class. For boundary-blocked updates, the answer is not to weaken the gate (A1 holds) — it's to give the agent a write-able registry that surfaces the intent to the human / target session. For toolchain-missing binary updates, the answer is to remove the toolchain dependency, not to ship cargo to every host. C1+C4 and D are scoped, testable, reversible, and address measurable friction.

Evidence:
- Boundary gate is centralized (one file, one allowlist) — a single registry primitive serves all 4 observed blocked-action classes (Spike B in research artifact).
- Pending-updates registry is the missing telemetry: Spike A could not measure copy-paste completion rate because there's no instrumentation today (0 explicit "copy-pasteable" markers in 30 handovers + bypass log).
- TermLink binary supports `cargo install --git`; adding GitHub Releases prebuilds is mechanical (Spike C: C1+C4 chosen over Homebrew/OCI on cost+reach).
- Half-session cost for D; ~1-day for C1+C4 release matrix.
- Reversible: pending-updates entries are append-only; release matrix doesn't remove cargo install.

Build decomposition (after GO):
- B1: `.context/working/pending-updates.yaml` schema + `fw pending {register,list,resolve}` CLI
- B2: `fw doctor` integration (surface unresolved entries)
- B3: Watchtower `/pending` page with one-click copy
- B4: Optional `fw pending remind` cron (24h ping for stale entries)
- B5: TermLink GitHub Releases matrix (`/opt/termlink/.github/workflows/release.yml`)
- B6: TermLink `install.sh` curl-bash installer

Each <1 session. B1+B2 close case 1 (boundary-blocked). B5+B6 close case 2 (toolchain-missing). B3+B4 are QoL.

Reversibility: Every B-unit is additive. No existing surface is removed. Can ship B1+B2+B5 first and stop if B3/B4/B6 prove unnecessary.

Alternative (NO-GO): Status quo — agent hands copy-pasteable commands; human follows through ad-hoc. Costs nothing to build but 24+ months of accumulated drift across consumer projects suggests the loop doesn't reliably close.

See `docs/reports/T-1268-cross-machine-update-friction.md` for full spike findings (A-E), trade-off matrix, and design sketches.
-->

### 2026-04-23T15:15:49Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
