---
id: T-2738
name: "verification gate: a pass-marker verdict on an unjudged test run closes green
  while tests fail"
description: >
  verification gate: a pass-marker verdict on an unjudged test run closes green while
  tests fail

status: work-completed
workflow_type: build
owner: agent
horizon: null
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
created: 2026-08-02T17:06:30Z
last_update: 2026-08-02T17:17:37Z
date_finished: 2026-08-02T17:17:37Z
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
  - ts: '2026-08-02T17:15:06Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-02T17:15:09Z'
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

# T-2738: verification gate: a pass-marker verdict on an unjudged test run closes green while tests fail

## Context

A `## Verification` line of the shape

    out=$(python3 -m pytest tests/unit/foo.py -q 2>&1); echo "$out" | grep -q "9 passed"

closes **green on a suite where tests fail**. Measured live against a 2-pass/1-fail
suite under the gate's exact evaluation: pytest emits `1 failed, 2 passed`, the
substring `2 passed` is present, `grep -q` exits 0, P-011 records PASS.

**Why the exit code does not save it.** `update-task.sh` sets `set -euo pipefail`
(:14) and evals each line at :1085 inside `if ( … ); then`. `pipefail` is a shell
option and stays in force — every *pipeline* shape is judged correctly. But
**`set -e` is suppressed inside an `if` condition**, so for a *sequence*
(`cmd1; cmd2`) only `cmd2`'s status is the verdict. The captured pytest run is
unjudged.

Measured under that exact harness (2 pass / 1 fail):

| Verification line shape | Verdict |
|---|---|
| `pytest … \| tail -5` | red ✓ (pipefail) |
| `pytest … \| grep -qE "[0-9]+ passed"` | red ✓ (pipefail) |
| `pytest … > o.txt && grep -q "2 passed" o.txt` | red ✓ (exit preserved) |
| `out=$(pytest …); echo "$out" \| grep -q "2 passed"` | **GREEN ✗** |
| `out=$(pytest … \|\| true); echo "$out" \| grep -q "2 passed"` | **GREEN ✗** |

**The capture idiom is not itself the defect.** 821 corpus lines use
`out=$(cmd); echo "$out" | grep -q "…"` and the overwhelming majority are sound —
`fw doctor` exits non-zero for unrelated warnings, so the grep *is* the assertion
and the discarded exit code is genuinely irrelevant. CLAUDE.md prescribes it.

The defect needs the conjunction: **the unjudged command is a test runner** (whose
exit code was the real verdict) **and** the replacement assertion is a pass marker
that a partially-failing run still emits. Then the grep is strictly *weaker* than
what it replaced, and the line reports success for a red suite.

Population narrowing (each step a denominator correction):

| Predicate | Lines | Task files |
|---|---|---|
| pins a literal count (OBS-132's framing) | 79 | 69 |
| pass marker with no failure guard | 161 | 137 |
| sequence line, real work before final `;` | 937 | 513 |
| **unjudged test run + pass-marker-only verdict** | **65** | **54** |

23 of the 65 sit in `.tasks/active/` — the close gate is still ahead of them.

Origin: OBS-132, filed against my own T-2736 line, framed as "pins a literal
count". That framing was wrong. The count is incidental; `grep -qE "[0-9]+ passed"`
— the fix the note recommended — is green on the same failing suite.

## Acceptance Criteria

### Agent
- [x] Predicate has exactly one definition, in `lib/`, sourced by both the gate and its
      regression suite — no re-typed copy in the test (L-533)
- [x] `fw task update --status work-completed` refuses a task whose `## Verification`
      contains the shape, naming the failing line and the safe rewrite
- [x] Named bypass env var exists, is stated in the refusal message, and logs Tier-2
      to `.gate-bypass-log.yaml` (parity with `FW_ALLOW_HARDCODED_PORT`, L-399)
- [x] Negative controls pass: the sanctioned `fw doctor` capture-grep idiom, and a
      pass-marker line that *does* carry a failure guard, both remain clean
- [x] End-to-end test drives a real partially-failing suite through the real gate —
      green before the fix, refused after (the defect is proven reachable, not asserted)
- [x] Task template's L-387 hint no longer teaches the defect: it states that for a
      **test runner** the capture idiom discards the verdict, and gives the safe form

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

bats tests/unit/verification_unjudged_test_run.bats > /tmp/.t2738.out 2>&1 && grep -q "^ok 16 " /tmp/.t2738.out && ! grep -q "^not ok" /tmp/.t2738.out
bash -n lib/verification-verdict.sh
bash -n agents/task-create/update-task.sh
grep -q "source .*lib/verification-verdict.sh" agents/task-create/update-task.sh
grep -q "BUT NOT for a test runner" .tasks/templates/default.md
bats tests/unit/verification_port_hardcode.bats > /tmp/.t2738.sib 2>&1 && ! grep -q "^not ok" /tmp/.t2738.sib

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

**Symptom:** a `## Verification` line that captures a pytest/bats run and asserts a
pass marker on the capture closes GREEN while the suite is red. Demonstrated end to
end through the real gate: a 2-pass/1-fail suite, `grep -q "2 passed"`, and P-011
reporting `Verification: 1/1 passed`.

**Root cause:** P-011 evaluates each line at `update-task.sh:1085` as
`if ( cd … && eval "$cmd" ); then`. `set -e` is suppressed inside an `if` condition,
so a sequence `cmd1; cmd2` is judged on `cmd2` alone. The capture discards the
runner's exit code — which for a test runner *was* the verdict — and the pass marker
substituted for it is still printed by a partially failing run.

**Why structurally allowed:** the framework taught the shape. The task template's
L-387 SIGPIPE hint prescribes `out=$(cmd 2>&1); echo "$out" | grep -q "PATTERN"`
as the safe pattern, and it is safe — for the advisory tools it was written for
(`fw doctor` exits non-zero on unrelated warnings, so the grep genuinely is the
assertion). Nobody noticed the remedy inverts when the captured command is a test
runner, because the guidance was written about SIGPIPE, not about verdict strength.
Compounding it: the failure direction is GREEN. A red verification line gets noticed
at the next close; a line asserting less than it appears to is indistinguishable
from one asserting everything, so it accumulated to 61 lines across 50 tasks
(L-534, same mechanism as T-2732's 371 port literals).

Also self-inflicted at the diagnosis step: OBS-132 filed this against my own T-2736
line as *"pins a literal test count"*, and proposed `grep -qE "[0-9]+ passed"` as the
fix. That fix is green on the same failing suite — pinned test 4. The literal count
was the visible feature, not the defect.

**Prevention:** `check_verification_unjudged_test_runs` in the P-011 close gate,
predicate single-defined in `lib/verification-verdict.sh` (L-533), bypass
`FW_ALLOW_UNJUDGED_TEST_RUN=1` logged Tier-2. Plus the template hint now states the
test-runner exception at the point the shape is taught — the gate stops the next
instance, the template stops it being written in the first place.

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

### 2026-08-02T17:06:30Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2738-verification-gate-a-pass-marker-verdict-.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-55b51b7a
- **Timestamp:** 2026-08-02T17:18:02Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **mock-only-integration** (partial, heuristic) @ AC vs Verification cross-check
     - evidence: `bats tests/unit/verification_unjudged_test_run.bats > /tmp/.t2738.out 2>&1 && grep -q "^ok 16 " /tmp/.t2738.out && ! grep -q "^not ok" /tmp/.t2738.out`

### 2026-08-02T17:17:37Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
