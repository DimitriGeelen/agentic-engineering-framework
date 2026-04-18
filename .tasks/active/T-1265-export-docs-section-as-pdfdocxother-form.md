---
id: T-1265
name: "Export docs section as PDF/DOCX/other formats"
description: >
  Inception: Export docs section as PDF/DOCX/other formats

status: captured
workflow_type: inception
owner: human
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-04-15T17:53:15Z
last_update: 2026-04-15T17:53:15Z
date_finished: null
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
- [ ] Problem statement validated
- [ ] Assumptions tested
- [ ] Recommendation written with rationale

### Human
- [ ] [REVIEW] Review exploration findings and approve go/no-go decision
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

<!-- REQUIRED before fw inception decide. Write your recommendation here (T-974).
     Watchtower reads this section — if it's empty, the human sees nothing.
     Format:
     **Recommendation:** GO / NO-GO / DEFER
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

<!-- Filled at completion via: fw inception decide T-XXX go|no-go --rationale "..." -->

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->
