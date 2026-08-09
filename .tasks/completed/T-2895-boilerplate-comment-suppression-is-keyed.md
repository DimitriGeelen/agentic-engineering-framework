---
id: T-2895
name: "boilerplate-comment suppression is keyed on text, not producer identity — mirror
  of 832's T-406"
description: >
  L-518 sweep of 832's T-406. tools/corpus_spec.py:_is_boilerplate_comment (T-2682)
  returns text.strip().startswith(_DI_TRAILER_PREFIX) -- a pure text match. 832 replaced
  exactly that mechanism with producer-identity gating, because when a peer's authored
  rationale is byte-identical to the boilerplate no string test can separate them;
  only provenance can. So our importer destroys any authored rationale that opens
  with the DI trailer prefix, whoever wrote it. Measured: the string is in 17 documents
  under .context/designer/projects/. CAUTION, and it is why this is not a one-line
  fix: T-2682's docstring records that the position-blind reader already laundered
  this exact trailer into the doc slot on aef-audit-cron and aef-session-lifecycle,
  both already promoted, so the text matcher is load-bearing against real observed
  corruption rather than merely defensive. Removing it without an identity-based replacement
  re-opens that. T-2891's new exporter stamp makes identity gating possible for documents
  we GENERATE, but the 17 legacy carriers name no producer at all and the designer
  save path writes client bytes verbatim, so a straight port of 832's fix does not
  cover our population. Evidence and full reasoning in T-2893.

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [tests/unit/test_corpus_spec_doc_guard.py, tools/corpus_spec.py]
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
created: 2026-08-09T11:07:44Z
last_update: 2026-08-09T12:24:55Z
date_finished: 2026-08-09T12:24:55Z
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
  - ts: '2026-08-09T11:15:08Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 7
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=7 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-09T11:15:13Z'
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

# T-2895: boilerplate-comment suppression is keyed on text, not producer identity — mirror of 832's T-406

## Context

`tools/corpus_spec.py:_is_boilerplate_comment` is `text.strip().startswith(_DI_TRAILER_PREFIX)`
— a pure text match, the same mechanism 832 replaced in their T-406. Filed at rail 497 as
the mirror image of their defect.

**832's fix does not transfer, and the reason is worth more than the fix.** They gate on
producer identity: a document naming a *different* producer cannot be carrying their own
boilerplate, so preserve it. That inference works because the boilerplate is **their**
text. Ours isn't. `BPMN DI (visual layout) omitted` originates in *their* designer, and
T-2682 records how it got into our documents: the position-blind reader adopted the
trailing comment, `generate()` re-emitted it in leading position — and that generated file
carries `exporter="aef-corpus-spec"`, our own stamp, from T-2891. **A laundered document
names us.** So porting their gate would preserve exactly the corruption T-2682 closed, on
documents already promoted (`aef-audit-cron`, `aef-session-lifecycle`).

Producer identity is informative for them and uninformative for us. The asymmetry is not a
gap in our implementation; it is which side authored the string.

**What does transfer is the loss they identified**, and we can close it on a different
axis. `startswith` destroys a comment that *begins* with the trailer and then continues
into real content. That is not hypothetical here — `tests/fixtures/832-outbound/t406-incidental-leading-boilerplate.bpmn`
(T-2893) is our real `aef-task-lifecycle/v1.bpmn` rationale with the trailer prepended, and
it currently reads back `doc: None`. Requiring the comment to be *nothing but* the trailer
keeps every byte of T-2682's protection (the 19 byte-exact carriers and the two authored
variants are all trailer-only) while preserving anything with real content after it.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] Suppression requires the comment to be **only** the trailer, not merely to start with
      it — so a rationale that opens with those words and continues into real content
      survives the read
- [x] The two known authored variants still suppress (`omitted in this authored fixture`,
      and the form dropping `in this demo`) — the tail wording drifts, which is why the
      prefix match existed in the first place; narrowing must not reopen that
- [x] Measured against both T-2893 fixtures: `t406-clean-leading-boilerplate.bpmn` still
      reads `doc: None`; `t406-incidental-leading-boilerplate.bpmn` now returns its real
      rationale rather than `None`
- [x] Every one of the 21 live `.bpmn` carriers reads back the same `doc` value before and
      after the change — a corpus-wide before/after diff, not a spot check, because the
      whole risk of this change is re-opening a hole on documents already promoted.
      **Measured: 59 files compared, exactly 1 changed, and it is the incidental fixture.**
- [x] `_is_boilerplate_comment` does **not** gate on `exporter`/producer identity, and a
      comment in the source says why — a future reader who has seen 832's T-406 will
      otherwise "fix" this to match theirs. Pinned by a test that reads the source.
