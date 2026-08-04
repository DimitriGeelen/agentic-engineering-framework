---
id: T-449
name: "Deep-dive articles 02-06: editing pass — strip fabricated stats, tighten voice"
description: >
  Edit pass on unpublished articles 02 (Tier 0), 03 (Context Budget), 05 (Healing
  Loop), 06 (Authority Model). These have the right structure and real incidents but
  need: (1) strip any percentage/statistic that cannot be traced to actual project
  data, (2) replace closing analogy if it reads as agent-generated, (3) tighten voice
  to match author tone (no hype, specific evidence, cross-domain analogies from governance
  background). Articles 02-06 are rescuable with one pass. See feedback in conversation
  and docs/reports/T-445-readme-overhaul.md for voice guide.

status: captured
workflow_type: refactor
owner: human
horizon: next
tags: [content, deep-dives]
components: [docs/articles/deep-dives/02-tier0-protection.md, 
      docs/articles/deep-dives/03-context-budget.md, 
      docs/articles/deep-dives/05-healing-loop.md, 
      docs/articles/deep-dives/06-authority-model.md]
related_tasks: [T-450, T-338, T-446]
created: 2026-03-12T06:37:40Z
last_update: 2026-08-04T18:06:23Z
date_finished:
bvp_scores_proposed:
  - ts: '2026-05-19T18:27:46Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-05-28T20:15:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F1: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F1=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-05-28T22:54:12Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-05T18:00:04Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 2
      F-ORCH: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=2 (body:lightly-promoted); F-ORCH=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T16:00:04Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 2
      F-ORCH: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=2 (body:lightly-promoted); F-ORCH=0 (no-signal); 
      F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:23:34Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 2
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=2 (body:lightly-promoted); F-ORCH=0 (no-signal); 
      F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-13T18:00:05Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 2
      F-ORCH: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=2 (body:lightly-promoted); F-ORCH=0 (no-signal); 
      F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-07-07T10:45:08Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0 (no-signal);
      F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-05-19T21:45:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 5
      tier: 3
      effort: 6
    rationale: blast_radius=5 (no-signal); tier=3 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-05-24T10:00:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 5
      tier: 3
      effort: 7
    rationale: blast_radius=5 (no-signal); tier=3 (no-signal); effort=7 
      (no-signal)
    rubric_sha: e4a00f38e801
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

### 2026-03-27T17:34:22Z — status-update [task-update-agent]
- **Change:** horizon: now → next

### 2026-05-24T09:16:36Z — status-update [task-update-agent]
- **Change:** workflow_type: refactor → build

### 2026-05-24T09:16:37Z — status-update [task-update-agent]
- **Change:** workflow_type: build → refactor

### 2026-05-24T09:27:35Z — status-update [task-update-agent]
- **Change:** horizon: next → next

### 2026-05-24T09:28:46Z — status-update [task-update-agent]
- **Change:** horizon: next → next

### 2026-05-24T09:29:09Z — status-update [task-update-agent]
- **Change:** workflow_type: refactor → build

### 2026-05-24T09:29:10Z — status-update [task-update-agent]
- **Change:** workflow_type: build → refactor

### 2026-05-24T09:54:36Z — status-update [task-update-agent]
- **Change:** workflow_type: refactor → build

### 2026-05-24T09:54:37Z — status-update [task-update-agent]
- **Change:** workflow_type: build → refactor

### 2026-05-24T09:55:00Z — status-update [task-update-agent]
- **Change:** horizon: next → next

### 2026-05-25T22:04:42Z — status-update [task-update-agent]
- **Change:** workflow_type: refactor → build

### 2026-05-25T22:04:42Z — status-update [task-update-agent]
- **Change:** workflow_type: build → refactor

### 2026-05-25T22:06:15Z — status-update [task-update-agent]
- **Change:** horizon: next → next

### 2026-05-25T22:09:37Z — status-update [task-update-agent]
- **Change:** horizon: next → next

### 2026-08-04T10:33:55Z — status-update [task-update-agent]
- **Change:** horizon: next → next

### 2026-08-04T11:01:29Z — status-update [task-update-agent]
- **Change:** workflow_type: refactor → build

### 2026-08-04T11:01:30Z — status-update [task-update-agent]
- **Change:** workflow_type: build → refactor

### 2026-08-04T12:46:52Z — status-update [task-update-agent]
- **Change:** horizon: next → next

### 2026-08-04T14:39:06Z — status-update [task-update-agent]
- **Change:** horizon: next → next

### 2026-08-04T15:25:55Z — status-update [task-update-agent]
- **Change:** workflow_type: refactor → build

### 2026-08-04T15:25:56Z — status-update [task-update-agent]
- **Change:** workflow_type: build → refactor

### 2026-08-04T17:40:40Z — status-update [task-update-agent]
- **Change:** horizon: next → next

### 2026-08-04T18:06:22Z — status-update [task-update-agent]
- **Change:** workflow_type: refactor → build

### 2026-08-04T18:06:23Z — status-update [task-update-agent]
- **Change:** workflow_type: build → refactor
