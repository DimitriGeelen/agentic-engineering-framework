---
id: T-2911
name: "Every consumer is missing 7 enforcement hooks incl. arc-017's onboarding gate
  — init template never mirrored hook-enable"
description: >
  Every consumer is missing 7 enforcement hooks incl. arc-017's onboarding gate —
  init template never mirrored hook-enable

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [tests/demo/arc015_capture.sh]
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
created: 2026-08-10T20:02:33Z
last_update: '2026-08-16T22:25:22Z'
date_finished: 2026-08-10T21:19:51Z
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
  - ts: '2026-08-10T20:15:09Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-10T20:15:16Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 2
      D3: 3
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=2 
      (body:telemetry-or-audit-entry); D3=3 (body:component-discoverability); 
      D4=2 (body:env-class-handled); F-RECALL=0 (no-signal); F-AUTONOMY=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:25:22Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 2
      D3: 3
      D4: 3
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=2 
      (body:telemetry-or-audit-entry); D3=3 (body:component-discoverability); 
      D4=3 (body:portability-abstraction); F-RECALL=0 (no-signal); F-AUTONOMY=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2911: Every consumer is missing 7 enforcement hooks incl. arc-017's onboarding gate — init template never mirrored hook-enable

## Context

Measured 2026-08-10 on a **real** freshly-`fw init`'d consumer (not a fixture), under
`env -i`:

| | hooks registered |
|---|---|
| this framework repo | **24** |
| any fresh consumer | **17** |

The 7 a consumer never gets: `check-arc-id`, `check-onboarding-gate`,
`check-inception-decisions`, `check-inception-schema`, `check-active-completed-dup`,
`check-heredoc-cmd-sub`, `check-settings-edit`.

