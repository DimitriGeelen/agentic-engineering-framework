---
id: T-2586
name: "designer-corpus v2: cross-process off-page handoffs (make T-2571 seam observable
  in corpus)"
description: >
  designer-corpus v2: cross-process off-page handoffs (make T-2571 seam observable
  in corpus)

status: work-completed
workflow_type: build
owner: human
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
created: 2026-07-21T08:44:09Z
last_update: 2026-07-21T08:52:32Z
date_finished: 2026-07-21T08:52:32Z
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
cost_estimate_proposed:
  - ts: '2026-07-21T08:45:05Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-07-21T08:45:08Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=2 
      (body:telemetry-or-audit-entry); D3=2 (body:default-change); D4=2 
      (body:env-class-handled); F-RECALL=0 (no-signal); F-AUTONOMY=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2586: designer-corpus v2: cross-process off-page handoffs (make T-2571 seam observable in corpus)

## Context

Follow-up to T-2584 RCA: the T-2571 off-page seam works end-to-end but is invisible because no corpus diagram contains a single handoff. Fix = draft v2 of the two flagship corpus diagrams with the semantically-real cross-process handoffs, pair-draft style (agent drafts, operator reviews — same loop as D1-D5 v1):

- **aef-task-lifecycle v2:** the dispatch step hands off to the dispatch loop → `Handoff → aef-dispatch-loop` (resolved target; compile resolves silently per T-2570)
- **aef-inception-flow v2:** GO decision mints build tasks that enter the task lifecycle → `Handoff → aef-task-lifecycle`

Resolved targets only (no ghosts) — the operator's double-click jump then works corpus-to-corpus, which is the observable payoff. Remaining diagrams (session-lifecycle, audit-cron → task-lifecycle) follow in a later slice after operator confirms the v2 shape.

## Acceptance Criteria

### Agent
- [x] aef-task-lifecycle v2.bpmn adds an intermediateThrowEvent with `aef:link targetWorkflow="aef-dispatch-loop"` wired into the flow at the dispatch step; meta.json bumps latest to 2 with a pair-draft note (node `agt_9_handoff_dispatch`, flow `tl_f13` from `agt_3_work`)
- [x] aef-inception-flow v2.bpmn adds an intermediateThrowEvent with `aef:link targetWorkflow="aef-task-lifecycle"` wired after the GO branch; meta.json bumps latest to 2 with a pair-draft note (node `agt_8_handoff_tl`, flow `if_f9` from `agt_4_children`)
- [x] `bin/fw bpmn compile` on both v2 files exits 0 and both handoff targets RESOLVE (no dangling/ghost WARN); the legacy-slug migrate ADVISORY carrying the live uuid is the correct T-2576 output for 0.3.0-editor-shape content and is expected (workflowRef now would be silently stripped on the operator's next 0.3.0 editor save — see Decisions). Verified: task-lifecycle advisory carries `workflowRef="e32a518c-…"` (dispatch-loop's live uuid)
- [x] Registry rescan shows no new ghosts (resolved refs must not ghost) — registry after both compiles: only the pre-existing t2584-ghost-target/T-2585
- [x] Live: /designer opens each v2 (latest) and the handoff node's "↗ Open target workflow" opens the target (Playwright vs :3001 at 1600×1000: task-lifecycle → `workflow:aef-dispatch-loop`; inception-flow → `workflow:aef-task-lifecycle`). Note: node-click hit-testing is unreliable in a sub-400px viewport (tiny circles) — test-harness caveat, not a product defect

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

- [ ] [REVIEW] The v2 handoff placement matches how you think the processes actually connect (pair-draft loop: correct in the UI or note what to change)
  **Steps:**
  ⚠ On opening /designer the canvas shows your LAST LOCAL DRAFT (the 0.3.0 bundle silently restores browser autosave — a "Restored your unsaved work" toast flashes bottom-center). That draft can be an old copy of a corpus diagram under the same title, WITHOUT the new handoff nodes. Ignore the initial canvas; step 1's "📂 Open project…" always fetches the server's latest saved version. (Found 2026-07-21 investigating "still not working" — defect reported upstream to 832.)
  1. Open http://192.168.10.107:3001/designer, click "📂 Open project…", open `aef-task-lifecycle` (opens v2)
  2. Find the "Handoff → dispatch loop" node branching off the work step; click it, then click "↗ Open target workflow" — it should open `aef-dispatch-loop`
  3. Re-open the project browser, open `aef-inception-flow` (v2); find "Handoff → task lifecycle" after the file-build-children step; jump the same way — it should open `aef-task-lifecycle`
  **Expected:** both handoffs sit at the semantically right point and the jump lands on the workflow you'd expect; this is the off-page connector mechanic working corpus-to-corpus
  **If not:** correct the node placement/wiring directly in the designer and Save to project (creates v3) — or note what's wrong and the agent re-drafts; session-lifecycle and audit-cron handoffs follow in the next slice once the shape is confirmed

## Verification

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
#
# Single pipe only — no intermediate tail/awk/sed stages between capture and grep
# (T-2090): `echo "$out" | tail -3 | grep -q PAT` re-introduces the SIGPIPE risk
# the capture step closed off — the middle stage is what `grep -q` slams its
# stdin on. `echo "$out"` is small and immediate; grep scans the whole captured
# string anyway, so the tail-3 was cosmetic. Drop it: `echo "$out" | grep -q PAT`.
#
# Enforcement-baseline hint (L-398, T-1886): if you edited `.claude/settings.json`
# (added/removed/reorganised hooks), add `bin/fw enforcement baseline` to your
# Verification block. Otherwise the canonical hash diverges and `fw doctor`
# reports a FAIL ("Enforcement baseline CHANGED") that accumulates silently.
# Origin: T-1849/T-1730/T-1731 each added a legitimate hook without refreshing
# the baseline — FAIL sat for multiple sessions until T-1886 cleaned up.

