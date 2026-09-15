---
id: T-3367
name: "tests/unit: importlib.reload(web.config) rebuilds Config, orphaning import-time
  bindings — 10 failures"
description: >
  importlib.reload re-executes a module in place, so sys.modules identity is preserved
  (every module-level guard misses it) but the Config CLASS is rebuilt. web/embeddings.py:29
  did 'from web.config import Config' at import and holds the old class. test_csrf_cookie_scoping.py:45,92
  reloads web.config; test_embed_health (6) and test_incremental_reindex (4) then
  patch the NEW class while the code under test reads the OLD one, so the patch is
  invisible. Collection order does the rest: csrf < embed_health < incremental_reindex.
  Neither L-421 cause covers this: cause 1 is a stale attribute value, cause 2 is
  del sys.modules replacing the module. This is a class inside a module that was never
  deleted. Split from T-3363 whose fixture closes cause 1 only.

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
# demo_target: true               # T-2286: optional — marks task as reserved for an orchestrated demo
#                                 # worker (e.g. arc-010 HM-A dispatches via mcp__fw__work_on). When set,
#                                 # `fw work-on T-XXX` refuses unless --i-am-demo-orchestrator (CLI) or
#                                 # FW_I_AM_DEMO_ORCHESTRATOR=1 (env) is passed. Prevents the parent
#                                 # session from consuming the captured→started-work transition the demo
#                                 # worker expects to drive. Origin OBS-057.
created: 2026-09-15T17:49:09Z
last_update: 2026-09-15T17:52:16Z
date_finished:
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
  - ts: '2026-09-15T17:50:28Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 3
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=3
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-09-15T17:51:03Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=269,acs=4)
    rubric_sha: e4a00f38e801
---

# T-3367: tests/unit: importlib.reload(web.config) rebuilds Config, orphaning import-time bindings — 10 failures

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] **The mechanism is proven by bisection, not by reading.** `test_embed_health.py`
      alone is green; `test_csrf_cookie_scoping.py` + `test_embed_health.py` in that
      order reproduces failures. Both legs recorded with counts. Until this is
      measured, the causal chain in the description is a hypothesis.
- [x] **Class identity is confirmed as the carrier** — a probe shows
      `web.embeddings.Config is not web.config.Config` after the reload, which is
      what distinguishes this from L-421 causes (1) and (2). A fix that works
      without this evidence is a coincidence.
- [x] All 10 victims pass in the contaminator-first ordering that reproduced the
      failure: `test_embed_health.py` (6) and `test_incremental_reindex.py` (4).
- [x] **Control leg:** with the fix neutralised, that same ordering fails again.
      Distinguishes "the fix works" from "the ordering stopped reproducing".
- [ ] **Anti-masking leg:** a full-suite run afterwards still reports the 7 genuine
      standing failures (T-3364, T-3365, T-3326/E, T-2219×3, T-3368). An isolation
      fix must not paper over real reds — T-3363 measured contamination producing a
      false GREEN, so this risk is demonstrated here, not theoretical.
- [x] The fix is **test-side**. `from web.config import Config` in `web/embeddings.py`
      is ordinary Python and not the defect; the defect is a test reloading a module
      other modules bound from. Production code is not altered to accommodate a test.

### Human
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
     Remove this section if all criteria are agent-verifiable.
     Each criterion MUST include Steps/Expected/If-not so the human can act without guessing.

     ── Prefix routing (T-1811, T-1878): default to [REVIEWER] if Expected is grep-able ──
     If your Expected clause is grep-able / file-exists / structural (a deterministic
     shell check), prefer [REVIEWER] — that AC should be an Agent AC with the reviewer
     command in `## Verification`. See CLAUDE.md §AC Classification Guidance.
     Remove this section if all criteria are agent-verifiable. -->

## Measurements

**The hypothesis I started with was wrong, and the bisection AC caught it.** The
description's causal chain named `test_csrf_cookie_scoping` as the contaminator,
derived from reading source. Measured:

```
test_csrf_cookie_scoping.py + test_embed_health.py  ->  28 passed
```

No failure. Had AC 1 not required bisection before fixing, the fix would have
"worked" by coincidence and the real mechanism would have stayed unknown.

