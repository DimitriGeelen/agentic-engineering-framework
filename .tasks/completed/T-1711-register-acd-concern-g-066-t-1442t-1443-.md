---
id: T-1711
name: "Register §ACD concern G-066: T-1442/T-1443 closed with auto-tick + TermLink-dispatch halves never wired"
description: >
  Register §ACD concern G-066: T-1442/T-1443 closed with auto-tick + TermLink-dispatch halves never wired

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: [ACD, G-062-family]
components: []
related_tasks: [T-1442, T-1443, T-1709]
arc_id: orchestrator-rethink
created: 2026-05-04T06:29:50Z
last_update: 2026-05-04T06:35:27Z
date_finished: 2026-05-04T06:35:27Z
---

# T-1711: Register §ACD concern G-066: T-1442/T-1443 closed with auto-tick + TermLink-dispatch halves never wired

## Context

T-1442 (inception, GO) and T-1443 (build, work-completed) reached an explicit GO on three
deliverables:
  1. 3-layer escalation classifier (mechanical patterns + frontmatter risk/human_signoff
     + audit cron Pass-B re-scan).
  2. Reviewer **auto-ticks** Agent ACs from machine-verifiable evidence.
  3. Reviewer **dispatches via TermLink** (evidence-gated, isolated process).

What actually shipped (verified 2026-05-04):
  ✓ Layer 1: `policy/escalation-patterns.yaml` — schema_version: 1, v1.1-seed catalogue
  ✓ Layer 2: `policy/anti-patterns.yaml` — schema_version: 2, v1.3-seed
  ✓ Layer 3: `lib/reviewer/static_scan.py` — Pass-B audit re-scan
  ✗ Auto-tick: NEVER wired. `static_scan.py` ships with explicit guard
    `# Sovereignty: NEVER modifies AC checkboxes (##{2,}Human or ### Agent)`.
  ✗ TermLink-dispatched reviewer: `agents/reviewer/` does not exist; reviewer
    runs in-process under the parent session.

Closure pattern: T-1442 + T-1443 closed `work-completed` with substrate (1) shipped and
deliverables (2)+(3) silently dropped. This is the §ACD substrate-vs-deliverable
conflation that defined the orchestrator-rethink arc — happening at the per-task level,
not the arc level. The §ACD gates added in T-1668/T-1671 (`--headline-mechanic` at create,
`--demo` at close, CLAUDECODE refusal on `fw arc close`) only apply to ARC closures.
A regular `fw task update --status work-completed` against an inception/build task pair
has no equivalent gate.

T-1709 is the proposed wiring fix (awaiting GO/NO-GO/DEFER). This task registers the
gap structurally so it stays visible regardless of T-1709's outcome.

## Acceptance Criteria

### Agent
- [x] G-066 entry added to `.context/project/concerns.yaml` with: title, description
      (3 paragraphs: what GO promised / what shipped / what didn't), spec_reference
      (T-1442, T-1443, CLAUDE.md §ACD), severity (medium), trigger_fired: true,
      trigger_event (this session's verification), status: watching, what_works_now,
      what_remains, recommendation (link to T-1709), created/last_reviewed dates,
      related_task: T-1709.
      **Verified:** entry written at end of concerns.yaml (after G-065). All required
      fields present including the 2-prong recommendation (T-1709 wiring + structural
      task-pair §ACD gate). `related_tasks_extra` cross-links T-1442, T-1443, T-1668,
      T-1671, G-062.
- [x] `python3 -c "import yaml; yaml.safe_load(open('.context/project/concerns.yaml'))"`
      parses clean (regression check).
      **Verified:** parses without exception.
- [x] `bin/fw gaps` lists G-066.
      **Verified:** output shows `G-066 [medium]  T-1442/T-1443 closed work-completed
      while half of GO scope (auto-tick + TermLink-dispatch reviewer) never wired —
      §ACD pattern at task level (G-062 family)`.
- [x] `bin/fw audit` exits without new failures (warnings ok).
      **Verified:** post-add audit run = pass=9, warn=2, fail=0 (same as pre-add).

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

python3 -c "import yaml; yaml.safe_load(open('.context/project/concerns.yaml'))"
grep -q "id: G-066" .context/project/concerns.yaml
bin/fw gaps 2>&1 | grep -q "G-066"
# audit: warnings tolerated, failures not (read latest cron audit yaml).
test "$(grep '^  fail:' .context/audits/cron/LATEST-CRON.yaml | head -1 | awk '{print $2}')" = "0"

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

### 2026-05-04T06:29:50Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1711-register-acd-concern-g-066-t-1442t-1443-.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.4)

- **Scan ID:** R-67dd0330
- **Timestamp:** 2026-05-04T06:35:27Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-05-04T06:35:27Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
