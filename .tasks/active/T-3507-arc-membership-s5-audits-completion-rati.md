---
id: T-3507
name: "arc membership S5: audit's completion-ratio check reads a deprecated cache
  as a fallback instead of unioning it"
description: >
  arc membership S5: audit's completion-ratio check reads a deprecated cache as a
  fallback instead of unioning it

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [arc:arc-grooming]
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
created: 2026-09-26T18:04:56Z
last_update: 2026-09-26T18:20:09Z
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
  - ts: '2026-09-26T18:15:10Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=341,acs=12)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-09-26T18:15:26Z'
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

# T-3507: arc membership S5: audit's completion-ratio check reads a deprecated cache as a fallback instead of unioning it

## Context

Closes **OBS-545**, filed during T-3501 rather than built, because the slice the
operator had approved was a different (and wrong) idea. Operator GO to proceed
2026-09-26.

`agents/audit/audit.sh:7586` — the arc-completion-ratio check (G-062 closure
pressure) reads the arc's `constituent_tasks:` list and runs the live membership
scan **only `if not items`**, i.e. as a *fallback* when the list is empty. The
comment immediately above it claims a union:

> *"T-1875 (T-NEW-11): extended to union with `arc_id:` frontmatter scan… Without
> this union, audit was blind to 163 task-arc relationships across 5 arcs after
> migration."*

The union is real but lives **inside** the fallback branch, so it unions only with
itself. Whenever `constituent_tasks:` is non-empty, the live scan never runs and the
check computes `completed/total` over a deprecated, append-only cache.

**Measured 2026-09-26:**

| arc | audit sees | actual union | hidden |
|---|---:|---:|---:|
| orchestrator-rethink | 31 | 124 | 93 |
| watchtower-redesign | 1 | 70 | 69 |
| project-shape-resilience | 6 | 18 | 12 |

**174 task-arc relationships invisible to the check.**

**Consequence, stated honestly: no verdict changes today.** All three cross the 0.80
threshold either way (31/31 = 1.00 vs 122/124 = 0.98; 1/1 vs 70/70; 5/6 = 0.83 vs
17/18 = 0.94). So this is a **latent** correctness defect whose live cost is
**reporting**: the operator is told *"31/31 tasks completed"* for an arc with 124
members, inside a WARN they are expected to act on. A ratio computed over 25% of the
population is not the ratio it claims to be, and the next arc it misreports may
straddle the threshold.

**Why the fix is a pre-loop pass, not an unconditional per-arc scan.** The check is
a shell `for` loop that spawns a fresh `python3` per arc, so nothing caches across
iterations. Simply deleting `if not items` would fire the existing inline scan for
all ~20 arcs — 20 full walks of 3,484 task files. The same O(arcs × tasks) trap
T-3503 just removed from `fw bvp arcs`, which had exceeded a 300 s timeout because
of it. So membership is computed **once** before the loop and looked up per arc.

**This also removes the fourth inline reinvention of arc membership.** The scan at
`:7586-7610` has its own tag and `arc_id` regexes, mirroring
`lib/arc.sh:_arc_tasks_for` by its own admission. Delegating to
`lib/arc_membership.py` is what audit's own T-1881 rail asks for — and note that
rail cannot see this site either, since its pattern requires a literal `grep`
(OBS-546, the next slice).

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] The check computes membership as an unconditional **union**, not a fallback.
      → `if not items and arc_slug:` is gone; `items = sorted(set(items) | scan_ids)`.
      Pinned by `t3507: the scan is no longer gated on an empty cache`.
- [x] Membership is resolved via `lib/arc_membership.py`, removing the inline
      tag/`arc_id` regexes.
      → The fourth inline reinvention of arc membership deleted. Pinned by
      `t3507: membership is delegated, not re-derived inline`.
