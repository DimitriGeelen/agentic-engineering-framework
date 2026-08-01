---
id: T-2714
name: "doctor hook counters state their denominator (OBS-110)"
description: >
  doctor hook counters state their denominator (OBS-110)

status: started-work
workflow_type: build
owner: agent
horizon: now
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
created: 2026-08-01T09:09:02Z
last_update: '2026-08-01T09:15:09Z'
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
  - ts: '2026-08-01T09:15:06Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-01T09:15:09Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=0 
      (no-signal); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal);
      F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2714: doctor hook counters state their denominator (OBS-110)

## Context

One `fw doctor` run prints four different hook counts for one `.claude/settings.json`,
three of them under the bare word "hooks". Measured ground truth for this repo:

| doctor line | prints | actually counts | label |
|---|---|---|---|
| `Hook path validation` (bin/fw:1208) | 25 | hook commands | correct |
| `Hook exercise from /tmp` (bin/fw:1283) | 21 | commands in PreToolUse+PostToolUse **only** | count right, scope unstated |
| `Hook configuration valid` (bin/fw:1763) | 19 | **matcher entries** | **wrong — says "hooks"** |
| consumer fleet (bin/fw:2072) | 23 | distinct `fw hook` names | different denominator, unstated |

`settings.json` has 4 events → 19 matcher entries → 25 hook commands → 23 distinct
hook names (`post-compact-resume` is wired 3×).

The OBS-110 defect proper is bin/fw:1763: `sum(len(v) for v in hooks.values())`
sums the per-event *entry lists*, and each entry holds a `hooks:` array of 1..n
commands. It is a count of matchers presented as a count of hooks.

This surfaces exactly where it does most damage. An operator checking whether hooks
survived a regenerate (the T-2710 class) reads a lower number than reality, sees it
disagree with the line three rows up, and has no way to tell which one is lying —
so the check that exists to build confidence in the config removes it.

## Acceptance Criteria

### Agent
- [x] `Hook configuration valid` reports the hook-command count (25), matching `Hook path validation`, and states the matcher/event breakdown so the three numbers are reconcilable rather than contradictory
      → live: `OK  Hook configuration valid (25 hooks in 19 matchers across 4 events)`, directly under `Hook path validation: 25 hooks, all portable`
- [x] `Hook exercise from /tmp` names the event scope it probes, so its lower number reads as deliberate coverage rather than 4 missing hooks
      → live: `OK  Hook exercise from /tmp: 21 PreToolUse/PostToolUse hook(s) resolve from foreign CWD`
- [x] A bats suite pins each counter to what it counts, with a negative control that goes red if the entry-vs-command conflation is reintroduced
      → `tests/unit/doctor_hook_counters.bats` 7/7. Falsified by reverting both fixes: tests 2,3,4,5,7 go red; tests 1 and 6 stay green, correctly — they guard the fixture's premise and are meant to be insensitive to the code under test.
- [x] Ground truth is asserted from a fixture whose entry count and command count differ (a 1-entry/3-command matcher), so a fix that merely renames the label without changing the arithmetic fails
      → fixture is 19 entries / 27 commands. Falsified against the cosmetic fix (new wording `{entry_count} hooks in {entry_count} matchers`, arithmetic untouched): tests 2,3,4,7 go red. Expected values are read from the fixture at runtime, never typed into the assertions.

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
# Enforcement-baseline hint (L-398, T-1886): if you edited `.claude/settings.json`
# (added/removed/reorganised hooks), add `bin/fw enforcement baseline` to your
# Verification block. Otherwise the canonical hash diverges and `fw doctor`
# reports a FAIL ("Enforcement baseline CHANGED") that accumulates silently.
# Origin: T-1849/T-1730/T-1731 each added a legitimate hook without refreshing
# the baseline — FAIL sat for multiple sessions until T-1886 cleaned up.
bash -n bin/fw
bats tests/unit/doctor_hook_counters.bats
out=$(bin/fw doctor 2>&1); echo "$out" | grep -q "Hook configuration valid (25 hooks in 19 matchers across 4 events)"
out=$(bin/fw doctor 2>&1); echo "$out" | grep -q "PreToolUse/PostToolUse hook(s) resolve from foreign CWD"

## RCA

**Symptom:** one `fw doctor` run printed four different hook counts for one
`.claude/settings.json` — `25 hooks, all portable`, `21 hook(s) resolve`,
`19 hooks across 4 events`, `23/23 hooks` — three of them under the bare word
"hooks". The 19 was wrong outright.

**Root cause:** `sum(len(v) for v in hooks.values())` sums each event's list of
*matcher entries*. Every entry carries a `hooks:` array holding 1..n commands, so
the expression counts matchers. The label called them hooks. Live: 19 entries
holding 25 commands.

**Why structurally allowed:** the settings.json schema nests commands one level
below the thing you get by iterating an event, so the wrong count is the one that
falls out of the obvious traversal — and it is only wrong when some matcher holds
more than one command. This repo had exactly one such matcher for most of its
history (`post-compact-resume`, wired 3×), so the two numbers agreed until they
quietly didn't. Nothing compared the counters to each other: four sites each
computed a total independently, none asserted agreement, and the check that
would have caught it is the check that was wrong. Three of the four labels said
"hooks" while counting three different things, which made the disagreement look
like a display quirk rather than an arithmetic error.

**Prevention:** `tests/unit/doctor_hook_counters.bats` runs the real doctor
against a fixture built so entry count and command count *cannot* coincide (19 vs
27), and asserts the two whole-file counters agree with each other — so any future
counter that drifts from the others fails on the relationship, not on a hardcoded
number. Expected values are derived from the fixture at runtime. The negative
control asserts the fixture still reproduces the old expression's answer, so the
suite fails loudly if it ever stops being a valid witness.

**Not fixed here (one bug, one task):** the consumer-fleet line prints
`agentic-engineering-framework (v, 23/23 hooks)` — an empty version string and a
fourth denominator (distinct `fw hook` names). Filed separately rather than
folded in.

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

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-08-01T09:09:02Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2714-doctor-hook-counters-state-their-denomin.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-bee665f6
- **Timestamp:** 2026-08-01T09:25:19Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
