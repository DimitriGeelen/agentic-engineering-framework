---
id: T-3553
name: "arc demo evidence is never checked until close - add the mechanical leg"
description: >
  arc demo evidence is never checked until close - add the mechanical leg

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
# write_set:                      # T-3512: optional — globs (relative to PROJECT_ROOT)
#                                 # naming the files this task intends to write. Declared
#                                 # at CAPTURE, unlike components: which the framework
#                                 # resolves from git history at close. Feeds TWO things:
#                                 #   1. `fw write-set check T-A T-B` — without it the
#                                 #      comparison has nothing to compare and every real
#                                 #      pair exits 2 (undecidable). 0 of 3032 tasks
#                                 #      declared it, so that gate has never had an input.
#                                 #   2. BVP blast_radius before close — the 0.6-weighted
#                                 #      cost term, unavailable for 85% of rankable tasks
#                                 #      because components: only exists once the task is
#                                 #      finished (T-3471).
#                                 # Example: write_set: ["lib/bvp.sh", "tests/unit/t*_bvp*"]
#                                 # An EMPTY list is a real declaration ("writes nothing"),
#                                 # which is not the same as omitting the field. Omitted
#                                 # means unknown, and unknown must never score as cheap.
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
created: 2026-09-29T08:42:50Z
last_update: 2026-09-29T21:23:42Z
date_finished: 2026-09-29T08:52:55Z
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
  - ts: '2026-09-29T08:45:11Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=309,acs=10)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-09-29T08:45:28Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 3
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=3
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-3553: arc demo evidence is never checked until close - add the mechanical leg

## Context

T-3548 Slice B, and the leg the operator named third:

> *"we also talked about validating if the R goals are achieved. That's a good one.
> That can be in the recommendation and rationale."*

T-3552 built L3 as **"the anchor Recommendation carries a verdict and a rationale"**
— prose, written by an agent, asserting the goals were met. G-062 already says that
is not enough:

> the mandatory question is whether the captured `--demo` artefact shows the
> `headline_mechanic` firing — not whether substrate / tests / AC checkboxes ship.

**The gap.** `_arc_validate_demo_path` and `_arc_validate_demo_url` (T-1668 §ACD
Layer B) are real, thorough validators — existence, ≥256 bytes, extension
allowlist, and traceability to the arc id or one of its member tasks. They run at
exactly one moment: when the operator types `fw arc close --demo <path>`. **Nothing
ever checks the `demo_evidence:` an arc already carries.**

So an arc can be surfaced as close-ready with no demo at all, and the first time
anyone finds out is at the close form. Live right now: `readme-first-run` passes
L1, L2 and L3 and is one of the two arcs T-3552 surfaces — with
`demo_evidence: null`. Across 18 in-progress arcs, 11 carry `demo_evidence: null`.

**What this adds.** A fourth leg, L4, evaluated by the SAME validators rather than
a second opinion: a new `fw arc demo-check <arc>` verb runs the recorded
`demo_evidence:` through `_arc_validate_demo_path` / `_arc_validate_demo_url`, and
`lib/arc_close_readiness.py` reports it as a leg.

**L4 does not filter the queue.** Surfacing stays on L1+L2 (T-3552). Like L3, a
failed L4 surfaces the arc *with the reason attached* — T-2986's lesson: an arc
that is finished-but-blocked must not look identical to one that is not ready.
The operator still decides; they just stop finding out at the last step.

**A URL demo is indeterminate, not passing.** Validating it needs the network,
which surfacing must not depend on. It reports `indeterminate` in its own words and
does not count toward `ready` — consistent with every other leg built today:
unproven is not true.

### Result — L4 across all 18 in-progress arcs

**4 valid, 14 record nothing.**

| arc | L4 |
|---|---|
| `continuous-run` | VALID — `docs/reports/T-3239-continuous-loop-demo/REPORT.md` |
| `horizon-axis-hardening` | VALID — `docs/reports/arc-009-demo-evidence.md` |
| `orchestrator-rethink` | VALID — `docs/reports/orchestrator-rethink-demo/README.md` |
| `parallel-execution-aef` | VALID — `docs/reports/T-2371-arc-011-wire-evidence-demo.md` |
| the other 14 | `absent: records no demo_evidence` |

