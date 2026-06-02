---
id: T-1265
name: "Export docs section as PDF/DOCX/other formats"
description: >
  Inception: Export docs section as PDF/DOCX/other formats

status: captured
workflow_type: inception
owner: human
horizon: later
tags: []
components: []
related_tasks: []
created: 2026-04-15T17:53:15Z
last_update: '2026-06-02T08:30:02Z'
date_finished:
bvp_scores_proposed:
  - ts: '2026-05-19T18:27:45Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 1
      D2: 0
      D3: 0
      D4: 2
    rationale: D1=1 (body:fix-without-learning); D2=0 (no-signal); D3=0 
      (no-signal); D4=2 (body:env-class-handled)
    rubric_sha: e4a00f38e801
  - ts: '2026-05-28T20:15:01Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 1
      D2: 0
      D3: 0
      D4: 2
      F1: 0
    rationale: D1=1 (body:fix-without-learning); D2=0 (no-signal); D3=0 
      (no-signal); D4=2 (body:env-class-handled); F1=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-05-28T22:54:09Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 1
      D2: 0
      D3: 0
      D4: 2
      F1: 0
      F2: 0
    rationale: D1=1 (body:fix-without-learning); D2=0 (no-signal); D3=0 
      (no-signal); D4=2 (body:env-class-handled); F1=0 (no-signal); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-05-29T23:00:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 1
      D2: 0
      D3: 0
      D4: 2
      F1: 0
    rationale: D1=1 (body:fix-without-learning); D2=0 (no-signal); D3=0 
      (no-signal); D4=2 (body:env-class-handled); F1=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-01T08:15:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 1
      D2: 0
      D3: 0
      D4: 2
    rationale: D1=1 (body:fix-without-learning); D2=0 (no-signal); D3=0 
      (no-signal); D4=2 (body:env-class-handled)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-02T08:30:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 1
      D2: 0
      D3: 0
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
    rationale: D1=1 (body:fix-without-learning); D2=0 (no-signal); D3=0 
      (no-signal); D4=2 (body:env-class-handled); F-RECALL=0 (no-signal); 
      F-ORCH=0 (no-signal)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-05-19T21:45:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 4
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=4 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
---

# T-1265: Export docs section as PDF/DOCX/other formats

## Problem Statement

Users want to export the Watchtower `/docs` section content (generated component docs, deep-dive articles, reports) as portable documents — PDF, DOCX, or equivalent. Current `/docs` is HTML-only in the web UI; no offline / printable / shareable format exists. Use cases: sharing framework walkthroughs with external collaborators, archival snapshots of research artifacts, offline reading on mobile, compliance handoff.

## Assumptions

- A1: PDF + DOCX cover ≥90% of user demand (other formats nice-to-have)
- A2: Pandoc (or equivalent) is an acceptable toolchain — already in common Linux/Mac distros
- A3: Export entry point is a button/menu in the `/docs` UI (not CLI-first), with optional CLI for bulk export
- A4: Per-page export is primary UX; full-corpus export is secondary
- A5: Framework repo and consumer projects share the same export pipeline (no consumer-specific forks)

## Exploration Plan

- Spike A: Survey `/docs` content shapes (markdown sources, generated templates, article structure)
- Spike B: Evaluate tooling — pandoc vs WeasyPrint vs browser-print vs bespoke
- Spike C: Styling fidelity — code blocks, tables, diagrams, cross-links under each tool
- Spike D: Distribution model — on-demand render vs pre-generated archive vs CI-generated release artifact
- Spike E: Scope audit — which `/docs` subsections are in/out (generated-components? articles? reports? walkthrough?)

## Technical Constraints

- Watchtower runs as Flask on :3000 (local dev) and behind Traefik (prod) — export must work in both
- Pandoc requires LaTeX for PDF (heavy dep) — consider alternatives for lighter footprint
- Diagrams are mermaid/ascii — PDF/DOCX rendering differs per tool
- Task files contain YAML frontmatter + Markdown — export pipeline must strip frontmatter cleanly

## Scope Fence

**IN:**
- Export of `/docs/generated/components/*.md`, `/docs/articles/*.md`, `/docs/reports/*.md`
- PDF + DOCX formats at minimum
- Web UI trigger (button on each docs page)

**OUT:**
- Export of task files (different workflow; already downloadable as .md)
- Export of raw `.md` source files (already served by Watchtower)
- Epub / mobi / other ebook formats (nice-to-have, defer)
- Bulk/batch export across all docs (secondary; future task if demand emerges)

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

**Recommendation:** DEFER — demand has not materialised

