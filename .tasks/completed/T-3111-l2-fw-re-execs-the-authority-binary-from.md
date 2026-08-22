---
id: T-3111
name: "L2: fw re-execs the authority binary from a linked worktree (R7)"
description: >
  R7 leg 2. bin/fw detects a linked worktree via git rev-parse --git-common-dir and
  re-execs the authority's bin/fw. Fixes stale-replica-code and ID allocation in one
  move. Future-facing only: a worktree needs the redirect already in its checkout.
  See docs/design/task-corpus-concurrency-model.md R7.

status: work-completed
workflow_type: build
owner: claude-code
horizon: null
tags: []
components: [bin/fw, lib/hook-parity.sh, lib/paths.sh, lib/worktree-identity.sh, tests/unit/t3111_worktree_reexec.bats, tests/unit/t3112_worktree_hook_parity.bats]
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
created: 2026-08-20T17:35:42Z
last_update: 2026-08-22T10:51:43Z
date_finished: 2026-08-22T10:51:43Z
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
  - ts: '2026-08-20T17:45:08Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=202,acs=4)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-20T17:45:14Z'
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
  - ts: '2026-08-21T18:00:15Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 2
      D3: 3
      D4: 2
      F-RECALL: 1
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=2 
      (body:telemetry-or-audit-entry); D3=3 (body:component-discoverability); 
      D4=2 (body:env-class-handled); F-RECALL=1 (body:episodic-only); 
      F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-3111: L2: fw re-execs the authority binary from a linked worktree (R7)

## Context

### HANDOVER — exact next command (2026-08-21, budget-forced, mid-leg)

L1/L3/L4 are landed and closed. L2 is the last R7 leg. Nothing has been edited
for it yet — this task is `started-work` with focus set, and no source change
exists. Start clean.

```
cd /opt/999-Agentic-Engineering-Framework && bin/fw work-on T-3111
```

Then write real ACs BEFORE touching `bin/fw` — G-020 blocks Bash under this task
until the placeholder ACs are replaced, and the Edit tool is the only way to make
that first edit (the Bash gate refuses its own unblocking write).

**What L2 is.** `bin/fw` detects it is running inside a linked worktree and
re-execs the *authority's* `bin/fw` instead of the replica's. That fixes stale
replica code and ID allocation in one move. It is the only *complete* fix in R7 —
and it reaches only worktrees created after it ships, which is why L1 (the shared
pre-commit hook) was the keystone.

**Reuse, do not re-derive.** These already exist and are landed:
- `lib/paths.sh:fw_is_linked_worktree` — the detection predicate.
- `lib/hook-parity.sh:fw_hook_parity_authority_root` — resolves the authority via
  `--git-common-dir`. Use it. Do NOT resolve from `$FRAMEWORK_ROOT`: in a linked
  worktree that points at the replica, which is the checkout whose code must not
  be trusted.

**The two hazards, both real:**
1. **Re-exec loops.** The authority's `bin/fw` must not bounce back. Guard with an
   env sentinel (`FW_REEXEC_DEPTH` or similar) set before `exec`, checked first.
2. **`FRAMEWORK_ROOT` inheritance.** T-2845 measured this exact trap in
   `_t2094_emit_doctor_advisory`: `fw` honours an inherited `FRAMEWORK_ROOT` over
   its own location, so re-execing the authority binary while a replica-scoped
   `FRAMEWORK_ROOT` is still exported puts the authority back into the replica's
   world and the output is byte-identical to having changed nothing. **The binary
   and `FRAMEWORK_ROOT` must move together.** Read that comment before writing the
   exec.

