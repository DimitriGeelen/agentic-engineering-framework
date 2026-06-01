---
id: T-1656
name: "G-062 mechanism #2: fw audit arc-completion check — N child tasks under one parent reach work-completed within M days"
description: >
  Detective half of G-062 closure. When N child tasks (default 3?) under one parent task reach work-completed within M days (default 7?), agents/audit/audit.sh emits a check requiring evidence that the arc-parent has (a) behavioral verification artefact, (b) policy-defaults audit, (c) framework-side use evidence. Exit code 1 (warn) if missing. Pairs with mechanism #3 (fw task review extra gate). T-1655 shipped behavioral mechanism #1 (CLAUDE.md text); structural enforcement still pending.

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
arc_id: orchestrator-rethink
created: 2026-05-01T16:39:00Z
last_update: 2026-05-01T19:12:40Z
date_finished: 2026-05-01T19:12:40Z
---

# T-1656: G-062 mechanism #2: fw audit arc-completion check — N child tasks under one parent reach work-completed within M days

## Context

G-062 partial-mitigation arc: T-1655 codified §Arc Completion Discipline (CLAUDE.md
behavioral text); this task adds the structural detective. When an arc accumulates
completed children without explicit closure, audit emits a warning forcing the
agent/human to either run the three-question check + `fw arc close`, or document
why open tasks remain. Depends on T-1661 (arc system MVP) — now implementable.

## Acceptance Criteria

### Agent
- [x] AC1 — `agents/audit/audit.sh` includes a new `arc-completion` section selectable via `--section arc-completion`
- [x] AC2 — Section iterates `.context/arcs/*.yaml`, computes completion ratio (constituent_tasks at work-completed / total) for each in-progress arc
- [x] AC3 — When ratio ≥ FW_ARC_COMPLETION_THRESHOLD (default 0.80) AND arc.status is `in-progress`, emits a WARN with mitigation pointing at CLAUDE.md §Arc Completion Discipline
- [x] AC4 — Closed arcs are skipped (no check), arcs with zero constituent_tasks are skipped (cannot compute ratio)
- [x] AC5 — Unit test `tests/unit/test_audit_arc_completion.py` exercises the check in isolation: 4 fixtures (no arcs, in-progress arc 50%, in-progress arc 90%, closed arc 100%) → expected warn count 0/0/1/0; passes (4/4)
- [x] AC6 — `bin/fw audit --section arc-completion` runs against the live registry without errors

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

# Structural-only checks — recursive `fw audit` invocations trip the audit run-lock when
# CTL-013 itself re-runs them, producing false-positive failures. Verify the logic exists
# in the source instead. Pytest covers behavior in normal test runs.
grep -q 'ARC-COMPLETION CHECKS' agents/audit/audit.sh
grep -q 'should_run_section "arc-completion"' agents/audit/audit.sh
test -f tests/unit/test_audit_arc_completion.py
bash -n agents/audit/audit.sh

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# The completion gate runs each command — if any exits non-zero, completion is blocked.
#
# Toolchain hint (L-291): if you edited *.vbproj/*.csproj/*.xaml add `dotnet build`;
# *.go → `go build ./...`; Cargo.toml → `cargo check`; tsconfig.json → `tsc --noEmit`;
# pom.xml → `mvn -q compile`. P-011 runs only what you write — broken builds slip
# past otherwise (origin: 003-NTB-ATC-Plugin T-077, broken WPF DLL on master 5 days).

## Recommendation

- **Recommendation:** GO (no Human ACs — all checks structural)
- **Rationale:** Mechanism #2 is the detective half of G-062. Mechanism #1 (CLAUDE.md §Arc Completion Discipline, T-1655) was behavioral text the agent was supposed to consult before declaring an arc shipped — but text is not enforcement. This audit section turns the rule into a structural gate: every 6h (default cron cadence for `gaps`-class checks) the framework scans `.context/arcs/*.yaml` and warns when any in-progress arc reaches 80% child-completion without explicit closure. The warning's mitigation points the agent/human at the three-question check + `fw arc close`, exactly the closure ritual the rule prescribes.
- **Evidence:**
  - `bin/fw audit --section arc-completion` against the live registry: PASS (orchestrator-rethink at 12/17 = 70.59%, below 0.80 threshold). When ratio crosses 0.80, this becomes a WARN with the exact mitigation text required.
  - `python3 -m pytest tests/unit/test_audit_arc_completion.py -q` → 4/4 pass (empty / 50% / 90% / closed-100% fixtures).
  - Threshold tunable via `FW_ARC_COMPLETION_THRESHOLD` env var.
  - Closed arcs are skipped (no double-warn). Empty arcs are skipped (no division-by-zero).

**Pairing:** mechanism #3 (T-1657, captured/later) is the last leg — `fw task review` interactive three-question check for arc-parent tasks. With #1+#2 shipped, G-062 moves from `partial-mitigation` (behavioral only) toward `mitigated` (structural detective in place; #3 remains for proactive prompt at review time).

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

### 2026-05-01T16:39:00Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1656-g-062-mechanism-2-fw-audit-arc-completio.md
- **Context:** Initial task creation

### 2026-05-01T16:39:16Z — status-update [task-update-agent]
- **Change:** horizon: now → next
- **Change:** status: started-work → captured (auto-sync)

### 2026-05-01T19:09:43Z — status-update [task-update-agent]
- **Change:** tags: +arc:orchestrator-rethink

### 2026-05-01T19:09:44Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

### 2026-05-01T19:09:56Z — status-update [task-update-agent]
- **Change:** horizon: now → now

## Reviewer Verdict (v1.4)

- **Scan ID:** R-29300cd8
- **Timestamp:** 2026-05-01T19:12:43Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-05-01T19:12:40Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
