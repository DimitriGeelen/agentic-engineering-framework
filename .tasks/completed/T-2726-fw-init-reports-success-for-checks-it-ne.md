---
id: T-2726
name: "fw init reports success for checks it never ran — join the @init manifest to the validator evaluator set"
description: >
  fw init reports success for checks it never ran — join the @init manifest to the validator evaluator set

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [lib/validate-init.sh]
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
created: 2026-08-02T07:29:30Z
last_update: 2026-08-02T07:44:13Z
date_finished: 2026-08-02T07:44:13Z
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

# T-2726: fw init reports success for checks it never ran — join the @init manifest to the validator evaluator set

## Context

`fw init`'s post-init validation is two representations of one rule set with nothing
joining them:

- the **manifest** — inline `#@init: <type>-<key> <path>` annotations scraped out of
  `lib/init.sh` by awk (`lib/validate-init.sh:67`)
- the **evaluator** — a `case "$check_type"` in `lib/validate-init.sh:334`

Nothing checks that every declared type has an evaluator. Two live divergences today:

| direction | instance | consequence |
|-----------|----------|-------------|
| declared, **not** handled | `md-3bv policy/bvp-scoring-rubric.md` | falls to the `*)` branch → `skipped++`, message to **stderr**, `continue`. `total` was already incremented, so it is counted in the denominator and never evaluated. |
| handled, **never** declared | `exec)` branch | a complete evaluator that no manifest entry reaches. |

A fresh `fw init` therefore prints `Validation passed: 40/42 checks OK (2 skipped)`
and returns success while one of its 42 checks *cannot be evaluated at all*. The
artifact happens to exist, so nothing is broken today — the check is lucky, not
right. If `policy/bvp-scoring-rubric.md` ever went missing, no surface would report it.

This is the second of the two duals 832 named on rail 381, and the sibling of T-2724:

```
unreachable PASS   check always fails,    reads as decoration    <- T-2724 (19 hooks)
vacuous PASS       check never evaluates, reads as confirmation  <- this task
```

T-2724's variant was survivable-by-noise (it screamed `✗` on every run and was
eventually read). This one is strictly worse: it is silent and green.

Same class as L-526 (a guard suite no runner globs reports success by silence) and
L-399 (the bug lives at the producer/consumer join, invisible to either side alone).

The remedy is 832's rail-380 prescription applied one level over: derive both sets
from their real sources rather than re-typing either, and fail when the declaration
side names a type the evaluator cannot serve.

## Acceptance Criteria

### Agent
- [x] A guard extracts the declared-type set from `lib/init.sh` and the handled-type
      set from `lib/validate-init.sh`'s `case`, from source in both directions — no
      hand-maintained list of types anywhere in the test.
      → `_declared_types` / `_handled_types` in `tests/unit/validate_init_check_type_join.bats`.
- [x] The guard **fails** on declared-but-not-handled (a check that cannot be
      evaluated), and is verified to fail by introducing one, not by assertion alone.
      → observed red twice: on the real `md` orphan before the fix, and on a seeded
      `qqq-999` orphan after it (`not ok 1 … # qqq`), tree restored.
- [x] The guard **records** handled-but-not-declared as a named, reachable-but-
      unoccupied set rather than an error — `exec` is capability without occupancy,
      and deleting it would manufacture a capability zero out of an occupancy zero
      (832 rail 378).
- [x] `md` gains a real evaluator, so `policy/bvp-scoring-rubric.md` is actually
      checked on a fresh install.
      → live: `✓ md-3bv  BVP scoring rubric (T-1921/T-2259)`.
- [x] At runtime, an unknown check type is a **failure**, not a silent skip: the
      validator's own verdict goes red when it is handed a check it cannot run.
      → measured differentially against a control identical but for the type.
- [x] The unknown-type message goes to stdout with the rest of the verdict lines,
      not stderr.
- [x] A fresh `fw init` reports zero skipped-as-unknown checks and its validation
      count reconciles: passed + failed + skipped == total.
      → live: `Validation passed: 41/42 checks OK (1 skipped)`, no unknown types.
