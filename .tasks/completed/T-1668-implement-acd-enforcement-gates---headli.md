---
id: T-1668
name: "Implement §ACD enforcement gates: --headline-mechanic at create, --demo at close, CLAUDE.md §ACD compression"
description: >
  Implement §ACD enforcement gates: --headline-mechanic at create, --demo at close, CLAUDE.md §ACD compression

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [C-004, lib/arc.sh, tests/unit/test_arc_system.py, tests/unit/test_audit_arc_completion.py]
related_tasks: []
arc_id: orchestrator-rethink
created: 2026-05-02T06:11:31Z
last_update: 2026-05-02T07:28:58Z
date_finished: 2026-05-02T07:18:01Z
---

# T-1668: Implement §ACD enforcement gates: --headline-mechanic at create, --demo at close, CLAUDE.md §ACD compression

## Context

Implements all three layers of T-1667 remediation as one PR:
- Layer A: `fw arc create --headline-mechanic` (definition-time gate, substrate denylist)
- Layer B: `fw arc close --demo <path|url>` (closure-time gate, mechanical content check)
- Layer C: §ACD compression in CLAUDE.md (24 → ~12 lines, points at the gates)

Authority: T-1667 inception research dispatched 3 agents that converged on this
mechanism. User authorised "all-three together as one PR" (option 2).

Reports: `docs/reports/T-1667-angle-{1,2,3}-*.md`

## Acceptance Criteria

### Agent
- [x] `fw arc create` refuses without `--headline-mechanic` (clear error message)
- [x] `fw arc create --headline-mechanic` refuses substrate-only phrasing (denylist + missing user-action verb)
- [x] `fw arc create --headline-mechanic "<valid>"` writes `headline_mechanic:` field into arc YAML
- [x] `fw arc close` refuses without `--demo` (clear error pointing at §ACD)
- [x] `fw arc close --demo <path>` validates: file exists, ≥256 bytes, extension allowlist, contains arc id or constituent task id
- [x] `fw arc close --demo <url>` validates: HEAD 2xx, body contains arc id within first 32KB
- [x] `fw arc close --demo none --justification "..."` logs to `.context/audits/arc-bypass.jsonl` and proceeds
- [x] `fw arc close` writes `demo_evidence:` field into arc YAML
- [x] `.context/arcs/orchestrator-rethink.yaml` backfilled with `headline_mechanic` describing actual deliverable
- [x] CLAUDE.md §ACD section (lines 715-738, 24 lines) compressed to ≤14 lines with pointer to gates (net negative)
- [x] CLAUDE.md total line count strictly decreases (verify: `wc -l CLAUDE.md` < 976)
- [x] All existing arc tests pass: `pytest tests/unit/test_arc_system.py tests/unit/test_audit_arc_completion.py tests/unit/test_arcs_routes.py -q`
- [x] New tests pin the gates: `pytest tests/unit/test_arc_headline_demo.py -q` (all pass)

### Human
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
     Remove this section if all criteria are agent-verifiable.
     Each criterion MUST include Steps/Expected/If-not so the human can act without guessing.
     Optionally prefix with [RUBBER-STAMP] or [REVIEW] for prioritization.
     Example:
       - [x] [REVIEW] Dashboard renders correctly
         **Steps:**
         1. Open https://example.com/dashboard in browser
         2. Verify all panels load within 2 seconds
         3. Check browser console for errors
         **Expected:** All panels visible, no console errors
         **If not:** Screenshot the broken panel and note the console error
-->

## Verification

bash -n lib/arc.sh
test "$(wc -l < CLAUDE.md)" -lt 976
pytest tests/unit/test_arc_system.py tests/unit/test_audit_arc_completion.py -q
pytest tests/unit/test_arc_headline_demo.py -q
grep -q "^headline_mechanic:" .context/arcs/orchestrator-rethink.yaml

## Recommendation

**Recommendation:** GO

**Rationale:** All Agent ACs verified. Both gates fire correctly on the live
orchestrator-rethink arc — `fw arc close orchestrator-rethink --decision "..."`
is structurally refused without `--demo`, and the gate's error message prints
the arc's `headline_mechanic` so the agent knows what evidence is required.
CLAUDE.md compressed net-negative (976 → 961). 28/28 arc tests pass.

**Evidence:**
- Commit `8a31c99c7` — implementation
- Commit `b35111fa3` — T-1667 inception research that motivated the design
- Live demo: `bin/fw arc close orchestrator-rethink --decision "test"` → refuses with §ACD/G-062 message + prints headline_mechanic (verified post-push)
- `lib/arc.sh:84-180` — validators
- `tests/unit/test_arc_headline_demo.py` — 13 tests pinning all paths
- `CLAUDE.md:715-723` — §ACD compressed (24 → 9 lines)
- `.context/arcs/orchestrator-rethink.yaml:7` — backfilled headline_mechanic
- `docs/reports/T-1667-angle-{1,2,3}-*.md` — convergent 3-agent research

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

### 2026-05-02T06:11:31Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1668-implement-acd-enforcement-gates---headli.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-66a437d4
- **Timestamp:** 2026-06-02T14:59:00Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#7 (Agent)** — `fw arc close --demo none --justification "..."` logs to `.context/audits/arc-bypass.jsonl` and proceeds
  - **AC-verify-mismatch** (narrow, heuristic) — `path=context/audits/arc-bypass.jsonl in: `fw arc close --demo none --justification "..."` logs to `.context/audits/arc-bypass.jsonl` and proceeds`
### 2026-05-02T07:18:01Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

### 2026-05-02T07:28:58Z — status-update [task-update-agent]
- **Change:** tags: +arc:orchestrator-rethink
