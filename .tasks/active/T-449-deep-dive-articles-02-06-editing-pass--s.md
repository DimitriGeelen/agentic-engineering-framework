---
id: T-449
name: "Deep-dive articles 02-06: editing pass — strip fabricated stats, tighten voice"
description: >
  Edit pass on unpublished articles 02 (Tier 0), 03 (Context Budget), 05 (Healing Loop), 06 (Authority Model). These have the right structure and real incidents but need: (1) strip any percentage/statistic that cannot be traced to actual project data, (2) replace closing analogy if it reads as agent-generated, (3) tighten voice to match author tone (no hype, specific evidence, cross-domain analogies from governance background). Articles 02-06 are rescuable with one pass. See feedback in conversation and docs/reports/T-445-readme-overhaul.md for voice guide.

status: captured
workflow_type: refactor
owner: human
horizon: now
tags: [content, deep-dives]
components: [docs/articles/deep-dives/02-tier0-protection.md, docs/articles/deep-dives/03-context-budget.md, docs/articles/deep-dives/05-healing-loop.md, docs/articles/deep-dives/06-authority-model.md]
related_tasks: [T-450, T-338, T-446]
created: 2026-03-12T06:37:40Z
last_update: 2026-03-12T06:37:40Z
date_finished: null
---

# T-449: Deep-dive articles 02-06: editing pass — strip fabricated stats, tighten voice

## Context

External review identified a quality split: articles 01-07 are strong, 08-15 are weak. Articles 02-06 fall in the "strong but unpublished" group — they have real incidents and correct structure but need a tightening pass before publication. Voice guide in `docs/reports/T-445-readme-overhaul.md`.

Related: T-450 (gut rewrite of 08-15), T-338 (content series), T-446 (README rewrite with voice calibration).

## Acceptance Criteria

### Human
- [ ] [REVIEW] Article 02 (Tier 0): no unverifiable statistics remain
  **Steps:**
  1. Read `docs/articles/deep-dives/02-tier0-protection.md`
  2. Check every percentage — can you trace it to a task file, audit output, or metrics?
  3. Verify the force-push catch anecdote is accurate
  **Expected:** All stats traceable or replaced with qualitative language
  **If not:** Flag the specific stat and its claimed source

- [ ] [REVIEW] Article 03 (Context Budget): research citations are real
  **Steps:**
  1. Read `docs/articles/deep-dives/03-context-budget.md`
  2. Verify T-138, T-174 references match actual task files
  3. Check token threshold numbers match CLAUDE.md
  **Expected:** Citations match reality, thresholds accurate
  **If not:** Note which references are fabricated

- [ ] [REVIEW] Article 05 (Healing Loop): closing analogy sounds like the author, not the agent
  **Steps:**
  1. Read the closing paragraph
  2. Compare tone to articles 01 and 04
  **Expected:** Same voice — cross-domain analogy, no hype, "the domain changed"
  **If not:** Rewrite closing

- [ ] [REVIEW] Article 06 (Authority Model): T-151 anecdote is consistent with article 01's version
  **Steps:**
  1. Compare the T-151 incident description in article 06 vs article 01
  2. Verify they don't contradict each other
  **Expected:** Same incident, possibly different angle, no contradictions
  **If not:** Align to article 01's version (published first)

- [ ] [REVIEW] All 4 articles: voice matches author tone (no "Governance begins with X" openers, no exclamation marks, no hype vocabulary)
  **Steps:**
  1. Read first paragraph of each article
  2. Check against voice guide DO/DON'T rules in `docs/reports/T-445-readme-overhaul.md`
  **Expected:** Reads like articles 01/04/07
  **If not:** Note which articles still sound agent-generated

## Verification

# All 4 article files exist and are non-empty
test -s docs/articles/deep-dives/02-tier0-protection.md
test -s docs/articles/deep-dives/03-context-budget.md
test -s docs/articles/deep-dives/05-healing-loop.md
test -s docs/articles/deep-dives/06-authority-model.md

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Updates

### 2026-03-12T06:37:40Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-449-deep-dive-articles-02-06-editing-pass--s.md
- **Context:** Initial task creation
