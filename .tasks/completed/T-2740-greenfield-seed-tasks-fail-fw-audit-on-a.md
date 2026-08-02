---
id: T-2740
name: "greenfield seed tasks fail fw audit on a freshly initialised project"
description: >
  greenfield seed tasks fail fw audit on a freshly initialised project

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
created: 2026-08-02T21:56:59Z
last_update: 2026-08-02T22:02:10Z
date_finished: 2026-08-02T22:02:10Z
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
  - ts: '2026-08-02T22:00:07Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-02T22:00:11Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 2
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=2
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=0 
      (no-signal); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal);
      F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2740: greenfield seed tasks fail fw audit on a freshly initialised project

## Context

A project created with `fw init` (greenfield) fails its own `fw audit` before
anyone has done a stroke of work:

```
[FAIL] CTL-027: Inception T-002 missing required sections: ## Recommendation, ## Decision
[WARN] Task T-002…T-005 missing Updates section   (×4)
```

Root cause is template drift with a second, hidden template set. `fw init` seeds
`.tasks/active/T-001..T-005` from `lib/seeds/tasks/greenfield/*.md` — a copy that
is *separate* from `.tasks/templates/{default,inception}.md`. When `audit.sh`
grows a control (CTL-027 landed in T-1263), the canonical templates get updated
and the seeds do not, because nothing runs `fw audit` against a freshly seeded
project. T-001 has `## Updates`; T-002–T-005 do not — the drift is partial, which
is why it never looked like a systematic break.

This is the worst possible first impression for the onboarding path: the very
first thing the framework tells a new user about their untouched project is that
it is already non-compliant, and the mitigation text asks them to hand-fix files
they did not write.

Diagnosed by `tests/unit/greenfield_seed_audit_prototype.bats` (T-2703), which
has been RED on disk since 2026-07-31 — and **untracked**, so the guard existed
on one machine and in no clone (OBS-131). Its author deliberately left it as
`.bats` rather than `.bats.disabled` so the failure stays visible; the note's
"move it out of tests/unit/" framing is therefore the wrong remedy. Make it pass
and commit it.

## Acceptance Criteria

### Agent
- [x] `fw audit` on a freshly `fw init`-ed greenfield project exits ≤1 — zero hard
      FAILs, and none of the four missing-Updates WARNs
- [x] Every greenfield seed carries the sections its own `workflow_type` requires,
      matching `.tasks/templates/` shape rather than a re-invented one
- [x] `tests/unit/greenfield_seed_audit_prototype.bats` passes AND is tracked in git —
      an untracked guard is a guard that exists on exactly one machine (OBS-131)
- [x] Seed section-conformance is checked mechanically, so the next control added to
      `audit.sh` cannot drift the seeds silently again — not just fixed by hand today
- [x] Fix is in the seeds, not in the audit control: CTL-027 is correct and stays

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
# stdin on. `echo "$out"` is small and immediate; grep scans the whole captured
# string anyway, so the tail-3 was cosmetic. Drop it: `echo "$out" | grep -q PAT`.
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

bats tests/unit/greenfield_seed_audit_prototype.bats > /tmp/.t2740.out 2>&1 && grep -q "^ok 3 " /tmp/.t2740.out && ! grep -q "^not ok" /tmp/.t2740.out
# the guard is in the repo, not just on this machine (OBS-131)
git ls-files --error-unmatch tests/unit/greenfield_seed_audit_prototype.bats
# every greenfield seed carries Updates — asserted over the whole seed set, not a named few
test "$(grep -l '^## Updates' lib/seeds/tasks/greenfield/*.md | wc -l)" -eq "$(ls lib/seeds/tasks/greenfield/*.md | wc -l)"
# the inception seed carries what CTL-027 demands
grep -q '^## Recommendation' lib/seeds/tasks/greenfield/T-002-define-project-goals.md
grep -q '^## Decision' lib/seeds/tasks/greenfield/T-002-define-project-goals.md

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

**Symptom:** `fw audit` on a project created seconds earlier by `fw init` reports
one hard FAIL (CTL-027: T-002 missing `## Recommendation`, `## Decision`) and four
WARNs (T-002–T-005 missing `## Updates`), on files the user never touched.

**Root cause:** two template sets for one concept. Canonical task templates live in
`.tasks/templates/`; the greenfield onboarding tasks are seeded from a separate
hardcoded set in `lib/seeds/tasks/greenfield/`. CTL-027 was added in T-1263 and
the canonical templates were updated; the seeds were not. T-001 has `## Updates`
and T-002–T-005 do not, so the drift was partial — it never read as a systematic
break, just as four tasks that happened to be untidy.

**Why structurally allowed:** nothing ever ran `fw audit` against a freshly seeded
project. Every audit in this repo runs against *this* repo, whose tasks come from
the canonical templates — so the seeds were never in the population any audit was
computed over. Same shape as T-2735/T-2737: the check was fine, the *set it ran
over* excluded the thing that was broken. The onboarding path is especially prone
to it because its artefacts only exist inside other people's projects.

Compounding: the guard that found this (T-2703's bats suite) had been red on disk
since 2026-07-31 and was **never `git add`ed** (OBS-131). `bats tests/unit/` globs
untracked files, so it ran and failed locally for whoever had it, and did not
exist in any clone. A red guard nobody owns trains everyone to ignore red; an
untracked one cannot even do that.

**Prevention:** the suite is now tracked and green, and it asserts by running the
REAL `fw audit` against a REALLY seeded project rather than against a list of
expected sections. Any control added to `audit.sh` later applies automatically —
a hand-maintained list would only cover the controls its author had in hand, which
is exactly how CTL-027 drifted past in the first place (L-533). Three tests: no
hard FAIL, no missing-Updates WARN, and the generalisation over any FAIL line.

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

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-08-02T21:56:59Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2740-greenfield-seed-tasks-fail-fw-audit-on-a.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-42ac7804
- **Timestamp:** 2026-08-02T22:02:39Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-08-02T22:02:10Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
