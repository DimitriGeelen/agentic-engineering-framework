---
id: T-5241
name: "inception readiness predicate counts the template's commented-out IW-1 example
  as a filed question, so inceptions with no real questions read 'ready for a recommendation'
  (24 found by T-5228)"
description: >
  Found by the T-5228 triage 2026-11-18: inception_handoff_blockers / inception_underdisposed_questions
  treat the inception template's commented example '- **IW-1: <question text>**' inside
  the HTML comment as a real Open Question. 24 inceptions with no real questions land
  on il_ready, and 29 of the 31 'ready' among the 43 were ready only because no real
  question was filed. One predicate in shell (lib/task-audit.sh / lib/inception-readiness.sh)
  and its Python copy (web/shared.py) must both skip HTML comments; parity tests (T-5198,
  T-3279) must cover it.

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [lib/inception-readiness.sh, web/shared.py]
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
created: 2026-11-18T22:28:53Z
last_update: 2026-11-19T23:58:10Z
date_finished: 2026-11-19T08:08:50Z
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
  - ts: '2026-11-18T22:45:29Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=302,acs=4)
    rubric_sha: e4a00f38e801
  - ts: '2026-11-19T23:00:44Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 2
      effort: 8
    rationale: blast_radius=3 (2-components); tier=2 (workflow:build); effort=8 
      (lines=368,acs=9)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-11-18T22:46:08Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
date_finalised: 2026-11-19T23:58:10Z
---

# T-5241: inception readiness predicate counts the template's commented-out IW-1 example as a filed question, so inceptions with no real questions read 'ready for a recommendation' (24 found by T-5228)

## Context

<!-- All four parts are required before source edits (T-4907). Plain language; link design docs for substantial tasks. -->
**Background / trigger:** The T-5228 triage (2026-11-18) found 24 inceptions reported "ready for a recommendation" with no real question filed; 29 of the 31 that passed the readiness check passed only that way. Registered as G-134.

**Problem / hypothesis:** The inception template's `## Open Questions` carries an HTML-commented example question, and that example includes `disposition:` and `rationale:` lines. `inception_underdisposed_questions` and the EXPLORING question count in `inception_handoff_blockers` (lib/inception-readiness.sh) read the section without dropping comments, so the example counts as one filed, disposed question. The Python transcription in web/shared.py (`_handoff_blockers_from_text`, T-5198) copies the same behaviour.

**Goal:** Comment lines in `## Open Questions` never count as questions, dispositions or rationales, in both copies, so an inception with no real question reads "no Open Questions filed yet".

**Expected outcome:** These inceptions show as EXPLORING with no questions filed instead of ready for a recommendation, in `fw inception lifecycle`, audit, the handover and Watchtower alike. Shell and Python stay in parity.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] lib/inception-readiness.sh drops HTML-comment lines from `## Open Questions` before parsing (both the disposition scan and the EXPLORING question count)
- [x] web/shared.py `_handoff_blockers_from_text` applies the same rule; the T-5198 corpus parity test passes
- [x] Fixture tests in both languages: template-only Open Questions → "no Open Questions filed yet"; a real disposed question beside the commented example → ready-for-recommendation; a real undisposed question → open count 1, not 2
- [x] Existing readiness tests stay green (t3279, t5215, t5226, disposition_gate, test_t5198_handoff_blockers, test_t5226_inception_exploring)
- [x] Corpus effect measured with `fw inception lifecycle` before and after, and reported
- [x] Vendored copies synced; Watchtower restarted and current

Measured 2026-11-19, `fw inception lifecycle`: ready for a recommendation 24 → 1 (T-4834: one real, disposed question); exploring waiting on the agent 5 → 22, on a peer 4 → 9, on the operator 3 → 4. Awaiting decision unchanged at 7. Tests: new bats 7/7 (template-only and control fail on the old code), new pytest 6/6, readiness bats 109/109, related pytest 115/115.

### Human
- [x] [REVIEW] An inception with no real questions shows as not ready in Watchtower
  **Steps:**
  1. Open http://192.168.10.107:3000/inception/T-3331 (only the template's commented example under Open Questions: the case this task fixed)
  2. Open http://192.168.10.107:3000/inception/T-4992 (four real, open questions)
  **Expected:** T-3331 shows the not-ready box saying "no Open Questions filed yet" (before the fix it read "ready for a recommendation") and no decision buttons; T-4992 shows the not-ready box with "4 question(s) open" and no decision buttons. (Examples changed 2026-11-19: the original T-5224 and T-4834 were decided since.)
  **If not:** Note which page shows the wrong state; the predicate is lib/inception-readiness.sh and its copy in web/shared.py
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

