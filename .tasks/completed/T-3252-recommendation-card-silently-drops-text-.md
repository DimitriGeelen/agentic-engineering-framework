---
id: T-3252
name: "Recommendation card silently drops text: any span the marker tokeniser classifies
  as other is discarded, and raw is never rendered"
description: >
  Recommendation card silently drops text: any span the marker tokeniser classifies
  as other is discarded, and raw is never rendered

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
created: 2026-09-01T22:38:02Z
last_update: 2026-09-02T08:03:25Z
date_finished: 2026-09-02T08:03:25Z
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
  - ts: '2026-09-01T22:45:09Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=312,acs=8)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-09-01T22:45:17Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 3
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=3 
      (body:prompt-meaningful); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-3252: Recommendation card silently drops text: any span the marker tokeniser classifies as other is discarded, and raw is never rendered

## Context

Reported by 001-CashWeb at chat-arc offset 956 (their G-081), alongside an unrelated
`/pending` CSRF defect filed separately as T-3251. Their diagnosis was verified here by
reading `web/shared.py:743 extract_recommendation` and then measured on this repo's own
corpus.

**The mechanism.** The section is tokenised by `_REC_MARKER_RE` — any bold label at the
start of a line, bullet prefix allowed since T-1580. Each span between markers is
bucketed by `_classify_rec_marker`, which knows four labels; everything else becomes
`other`. The loop then writes only `rationale` and `evidence` into the output, so an
`other` span is dropped along with everything up to the next recognised marker. The card
(`web/blueprints/review.py:176`) renders `rationale` and `evidence`; `raw` is never
shown. No warning, no count, no gap on the page.

Three shapes, one cause:

- **(a)** text before the first bold marker — never inside any span, so never bucketed;
- **(b)** prose after the verdict token on the Recommendation line — only the
  `GO|NO-GO|DEFER|...` match is kept and the rest of that span is discarded;
- **(c)** a span under an author's own bold label — classified `other`, dropped, and it
  takes the following bullets with it up to the next recognised marker. This is why it
  is so often the *last* bullets that vanish: it reads like length truncation and is not.

**Measured here, before any change** (`extract_recommendation` over
`.tasks/{active,completed}`, comparing the parsed `raw` line by line against
`rationale + evidence + verdict`, with the leading bold marker stripped so labels that
are dropped *by design* are not counted, and with whitespace, emphasis and link syntax
flattened on both sides):

| | |
|---|---:|
| task bodies with a `## Recommendation` section | **1057** |
| cards that drop at least one line of ≥25 chars | **601** |
| dropped fragments | **3399** |

The peer measured 26 of 46 on their corpus. 601 of 1057 here is the same class at scale.
A first pass without the marker-stripping refinement reported 1001 lossy cards — over-counting
by ~400, because a label consumed by the parser looks identical to one it lost. The
refinement is part of the measurement, not a softening of it.

**Same script, re-run after the fix** (`docs/reports/T-3252-measure-recommendation-loss.py`,
reproducible via `git stash push -- web/shared.py && python3 docs/reports/T-3252-measure-recommendation-loss.py`
against the pre-fix tree, `git stash pop` to restore — corpus is live so the body count
ticks by ±1 between runs as tasks are created/completed in the ordinary course of work;
the script itself was refined mid-task to re-derive the same marker spans
`extract_recommendation` iterates over instead of a naive per-line split, which had
mis-scored 2 cards where an author's bold span wraps a hard-wrapped line break —
see `docs/reports/T-3252-recommendation-text-loss.md` §Measurement — after; the
"before" count below is re-run with the same, final script version, not the earlier draft):

| | before | after |
|---|---:|---:|
| task bodies with a `## Recommendation` section | 1058 | 1058 |
| cards that drop at least one span of ≥25 chars | 602 | **0** |
| dropped fragments | 1452 | **0** |

Worked examples from the corpus, first dropped fragment per card:

- `T-100201` — *"CLOSE AS DISSOLVED. Do not adopt A, B, C or D."* (shape b: the operative
  instruction, on the verdict line, after the token)
