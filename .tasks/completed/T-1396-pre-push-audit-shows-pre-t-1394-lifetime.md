---
id: T-1396
name: "pre-push audit shows pre-T-1394 lifetime trend despite fix on HEAD"
description: >
  pre-push audit shows pre-T-1394 lifetime trend despite fix on HEAD

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: [agents/git/lib/hooks.sh]
related_tasks: []
created: 2026-04-23T13:49:24Z
last_update: '2026-06-11T22:23:47Z'
date_finished: 2026-04-23T13:54:02Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:47Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 1
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=1 (body:fix-without-learning); D2=0 (no-signal); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1396: pre-push audit shows pre-T-1394 lifetime trend despite fix on HEAD

## Context

Pre-push audit in the framework repo continues to show lifetime trend
counts ("39 times", "56 previous audits") despite T-1394 shipping the
14-day rolling window on HEAD. Root cause: `agents/git/lib/hooks.sh`
(pre-push template) resolves AUDIT_SCRIPT in this priority order:

1. `.framework.yaml` → framework_path
2. `$PROJECT_ROOT/.agentic-framework/agents/audit/audit.sh` (vendored bootstrap)
3. `$PROJECT_ROOT/agents/audit/audit.sh` (source-of-truth)

The framework repo has no `.framework.yaml` but DOES have the vendored
bootstrap `.agentic-framework/` AND the source-of-truth `agents/` at
root. Resolution step 2 matches first → stale vendored audit.sh (no
T-1394 fix) runs instead of HEAD.

Consumers never have root-level `agents/` — that is a framework-repo
marker. Swapping priorities 2 and 3 is strictly correct: prefer the
source-of-truth when present, fall back to vendored otherwise.

## Acceptance Criteria

### Agent
- [x] `agents/git/lib/hooks.sh` resolves root-level `agents/audit/audit.sh` before `.agentic-framework/agents/audit/audit.sh` in the pre-push template
- [x] Installed `.git/hooks/pre-push` in this repo reflects the new order (via `fw git install-hooks --force`)
- [x] Running pre-push audit against HEAD produces trend output in the 14-day window format (`Repeated issues detected in last 14 days` or `No repeated issues in last 14 days`), NOT the lifetime format (`N times`)
- [x] Consumer path still works: when root-level `agents/` is absent but `.agentic-framework/` is present, the vendored copy is still selected (by fallthrough logic — order preserved)
- [x] `bash -n agents/git/lib/hooks.sh` passes

## Verification

bash -n agents/git/lib/hooks.sh
grep -q 'AUDIT_SCRIPT="$PROJECT_ROOT/agents/audit/audit.sh"' agents/git/lib/hooks.sh
grep -q 'AUDIT_SCRIPT="$PROJECT_ROOT/agents/audit/audit.sh"' .git/hooks/pre-push
# Order check: root-level assignment precedes vendored assignment in both files
test "$(grep -n 'AUDIT_SCRIPT="$PROJECT_ROOT/agents/audit/audit.sh"' agents/git/lib/hooks.sh | cut -d: -f1)" -lt "$(grep -n 'AUDIT_SCRIPT="$PROJECT_ROOT/.agentic-framework/agents/audit/audit.sh"' agents/git/lib/hooks.sh | cut -d: -f1)"
test "$(grep -n 'AUDIT_SCRIPT="$PROJECT_ROOT/agents/audit/audit.sh"' .git/hooks/pre-push | cut -d: -f1)" -lt "$(grep -n 'AUDIT_SCRIPT="$PROJECT_ROOT/.agentic-framework/agents/audit/audit.sh"' .git/hooks/pre-push | cut -d: -f1)"
# HEAD audit emits 14-day window format (not lifetime "N times")
# Use tempfile to avoid SIGPIPE (exit 141) under pipefail
_t=$(mktemp) && PROJECT_ROOT="$PWD" bash agents/audit/audit.sh --section structure >"$_t" 2>&1; grep -qE "Repeated issues detected in last 14 days|No repeated issues in last 14 days" "$_t"; _r=$?; rm -f "$_t"; exit $_r

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

### 2026-04-23T13:49:24Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1396-pre-push-audit-shows-pre-t-1394-lifetime.md
- **Context:** Initial task creation

### 2026-04-23T13:54:02Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-a2344ada
- **Timestamp:** 2026-06-02T14:57:11Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** yes
- **Findings:** none

- **Layer-1 escalations:** 1
  1. **destructive-action** (high) — Destructive operation in verification or AC
     - matched: `rm -f`