- [x] The corpus is walked **once per run, not once per arc**, asserted by
      measurement.
      → Pre-loop index into a temp file, looked up per arc, removed after the loop.
      **`fw audit --section arc-completion` runs in 10.9 s** on the live corpus
      (3,484 tasks, 20 arcs). Had the guard simply been deleted, the existing
      per-arc scan would have fired ~20 times — the O(arcs × tasks) trap T-3503 had
      just removed from `fw bvp arcs`, which exceeded a 300 s timeout because of it.
- [x] The WARN/PASS message reports the union denominator.
      → Live, before → after: `arc-003` **31/31 → 122/124**, `arc-007`
      **1/1 → 70/70**, `arc-004` **5/6 → 17/18**.
- [x] Degrades loudly, never silently.
      → Import failure emits `Arc-completion membership DEGRADED to
      constituent_tasks: only` naming the consequence ("may under-count"), and the
      ratios still print. Two legs: absence of the banner on a healthy tree proves
      the delegation actually works, and a source assertion proves the banner is
      wired — an unreachable warning is indistinguishable from a missing one.
- [x] CONTROL LEG: an arc whose cache already matches its membership is unchanged.
      → `arc-303` reports `1/1` both before and after — **verified by running the
      suite against the pre-fix `audit.sh`**, not by inspection.
- [x] A fixture proves the union on a NON-EMPTY short cache.
      → `arc-301`: cache `["T-9001"]` plus an `arc_id:` member and a tag-only
      member → reports **3/3**. A second leg proves the union **keeps** the cache
      rather than replacing it: `T-9001` carries no membership field at all, so a
      replace-instead-of-union fix would have reported 2/2 and silently shrunk the
      arc's historical denominator.
- [x] A fixture proves the empty-cache path (T-1813) still works.
      → `arc-302` reports `2/2`. Green both before and after — correctly, since the
      fallback fired there and the answer was accidentally right.
- [x] Before/after verdicts recorded, including whether any flipped.
      → **No verdict flipped.** All three measured arcs cross the 0.80 threshold
      either way (1.00→0.98, 1.00→1.00, 0.83→0.94), so the WARN set is identical
      and only the denominators corrected. Stated plainly rather than dressed up: a
      fix that changes no verdict is still correct, and the live cost was
      misreporting a ratio the operator acts on, not a wrong decision.
- [x] `fw audit --section arc-completion` runs clean end-to-end on the live corpus.
      → 17 arc WARNs emitted, no DEGRADED banner, exit 1 (audit's normal code when
      WARNs are present).
- [x] COUNTERFACTUAL measured, not assumed: the suite was run against the pre-fix
      `audit.sh` (restored byte-identical afterwards, verified with `cmp`).
      → Legs 2, 3, 7, 8, 9, 10 **FAIL** pre-fix; legs 4 (T-1813 regression guard)
      and 5 (the control) **PASS** both ways. That is the shape a discriminating
      suite should have — if the control leg had failed pre-fix it would have been
      measuring the change rather than fencing it.

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

out=$(bats tests/unit/t3507_arc_completion_union.bats 2>&1); echo "$out" | grep -qE "^ok 10 " && ! echo "$out" | grep -qE "^not ok|# skip"
bash -n agents/audit/audit.sh
# The fallback guard must not return, and the delegation must stay.
! grep -qE '^if not items and arc_slug:' agents/audit/audit.sh
grep -q "from arc_membership import scan_tasks_by_arc_membership" agents/audit/audit.sh
# The pre-loop index must be created AND removed — a leaked mktemp per audit run
# would be a slow filesystem leak nobody notices.
grep -qF 'ARC_MEMBERSHIP_MAP="$(mktemp)"' agents/audit/audit.sh
grep -qF 'rm -f "$ARC_MEMBERSHIP_MAP"' agents/audit/audit.sh
cmp -s agents/audit/audit.sh .agentic-framework/agents/audit/audit.sh

## RCA

**Symptom:** the arc-completion-ratio check (G-062 closure pressure) reported
`31/31 tasks completed` for an arc with **124** members, `1/1` for one with 70, and
`5/6` for one with 18 — 174 task-arc relationships invisible to it.

