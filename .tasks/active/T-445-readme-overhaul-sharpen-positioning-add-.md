---
id: T-445
name: "README overhaul: sharpen positioning, add 5-min demo, honest enforcement gradient"
description: >
  Inception: README overhaul: sharpen positioning, add 5-min demo, honest enforcement gradient

status: started-work
workflow_type: inception
owner: human
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-03-12T00:23:46Z
last_update: 2026-03-12T00:23:46Z
date_finished: null
---

# T-445: README overhaul: sharpen positioning, add 5-min demo, honest enforcement gradient

## Problem Statement

The README is the project's front door. Two independent critical reviews (one positioning-focused, one technical honesty-focused) identified the same structural problems:

1. **Wrong mental model** — Readers compare us to assistant runtimes (OpenClaw, LangGraph) because we never say "this is not that." We lose that comparison immediately because we don't ship messaging, browser automation, or skill ecosystems.
2. **Feature tour, not outcome pitch** — 80% of the README describes *what* the framework has. A VP/tech lead wants: "stops AI-caused incidents, makes commits traceable, sessions survive restarts."
3. **No proof of value** — For a guardrails product, we never show a single guardrail firing. No blocked command output, no caught audit failure, no war story.
4. **Complexity front-loaded** — "12 subsystems, 126 components" screams enterprise overhead. Users interact with ~6 commands and a dashboard.
5. **No 5-minute demo** — Quickstart has 3 paths but none show enforcement kicking in.
6. **Oversold claims** — Static metadata presented as "live topology," file-based memory as "memory system," bash checks as "compliance engine." Not dishonest, but the framing implies more depth than exists.
7. **Enforcement gradient hidden** — Full enforcement only works with Claude Code (PreToolUse hooks). Cursor/Copilot get git hooks + voluntary compliance. The README doesn't make this gradient clear.

**For whom:** GitHub visitors evaluating the project (devs, tech leads, VPs)
**Why now:** The project is live on GitHub and being marketed. Every day with wrong positioning is lost adoption.

## Assumptions

A1: Readers subconsciously compare us to OpenClaw/LangGraph-style agent runtimes
A2: A "5-minute demo" section showing enforcement in action would convert more visitors than the current feature tour
A3: Honest enforcement gradient (Claude Code = full, Cursor = partial, others = voluntary) builds more trust than the current uniform "structural enforcement" claim
A4: Moving architecture details into collapsibles and leading with outcomes improves first-impression retention
A5: Showing real blocked actions (Tier 0, task gate) is more compelling than describing the mechanism

## Exploration Plan

### Phase 1: Competitive positioning research (10 min)
- Review OpenClaw, LangGraph, CrewAI READMEs for framing patterns
- Identify what they do that we don't (and vice versa)
- Draft positioning contrast line

### Phase 2: Evidence gathering (15 min)
- Find real examples of Tier 0 blocks, task gate blocks, audit catches from our own history
- Extract terminal output or reconstruct realistic examples
- Identify 3-4 "war stories" that demonstrate value

### Phase 3: Draft new README structure (20 min)
- Rewrite top 15 lines with sharp positioning
- Draft "What this actually stops" section with evidence
- Draft "5-minute demo" section (5 commands → visible payoff)
- Restructure: outcomes first, architecture in collapsibles
- Add honest enforcement gradient table
- Present draft for review

## Technical Constraints

- README.md is the only file that changes (no code changes)
- Must keep existing screenshots references working
- Must not break any links from external sites (GitHub, LinkedIn posts)
- Keep README under ~400 lines (currently 417) — don't make it longer, make it sharper

## Scope Fence

**IN scope:**
- README.md rewrite (positioning, structure, content)
- Gathering evidence from project history (blocked commands, audit catches)
- Honest enforcement gradient disclosure

**OUT of scope:**
- FRAMEWORK.md changes
- CLAUDE.md changes
- Watchtower changes
- New screenshots (use existing)
- Project renaming (the name stays, just reframe the subtitle)

## Acceptance Criteria

### Agent
- [ ] Research artifact created at `docs/reports/T-445-readme-overhaul.md`
- [ ] Competitive positioning analysis (OpenClaw, LangGraph, CrewAI)
- [ ] Real enforcement evidence gathered (3+ examples)
- [ ] Draft README structure presented for review
- [ ] Go/No-Go decision made

### Human
- [ ] [REVIEW] Draft positioning resonates — reads as "governance layer" not "assistant runtime"
  **Steps:**
  1. Read the first 5 lines of the proposed README
  2. Ask: "Would a visitor immediately understand this is NOT another OpenClaw?"
  **Expected:** Clear differentiation in first 3 seconds of reading
  **If not:** Iterate on positioning language

## Go/No-Go Criteria

**GO if:**
- Positioning contrast is sharp and honest (not marketing fluff)
- 5-minute demo can be written with real commands that work
- Enforcement gradient can be disclosed without making the project look weak
- README stays ≤400 lines

**NO-GO if:**
- Honest disclosure of enforcement limitations makes the project look like "just git hooks"
- Can't find real evidence of blocked actions to show
- Rewrite would break existing inbound links

## Verification

# Inception — no code verification needed
echo "Inception task — verification is go/no-go decision"

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