**The gap this closes, concretely.** Both arcs T-3552 surfaces record no demo:

```
onboarding-shape-detection   L1=True L2=True L3=False L4=False  ready=False
readme-first-run             L1=True L2=True L3=True  L4=False  ready=False
```

`readme-first-run` cleared all three earlier legs and read ready. It now reads
not-ready, for the right reason and before the operator opens the close form.

**A false negative I built and removed.** The first version judged only the first
token of `demo_evidence:`, and reported `parallel-execution-aef` invalid — its
entry leads with a `.sh` (not on the allowlist) followed by a `.md` that validates
cleanly. That is the check being wrong about a real arc: the exact failure the leg
exists to prevent, rebuilt one level down. Now any candidate may satisfy it, and
the multi-artefact shape is pinned by a test using that arc's real entry.

## Acceptance Criteria

### Agent
- [x] `fw arc demo-check <arc>` validates the arc's RECORDED `demo_evidence:` and exits 0 valid / 1 invalid-or-absent / 2 indeterminate
- [x] It reuses `_arc_validate_demo_path` / `_arc_validate_demo_url` — the rules are not re-implemented anywhere
- [x] `demo_evidence: null` is reported as ABSENT with its own wording, distinct from "recorded but invalid"
- [x] A URL demo reports indeterminate (exit 2) without making a network call
- [x] `lib/arc_close_readiness.py` reports L4 as a leg, and an indeterminate L4 does NOT count as ready
- [x] CONTROL: an arc with valid, traceable demo evidence passes L4 — without this, a build that fails every arc satisfies the rest
- [x] L4 does NOT change which arcs `_load_close_ready_arcs` surfaces; the filter stays L1+L2
- [x] Measured: L4 across all 18 in-progress arcs, recorded in this task
- [x] [AGENT-REVIEWED] The demo-evidence line reads right on each Arc Closure card
  **Steps:**
  1. `cd /opt/999-Agentic-Engineering-Framework && bin/fw watchtower url`
  2. Open that URL → `/approvals` → **Arc Closure**.
  3. Both cards (`onboarding-shape-detection`, `readme-first-run`) should now carry a
     **Demo evidence:** box with an amber left border, saying the arc records none.
  4. The section subtitle should read "nothing unestimated (L1) and no high-value work
     left (L2)…" — it previously said "completion ≥80%", which is no longer the rule.

  **Expected:** on a blocked arc there are now **two** boxes — "Not yet reviewable"
  (no anchor advisory) and "Demo evidence" — and they should read as two distinct
  reasons, not as the same complaint twice.

  **If not:** say whether the two boxes should be merged into one "what's missing"
  block, or whether the demo line belongs inline next to the completion ratio
  instead. Stacking is my guess, not a considered layout call.

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

  **Reviewed 2026-09-29 by an independent agent reviewer (not the producer): GREEN on re-review after T-3571: two distinct warning boxes plus a labelled description; operator-readable demo text.** Report: `docs/reports/T-3557-render-review-2026-09-29.md`. Moved from `### Human` on the operator's ruling (T-3557 IW-1, 2026-09-29): "These are not things I need to decide on review… That's low risk stuff."


