---
id: T-392
name: "Tag cloud for topic-based document browsing"
description: >
  Add a tag cloud to the search page empty state showing document topics derived from search categories and frequent terms. Tags are clickable and filter search results. Support single and multi-tag selection. Predecessor: T-388.

status: work-completed
workflow_type: build
owner: human
horizon: next
tags: []
components: []
related_tasks: []
created: 2026-03-09T11:36:23Z
last_update: 2026-03-12T12:41:19Z
date_finished: 2026-03-09T13:31:57Z
---

# T-392: Tag cloud for topic-based document browsing

## Context

Tag cloud derived from episodic memory tags (247 unique tags, 384 files). Shows top 24 topics with size variation based on frequency. Clicking a tag triggers a search. Part of T-388 search UX overhaul.

## Acceptance Criteria

### Agent
- [x] `aggregate_tags()` function in `web/search_utils.py` collects tags from episodic YAML
- [x] Tags filtered (min count 2, skip single-char/directive-ref noise)
- [x] Top 24 tags passed to search template on empty state only
- [x] Tag cloud renders above "Try a search" / "Saved answers" cards
- [x] Tags have size classes (sm/md/lg/xl) based on frequency
- [x] Each tag is a clickable link that triggers a hybrid search
- [x] Tag cloud hidden when search results are showing

### Human
- [x] [REVIEW] Tag cloud looks good and tags are useful for browsing
  **Steps:**
  1. Open http://localhost:3000/search
  2. Check the "Browse by topic" section with 24 tags
  3. Click a tag (e.g. "healing-loop") — search results should appear
  4. Verify tag sizes vary (build, cli should be larger than onboarding)
  **Expected:** Tag cloud is visually clear, tags are relevant topics, clicking works
  **If not:** Note which tags are unhelpful or which visual aspect is off

## Verification

curl -sf http://localhost:3000/search | grep -q tag-cloud
curl -sf http://localhost:3000/search | grep -q tag-chip

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

### 2026-03-09T11:36:23Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-392-tag-cloud-for-topic-based-document-brows.md
- **Context:** Initial task creation

### 2026-03-09T13:31:57Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

### 2026-03-10T22:04:14Z — status-update [task-update-agent]
- **Change:** horizon: now → next
