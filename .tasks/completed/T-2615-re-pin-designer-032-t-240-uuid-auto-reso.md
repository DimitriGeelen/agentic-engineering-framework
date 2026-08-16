---
id: T-2615
name: "re-pin designer 0.3.2 (T-240 uuid auto-resolve hotfix) — flag flip + alias
  drop + e2e"
description: >
  re-pin designer 0.3.2 (T-240 uuid auto-resolve hotfix) — flag flip + alias drop
  + e2e

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
created: 2026-07-23T07:55:16Z
last_update: '2026-08-16T22:25:12Z'
date_finished: 2026-07-23T08:52:00Z
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
  - ts: '2026-07-23T08:00:06Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-07-23T08:00:09Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 3
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=3 (body:portability-abstraction); F-RECALL=0 
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
      F-AUTONOMY: 3
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=4 (body:cross-machine); F-RECALL=0 (no-signal); 
      F-AUTONOMY=3 (body:feedback-loop-closed); F3=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2615: re-pin designer 0.3.2 (T-240 uuid auto-resolve hotfix) — flag flip + alias drop + e2e

## Context

832 cut 0.3.2 — the T-240 hotfix (uuid workflowRef auto-resolve at load) requested in
T-2612's rail-168 escalation, plus T-242. Announced rail 171 with the agreed flow:
sha-confirm → re-pin → flip resolves_workflow_ref → e2e → drop the compat aliases.
Delivered via file_send (announced sha 983e0e30…d38a, 866701 bytes, tag
designer-v0.3.2). This task runs the full T-2611-pattern re-pin cycle PLUS the
T-2612 unwind: emit must become pin-flag-conditional (alias only while the pinned
editor can't resolve uuids), corpus regenerated back to uuid-only form, e2e must
prove auto-resolve on a uuid-ONLY link (the case 0.3.1 failed).

## Acceptance Criteria

### Agent
- [x] Delivered artifact received and INDEPENDENTLY verified: sha256
      983e0e304a3dc12e41ed9ea7270ba6edd032453c72c9ee423f466aa9d9e8d38a, 866701
      bytes — exact match to the rail-171 release pin; T-240 marker
      ("auto-resolved from workflow ref") present on delivered bytes, 0.3.1
      markers retained (_loadSrcKey x5, EVENT_KIND_TYPE x2); match confirmed to
      832 at rail offset 172 BEFORE sync (T-559/T-2611 flow).

- [x] Pin bumped to 0.3.2 (sha/bytes/tag/vendored_path/content-note) with
      `resolves_workflow_ref: true`; `fw designer sync` clean; doctor OK
      ("designer vendored build matches pin 983e0e304a3d…"); served bytes at
      /designer/app sha-identical to the pin (983e0e30…d38a).
- [x] emit_map made capability-conditional: `compat_alias` param (None → derived
      from the pin flag; explicit bool in tests) — targetWorkflow compat alias
      emitted ONLY while the pin lacks resolves_workflow_ref; pinned both ways +
      live-default in tests/unit/test_corpus_spec_roundtrip.py. Corpus handoff
      maps regenerated uuid-only as new versions (task-lifecycle v3,
      dispatch-loop v3, inception-flow v4), canonical-IDENTICAL to their
      predecessors, uuids preserved (1f9b5f0c/e32a518c/6178cf0a), zero
      targetWorkflow attrs in the new versions.
- [x] T-240 proven on served bytes (Playwright, operator path): uuid-ONLY link
      (task-lifecycle v3 tl_handoff_dispatch — exactly the 0.3.1-dead case)
      shows "Target workflow: aef-dispatch-loop ↳ auto-resolved from workflow
      ref (uuid)", jump enabled, jump completes (landed in dispatch-loop, 20
      dl_* elements). T-242 proven on dual-form (v2): same uuid-authoritative
      binding + jump completes. inception-flow v4 renders connected
      (if_inception present, 9/9 edges).
- [x] Corpus lint at pinned 2-finding baseline (t2584-scratch legacy-ref +
      agt_msg_result emitterless); editor-unbindable dormant under the flipped
      flag; corpus suites 27/27 green.

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

python3 -c "import yaml; p=yaml.safe_load(open('policy/designer-pin.yaml')); assert p['version']=='0.3.2' and p['resolves_workflow_ref'] is True and p['sha256'].startswith('983e0e30'), p"
out=$(sha256sum vendor/designer/aef-workflow-designer-0.3.2.html); echo "$out" | grep -q 983e0e304a3dc12e41ed9ea7270ba6edd032453c72c9ee423f466aa9d9e8d38a
python3 -m pytest tests/unit/test_corpus_spec_roundtrip.py tests/unit/test_corpus_lint.py -q
out=$(python3 tools/corpus_lint.py 2>&1); echo "$out" | grep -q "2 finding(s)"
! grep -q targetWorkflow .context/designer/projects/aef-task-lifecycle/v3.bpmn .context/designer/projects/aef-dispatch-loop/v3.bpmn .context/designer/projects/aef-inception-flow/v4.bpmn

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

**Symptom:** (inherited class — full RCA in T-2612) corpus handoff jumps dead on
the served designer: uuid-only `workflowRef` links rendered "Target workflow
— none —" with the jump disabled, because the pinned 0.3.1 editor could only
bind from the legacy `targetWorkflow` slug.

**Root cause:** producer serialized form (contract-v0 uuid refs, T-2605/T-2609
recreates) drifted ahead of the pinned consumer's binding capability — the
canonical-diff gate proves serialization identity, not consumer-binding
semantics (L-399 cross-project producer/consumer sibling).

**Why structurally allowed:** the pin recorded WHICH build was served but not
WHAT the build could bind; no capability axis existed for the emitter or lint
to key off.

**Prevention (this task closes the loop):** capability now lives in the pin
(`resolves_workflow_ref`) and drives BOTH sides symmetrically — emit_map's
compat alias (auto re-enables on a capability regression) and lint rule
`editor-unbindable` (FAILs any served map the pinned editor cannot bind), plus
the live-default unit pin in test_corpus_spec_roundtrip.py. A future re-pin that
regresses T-240 flips one flag and the whole guard rearms with zero code change.

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

### 2026-07-23 — emit_map alias conditionality mechanism
- **Chose:** `compat_alias: bool | None = None` parameter on emit_map — None
  reads policy/designer-pin.yaml `resolves_workflow_ref` (missing file/field →
  alias ON, the safe direction); tests pass an explicit bool for hermeticity.
  Mirrors the T-2612 lint pattern (`editor_resolves_uuid=None` → pin read).
- **Why:** symmetric producer/consumer pattern — the same pin flag drives both
  the emitter (alias on/off) and the lint gate (editor-unbindable armed/dormant),
  so a future capability regression re-activates BOTH automatically with one
  flag flip and zero code changes.
- **Rejected:** importing corpus_lint's pin reader into corpus_spec (cross-tool
  import coupling for 10 lines); a CLI flag on `corpus_spec generate` (operator
  could emit a form the pinned editor can't bind — the exact T-2612 class).

### 2026-07-23 — old dual-form versions retained
- **Chose:** regenerate uuid-only as NEW versions (v3/v3/v4); dual-form v2/v2/v3
  stay in the store as history.
- **Why:** /api/save is non-destructive by design; old versions double as the
  T-242 dual-form e2e fixture (proven: v2 binds uuid-authoritatively on 0.3.2).

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-07-23T07:55:16Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2615-re-pin-designer-032-t-240-uuid-auto-reso.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-3c4427c8
- **Timestamp:** 2026-07-23T08:52:02Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-07-23T08:52:00Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
