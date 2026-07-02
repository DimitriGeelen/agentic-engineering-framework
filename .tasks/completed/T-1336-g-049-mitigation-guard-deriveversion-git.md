---
id: T-1336
name: "G-049 mitigation: guard _derive_version git describe on framework-own .git
  to stop consumer-tag walk"
description: >
  G-049 mitigation: guard _derive_version git describe on framework-own .git to stop
  consumer-tag walk

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: []
related_tasks: []
created: 2026-04-19T14:14:26Z
last_update: '2026-06-11T22:23:45Z'
date_finished: 2026-04-19T15:57:32Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:45Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=2 (body:concern-ref); D2=0 (no-signal); D3=0 (no-signal); D4=0
      (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1336: G-049 mitigation: guard _derive_version git describe on framework-own .git to stop consumer-tag walk

## Context

G-049 mitigation. `_derive_version` in bin/fw:16-38 uses `git -C "$fw_dir" describe` which walks up the directory tree until it finds a `.git`. In vendored mode (framework installed inside a consumer project), this finds the **consumer's** `.git` and returns the consumer's tag (e.g. 0.12.1191 instead of the framework's 1.5.744). Fix: only invoke `git describe` when `$fw_dir` has its own `.git` (directory or worktree file); otherwise fall through to the VERSION file.

## Acceptance Criteria

### Agent
- [x] `_derive_version` guards `git describe` on presence of `$fw_dir/.git` (dir or file)
- [x] Framework-repo mode still reports correct tag-derived version (fw v1.5.20 unchanged)
- [x] Simulated vendored test: consumer repo tagged v0.12.1191, vendored subdir VERSION=1.5.744 — without guard, git describe walks up and returns consumer tag; with guard, guard fails and control falls to VERSION file
- [x] `bin/fw --version` unchanged in the framework repo (regression check)

### Human
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
     Remove this section if all criteria are agent-verifiable.
     Each criterion MUST include Steps/Expected/If-not so the human can act without guessing.
     Optionally prefix with [RUBBER-STAMP] or [REVIEW] for prioritization.
     Example:
       - [ ] [REVIEW] Dashboard renders correctly
         **Steps:**
         1. Open https://example.com/dashboard in browser
         2. Verify all panels load within 2 seconds
         3. Check browser console for errors
         **Expected:** All panels visible, no console errors
         **If not:** Screenshot the broken panel and note the console error
-->

## Verification

bash -n bin/fw
bin/fw --version | grep -qE "^fw v[0-9]+\.[0-9]+\.[0-9]+"

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

### 2026-04-19T14:14:26Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1336-g-049-mitigation-guard-deriveversion-git.md
- **Context:** Initial task creation

### 2026-04-19T15:57:32Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-1141daad
- **Timestamp:** 2026-06-02T14:56:47Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 2
     - evidence: `bin/fw --version | grep -qE "^fw v[0-9]+\.[0-9]+\.[0-9]+"`
