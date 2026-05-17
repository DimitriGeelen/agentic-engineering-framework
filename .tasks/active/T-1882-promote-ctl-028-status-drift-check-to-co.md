---
id: T-1882
name: "Promote CTL-028 status-drift check to compliance section (pre-push catches before ship)"
description: >
  Promote CTL-028 status-drift check to compliance section (pre-push catches before ship)

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [arc-grooming, audit, prevention, governance]
components: ["agents/audit/audit.sh", "tests/unit"]
related_tasks: ["T-1846", "T-1687", "T-1870", "T-1881"]
arc_id: arc-grooming
created: 2026-05-17T18:25:53Z
last_update: 2026-05-17T18:25:53Z
date_finished: null
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
---

# T-1882: Promote CTL-028 status-drift check to compliance section (pre-push catches before ship)

## Context

CTL-028 (T-1870, L-390) detects tasks moved to `.tasks/completed/` via `git mv` without
running through `fw task update --status work-completed`. It catches the metadata-drift
class where status remains `started-work` despite the file living in `completed/`.

**Gap:** CTL-028 is currently gated by the `oe-daily` section. Pre-push audit runs
`--section structure,compliance,quality,discovery` — none of which trigger CTL-028.
The daily cron at 07:00 catches drift, but the window is up to 24h. A drift can ship
to remote and propagate before detection.

**Origin:** T-1846 was renamed `active/` → `completed/` in commit c15b9b81 (2026-05-15)
without status transition. CTL-028 fired daily WARN starting 2026-05-16 07:00 but the
drift was only spotted today (2026-05-17, ~2 days later) during arc-grooming review.
T-1687 commit 78d00388 fixed the metadata. This task closes the detection-window gap.

**Fix:** promote CTL-028 from `oe-daily` to `compliance` section. Pre-push audit already
includes compliance, so any future `git mv → completed/` without state-machine transition
fails (WARN-level) before push. CTL-028 stays in oe-daily output too (compliance is a
subset trigger).

## Acceptance Criteria

### Agent
- [ ] CTL-028 fires when audit runs with `--section compliance` (currently only fires with `--section oe-daily`)
- [ ] CTL-028 still fires when audit runs with `--section oe-daily` (no regression)
- [ ] `COMPLETED_SCAN` is populated when compliance section is requested (dependency wiring)
- [ ] New bats test `tests/unit/audit_ctl028_compliance_section.bats` exercises both code paths (compliance, oe-daily) against synthetic drift fixture; both PASS
- [ ] Pre-push audit (`bin/fw audit --section structure,compliance,quality,discovery`) emits CTL-028 line in output
- [ ] No new audit warnings/failures introduced on the live tree (regression check)

## Verification
cd /opt/999-Agentic-Engineering-Framework && bats tests/unit/audit_ctl028_compliance_section.bats
# Regression: live audit still passes
cd /opt/999-Agentic-Engineering-Framework && out=$(bin/fw audit --section compliance 2>&1); echo "$out" | grep -q "CTL-028"
cd /opt/999-Agentic-Engineering-Framework && out=$(bin/fw audit --section oe-daily 2>&1); echo "$out" | grep -q "CTL-028"

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

### 2026-05-17T18:25:53Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1882-promote-ctl-028-status-drift-check-to-co.md
- **Context:** Initial task creation
