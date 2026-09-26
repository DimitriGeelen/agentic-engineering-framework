---
id: T-3504
name: "arc membership S4: fw arc help names the deprecated tag form canonical"
description: >
  arc membership S4: fw arc help names the deprecated tag form canonical

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: [arc:arc-grooming]
components: [lib/arc.sh]
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
created: 2026-09-26T13:16:57Z
last_update: 2026-09-26T13:21:24Z
date_finished: 2026-09-26T13:21:24Z
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

# T-3504: arc membership S4: fw arc help names the deprecated tag form canonical

## Context

Slice S4 of `docs/reports/T-3501-arc-mechanism-faults.md` (operator GO 2026-09-26).
Reported by the peer agent at `agent-chat-arc` @1090, who found it in their own tree
while confirming 832's `fw arc tag` report and flagged it as *"a second place where
the fix must go"* — the point being that the defect is **self-justifying for a
reader**: an agent who checks `fw arc help` before writing is told the deprecated
form is the right one.

Live here. `fw arc help` contradicts itself within 50 lines of its own output:

```
line 17: Source-of-truth is task-side arc_id: (T-1849).         <- correct
line 53: T-1851: prefer task-side arc_id: + 'fw arc tag'.       <- correct
line 67: Task tags: arc:<id> (canonical); from-T-XXXX as legacy alias
                              ^^^^^^^^^  <- the DEPRECATED form, called canonical
```

Source: `lib/arc.sh:1130` (printed) and `lib/arc.sh:34` (header comment). The wrong
statement is the **last** one a reader encounters, and it is the only one that uses
the word "canonical" about the tag namespace.

**Why this is not cosmetic.** `arc_id:` is the source of truth (T-1849); the
`arc:<slug>` tag is the pre-T-1850 legacy form that a 162-task migration moved away
from. Every membership defect repaired in this arc — S1's truncated reads, S3's
`arc_id:`-only rollups — exists because the two forms coexist. Documentation that
tells the next author the legacy form is canonical is a *producer* of that
coexistence, not a description of it.

This slice changes help text and comments only. No behaviour, no membership logic.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] `fw arc help` no longer describes the `arc:<slug>` tag namespace as canonical.
      → Now reads `Task membership: arc_id: <id> in frontmatter (canonical, T-1849)`
      / `arc:<id> tag (legacy, pre-T-1850 — still read, not written)`. The three
      membership statements in the output now agree instead of contradicting.
- [x] `lib/arc.sh:34`'s header comment is corrected the same way.
      → Rewritten to name `arc_id:` canonical and the tag legacy, with the reason
      recorded inline (including the peer's point that the old wording made the
      defect self-justifying for anyone who checked the help first).
- [x] The two ALREADY-correct statements are left intact.
      → Pinned by `t3504: the pre-existing correct statements survive`, which greps
      both verbatim. The defect was a contradiction, not a shortage of guidance.
- [x] A test asserts the contradiction cannot return, on the RENDERED output.
      → `tests/unit/t3504_arc_help_canonical_field.bats`, 7 tests. Includes a
      broader regex leg (`no line pairs the tag namespace with the word canonical`)
      so a *reworded* regression is caught, not just the exact old string, and a
      guard that the help prints membership guidance at all — otherwise every
      "must not contain" assertion would pass vacuously against empty output.
- [x] CONTROL LEG: the test fails against the pre-fix wording.
      → **Proven, not asserted:** `git show HEAD:lib/arc.sh | grep -cF 'arc:<id>
      (canonical)'` returns **1**, so the control-leg assertion would have failed
      against the pre-fix tree.
- [x] No behaviour change; existing arc suites stay green.
      → `arc_tag()` and every membership path untouched; this slice edits help text
      and comments only. **47 ok, 0 failures, 0 skips** across four arc suites
      (`arc_membership_shared`, `arc_membership_union`, `arc_dual_identity_verbs`,
      `arc_membership_agent_surfaces`).

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

