---
id: T-2912
name: "fw upgrade names 7 missing hooks, prints UPDATED Hooks regenerated, and adds
  none — non-convergent false success"
description: >
  fw upgrade names 7 missing hooks, prints UPDATED Hooks regenerated, and adds none
  — non-convergent false success

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [lib/init.sh, lib/upgrade.sh, tests/unit/t2912_upgrade_hook_regen_convergence.bats]
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
created: 2026-08-10T20:04:14Z
last_update: 2026-08-10T23:42:40Z
date_finished: 2026-08-10T23:42:40Z
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
  - ts: '2026-08-10T20:15:17Z'
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

# T-2912: fw upgrade names 7 missing hooks, prints UPDATED Hooks regenerated, and adds none — non-convergent false success

## Context

`fw upgrade` on a real consumer, measured 2026-08-10, three consecutive runs:

```
  OK       .claude/settings.json (all hooks: task gate, tier0, budget, plan blocker, …)
  UPDATED  Hooks regenerated (missing 7 hook(s): PostToolUse:check-settings-edit;
           PreToolUse:check-active-completed-dup; PreToolUse:check-arc-id;
           PreToolUse:check-heredoc-cmd-sub; PreToolUse:check-inception-decisions;
           PreToolUse:check-inception-schema; PreToolUse:check-onboarding-gate).
           Backup: settings.json.bak
```

Hook count before: **17**. After run 1: **17**. After run 2: **17**. After run 3: **17**.
Hooks actually added: **none**, ever.

Four things are wrong at once, and each one alone would be survivable:

1. **It reports an outcome it did not achieve.** `UPDATED Hooks regenerated` is a
   past-tense success claim. Nothing was added.
2. **It is non-convergent.** The identical message, naming the identical 7, on every run
   forever. A remedy that never converges is indistinguishable from one that has nothing
   to do — except that this one keeps announcing work.
3. **It writes a `.bak`.** The backup is the strongest available signal that a real
   mutation occurred. Here it is produced by a no-op, so the one artefact a careful
   operator would check for corroboration actively misleads.
4. **The line directly above says `OK … (all hooks: …)`** and lists 14 by friendly name.
   Two checks disagree in adjacent lines of the same output, and the reassuring one is
   printed first.

**Why it cannot converge.** The detector compares against the full 24-hook set; the
regenerator sources from `lib/init.sh generate_claude_code_config`, which contains 17 and
knows none of the 7. So "regenerate" faithfully reproduces the state the detector is
complaining about. The message is describing its *trigger*, not its *result* — and no
code checks whether the result differs from the trigger.

**Relationship to the sibling task.** The missing-7 parity break is filed separately.
Fixing that template makes *this specific* message stop firing — but it does not fix
this defect. The eighth hook added via `fw hook-enable` reproduces it exactly, silently,
and the consumer fleet gets no signal again. **This task is the one that must not be
closed by fixing the other.**

**Class.** Same family as T-2909 D3 (`fw enforcement baseline` launders a deleted gate),
L-506, L-570, T-2902: an operation whose reported outcome and actual outcome are
independent, where the *reassuring* reading is the default. New leg for the register:
here the false success is in a **remedy**, so the operator who does the right thing —
runs the upgrade, reads the output, sees `UPDATED`, sees a `.bak` — ends up more
confident and no more correct. 832 hit the identical shape today from the other side
(rail 520 §3): their correct outcome came from the order they happened to work in, not
from any mechanism.

## Scope

Make the hook-regeneration step verify its own effect and report what actually changed.
**Do not** mirror the missing 7 here — that is the sibling task, and doing it here would
mask this defect behind a green run.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] The hook-regeneration step compares the hook set **after** its write against the
      set **before**, and reports what actually changed — never what it intended. If it
      adds nothing, it must not print `UPDATED`
      (`lib/upgrade.sh` step 5: snapshot → regen → re-run `_t2912_hook_gap` on the result →
      `cmp` the file content; `UPDATED` only fires when content changed AND the detector
      no longer trips)
- [x] A regeneration that leaves a detected-missing hook still missing is reported as a
      **failure**, not as success. The operator must be able to tell "there was nothing
      to do" from "I tried and it did not work" — those are currently the same output
      (no mutation + gap remains → `FAILED`; mutation + gap remains → `PARTIAL`; both
      increment `failed_steps` and honour `--strict`)
- [x] No `.bak` is written when nothing changed. The backup currently corroborates a
      mutation that did not happen, which is worse than no backup
      (`.bak` only written inside the `cmp -s` else-branch, i.e. only when the file
      content actually differs)
