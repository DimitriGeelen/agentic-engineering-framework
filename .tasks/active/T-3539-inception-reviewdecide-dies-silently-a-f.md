---
id: T-3539
name: "inception review/decide dies silently: a finding-signal return code killed
  by set -e, and Watchtower renders it as Unknown error"
description: >
  inception review/decide dies silently: a finding-signal return code killed by set
  -e, and Watchtower renders it as Unknown error

status: started-work
workflow_type: build
owner: agent
horizon: now
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
created: 2026-09-28T17:27:58Z
last_update: '2026-09-28T17:30:35Z'
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
  - ts: '2026-09-28T17:30:11Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=274,acs=9)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-09-28T17:30:35Z'
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

# T-3539: inception review/decide dies silently: a finding-signal return code killed by set -e, and Watchtower renders it as Unknown error

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] **`fw task review` on an undisposed inception prints its warning and succeeds**, instead of dying silently. Reproducer: `bin/fw task review T-3532` currently exits 1 with ZERO output; T-3532 has 5 undisposed Open Questions.
- [x] **All three call sites are fixed, not just the one that was reported.** `lib/review.sh:145`, `lib/inception.sh:570`, `agents/task-create/update-task.sh:848` share the identical shape, which means `fw task review`, `fw inception decide` and `fw task update --status work-completed` on an inception are all affected. Fixing only the reported one leaves the operator to rediscover the other two.
- [x] **The ambiguity is removed at the source, not only patched at the callers.** `inception_underdisposed_questions` returns non-zero to mean *"I found something"* — indistinguishable from *"I failed"*. Its contract is made explicit and its callers no longer depend on guessing which one a non-zero meant.
- [x] **A test reproduces the silent death before the fix and the warning after it**, driven through `bin/fw` — not by calling the library function directly. The bug is invisible at unit level: the function behaves correctly in isolation and only dies under the caller's `set -euo pipefail`.
- [x] **Watchtower surfaces the CLI's actual stderr instead of "Unknown error".** The operator saw *"Unknown error from fw inception decide"* — a message that cost a full diagnosis session to translate. Where the CLI exits non-zero with empty stderr, the surface says so explicitly rather than inventing a category.
- [x] **The class is registered**, not just the instance: a shell function that signals a *finding* through its exit code is a latent silent-death under any `set -e` caller. This is the THIRD instance today (`find_task_file` masked by `local` in T-3537; L-387 SIGPIPE; this one).
- [x] `bin/fw vendor self --check` clean before close.

### Human

- [ ] [REVIEW] The decision you tried to record actually records now, and if anything still fails the message tells you something usable.
  **Steps:**
  1. Open http://192.168.10.107:3002/inception/T-3532 — this is the one that gave you "Unknown error". Its five Open Questions are now disposed, so the T-2190 gate that was silently refusing it should be satisfied.
  2. Record the decision (GO, per your ruling: B then A — both slices T-3536 and T-3537 are already built and shipped).
  3. Then open http://192.168.10.107:3002/inception/T-3535 — that one is **deliberately still undisposed**, so it should refuse. Read what it says.
  **Expected:** T-3532 records. T-3535 refuses with the disposition reason spelled out — five IW questions named — not "Unknown error". A refusal that tells you which questions to dispose is the fix working; a bare category is not.
  **If not:** Send the exact text shown. If it is still "Unknown error", the CLI is dying before writing to stderr on a path this task did not reach, and the new Watchtower message should now say so explicitly — which itself narrows where to look next.

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

# THE REPRODUCER: `fw task review` on an undisposed inception now prints its warning
# and exits 0, where before it exited 1 with zero output on both streams.
bin/fw task review T-3535 > /tmp/.t3539a 2>&1 && grep -q 'NOT decision-ready' /tmp/.t3539a
# ...and a DISPOSED inception emits no warning and still hands off cleanly.
bin/fw task review T-3532 > /tmp/.t3539b 2>&1 && ! grep -q 'NOT decision-ready' /tmp/.t3539b
grep -q 'Decide:' /tmp/.t3539b
# All six regression tests, including the control proving the unguarded form dies.
timeout 300 bats tests/unit/t3539_finding_signal_set_e.bats > /tmp/.t3539c 2>&1 && ! grep -q '^not ok' /tmp/.t3539c
test "$(grep -c '# skip' /tmp/.t3539c)" -eq 0
# The caller contract is stated at the source, not only at the call sites.
grep -q 'CALLER CONTRACT' lib/inception-readiness.sh
# Watchtower names the SHAPE of a silent failure instead of a category.
grep -q 'produced NO output on either stream' web/blueprints/inception.py
# web/ touched → the running server must not be serving pre-fix bytes (T-3282, G-104).
bin/fw watchtower current
# The class outlives the instance.
grep -q 'id: OBS-566' .context/concerns.yaml
python3 -c "import yaml; yaml.safe_load(open('.context/concerns.yaml'))"
# Vendored copies in sync (lib/ and agents/ are vendored paths).
bin/fw vendor self --check

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
# Enforcement-baseline hint (L-398, T-1886): if you edited `.claude/settings.json`
# (added/removed/reorganised hooks), add `bin/fw enforcement baseline` to your
# Verification block. Otherwise the canonical hash diverges and `fw doctor`
# reports a FAIL ("Enforcement baseline CHANGED") that accumulates silently.
# Origin: T-1849/T-1730/T-1731 each added a legitimate hook without refreshing
# the baseline — FAIL sat for multiple sessions until T-1886 cleaned up.