out=$(bats tests/unit/t3504_arc_help_canonical_field.bats 2>&1); echo "$out" | grep -qE "^ok 7 " && ! echo "$out" | grep -qE "^not ok|# skip"
out=$(bats tests/unit/arc_membership_shared.bats tests/unit/arc_membership_union.bats tests/unit/arc_dual_identity_verbs.bats tests/unit/arc_membership_agent_surfaces.bats 2>&1); echo "$out" | grep -qE "^ok 47 " && ! echo "$out" | grep -qE "^not ok|# skip"
bash -n lib/arc.sh
cmp -s lib/arc.sh .agentic-framework/lib/arc.sh

## RCA

**Symptom:** `fw arc help` told the reader the deprecated `arc:<slug>` tag
namespace was canonical, 50 lines after telling them `arc_id:` was the source of
truth. The wrong statement was the last word, and the only one using the word
"canonical" about the tag form.

**Root cause:** the help text and the file header were written before T-1849
established `arc_id:` and T-1850 migrated 162 tasks off the tag form. The
statements that were added later (`Source-of-truth is task-side arc_id:`,
`T-1851: prefer task-side arc_id:`) were added *beside* the old one rather than
replacing it, so the file accumulated two incompatible answers to the same
question.

**Why structurally allowed:** nothing checks documentation for **internal
consistency**. Both statements are individually well-formed, both cite real task
ids, and no test reads the help output. A contradiction is invisible to every check
this repo runs — the same shape as the defects in S1 and S3, where the wrong value
was well-formed and therefore unnoticeable. And it is the most contagious of the
three: the other two produced wrong numbers, this one produced *wrong instructions
to the next author*, which is how the coexistence of two membership forms kept being
reproduced.

**Prevention:** `t3504_arc_help_canonical_field.bats` asserts the rendered help
output — not a source line, since the output is what misinforms — both that the tag
form is never called canonical (with a broad regex leg so a reworded regression is
caught) and that the correct statements survive. Plus a vacuity guard: a help
command that printed nothing would otherwise satisfy every negative assertion.

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

### 2026-09-26 — the smallest slice is the one that kept reproducing the others

- **What changed:** Filed as the cheap tidy-up of the four. Reading it in sequence
  after S1 (a truncated reader) and S3 (an `arc_id:`-only rollup) reframed it: both
  of those exist *because* two membership forms coexist, and this text is what tells
  the next author the legacy form is the right one to write. It is a producer of the
  condition the other slices repair, not a description of it.
- **Plan impact:** None to scope — the change is still two text edits. It changed
  what the RCA has to say: the defect class here is "documentation with no internal
  consistency check", which no gate in this repo can see.
- **Triggered:** Nothing filed. Worth noting the peer at @1090 had already drawn
  exactly this conclusion — they called it *"a second place where the fix must go"*
  and said the wording makes the defect *self-justifying for a reader*. That framing
  was correct and I did not improve on it.

### 2026-09-26 — a negative assertion needs a vacuity guard

- **What changed:** Four of this suite's seven tests are "the output must NOT say
  X". Every one of them passes against a help command that prints nothing at all —
  including one that crashed. Added a leg asserting the help emits membership
  guidance at all before the negatives are meaningful.
- **Plan impact:** None; it is one extra test.
- **Triggered:** Nothing. Recorded because this is the same family as T-3099
  (`warn_unenumerable` — a scan that did not evaluate must not read as one that
  found nothing) applied to an assertion rather than a scan.

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

### 2026-09-26T13:16:57Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3504-arc-membership-s4-fw-arc-help-names-the-.md
- **Context:** Initial task creation

### 2026-09-26T13:20:42Z — status-update [task-update-agent]
- **Change:** tags: +arc:arc-grooming

## Reviewer Verdict (v1.5)

- **Scan ID:** R-895443cf
- **Timestamp:** 2026-09-26T13:21:35Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-09-26T13:21:24Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
