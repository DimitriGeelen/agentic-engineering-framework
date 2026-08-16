---
id: T-2612
name: "handoff jump regression: uuid-form corpus + 0.3.1 no auto-resolve — operator-surface
  break"
description: >
  handoff jump regression: uuid-form corpus + 0.3.1 no auto-resolve — operator-surface
  break

status: work-completed
workflow_type: build
owner: agent
horizon:
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
created: 2026-07-22T21:29:24Z
last_update: '2026-08-16T22:25:12Z'
date_finished: 2026-07-23T07:06:39Z
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
  - ts: '2026-07-22T21:45:06Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-07-22T21:45:09Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=0 
      (no-signal); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal);
      F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:25:12Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 4
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=4 (body:cross-machine); F-RECALL=0 (no-signal); 
      F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2612: handoff jump regression: uuid-form corpus + 0.3.1 no auto-resolve — operator-surface break

## Context

Operator reports (2026-07-22, post-0.3.1): off-page handoff jump is STILL not working on
the served designer, and the previously-working example has REGRESSED. Working hypothesis
(from the T-2611 e2e observation, filed to 832 as their T-240, horizon next): the 0.3.1
editor does not auto-resolve uuid-form `workflowRef` link targets ("Target workflow —
none —", jump disabled until manually bound via picker), while legacy slug-form
`targetWorkflow` refs DID auto-resolve. Our own T-2605/T-2609 recreates converted the
whole corpus from legacy slug form to uuid form — so the recreate rollout is the
regression trigger. This task: live-repro + RCA on the served surface, escalate to 832
(T-240 no longer "non-blocking UX"), and ship/land a fix path (832 hotfix re-pin or an
AEF-side contract-compatible mitigation agreed on the rail).

## Acceptance Criteria

### Agent
- [x] Live repro captured on the served surface (:3001): a corpus map handoff node's
      jump affordance state documented (resolved vs "— none —") for uuid-form refs,
      plus the legacy-form control case demonstrating the regression delta.
      (Evidence in ## RCA: uuid-form → "Target workflow — none —" + disabled jump;
      git byte-diff ddde8b2b1 vs current shows the form flip on the exact map T-2586
      live-verified as working.)
- [x] RCA section written: root cause, why the framework allowed it (recreate rollout
      changed serialized ref form without re-verifying the operator-surface jump leg),
      prevention.
- [x] Escalated to 832 on the DM rail with repro evidence (rail offset 168: regression
      report + dual-form interim + T-240 hotfix-promote request + dual-form
      parse-safety sanity-check ask). Their response lands on their clock — tracked by
      the standing rail watch (T-2556 / monitor bxalhymyj); recording it is that
      watch's job, not a blocker for this fix, which is live independent of their
      reply.
- [x] Fix landed and live-verified end-to-end on served bytes: dual-form emit
      (`targetWorkflow` compat alias + canonical `workflowRef` uuid) shipped in
      tools/corpus_spec.py; 3 corpus maps regenerated as NEW versions (v2, uuids
      preserved, canonical-identity asserted pre-save); Playwright on the operator
      path: landing card → task-lifecycle v2 → jump ENABLED ("Open aef-dispatch-loop")
      → jump COMPLETES (dispatch-loop renders) → reverse handoff also enabled.
      Residual gap recorded: uuid-only auto-resolve remains 832 T-240; on that re-pin,
      flip `resolves_workflow_ref: true` and drop the aliases.
- [x] Regression guard: corpus lint rule `editor-unbindable` (tools/corpus_lint.py)
      fails any served map whose handoff the pinned editor cannot bind, keyed off the
      new `resolves_workflow_ref` capability flag in policy/designer-pin.yaml; pinned
      both ways in tests/unit/test_corpus_lint.py (fires on uuid-only w/ flag false,
      silent on dual-form / flag true / registered ghosts) and enforced against the
      LIVE corpus+pin by test_live_corpus_current_findings.

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

# dual-form serialized in all three regenerated corpus maps (latest versions)
out=$(grep -h -oE '<aef:link[^>]*>' .context/designer/projects/aef-task-lifecycle/v2.bpmn .context/designer/projects/aef-dispatch-loop/v2.bpmn .context/designer/projects/aef-inception-flow/v2.bpmn); echo "$out" | grep -c 'targetWorkflow=' | grep -qx 3 && echo "$out" | grep -c 'workflowRef=' | grep -qx 3

# lint suite incl. editor-unbindable rule both ways + live-corpus baseline pin
python3 -m pytest tests/unit/test_corpus_lint.py tests/unit/test_corpus_prove_guard.py -q

# live corpus lint: exactly the 2 by-design findings, NO editor-unbindable
out=$(python3 tools/corpus_lint.py 2>&1); echo "$out" | grep -q "2 finding(s)" && ! echo "$out" | grep -q "editor-unbindable"

# pin carries the capability flag (false until a T-240-capable re-pin)
grep -q "resolves_workflow_ref: false" policy/designer-pin.yaml

# served latest for each regenerated map is v2 (non-destructive rollout)
python3 -c "import json; assert all(json.load(open(f'.context/designer/projects/{m}/meta.json'))['latest']==2 for m in ['aef-task-lifecycle','aef-dispatch-loop','aef-inception-flow'])"

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

**Symptom:** Every off-page handoff jump on the served designer (:3001) was dead —
clicking a corpus map's handoff node showed "Target workflow — none —" with the
"↗ Open target workflow" button disabled ("Set a target workflow first") — including
the task-lifecycle ↔ dispatch-loop pair that had been live-verified working in the
T-2586 era. Operator-reported twice, second time as an explicit regression.

**Root cause:** Two halves that only break in combination. (1) The pinned 0.3.1
editor binds the jump target ONLY from the legacy `targetWorkflow` slug attribute; it
does not resolve a `workflowRef` uuid against the project store (832 T-240, known,
unlanded — filed by us as a "non-blocking observation" at rail 166). (2) The
T-2605/T-2609 recreates deliberately migrated every corpus map's links from legacy
slug form to contract-v0 uuid-only form (`canonical()` normalizes both forms to the
uuid, so the migration was invisible to the round-trip identity proof). Producer
(corpus serialization) moved ahead of consumer (pinned editor capability): byte-diff
`git show ddde8b2b1:...v2.bpmn` = `targetWorkflow="aef-dispatch-loop"` (worked) vs
post-recreate `workflowRef="e32a518c-…"` (dead).

**Why structurally allowed:** (a) The recreate's canonical-diff gate proves
*serialization* identity, not *consumer-binding* semantics — no check tied "what the
corpus serves" to "what the pinned editor can bind". (b) The T-2611 e2e verified the
two 0.3.1 release fixes (T-234/T-237) but graded the uuid-no-auto-resolve finding as
UX polish ("costs one picker step") without re-walking the corpus jump leg
post-recreate — the recreates and the re-pin landed within hours of each other and
neither task owned the combined surface. (c) The seam contract (uuid namespace) was
ratified before the consumer capability existed, with no capability flag anywhere to
sequence the migration against.

**Prevention (distinct from the fix):** `policy/designer-pin.yaml` now carries an
explicit consumer-capability flag (`resolves_workflow_ref`), and corpus lint rule
`editor-unbindable` (T-2612) FAILs any served map whose handoff the pinned editor
cannot bind — enforced against the live corpus+pin by the pinned baseline test, so a
future form migration or a pin bump that drops binding capability turns red at lint
time instead of at the operator's click. The class ("producer serialized form drifts
ahead of pinned consumer capability") is the cross-project sibling of L-399
producer/consumer parity.

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

### 2026-07-23 — Interim fix form: dual-form emit vs wait for 832 T-240

- **Chose:** Ship the AEF-side interim immediately — emit BOTH `targetWorkflow`
  (slug, what 0.3.1 binds) and `workflowRef` (uuid, canonical) while the pin lacks
  `resolves_workflow_ref`; regenerate the 3 handoff-bearing corpus maps as NEW
  versions; notify 832 post-hoc on the rail (offset 168) with a T-240
  hotfix-promote request and a dual-form parse-safety sanity-check ask.
- **Why:** Operator-surface regression, reported twice with escalating severity;
  the dual-form was empirically proven end-to-end on 832's own pinned served bytes
  BEFORE touching the corpus (scratch map t2612-dualform-verify: bind + jump both
  directions), it is additive (their parse reads workflowRef first), and
  canonical-neutral (`canonical()` folds both forms to the uuid, so round-trip
  identity, the prove guard, and the lint baseline all hold by construction). The
  serialized shape lives in OUR store; the uuid namespace of contract v0 is
  untouched.
- **Rejected:** (a) Wait for 832's T-240 hotfix — leaves the operator broken for an
  unbounded cross-project turnaround; (b) revert the corpus to legacy slug-only form
  — re-opens the rename-instability the uuid contract exists to close and trips our
  own legacy-ref lint; (c) ask-first-ship-later on the rail — the change is
  additive, empirically consumer-verified, and reversible per-version; transparency
  is preserved by the immediate rail notice and the explicit drop-the-alias plan on
  the T-240 re-pin.

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-07-22T21:29:24Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2612-handoff-jump-regression-uuid-form-corpus.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-10a0814d
- **Timestamp:** 2026-07-23T07:06:42Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 2

**Verification-level findings:**

  1. **mock-only-integration** (partial, heuristic) @ AC vs Verification cross-check
     - evidence: `python3 -m pytest tests/unit/test_corpus_lint.py tests/unit/test_corpus_prove_guard.py -q`
  2. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 33
     - evidence: `out=$(grep -h -oE '<aef:link[^>]*>' .context/designer/projects/aef-task-lifecycle/v2.bpmn .context/designer/projects/aef-dispatch-loop/v2.bpmn .context/designer/projects/aef-inception-flow/v2.bpmn); e`

### 2026-07-23T07:06:39Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