- [x] The adjacent `OK .claude/settings.json (all hooks: …)` line cannot claim "all hooks"
      while the same run reports hooks missing — the two checks are reconciled to one
      source of truth, or the reassuring line is removed
      (`lib/init.sh` — replaced the hardcoded 14-name string with a count computed from
      the file actually on disk after the merge; it no longer claims completeness)
- [x] A test proves non-convergence is caught: run the upgrade twice against a consumer
      seeded with a hook the regenerator cannot supply, and assert the second run does not
      report success. This must be demonstrated RED against current code first — the whole
      defect is that the current behaviour looks like success, so a test written after the
      fix would pass against the bug
      (`tests/unit/t2912_upgrade_hook_regen_convergence.bats`; rehearsed RED by hand against
      pre-fix `lib/upgrade.sh`/`lib/init.sh` before committing — both runs printed `UPDATED`
      for the identical seeded gap, forever, matching the origin report exactly)
- [x] Verified against a **real** `fw init`'d consumer under `env -i`, not a fixture. This
      defect was invisible in-repo and only appeared on a real vendored consumer
      (§Consumer-Facing Command Hygiene, T-1633)
      (bats suite drives a real `.agentic-framework/bin/fw upgrade` subprocess against a
      vendored consumer via `env -i` — same pattern as
      `tests/unit/upgrade_fresh_machine_simulation.bats`)

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

bash -n lib/upgrade.sh
bash -n lib/init.sh
bats tests/unit/t2912_upgrade_hook_regen_convergence.bats > /tmp/.t2912-verif-1.out 2>&1 && grep -q "^ok 5" /tmp/.t2912-verif-1.out && ! grep -q "^not ok" /tmp/.t2912-verif-1.out
bats tests/unit/upgrade_relative_hook_path_detection.bats tests/unit/upgrade_duplicate_hook_detection.bats tests/unit/hook_producer_site_parity.bats tests/unit/t2093_upgrade_strict_exit_codes.bats tests/unit/lib_upgrade.bats tests/unit/hook_absolute_paths.bats tests/unit/settings_regenerate_preserves_hooks.bats > /tmp/.t2912-verif-2.out 2>&1 && grep -q "^ok " /tmp/.t2912-verif-2.out && ! grep -q "^not ok" /tmp/.t2912-verif-2.out
bin/fw reviewer T-2912 > /tmp/.t2912-verif-3.out 2>&1 && grep -q "Overall:.*PASS" /tmp/.t2912-verif-3.out

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

**Symptom:** `fw upgrade` printed `UPDATED  Hooks regenerated (missing 7 hook(s): …)`
on three consecutive real runs against a real consumer, naming the identical 7 hooks
every time, with a `.bak` backup written on every run and hook count staying at 17
throughout. The adjacent line claimed `OK … (all hooks: …)`.

**Root cause:** `lib/upgrade.sh` step 5 computed a "reason" string from the
BEFORE-write hook-gap detection, called `generate_claude_code_config`, then printed
`UPDATED (reason)` unconditionally — the message described the trigger, not the
result. No code path re-ran the detector after the write to check whether the gap it
just described still existed. Separately, `lib/init.sh`'s internal status line inside
that same function was a hardcoded 14-name string, unconditionally optimistic
regardless of what the write actually produced.

**Why structurally allowed:** the hook-gap detector (source of truth: the framework's
own `.claude/settings.json`) and the regenerator's template (`generate_claude_code_config`'s
fixed heredoc) are two independent producer sites (same class as T-2710/T-2911's
producer-parity gap) — nothing checked that the regenerator's OWN output satisfied the
detector that triggered it. A remedy step with no after-check is indistinguishable from
one with nothing to do, except it keeps claiming success.

**Prevention:** `lib/upgrade.sh` step 5 now snapshots before regeneration, regenerates,
then re-runs the identical detector against the result and diffs the file content.
UPDATED requires both a real file change AND a cleared detector; anything else is
FAILED/PARTIAL and increments `failed_steps` (wired into the existing `--strict`
machinery, T-2093). `.bak` is only written when content actually changed.
`tests/unit/t2912_upgrade_hook_regen_convergence.bats` pins this end-to-end against a
real vendored consumer, seeding a hook the template cannot supply and asserting two
consecutive runs both refuse to claim success.

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

### 2026-08-10T20:04:14Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2912-fw-upgrade-names-7-missing-hooks-prints-.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-00b9d0f2
- **Timestamp:** 2026-08-10T23:47:09Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

- **Suppressed:** 1 (by override)
  - AC-verify-mismatch @ AC#4 (Agent)

### 2026-08-10T23:42:40Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