- [x] Negative control: the guard is shown to pass on the fixed tree and fail on a
      seeded divergence in each direction it claims to detect.
      → orphan-type seed (test 2) and silent-skip seed (test 9), both observed red,
      both restored; and two in-suite controls prove the differential can register a
      `+1` at all and does not fire on manifest length.
- [x] Every declared check produces exactly one visible row, so the summary's
      denominator is auditable from the output the operator sees.
      → 42 rows / 42 checks; the provider-scoped skip is now named
      (`- file-6qs … (skipped: provider 'generic' not in cursor)`) instead of silent.

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

# Each line runs in its own shell, so $$ differs per line — a cleanup line
# using $$ would never match the dirs the earlier lines created. Self-contained.
bats tests/unit/validate_init_check_type_join.bats
d=$(mktemp -d); out=$(bin/fw init "$d" 2>&1); rm -rf "$d"; echo "$out" | sed 's/\x1b\[[0-9;]*m//g' | grep -q "Validation passed"
d=$(mktemp -d); out=$(bin/fw init "$d" 2>&1); rm -rf "$d"; ! (echo "$out" | sed 's/\x1b\[[0-9;]*m//g' | grep -q "Unknown check type")
bash -n lib/validate-init.sh

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

**Symptom:** a correct fresh `fw init` prints `Validation passed: 40/42 checks OK
(2 skipped)` and returns success. One of those 42 — `md-3bv
policy/bvp-scoring-rubric.md` — was never evaluated, because no evaluator exists for
its type. The operator reads "passed", the count looks complete, and a check that
cannot run is indistinguishable from one that ran and passed.

**Root cause:** the check manifest and the check evaluator are two independently
edited representations of one rule set, joined by nothing. Adding a `#@init:`
annotation requires no corresponding evaluator, and the `*)` fallthrough treats an
unserveable declaration as a *skip* rather than a *defect*. `total` is incremented
before the `case`, so the unserved entry still inflates the denominator.

**Why structurally allowed:** three properties compound.
1. The fallthrough's disposition is `skipped`, and `skipped` does not touch the
   verdict — the function returns `[ "$failed" -eq 0 ]`.
2. Its message goes to **stderr**, so it is absent from any stdout capture and from
   the visual block the operator scans.
3. `fw init` does not gate on the validator's exit status at all — it prints
   "Init completed with validation errors" and returns 0 regardless
   (`lib/init.sh:456-460`). Even a red verdict has no downstream consequence.

832 named property 3 as the load-bearing one on rail 381: *their* equivalent class is
caught for free because their runner's exit code is wired and CI gates on it —
"our protection is not discipline, it is that the exit code is wired." Ours is not.

**Prevention:** distinct from the fix, in two layers.
- *Test time* — `tests/unit/validate_init_check_type_join.bats` derives both sets from
  their real sources and fails when a declared type has no evaluator. A future
  `#@init:` annotation of a new type goes red in CI before it can ship silent.
- *Run time* — an unknown check type becomes a failure, so the same divergence
  arriving through any path the test does not cover still turns the verdict red
  instead of being absorbed into the skip count.

The exit-code wiring in `fw init` (property 3) is deliberately **not** in this task:
it is a blast-radius change to a consumer-facing command and belongs to its own slice
with its own evidence. Filed separately rather than folded in.

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

### 2026-08-02T07:29:30Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2726-fw-init-reports-success-for-checks-it-ne.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-86e5c39c
- **Timestamp:** 2026-08-02T07:44:31Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** yes
- **Findings:** 2

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 4
     - evidence: `d=$(mktemp -d); out=$(bin/fw init "$d" 2>&1); rm -rf "$d"; echo "$out" | sed 's/\x1b\[[0-9;]*m//g' | grep -q "Validation passed"`
  2. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 5
     - evidence: `d=$(mktemp -d); out=$(bin/fw init "$d" 2>&1); rm -rf "$d"; ! (echo "$out" | sed 's/\x1b\[[0-9;]*m//g' | grep -q "Unknown check type")`

- **Layer-1 escalations:** 1
  1. **destructive-action** (high) — Destructive operation in verification or AC
     - matched: `rm -rf`

### 2026-08-02T07:44:13Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
