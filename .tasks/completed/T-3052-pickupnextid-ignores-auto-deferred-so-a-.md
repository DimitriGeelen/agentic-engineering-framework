---
id: T-3052
name: "pickup_next_id ignores auto-deferred/, so a reissued id silently overwrites
  a filed pickup"
description: >
  From T-3047 triage M-23 (ring20-dashboard P-010, 2026-06-09). Gap A: lib/pickup.sh:306
  scans inbox/processed/rejected only — PICKUP_AUTO_DEFERRED is declared at lib/pickup.sh:26
  but absent from the allocator loop. Gap B: lib/pickup.sh:424 is a plain mv with
  errors suppressed, no -i and no destination check, so the collision is silent. Two
  cooperating gaps; one lost pickup per collision.

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: [upstream-pickup, T-3047-triage]
components: [lib/pickup.sh, tests/unit/t3052_pickup_id_collision.bats]
related_tasks: [T-3047]
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
created: 2026-08-16T22:31:11Z
last_update: 2026-08-17T06:25:48Z
date_finished: 2026-08-17T06:25:48Z
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
  - ts: '2026-08-16T22:45:05Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-16T22:45:08Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-3052: pickup_next_id ignores auto-deferred/, so a reissued id silently overwrites a filed pickup

## Context

An envelope's filename is its id: `lib/pickup.sh:566` builds
`${pickup_id}-${pickup_type}.yaml`. So an id is not a label, it is a filesystem
key — reissuing one aims two different envelopes at the same path.

Two gaps have to line up, and each is harmless alone:

- **Gap A — the allocator is blind to one of the four directories.**
  `pickup_next_id` (`:306`) scans `inbox`, `processed`, `rejected`.
  `PICKUP_AUTO_DEFERRED` is declared at `:26` and used at nine other sites, but
  not here. An id parked in `auto-deferred/` is invisible to the high-water mark,
  so the next `pickup send` reissues it. This is not a stale directory being
  ignored: `:259` promotes envelopes back out of `auto-deferred/` into the inbox
  when their blocking task ships, so those files are live work waiting on a
  condition, not archive.

- **Gap B — the move that lands them is a clobbering `mv` with errors dropped.**
  `:424` and `:435` are `mv "$file" "$PICKUP_AUTO_DEFERRED/" 2>/dev/null || true`.
  `mv` overwrites without asking, so when the reissued P-NNN is auto-deferred in
  its turn it lands on top of the original. No error, no diff, no count change —
  `fw pickup status` reports the same number of deferred envelopes before and
  after, because one replaced one.

Chain: envelope A gets P-007 → auto-deferred → allocator can't see it → envelope B
is issued P-007 → B is auto-deferred → B's `mv` overwrites A. A is gone, and the
only surface that would have shown it (the deferred count) is unchanged.

Note the asymmetry that hid this: `processed/` and `rejected/` receive the same
clobbering `mv`, and are safe **only** because the allocator scans them. Gap B is
latent everywhere; Gap A decides where it fires.

Out of scope, filed separately: `pickup_next_id` is also read-then-write with no
lock, so two concurrent `pickup send` calls can both issue the same id regardless
of this fix. That is a different root cause (TOCTOU, not a missed directory) and
gets its own task per §Task Sizing: **T-3059**.

## Acceptance Criteria

### Agent
- [x] **A1 — the allocator sees all four directories.** `pickup_next_id` counts
      envelopes in `auto-deferred/`, so an id parked there is never reissued.
- [x] **A2 — no pickup file is ever overwritten by a move.** A helper moves an
      envelope into a pickup directory without clobbering: on collision it keeps
      both, files the arriving one under a distinct name, and warns on stderr
      naming both files. It echoes the destination it actually used.
- [x] **A3 — every pickup-file move goes through it.** Both auto-defer sites, the
      two reject sites, the processed site, and the auto-deferred→inbox promotion.
      Gap B is latent at all of them; A1 only removes today's trigger.
- [x] **A4 — callers that need the post-move path use the real one.** The
      triple-dedup breadcrumb (`:436`) and the channel-bridge `processed_path`
      (`:471`) currently reconstruct the destination by assuming the basename
      survived. They read the helper's echoed path instead, so a renamed arrival
      does not silently write a breadcrumb for, or mirror, the wrong file.
- [x] **A5 — each fix is independently pinned by a mutation.** Reverting A1
      alone, and reverting A2 alone, each turn a distinct test red; plus a
      positive control (L-616) proving the harness can still tell pass from fail.

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
# ── Pipefail/SIGPIPE: grepping a command's output (L-387, T-2090, T-2743, T-2738) ──
#
# THE DEFAULT — redirect to a file, then grep the file:
#     cmd > /tmp/.out 2>&1 && grep -q "PATTERN" /tmp/.out
#     curl -sf "$(bin/fw watchtower url)/page" -o /tmp/.out && grep -q "PAT" /tmp/.out
# Correct at any output size, and `&&` keeps the PRODUCING command's exit code in
# the verdict. Reach for this first; the alternative below is the special case.
#
# Why not `cmd | grep -q PAT` (L-387): P-011 runs each line under `set -eo
# pipefail`. When grep matches it exits and closes stdin while cmd is still
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
# REHEARSING A LINE BY HAND DOES NOT REHEARSE THE GATE (T-2743). Your interactive
# shell has no `set -eo pipefail`. A line has returned 0 by hand and 141 under
# P-011, from the same directory, the same second. To rehearse for real:
#     bash -c 'set -eo pipefail; <your verification line>'
#
# Enforcement-baseline hint (L-398, T-1886): if you edited `.claude/settings.json`
# (added/removed/reorganised hooks), add `bin/fw enforcement baseline` to your
# Verification block. Otherwise the canonical hash diverges and `fw doctor`
# reports a FAIL ("Enforcement baseline CHANGED") that accumulates silently.
# Origin: T-1849/T-1730/T-1731 each added a legitimate hook without refreshing
# the baseline — FAIL sat for multiple sessions until T-1886 cleaned up.

