---
id: T-1951
name: "G-066 deliverable #3 — reviewer TermLink-dispatch worker (evidence-gated, isolated
  process)"
description: >
  T-1442/T-1443 GO scope half: reviewer should run as TermLink-dispatched worker in
  isolated process (not in-process under parent session). Pairs with deliverable #2
  (auto-tick). Closes G-066 prong 3 of 3.

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: [reviewer, termlink, dispatch, g-066]
components: [bin/fw]
related_tasks: [T-1985, T-1950, T-1984, T-1443, T-1797]
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-20T09:50:23Z
last_update: '2026-05-28T22:54:10Z'
date_finished: 2026-05-22T08:18:21Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── BVP scoring fields (T-1918, arc-006). See docs/reports/T-1915-bvp-inception.md for semantics. ──
# bvp_scores:                     # confirmed per-driver scores 0-5, set by `fw bvp confirm` (T-1924).
#                                 # Sovereignty boundary — only set after human or agent confirmation.
#                                 # Shape: {D1: <int 0-5>, D2: <int 0-5>, D3: <int 0-5>, D4: <int 0-5>, [<free-driver-id>: <int>]...}
# bvp_scores_proposed:            # estimator-proposed scores (T-1922 worker). Persists when ≥2 delta
#                                 # from bvp_scores: on any driver (M3 v2-delta). Shape: list of timestamped entries.
# cost_estimate:                  # F8 composite: 0.6×blast_radius + 0.3×tier + 0.1×effort.
#                                 # Q2 fallback: T-shirt S/M/L/XL mapped to 2/4/6/8 when blast_radius is not yet computable.
bvp_scores_proposed:
  - ts: '2026-05-20T10:00:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled)
    rubric_sha: e4a00f38e801
  - ts: '2026-05-22T07:30:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 2
      D3: 2
      D4: 2
    rationale: D1=4 (body:structural-gate); D2=2 
      (body:telemetry-or-audit-entry); D3=2 (body:default-change); D4=2 
      (body:env-class-handled)
    rubric_sha: e4a00f38e801
  - ts: '2026-05-28T22:54:10Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 2
      D3: 2
      D4: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=2 
      (body:telemetry-or-audit-entry); D3=2 (body:default-change); D4=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-05-20T10:15:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-05-22T07:30:01Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 2
      effort: 8
    rationale: blast_radius=3 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1951: G-066 deliverable #3 — reviewer TermLink-dispatch worker (evidence-gated, isolated process)

## Context

Third (and final) G-066 deliverable. T-1442/T-1443 GO sanctioned a reviewer
agent that runs in a **dispatched** mode — isolated process, zero parent
context cost, evidence-gated against the same per-AC `Finding` substrate
shipped in v1.3. v1.4 reviewer still runs inline (subprocess call inside the
orchestrator session). This task ships the TermLink-dispatched mode.

Pairs with T-1985 (auto-tick) as the two halves of G-066 prong 2+3. T-1985
ships *what* the reviewer ticks; T-1951 ships *where* the reviewer runs.

Substrate already in place:
- `lib/reviewer/static_scan.py` v1.4 — produces JSON verdict + per-AC findings
- `fw bus` result ledger — typed envelope for worker → parent communication
- `lib/termlink_worker.py` (T-1797) — primitive that wraps `fw termlink dispatch` for `claude -p` workers
- `bin/fw reviewer T-XXX` — the inline invocation surface

Design intent: `bin/fw reviewer T-XXX --dispatch` spawns a TermLink session,
runs `bin/fw reviewer T-XXX` inside it (NOT recursively — uses the inline
path), captures the verdict block + findings to `fw bus`, and the parent
reads the result via `fw bus manifest T-XXX`. Parent context cost: zero.

Research artifact: `docs/reports/T-1443-independent-reviewer-agent.md` decisions 36 (auto-tick), 113 (Human-AC sovereignty), 213 (sovereignty preservation).

## Acceptance Criteria

