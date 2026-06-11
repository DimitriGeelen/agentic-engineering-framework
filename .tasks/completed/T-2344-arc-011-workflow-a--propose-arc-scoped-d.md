---
id: T-2344
name: "arc-011 Workflow A — propose arc-scoped drivers (5-step protocol, retroactive)"
description: >
  arc-011 Workflow A — propose arc-scoped drivers (5-step protocol, retroactive)

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [.context/arcs/parallel-execution-aef.yaml]
related_tasks: [T-2303, T-1925, T-1926]
arc_id: parallel-execution-aef
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
created: 2026-06-11T19:41:53Z
last_update: '2026-06-11T22:24:16Z'
date_finished: 2026-06-11T19:46:43Z
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
  - ts: '2026-06-11T19:45:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 2
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=2 
      (body:lightly-promoted); F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:24:16Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 4
      D4: 2
      F-RECALL: 2
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=4 
      (body:framework-level-ux); D4=2 (body:env-class-handled); F-RECALL=2 
      (body:lightly-promoted); F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-06-11T19:45:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 1
      tier: 2
      effort: 8
    rationale: blast_radius=1 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2344: arc-011 Workflow A — propose arc-scoped drivers (5-step protocol, retroactive)

## Context

arc-011 (`parallel-execution-aef`) was created 2026-06-10 with `proposed_scoped_drivers: []`
empty. The §Arc-Scoped Driver Suggestion Workflow (CLAUDE.md, T-1925) prescribes a 5-step
protocol to run on new-arc creation:

1. Read the arc anchor-task body in full (T-2303).
2. List 2-3 candidate drivers + one-line rationales of what each distinguishes that D1-D4 don't.
3. Write candidates to `proposed_scoped_drivers:` in the arc YAML.
4. Surface via `fw arc show-suggestions arc-011`.
5. Operator approves (zero or more) via `fw arc approve-driver` — Sovereign-gated, not in this scope.

This task runs Workflow A (`mode=batch_propose`) retroactively. The keystone bundle is at
`policy/prompts/bvp-driver-session.md`; worked examples at `bvp-references/arc-scoped-driver-examples.md`.

R5 mitigation applies: *manufacturing drivers to look thorough is worse than proposing
zero and recommending --none.* If the candidate analysis below converges on "no real
distinction beyond D1-D4", recommend `--none` instead.

## Acceptance Criteria

### Agent
- [x] `.context/arcs/parallel-execution-aef.yaml` `proposed_scoped_drivers:` populated with ≥1 entry (or empty + research artifact recommends --none)
- [x] Each proposed entry has shape `{id, name, rationale, source: agent, ts}` per T-1925
- [x] Research artifact written at `docs/reports/T-2344-bvp-driver-arc-011.md` per `policy/prompts/artefact-template.md` (Context, Candidates Considered, Final Spec, Dialogue Log if any)
- [x] `bin/fw arc show-suggestions arc-011` exit 0 + displays the proposals (or "no proposals" if --none)
- [x] YAML parses cleanly (`python3 -c "import yaml; yaml.safe_load(open('.context/arcs/parallel-execution-aef.yaml'))"`)
- [x] Reviewer PASS on T-2344 (no AC-verify-mismatch is fine to override 90d if it fires)

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

python3 -c "import yaml; arc=yaml.safe_load(open('.context/arcs/parallel-execution-aef.yaml')); assert len(arc['proposed_scoped_drivers']) >= 1"
test -f docs/reports/T-2344-bvp-driver-arc-011.md
out=$(bin/fw arc show-suggestions arc-011 2>&1); echo "$out" | grep -q "D-DISJOINT\|D-WIRE-EVIDENCE"
out=$(bin/fw reviewer T-2344 2>&1); echo "$out" | grep -qE "Overall:.*(PASS|CONCERN)" && ! echo "$out" | grep -q "Overall:.*FAIL"

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

### 2026-06-11 — Retroactive Workflow A on arc-011
- **What changed:** Workflow A protocol (T-1925 5-step) should fire on `fw arc create` but
  didn't auto-run for arc-011 (created 2026-06-10) — `proposed_scoped_drivers: []` stayed
  empty through 6 M1 slices. The trigger is documented in CLAUDE.md but is agent-discipline,
  not hook-enforced. Discovered during this session's HV-LC survey of arc-011 follow-on work.
- **Plan impact:** None to M1 (already shipped). Forward-value only — M2 / IC work will
  benefit if operator approves the proposals.
- **Triggered:** None new. Open observation: should `fw arc create` emit a reminder "Workflow
  A — propose drivers?". R5 discipline says no — agent-discipline is the cheaper enforcement
  here than another hook reminder; the keystone bundle is already authoritative.

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

**Recommendation:** GO — operator approves both proposed drivers via CLI / Watchtower.

**Rationale:** Two drivers (D-DISJOINT w=5, D-WIRE-EVIDENCE w=4) clearly distinguish arc-011
member tasks along the two structural axes the headline_mechanic asserts (invariant +
evidence). R1 differentiation tests in `docs/reports/T-2344-bvp-driver-arc-011.md` show each
is distinct from D1-D4 (and from each other). R5 discipline applied — third candidate
D-YIELD rejected as overlapping with D-DISJOINT/D2. Two approved drivers leave headroom for
a 3rd if M2 reveals a real distinction.

**Evidence:**
- `.context/arcs/parallel-execution-aef.yaml` `proposed_scoped_drivers:` lines populated
- `docs/reports/T-2344-bvp-driver-arc-011.md` — full session artifact (R1+R2 per driver,
  Candidates Considered, Rejected Paths)
- `bin/fw arc show-suggestions arc-011` displays both proposals with rationale
- YAML parse-clean verified at task close

**Operator action (copy-pasteable):**
```
cd /opt/999-Agentic-Engineering-Framework && bin/fw arc approve-driver arc-011 D-DISJOINT --weight 5 --i-am-human
cd /opt/999-Agentic-Engineering-Framework && bin/fw arc approve-driver arc-011 D-WIRE-EVIDENCE --weight 4 --i-am-human
```

Or partial (one), or full reject (`bin/fw arc approve-driver arc-011 --none --justification "..."`).

## Updates

### 2026-06-11T19:41:53Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2344-arc-011-workflow-a--propose-arc-scoped-d.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-d05c8065
- **Timestamp:** 2026-06-11T19:46:45Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-06-11T19:46:43Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