## RCA

**Symptom (operator-reported, 2026-09-28).** Watchtower: *"T-3532: Decision not recorded /
Unknown error from fw inception decide / Resolve the issue above, then reload to retry."*
Twice, on both inceptions handed over. Operator: *"there we really have something wrong in
our inception workflow. We're missing quality text because I got two errors from that."*

On the host, `bin/fw task review T-3532` exited **1 with zero bytes on both streams**.

**Root cause.** `lib/inception-readiness.sh:inception_underdisposed_questions` returns **1
to mean "I found under-disposed questions"** — a *finding* signal, documented as such. All
three call sites captured it as `out=$(fn "$f")` with no guard, and all three run under
`set -euo pipefail`. The assignment propagates the 1, and the shell dies **at that line** —
which sits immediately *above* the warning the function exists to trigger.

**So the diagnostic destroyed the thing it was diagnosing.** The more wrong the inception
was, the more certainly the command died before saying so. A fully-disposed inception
worked fine, which is why this survived: it only fails in the case it was written for.

**Why Watchtower said "Unknown error".** It did the right thing —
`stderr or stdout or "Unknown error"`. Both were empty because the CLI died before writing
anything. The message was *honest and useless*: it named a category instead of a shape, and
pointed the reader at the web layer when the fault was two layers down in a shell library.

**Why structurally allowed.**

1. **A non-zero return that means "found" is indistinguishable from "failed."** Nothing in
   bash separates them, and `set -e` collapses both into death. The contract was documented
   correctly at the source; the hazard it creates for callers was not.
2. **All three call sites were written the same wrong way**, which means the shape was
   copied, not reasoned about. There was no rail to catch the second and third.
3. **Unit testing could never have found it.** The function is correct in isolation and
   always was. The defect lives in the *composition* of its contract with the caller's
   shell options — the failure needs the caller's `set -e` to exist at all.
4. **The blast radius was the whole workflow, not one verb.** `fw task review`,
   `fw inception decide` and `fw task update --status work-completed` on an inception all
   broke together, which is exactly why the operator's experience was *"things keep popping
   up with inception"* rather than one reproducible bug.

**This is the THIRD instance of the class today**, and the repetition is the real finding:

| # | Where | The finding-signal |
|---|---|---|
| 1 | L-387 | `cmd \| grep -q` — grep exits on match, producer takes SIGPIPE, pipeline returns 141 with the pattern present |
| 2 | T-3537 | `find_task_file` returns 1 when not found; `local x=$(…)` masked it, dropping `local` unmasked it and killed `fw context focus` silently |
| 3 | T-3539 | this one |

Each is *a non-error condition expressed as a non-zero exit, meeting a `set -e` caller, and
becoming silence.*

**Prevention** (distinct from the fix):
1. `|| true` at all three call sites, each with a comment naming why — not just the reported one.
2. A **CALLER CONTRACT** block at the function's own definition, stating in the header that
   the return code is a finding and that `set -e` callers must guard it. The producer now
   warns about the consumer hazard it creates.
3. `tests/unit/t3539_finding_signal_set_e.bats` — 6 tests including a **control that proves
   the unguarded form really dies**, because a test that cannot fail against the pre-fix
   tree measures nothing; plus a **structural test that every call site carries the guard**,
   so a fourth one added later goes red.
4. Watchtower now names the *shape* — "failed and produced NO output on either stream … that
   is a CLI-side failure, not a Watchtower one" — with the reproducer command. One read
   instead of a diagnosis session.
5. Registered as **OBS-566** so the class outlives this instance.

**Not fixed here:** the general rail. Nothing stops the *next* function from signalling a
finding through its exit code. A lint for `x=$(fn …)` where `fn` is a known finding-signal
would catch it, but the set of such functions is not declared anywhere — naming them is the
prerequisite, and that is its own unit of work.

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

**Rationale:** The reported symptom is fixed and the cause is understood, not guessed. All
three call sites of the finding-signal function are guarded, the contract is documented at
the source so the next caller is warned, and the operator's own reproducer now prints the
warning it was supposed to print all along. The one thing only the operator can confirm is
whether the Watchtower path they actually used now records the decision — hence the single
`[REVIEW]` criterion.

**Evidence:**
- `bin/fw task review T-3532` — was: exit 1, zero bytes on both streams. Now: exit 0, warning printed, decide link emitted.
- Root cause reproduced and pinned: `inception_underdisposed_questions` returns 1 as a *finding*; `out=$(fn)` under `set -euo pipefail` dies at that line, above the warning it was about to print.
- Blast radius was three verbs, not one: `fw task review`, `fw inception decide`, `fw task update --status work-completed`. All three fixed.
- 6 regression tests, including a **control proving the unguarded form really dies** and a structural test that a fourth unguarded call site would go red.
- T-3532's five Open Questions disposed with rationale drawn from T-3536/T-3537, which is what actually unblocks the decision the operator was trying to record.
- Watchtower restarted; `bin/fw watchtower current` confirms it is not serving pre-fix bytes.
- Class registered as OBS-566 — third instance in one day (L-387, T-3537, this).

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

### 2026-09-28T17:27:58Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3539-inception-reviewdecide-dies-silently-a-f.md
- **Context:** Initial task creation