out=$(bats tests/unit/t3052_pickup_id_collision.bats 2>&1); echo "$out" | grep -q "^ok 14 " && ! echo "$out" | grep -q "^not ok"
! grep -qE 'mv "\$(file|f)" "\$PICKUP_' lib/pickup.sh
sed -n '/^pickup_next_id/,/^}/p' lib/pickup.sh > /tmp/.t3052-alloc.out && grep -q PICKUP_AUTO_DEFERRED /tmp/.t3052-alloc.out
T=$(mktemp -d); mkdir -p "$T/.context/pickup"/{inbox,processed,rejected,auto-deferred}; printf 'pickup_id: "P-007"\nORIGINAL\n' > "$T/.context/pickup/auto-deferred/P-007-learning.yaml"; printf 'pickup_id: "P-007"\nARRIVING\n' > "$T/.context/pickup/inbox/P-007-learning.yaml"; PROJECT_ROOT="$T" bash -c 'source lib/pickup.sh; [ "$(pickup_next_id)" = "P-008" ] && pickup_move_preserving "$PICKUP_INBOX/P-007-learning.yaml" "$PICKUP_AUTO_DEFERRED" >/dev/null 2>&1' && grep -q ORIGINAL "$T/.context/pickup/auto-deferred/P-007-learning.yaml" && grep -q ARRIVING "$T/.context/pickup/auto-deferred/P-007-learning.dup-1.yaml"

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

**Symptom:** a filed pickup disappears from `auto-deferred/` with no error, no
log line, and no change in any count. `fw pickup status` reports the same number
of deferred envelopes before and after, because one file replaced one file.

**Root cause:** an envelope's id *is* its filename (`:566` —
`${pickup_id}-${type}.yaml`), and the allocator that guarantees id uniqueness
(`pickup_next_id`, `:306`) scanned three of the four directories an envelope can
occupy. `auto-deferred/` was omitted. Ids parked there were reissued, and the
reissued envelope's landing was a plain `mv`, which overwrites.

**Why structurally allowed:** three things had to be true at once, and each is
individually reasonable.

1. **The omission looks like a scope decision, not a bug.** `auto-deferred/`
   reads as an archive, and archives are the sort of thing an allocator skips.
   It is not one — `:259` promotes envelopes back out of it into the inbox once
   their blocking task ships, so those files are live work waiting on a
   condition. Nothing in the code says so at the allocator; you have to already
   know `promote-deferred` exists.
2. **The failure erases its own evidence.** Every other pickup failure leaves
   something behind — a rejected file, a FAIL line, a count that moved. This one
   consumes exactly one file and produces exactly one file. There is no state in
   which the system is visibly wrong, only a state in which something that used
   to be there isn't, discoverable solely by someone who remembers filing it.
3. **The safe directories made the dangerous one look safe.** `processed/` and
   `rejected/` receive the same clobbering `mv` and have never lost anything —
   not because the move is safe, but because the allocator scans them. Six sites
   share one unsafe idiom and five are protected by an invariant that holds
   somewhere else entirely. Reading any one of them tells you nothing.

The deeper class: **a uniqueness guarantee is only as wide as the set the
allocator enumerates, and nothing forces that set to match the set the consumers
write into.** The four directory constants sit together at `:23-26`; the loop at
`:306` lists three of them. That divergence is invisible at both ends.

**Prevention** (distinct from the fix):

- The allocator now enumerates all four, and the move can no longer clobber, so
  the two gaps are closed independently — either one alone would have prevented
  the loss, which is exactly why fixing only one is tempting and wrong.
- `pickup_move_preserving` converts the class from silent to loud: any *future*
  allocator gap now produces a `dup-N` file and a WARN naming both envelopes,
  instead of a deletion. This is the part that survives the next omission.
- Verification line 2 fails if any `mv "$file" "$PICKUP_*"` reappears, so the
  unsafe idiom cannot be reintroduced by copy-paste at a seventh site.
- Mutation tests pin A1, A2 and A4 *separately* (each with the positive control
  L-616 requires), so a future change that quietly re-breaks one of them cannot
  hide behind the other two still passing.

**Not fixed here, filed as T-3059:** `pickup_next_id` is read-then-write with no
lock, so two concurrent `pickup send` calls can still issue the same id. That is
a different root cause (TOCTOU, not a missed directory) and the collision-safe
move now degrades it from data loss to a visible `dup-1` — but it is a real
remaining hole, not something this task closed.

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

### 2026-08-16T22:31:11Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3052-pickupnextid-ignores-auto-deferred-so-a-.md
- **Context:** Initial task creation

### 2026-08-17T06:10:40Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-db019de2
- **Timestamp:** 2026-08-17T06:25:52Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-08-17T06:25:48Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