- [x] Existing `tests/unit/test_corpus_spec_doc_guard.py` stays green (9 → 14)

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
# stdin on. grep scans the whole captured string anyway, so the tail-3 was
# cosmetic. Drop it: `echo "$out" | grep -q PAT`.
#
# AND ONLY WHILE THE CAPTURE IS SMALL (T-2743). The two hints above are correct
# for the captures they were written about, and both invert above the pipe
# buffer. `echo "$out" | grep -q PAT` is NOT SIGPIPE-free — it is SIGPIPE-free
# only while "$out" fits in the 65536-byte pipe buffer. Above that, with an
# early match: echo blocks on the full pipe, grep -q exits, echo takes SIGPIPE,
# pipeline exits 141 under pipefail — the exact failure L-387 exists to prevent.
# Measured: a Watchtower page is 146,366 bytes, rc=141 on 3/3 runs, deterministic
# not racy. Any line that curls a rendered page is exposed (routes run 50-200KB).
# For anything that might be large, redirect to a file:
#     cmd -o /tmp/.out && grep -q "PATTERN" /tmp/.out
#     curl -sf "$(bin/fw watchtower url)/page" -o /tmp/.out && grep -q "PAT" /tmp/.out
# This is the better default even when size is not a concern: `&&` keeps the
# PRODUCING command's exit code in the verdict, where `out=$(cmd)` discards it —
# the T-2738 problem one layer down. A 404 from curl fails the line instead of
# silently producing an empty capture for grep to not-match.
#
# REHEARSING A LINE BY HAND DOES NOT REHEARSE THE GATE (T-2743). Your interactive
# shell has no `set -eo pipefail`. The line above returned 0 when run by hand and
# 141 under P-011, from the same directory, the same second. To rehearse for real:
#     bash -c 'set -eo pipefail; <your verification line>'
#
# BUT NOT for a test runner (T-2738): the capture above discards the command's
# exit code, and `set -e` is suppressed inside the `if` condition the gate runs
# each line in — so in `cmd1; cmd2` only cmd2 is the verdict. For pytest/bats
# that exit code WAS the verdict, and the pass marker you grep instead survives
# a partial failure: a suite printing "3 failed, 9 passed" satisfies
# `grep -q "9 passed"`. Generalising to `grep -qE "[0-9]+ passed"` matches the
# same output. Either keep the exit code:
#     python3 -m pytest <file> -q > /tmp/.out 2>&1 && grep -q passed /tmp/.out
# or add the guard the exit code used to supply:
#     out=$(python3 -m pytest <file> -q 2>&1); echo "$out" | grep -q passed && ! echo "$out" | grep -q failed
#     out=$(bats <file> 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
# The close gate refuses the unguarded form. Bypass: FW_ALLOW_UNJUDGED_TEST_RUN=1.
#
# Enforcement-baseline hint (L-398, T-1886): if you edited `.claude/settings.json`
# (added/removed/reorganised hooks), add `bin/fw enforcement baseline` to your
# Verification block. Otherwise the canonical hash diverges and `fw doctor`
# reports a FAIL ("Enforcement baseline CHANGED") that accumulates silently.
# Origin: T-1849/T-1730/T-1731 each added a legitimate hook without refreshing
# the baseline — FAIL sat for multiple sessions until T-1886 cleaned up.

python3 -m pytest tests/unit/test_corpus_spec_doc_guard.py -q > /tmp/.t2895 2>&1 && grep -q "14 passed" /tmp/.t2895
python3 -m pytest tests/unit/test_importer_fidelity.py -q > /tmp/.t2895b 2>&1 && grep -q passed /tmp/.t2895b
python3 -c "import sys; sys.path.insert(0,'tools'); import corpus_spec as c; assert c._is_boilerplate_comment('BPMN DI (visual layout) omitted in this demo; x'); assert not c._is_boilerplate_comment('BPMN DI (visual layout) omitted in this demo; x\nreal rationale')"

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

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

### 2026-08-09 — recovered doc keeps the trailer line instead of editing it out

- **Chose:** when a comment is trailer + real content, return the WHOLE comment as the doc,
  junk first line included.
- **Why:** the tidier option — strip the leading trailer line, keep the rest — mangles the
  exact case this fix exists to protect. A genuine rationale whose own first line happens to
  begin with those words would lose that line. This whole defect class is silent deletion;
  the fix must not ship a smaller version of it. Preserve, never delete; a human can tidy a
  visible junk line, and cannot recover a deleted one.
- **Rejected:** strip-the-prefix (mangles authored first lines); leave `startswith` and
  accept the loss (that is the defect); port 832's producer gate (see below).

### 2026-08-09 — did NOT port 832's producer-identity fix, and this is the finding

- **Chose:** narrow the text match on the "one line only" axis; explicitly do not gate on
  `exporter`.
- **Why:** their inference is sound *for them* — the boilerplate is their designer's text,
  so a document naming a different producer cannot be carrying their trailer. On our side
  the same string arrives by laundering (T-2682: reader adopts the trailing comment,
  `generate()` re-emits it leading) and that generated file carries our own
  `exporter="aef-corpus-spec"` stamp from T-2891. **A laundered document names us.** Gating
  on identity would preserve precisely the corruption the function exists to suppress, on
  maps already promoted. The asymmetry is which side authored the string — not a gap in our
  implementation.
- **Rejected:** straight port of T-406 (re-opens T-2682 on `aef-audit-cron` and
  `aef-session-lifecycle`); belt-and-braces identity + text (same failure, since the
  identity leg would win on exactly the laundered documents).


## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-08-09T11:07:44Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2895-boilerplate-comment-suppression-is-keyed.md
- **Context:** Initial task creation

### 2026-08-09T12:16:45Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-24bde097
- **Timestamp:** 2026-08-09T12:25:01Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-08-09T12:24:55Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