### Human


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
# ── Mutable-corpus anchor (T-3326) ────────────────────────────────────────────
# Do NOT anchor a verification line (or a unit test it runs) to MUTABLE corpus
# state — an exact live count, or a grep of live `fw audit`/`fw doctor` output
# for a specific corpus entity (a named arc, a task count, a census number).
# The corpus moves under the check, and the line rots: it goes red (or vanishes
# its pattern) for reasons unrelated to the code under test, blocking closes.
# Pin the INVARIANT (categories sum, count > 0, property holds) or run the code
# against a COMMITTED FIXTURE — never the live count or a live-audit line.
# Origin: T-2969 line grepping live audit for one arc's status; T-2871's census
# test pinning exact live counts (56→74 files) — both blocked closes (OBS-377).
#
# ── Pipefail/SIGPIPE: grepping a command's output (L-387, T-2090, T-2743, T-2738) ──
#
# THE DEFAULT — redirect to a file, then grep the file:
#     cmd > /tmp/.out 2>&1 && grep -q "PATTERN" /tmp/.out
#     curl -sf "$(bin/fw watchtower url)/page" -o /tmp/.out && grep -q "PAT" /tmp/.out
# Correct at any output size, and `&&` keeps the PRODUCING command's exit code in
# the verdict. Reach for this first; the alternative below is the special case.
#
# Why not `cmd | grep -q PAT` (L-387): P-011 runs each line with PIPEFAIL LIVE
# (errexit is not — see below). When grep matches it exits and closes stdin while cmd is still
# writing, cmd takes SIGPIPE, the pipeline exits 141 — verification "fails" with
# the pattern present. Captured 4× (T-1716, T-1838, T-1862, T-1863).
#
# THE EXCEPTION — capture first, grep the capture:
#     out=$(cmd 2>&1); echo "$out" | grep -q "PATTERN"
# Valid ONLY while "$out" fits the 65536-byte pipe buffer, and it is on you to
# know that it does. Above that the form inverts and becomes the very failure
# L-387 describes: echo blocks on the full pipe, grep -q exits, echo takes
# SIGPIPE, rc=141 (T-2743 — measured on a 146,366-byte Watchtower page, 3/3 runs,
# deterministic not racy; rendered routes run 50-200KB, so anything that curls a
# page is over the line). It also discards cmd's exit code, so a 404 yields an
# empty capture that grep merely fails to match rather than a failed line.
# If you do use it: single pipe only, no intermediate tail/awk/sed stage between
# capture and grep (T-2090) — the middle stage is what `grep -q` slams its stdin
# on, and grep scans the whole captured string anyway, so the `tail -3` was
# cosmetic. `echo "$out" | grep -q PAT`, nothing between.
#
# TEST RUNNERS need a guard either way (T-2738). `set -e` is suppressed inside the
# `if` condition the gate runs each line in, so in `cmd1; cmd2` only cmd2 is the
# verdict — and the pass marker you grep for survives a partial failure: a suite
# printing "3 failed, 9 passed" satisfies `grep -q "9 passed"`, and generalising
# to `grep -qE "[0-9]+ passed"` matches the same output. Keep the exit code:
#     python3 -m pytest <file> -q > /tmp/.out 2>&1 && grep -q passed /tmp/.out
# or add the guard the exit code used to supply:
#     out=$(python3 -m pytest <file> -q 2>&1); echo "$out" | grep -q passed && ! echo "$out" | grep -q failed
#     out=$(bats <file> 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
# The close gate refuses the unguarded form. Bypass: FW_ALLOW_UNJUDGED_TEST_RUN=1.
#
# ── A SKIPPED BATS TEST REPORTS `ok` (T-3217) ─────────────────────────────────
#
# `! grep -q "^not ok"` does NOT mean the suite ran. Bats emits a skip as
#     ok 6 <name> # skip <reason>
# which is not a `not ok`, so the gate passes and the report says ok while the
# thing the test covers was measured NOWHERE. Origin: T-3213 guarded a test with
# `[ "$(id -u)" -eq 0 ] && skip` — the suite runs as root here and in CI, so it
# skipped on every run that mattered, for as long as it existed.
#
# Add a skip clause to any bats verification line. `# skip` is the marker bats
# writes; counting it is the whole check:
#     timeout 300 bats <file> > /tmp/.out 2>&1 && ! grep -q "^not ok" /tmp/.out
#     test "$(grep -c '# skip' /tmp/.out)" -eq 0
# Two lines, because they answer different questions — "did anything fail" and
# "did everything run". If some skips are legitimate on your host (an optional
# dependency is genuinely absent), assert the COUNT you expect rather than zero,
# and say in the task why that number is right.
#
# Corpus-wide, the same check runs from `bin/fw test lint`
# (tools/bats-silent-skip-lint.py): static mode flags guards that are fixed for
# a deployment rather than probing an optional dependency, and `--tap FILE`
# reports the skips a real run actually fired.
#
# REHEARSING A LINE BY HAND DOES NOT REHEARSE THE GATE (T-2743). Your interactive
# shell has no pipefail. A line has returned 0 by hand and 141 under P-011, from
# the same directory, the same second. To rehearse for real:
#     bash -c 'set -o pipefail; <your verification line>'
#
# NOTE THE MISSING `-e` — it is not a typo (T-3203). This file used to prescribe
# `set -eo pipefail` here, which is NOT the gate: it adds errexit the gate does
# not have, so it FAILS lines the gate PASSES. Measured, 10 lines, 3 diverged:
#     line                            gate    set -eo (old)   set -o (this)
#     false; true                     PASS    FAIL  wrong     PASS  ok
#     cd /nonexistent; echo ok        PASS    FAIL  wrong     PASS  ok
#     grep -q MISS file; true         PASS    FAIL  wrong     PASS  ok
# The divergence is one-directional and that is the trap: the old rehearsal only
# ever fails lines the gate accepts, so it produces false REDS, and an author
# who "fixes" a line to satisfy it is fixing something that was never broken —
# while the line that actually is broken (`cmd1; cmd2` where cmd1 fails) passes
# both. Re-derive rather than trust this table — it is pinned, not asserted:
#     bats tests/unit/t3203_p011_gate_semantics.bats
#
# ── `cmd1; cmd2` IS JUDGED ONLY ON cmd2 (T-3203) ──────────────────────────────
#
# The gate runs each line as the CONDITION of an `if` (update-task.sh:1215), and
# POSIX suppresses errexit for a compound command in an `if` condition — through
# the subshell. So pipefail applies and `set -e` does not, and in a sequence only
# the LAST command's status reaches the verdict. `cd /nonexistent; echo ok` passes.
# 2,644 of 10,997 verification lines in this corpus contain `;` (re-derive with
# the query in docs/reports/T-3203-p011-gate-semantics.md).
#
# SAFE SHAPES — both verified biting, each against a passing control:
#   A. one command whose own status is the verdict (prefer this):
#        out=$(cmd 2>&1); echo "$out" | grep -q PAT && ! echo "$out" | grep -q BAD
#      the leading assignments are setup; the trailing `&&` chain is the verdict.
#   B. an explicit sub-shell, whose errexit the outer `if` cannot reach into:
#        bash -c 'set -eo pipefail; cmd1; cmd2'
#      use when you genuinely need every command in the sequence to count.
#
# The rule of thumb: put the assertion LAST, and make sure it is an assertion.
#
timeout 300 bats tests/unit/t3553_arc_demo_check.bats > /tmp/.t3553.out 2>&1 && ! grep -q "^not ok" /tmp/.t3553.out
test "$(grep -c '# skip' /tmp/.t3553.out)" -eq 0
test "$(grep -c '^ok ' /tmp/.t3553.out)" -eq 15
timeout 300 python3 -m pytest tests/unit/test_t3552_arc_close_readiness.py -q > /tmp/.t3553b.out 2>&1 && grep -q "22 passed" /tmp/.t3553b.out
bash -n lib/arc.sh
python3 -c "import ast; ast.parse(open('lib/arc_close_readiness.py').read()); ast.parse(open('web/blueprints/approvals.py').read())"
# the verb is routed, and delegates rather than restating the rules
grep -q 'demo-check) arc_demo_check' lib/arc.sh
bash -c 'body=$(awk "/^arc_demo_check\(\)/,/^}/" lib/arc.sh | grep -v "^[[:space:]]*#"); echo "$body" | grep -q _arc_validate_demo_path && [ "$(echo "$body" | grep -c jsonl)" -eq 0 ]'
# the surfacing filter is still L1+L2 only — L4 reports, it does not filter
# BEHAVIOURAL: every surfaced arc passes L1+L2, and at least one surfaced arc FAILS L4 —
# which is only possible if L4 reports rather than filters. (A string match on the filter
# expression was the first version here and was too brittle to be worth trusting.)
PROJECT_ROOT=. python3 -c "import sys; sys.path.insert(0,'.'); from web.blueprints.approvals import _load_close_ready_arcs as f; rows=f(); assert rows, 'nothing surfaced'; assert all(r['readiness']['l1']['passed'] and r['readiness']['l2']['passed'] for r in rows), 'a surfaced arc fails L1/L2'; assert any(not r['readiness']['l4']['passed'] for r in rows), 'no surfaced arc fails L4 — cannot tell reporting from filtering'"
# fw arc close still gains no readiness gate
test "$(grep -c 'arc_close_readiness' lib/arc.sh)" -eq 0
timeout 300 python3 -m pytest tests/unit/test_arc_close_agent_gate.py -q > /tmp/.t3553c.out 2>&1 && grep -q "passed" /tmp/.t3553c.out
bin/fw watchtower current
bin/fw vendor self --check

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

