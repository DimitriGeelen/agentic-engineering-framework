---
id: T-015
name: Fix episodic generator to require enrichment
description: >
  The episodic generator produces empty templates that look complete but contain no
  useful content. Fix by: (1) Add enrichment_status: pending|complete field, (2) Replace
  empty sections with explicit TODO prompts for LLM enrichment, (3) Make incomplete
  episodics visually obvious. Per multi-agent review finding.
status: work-completed
workflow_type: build
owner: human
priority: high
tags: [context-fabric, D1, D2, D3]
agents:
  primary: claude-code
  supporting: []
created: 2026-02-13T21:21:25Z
last_update: '2026-06-11T22:23:35Z'
date_finished: 2026-02-13T21:26:09Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:35Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 1
      F-ORCH: 0
      F3: 1
      F1: 1
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=1 (body:episodic-only); F-ORCH=0 (no-signal); F3=1 
      (body/components:prompt-incidental); F1=1 
      (body/components:context-fabric-incidental); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-015: Fix episodic generator to require enrichment

## Design Record

**Problem:** The episodic generator (agents/context/lib/episodic.sh) produces files that:
- Look complete ("Episodic summary generated")
- Contain empty/placeholder content
- Pass existence checks but fail usefulness

**Solution approach:**
1. Add `enrichment_status: pending` field to all generated episodics
2. Replace `successes: []` with structured TODO prompts
3. Replace `decisions: []` with prompts that reference Design Record
4. Add visible warning banner that enrichment is required
5. Output message should say "skeleton generated" not "summary generated"

**Key insight from multi-agent review:** The generator's job is to create a well-structured skeleton with clear prompts — not to fake understanding.

## Specification Record

Acceptance criteria:
- [x] Generated episodics have `enrichment_status: pending` field
- [x] Empty `summary:` replaced with TODO prompt referencing source task
- [x] Empty `successes:` has structured prompt for what to fill in
- [x] Empty `decisions:` prompts to extract from Design Record
- [x] Output message says "skeleton" not "summary"
- [x] Warning banner at top of file indicates enrichment required
- [x] Test: generate episodic for a task, verify TODO prompts present

## Test Files

- Generate episodic for existing completed task
- Verify enrichment_status field exists
- Verify TODO prompts are actionable

## Updates

### 2026-02-13T21:21:25Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-015-fix-episodic-generator-to-require-enrich.md
- **Context:** Initial task creation

### 2026-02-13T22:25:00Z — started-work [claude-code]
- **Action:** Read current episodic.sh, identified specific changes needed
- **Output:** Design record with solution approach
- **Context:** Generator outputs placeholders with comments, need to make them actionable prompts

### 2026-02-13T22:26:00Z — work-completed [claude-code]
- **Action:** Implemented all changes to episodic.sh
- **Output:**
  - Added header banner with REQUIRES ENRICHMENT status
  - Added enrichment_status: pending field
  - Replaced empty placeholders with [TODO] prompts
  - Changed output message to "skeleton generated" with warning
  - Generated and enriched T-015 episodic as example
- **Context:** Generator now honest about its limitations; creates skeleton for enrichment

## Reviewer Verdict (v1.5)

- **Scan ID:** R-602d9e33
- **Timestamp:** 2026-06-02T14:54:02Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
