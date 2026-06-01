---
id: T-1864
name: "default task template lacks SIGPIPE-safe Verification hint — L-387 keeps recurring"
description: >
  default task template lacks SIGPIPE-safe Verification hint — L-387 keeps recurring

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: [template, hardening]
components: [.tasks/templates/default.md]
related_tasks: [T-1862, T-1863, T-1838]
created: 2026-05-15T19:44:49Z
last_update: 2026-05-15T19:46:54Z
date_finished: 2026-05-15T19:46:54Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
---

# T-1864: default task template lacks SIGPIPE-safe Verification hint — L-387 keeps recurring

## Context

The `cmd | grep -q` pattern in `## Verification` blocks fails with exit 141
(SIGPIPE) under `set -o pipefail` — which P-011 runs. Captured 4 times in
learnings.yaml (L-302, L-321 cluster, L-387 here from T-1862, and again on
T-1863 today). Each time the agent wrote a fresh `... | grep -q ...` because
the template doesn't show the safe pattern.

The default template's `## Verification` block has a `Toolchain hint (L-291)`
sub-comment but no pipefail/SIGPIPE hint. Adding one redirects future agents
to the safe form before they write a broken verification.

## Acceptance Criteria

### Agent
- [x] `.tasks/templates/default.md`'s `## Verification` block carries an
      "L-387: pipefail/SIGPIPE" hint with the safe pattern shown inline:
      `out=$(cmd 2>&1); echo "$out" | grep -q PATTERN` (not `cmd | grep -q`).
      *(Done — template edited with a 9-line `Pipefail/SIGPIPE hint (L-387)`
      block right after the existing Toolchain hint.)*
- [x] The hint cites the learning ID (`L-387`) so the agent can look up why.
      *(Done — `L-387` appears twice in the template: in the section header
      and in the "captured 4×" attribution line.)*

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# The completion gate runs each command — if any exits non-zero, completion is blocked.
#
out=$(grep -c "L-387" .tasks/templates/default.md); [ "$out" -ge 1 ]
out=$(grep -Fc 'out=$(' .tasks/templates/default.md); [ "$out" -ge 1 ]

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

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-05-15T19:44:49Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1864-default-task-template-lacks-sigpipe-safe.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.4)

- **Scan ID:** R-aa7489ae
- **Timestamp:** 2026-05-15T19:46:55Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-05-15T19:46:54Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
