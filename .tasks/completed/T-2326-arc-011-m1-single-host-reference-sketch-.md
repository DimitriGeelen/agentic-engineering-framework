---
id: T-2326
name: "arc-011 M1 single-host reference sketch — companion design artifact to T-2325
  §3 (6 workstreams concretized for operator grill, not implementation)"
description: >
  arc-011 M1 single-host reference sketch — companion design artifact to T-2325 §3
  (6 workstreams concretized for operator grill, not implementation)

status: work-completed
workflow_type: design
owner: agent
horizon:
tags: [arc-parallel-execution-aef, agent-prep, design-sketch, no-source-change]
components: []
related_tasks: [T-2303, T-2323, T-2324, T-2325]
arc_id: parallel-execution-aef
# demo_target: true               # T-2286: optional — marks task as reserved for an orchestrated demo
#                                 # worker (e.g. arc-010 HM-A dispatches via mcp__fw__work_on). When set,
#                                 # `fw work-on T-XXX` refuses unless --i-am-demo-orchestrator (CLI) or
#                                 # FW_I_AM_DEMO_ORCHESTRATOR=1 (env) is passed. Prevents the parent
#                                 # session from consuming the captured→started-work transition the demo
#                                 # worker expects to drive. Origin OBS-057.
created: 2026-06-11T06:58:46Z
last_update: '2026-08-16T22:25:02Z'
date_finished: 2026-06-11T07:04:00Z
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
  - ts: '2026-06-11T07:00:03Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 3
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=3 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-06-11T07:00:04Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-ORCH: 0
    rationale: D1=4 (body:structural-gate); D2=2 
      (body:telemetry-or-audit-entry); D3=2 (body:default-change); D4=2 
      (body:env-class-handled); F-RECALL=2 (body:lightly-promoted); F-ORCH=0 
      (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:24:15Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=2 
      (body:telemetry-or-audit-entry); D3=2 (body:default-change); D4=2 
      (body:env-class-handled); F-RECALL=2 (body:lightly-promoted); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:25:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=2 
      (body:telemetry-or-audit-entry); D3=2 (body:default-change); D4=2 
      (body:env-class-handled); F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2326: arc-011 M1 single-host reference sketch — companion design artifact to T-2325 §3 (6 workstreams concretized for operator grill, not implementation)

## Context

T-2325 §3 proposed treating arc-011 as a two-milestone arc — M1 (single-host
parallel + headline_mechanic demo, AEF-only) and M2 (ring20 multi-host
substrate-bound). The §3 listed 6 AEF-only workstreams. Without concretization,
"single-host parallel" can be grilled as hand-wave: what files change? what
tests? what cost? what does each workstream actually look like at the wire level?

This task answers those questions by writing a reference sketch — one section
per §3 workstream, naming surface area (files, ACs, tests), Q-sized estimate,
and how that workstream's exit criterion contributes to the headline_mechanic
firing. The artifact is explicitly a DESIGN SKETCH for grilling, not an
implementation spec — the operator approves/rescopes/rejects each piece, and
the actual build only happens under separately-filed build tasks AFTER
operator-approved milestone split (which has not happened).

Scope: a single docs/reports/ artifact. No source change. No build tasks
filed. No edit to arc-011.yaml or the AEF ADR. References T-2325 § for §
correspondence.

Critical anti-pre-emption framing the artifact will declare:
- The milestone split is a T-2325 §3 proposal, NOT an arc-011 decision yet
- Each sketched workstream is a "what M1 *could* look like", not "what M1 *is*"
- The operator's possible answers: APPROVE the split → file 6 build tasks
  per this sketch; RESCOPE the split → keep arc-011 as one milestone; REJECT
  the split → keep arc-011 substrate-bound

## Acceptance Criteria

### Agent
- [x] docs/reports/arc-011-m1-single-host-sketch.md exists with non-empty body
- [x] Artifact contains 6 numbered workstream sections matching T-2325 §3 (orchestrator-graph, harness yield-point, disjoint-write-set policy validator, single-host parallel demo, /orchestrator/parallel view, disjointness gate pre-flight)
- [x] Each workstream section names ≥1 specific file path under `agents/`, `bin/`, `lib/`, `web/`, or `tests/` (23 path references total)
- [x] Each workstream section gives a Q-sized estimate (S/M/L/XL) and a one-line cost rationale (6 Size lines)
- [x] Each workstream section names ≥1 exit criterion that connects to headline_mechanic firing (32 exit/dispatches.jsonl references)
- [x] Artifact has an explicit "What this is NOT" closing block declaring no pre-emption of operator milestone-split decision
- [x] Artifact cross-references T-2325 §3 by section number for traceability (10 cross-references)
- [x] No new build tasks filed under this task (anti-pre-emption — sequencing table is a recommendation block, not pre-emptive filing)

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

test -s docs/reports/arc-011-m1-single-host-sketch.md
out=$(cat docs/reports/arc-011-m1-single-host-sketch.md); n=$(echo "$out" | grep -cE "^## (1|2|3|4|5|6)\."); test "$n" -eq 6
out=$(cat docs/reports/arc-011-m1-single-host-sketch.md); n=$(echo "$out" | grep -cE "(agents|bin|lib|web|tests)/[A-Za-z_./-]+"); test "$n" -ge 6
out=$(cat docs/reports/arc-011-m1-single-host-sketch.md); n=$(echo "$out" | grep -cE "Size:[*[:space:]]+(S|M|L|XL)"); test "$n" -ge 6
out=$(cat docs/reports/arc-011-m1-single-host-sketch.md); echo "$out" | grep -qE "(Exit|exit criterion|headline_mechanic|dispatches\.jsonl)"
out=$(cat docs/reports/arc-011-m1-single-host-sketch.md); echo "$out" | grep -qE "What this is NOT|deliberately does NOT|pre-emption|pre-empt"
out=$(cat docs/reports/arc-011-m1-single-host-sketch.md); echo "$out" | grep -qE "T-2325.*§3|§3.*T-2325"
# L-387 capture-first: no pipe-to-grep on find boundary
n=$(find .tasks/active -name "T-23[3-9][0-9]-*" -newer .tasks/active/T-2326-arc-011-m1-single-host-reference-sketch-.md 2>/dev/null); test -z "$n"

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

## Recommendation

**Recommendation:** GO (full close — design sketch artifact in place, 8/8
Agent ACs, no human [REVIEW] needed; the artifact's content is operator-facing
material the operator grills, not something the agent needs operator approval
to ship)

**Rationale:** Concretizes T-2325 §3's 6 AEF-only workstreams into a grillable
M1 design sketch. Each workstream named (files, Size, exit criterion,
headline_mechanic traceability) so the operator can grill "what does M1 cost
and how does each piece move toward headline_mechanic firing" rather than
"but is single-host parallel real work?" The artifact is explicitly framed
as DESIGN SKETCH FOR GRILLING — three "What this is NOT" sub-points name
the operator's possible answers (REJECT split / RESCOPE / APPROVE) and
preserve the operator's authority to make the milestone-split decision.

**Evidence:**
- `docs/reports/arc-011-m1-single-host-sketch.md` exists with 6 numbered
  workstream sections (§1-§6 matching T-2325 §3's 6 workstreams in order)
- 23 file path references under `agents/` `bin/` `lib/` `web/` `tests/`
- 6 Size markers (S/M/L/XL) — §3 Size: M, §2 Size: S, §3 Size: M, §4 Size: L,
  §5 Size: M, §6 Size: S (total ≈ 4-7 build sessions)
- 32 references to `Exit` / `headline_mechanic` / `dispatches.jsonl` —
  every workstream traces to the headline_mechanic firing observable
- 10 explicit T-2325 §3 cross-references
- Anti-pre-emption block at the bottom names: (a) NOT milestone-split
  decision, (b) NOT build-task batch, (c) NOT substrate contract, (d)
  NOT §6-question resolver for the AEF ADR, (e) NOT commit-to-ship
- Sequencing table is a recommendation block with NO `fw work-on` invocations

**What this gives arc-011 prep:**
- T-2325 (grill responses) + T-2326 (M1 sketch) together give the operator
  a complete grill bundle: WHY split (T-2325 §4) + HOW M1 fits (T-2325 §3)
  + WHAT M1 costs concretely (T-2326)
- Each of the 6 workstreams becomes a grill target ("does §1 really need
  ~150 lines?" / "is §4 really L?") — the discussion is now about cost
  and scope, not about whether the work is real

**Out of scope (deliberately):**
- No edit to `.context/arcs/parallel-execution-aef.yaml` (milestone-split
  field doesn't yet exist; that's an operator decision)
- No edit to `docs/architecture/parallel-execution-aef.md` (ADR is fixed;
  this sketch consumes it)
- No T-23XX build tasks filed (cluster-bombing anti-pattern; sequencing
  table is recommendation only)
- No edit to T-2323/T-2324 (operator-parked inceptions; their collapse-to-M1
  framing in this artifact is a proposal, not a re-scope)
- No code in `agents/orchestrator/` `agents/dispatch/` `lib/write_set.py` etc.
  The implementations would only happen under operator-approved build tasks

## Updates

### 2026-06-11T06:58:46Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2326-arc-011-m1-single-host-reference-sketch-.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-c8585f10
- **Timestamp:** 2026-06-11T07:04:00Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

- **Suppressed:** 1 (by override)
  - AC-verify-mismatch @ AC#5 (Agent)

### 2026-06-11T07:04:00Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
