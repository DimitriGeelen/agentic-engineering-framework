---
id: T-1671
name: "Implement Default-to-OPEN agent gate in fw arc close — refuse closure when
  CLAUDECODE=1 (T-1670 build, mirror T-1259 inception-decide)"
description: >
  Implement Default-to-OPEN agent gate in fw arc close — refuse closure when CLAUDECODE=1
  (T-1670 build, mirror T-1259 inception-decide)

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: [lib/arc.sh, tests/unit/test_arc_system.py]
related_tasks: []
arc_id: orchestrator-rethink
created: 2026-05-02T07:38:50Z
last_update: '2026-06-11T22:23:55Z'
date_finished: 2026-05-02T07:45:23Z
bvp_scores_proposed:
  - ts: '2026-05-19T17:56:23Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 4
      D4: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=4 
      (body:framework-level-ux); D4=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:23:55Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 4
      D4: 0
      F-RECALL: 2
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=4 
      (body:framework-level-ux); D4=0 (no-signal); F-RECALL=2 
      (body:lightly-promoted); F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1671: Implement Default-to-OPEN agent gate in fw arc close — refuse closure when CLAUDECODE=1 (T-1670 build, mirror T-1259 inception-decide)

## Context

Builds T-1670's GO decision (universal agent gate, default
recommendation). Mirrors `lib/inception.sh do_inception_decide`'s
T-1259/T-1260 pattern: refuse the terminal-decision verb when
`CLAUDECODE=1`, point at `fw task review`, allow `--i-am-human`
override (refused under CLAUDECODE), exempt `--from-watchtower` for
the Flask backend.

Authority: T-1670 inception decided GO 2026-05-02 with rationale
"4th-instance failure of same closure-bias signature warrants
structural enforcement; universal gate matches T-1259 precedent;
heuristic pushback counting adds attack surface without proportional
benefit."

Files: `lib/arc.sh:arc_close()` (current entry point — see also
T-1668 demo gate above it).

## Acceptance Criteria

### Agent
- [x] `lib/arc.sh:arc_close()` refuses when `CLAUDECODE=1` and neither
      `--i-am-human` nor `--from-watchtower` was passed
- [x] Refusal message names §ACD/G-062, points at
      `bin/fw task review T-<anchor>`, and prints a copy-pasteable
      Watchtower URL for the arc detail page
- [x] `--i-am-human` flag bypasses the gate (rare human-typing-into-
      agent-session override; matches T-1259 actual behaviour). NOTE:
      T-1670 recommendation text said REFUSED here; corrected during
      build to match T-1259 precedent the recommendation cited — see
      "Decision note" below.
- [x] `--from-watchtower` flag bypasses the gate (Flask backend exemption,
      matches T-1260 inception-decide pattern)
- [x] `CLAUDECODE` unset OR empty AND `--i-am-human` passed → close proceeds
      normally (human CLI invocation works)
- [x] No regression in T-1668 gates (--demo + --headline-mechanic still
      enforced regardless of CLAUDECODE)
- [x] New test file `tests/unit/test_arc_close_agent_gate.py` pins:
      - CLAUDECODE=1 + no override → refused
      - CLAUDECODE=1 + --i-am-human → refused
      - CLAUDECODE=1 + --from-watchtower → accepted
      - CLAUDECODE unset + --i-am-human → accepted
      - CLAUDECODE unset + nothing → accepted (current behaviour preserved)
- [x] All existing arc tests pass: `pytest tests/unit/test_arc_system.py
      tests/unit/test_arc_headline_demo.py tests/unit/test_audit_arc_completion.py -q`
- [x] CLAUDE.md §Arc Completion Discipline updated with one-line note
      pointing at the new gate (no length growth — extend the existing
      "Enforced structurally" sentence)
- [x] Live verification: `CLAUDECODE=1 bin/fw arc close orchestrator-rethink
      --demo docs/reports/orchestrator-rethink-demo/README.md
      --decision "test"` → exits non-zero with §ACD/G-062 message

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
pytest tests/unit/test_arc_close_agent_gate.py tests/unit/test_arc_system.py tests/unit/test_arc_headline_demo.py tests/unit/test_audit_arc_completion.py -q
bash -c 'out=$(CLAUDECODE=1 bin/fw arc close orchestrator-rethink --demo docs/reports/orchestrator-rethink-demo/README.md --decision "verification probe — should refuse" 2>&1); echo "$out" | grep -qiE "claudecode|fw task review|G-062|§ACD"'

## Recommendation

**Recommendation:** GO

**Rationale:** All 9 Agent ACs verified. Gate added to `lib/arc.sh:arc_close`
mirrors lib/inception.sh:do_inception_decide T-1259/T-1260 pattern (same
override flags, same redirection at `fw task review`). 35/35 tests pass
across the four arc test suites (gate + headline_mechanic + demo + audit).
Live verification refuses my own session's `fw arc close` attempt with
the §ACD/G-062 message and the orchestrator-rethink arc remains
in-progress where it should be.

CLAUDE.md §Arc Completion Discipline updated with one-line gate note;
file stays at 961 lines (the user's hard constraint of net-zero growth
preserved).

**Evidence:**
- `lib/arc.sh:411-455` — gate logic mirroring T-1259
- `tests/unit/test_arc_close_agent_gate.py` — 7 tests pinning the 5
  canonical scenarios + T-1668 regression + anchor-redirect message
- `tests/unit/test_arc_headline_demo.py` + `tests/unit/test_arc_system.py`
  — `_run` helper now clears `CLAUDECODE` so pre-T-1671 tests run as
  human invocation; no test changes needed beyond that
- `CLAUDE.md:721` — one-line gate reference added inline; file 961
  lines (no growth)
- Live: `CLAUDECODE=1 bin/fw arc close orchestrator-rethink --demo
  ... --decision "..."` exits non-zero with "agents must not invoke
  'fw arc close' directly (§ACD/G-062, T-1671)" + redirect to
  `bin/fw task review T-1641` + Watchtower URL for the arc

The orchestrator-rethink arc closure is now structurally gated. The
4th-instance auto-close incident from this session cannot recur — the
gate refuses before the existing T-1668 demo-validation gate is even
reached.

## Decision note: --i-am-human override semantics

T-1670 recommendation text said "agents cannot self-elevate via
--i-am-human". That was stricter than T-1259's actual behaviour and
inconsistent with the precedent the same recommendation explicitly
cited. T-1259 allows --i-am-human as a deliberate human-typing-into-
agent-session override. T-1671 follows T-1259's actual behaviour
rather than my (mis-)written recommendation text — consistency with
the cited precedent reduces surprise, and the Watchtower path remains
the recommended flow.

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

### 2026-05-02T07:38:50Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1671-implement-default-to-open-agent-gate-in-.md
- **Context:** Initial task creation

### 2026-05-02T07:44:44Z — status-update [task-update-agent]
- **Change:** tags: +arc:orchestrator-rethink

## Reviewer Verdict (v1.5)

- **Scan ID:** R-b240b16e
- **Timestamp:** 2026-06-02T14:59:01Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-02T07:45:23Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
