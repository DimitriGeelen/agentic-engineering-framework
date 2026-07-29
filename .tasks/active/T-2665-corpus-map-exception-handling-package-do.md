---
id: T-2665
name: "corpus map: exception-handling (package dogfood catalog)"
description: >
  Map the exception-handling process (detection → classification → escalation routing
  per Error Escalation Ladder → resolution → learning capture; lib healing + status:issues
  flow) as a corpus map + conformance rail. Second of the package's four worst-regression
  processes (T-2662 gap 6). Gated on the tier0-escalation P4 test outcome — promote
  horizon only after that lands.

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [process-layer, corpus]
components: []
related_tasks: [T-2662]
arc_id: designer-corpus
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
created: 2026-07-28T16:19:32Z
last_update: 2026-07-29T05:29:17Z
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
cost_estimate_proposed:
  - ts: '2026-07-28T16:30:05Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-07-28T16:30:09Z'
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
---

# T-2665: corpus map: exception-handling (package dogfood catalog)

## Context

Second dogfood round of the process-layer package's four worst-regression processes
(T-2662 gap 6). Maps the exception-handling machine: status:issues trigger →
auto-diagnose (update-task.sh Trigger 1) → keyword classification → pattern lookup →
Error Escalation Ladder suggestions → fix → resolve (FP + L capture). Rail candidate:
vocabulary-set on the "failure type?" gateway vs the enforced classification enum in
`agents/healing/lib/diagnose.sh` (CLASSIFY_ORDER 5 types + the `unknown` fallback = 6
outcomes; extraction regex `(?:FAILURE_KEYWORDS_|best_type=")([a-z]+)` verified to
yield exactly those 6 tokens).

## Regression-History Baseline (AC-1)

Mined 2026-07-29 (episodics, concerns.yaml, learnings.yaml, git log, prior audits):

- **Code churn:** 14 commits on `agents/healing/` — 1 implementation (T-007) + 13
  touches, including a 4-commit consecutive pure-fix cluster (T-796, T-868, T-871,
  T-1076) plus T-872 re-applying T-871's fix to the vendored copy (fix regressed
  across the copy boundary → duplicate learnings L-213/L-214).
- **Multi-defect incident:** T-028 found THREE simultaneous healing defects in one
  pass — classifier ordering (generic `code` matched before specific types → L-003),
  pattern lookup dumping all patterns, wrong section boundaries.
- **Loop legs empirically broken:** G-016 (mitigated) — 72% of bugfix tasks (31/43)
  produced zero learnings; the "log resolution" leg simply didn't fire. G-019 (still
  `watching`) — Level D self-escalation never fires on its own; two bolt-ons (T-1550
  RCA gate, T-1555 cron scanner) exist, no map. T-1767 — the escalation drift scanner
  itself shipped undeployed (detector for escalation failures silently failed).
- **Structural verdicts on record:** T-629 governance self-audit ranks self-healing
  #3 among failures — "zero proactive detection, zero auto-recovery, zero
  self-triggering... a knowledge base with a CLI, not a self-healing system"
  (docs/reports/fw-agent-t629-03-healing.md:39). T-580: retry-based recovery
  suggested for ALL failure types, no permanent-vs-transient distinction.
- **Status-flow blindness:** 61 episodic files mention `healing`, only 2 mention
  `status: issues` — the code churns constantly while the flow is never narrated.
  G-041: the status enum is re-enumerated at duplicate sites with no rail.
- **Pre-existing corpus hooks:** T-2551/T-2559 BPMN fixtures already carry
  `binding=status:issues` error-event annotations that nothing consumes yet.

Six concrete instances: T-028 (3 defects), T-871→T-872 (vendored regression),
T-868 (suggest.sh crash under set -e), T-580 (blanket retry advice), T-629/G-019
(Level D never self-fires), T-1767 (scanner undeployed). Baseline verdict: highest
defect density per line of any agent this size, and the process it implements is
the framework's declared "antifragile immune system" (T-396) — exactly the P4 claim's
target class.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] Regression-history baseline captured in task body before mapping (episodic +
      concerns evidence for exception-handling reiterations).
- [ ] `draft-exception-handling` seeded via the arc-014 pair-draft ritual from the
      enforced machine (status:issues flow, healing agent classify→lookup→suggest→
      resolve loop, Error Escalation Ladder A-D); operator + 832 iterate; canonical
      namespace untouched until approval.
- [ ] On approval: promoted, corpus lint baseline unchanged, `fw corpus prove` green.
- [ ] Conformance-rail entry added to `tools/conformance-registry.yaml`; result
      recorded honestly (green, or red with divergent pin test per T-2659 precedent).

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

### 2026-07-28T16:19:32Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2665-corpus-map-exception-handling-package-do.md
- **Context:** Initial task creation

### 2026-07-29T05:29:17Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: later → now (auto-sync)
