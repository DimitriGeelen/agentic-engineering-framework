---
id: T-334
name: "Execute launch sequence: r/ClaudeAI soft launch → Show HN → amplification"
description: >
  Launch sequence: Week -1: Post to r/ClaudeAI with 'here is what I built' framing + submit to Console.dev and TLDR newsletters. Week 0: Show HN Tuesday 9 AM PT with 200-word intro comment. Week +1: Product Hunt + r/programming + pitch Latent Space. Requires: demo video, all GitHub quick wins done, CONTRIBUTING.md ready. Ref: docs/reports/T-327-visibility-strategy.md

status: started-work
workflow_type: build
owner: human
horizon: next
tags: []
components: []
related_tasks: []
created: 2026-03-05T01:12:46Z
last_update: 2026-03-09T06:52:07Z
date_finished: null
---

# T-334: Execute launch sequence: r/ClaudeAI soft launch → Show HN → amplification

## Context

Launch sequence per `docs/reports/T-327-visibility-strategy.md` Tier 3 actions (#11-#14). All prerequisite GitHub quick wins done (topics, discussions, v1.0.0 release, AGENTS.md, CONTRIBUTING.md). Post drafts at `docs/articles/{reddit-claudeai-post,linkedin-post,launch-article}.md`.

## Acceptance Criteria

### Agent
- [x] Launch prerequisites verified (topics, discussions, release, AGENTS.md, CONTRIBUTING.md)
- [x] Post drafts exist and are ready for human review
- [x] Prerequisite gap documented (demo video missing — human-produced)

### Human
- [ ] [REVIEW] Review and post r/ClaudeAI draft (`docs/articles/reddit-claudeai-post.md`)
  **Steps:**
  1. Read `docs/articles/reddit-claudeai-post.md`
  2. Edit tone/content as needed
  3. Post to r/ClaudeAI
  **Expected:** Post live on r/ClaudeAI
  **If not:** Note what needs changing for agent revision

- [ ] [REVIEW] Review and post LinkedIn draft (`docs/articles/linkedin-post.md`)
  **Steps:**
  1. Read `docs/articles/linkedin-post.md`
  2. Post to LinkedIn
  **Expected:** Post live on LinkedIn
  **If not:** Note what needs changing

- [ ] Record 3-min demo video (Tier 1 action #5 — blocks Show HN for maximum impact)
  **Steps:**
  1. Record: Tier 0 block → task gate → audit pass flow
  2. Upload to YouTube or embed in README
  **Expected:** Video linked in repo README
  **If not:** Proceed without video (text-only launch)

- [ ] Show HN submission (Tuesday 9 AM PT, 200-word intro comment)
  **Steps:**
  1. Submit link to GitHub repo on news.ycombinator.com
  2. Post intro comment (see visibility strategy doc)
  3. Engage with comments for 6 hours
  **Expected:** HN post live
  **If not:** Try next Tuesday

## Verification

test -f docs/articles/reddit-claudeai-post.md
test -f docs/articles/linkedin-post.md
test -f docs/articles/launch-article.md
test -f CONTRIBUTING.md
test -f AGENTS.md

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

### 2026-03-05T01:12:46Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-334-execute-launch-sequence-rclaudeai-soft-l.md
- **Context:** Initial task creation

### 2026-03-09T06:52:01Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
