---
id: T-1657
name: "G-062 mechanism #3: fw task review extra gate — interactive three-question check for arc-parent tasks"
description: >
  Preventive half of G-062 closure. fw task review for arc-parent tasks (umbrella tasks tagged arc-parent or having related_tasks > 3 children) emits an interactive prompt asking the three questions from CLAUDE.md §Arc Completion Discipline — wire-level observation, constants audit, framework-side use evidence — before opening the Watchtower review URL. Pairs with mechanism #2. T-1655 shipped mechanism #1 (text).

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [C-004, tests/unit/test_audit_arc_completion.py]
related_tasks: []
arc_id: orchestrator-rethink
created: 2026-05-01T16:39:23Z
last_update: 2026-05-01T19:17:07Z
date_finished: 2026-05-01T19:17:07Z
---

# T-1657: G-062 mechanism #3: fw task review extra gate — interactive three-question check for arc-parent tasks

## Context

G-062 closure leg #3: preventive prompt at review time. Pairs with T-1655 (CLAUDE.md
§Arc Completion Discipline) and T-1656 (audit detective). When `fw task review T-XXX`
is invoked on an arc-parent task, print the three-question check before the
Watchtower URL — last chance for the agent to confirm wire-level/constants/
framework-use evidence is in hand.

## Acceptance Criteria

### Agent
- [x] AC1 — `lib/review.sh` exposes a function `_arc_parent_gate` called from `emit_review` that detects arc-parent status and prints the three questions
- [x] AC2 — Detection: task is anchor_task of an in-progress arc (via `.context/arcs/*.yaml`) OR has explicit `arc-parent` tag in frontmatter
- [x] AC3 — When detected, banner with three §Arc Completion Discipline questions is printed BEFORE the Watchtower URL block emitted by `emit_review`
- [x] AC4 — Non-arc-parent tasks see no banner (zero noise on regular review flow)
- [x] AC5 — Unit test `tests/unit/test_arc_parent_review_gate.py` covers: anchor-task case, arc-parent-tag case, regular task case, anchor of closed arc (no banner). 4/4 pass.
- [x] AC6 — Live: `bin/fw task review T-1641` (anchor of orchestrator-rethink) emits the banner

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

bin/fw task review T-1641 > /tmp/T-1657-arc-banner.out 2>&1; grep -qE "ARC COMPLETION CHECK" /tmp/T-1657-arc-banner.out
python3 -m pytest tests/unit/test_arc_parent_review_gate.py -q
bash -n lib/review.sh

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# The completion gate runs each command — if any exits non-zero, completion is blocked.
#
# Toolchain hint (L-291): if you edited *.vbproj/*.csproj/*.xaml add `dotnet build`;
# *.go → `go build ./...`; Cargo.toml → `cargo check`; tsconfig.json → `tsc --noEmit`;
# pom.xml → `mvn -q compile`. P-011 runs only what you write — broken builds slip
# past otherwise (origin: 003-NTB-ATC-Plugin T-077, broken WPF DLL on master 5 days).

## Recommendation

- **Recommendation:** GO (no Human ACs — purely structural)
- **Rationale:** With T-1655 (text rule) and T-1656 (audit detective) shipped, the missing leg of G-062 is the *preventive* prompt at the moment of review. This task adds `_arc_parent_gate` to `lib/review.sh` that prints the three §Arc Completion Discipline questions whenever `fw task review T-XXX` runs against an arc anchor or arc-parent-tagged task. The agent and human both see the questions before the URL — the agent gets a last visible reminder to verify wire-level/constants/framework-use evidence is in hand, and the human sees the same checklist before clicking GO. Non-blocking by design (banner only, no interactive prompt) — matches the philosophy that the rule lives in §Arc Completion Discipline, the gate exists to surface it.
- **Evidence:**
  - `bin/fw task review T-1641` (anchor of orchestrator-rethink) emits the banner with `arc: orchestrator-rethink` + three questions before the Watchtower URL.
  - `bin/fw task review T-1659` (regular task, not an anchor) does NOT emit the banner.
  - `python3 -m pytest tests/unit/test_arc_parent_review_gate.py -q` → 4/4 pass (anchor / tag / regular / closed-arc).
  - All three G-062 mechanisms now in place: behavioral (#1), detective (#2), preventive (#3).

**G-062 status:** ready to move from `partial-mitigation` → `mitigated` (separate concerns.yaml update).

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

### 2026-05-01T16:39:23Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1657-g-062-mechanism-3-fw-task-review-extra-g.md
- **Context:** Initial task creation

### 2026-05-01T16:39:41Z — status-update [task-update-agent]
- **Change:** horizon: now → later
- **Change:** status: started-work → captured (auto-sync)

### 2026-05-01T19:09:43Z — status-update [task-update-agent]
- **Change:** tags: +arc:orchestrator-rethink

### 2026-05-01T19:14:34Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: later → now (auto-sync)

### 2026-05-01T19:14:51Z — status-update [task-update-agent]
- **Change:** horizon: now → now

## Reviewer Verdict (v1.4)

- **Scan ID:** R-293407ac
- **Timestamp:** 2026-05-01T19:17:09Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-05-01T19:17:07Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