- `T-1062` — *"This Recommendation rates code-and-AC completeness, not behavioral
  verification or full Phase-1 scope coverage…"* (shape a/c: the scope caveat on the
  advisory itself)
- `T-1265`, `T-1309` — *"DEFER — demand has not materialised"*, *"DEFER — superseded by
  T-1312"* (shape b: the entire reason for the deferral)

Every one of those is the sentence a decision-maker most needs. A caveat the operator
never sees does not exist for that decision.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] The loss is measured on this repo's own corpus before anything is changed: how many task bodies carry a `## Recommendation` section, how many of those lose text through `extract_recommendation`, and how many fragments. A fix argued from the code alone cannot say whether it mattered here.
- [x] No text in a `## Recommendation` section is discarded. Every one of the three shapes survives: a span before the first bold marker, a span under a marker the classifier calls `other`, and prose following the verdict token on the Recommendation line itself.
- [x] `other` spans keep their label rather than being silently merged, so a reader of the card can tell an author's own heading from one the parser understands.
- [x] A regression test covers all three shapes with a negative control: against the pre-fix parser the test goes red. Without that, a test over already-parsing text proves the parser unchanged, not fixed.
- [x] The measurement from AC 1 is re-run after the fix and the dropped-fragment count is zero, reported as the same number so the before/after is one comparison rather than two claims.
- [x] The `/review/<id>` card renders the recovered text — a fix that only reaches the parser leaves the operator seeing exactly what they saw before.

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

out=$(python3 -m pytest tests/unit/test_extract_recommendation.py -q 2>&1); echo "$out" | grep -q "32 passed" && ! echo "$out" | grep -q failed
python3 docs/reports/T-3252-measure-recommendation-loss.py > /tmp/.t3252-loss.out 2>&1 && grep -q "dropped_fragments: 0$" /tmp/.t3252-loss.out
python3 -c "import ast; ast.parse(open('web/shared.py').read())"
python3 -c "import ast; ast.parse(open('web/blueprints/review.py').read())"

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

## RCA

**Symptom:** `/review/<id>` (and `/tasks/<id>`, the side panel) render `rationale`
and `evidence` from `## Recommendation` but never `raw`. Any text the tokenizer
couldn't classify into `rationale`/`evidence`/`verdict` had nowhere to go — 602 of
1058 cards on this repo's own corpus, 3399 fragments, verified by re-running the
extractor over `.tasks/{active,completed}` and diffing `raw` against the structured
output.

**Root cause:** `extract_recommendation` (T-1575) tokenises the section by bold
marker and buckets each span, but the bucketing was closed-world: only four labels
(`recommendation`, `rationale`, `evidence`, `captured_learning`) had a destination,
and even `recommendation`'s own span only kept the verdict token, discarding any
trailing prose on the same line. Everything else — the `other` classification, text
before the first marker, verdict-line trailing prose — was dropped by the loop
itself, not lost in rendering. `raw` was computed as a "full-text fallback" but no
call site ever read it.

**Why structurally allowed:** the bug is invisible by construction. A card with
rationale + evidence looks complete regardless of what else the author wrote — there
is no count, no diff, no "N chars not shown" indicator. The T-1575 test suite
(24 tests) covered only the four recognised labels; none asserted that unrecognised
content survived anywhere, so the closed-world bucketing shipped and stayed green for
every PR since.

**Prevention:** the fix itself removes the closed-world assumption — every span the
tokenizer finds now lands in a field (`rationale`/`evidence`/`verdict`/`verdict_note`/
`other`), so there is no bucket left that silently discards. `tests/unit/test_extract_recommendation.py`
adds one test per shape plus a combined case, each with a negative-control failure
against the pre-fix parser (verified via `git stash`). `docs/reports/T-3252-measure-recommendation-loss.py`
is committed as a reusable corpus-wide check — reachable by any future contributor
who wants to re-verify the class is still fixed, not just this instance of it.

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

### 2026-09-01T22:38:02Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3252-recommendation-card-silently-drops-text-.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-5b48e2fd
- **Timestamp:** 2026-09-02T08:03:29Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-09-02T08:03:25Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
