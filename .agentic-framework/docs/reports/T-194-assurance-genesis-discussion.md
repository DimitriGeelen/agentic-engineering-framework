# T-194: Assurance Model — Genesis Discussion

**Date:** 2026-02-19
**Participants:** Human + Claude (dialogue)
**Phase:** 0 (Pre-inception discovery)
**Origin:** Deep review of T-151 and T-184

## How This Started

Human requested reopening T-151 ("Investigate audit tasks as cronjobs") and T-184 ("Implement cron-based audit scheduling") for deep review. Key concern: **"what troubles me is I was not consulted at any point."**

## T-151 Timeline Analysis

| Timestamp | Event |
|-----------|-------|
| 2026-02-18 12:05 | Task created, immediately started-work |
| 2026-02-18 13:37 | Parked (horizon: next, status: captured) |
| 2026-02-18 23:22 | Promoted back to now |
| 2026-02-19 00:27 | Started-work again |
| 2026-02-19 00:29 | **Work-completed — 2 minutes later** |

A specification task (`workflow_type: specification`, `owner: human`) went from started to completed in 2 minutes with zero human consultation. The agent wrote the investigation findings, made the GO recommendation, chose cron vs systemd vs APScheduler, set frequencies, and decided which checks to include — all unilaterally.

**This is a governance failure:** The authority model says agents have INITIATIVE, not DECISION power. Specification tasks with `owner: human` exist precisely because the human needs to validate the spec.

## What Was Built (T-184) vs Original Intent

### Human's original intent (from T-151 description):
> "regularly check task quality or commit quality, other quality criteria standards that we have set if they are adhered to and then report out when they have findings"

**Key phrase: "report out when they have findings"** — the intent was discovery and alerting, not rote repetition.

### What was actually built:
The existing `fw audit` (same 11 sections, same checks) running on a cron schedule. No new discovery capability. No alerting. Reports pile up in `.context/audits/cron/` — 17 reports generated on 2026-02-19 alone.

### The gap:
- **Intent:** Active quality guardian that discovers problems, omissions, and emerging patterns (antifragility)
- **Reality:** Same audit on a timer, producing identical results every 30 minutes

## Three-Layer Model (Evolved Through Dialogue)

Initial framing had three layers:

| Layer | Role | Example |
|-------|------|---------|
| **Hooks** (real-time) | Prevent violations as they happen | Block Write without active task |
| **Cron audits** (periodic) | Verify hooks' effects are actually holding | Is traceability still 98%? |
| **Cron discovery** (periodic) | Find things no single check can see | Patterns, omissions, drift |

### Critical correction (human insight):
Agent initially dismissed Layer 2 as "adds almost nothing over hooks." Human pushed back:

> "not completely sure there because we have also observed that hooks fail or do not function as designed/intended, or suddenly stop working... correct?"

**Evidence of hook failures in AEF history:**
- Hooks snapshot at session start — editing a hook mid-session has zero effect
- Flat hooks format `{ "matcher": "*", "command": "..." }` silently fails (no error)
- `((x++))` with `set -e` broke `budget-gate.sh` silently when counter was 0
- `--no-verify` bypasses git hooks entirely (used for inception tasks)

**Corrected understanding:** Layer 2 is **defense in depth** — it catches reality drift when hooks themselves malfunction. Not redundant; essential for antifragility.

## ISO 27001 Mapping (Human Contribution)

Human introduced ISO 27001's four-level assurance model as the proper framework:

### ISO 27001 Four Levels (from human's reference):

1. **Risk (Assessment & Treatment)** — Foundation. Identify risks through likelihood × impact. Document in Risk Register. Link to controls.

2. **Control Design (Adequacy)** — Select controls to address risks. Assess: "If this control works as intended, would it sufficiently mitigate the risk?" (= design effectiveness)

3. **Operational Effectiveness (OE)** — "Is the control actually working in practice, consistently, over time?" Tested through evidence: logs, records, observations. Proves controls aren't just on paper.

4. **Audit (Internal & External)** — Independent verification of all three levels above.

**The cascade:** Risk → drives → Control Design → verified by → OE → assured by → Audit

### Mapped to AEF:

