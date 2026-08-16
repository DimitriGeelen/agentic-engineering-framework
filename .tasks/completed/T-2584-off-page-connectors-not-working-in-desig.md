---
id: T-2584
name: "Off-page connectors not working in designer (operator field report 2026-07-21)"
description: >
  Off-page connectors not working in designer (operator field report 2026-07-21)

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [agents/task-create/create-task.sh]
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
created: 2026-07-21T08:00:34Z
last_update: '2026-08-16T22:25:11Z'
date_finished: 2026-07-21T08:52:08Z
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
  - ts: '2026-07-21T08:15:05Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-07-21T08:15:08Z'
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
  - ts: '2026-08-16T22:25:11Z'
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

# T-2584: Off-page connectors not working in designer (operator field report 2026-07-21)

## Context

Operator field report 2026-07-21 (mid-session, verbatim): "noticed that the off page connectors still are not working". This contradicts T-2571's shipped+live status — the AEF half (S1-S6: aefLink parse at save, pending-ref registry, compile Pass-5 WARNs, ghost task minting, /designer/ghosts) was live-verified on :3001, BUT the store contains ZERO diagrams with `aef:link` elements, meaning the operator-facing authoring path (creating an off-page connector in the pinned 0.3.0 editor at /designer) has never produced one. Working hypothesis (H1): the pinned designer 0.3.0 build predates off-page connector authoring support — that is exactly the 832 EDITOR BUILD gated on their /inception/T-218 (uuid mint model, workflowRef serialization, claim picker). If H1 holds, the fix is expectation-surfacing (placeholder/notice on the AEF side + rail coordination), not code — the authoring surface is 832's artifact, off-limits per the vendored-build contract (policy/designer-pin.yaml, read-only).

832 rail: offset 114 (they are proceeding with pair-draft #3 fixture); my offset ~8613 reply flagged this report to them transparently.

## Acceptance Criteria

### Agent
- [x] Root cause identified with live evidence (what exactly the operator experiences at /designer when attempting an off-page connector, and why), recorded in ## RCA
- [x] If cause is the 0.3.0 editor lacking authoring support (H1): the gap is surfaced operator-visibly — H1 DISPROVEN as stated (0.3.0 has full legacy-slug authoring, live-verified), but the visibility half of it held: the seam had zero observable instances. Addressed by T-2586 (corpus v2 handoffs, live) + the scratch fixture kept in place (t2584-scratch + ghost card at /designer/ghosts + minted T-2585) so every seam state has a live example
- [x] If cause is an AEF-side defect (parse/serialize/render on my half): confirmed AEF-side cause was CONTENT (corpus had no handoffs), not code — no code defect found in 9 live-verified legs; fix = T-2586 corpus v2, shipped + live-verified on :3001 (regression pinning stays with the existing T-2579 seam harness, unchanged)
- [x] 832 informed via rail of the confirmed root cause (offset 8619: no contract-level defect, pin pair-draft #3 as planned; ghost-alert dead-end UX finding recorded upstream for their T-218 build)

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

**Symptom:** Operator field report (verbatim): "noticed that the off page connectors still are not working."

**Live verification (2026-07-21, fresh Playwright session against http://192.168.10.107:3001/designer):** every leg of the shipped T-2571 seam works end-to-end:
- Palette click-to-place of "Handoff →" (linkEventThrow) → node on canvas ✓
- "📂 Choose from project…" picker: modal lists all 7 workflows, pick writes into Target workflow ✓
- "↗ Open target workflow" + double-click jump: resolved target opens live (aef-task-lifecycle via /api/list + /api/version) ✓; ghost target raises the by-design not-found alert ✓
- Serialization: `<aef:link targetWorkflow="t2584-ghost-target" linkId=""/>` in View XML ✓
- Save to project → server store `t2584-scratch/v1.bpmn` ✓ → registry ghost minted (uuid 398f4752…, referenced_by t2584-scratch:hum_1_handoff) ✓
- Ghost documentation task auto-minted → **T-2585** (owner:human, horizon:later, FW_TASK_ORIGIN gate shape) ✓ — ~30s lag (fw task create subprocess); a mid-flight registry read shows `task: null` until it lands
- /designer/ghosts renders the ghost card (needs-mapping, referrer, task chip, claim cmd) ✓
- Reopen round-trip preserves the aef:link ✓
- `fw bpmn compile` Pass-5 WARN names both ends + pending-ghost state ✓

**Root cause (of the operator's perception) — the plumbing works but is nearly invisible; three real gaps, none in the shipped AEF code:**
1. **Corpus content gap (most likely trigger):** all five corpus diagrams (D1-D5 pair-drafts under review) contain ZERO off-page connectors — the five processes never hand off to each other, so nowhere in the reviewable corpus is the feature observable.
2. **The visible uuid half is 832's undelivered editor build:** claim picker, draw-time uuid mint, workflowRef serialization, gallery ghost cards — all gated on 832-operator's /inception/T-218 (no ETA). The pinned 0.3.0 editor only has legacy slug-form handoffs.
3. **Ghost-target double-click is a dead-end alert** (832 bundle wording): "not found … Open or save that workflow first" — no pointer to /designer/ghosts, the minted task, or the claim flow. An operator drawing a forward-reference and double-clicking it gets what reads as a failure.

Cosmetic: /api/thumb 404s in the picker for server-side-authored corpus versions (no client thumbnail saved; ▦ placeholder renders — by design).

**Why structurally allowed:** §ACD class — the T-2571 slices verified substrate (registry, WARNs, mint, a separate ghosts page) but no corpus content exercises the mechanic, so the operator's first-touch surface shows nothing. The render-review Human ACs (T-2578) point at the ghosts page, not at a corpus diagram where a handoff is actually drawn.

**Prevention:** corpus diagrams get real cross-process handoffs (follow-up task) so the mechanic stays permanently observable on the operator's primary surface; 832 informed of the alert dead-end for their T-218 build.

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

### 2026-07-21T08:00:34Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2584-off-page-connectors-not-working-in-desig.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-a1af339a
- **Timestamp:** 2026-07-21T08:52:09Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-07-21T08:52:08Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
