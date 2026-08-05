---
id: T-2788
name: "sweep: bats fixture paths built on an unguarded $PROJECT_ROOT"
description: >
  106 bats files build fixture paths as mkdir -p "$PROJECT_ROOT/.tasks/active" with
  $PROJECT_ROOT assigned inside each file's own setup(). Unset at that moment the
  path is literally /.tasks/active. This is the writer behind T-2787's filesystem-root
  pollution. Audit the 106 call sites, add a shared guard that refuses an empty or
  / root, and pin it with a test that proves the guard fires.

status: started-work
workflow_type: refactor
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
created: 2026-08-04T13:10:55Z
last_update: 2026-08-04T23:48:05Z
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
bvp_scores_proposed:
  - ts: '2026-08-04T13:14:38Z'
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
  - ts: '2026-08-04T13:15:08Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 3
      effort: 7
    rationale: blast_radius=0 (no-signal); tier=3 (no-signal); effort=7 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2788: sweep: bats fixture paths built on an unguarded $PROJECT_ROOT

## Context

T-2787 is the detective (asserts `/` carries no framework markers, currently
RED — the operator's Tier-0 cleanup is out of scope here). T-2788 is the
writer-side fix: `tests/test_helper.bash` gained `guard_project_root()`,
called immediately after the `PROJECT_ROOT` assignment in every real call
site, refusing empty/`/`/out-of-temp-dir values before any `mkdir` runs.

## Call Site Inventory (re-derived at close)

`grep -rl 'mkdir -p "\$PROJECT_ROOT' tests/ --include='*.bats'` returns 108
hits today (was 107 at filing — the delta is `tests/unit/guard_project_root.bats`,
this task's own proof file, added below). Two hits are **not** real call
sites — they mention the pattern in prose/demonstration strings, not in a
live fixture-building `setup()`:

- `tests/unit/no_root_framework_markers.bats` — T-2787's detective test;
  the string appears only in a comment and in the operator-facing remedy
  message it prints on failure.
- `tests/unit/guard_project_root.bats` — this task's own proof file; the
  string appears inside a `run bash -c "..."` demonstration body.

That leaves **106 real call sites**, matching the count at filing. Full list:

<details>
<summary>106 files (click to expand)</summary>

- tests/governance/test_checkpoint_handover_recorded.bats
- tests/governance/test_precompact_handover_robust.bats
- tests/integration/audit_blocks_review_and_decide.bats
- tests/integration/budget_gate.bats
- tests/integration/check_active_task.bats
- tests/integration/check_fabric_new_file.bats
- tests/integration/check_project_boundary.bats
- tests/integration/check_tier0.bats
- tests/integration/cron_install.bats
- tests/integration/fw_approvals.bats
- tests/integration/fw_ask.bats
- tests/integration/fw_assumption.bats
- tests/integration/fw_audit.bats
- tests/integration/fw_build.bats
- tests/integration/fw_bus.bats
- tests/integration/fw_consolidate.bats
- tests/integration/fw_context.bats
- tests/integration/fw_cron.bats
- tests/integration/fw_decisions.bats
- tests/integration/fw_dispatch.bats
- tests/integration/fw_docs.bats
- tests/integration/fw_doctor.bats
- tests/integration/fw_enforcement.bats
- tests/integration/fw_fix_learned.bats
- tests/integration/fw_gaps.bats
- tests/integration/fw_git.bats
- tests/integration/fw_handover.bats
- tests/integration/fw_harvest.bats
- tests/integration/fw_healing.bats
- tests/integration/fw_inception.bats
- tests/integration/fw_learnings.bats
- tests/integration/fw_mcp.bats
- tests/integration/fw_metrics.bats
- tests/integration/fw_note.bats
- tests/integration/fw_notify.bats
- tests/integration/fw_onboarding.bats
- tests/integration/fw_patterns.bats
- tests/integration/fw_pickup.bats
- tests/integration/fw_plugin_audit.bats
- tests/integration/fw_practices.bats
- tests/integration/fw_promote.bats
- tests/integration/fw_recall.bats
- tests/integration/fw_resume.bats
- tests/integration/fw_scan.bats
- tests/integration/fw_search.bats
- tests/integration/fw_self_audit.bats
- tests/integration/fw_serve.bats
- tests/integration/fw_setup.bats
- tests/integration/fw_task.bats
- tests/integration/fw_termlink.bats
- tests/integration/fw_test_cmd.bats
- tests/integration/fw_test_onboarding.bats
- tests/integration/fw_tier0.bats
- tests/integration/fw_timeline.bats
- tests/integration/fw_traceability.bats
- tests/integration/fw_update.bats
- tests/integration/fw_upgrade.bats
- tests/integration/fw_upstream.bats
- tests/integration/fw_validate_init.bats
- tests/integration/fw_vendor.bats
- tests/integration/fw_work_on.bats
- tests/integration/review_queue_arc.bats
- tests/integration/t2499_supervision_notice.bats
- tests/integration/verify_acs_arc.bats
- tests/unit/arc_membership_agent_surfaces.bats
- tests/unit/arc_membership_dual_id.bats
- tests/unit/arc_membership_shared.bats
- tests/unit/arc_membership_union.bats
- tests/unit/audit_arc_progress_arc_id.bats
- tests/unit/audit_ctl_arc_tag_only_pattern.bats
- tests/unit/audit_d10_html_comment_blindness.bats
- tests/unit/audit_gate_bypass_log.bats
- tests/unit/audit_stale_slice_reference.bats
- tests/unit/checkpoint.bats
- tests/unit/context_decision.bats
- tests/unit/context_episodic.bats
- tests/unit/context_focus.bats
- tests/unit/context_init.bats
- tests/unit/context_learning.bats
- tests/unit/context_pattern.bats
- tests/unit/context_status.bats
- tests/unit/emit_review_ac_counter.bats
- tests/unit/git_common.bats
- tests/unit/git_log.bats
- tests/unit/handover_checkpoint_push.bats
- tests/unit/healing_diagnose.bats
- tests/unit/healing_resolve_indent.bats
- tests/unit/hook_telemetry.bats
- tests/unit/hook_threshold.bats
- tests/unit/inception_defer_park.bats
- tests/unit/lib_costs.bats
- tests/unit/lib_keylock.bats
- tests/unit/lib_keylock_timeout.bats
- tests/unit/lib_prompt.bats
- tests/unit/rca_gate.bats
- tests/unit/recommendation_gate_build_partial.bats
- tests/unit/recommendation_gate_needs_human.bats
- tests/unit/review_pipefail.bats
- tests/unit/skip_ac_partial_complete.bats
- tests/unit/task_verify_extraction.bats
- tests/unit/test_mirror_stderr_capture.bats
- tests/unit/test_mirror_sync.bats
- tests/unit/test_orchestrator_status_synthetic_filter.bats
- tests/unit/test_update_task_horizon_null_reclose.bats
- tests/unit/update_task_horizon_null_on_close.bats
- tests/unit/update_task_orphan_guard.bats

</details>

## Classification

105 of 106 sites are **SAFE by assignment order**: each has exactly one real
`PROJECT_ROOT=` assignment, textually and execution-order first, inside a
`setup()` bats calls unconditionally before every `@test` in the file (or,
in the two dual-var files, inside their own locally-scoped equivalent —
`arc_membership_dual_id.bats` uses `$TEST_TMP`, `test_mirror_sync.bats`/
`test_mirror_stderr_capture.bats` use subpaths of `$TEST_TEMP_DIR`). Under
correct bats execution `mktemp -d` always runs first, so `PROJECT_ROOT` is
never empty *by construction* — but "SAFE by order" is not "immune": if
`mktemp -d` ever fails, or a helper is invoked outside the bats lifecycle
(T-2787's documented failure modes), the assignment silently degrades to
empty. All 105 now carry the guard as defense-in-depth, not because order
was wrong.

1 of 106 sites is **EXPOSED by construction**, found only by reading
assignment order rather than trusting current pass/fail:
`tests/unit/audit_d10_html_comment_blindness.bats:57` computes
`PROJECT_ROOT="$(dirname "$task_file")"` where `$task_file="$TEST_TEMP_DIR/${task_id}.md"`.
If `$TEST_TEMP_DIR` is empty, `$task_file` becomes `/${task_id}.md` and
`dirname` returns literally `/` — the exact T-2787 failure shape, reached
indirectly through `dirname` rather than a direct assignment. This site
gets the same `guard_project_root` call as the other 105.

## Guard Implementation

`tests/test_helper.bash:guard_project_root()` — refuses empty, `/`, or any
root not prefixed by a recognised OS temp directory (`$TMPDIR`, `/tmp`,
`/var/folders`, `/private/tmp`, `/private/var/folders`). Checked against a
temp-prefix rather than the literal `$TEST_TEMP_DIR` variable name because
3 of the 106 sites mint their own differently-named temp var
(`$TEST_TMP`, `.../work`, `.../proj`) instead of reusing the shared one —
the invariant that matters is "inside *some* process-private temp dir", not
"inside this specific variable". Called once per file, immediately after
that file's one real `PROJECT_ROOT=` assignment (verified: none of the 106
files has more than one genuine assignment — the higher `grep -c PROJECT_ROOT=`
counts on ~60 of them are read-only references inside
`PROJECT_ROOT='$PROJECT_ROOT'` passed to a nested `run bash -c "..."`, not
reassignments).

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] Every call site is enumerated, not sampled: the full list of files matching
      `mkdir -p "$PROJECT_ROOT/…"` (106 at filing) is recorded in the task, and the
      count is re-derived at close rather than quoted from here.
- [x] Each site is classified as SAFE (assigns `PROJECT_ROOT` before first use, in
      a `setup()` that cannot be skipped) or EXPOSED. Classification is by reading
      the assignment order, not by whether the file currently passes — a file that
      passes because its `setup()` happens to succeed is still exposed.
- [x] A shared guard refuses an empty root, `/`, and any path outside the test
      temp dir, and is reachable from every exposed site (a helper the sites call,
      or a load-time assertion in `tests/test_helper.bash` — whichever actually
      intercepts, verified by demonstration).
- [x] The guard is proven to fire: a deliberately-exposed fixture file fails with
      the guard's message, and passes with a correct `PROJECT_ROOT` (L-530).
- [x] The guard runs under the runner that executes bats today, verified by
      `bats --count tests/unit/` delta rather than by file presence (T-2696).
- [x] `tests/unit/no_root_framework_markers.bats` (T-2787) is green at close, or
      the reason it is not is stated — it is the detective half of this fix and
      its state is the outcome measure.
- [ ] No fixture write escapes its temp dir during a full `bats tests/` run,
      demonstrated by checking `/` for framework markers immediately before and
      after the run and diffing — the before/after pair is the evidence, since a
      clean "after" alone cannot distinguish "nothing escaped" from "root was
      already polluted".

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

grep -q 'guard_project_root()' tests/test_helper.bash
out=$(bats tests/unit/guard_project_root.bats 2>&1); echo "$out" | grep -q '^ok 7 ' && ! echo "$out" | grep -q '^not ok'
out=$(comm -13 <(printf '%s\n' tests/unit/no_root_framework_markers.bats tests/unit/guard_project_root.bats | sort) <(grep -rl 'mkdir -p "\$PROJECT_ROOT' tests/ --include='*.bats' | sort)); [ "$(echo "$out" | grep -c .)" -eq 106 ] && [ -z "$(echo "$out" | xargs grep -L 'guard_project_root')" ]

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

### 2026-08-04T13:10:55Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2788-sweep-bats-fixture-paths-built-on-an-ung.md
- **Context:** Initial task creation

### 2026-08-04T13:14:37Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)
