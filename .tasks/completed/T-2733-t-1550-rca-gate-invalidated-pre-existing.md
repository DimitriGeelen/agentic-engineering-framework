---
id: T-2733
name: "T-1550 RCA gate invalidated pre-existing test fixtures, red since May"
description: >
  T-1550 RCA gate invalidated pre-existing test fixtures, red since May

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [agents/task-create/update-task.sh, tests/unit/update_task_episodic_gen.bats, tests/unit/update_task_yaml_components_emit.bats]
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
created: 2026-08-02T10:43:20Z
last_update: 2026-08-02T11:07:43Z
date_finished: 2026-08-02T11:07:43Z
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
  - ts: '2026-08-02T10:45:06Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-02T10:45:10Z'
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

# T-2733: T-1550 RCA gate invalidated pre-existing test fixtures, red since May

## Context

Four tests across two suites are red, and all four fail for the same reason:

    ERROR: Cannot complete bug-class task — ## RCA section is missing.

That gate is T-1550, landed `e4f8b12be` on **2026-04-27**. The suites predate it:
`update_task_episodic_gen.bats` added 2026-04-20, `update_task_yaml_components_emit.bats`
added 2026-04-25 — two days before the gate — and untouched since.

Their fixtures create tasks named "Block-style components repro" / "Flow-style
components" and close them with `--status work-completed`. The bug-class heuristic
matches on title, so the gate classifies the fixtures as bug-class and refuses.
The suites are not testing RCA behaviour at all — one tests YAML components
emission, the other episodic generation. They are collateral.

Both suites are inside `tests/unit/`, which `fw test unit` runs wholesale
(`bin/fw:7551`). So this is not an unrun suite: it is a suite whose red has been
absorbed for ~97 days.

Filed earlier as OBS-130 for the episodic half only. The `yaml_components_emit`
half was found while checking T-2732 for regressions. Same root cause, so one task.

## Acceptance Criteria

### Agent
- [x] Attribution established by measurement (not inference), and its method limits stated
- [x] All 4 tests pass, with fixtures fixed at the fixture — not by weakening the assertion or by passing `--skip-rca`
- [x] The suites that can reach a close gate are swept for any OTHER instance of this class; each one found is either fixed here or filed with its own task id
- [x] Red count recorded before and after, so the residue is stated rather than implied
- [x] OBS-130 resolved and cross-referenced to this task

**AC1 as originally written was wrong and is reworded above.** It asserted "both
suites were GREEN immediately before `e4f8b12be`". Measured, that is false for
`update_task_episodic_gen.bats`: at `e4f8b12be~1` it shows 2 ok / 2 not ok.

Those two failures are an artefact of the method, not history. Checking out an
old `update-task.sh` while keeping TODAY's test file measures a mixture: the two
that fail are the T-1860 tests, added 2026-05-15, failing against 2026-04-27 code
because the feature they pin did not exist yet. Per-test names at each point:

    BEFORE gate (e4f8b12be~1)   red: 2, 3   (both T-1860 — anachronism)
    AT     gate (e4f8b12be)     red: 1, 2, 3, 4
    TODAY  (HEAD, pre-fix)      red: 1, 4

So T-1550 reddened exactly tests 1 and 4 — precisely the two red today — and
`update_task_yaml_components_emit.bats` went 2 green → 0 green at the same
commit. Attribution is clean once the anachronism is subtracted; the naive
before/after count is not.

**Red counts.** Before: 5 (episodic_gen 2, yaml_components_emit 2, rca_gate 1).
After: 0 across all 23 suites that invoke `--status work-completed`.

**Scope note.** The full `tests/unit/` run (2979 tests) was started but is far
too slow to gate on (~212 tests in 12 minutes). The sweep was therefore scoped to
the 23 suites that can actually reach a close gate — which is the population this
defect class can touch — rather than left as an unmeasured cell. Whether the full
unit suite should gate pushes is an operator decision, not one to take here.

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
out=$(bats tests/unit/update_task_episodic_gen.bats 2>&1); echo "$out" | grep -q "^ok 1 " && ! echo "$out" | grep -q "^not ok"
out=$(bats tests/unit/update_task_yaml_components_emit.bats 2>&1); echo "$out" | grep -q "^ok 1 " && ! echo "$out" | grep -q "^not ok"
out=$(bats tests/unit/rca_gate.bats 2>&1); echo "$out" | grep -q "^ok 1 " && ! echo "$out" | grep -q "^not ok"

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

**Symptom:** 5 tests across 3 suites red, up to 97 days. All failed inside a
close gate that landed after the suite was written: 4 on T-1550's RCA gate
(2026-04-27), 1 on G-052/T-1626's inception-decision gate.

**Root cause:** each new close gate adds a precondition to
`--status work-completed`. Existing fixtures were authored against the
preconditions of their day, so every gate addition silently invalidates some of
them. The fixtures are collateral — none of these suites is about RCA or
inception decisions; they test YAML component emission and episodic generation.

**Why structurally allowed:** nothing runs `tests/unit/` as a gate. It is not an
unrun suite — `fw test unit` runs the whole directory (`bin/fw:7551`) — but
nothing *requires* it green, so the red was absorbed. A gate author sees their
own new tests pass and has no signal that they broke four unrelated ones. There
is also no cheap signal available: the full suite is ~2979 tests and far too slow
to run per-commit, so "just run it" is not a remedy anyone will adopt.

**Prevention:** fixtures fixed at the fixture, so they now satisfy the gates they
must pass through. That is the fix, not the prevention, and I want to be explicit
about the difference: nothing here stops the NEXT close gate from reddening
another fixture. The candidate remedy — make some fast subset of `tests/unit/`
gate pushes, or have the pre-push audit report the red count — is a change to how
we work, and per §ACD that is the operator's call, not mine. Surfaced rather than
built. What this task does buy: the 23 close-gate suites are now a known, named
population that a gate author can run in ~3 minutes instead of 3 hours.

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

### 2026-08-02T10:43:20Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2733-t-1550-rca-gate-invalidated-pre-existing.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-8c0319a8
- **Timestamp:** 2026-08-02T11:08:05Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-08-02T11:07:43Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