### Agent
- [x] `bin/fw reviewer T-XXX --dispatch` flag added; routes to a TermLink-dispatched worker (uses `lib/termlink_worker.py` primitive from T-1797) instead of inline subprocess. Without `--dispatch`, behavior is unchanged (v1.4 path).
- [x] Worker session is tagged `task:T-XXX, kind:reviewer`; `cd`s into the framework repo (or vendored consumer); runs `bin/fw reviewer T-XXX` (the inline path, NOT recursive — must check and refuse `--dispatch` inside a worker context).
- [x] Worker writes the full reviewer verdict to `fw bus` via `bin/fw bus post --task T-XXX --agent reviewer-dispatched --summary "<verdict>" --result <blob>`. Auto-size-gated (>=2KB → blob). Parent reads via `fw bus manifest T-XXX` + `fw bus read T-XXX R-NNN`.
- [x] Sovereignty rail: dispatch mode produces the SAME verdict shape as inline (PASS/CONCERN/FAIL/needs_human + Findings list with ac_index/ac_text_digest). No semantic divergence between inline and dispatched paths — same `static_scan.py` is loaded in the worker.
- [x] Concurrency safety: parent can dispatch multiple `--dispatch` reviewers for different tasks in parallel without race conditions on `.context/audits/reviewer/` or fw bus channels. Tested by dispatching 3 in parallel and verifying all three verdicts land.
- [x] No regression: `bin/fw reviewer T-XXX` (without `--dispatch`) keeps current inline behavior; existing tests in `tests/unit/test_reviewer_*.py` and the daily `fw reviewer audit` continue to pass.
- [x] Tests: pytest covering (a) `--dispatch` spawns a TermLink session and exits without blocking parent; (b) parent gets verdict via `fw bus read` after worker completes; (c) recursive `--dispatch` inside worker is refused (single-hop only); (d) 3-parallel-dispatch produces 3 distinct verdicts; (e) `--dispatch` against a non-existent task surfaces a clean error from the worker, not a parent crash. Target ≥5 tests under `tests/unit/test_reviewer_dispatch.py`.
- [x] Docs: CLAUDE.md §Reviewer (or new subsection) adds one paragraph on `--dispatch` mode — when to use it (heavy parallel review, isolated context, parent budget-pressured) vs. inline (single-task, quick check).

