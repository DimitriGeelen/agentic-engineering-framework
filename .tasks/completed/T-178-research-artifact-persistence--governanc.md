---
id: T-178
name: "Research artifact persistence — governance and enforcement"
description: >
  Systemic gap: agent research outputs (e.g., T-174's 3-agent investigation) exist only in conversation context and vanish at session end. Episodic memory captures task metadata but NOT investigation substance. No structural enforcement ensures research is captured — it's agent discipline only (violates P-012). PRIOR ART: L-026 established docs/reports/ as the location with YAML frontmatter. L-027 identified the pattern of capturing thinking-out-loud sessions. Existing examples: docs/reports/2026-02-17-agent-communication-bus-research.md, T-174-compaction-vs-handover.md. The LOCATION question is answered (docs/reports/). The remaining questions are ENFORCEMENT: (1) How to structurally enforce capture? (Gate on inception completion? Hook on sub-agent dispatch? Audit check?) (2) How to inject into future sessions? (Watchtower scan? fw resume? Handover references?) (3) How to prevent bloat? (Age out? Summarize?) (4) Should episodic.yaml reference the research doc? (Yes — see T-174 as pattern)

status: work-completed
workflow_type: inception
owner: claude-code
horizon: next
tags: []
related_tasks: []
created: 2026-02-18T19:27:31Z
last_update: 2026-02-19T07:15:00Z
date_finished: 2026-02-19T07:15:00Z
---

# T-178: Research artifact persistence — governance and enforcement

## Problem Statement

Sub-agent dispatch protocol (CLAUDE.md) says content generators "MUST write output to disk" and investigators should use `fw bus post`. Reality: fw bus has NEVER been used (empty results/blobs dirs). T-174's 3 agents all returned full results to orchestrator context — would have been lost without manual save to docs/reports/. The protocol exists but has zero enforcement. Additionally, `fw resume status` doesn't scan docs/reports/ or .context/bus/, so even persisted research isn't surfaced on recovery.

## Investigation Findings

### Current State — What Works

1. **docs/reports/ is the established location** — 16 research artifacts exist (debates, audits, experiments, task-specific analysis). No YAML frontmatter (plain markdown). Referenced by episodic memory (T-072, T-077, T-108, etc.) and handovers (as path pointers).

2. **Episodic memory is the index** — Completed tasks' `.context/episodic/T-XXX.yaml` files list research artifacts in their `artifacts` section, linking tasks to their outputs.

3. **Handovers point to artifacts** — Handover documents reference docs/reports/ paths in narrative sections, guiding the next session to relevant research.

4. **fw bus exists but is unused** — Full implementation in `lib/bus.sh` with size-gated YAML envelopes. `.context/bus/results/` and `.context/bus/blobs/` are empty. No agent has ever used `fw bus post`.

### Current State — What's Broken

1. **Zero enforcement** — Sub-Agent Dispatch Protocol in CLAUDE.md says "MUST write output to disk" but no hook, gate, or audit check validates this. Protocol compliance is agent discipline only.

2. **Resume doesn't surface artifacts** — `fw resume status` synthesizes from: session.yaml, focus.yaml, git state, active tasks, LATEST.md handover. Does NOT scan docs/reports/ or .context/bus/.

3. **fw bus adoption failure** — The bus protocol adds ceremony (fw bus post, manifest, read, clear) for a problem that docs/reports/ already solves more simply. The bus solves a real problem (context explosion from sub-agent results) but the simpler "write to file, mention path" pattern wins in practice.

### Analysis of Enforcement Options

| Option | Feasibility | Value | Recommendation |
|--------|------------|-------|----------------|
| **Audit check: inception tasks should have research docs** | High — add section to audit.sh checking inception tasks in completed/ have matching docs/reports/ files | Medium — retroactive detection, not prevention | **DO** |
| **Gate on inception completion** | High — update-task.sh could check for docs/reports/ artifacts when workflow_type=inception | Medium — blocks completion without artifact | **DO** |
| **Hook on sub-agent dispatch** | Low — Claude Code Task tool doesn't have a hookable event | N/A | **SKIP** |
| **Resume scans docs/reports/** | High — add docs/reports/ scanning to resume.sh | High — surfaces research on recovery | **DO** |
| **Mandate fw bus for sub-agents** | Low — adds ceremony, agents ignore it, no enforcement possible | Low — docs/reports/ already works | **SKIP** — simplify protocol in CLAUDE.md instead |
| **YAML frontmatter on research docs** | Medium — would enable programmatic scanning | Low — plain markdown is fine, episodic provides the index | **SKIP** |

### Recommendation: GO (selective)

**Build 2 things:**
1. **Audit check** — New audit section that checks completed inception tasks have at least one docs/reports/ artifact or explicit "no research output" annotation. (~15 lines in audit.sh)
2. **Resume integration** — Add docs/reports/ scanning to `fw resume status` to surface recent research artifacts. (~20 lines in resume.sh)

**Simplify 1 thing:**
3. **Update CLAUDE.md Sub-Agent Dispatch Protocol** — De-emphasize fw bus (unused, over-engineered for this use case). Emphasize the simpler pattern: write to docs/reports/, return path + summary. Keep bus as optional for large multi-agent orchestrations.

**Skip:** Hook on dispatch (not hookable), fw bus mandating (ceremony vs simplicity), YAML frontmatter (unnecessary).

**Estimated effort:** 1 build task, ~1 hour.

## Acceptance Criteria

- [x] Problem statement validated
- [x] Assumptions tested (bus unused, docs/reports established, no enforcement exists)
- [x] Go/No-Go decision made

## Go/No-Go Criteria

**GO if:**
- Clear enforcement mechanism identified that's low-effort and high-value
- Existing patterns (docs/reports/) just need structural backing, not replacement

**NO-GO if:**
- Enforcement would require new hook types or Claude Code API changes
- The problem is theoretical (artifacts aren't actually being lost)

## Verification

# Investigation findings exist in task body
grep -q "Investigation Findings" /opt/999-Agentic-Engineering-Framework/.tasks/active/T-178-research-artifact-persistence--governanc.md

## Decisions

**Decision**: GO

**Rationale**: Audit check + resume integration identified as low-effort, high-value enforcement. docs/reports pattern has organic adoption.

**Date**: 2026-02-19T07:15:00Z
## Decision

**Decision**: GO

**Rationale**: Audit check + resume integration identified as low-effort, high-value enforcement. docs/reports pattern has organic adoption.

**Date**: 2026-02-19T07:15:00Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-02-19T07:12:33Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-02-19T07:14:37Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Clear, low-effort enforcement identified: (1) audit check for inception research artifacts, (2) resume.sh scanning docs/reports/. Existing docs/reports/ pattern has organic adoption (16 files) and just needs structural backing.

### 2026-02-19T07:15:00Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Audit check + resume integration identified as low-effort, high-value enforcement. docs/reports pattern has organic adoption.

### 2026-02-19T07:15:00Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
