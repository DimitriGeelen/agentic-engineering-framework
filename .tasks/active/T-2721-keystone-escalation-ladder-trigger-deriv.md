---
id: T-2721
name: "Keystone: escalation ladder trigger derived from witnessed failures, not self-report"
description: >
  Arc keystone for T-2715 GO item 5 (IW-12). Diagnosis complete in T-2715: the Escalation
  Ladder is a complete, wired mechanism whose trigger (status: issues) has been set
  on 0 of 2416 tasks — it has no producer. Mechanism is a separate arc: derive the
  trigger from failures the framework already witnesses (P-011 close failures, logged
  gate bypasses, Tier-0 blocks) instead of asking agents to self-report. Carries the
  arc's closure Recommendation.

status: started-work
workflow_type: design
owner: agent
horizon: now
tags: [arc:ladder-trigger-producer]
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
created: 2026-08-02T00:35:40Z
last_update: '2026-10-22T07:45:18Z'
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
  - ts: '2026-08-02T00:45:05Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 3
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=3 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-17T12:36:09Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 3
      effort: 6
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=3 
      (workflow:design); effort=6 (lines=148,acs=4)
    rubric_sha: e4a00f38e801
  - ts: '2026-10-21T09:30:56Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 3
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=3 
      (workflow:design); effort=8 (lines=154,acs=5)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-02T00:45:09Z'
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
  - ts: '2026-10-22T07:45:18Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 0
      D4: 0
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=2 (body:learning-ref,body:concern-ref); D2=2 
      (body:telemetry-or-audit-entry); D3=0 (no-signal); D4=0 (no-signal); 
      F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2721: Keystone: escalation ladder trigger derived from witnessed failures, not self-report

## Context

Design and the operator choice: `docs/reports/T-2721-ladder-trigger-design.md`.
Re-checked at HEAD 2026-10-21: still applies — nothing in `lib/ agents/ bin/ web/` writes
`status: issues`; P-011 failures (`update-task.sh:1751`) and Tier-0 blocks are not recorded anywhere.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] Gap re-measured at HEAD with evidence (no `status: issues` producer; P-011 failure and Tier-0 block unrecorded; bypass-log flag breakdown) in the design report §1
- [x] Design report names the three operator questions (what a failure writes, which sources count, counted ladder vs G-019) with options and costs, and gives a recommendation plus build slices
- [ ] Operator decision on Q1–Q3 recorded under `## Decisions`, and build slices filed as tasks on arc `ladder-trigger-producer` (blocked on the operator — see `## Recommendation`)

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
test -f docs/reports/T-2721-ladder-trigger-design.md
grep -q "^### Q1" docs/reports/T-2721-ladder-trigger-design.md && grep -q "^### Q2" docs/reports/T-2721-ladder-trigger-design.md && grep -q "^### Q3" docs/reports/T-2721-ladder-trigger-design.md
grep -q "^## 3. Recommendation" docs/reports/T-2721-ladder-trigger-design.md

## Recommendation

**Recommendation:** GO on option B — witnessed failures go to a new append-only ledger
(`.context/working/witnessed-failures.jsonl`), healing `diagnose` runs on each entry, Watchtower
shows them; task status is left alone. Sources: P-011 verification failure at close, plus the
four failure-shaped gate bypasses (`--skip-verification`, `--skip-acceptance-criteria`,
`--skip-rca`, `--skip-register-requirements`). Tier-0 blocks come later, recorded but not escalated.

**Rationale:** The gap is still there at HEAD. Nothing writes `status: issues`. A P-011 failure
(`update-task.sh:1751`) prints and exits, and a Tier-0 block writes nothing. B delivers the arc's
headline mechanic with the smallest governance change. Option A (flip `status: issues`) would
have the close gate change the task it just refused. It also collides with the T-1068 status/horizon
invariants, and every Verification typo would put a task into `issues`. Option C (count recurrences, then flip)
can be built later on the same ledger. The bypass log can't be taken whole as a source: 1037 of
its 1780 entries are focus switches, not failures.

**Evidence:**
- `docs/reports/T-2721-ladder-trigger-design.md` §1: measurements at HEAD, 2026-10-21
- `agents/healing/lib/diagnose.sh:98` only prints a note when the task isn't in `issues`, so
  healing can run without a status flip (corrects T-2715's "refuses")
- `.context/project/patterns.yaml`: 11 FPs, all entered by hand; last changed 2026-04-08

**Options for the operator (reply with the letter):**
- **A** — flip `status: issues` on a witnessed failure
- **B** — ledger + healing + Watchtower, status untouched (recommended)
- **C** — B, plus flip `issues` when the same fingerprint recurs N times on one task

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

### 2026-10-21 — keystone re-measured, design written
- **What changed:** Healing `diagnose` does not require `status: issues` (it notes and continues),
  so the ladder can be fed without touching task status. The bypass log is ~58% focus switches,
  and Tier-0 blocks are not recorded anywhere.
- **Plan impact:** "Derive the trigger" no longer has to mean "set `issues`". A ledger is the
  smaller change, and the bypass source has to be filtered to the failure-shaped flags.
- **Triggered:** operator choice A/B/C (see `## Recommendation`). Build slices are listed in the
  report §4 and get filed after the decision.

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

### 2026-08-02T00:35:40Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2721-keystone-escalation-ladder-trigger-deriv.md
- **Context:** Initial task creation

### 2026-08-02T00:36:51Z — status-update [task-update-agent]
- **Change:** tags: +arc:ladder-trigger-producer

### 2026-10-21T09:25:33Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