**Do not re-verify L1/L3/L4.** They are landed at `b3adc805a` on origin/master,
origin/t2539-staging and github/master.

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] `bin/fw`, when invoked from a linked worktree, re-execs the authority's `bin/fw` with the same argv, using `lib/paths.sh:fw_is_linked_worktree` for detection and `lib/hook-parity.sh:fw_hook_parity_authority_root` for resolution — no new detector, no `$FRAMEWORK_ROOT`-based resolution.
- [x] The re-exec exports `FRAMEWORK_ROOT` scoped to the authority in the same step as the `exec`. Binary and root move together (T-2845 measured that inheriting the replica's `FRAMEWORK_ROOT` makes the redirect byte-identical to doing nothing).
- [x] An env sentinel prevents re-exec loops: the authority's `bin/fw` sees it set and never bounces back, at any nesting depth.
- [x] Invocation from the main checkout is completely unaffected — no exec, no sentinel, no measurable change in behaviour or output.
- [x] An escape hatch (`FW_NO_REEXEC=1`) skips the redirect and is logged Tier-2, for the case where an operator genuinely needs the replica's own binary.
- [x] `bin/fw --version` (or an equivalent cheap probe) run from a linked worktree reports the AUTHORITY's version, not the replica's — the observable proof the redirect fired.
- [x] `tests/unit/t3111_worktree_reexec.bats` covers: redirect fires from a linked worktree, does not fire from the main checkout, loop guard holds, `FRAMEWORK_ROOT` lands on the authority, escape hatch works, and argv survives intact including args with spaces.

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

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-08-20T17:35:42Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3111-l2-fw-re-execs-the-authority-binary-from.md
- **Context:** Initial task creation

### 2026-08-20T22:26:16Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

bats tests/unit/t3111_worktree_reexec.bats > /tmp/.t3111.out 2>&1 && grep -q "^ok 16" /tmp/.t3111.out && ! grep -q "^not ok" /tmp/.t3111.out
bats tests/unit/t3112_worktree_hook_parity.bats > /tmp/.t3112.out 2>&1 && ! grep -q "^not ok" /tmp/.t3112.out
bats tests/unit/t3113_upgrade_worktree_advisory.bats > /tmp/.t3113.out 2>&1 && ! grep -q "^not ok" /tmp/.t3113.out
# The predicate exists exactly once repo-wide. A count in one named file cannot see a copy in a file it does not name (T-3113).
test "$(grep -rl '^fw_is_linked_worktree()' --include='*.sh' --include='*.py' --include='fw' . 2>/dev/null | grep -v '\.agentic-framework/' | grep -v '\.claude/worktrees/' | sort | tr '\n' ' ')" = "./lib/worktree-identity.sh "
# lib/paths.sh sources the shared definition rather than carrying its own.
grep -q 'worktree-identity.sh' lib/paths.sh
# bin/fw wires the redirect in (an unsourced/uncalled function is a silent no-op that reads like a clean bill of health).
grep -q '^_fw_reexec_authority "\$@"' bin/fw
# The main checkout is unaffected: fw still runs and reports the repo's own version.
bin/fw --version > /tmp/.t3111v.out 2>&1 && grep -q "Framework: /opt/999-Agentic-Engineering-Framework$" /tmp/.t3111v.out

## Reviewer Verdict (v1.5)

- **Scan ID:** R-09b53109
- **Timestamp:** 2026-08-22T10:51:44Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 2

**Per-AC findings:**

- **AC#1 (Agent)** — `bin/fw`, when invoked from a linked worktree, re-execs the authority's `bin/fw` with the same argv, using `lib/paths.sh:fw_is_linked_worktree` for detection and `lib/hook-parity.sh:fw_hook_parity_aut
  - **AC-verify-mismatch** (narrow, heuristic) — `path=lib/paths.sh in: `bin/fw`, when invoked from a linked worktree, re-execs the authority's `bin/fw` with the same argv, using `lib/paths.sh:fw_is_linked_worktree` for de`
- **AC#7 (Agent)** — `tests/unit/t3111_worktree_reexec.bats` covers: redirect fires from a linked worktree, does not fire from the main checkout, loop guard holds, `FRAMEWORK_ROOT` lands on the authority, escape hatch wor
  - **AC-verify-mismatch** (narrow, heuristic) — `path=tests/unit/t3111_worktree_reexec.bats in: `tests/unit/t3111_worktree_reexec.bats` covers: redirect fires from a linked worktree, does not fire from the main checkout, loop guard holds, `FRAMEW`

### 2026-08-22T10:51:43Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
