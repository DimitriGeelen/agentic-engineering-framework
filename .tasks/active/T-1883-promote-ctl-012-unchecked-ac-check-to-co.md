---
id: T-1883
name: "Promote CTL-012 unchecked-AC check to compliance section (twin of CTL-028, closes detection-window for AC-drift class)"
description: >
  Promote CTL-012 unchecked-AC check to compliance section (twin of CTL-028, closes detection-window for AC-drift class)

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [arc-grooming, audit, prevention, governance]
components: ["agents/audit/audit.sh", "tests/unit"]
related_tasks: ["T-1882", "T-1846", "T-1687", "T-1870"]
arc_id: arc-grooming
created: 2026-05-17T19:03:53Z
last_update: 2026-05-17T19:03:53Z
date_finished: null
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
---

# T-1883: Promote CTL-012 unchecked-AC check to compliance section (twin of CTL-028, closes detection-window for AC-drift class)

## Context

CTL-012 is the AC-drift symmetric twin of CTL-028: when a completed task lives in
`.tasks/completed/` but has unchecked Agent ACs, P-010 was bypassed (typically by
`git mv` or `--skip-acceptance-criteria`). CTL-028 catches the metadata-side
desync (status != work-completed); CTL-012 catches the AC-side desync.

**Identical detection-window gap as CTL-028:** CTL-012 currently lives in
`oe-daily` section (07:00 cron). Pre-push audit runs
`--section structure,compliance,quality,discovery` — none trigger CTL-012.
Detection window for AC drift can be up to 24h post-ship. T-1882 closed this
window for CTL-028; this task closes it for CTL-012.

**Why CTL-012 belongs in compliance:** it shares the COMPLETED_SCAN dependency
with CTL-028 (already gated by `compliance || oe-daily` after T-1882 — line 466).
Adding CTL-012 to the same gate is near-zero marginal cost (the scan is already
running when compliance fires).

**Origin:** T-1882 sweep (option 2 in S-2026-0517) identified CTL-012 as the
strongest follow-on candidate: same detection class as CTL-028, same scan path,
same blast radius. The pattern is "L-390 detection-window meta-lesson applied
to the symmetric twin."

## Acceptance Criteria

### Agent
- [ ] CTL-012 fires when audit runs with `--section compliance` (currently only fires with `--section oe-daily`)
- [ ] CTL-012 still fires when audit runs with `--section oe-daily` (no regression)
- [ ] `COMPLETED_SCAN` continues to populate when compliance section is requested (T-1882 wiring, no additional change needed)
- [ ] Regression tests added/updated — exercise both code paths (compliance, oe-daily) with synthetic unchecked-AC fixture; all PASS
- [ ] Pre-push audit profile (`--section structure,compliance,quality,discovery`) emits CTL-012 line
- [ ] No new audit warnings/failures on the live tree (regression check)
- [ ] CTL-012 does NOT fire from `--section structure` alone (negative test — gate granularity, mirrors T-1882 test #8)

## Verification
cd /opt/999-Agentic-Engineering-Framework && bats tests/unit/audit_ctl012_compliance_section.bats
# Pipefail-safe per L-387 — capture-then-grep
cd /opt/999-Agentic-Engineering-Framework && out=$(bin/fw audit --section compliance 2>&1); echo "$out" | grep -q "CTL-012"
cd /opt/999-Agentic-Engineering-Framework && out=$(bin/fw audit --section oe-daily 2>&1); echo "$out" | grep -q "CTL-012"
cd /opt/999-Agentic-Engineering-Framework && out=$(bin/fw audit --section structure,compliance,quality,discovery 2>&1); echo "$out" | grep -q "CTL-012"

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# The completion gate runs each command — if any exits non-zero, completion is blocked.
#
# Toolchain hint (L-291): if you edited *.vbproj/*.csproj/*.xaml add `dotnet build`;
# *.go → `go build ./...`; Cargo.toml → `cargo check`; tsconfig.json → `tsc --noEmit`;
# pom.xml → `mvn -q compile`. P-011 runs only what you write — broken builds slip
# past otherwise (origin: 003-NTB-ATC-Plugin T-077, broken WPF DLL on master 5 days).
#
# Pipefail/SIGPIPE hint (L-387): P-011 runs each command under `set -eo pipefail`.
# `cmd | grep -q PATTERN` exits 141 (SIGPIPE) when grep matches and closes stdin
# while the upstream is still writing — verification then "fails" even though
# the pattern was present. Safe pattern: capture first, grep the capture:
#     out=$(cmd 2>&1); echo "$out" | grep -q "PATTERN"
# Or:
#     cmd > /tmp/.out 2>&1 && grep -q "PATTERN" /tmp/.out
# Origin: L-387, captured 4× (T-1716, T-1838, T-1862, T-1863) before this hint.

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

### 2026-05-17T19:03:53Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1883-promote-ctl-012-unchecked-ac-check-to-co.md
- **Context:** Initial task creation