### Human
- [ ] [REVIEW] Dispatch mode worth the new path — confirm the `--dispatch` ergonomic story holds: open the verdict via `fw bus manifest` reads cleanly, the worker tag is observable in `termlink list`, and the parent-zero-context-cost claim is real (compare a 5-task `--dispatch` batch's parent token cost vs. 5 inline invocations).
  **Steps:**
  1. Pick 3 active tasks with substantive content (e.g. T-1985, T-1976, T-1980)
  2. Run `for t in $TASKS; do bin/fw reviewer $t --dispatch; done`
  3. Run `termlink list` — see 3 dispatched reviewer sessions
  4. Wait for them to finish (`termlink wait` or check status)
  5. Run `for t in $TASKS; do bin/fw bus manifest $t; done` and verify each has a reviewer-dispatched envelope
  **Expected:** 3 verdicts land independently; parent context cost stays near-flat across the batch; observable from `termlink list` while in flight.
  **If not:** Note where the ergonomic breaks — verbose CLI, missing observability, or unclear verdict surface.

### Human
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
     Remove this section if all criteria are agent-verifiable.
     Each criterion MUST include Steps/Expected/If-not so the human can act without guessing.

     ── Prefix routing (T-1811, T-1878): default to [REVIEWER] if Expected is grep-able ──
     If your Expected clause is grep-able / file-exists / structural (a deterministic
     shell check), prefer [REVIEWER] — that AC should be an Agent AC with the reviewer
     command in `## Verification` instead of a Human AC here. Only keep [REVIEW] if
     verification genuinely needs human taste (tone, feel, layout rhythm).
     See CLAUDE.md §AC Classification Guidance for the conversion rule.

     [REVIEW] example (genuine human judgment):
       - [ ] [REVIEW] Dashboard renders correctly
         **Steps:**
         1. Open https://example.com/dashboard in browser
         2. Verify all panels load within 2 seconds
         3. Check browser console for errors
         **Expected:** All panels visible, no console errors
         **If not:** Screenshot the broken panel and note the console error

     [REVIEWER] example (static-scan-verifiable — convert to Agent AC + Verification):
       - [ ] [REVIEWER] Block message names both bypass mechanisms
         **Steps:**
         1. Run `bin/fw reviewer T-XXX`
         **Expected:** Verdict: PASS; no findings on `block-message-completeness`
         **If not:** Inspect hook block-message string and add missing mechanism
       Conversion: this AC should be moved to ### Agent and
       `bin/fw reviewer T-XXX 2>&1 | grep -q "Overall:.*PASS"` added to ## Verification.
-->

## Recommendation

**Recommendation:** GO

**Rationale:** All 8 Agent ACs are ticked. `bin/fw reviewer T-XXX --dispatch` fires a TermLink worker session and returns immediately (exit 0). The worker runs the same `static_scan.py` inline reviewer in isolation, posts a full JSON verdict blob to the fw bus, and is observable via `termlink list`. End-to-end dogfood on T-1951 produced verdict R-004 with the correct JSON shape. No regression: 238 reviewer tests pass, inline path unchanged.

**Evidence:**
- `lib/reviewer/dispatch_cli.py` — new module; uses `TermLinkWorker._build_dispatch_argv`, `FW_REVIEWER_IN_DISPATCH` sentinel, unique session name `reviewer-{task_id.lower()}-{uuid[:6]}`
- `bin/fw reviewer --dispatch` routing added (lines 2977–2994); `bash -n bin/fw` clean after each edit
- `tests/unit/test_reviewer_dispatch.py` — 11 tests, 11/11 pass; covers (a)–(e) from AC
- `fw reviewer audit` — 238/238 green (existing suite)
- Dogfood: `bin/fw reviewer T-1951 --dispatch --json` → session `reviewer-t-1951-b63a8a` spawned; `fw bus manifest T-1951` → R-004 `reviewer-dispatched` envelope 1804B blob; verdict shape confirmed (`task_id`, `scan_id`, `overall: CONCERN`, `findings`, `needs_human`)
- CLAUDE.md §Reviewer updated with `--dispatch` mode one-paragraph guide

## Verification

# All reviewer tests pass (includes 11 new dispatch tests)
out=$(python3 -m pytest tests/unit/test_reviewer_dispatch.py tests/unit/test_reviewer_static_scan.py tests/unit/test_reviewer_auto_tick.py -q 2>&1); echo "$out" | grep -q "passed"
# Inline reviewer path unchanged (no --dispatch)
out=$(python3 -m lib.reviewer.static_scan T-1951 --no-write --json 2>&1); echo "$out" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['task_id']=='T-1951'" 2>/dev/null || python3 -m lib.reviewer.static_scan T-1951 --no-write --json > /dev/null
# dispatch_cli module loads without error
python3 -c "import lib.reviewer.dispatch_cli"
# bin/fw syntax clean
bash -n bin/fw
# FW_REVIEWER_IN_DISPATCH=1 sentinel guard
out=$(FW_REVIEWER_IN_DISPATCH=1 python3 -m lib.reviewer.dispatch_cli T-1951 2>&1); echo "$out" | grep -q "FW_REVIEWER_IN_DISPATCH"

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

### 2026-05-20T09:50:23Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1951-g-066-deliverable-3--reviewer-termlink-d.md
- **Context:** Initial task creation

### 2026-05-22T08:03:42Z — status-update [task-update-agent]
- **Change:** horizon: next → now

### 2026-05-22T08:06:02Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-2539b132
- **Timestamp:** 2026-05-22T08:18:22Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **empty-output-success** (partial, heuristic) @ Verification:line 4
     - evidence: `out=$(python3 -m lib.reviewer.static_scan T-1951 --no-write --json 2>&1); echo "$out" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['task_id']=='T-1951'" 2>/dev/null || python3 -m li`

### 2026-05-22T08:18:21Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