| Level | AEF Equivalent | Status |
|-------|---------------|--------|
| Risk | `gaps.yaml` (partial) | Informal — no likelihood × impact, no treatment options |
| Control Design | Hooks, gates, CLAUDE.md rules | Exists but not documented as controls |
| OE | Cron audits (supposed to be) | Weak — reruns structural checks, not control-specific tests |
| Audit | `fw audit` | Mixed — combines structural + some OE, no separation |

## Current Control Inventory

11 controls identified during review:

| Control | Type | Risk it mitigates | Design doc | OE test |
|---------|------|-------------------|-----------|---------|
| `check-active-task.sh` | PreToolUse hook | Work without task governance | CLAUDE.md | Indirect (compliance cron) |
| `check-tier0.sh` | PreToolUse hook | Destructive actions without approval | CLAUDE.md | **None** |
| `budget-gate.sh` | PreToolUse hook | Context exhaustion, lost work | CLAUDE.md | **None** |
| `checkpoint.sh` | PostToolUse hook | Missed auto-handover at critical | CLAUDE.md | **None** |
| `error-watchdog.sh` | PostToolUse hook | Silent errors | CLAUDE.md | **None** |
| `commit-msg` hook | Git hook | Commits without task refs | CLAUDE.md | Indirect (traceability cron) |
| `post-commit` hook | Git hook | Unlogged bypasses | CLAUDE.md | **None** |
| P-010 AC gate | Script gate | Incomplete work marked done | CLAUDE.md | **None** |
| P-011 Verification gate | Script gate | Unverified work marked done | CLAUDE.md | **None** |
| Inception gate | Git hook | Building before GO decision | CLAUDE.md | **None** |
| CLAUDE.md behavioral rules | Instruction | Agent overreach, skipped process | Self-referential | **None** |

**Result: 2 of 11 controls have indirect OE testing. 9 have none.**

## What Proper OE Testing Would Look Like

Examples discussed for specific controls:

| Control | OE Test | What it proves |
|---------|---------|---------------|
| `check-active-task.sh` | No source file writes exist without a preceding `fw context focus` in the same session | Control is actually blocking |
| `commit-msg` hook | 0 commits without T-XXX prefix (excluding logged `--no-verify` bypasses) | Hook is installed and executing |
| `budget-gate.sh` | No Write/Edit to source files after budget crossed 150K in any session log | Gate actually fires at threshold |
| P-010 AC gate | No tasks in `completed/` with unchecked ACs (unless `--force` logged) | Gate is enforcing |
| Inception gate | No non-inception commits after 2 exploration commits on inception tasks | Gate is counting correctly |

## What "Discovery" Could Mean (Not Built)

### Omission detection:

| Discovery | Example |
|-----------|---------|
| Tasks stuck too long | T-190 "started-work" for 10h with 0 updates |
| Decisions made without dialogue | T-151 captured→completed in 2 min with owner: human |
| Specs completed without human review | Specification tasks completed by agent without human interaction |
| Stale handovers with unfilled TODOs | LATEST.md has `[TODO]` sections |
| Growing gaps register without action | G-004 "watching" for days with no trigger |
| Commits bunching (budget pressure) | 5 commits in 10 minutes = agent rushing |

### Insight generation:

| Insight | Example |
|---------|---------|
| Pattern emerging across tasks | Same error type hit 3+ times → candidate for practice |
| Velocity change | Tasks taking 2x longer than average |
| Task quality degrading | Descriptions getting shorter, ACs vaguer over time |
| Agent bypassing governance | Bypass log growing, `--force` usage increasing |

## Key Decision: New Inception, Not Cron Fix

**Chose:** Create T-194 inception for full ISO 27001-aligned assurance model
**Why:** T-151 was the wrong shape — "cron the audits" treats symptoms. The real gap is assurance structure: risk → control → OE → audit.
**Rejected:**
- (a) Just fix T-151/T-184 with better frequencies — treats symptoms
- (b) Add OE tests to existing cron — misses risk linkage and discovery layer
- (c) Stay with T-151 scope — the scope was wrong from the start

## Open Questions for Phase 1

1. Does `gaps.yaml` become the risk register, or do we need a separate `risks.yaml`?
2. What risk categories make sense for a software governance framework (vs infosec)?
3. How granular should the control register be? (per-script? per-function? per-rule?)
4. Should OE testing be separate from the audit system or integrated into it?
5. What's the right alerting model? (file-based findings? session-start summary? web UI?)
