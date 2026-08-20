---
id: T-3099
name: "GO-scope-not-propagated detector is prose-keyed and has never fired"
description: >
  The audit's GO-scope detector gates on a claim phrase; 2 of 444 completed inceptions
  match it and 0 survive the next filter, so its candidate set is empty by construction.
  Replace with a structural predicate.

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [C-004]
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
created: 2026-08-20T07:13:52Z
last_update: 2026-08-20T07:38:29Z
date_finished: 2026-08-20T07:38:29Z
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
  - ts: '2026-08-20T07:15:07Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=202,acs=4)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-20T07:15:13Z'
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
  - ts: '2026-08-20T07:26:09Z'
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
---

# T-3099: GO-scope-not-propagated detector is prose-keyed and has never fired

## Context

The audit has had a detector for un-propagated inception scope since T-2096
(`agents/audit/audit.sh:1517`). Its docstring describes the failure exactly. Its gate is a
regex over prose:

```python
CLAIM_RE = re.compile(r'filed on GO|sub-tasks (filed|created)|build slices (filed|created)'
                      r'|child tasks (filed|spun off)', re.I)
```

Measured over the corpus: **2 of 444** completed inceptions match it, and **0** of those
survive the next filter. The candidate set is empty by construction, so every
`[PASS] No GO-scope-not-propagated inception(s)` ever printed is vacuous.

Applying every filter conservatively, **54** GO'd inceptions are invisible to it — among
them T-2822, whose un-built keystone slice is why worktrees are still a live problem two
weeks after the fix for them was approved. Full analysis:
`docs/reports/T-3097-worktree-rca.md` §IW-4.

A rail keyed to how an author phrased a promise is silent precisely when the author writes
carefully — an inverse correlation with the thing being measured.

## Acceptance Criteria

### Agent
- [x] The detector's candidate gate is **structural**, not a claim phrase: a GO'd
      completed inception with `related_tasks:` empty/absent, no task back-referencing it,
      and no `unlocks_inception_decision:` pointing at it. No vocabulary anywhere in the
      predicate
- [x] The before/after candidate counts are recorded in Decisions from a real run. Baseline
      measured on this corpus: **2 of 444** completed inceptions match the claim regex and
      **0** survive the `related_tasks` filter — the candidate set is empty by construction
- [x] Output is bounded: report a count plus a small sample, with the full list reachable
      by a named command. A section that emits 50+ WARN lines on first run trains people to
      skip it, which reproduces the blindness in a different way
- [x] Severity stays **WARN**. The finding is "somebody should triage this", not "the build
      is broken", and the 54-item backlog is pre-existing debt rather than a regression
- [x] The positive line states the size of the set actually examined, not just "none found"
      — the whole defect here is a PASS that asserted nothing (same class as `audit.sh:1791`
      fabric coverage, T-2737)
- [x] Bats coverage: a fixture inception that names slices in prose the OLD regex would
      have missed is now detected; one that is properly back-referenced is not; one with
      populated `related_tasks:` is not
- [x] Mutation check recorded in Decisions: restoring the claim-phrase gate turns the
      prose-fixture test red
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