<!--
  Render-touching build tasks (web/templates, web/static, web/blueprints, web/shared.py,
  web/app.py …) add a section headed "Visual Verification" (level-2 heading) after
  Verification, with one checklist table — the check-visual-verification gate reads it
  at commit time (T-4213; T-4202 GO):

    | state | control | 1024 | 1440 | 1920 | note |
    |-------|---------|------|------|------|------|
    | toolbar | Load | ok | ok | ok | |

  Cells: ok / clipped / hidden / overlap / unreachable (non-ok needs a note). Each
  listed state needs screenshots at every UX_SHOT_WIDTHS width:
  fw ux shots <T-ID> <state>=<URL>. This comment is inert: the gate ignores it.
-->
  **Reviewer verdict:** green V-20261119-0a23245f — reviewer-judge-t-5241-r3-3e35f913a009:reviewer (rung rung-3-termlink-single-reviewer), digest af2d8931e6e9; dispatch judge-t-5241-r3-3e35f913a009; evidence: .context/reviews/evidence/T-5241/AC1-judge-t-5241-r3-3e35f913a009.md, .context/reviews/evidence/T-5241/01-inception-t-3331-judge-t-5241-r3-3e35f913a009.png, .context/reviews/evidence/T-5241/02-inception-t-4992-judge-t-5241-r3-3e35f913a009.png, .context/reviews/evidence/T-5241/no-questions@1024-judge-t-5241-r3-3e35f913a009.png, .context/reviews/evidence/T-5241/no-questions@1440-judge-t-5241-r3-3e35f913a009.png, .context/reviews/evidence/T-5241/no-questions@1920-judge-t-5241-r3-3e35f913a009.png, .context/reviews/evidence/T-5241/open-questions@1024-judge-t-5241-r3-3e35f913a009.png, .context/reviews/evidence/T-5241/open-questions@1440-judge-t-5241-r3-3e35f913a009.png, .context/reviews/evidence/T-5241/open-questions@1920-judge-t-5241-r3-3e35f913a009.png; ledger .context/reviews/verdicts.jsonl

## Verification

<!-- T-4906: guidance is an HTML comment so GitHub does not render its `#` lines as
     headings; the completion gate strips HTML comments before running anything.
     Write your commands BELOW this comment, one per line.
# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# The completion gate runs each command — if any exits non-zero, completion is blocked.
# Build/refactor/decommission tasks with NO command here are refused. If nothing can be
# run, add the line `# verification: none — <why nothing can be run>`; it is serviced
# (queued for review: add a check / other evidence / accept). See docs/reports/T-4024-servicing-loop.md.
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
# THE EXCEPTION — capture first, grep the capture with a HERE-STRING:
#     out=$(cmd 2>&1); grep -q "PATTERN" <<<"$out"
# No pipe, so no SIGPIPE at any size. Do NOT write `echo "$out" | grep -q PAT`:
# it is not safe "below 64 KB" as this file used to say (T-4921, 832 T-1340). The
# builtin writes a multi-line value line by line, so grep -q can exit before the
# last write at ANY size (measured 4 in 3,000 for a 40-line value), and above the
# pipe buffer it fails every time (T-2743: 146,366-byte page, 3/3). In a gate that
# allows on "no match" that is a fail-OPEN (T-4920: the Tier 0 pre-filter).
# The capture still discards cmd's exit code, so a 404 yields an empty capture that
# grep merely fails to match rather than a failed line — prefer THE DEFAULT above.
#
# TEST RUNNERS need a guard either way (T-2738). `set -e` is suppressed inside the
# `if` condition the gate runs each line in, so in `cmd1; cmd2` only cmd2 is the
# verdict — and the pass marker you grep for survives a partial failure: a suite
# printing "3 failed, 9 passed" satisfies `grep -q "9 passed"`, and generalising
# to `grep -qE "[0-9]+ passed"` matches the same output. Keep the exit code:
#     python3 -m pytest <file> -q > /tmp/.out 2>&1 && grep -q passed /tmp/.out
# or add the guard the exit code used to supply:
#     out=$(python3 -m pytest <file> -q 2>&1); grep -q passed <<<"$out" && ! grep -q failed <<<"$out"
#     out=$(bats <file> 2>&1); grep -q '^ok 1 ' <<<"$out" && ! grep -q '^not ok' <<<"$out"
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
#
# Vendored-path hint (T-3236, T-4419): if you edited bin/fw, lib/, agents/, policy/,
# web/, tools/ or .tasks/templates/, run `bin/fw vendor self` and add
#     bin/fw vendor self --check --task T-XXXX
# (your own task id). It checks only the files your commits changed, so another
# worker's uncommitted edit does not block your close; that drift is listed as
# "in flight, not this task". The whole-tree `--check` stays for audit/pre-push.
-->
bats tests/unit/t5241_open_questions_comments.bats
python3 -m pytest -q tests/unit/test_t5241_open_questions_comments.py
bats tests/unit/t5226_inception_exploring.bats
bats tests/unit/t3279_decision_readiness_parity.bats
python3 -c "import yaml; yaml.safe_load(open('.context/project/concerns.yaml'))"
bin/fw vendor self --check --task T-5241
bin/fw watchtower current

