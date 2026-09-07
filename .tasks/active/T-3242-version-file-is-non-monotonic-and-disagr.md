---
id: T-3242
name: "VERSION file is non-monotonic and disagrees with release tags — 'which version
  am I on' has two answers"
description: >
  MEASURED 2026-09-01. The VERSION file at the last five release tags reads 1.6.121,
  1.6.499, 1.6.430, 1.6.176, 1.6.72 while the tags climb v1.6.764..v1.6.768 monotonically.
  So VERSION DECREASED across consecutive releases (176 -> 72 between v1.6.767 and
  v1.6.768). lib/version.sh does a plain semver patch increment, which is monotonic
  on a linear branch, so the divergence means tagged commits carried VERSION counters
  from different lines of history. Consequence: a consumer reading VERSION concludes
  it downgraded, and comparing a stable VERSION against a bleeding-edge VERSION (1.6.72
  vs 1.6.149) reads as a 77-version gap when the real relationship is 152 commits
  on one branch. The operator hit exactly this misreading. Either VERSION or the tag
  must be the single source of truth, and fw doctor should FAIL when they disagree
  on the same commit.

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: [bug, release, version, false-green]
components: [bin/fw, lib/release.sh, lib/version.sh]
related_tasks: [T-3185, T-3190]
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
created: 2026-09-01T07:34:38Z
last_update: 2026-09-07T20:15:36Z
date_finished: 2026-09-07T20:15:36Z
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
  - ts: '2026-09-01T07:45:10Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=258,acs=4)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-09-01T07:45:17Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-09-07T20:15:17Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 1
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=1 
      (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
---

# T-3242: VERSION file is non-monotonic and disagrees with release tags — 'which version am I on' has two answers

## Context

VERSION was synced from `_derive_version`'s resetting commit counter
(`major.minor.<commits-since-newest-tag>`, bin/fw:16), so at consecutive release
tags it read 1.6.176 then 1.6.72 while the tags climbed v1.6.767 → v1.6.768.
Ruling shipped here: **the release tag is canonical; VERSION mirrors it.**
Mechanism: `lib/release.sh` reconciles VERSION to the new tag in a pathspec
commit BEFORE tagging (so the tagged commit carries the version the tag names),
refuses a release that would decrease VERSION, `fw doctor` Check 1c FAILs on
VERSION-below-tag, and `fw version sync` refuses to write the resetting counter
below the tag floor. Suite: `tests/unit/t3242_version_tag_reconcile.bats` (25 tests).

Known residual (out of this task's file constraints, flag for triage): 
`agents/audit/self-audit.sh` §5.1 still FAILs on `VERSION != FW_VERSION` — under
tag-as-canonical that comparison is the wrong axis (FW_VERSION is the resetting
counter and legitimately differs from VERSION between releases). It was already
red before this task (1.6.448 vs 1.6.460); it needs re-anchoring to
`release_version_tag_parity` in a follow-up.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] **A1 Single source of truth implemented:** the release tag is canonical; at release time (`fw release tag-and-release` / `lib/release.sh`) VERSION is derived from / reconciled with the new tag so a tagged commit can never carry a VERSION below the previous tag's. The mechanism and the rejected alternative (VERSION-as-canonical) are recorded in ## Decisions
- [x] **A2 Doctor parity check:** `fw doctor` gains a cheap check comparing VERSION against the latest reachable release tag — FAIL when VERSION < tag's version or when they name different lines of history per the reconciliation rule; PASS otherwise; silent/skip when no tags are reachable (fresh clone/consumer)
- [x] **A3 Release guard:** `fw release tag-and-release --dry-run` reports the VERSION reconciliation it would perform; a release that would write a DECREASED version refuses (same refuse-family as the T-3190 fast-forward gate)
- [x] **A4 Pinned:** hermetic bats suite covers: monotonic release passes; decreasing-VERSION release refuses; doctor FAILs on a fixture repo with VERSION < tag; doctor silent with no tags; `bash -n` clean on edited files
- [x] **A5 No-widening:** existing release/version/doctor suites green; `bin/fw vendor self --check` clean for the files this task touched
  *Evidence note:* the 8 hermetic release/version suites are green (96 tests, see Verification). Two tests that assert LIVE-repo health are red for environmental reasons, not this task's widening: `self_vendor_version.bats:7` (full `vendor self --check` — another worker's uncommitted `agents/context/lib/safe-commands.sh` drifts; this task's three files are byte-identical to their vendored copies, pinned by the `cmp` Verification lines) and `t2452_doctor_quick.bats:5` (live `fw doctor --quick` exit≠2 — the mid-flight session's repo state carries other FAILs; this task's Check 1c prints `OK VERSION matches latest release tag (v1.6.768)` in that same live run, so the exit 2 is not from this check).

### Human
- [ ] [REVIEW] Tag-as-canonical is the right ruling for the release train
  **Steps:**
  1. `cd /opt/999-Agentic-Engineering-Framework && git show v1.6.768:VERSION; cat VERSION` — the tag line vs the reconciled file (now both 1.6.768-anchored)
  2. Read `## Decisions` below: tag-as-canonical was chosen over VERSION-as-canonical; consumers read VERSION (vendored copies have no `.git`, so `_derive_version` falls back to the VERSION file — it is their only identity)
  3. `cd /opt/999-Agentic-Engineering-Framework && bin/fw release tag-and-release --dry-run` — confirm the reported reconciliation ("would reconcile VERSION ... → ...") matches your intent for what a release does to VERSION
  **Expected:** you agree the tag is the single source of truth and VERSION follows it at release time; a decreasing VERSION is a refused release, not a synced file
  **If not:** the inverse ruling (VERSION-as-canonical, tags derived from VERSION) is recorded as the rejected alternative in ## Decisions — reopen this task and say which ruling should stand; the mechanism inverts cleanly (tag from VERSION instead of VERSION from tag)

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

timeout 300 bats tests/unit/t3242_version_tag_reconcile.bats > /tmp/t3242-suite.out 2>&1 && ! grep -q "^not ok" /tmp/t3242-suite.out
test "$(grep -c '# skip' /tmp/t3242-suite.out)" -eq 0
# A5: existing release/version suites. self_vendor_version.bats is excluded from this
# line ON PURPOSE: its test 7 runs a FULL `fw vendor self --check` against the live
# repo, and other workers hold uncommitted vendored files (agents/context/lib/
# safe-commands.sh) that legitimately drift — environmental, not this task's widening.
timeout 600 bats tests/unit/lib_release.bats tests/unit/lib_version.bats tests/unit/t3190_release_master_ff.bats tests/unit/t3193_release_tag_push_failure.bats tests/unit/version_relation.bats tests/unit/pre_push_version_monotonicity.bats tests/unit/fw_version_output.bats tests/unit/fw_derive_version_symlink.bats > /tmp/t3242-a5.out 2>&1 && ! grep -q "^not ok" /tmp/t3242-a5.out
test "$(grep -c '# skip' /tmp/t3242-a5.out)" -eq 0
bash -n lib/release.sh && bash -n lib/version.sh && bash -n bin/fw
# Scoped vendor check (see comment above on why not the full --check): this task's
# three edited files must be byte-identical to their vendored copies.
cmp -s lib/release.sh .agentic-framework/lib/release.sh
cmp -s lib/version.sh .agentic-framework/lib/version.sh
cmp -s bin/fw .agentic-framework/bin/fw
# The live repo itself is reconciled: VERSION equals the newest reachable tag.
bash -c 'source lib/release.sh; out=$(release_version_tag_parity "$PWD"); case "$out" in ok\ *) exit 0;; *) echo "$out"; exit 1;; esac'
# Release guard live (read-only): dry-run reports, and reports no reconciliation needed post-reconcile.
bin/fw release tag-and-release --dry-run > /tmp/t3242-dry.out 2>&1 && grep -qE "would reconcile VERSION|no reconciliation needed" /tmp/t3242-dry.out

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

**Symptom:** VERSION at the last five release tags read 1.6.121, 1.6.499, 1.6.430,
1.6.176, 1.6.72 while the tags climbed v1.6.764..v1.6.768 — VERSION DECREASED
across consecutive releases. The operator compared a stable VERSION against a
bleeding-edge VERSION and misread a 152-commit relationship as a 77-version gap.

**Root cause:** two version authorities with no reconciliation point. `_derive_version`
(bin/fw:16) computes `major.minor.<commits-since-newest-tag>` — a counter that RESETS
to ~0 at every tag — and `fw version sync` copied that counter into VERSION. Which
number VERSION carried depended on when sync last ran relative to tagging and on which
line of history the tagged commit sat, so tagged commits carried incomparable counters.

**Why structurally allowed:** the release path (`lib/release.sh`) never touched VERSION
at all — it tagged HEAD with whatever VERSION happened to be there. No gate compared
VERSION to the tag; the pre-push monotonicity gate was deliberately relaxed (T-1829)
to ALLOW forward-in-time decreases precisely because the resetting counter made them
routine — the accommodation of the symptom entrenched the disease. The T-2796
`fw version` comment documented the counter's incomparability but only annotated it.

**Prevention (distinct from the fix):** (1) `fw doctor` Check 1c FAILs whenever
VERSION < newest reachable tag — the state can no longer sit silent; (2) the release
refuses to write a decreasing VERSION (T-3190 refuse-family); (3) `fw version sync`
refuses to sync the counter below the tag floor — the writer that caused the decreases
is now gated at its own hand; (4) all three pinned in
tests/unit/t3242_version_tag_reconcile.bats (25 tests, hermetic fixtures).

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

**Recommendation:** GO
**Rationale:** Tag-as-canonical is the only ruling consistent with the release-train
model just adopted (T-3185/T-3190): tags already climb monotonically by construction
(`release_bump_version` on the previous tag), while VERSION was a derived resetting
counter with no independent authority. All four rails shipped and are pinned green;
the live repo is reconciled (VERSION = 1.6.768 = newest tag). The one Human AC asks
the operator to confirm the ruling because consumers read VERSION as their only
identity (vendored copies have no .git) — consumer blast radius warrants the check.
**Evidence:**
- tests/unit/t3242_version_tag_reconcile.bats: 25/25 ok, 0 skips (hermetic fixtures)
- Existing suites: lib_release, lib_version, t3190, t3193, version_relation, pre_push_version_monotonicity, fw_version_output, fw_derive_version_symlink — green (self_vendor_version test 7 red from ANOTHER worker's uncommitted safe-commands.sh drift, pre-existing/environmental)
- Live doctor Check 1c: "OK VERSION matches latest release tag (v1.6.768)"
- `git show v1.6.768:VERSION` still shows the old counter (history is immutable); from the NEXT release onward the tagged commit carries the tag's own version (pinned by suite test 7)

## Decisions

### 2026-09-07 — Which of the two answers is canonical
- **Chose:** the release tag. At release time `lib/release.sh` writes `${tag#v}` into VERSION (+ vendored copy) in a pathspec commit BEFORE tagging, so the tagged commit carries the version the tag names; a release that would decrease VERSION refuses.
- **Why:** under the release train the tag IS the release (T-3190: the fast-forward is the release, the tag names it), and tags are monotonic by construction. VERSION had no independent authority — it was a copy of a resetting commit counter.
- **Rejected:** VERSION-as-canonical (derive tags from VERSION). Would require making every VERSION write monotonic first — but the main writer (`fw version sync`) copies `_derive_version`'s counter, which resets at each tag; fixing that means redefining `_derive_version`, which every install's `fw --version`, version-relation logic (T-2713/L-536), and consumer-fleet checks depend on. Far larger blast radius for the same invariant.

### 2026-09-07 — Reconcile only when a VERSION file exists
- **Chose:** repos without a root VERSION file release without reconciling (no file created).
- **Why:** no file = no second answer to disagree with; and it keeps the t3190/t3193 fixtures (and consumer-shaped repos) byte-for-byte untouched by this change — A5 no-widening.
- **Rejected:** creating VERSION at release time — surprising write in repos that never carried one.

### 2026-09-07 — Guard `fw version sync` rather than redefine it
- **Chose:** `do_version_sync` refuses (exit 1, actionable stderr) when FW_VERSION < newest reachable tag; unchanged when no tags reachable.
- **Why:** sync was the writer that produced every measured decrease; gating it at the tag floor closes the regression vector without touching `_derive_version`. `_version_lt` is duplicated into version.sh (not sourced from release.sh) because version.sh must stand alone in vendored copies.
- **Rejected:** re-anchoring `do_version_check`/`do_version_audit` to the tag in the same pass — `agents/audit/self-audit.sh` §5.1 (out of this task's file constraints, another worker's territory) does its own independent FW_VERSION-vs-VERSION compare; re-anchoring one side only would make the two audits disagree. Flagged in ## Context as the follow-up.

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-09-01T07:34:38Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3242-version-file-is-non-monotonic-and-disagr.md
- **Context:** Initial task creation

### 2026-09-07T19:54:09Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-1e6b3e1e
- **Timestamp:** 2026-09-07T20:15:59Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-09-07T20:15:36Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