out=$(bats tests/unit/t3099_go_scope_structural.bats 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
bash -n agents/audit/audit.sh
# no vocabulary anywhere in the candidate predicate (AC #1)
# CLAIM_RE survives only in the comment recording what was removed — never as a predicate
sed -n '/^# T-2096 (OBS-036/,/^# end GO-scope-not-propagated scan/p' agents/audit/audit.sh > /tmp/.t3099blk && grep -vE "^[[:space:]]*#" /tmp/.t3099blk > /tmp/.t3099code && ! grep -q 'CLAIM_RE' /tmp/.t3099code
# the two-pass O(M+N) structure survives (T-2298)
grep -q 'Pass 2' /tmp/.t3099blk && grep -q 'referenced = set()' /tmp/.t3099blk
# the rail actually fires now, and names the size of the set examined (AC #2, #5)
timeout 300 bash agents/audit/audit.sh --section structure > /tmp/.t3099aud 2>&1 || true; grep -qE 'GO-scope-not-propagated inception\(s\) of [0-9]+ GO-recorded' /tmp/.t3099aud
# WARN, never FAIL (AC #4)
! grep -qE '^\[FAIL\].*GO-scope' /tmp/.t3099aud
diff -q agents/audit/audit.sh .agentic-framework/agents/audit/audit.sh

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

### 2026-08-20 — Structural predicate replaces the claim-phrase gate

- **Chose:** candidate = completed task with `workflow_type: inception` + a GO recorded in
  `## Decision` (`^\*\*Decision\*\*:\s*GO\b`) + `related_tasks:` empty/absent + not named on
  any task's `related_tasks:` line + not named by any `unlocks_inception_decision:` entry.
  No vocabulary anywhere in the predicate.
- **Why:** `**Decision**: GO` is a field written by `fw inception decide`, not prose an author
  composes, so it cannot drift with phrasing. Corpus check on the 444 completed inceptions:
  `GO` 345, `NO-GO` 22, `DEFER` 26+8 variants, `SUPERSEDED` 2, absent 38 — the marker is
  present and unambiguous, and the anchor makes `NO-GO` unmatchable.
- **Rejected:** widening the regex (same failure class, one vocabulary generation later);
  requiring a `## Recommendation` that "names slices" (still prose, and the RCA's conservative
  54 was derived that way — it under-counts by design).

### 2026-08-20 — Before/after candidate counts (real run, live corpus)

Both blocks extracted from `agents/audit/audit.sh` and evaluated against stub
`pass`/`warn`/`fail` with `PROJECT_ROOT` = this repo (audit.sh's global lock makes a
whole-audit run unusable as an assertion surface — same reason as T-3095).

| | old (claim-phrase gate, `git show HEAD`) | new (structural) |
|---|---|---|
| completed tasks scanned | 2705 | 2705 |
| `workflow_type: inception` | 444 | 444 |
| GO recorded | n/a (not consulted) | 347 |
| survive candidate gate | 2 (`T-2078`, `T-2118`) | 178 |
| survive `related_tasks` filter | **0** | 178 |
| emitted | `[PASS] No GO-scope-not-propagated inception(s)` | `[WARN] Found 178 … of 347 GO-recorded completed inception(s) examined` |
| wall-clock | 1.06s | 0.97s |

The old PASS was vacuous: the candidate set was empty by construction, so it asserted that a
set nothing could enter was empty. T-2822 is now finding #48 of 178, ordered most-recent-first.

**178, not the RCA's 54.** §IW-4's 54 applied two extra conservative filters ("names slices in
prose", "would not have matched the regex") to bound the claim it was making. Both are
vocabulary, so neither survives AC #1. 178 is what the structural predicate actually yields;
they are triage candidates, not 178 confirmed abandoned decisions, and the report file says so.

### 2026-08-20 — Bounded output

Evidence line carries a count + the 5 most recent ids + `(+N more)`. Full list is written to
`.context/audits/go-scope-unpropagated/LATEST.md` and named in the mitigation as
`cat <path>` — mirroring the `unclosed-satisfied/LATEST.md` precedent at `audit.sh:2538`.
178 WARN lines would have trained people to skip the section, reproducing the blindness in a
different form.

- **Also chose:** an empty pre-scan summary emits WARN ("scan did not evaluate"), not PASS.
  The `2>/dev/null` on the python3 call would otherwise convert any breakage into a green
  line — the exact defect being removed.

### 2026-08-20 — Mutation check (AC #7)

Restored `CLAIM_RE` as an additional candidate filter (the two-line mutation: re-add the regex,
re-add `if not CLAIM_RE.search(content): continue` in pass 1), re-ran the suite, reverted.

- **Red:** test 1 `prose the old regex missed: GO'd inception with no propagation is detected`
  — the named prose fixture, as AC #7 requires.
- Also red, as collateral (all three assert on the WARN the prose fixture produces): test 7
  `severity is WARN, never FAIL`, test 8 `output is bounded`, test 9 `full list is reachable by
  a named command`.
- Green before mutation: 12/12. Green after revert: 12/12. Under mutation: 8/12.

Test 1 additionally asserts the *old* regex does not match its own fixture, so it cannot pass
for the wrong reason.

### 2026-08-20 — T-2298 two-pass structure preserved

Kept the single `python3 -c` pre-scan: pass 1 walks `completed/` once (counting the examined
population and collecting candidates, caching contents), pass 2 walks `active/` once and reuses
the pass-1 cache to build the referenced-id set. Still O(M+N); measured 0.97s vs the old 1.06s.
Test 12 pins it by asserting exactly one `python3 -c` in the block and no `grep` over
`.tasks/{active,completed}` — the 30-60s fan-out T-2298 removed. Self-references are excluded
from the referenced-id set: a task naming itself is not propagation.

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-08-20T07:13:52Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3099-go-scope-not-propagated-detector-is-pros.md
- **Context:** Initial task creation

### 2026-08-20T07:26:09Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-27b1d04f
- **Timestamp:** 2026-08-20T07:39:55Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-08-20T07:38:29Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
