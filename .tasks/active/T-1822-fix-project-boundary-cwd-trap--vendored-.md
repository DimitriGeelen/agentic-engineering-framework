---
id: T-1822
name: "fix project-boundary cwd-trap — vendored .agentic-framework/ cwd traps consumer agent (session-fatal)"
description: >
  B-1 (HIGH/session-fatal) reported by termlink-agent on 2026-05-14. After cd into .agentic-framework/ from a consumer root (normal diagnostic move), every subsequent cd back, git -C, pushd, or Write to the outer consumer is BLOCKED by check-project-boundary.sh. Root cause: the hook resolves PROJECT_ROOT from cwd; .agentic-framework/ ships FRAMEWORK.md so cwd-inside-vendored-copy makes the hook decide we ARE in the framework repo, and everything outside .agentic-framework/ becomes 'another project'. PROJECT_ROOT env doesn't propagate. Symmetric twin of T-1542 (T-1542 is the write-side; this is the read/cd side). Suggested fix: when cwd is inside a vendored copy AND a parent dir has .framework.yaml (i.e. consumer-vendored not standalone-framework), prefer the OUTER as PROJECT_ROOT. Files: agents/context/check-project-boundary.sh.

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [arc:project-shape-resilience, project-boundary, fw-upgrade-incident-2026-05-14, T-559, T-1542, bug]
components: []
related_tasks: [T-559, T-1542, T-1634]
created: 2026-05-14T07:30:21Z
last_update: 2026-05-14T07:32:07Z
date_finished: null
---

# T-1822: fix project-boundary cwd-trap — vendored .agentic-framework/ cwd traps consumer agent (session-fatal)

## Context

Reported by termlink-agent on 2026-05-14 during framework-upgrade incident. Session-fatal for any consumer agent doing diagnostic work that requires entering the vendored `.agentic-framework/` directory. Symmetric twin of T-1542 (write-side guard) — same root-cause family on the read/cd side.

## Acceptance Criteria

### Agent
- [ ] `lib/paths.sh` detects vendored case: when `FRAMEWORK_ROOT` basename is `.agentic-framework` AND its parent contains `.framework.yaml`, sets `PROJECT_ROOT` to the parent.
- [ ] Standalone framework checkouts (FRAMEWORK_ROOT not named `.agentic-framework`, or parent has no `.framework.yaml`) keep the existing git-toplevel resolution — no regression.
- [ ] Unit test added in `tests/unit/` exercising both branches (vendored + standalone) via fixture directories under `/tmp`.
- [ ] Existing PROJECT_ROOT-sensitive tests still pass (`fw test unit`).
- [ ] Reproduction from termlink-agent's report no longer traps: with vendored `.agentic-framework/` (own `.git`, parent `.framework.yaml`), `cd $PROJECT_ROOT_OUTER` from inside `.agentic-framework/` is allowed by the boundary hook.

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

bash -n lib/paths.sh
bin/fw test unit 2>&1 | tail -5 | grep -qE 'pass|ok|PASS|0 failed|no tests'
bash -c 'TMPDIR=$(mktemp -d); mkdir -p "$TMPDIR/consumer/.agentic-framework/lib"; touch "$TMPDIR/consumer/.framework.yaml"; cp lib/paths.sh "$TMPDIR/consumer/.agentic-framework/lib/paths.sh"; unset PROJECT_ROOT FRAMEWORK_ROOT; cd "$TMPDIR/consumer/.agentic-framework" && source lib/paths.sh && [ "$PROJECT_ROOT" = "$TMPDIR/consumer" ] && echo "VENDORED-CASE-OK: $PROJECT_ROOT" || { echo "FAIL: PROJECT_ROOT=$PROJECT_ROOT expected=$TMPDIR/consumer"; exit 1; }'

## RCA

<!-- REQUIRED for bug-class tasks (workflow_type=build with bug-tag, OR title matches
     fix/bug/rca/broken/crash/error/regression/fail/hotfix).
     Non-bug-class tasks may leave this section empty or remove it.

     For bug-class, fill in:
       **Symptom:** what was observed (the user-facing manifestation).
       **Root cause:** the specific structural/logical gap — not "the code was wrong".
       **Why structurally allowed:** what in the framework/code/tooling let this go undetected.
       **Prevention:** what catches the next instance (test/lint/gate/doc/learning) — distinct from the fix itself.

     The completion gate (T-1550, G-019) blocks --status work-completed when
     bug-class AND this section is empty/template-only. Use --skip-rca to bypass (logged).
-->

## Evolution

<!-- REQUIRED for arc-tagged build tasks (tags include arc:*). Captures how
     understanding evolved during build — what was learned that wasn't known at
     filing, what in the original plan no longer fits, what triggered pivots
     or new sub-tasks. Mandatory at slice boundaries (when applicable) and
     before --status work-completed.

     Origin: T-1717 grill Q4 — "the understanding of what we need and want
     evolves with the process of materialisation." Structural counter to §ACD:
     spec-vs-build divergence is logged as soon as it happens, not lost as
     folklore.

     Format (one entry per slice boundary or significant insight):
       ### YYYY-MM-DD — [topic]
       - **What changed:** [what we learned that we didn't know at filing]
       - **Plan impact:** [what in the plan no longer fits]
       - **Triggered:** [new sub-task / pivot / scope cut, with task ID if filed]

     The completion gate (T-1718) blocks --status work-completed when this
     section exists but is empty/template-only. Use --skip-evolution to bypass
     (logged Tier-2). Non-arc tasks may leave this empty.
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

## Updates

### 2026-05-14T07:30:21Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1822-fix-project-boundary-cwd-trap--vendored-.md
- **Context:** Initial task creation

### 2026-05-14T07:32:07Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