## Visual Verification

| state | control | 1024 | 1440 | 1920 | note |
|-------|---------|------|------|------|------|
| no-questions | not-ready box on /inception/T-3331 | ok | ok | ok | "no Open Questions filed yet"; no decision buttons |
| open-questions | not-ready box on /inception/T-4992 | ok | ok | ok | "4 question(s) open"; no decision buttons |

## RCA

**Symptom:** 24 inceptions with no real question showed as "ready for a recommendation" (T-5228 triage, 2026-11-18); they would have been invited for a verdict and then handed to the operator.

**Root cause:** the template's `## Open Questions` holds an HTML-commented example question with `disposition:` and `rationale:` lines. `inception_underdisposed_questions` and the EXPLORING count in `inception_handoff_blockers` read the section raw, so the example counted as one filed, disposed question. The Python copy (T-5198) is a line-for-line transcription and inherited it.

**Why structurally allowed:** the readiness tests built their fixtures by hand, without the template's comment, so no fixture ever had the shape every real inception has. The T-5198 parity test proved shell and Python agree, not that either is right. The `## Recommendation` parser already skipped comments; the Open Questions parser was never given the same rule.

**Prevention:** new fixtures are built from the real template comment (shell and Python), with a template-sanity test, a control for a disposition hidden in a comment, and shell/Python parity per case. Run against the old code, the template-only and control tests fail.


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
**Rationale:** Both copies of the readiness check now ignore comment lines in Open Questions, pinned by fixtures built from the real template and by shell/Python parity. The only rendered effect is which state an inception page shows; the page code itself is unchanged.
**Evidence:**
- `fw inception lifecycle`: ready for a recommendation 24 → 1 (T-4834, one real disposed question)
- Watchtower restarted; http://192.168.10.107:3000/api/instances?template=aef-inception-lifecycle lists only T-4834 at il_ready
- New tests 7/7 bats and 6/6 pytest; the template-only and control cases fail on the old code; existing readiness tests green

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

### 2026-11-18T22:28:53Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-5241-inception-readiness-predicate-counts-the.md
- **Context:** Initial task creation

### 2026-11-19T07:52:33Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

### 2026-11-19T08:08:50Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-13f3862b
- **Timestamp:** 2026-11-19T08:09:30Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Scope:** static anti-pattern scan; PASS means no anti-pattern was found, not that the criteria hold
- **Needs Human:** no
- **Findings:** 2

**Per-AC findings:**

- **AC#2 (Agent)** — web/shared.py `_handoff_blockers_from_text` applies the same rule; the T-5198 corpus parity test passes
  - **AC-verify-mismatch** (narrow, heuristic) — `path=web/shared.py in: web/shared.py `_handoff_blockers_from_text` applies the same rule; the T-5198 corpus parity test passes`
- **AC#1 (Human)** — [REVIEW] An inception with no real questions shows as not ready in Watchtower
  - **human-ac-mechanical-signal** (partial, heuristic) — `matched='shows "ready for a recommendation"' in Expected: T-5224 shows the not-ready box with its open questions and no decision buttons; T-4834 shows "ready for a recommendation" (EXPLORING with ev`