**Root cause:** `if not items and arc_slug:` ran the live membership scan only when
`constituent_tasks:` was **empty**. The comment directly above claimed a union with
the `arc_id:` scan (T-1875), and that union was genuine — but it was written
*inside* the fallback branch, so it unioned only with itself. Any arc with a
non-empty cache had its ratio computed over a deprecated, append-only list.

**Why structurally allowed — two reinforcing reasons:**

1. **The comment described the intent, and the code implemented a narrower thing.**
   T-1875 added the `arc_id:` half *into an existing fallback* rather than promoting
   the whole thing to a union. Nothing compared the comment to the control flow, and
   a reader checking whether the union existed would have found it and stopped.
2. **Every fixture had an empty `constituent_tasks:`.** The fallback therefore fired
   in every test, so the tests exercised the correct path and the defective one was
   unreachable from the suite. The population that triggers it — a non-empty *short*
   cache — existed only in the live corpus. Same shape as T-3502's 1 KB budget,
   where every hand-written fixture was short enough to pass.

**Prevention:**
1. `t3507_arc_completion_union.bats` carries the missing population: a non-empty
   short cache plus members it omits. **Measured against the pre-fix tree**, that leg
   fails and the T-1813/control legs pass — so the suite discriminates rather than
   merely being green.
2. A leg asserts the union **keeps** the cache: a stored task carrying no membership
   field must still count, or a future "just use the scan" simplification would
   silently shrink historical denominators.
3. Verification asserts the fallback guard's *absence* and the delegation's
   *presence*, so regrowing either fails the close gate rather than needing a
   reviewer to notice.
4. **Not fixed here, filed:** OBS-546 — audit's own T-1881 rail was supposed to stop
   inline membership reinventions like the one deleted here, and cannot see it,
   because its pattern requires a literal `grep` token. That is the next slice.

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

### 2026-09-26 — deleting the guard was the wrong fix, and the reason is performance

- **What changed:** The obvious one-line fix is to delete `if not items and
  arc_slug:` so the existing inline scan always runs. That would have been correct
  and slow: the check is a shell loop spawning a fresh `python3` per arc, so nothing
  caches, and the scan walks 3,484 task files — roughly 20 walks per audit run. This
  is the same O(arcs × tasks) shape T-3503 had just removed from `fw bvp arcs`, where
  it caused a 300 s timeout. Having hit it hours earlier is the only reason I checked
  the loop structure before editing.
- **Plan impact:** The fix became a pre-loop single pass writing an index to a temp
  file, plus per-arc lookup — more code than a one-line guard removal, and it
  required adding cleanup (`rm -f`) that the one-liner would not have needed.
- **Triggered:** Nothing filed. Recorded because the cheap fix and the correct fix
  differed here, and only a measurement taken on a *different* task revealed it.

### 2026-09-26 — the suite was green against the broken code until I built the missing population

- **What changed:** Every pre-existing arc-completion fixture has an empty
  `constituent_tasks:`, so the fallback fired in all of them and the tests exercised
  the *correct* path. The defective branch was unreachable from the suite. Verified
  by running this new suite against the pre-fix `audit.sh`: the union legs fail, and
  the T-1813 and control legs pass both ways.
- **Plan impact:** Added the population that distinguishes them — a non-empty *short*
  cache — and kept the counterfactual measurement in the file header rather than as a
  claim in a commit message.
- **Triggered:** Nothing filed; it is the same class as T-3502's short-fixture
  blindness, now twice in one session on the same subsystem. Worth stating as the
  transferable form: **a fixture set assembled from the convenient shape cannot see
  the inconvenient one**, and for membership the convenient shape is "empty" while
  the live corpus is full of "partial".

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

### 2026-09-26T18:04:56Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3507-arc-membership-s5-audits-completion-rati.md
- **Context:** Initial task creation

### 2026-09-26T18:20:09Z — status-update [task-update-agent]
- **Change:** tags: +arc:arc-grooming