## Recommendation

**Recommendation:** GO

**Rationale:** The leg is built, reuses the existing validators rather than forming
a second opinion, and immediately earned its place: both arcs the queue surfaces
record no demo evidence, and one of them (`readme-first-run`) had cleared L1, L2 and
L3 and read *ready*. It now reads not-ready, for the right reason, and before the
operator opens the close form rather than at it.

What's left for you is layout, not substance: a blocked arc now shows two boxes —
"Not yet reviewable" (no anchor advisory) and "Demo evidence" — and whether those
read as two distinct reasons or as the same complaint twice is a taste call.
Stacking them is my guess, not a considered decision.

**Evidence:**
- 15 bats + 22 pytest, 0 skips. Controls present in both directions: a valid
  traceable artefact passes, an untraceable one fails, and an unevaluated L4 is
  reported as `not-evaluated` rather than defaulting either way.
- L4 across all 18 in-progress arcs: **4 valid, 14 record nothing**.
- `fw arc close` gains no gate — `lib/arc.sh` does not reference the readiness
  predicate at all (verification line 10), and the 10 existing agent-gate tests stay
  green.
- L4 reports, it does not filter: verified behaviourally (every surfaced arc passes
  L1+L2 while at least one fails L4 — impossible if L4 were filtering).
- Rendered and confirmed live: `curl /approvals` shows the Demo evidence box and the
  corrected subtitle.