grep -q 'targetWorkflow="aef-dispatch-loop"' .context/designer/projects/aef-task-lifecycle/v2.bpmn
grep -q 'targetWorkflow="aef-task-lifecycle"' .context/designer/projects/aef-inception-flow/v2.bpmn
python3 -c "import json; m=json.load(open('.context/designer/projects/aef-task-lifecycle/meta.json')); assert m['latest']==2"
python3 -c "import json; m=json.load(open('.context/designer/projects/aef-inception-flow/meta.json')); assert m['latest']==2"
bin/fw bpmn compile .context/designer/projects/aef-task-lifecycle/v2.bpmn >/dev/null 2>&1
bin/fw bpmn compile .context/designer/projects/aef-inception-flow/v2.bpmn >/dev/null 2>&1
out=$(bin/fw bpmn compile .context/designer/projects/aef-task-lifecycle/v2.bpmn 2>&1); echo "$out" | grep -q 'workflowRef="e32a518c'
python3 -c "import yaml; r=yaml.safe_load(open('.context/designer/registry.yaml')); names=[g['name'] for g in (r.get('ghosts') or [])]; assert 'aef-dispatch-loop' not in names and 'aef-task-lifecycle' not in names"
curl -sf "$(bin/fw watchtower url)/api/version?id=aef-task-lifecycle&v=2" | grep -q agt_9_handoff_dispatch
curl -sf "$(bin/fw watchtower url)/api/version?id=aef-inception-flow&v=2" | grep -q agt_8_handoff_tl

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

### 2026-07-21 — legacy targetWorkflow slug, not workflowRef uuid, in v2 drafts
- **Chose:** author the two handoff connectors in the 0.3.0 editor's own shape: `aef:link targetWorkflow="<slug>"` (no `workflowRef`)
- **Why:** the pinned 0.3.0 editor serializes ONLY targetWorkflow/linkId; a hand-added `workflowRef` attribute would be silently stripped the first time the operator opens the diagram and saves v3 — silent data loss in the operator's own edit loop. The compile migrate-advisory (T-2576) then correctly carries the live uuid for the future migration when 832's T-218 build (workflowRef-aware) ships.
- **Rejected:** `workflowRef="<uuid>"` now (round-trip loss through 0.3.0); waiting for 832's editor build (indefinite gate — the operator's "still not working" needs an observable fix now)

### 2026-07-21 — two flagship diagrams first, not all four
- **Chose:** task-lifecycle→dispatch-loop and inception-flow→task-lifecycle only; session-lifecycle and audit-cron handoffs deferred to a follow-up slice
- **Why:** pair-draft discipline — get the operator's confirmation on the handoff shape before propagating it corpus-wide; budget at warn threshold (P-009 Work Proposal Rule: small bounded units)
- **Rejected:** all-four sweep in one slice (larger review surface on an unconfirmed shape)

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Recommendation

**Recommendation:** GO — approve the v2 handoff shape (or correct it in the UI; your edit becomes v3 and is the pair-draft loop working as designed).

**Rationale:** The T-2584 RCA showed the off-page seam works end-to-end but was invisible because no corpus diagram contained a handoff. These two v2 drafts put the mechanic where you'll actually see it: task-lifecycle's work step hands off to the dispatch loop, and inception GO's build children hand off into the task lifecycle. Both targets resolve (no ghosts), compile is clean, and the jump was live-verified in both directions.

**Evidence:**
- `.context/designer/projects/aef-task-lifecycle/v2.bpmn` node `agt_9_handoff_dispatch` → `aef-dispatch-loop`; `aef-inception-flow/v2.bpmn` node `agt_8_handoff_tl` → `aef-task-lifecycle`; both meta.json `latest: 2`
- `fw bpmn compile` rc=0 both; migrate advisory carries dispatch-loop's live uuid `e32a518c-…` (T-2576 designed output for 0.3.0-shape content)
- Registry: zero new ghosts after both compiles
- Playwright live on :3001 (1600×1000): open v2 → click handoff → "↗ Open target workflow" → lands on `workflow:aef-dispatch-loop` / `workflow:aef-task-lifecycle` respectively

## Updates

### 2026-07-21T08:44:09Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2586-designer-corpus-v2-cross-process-off-pag.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-758beecf
- **Timestamp:** 2026-07-21T08:52:34Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 4

**Verification-level findings:**

  1. **empty-output-success** (partial, heuristic) @ Verification:line 36
     - evidence: `bin/fw bpmn compile .context/designer/projects/aef-task-lifecycle/v2.bpmn >/dev/null 2>&1`
  2. **empty-output-success** (partial, heuristic) @ Verification:line 37
     - evidence: `bin/fw bpmn compile .context/designer/projects/aef-inception-flow/v2.bpmn >/dev/null 2>&1`
  3. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 40
     - evidence: `curl -sf "$(bin/fw watchtower url)/api/version?id=aef-task-lifecycle&v=2" | grep -q agt_9_handoff_dispatch`
  4. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 41
     - evidence: `curl -sf "$(bin/fw watchtower url)/api/version?id=aef-inception-flow&v=2" | grep -q agt_8_handoff_tl`

### 2026-07-21T08:52:32Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