**Bisection.** Files 38-75 (alphabetical) reproduce in 72s: 7 failed (6 victims +
the standing `corpus_lint`). Splitting that window in half reproduced *neither*
side — the signature of a multi-party interaction, not a polluter/victim pair.

**Minimal reproducer — three participants, each necessary, none sufficient:**

| Set | `web.embeddings.Config is web.config.Config` | Result |
|---|---|---|
| `chunk_cap` + `csrf` + `embed_health` | **False** | **6 failed** |
| drop `chunk_cap` | True | 29 passed |
| drop `csrf` | True | 35 passed |

The roles:

1. **`tests/unit/test_chunk_cap.py:28`** — `from web import embeddings as E` at
   MODULE level, so at collection, pinning `web/embeddings.py:29`'s
   `from web.config import Config` to the original class.
2. **`tests/unit/test_csrf_cookie_scoping.py:45`** — `importlib.reload(web.config)`
   builds a new `Config` class.
3. **`tests/unit/test_embed_health.py:148,198`** — imports `web.embeddings` LAZILY,
   inside the test function. Its in-function `from web.config import Config`
   resolves to the NEW class; `web.embeddings` still reads the OLD one. The
   monkeypatch is silently inert.

The failure message names the mechanism outright: the test asserts the patched
`http://query-host:1` and gets `http://192.168.10.107:11434` — the real default,
read from the class the patch never touched.

**After the fix:**

| Run | Result |
|---|---|
| minimal repro | `identical=True`, 39 passed |
| window 38-75 | 1 failed (`corpus_lint`, standing / T-3326) — was 7 |
| window 38-75 `--noconftest` (control) | 7 failed |
| `incremental_reindex` triple | `identical=True`, 38 passed |
| same triple `--noconftest` (control) | `identical=False`, 4 failed |

Both control legs fail as required, so the fix is load-bearing and the orderings
still reproduce without it.

## Verification

# T-3367 — all three legs. Control legs assert FAILURE on purpose: without them
# "the fix works" is indistinguishable from "the ordering stopped reproducing".

test -f tests/unit/conftest.py && grep -q "_restore_rebound_class_identity" tests/unit/conftest.py

# Victims green in the ordering that reproduced the failure.
o=$(mktemp); timeout 600 python3 -m pytest tests/unit/test_chunk_cap.py tests/unit/test_csrf_cookie_scoping.py tests/unit/test_embed_health.py tests/unit/test_incremental_reindex.py -q -p no:cacheprovider --color=no > "$o" 2>&1 && grep -q "passed" "$o"

# Control: fix neutralised, same ordering must fail again.
c=$(mktemp); timeout 600 python3 -m pytest --noconftest tests/unit/test_chunk_cap.py tests/unit/test_csrf_cookie_scoping.py tests/unit/test_embed_health.py tests/unit/test_incremental_reindex.py -q -p no:cacheprovider --color=no > "$c" 2>&1; grep -q "failed" "$c"

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

## Recommendation

<!-- T-2945: same shape as inception.md's block — the gate that reads it
     (audit_inception_recommendation, lib/task-audit.sh:117) is shared, so the
     shape is copied rather than reinvented.

     REQUIRED once this task reaches partial-complete: Agent ACs done, at least
     one `### Human` AC still unticked. `lib/review.sh:205-211` (T-2421) BLOCKS
     `fw task review` emission for build/refactor/test/decommission tasks in that
     state with no substantive block here — the operator would otherwise open
     /review/<id> to a blank Recommendation card and be asked to approve a form.

     Not required while every Human AC is ticked or the task has none: the gate
     only fires on the partial-complete transition. It is here from the start so
     you write it while you still have the evidence, not when the gate refuses.

     Format (the parser wants the `**Recommendation:**` line at the start of a
     line; a leading `-` or `*` bullet is also accepted):
     **Recommendation:** GO / NO-GO / DEFER
     **Rationale:** Why (cite evidence — what shipped, what was proven, what remains)
     **Evidence:**
     - Finding 1
     - Finding 2

     DEFER is for evidence gaps, not confidence gaps (CLAUDE.md §Presenting Work
     for Human Review). If the artefact is complete and you still don't want to
     commit, that is a calibration failure — recommend GO or NO-GO.
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

### 2026-09-15T17:49:09Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3367-testsunit-importlibreloadwebconfig-rebui.md
- **Context:** Initial task creation

### 2026-09-15T17:52:16Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
