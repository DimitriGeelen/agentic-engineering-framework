---
id: T-2727
name: "fw init validates before it creates — the onboarding-task check can never run in the init path"
description: >
  fw init validates before it creates — the onboarding-task check can never run in the init path

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
created: 2026-08-02T07:49:12Z
last_update: 2026-08-02T07:49:12Z
date_finished: null
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
---

# T-2727: fw init validates before it creates — the onboarding-task check can never run in the init path

## Context

`do_validate_init` has a check — `func-tasks` — that parses every file in
`.tasks/active/` and verifies the onboarding tasks have valid frontmatter. It is
guarded by `[ "$active_tasks" -gt 0 ]` (`lib/validate-init.sh:462`).

`fw init` runs validation at `lib/init.sh:453`, and seeds the onboarding tasks at
`lib/init.sh:567` — **114 lines later**. At validation time `.tasks/active/` is
empty, so the guard is false, the check does not run, and because the guard sits
*outside* the `total=$((total + 1))` it is not counted either. It appears in neither
the numerator nor the denominator. Nothing is printed. There is no way to tell from
the output that the check exists.

Measured:

```
fw init <fresh>            → Tier 2 shows func-hook×3, func-paths, func-claude
                             (no func-tasks) — "41/42 checks OK"
fw validate-init <same>    → ✓ func-tasks  5 onboarding tasks have valid frontmatter
```

So the check is not dead — it is unreachable *in the init path specifically*, which
is the only path most users ever run. The artifact it exists to protect is the
onboarding task set: the thing a first-run user is handed, and the thing that
determines whether the T-532 gate can ever be cleared.

This is the third distinct member of the family, and the one 832 named on rail 382
as the best-hidden:

```
unreachable PASS      check always fails                        T-2724
vacuous PASS          check never evaluates, still counted      T-2726
unwitnessable         check cannot be reached by the instrument
                      that would witness it                     this task
```

Their formulation: *"a missing fixture and an impossible one look the same."* Here a
check that never ran and a check that does not exist look the same, because the
absence is not representable in the output — the same property T-2726 fixed for the
provider-scoped skip, arrived at from the other direction (ordering rather than
disposition).

Note the fix direction is **ordering**, not the guard: `active_tasks > 0` is a
correct guard for the standalone verb, where a project genuinely may have no tasks.

## Acceptance Criteria

### Agent
- [x] `func-tasks` is evaluated during `fw init` on a fresh project — it appears in
      the init output, not only under a separate `fw validate-init` run.
      → live: `✓ func-tasks  5 onboarding tasks have valid frontmatter`.
- [x] The init validation denominator accounts for it (42 → 43 on a greenfield init).
      → live: `Validation passed: 42/43 checks OK (1 skipped)`.
- [x] The check has **teeth** in the init path, proven by a negative control: an
      onboarding task template with malformed frontmatter makes `fw init`'s own
      validation report the failure. Presence in the output is not the claim —
      firing is.
      → live: `✗ func-tasks  Invalid task files: T-001-broken.md`,
      `Validation: 1 error(s) out of 43 checks`, `Init completed with validation errors`.
- [x] Reordering validation back before task seeding turns the guard red, verified
      by seeding that divergence and observing it, then restoring.
      → tests 1-3 went red on the revert; 4-5 stayed green *by design* (they use a
      pre-existing task, so `active_tasks > 0` holds even at the early point — they
      pin teeth, not ordering). Scope noted in the test file so the split is not
      mistaken for coverage.
- [x] Nothing that previously passed now fails: the existing init validation set is
      unchanged apart from the added check, and `validate_init_check_type_join.bats`,
      `validate_init_hook_path_expansion.bats` and `init_project_shape_detection.bats`
      stay green.
      → 10 + 8 + 12 + 5 = 35 green, zero failures.
- [x] Whatever `fw init` does after validation cannot change a validated artifact —
      or if it can, validation moves after it too, so the verdict describes the tree
      the user is actually left with.
      → only the `Done!` banner follows validation now; it writes nothing.

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

bats tests/unit/init_validation_ordering.bats
bats tests/unit/validate_init_check_type_join.bats
d=$(mktemp -d); out=$(bin/fw init "$d" 2>&1); rm -rf "$d"; echo "$out" | sed 's/\x1b\[[0-9;]*m//g' | grep -q "func-tasks"
bash -n lib/init.sh

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

**Symptom:** `fw init` reported `41/42 checks OK` and never mentioned `func-tasks`,
the check that validates the onboarding task set. Running `fw validate-init` on the
very same directory a moment later ran it and passed it. The check existed, worked,
and was structurally excluded from the only run most users ever see.

**Root cause:** ordering. Validation was invoked ~114 lines before the onboarding
tasks were seeded. `func-tasks` is guarded by `active_tasks > 0` — correct for the
standalone verb, where a project may legitimately have no tasks — so it saw an empty
`.tasks/active/` and did not run.

**Why structurally allowed:** the guard sits *outside* the `total=$((total + 1))`,
so the unrun check left no trace in either the numerator or the denominator, and it
prints nothing on the not-taken path. The output of a run where it never executed is
byte-identical to the output of a build where the check was never written. There is
no surface — not the count, not the row list, not the exit status — on which the two
differ. Nothing was "wrong" to notice.

Underneath that: `fw init` is a sequence of mutations with a verification step
embedded in the middle of it, so the verdict describes an intermediate state rather
than the artifact the user is handed. Any check whose subject is created after line
453 was invisible in the same way; `func-tasks` is simply the one that exists today.

**Prevention:**
- *Ordering invariant* — `tests/unit/init_validation_ordering.bats` test 3 asserts
  the `Validating...` block appears after the onboarding-task line in init's own
  output. Verified red by reverting the move.
- *Teeth* — tests 4-5 pin that the check fails on malformed frontmatter and passes
  on valid, so a future change cannot satisfy the ordering while neutering the check.
- *Denominator* — test 2 requires the check to be inside init's count, not beside it.

**Not fixed here, deliberately:** `fw init` still exits 0 when its own validation
reports errors (observed live: `Validation: 1 error(s) out of 43 checks` →
`exit: 0`). 832 named this as the load-bearing property on rail 381 — a printed
verdict that nothing consumes cannot gate anything even in principle. It is a
blast-radius change to a consumer-facing command and belongs in its own slice.

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

### 2026-08-02T07:49:12Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2727-fw-init-validates-before-it-creates--the.md
- **Context:** Initial task creation
