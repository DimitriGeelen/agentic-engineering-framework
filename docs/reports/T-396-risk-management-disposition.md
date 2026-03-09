---
title: "T-396: Risk Management Process Disposition"
task: T-396
date: 2026-03-09
type: inception-research
---

# T-396: Risk Management Process Disposition

## Problem Statement

The risk management process (risks.yaml, issues.yaml, controls.yaml) has become stale and disconnected from the operational framework. Last updated Feb 19 (18 days ago). Human raised concern about staleness.

## Current State

| Register | Entries | Open | Last Updated | Operational Consumers |
|----------|---------|------|--------------|----------------------|
| risks.yaml | 37 | 4 | Feb 19 (18 days) | Web UI only |
| gaps.yaml | 19 | 7 | Today | Audit, CLAUDE.md, handover, tasks |
| controls.yaml | 27 | 5 | Feb 20 | fw doctor (1 control) |
| issues.yaml | ~10 | 2 | Feb 19 | Web UI only |

## Five Independent Analyses

### 1. Governance Architect — ARCHIVE

risks.yaml is governance theater: 18 days stale, zero audit coverage, zero CLI integration. 28 of 37 risks were discovered FROM incidents, not predicted — they are gaps wearing risk-register clothing. The ISO 27001 L*I scoring has never been consumed by any tool. Maintaining 4 registers when only 1 is alive creates cognitive tax (agent must decide which register to write to) and integration overhead.

**Recommendation:** Archive risks.yaml and issues.yaml. Slim controls.yaml to reference table. Gaps.yaml is the winner.

### 2. Practitioner/Operator — ARCHIVE + MIGRATE

"I never look at risks.yaml." The only register the framework actually uses is gaps. The heatmap is a dashboard for a process that doesn't exist. Three stale registers give the appearance of governance without the reality. One well-maintained register beats three dead ones.

**Recommendation:** Archive risks/controls/issues. Migrate 4 open risks to gaps.yaml.

### 3. Antifragility Theorist — DECOMMISSION

A scored risk register is predict-and-prevent thinking — the opposite of antifragility. The healing loop + gaps + patterns + escalation ladder form a complete antifragile immune system. Zero incidents were prevented by reading the risk register. Every improvement came from surviving a failure. "Taleb would burn the heatmap."

The risk register is fragile by nature: requires active maintenance to reflect reality, provides false confidence when neglected.

**Recommendation:** Decommission. Move controls.yaml ownership from risks to incidents/gaps.

### 4. Systems Engineer — WIRE IN OR CONSOLIDATE

The architecture is sound but implementation incomplete. 4 feedback loops are broken:
- Risk → Audit (never checked)
- Issue → Risk scoring (never recalculated)
- Risk → Healing (never consulted)
- Risk → Handover (never surfaced)

**Minimum integration:** ~55 lines of shell (audit section + handover awareness + healing lookup).
**Maximum simplification:** Merge risks into gaps as `type: risk` entries, delete issues.yaml (duplicates episodic + patterns).

**Recommendation:** Wire it in first (~55 lines), evaluate consolidation after 30 days. Delete issues.yaml now (unambiguous).

### 5. Devil's Advocate — REVIVE

Archiving removes the framework's only forward-looking instrument. Staleness is a bandwidth symptom, not uselessness evidence. Gaps = present tense, risks = future tense — collapsing them loses temporal dimension. 3 gaps (G-015, G-018, G-019) registered since Feb 19 map to risk classes that should have been tracked. External adopters expect a risk register.

**Recommendation:** Revive with `fw risk` CLI + audit staleness check + CLAUDE.md mention. ~2 hours. Non-negotiable: CLI and audit hook, or revival is meaningless.

## Score Card

| Option | Votes | Advocates |
|--------|-------|-----------|
| Archive/Decommission | 3 | Governance, Practitioner, Antifragile |
| Revive | 1 | Devil's Advocate |
| Wire-in-then-evaluate | 1 | Systems Engineer |

## Key Tensions

1. **Forward-looking vs reactive-only:** Archiving removes the ability to track "what hasn't happened yet but could be catastrophic." Keeping adds maintenance cost for a register nobody reads.

2. **ISO compliance vs operational simplicity:** Risk registers are expected in governed organizations. But this is a solo-developer framework where gaps.yaml already does the job.

3. **Temporal distinction vs cognitive overhead:** Risks (future), gaps (present), issues (past) is conceptually clean. But agents always write to gaps because CLAUDE.md only mentions gaps.

4. **Antifragility paradox:** D1 says strengthen under stress. A risk register tries to prevent stress. But the barbell strategy says protect against catastrophic downside. Both are valid interpretations.

## Dialogue Log

### Human concern (2026-03-09)
- "we have a risk management process can you please use the component fabric to analyse how the process works, i am concerned this process has become stale"
- After seeing 5-perspective analysis: "go lets follow framework governance"
- Initiated inception task T-396

## Options for Decision

### Option A: Archive + Migrate (majority recommendation)
- Archive risks.yaml, issues.yaml to `docs/archive/`
- Migrate 4 open risks → gaps.yaml as `type: risk` entries
- Keep controls.yaml as reference table (remap from risks to gaps)
- Keep web UI as historical view with "archived" banner
- **Cost:** ~1 hour. **Risk:** Lose forward-looking dimension.

### Option B: Slim + Integrate (middle ground)
- Keep risks.yaml but slim to open risks only (4-8 entries)
- Add audit staleness check (~10 lines)
- Add `fw risk` CLI (~30 lines)
- Add 1 line to CLAUDE.md
- Delete issues.yaml (duplicates episodic)
- **Cost:** ~2 hours. **Risk:** May still go stale if not wired deeply enough.

### Option C: Full Integration (systems engineer)
- Wire risks into audit + handover + healing (~55 lines)
- Add `fw risk` CLI
- Add CLAUDE.md reference
- Delete issues.yaml
- Evaluate consolidation after 30 days
- **Cost:** ~4 hours. **Risk:** Over-engineering for 4 open risks.

### Option D: Consolidate into unified concerns register (novel)
- Merge risks + gaps into `concerns.yaml` with `type: gap | risk`
- Delete issues.yaml
- All existing gap infrastructure carries over
- Risks gain audit, handover, CLAUDE.md coverage automatically
- Controls.yaml maps to concerns instead of risks
- **Cost:** ~3 hours. **Risk:** Migration complexity, backlink updates.