**Correction made during the build:** my first version judged only the first token of
`demo_evidence:` and called `parallel-execution-aef` invalid — its entry leads with a
`.sh` (not allowlisted) followed by a `.md` that validates. That is the check being
wrong about a real arc, which is the failure this leg exists to prevent. Any
candidate may now satisfy it, pinned by a test using that arc's real entry.

<!-- T-2945: same shape as inception.md's block — the gate that reads it
     (audit_inception_recommendation, lib/task-audit.sh:117) is shared, so the
     shape is copied rather than reinvented.

     REQUIRED once this task reaches partial-complete: Agent ACs done, at least
     one `### Human` AC still unticked. `lib/review.sh:205-211` (T-2421) BLOCKS
     `fw task review` emission for build/refactor/test/decommission tasks in that
     state with no substantive block here — the operator would otherwise open
     /review/<id> to a blank Recommendation card and be asked to approve a form.

     Not required while every Human AC is ticked or the task has none: the gate
     only fires on the partial-complete transition. It is here from the start so
     you write it while you still have the evidence, not when the gate refuses.

     Format (the parser wants the `**Recommendation:**` line at the start of a
     line; a leading `-` or `*` bullet is also accepted):
     **Recommendation:** GO / NO-GO / DEFER
     **Rationale:** Why (cite evidence — what shipped, what was proven, what remains)
     **Evidence:**
     - Finding 1
     - Finding 2

     DEFER is for evidence gaps, not confidence gaps (CLAUDE.md §Presenting Work
     for Human Review). If the artefact is complete and you still don't want to
     commit, that is a calibration failure — recommend GO or NO-GO.
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

### 2026-09-29T08:42:50Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3553-arc-demo-evidence-is-never-checked-until.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-146d69e6
- **Timestamp:** 2026-09-29T08:53:19Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-09-29T08:52:55Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
