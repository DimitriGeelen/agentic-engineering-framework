---
id: T-1370
name: "Self-vendor sync — lib/init.sh G-053-A absolute-path propagation"
description: >
  Self-vendor sync — lib/init.sh G-053-A absolute-path propagation

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-04-20T22:32:05Z
last_update: '2026-06-11T22:23:46Z'
date_finished: 2026-04-20T22:47:05Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:46Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 1
      F1: 0
      F2: 0
    rationale: D1=2 (body:concern-ref); D2=0 (no-signal); D3=0 (no-signal); D4=0
      (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=1 
      (body/components:prompt-incidental); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1370: Self-vendor sync — lib/init.sh G-053-A absolute-path propagation

## Context

Source lib/*.sh had accumulated fixes (T-1364 G-053-A absolute paths in init.sh; T-1366 keylock $2-with-default + timeout; others) that weren't mirrored to the self-vendored .agentic-framework/lib/. The self-vendor block in lib/upgrade.sh only runs during consumer upgrades — never on the framework repo itself. Consumers receive these via `fw upgrade`; framework self-copy gets stale silently.

## Acceptance Criteria

### Agent
- [x] All lib/*.sh files match their .agentic-framework/lib/ counterparts (diff -q empty for every pair)
- [x] Synced files pass `bash -n` syntax check
- [x] Untracked .agentic-framework/lib/prompt.sh added to git

## Verification

for f in lib/*.sh; do name=$(basename "$f"); vf=".agentic-framework/lib/$name"; [ -f "$vf" ] && diff -q "$f" "$vf" >/dev/null || { echo "DRIFT: $name"; exit 1; }; done
bash -n .agentic-framework/lib/init.sh
bash -n .agentic-framework/lib/keylock.sh

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

### 2026-04-20T22:32:05Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1370-self-vendor-sync--libinitsh-g-053-a-abso.md
- **Context:** Initial task creation

### 2026-04-20T22:47:05Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-ca2057a9
- **Timestamp:** 2026-06-02T14:57:00Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#3 (Agent)** — Untracked .agentic-framework/lib/prompt.sh added to git
  - **AC-verify-mismatch** (narrow, heuristic) — `path=agentic-framework/lib/prompt.sh in: Untracked .agentic-framework/lib/prompt.sh added to git`
