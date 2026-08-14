---
id: T-2985
name: "corpus lint findings have no route into work — advisory, unscheduled, ungated"
description: >
  fw corpus lint is not in fw audit, not on cron, and not in any Verification block,
  so a finding persists until someone types the command. T-2984 found two that had
  stood ~4 weeks on a vendored, seed-referenced map. Decide the surfacing mechanism
  (audit section vs cron vs close-gate on corpus-touching tasks) and wire it.

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: [corpus, audit]
components: [tests/unit/t2984_session_lifecycle_lane_geometry.py]
related_tasks: [T-2984, T-2980, T-2684, T-2688, T-2689, T-2930]
arc_id: designer-corpus
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
created: 2026-08-14T11:48:30Z
last_update: 2026-08-14T12:08:07Z
date_finished: 2026-08-14T12:08:07Z
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
bvp_scores_proposed:
  - ts: '2026-08-14T11:50:19Z'
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
cost_estimate_proposed:
  - ts: '2026-08-14T12:00:08Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2985: corpus lint findings have no route into work — advisory, unscheduled, ungated

## Context

`fw corpus lint` reports only when a human types it. It is not in `fw audit`, not on cron,
not in any `## Verification` block. A finding therefore persists exactly as long as nobody
happens to run the command.

T-2984 is the worked example: `lane-geometry` (T-2684) and `lane-overflow` (T-2688/T-2689)
both fired on `aef-session-lifecycle` for ~4 weeks. That map is vendored into every consumer
by T-2942 and is the one `existing-project/T-001` routes a first-time operator to. It was
found by hand-auditing arc-014 — not a mechanism.

This is the surfacing half of arc-014's headline mechanic ("every vocabulary gap discovered
en route tracked to closure in the arc"). The detectors are the *finding* half and they work;
nothing converts a finding into work.

**Tier is WARN, not FAIL** — and that is the substantive design decision, not a hedge. The
sibling check from T-2980 (seed → corpus-map references) is FAIL because a dangling reference
is unambiguously broken and ships to new installs. Corpus-lint findings are not homogeneous:
of the two currently standing, `legacy-ref` on `t2584-scratch` is a scratch artefact and
`emitterless-typed-event` on `aef-dispatch-loop@v3` is a **real seam** — a typed catch whose
throw legitimately lives outside the corpus. A blanket FAIL would make `fw audit` exit 2 on
a correct corpus, and the reliable response to an audit that fails for a known-acceptable
reason is that people stop reading it. WARN puts every finding in the daily output where
drift becomes visible, without teaching anyone to ignore the exit code.

**Scope fence:** audit only. `fw doctor` is the usual second surface for drift classes
(cron registry, tool-set manifest) but is deliberately out of scope — doctor is the
fast-feedback path agents run mid-session, and corpus lint parses every map in the store.
If daily audit proves too slow a loop, adding doctor is a follow-up with its own evidence.

## Acceptance Criteria

### Agent
- [x] `fw audit` runs corpus lint over the store and emits one WARN per finding, each naming
      the map, the node(s), and the rule — enough to act on without re-running the linter
- [x] Zero findings emits a PASS line carrying the scanned-map count (same shape as T-2980's
      `All N onboarding-seed corpus references resolve...`), so "clean" is distinguishable
      from "did not run"
- [x] Findings are WARN tier: with findings present `fw audit` exits ≤ 1, never 2 — pinned by
      a test, since the tier IS the decision and a later blanket-FAIL would be silent
- [x] Degrades silently where the linter or store is absent (vendored consumers without
      `tools/corpus_lint.py`, fresh projects with no `.context/designer/projects/`) — no
      traceback, no spurious WARN, no PASS line claiming a scan that did not happen
- [x] A test asserts the check sees the REAL store in this checkout, not just fixtures —
      the T-2980 lesson: a scan that drifts from what it claims to cover leaves every
      fixture test green
- [x] The two currently-standing findings (`t2584-scratch` legacy-ref, `aef-dispatch-loop`
      emitterless-typed-event) appear as WARNs rather than being suppressed — if they are
      acceptable, that is a judgement to record against them, not a reason to hide them

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

out=$(timeout 580 bats tests/unit/audit_corpus_lint_findings.bats 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
bash -n agents/audit/audit.sh
grep -q "T-2985 (arc-014, designer-corpus): corpus-lint findings reach the daily audit" agents/audit/audit.sh
out=$(bin/fw doctor 2>&1); ! echo "$out" | grep -q "Self-vendor drift"

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

### 2026-08-14 — the mechanism question answered itself; the test found a real contract

- **What changed:** Filed as "decide the surfacing mechanism (audit vs cron vs close-gate)",
  expecting that to be the work. It was not a real fork. `fw audit` already runs daily on
  cron, so an audit section *is* the cron option, and a close-gate only fires on tasks that
  touch corpus files — which is precisely the population that does not need reminding. Audit
  section, no inception needed.
- **Plan impact:** The genuine decision turned out to be the **tier**, not the surface, and
  it inverts the T-2980 sibling directly above it in the same file. Seed→map references are
  homogeneous (dangling is always broken → FAIL). Corpus findings are not: one of the two
  standing findings is a real seam. So the reasoning had to be written down *at the divergence*
  rather than left as an unexplained inconsistency between adjacent checks.
- **Triggered:** The real-store test initially failed with "no corpus lines at all" — but the
  audit had exited 75 (EX_TEMPFAIL) because the daily cron audit held the lock. T-2930/OBS-221
  chose 75 over 0 specifically so readers could distinguish contention from a verdict, and the
  test was ignoring that contract with `|| true`. Fixed to skip on 75. Worth noting as a class:
  a test that asserts through a lock is flaky exactly on the hosts where the thing it tests is
  actually scheduled. Verified the test passes for real once the lock cleared, since a skip
  proves nothing.

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

### 2026-08-14T11:48:30Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2985-corpus-lint-findings-have-no-route-into-.md
- **Context:** Initial task creation

### 2026-08-14T11:50:19Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-3c37167f
- **Timestamp:** 2026-08-14T12:15:43Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 4
     - evidence: `out=$(bin/fw doctor 2>&1); ! echo "$out" | grep -q "Self-vendor drift"`

### 2026-08-14T12:08:07Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