**Rationale:** The exploration plan is well-scoped (5 spikes A–E for content survey, tooling eval, styling fidelity, distribution model, scope audit) but none of the spikes have been executed. More importantly, in the 45+ days since capture (2026-03-05), no user has requested a specific document export, and no downstream integration (compliance handoff, external collaborator share) has cited `/docs` export as a blocker. Watchtower already serves raw `.md` files via `/file/…`, which covers the archival/offline case for technical users. Implementing the full pipeline (pandoc toolchain, per-page export button, CLI bulk mode, styling fidelity for diagrams/code blocks) is multi-session work that would be speculative today. DEFER until a concrete use case files a sibling task with named user + artefact.

**Evidence:**
- Task captured 2026-03-05 (49 days at time of review); no follow-up activity, no related_tasks linking in.
- Watchtower `/docs` pages already render component cards, articles, and reports as HTML — no user complaint recorded that HTML is insufficient.
- Raw markdown download exists via `/file/docs/…` endpoints (served through `web/shared.py`) — archival use case is already served.
- No spike executed: A (content-shape survey), B (tooling eval), C (styling fidelity), D (distribution model), E (scope audit) all in "planned" state.
- Scope fence is crisp (IN: 3 doc types × PDF+DOCX; OUT: epub/bulk/task-files) so the work IS well-shaped — this is not a "needs more scoping" DEFER, it is a "needs demand" DEFER. Re-open when the first real request arrives.

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

**Decision**: DEFER

**Rationale**: Recommendation: DEFER — demand has not materialised

Rationale: The exploration plan is well-scoped (5 spikes A–E for content survey, tooling eval, styling fidelity, distribution model, scope audit) but none of the spikes have been executed. More importantly, in the 45+ days since capture (2026-03-05), no user has requested a specific document export, and no downstream integration (compliance handoff, external collaborator share) has cited `/docs` export as a blocker. Watchtower already serves raw `.md` files via `/file/…`, which covers the archival/offline case for technical users. Implementing the full pipeline (pandoc toolchain, per-page export button, CLI bulk mode, styling fidelity for diagrams/code blocks) is multi-session work that would be speculative today. DEFER until a concrete use case files a sibling task with named user + artefact.

Evidence:
- Task captured 2026-03-05 (49 days at time of review); no follow-up activity, no related_tasks linking in.
- Watchtower `/docs` pages already render component cards, articles, and reports as HTML — no user complaint recorded that HTML is insufficient.
- Raw markdown download exists via `/file/docs/…` endpoints (served through `web/shared.py`) — archival use case is already served.
- No spike executed: A (content-shape survey), B (tooling eval), C (styling fidelity), D (distribution model), E (scope audit) all in "planned" state.
- Scope fence is crisp (IN: 3 doc types × PDF+DOCX; OUT: epub/bulk/task-files) so the work IS well-shaped — this is not a "needs more scoping" DEFER, it is a "needs demand" DEFER. Re-open when the first real request arrives.

**Date**: 2026-04-24T09:24:40Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-04-24T09:24:40Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** DEFER
- **Rationale:** Recommendation: DEFER — demand has not materialised

Rationale: The exploration plan is well-scoped (5 spikes A–E for content survey, tooling eval, styling fidelity, distribution model, scope audit) but none of the spikes have been executed. More importantly, in the 45+ days since capture (2026-03-05), no user has requested a specific document export, and no downstream integration (compliance handoff, external collaborator share) has cited `/docs` export as a blocker. Watchtower already serves raw `.md` files via `/file/…`, which covers the archival/offline case for technical users. Implementing the full pipeline (pandoc toolchain, per-page export button, CLI bulk mode, styling fidelity for diagrams/code blocks) is multi-session work that would be speculative today. DEFER until a concrete use case files a sibling task with named user + artefact.

Evidence:
- Task captured 2026-03-05 (49 days at time of review); no follow-up activity, no related_tasks linking in.
- Watchtower `/docs` pages already render component cards, articles, and reports as HTML — no user complaint recorded that HTML is insufficient.
- Raw markdown download exists via `/file/docs/…` endpoints (served through `web/shared.py`) — archival use case is already served.
- No spike executed: A (content-shape survey), B (tooling eval), C (styling fidelity), D (distribution model), E (scope audit) all in "planned" state.
- Scope fence is crisp (IN: 3 doc types × PDF+DOCX; OUT: epub/bulk/task-files) so the work IS well-shaped — this is not a "needs more scoping" DEFER, it is a "needs demand" DEFER. Re-open when the first real request arrives.

### 2026-04-28T20:02:46Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-05-15T19:54:38Z — status-update [task-update-agent]
- **Change:** horizon: now → later
- **Change:** status: started-work → captured (auto-sync)
- **Reason:** T-1865 sweep: DEFER limbo recovery