**Root cause.** All 7 were added to this repo via `fw hook-enable`, which writes only
`.claude/settings.json`. The consumer's file comes from `lib/init.sh
generate_claude_code_config`, a **separate** hardcoded list that knows none of them
(`sed -n '/generate_claude_code_config()/,/^}/p' lib/init.sh | grep -c <name>` = 0 for
all seven). This is not a subtle omission: `bin/hook-enable.sh:120` carries the comment

> *"Mirrors lib/init.sh:generate_claude_code_config; both sites must change together
> (L-399 producer/consumer parity)."*

The comment names the exact failure and the exact two sites. It was broken seven times.
A prose reminder at one of two sites is not parity enforcement — same shape as L-399/T-1890
(contract shipped on one side only), and the same shape as G-079 (per-site re-derivation).

**The inversion that makes this urgent.** `check-onboarding-gate` is T-2815 — arc-017's
entire headline mechanic ("if anyone later adds an `owner:human` or agent-unresolvable
task to the gated onboarding set, the framework refuses it instead of shipping another
deadlock"). Measured:

| | onboarding tasks present | onboarding gate registered |
|---|---|---|
| this framework repo | **0** | **yes** |
| fresh consumer | **6** | **no** |

**The gate is installed only where there is nothing to guard, and absent everywhere the
thing it guards exists.** Its 38 green test legs all execute in this repo, so the suite
is green and the gate is, in deployment terms, unreachable. Sibling of the reasoning in
OBS-209 and of T-2902's class: a green reading that does not mean what it appears to.

**Corroboration from 832.** They independently reported 17 registered hooks and 21
unregistered scripts in their tree, with `git log -- .claude/settings.json` showing **2
revisions total** — their whole enforcement config arrived in the setup commit on
2026-06-04 and was never touched for 67 days (rail 517 §2, 520 §2). Their framing, which
the numbers above confirm from this side: *not a gate someone disabled, but the vendored
default never reconciled against the vendored prose.* They explicitly could not check
whether it was fleet-wide and asked whether we could. It is.

Sibling defect filed separately (one bug = one task): `fw upgrade` **detects** all 7,
names them, prints `UPDATED Hooks regenerated`, writes a `.bak`, and adds none — see the
task filed alongside this one. That defect is why no consumer could self-heal from this
one even if they noticed.

## Scope

Mirror the 7 into `generate_claude_code_config` and make the two lists impossible to
diverge again. **Do not** fix the upgrade-reporting defect here.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] A freshly `fw init`'d consumer registers the same hook **set** this repo does —
      verified by comparing the two `settings.json` files by hook name, not by count
      (a count matches for the wrong reasons the moment anything is renamed)
- [x] `check-onboarding-gate` specifically is registered in a fresh consumer, asserted by
      name — it is arc-017's whole mechanic and the reason this is urgent, so it must not
      ride on a set-comparison that a future refactor could weaken
- [x] A test fails if the two producer sites ever diverge again — `fw hook-enable`'s
      target and `generate_claude_code_config` — keyed on hook **name**, per the T-2909 S1
      measurement that name is the only key with zero false positives over history. The
      prose comment at `bin/hook-enable.sh:120` already said "both sites must change
      together"; this AC is what makes that statement load-bearing rather than advisory
- [x] The test is proven non-vacuous: it goes RED when one hook is removed from
      `generate_claude_code_config`, demonstrated in the task, not assumed. A parity test
      that passes because it compares a list to itself is the failure mode here
- [x] Any hook deliberately framework-only is named in an explicit allowlist with a
      one-line reason each, so "missing from consumers" and "intentionally framework-only"
      stop being the same observable state — the L-506 leg this whole class keeps hitting

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

bats tests/unit/hook_producer_site_parity.bats > /tmp/.t2911-parity.out 2>&1; ec=$?; cat /tmp/.t2911-parity.out; [ $ec -eq 0 ] && grep -q '^ok 6' /tmp/.t2911-parity.out
bats tests/unit/settings_regenerate_preserves_hooks.bats > /tmp/.t2911-regen.out 2>&1; ec=$?; cat /tmp/.t2911-regen.out; [ $ec -eq 0 ]

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

**Symptom:** every `fw init`'d consumer registers only 17 of the 25 governance hooks
this repo enforces on itself — including arc-017's onboarding gate, which is 0-for-0
reachable in the one repo where the test suite runs it and present nowhere the
onboarding tasks it guards actually exist.

**Root cause:** two independent producer sites write `.claude/settings.json` and
neither is derived from the other. `fw hook-enable` (`bin/hook-enable.sh`) is how this
repo's own file was built up — one ad-hoc call per hook, over 7+ separate tasks.
`generate_claude_code_config` (`lib/init.sh`) is a fixed heredoc template that every
`fw init`/`fw upgrade` regenerate writes for a consumer. Nothing keeps the second in
sync with the first; the file even carried a comment saying so (`bin/hook-enable.sh:120`)
which is exactly the failure mode this class keeps hitting (L-399 producer/consumer
parity, shipped on one side only).

**Why structurally allowed:** the comment was prose, not a gate — advisory text with no
mechanism checking it. It was violated 7 times over the life of this repo (8 counting
`check-rail-mcp-label`, added via `fw hook-enable` by a concurrent task, T-2908, one
commit before this task's own measurement — reproducing the exact defect live, mid-RCA).
No test compared the two producer sites' output before this task; the 38 tests for
`check-onboarding-gate` itself all run inside this repo, so the suite was green while
the gate was unreachable in deployment.

**Prevention:** `tests/unit/hook_producer_site_parity.bats` — name-keyed comparison
between this repo's live `.claude/settings.json` (the de facto record of every
`fw hook-enable` call) and `generate_claude_code_config`'s emitted set, plus an e2e
check against a real `fw init`'d consumer, plus an explicit framework-only allowlist so
a future intentional exception doesn't read as another instance of this bug. A negative
control (removing one hook from a temp copy of the template) proves the comparator
actually catches divergence rather than passing by comparing a list to itself.

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

**Recommendation:** GO — no Human ACs, mechanical fix + structural test, safe to close.

**Rationale:** All 5 Agent ACs are met with evidence below. `.claude/settings.json`
itself was not touched (only `lib/init.sh`), so no enforcement-baseline refresh is
needed. The fix is purely additive to the consumer template — no existing hook was
removed or reordered — and the full init/hook regression suite (30 tests across the
new file plus 4 pre-existing sibling files) is green.

**Evidence:**
- `lib/init.sh:generate_claude_code_config` now emits all 25 hook names this repo's
  own `.claude/settings.json` declares (was 17); the 8 added: `check-active-completed-dup`,
  `check-arc-id`, `check-heredoc-cmd-sub`, `check-inception-decisions`,
  `check-inception-schema`, `check-onboarding-gate`, `check-rail-mcp-label`,
  `check-settings-edit` (the 7 named in this task, plus `check-rail-mcp-label` which
  T-2908 added via `fw hook-enable` one commit before this task's own investigation —
  live reproduction of the exact defect being fixed).
- `tests/unit/hook_producer_site_parity.bats` (new, 6 tests, all green): name-keyed
  comparison between the two producer sites, an e2e check against a real `fw init`'d
  consumer, an explicit (currently empty, documented) framework-only allowlist, and a
  NEGATIVE CONTROL proving the comparator genuinely goes RED when a hook is removed
  from the template — rehearsed by stashing `lib/init.sh` and confirming the pre-fix
  tree fails test 3 by name, listing all 8 divergent hooks.
- `tests/unit/settings_regenerate_preserves_hooks.bats` (pre-existing, T-2710) still
  green — the forced-regenerate merge-preservation invariant is unaffected.
- No hook was found to be legitimately framework-only; the allowlist mechanism exists
  for the next genuine case (documented in the test file with a worked example).

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

### 2026-08-10T20:02:33Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2911-every-consumer-is-missing-7-enforcement-.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-b3248c79
- **Timestamp:** 2026-08-10T21:22:34Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-08-10T21:19:51Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
