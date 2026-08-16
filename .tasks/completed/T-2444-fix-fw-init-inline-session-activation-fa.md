---
id: T-2444
name: "Fix fw init inline session activation failing on greenfield (F5)"
description: >
  Fix fw init inline session activation failing on greenfield (F5)

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: [onboarding, remediation, dogfood, init, bug]
components: [agents/context/lib/init.sh, lib/init.sh]
related_tasks: [T-2442, T-2441, T-2443]
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
created: 2026-06-21T08:49:04Z
last_update: '2026-08-16T22:25:06Z'
date_finished: 2026-06-21T10:03:46Z
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
  - ts: '2026-08-16T22:25:06Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 1
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=0 
      (no-signal); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=1 
      (body/components:context-fabric-incidental); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2444: Fix fw init inline session activation failing on greenfield (F5)

## Context

F5 from the T-2441 onboarding dogfood (GO on T-2442). On the greenfield happy path `fw init` prints
`⚠ Session init failed — run 'fw context init' manually`. The manual recovery *succeeds*, so the
first-run failure is not a real environment problem — it is an invocation-env gap, masked by a
`2>/dev/null`. See `## RCA`. Second build slice of the T-2442 batch (after F4/T-2443).

## Acceptance Criteria

### Agent
- [x] Root cause confirmed (CORRECTED — original hypothesis was wrong, see `## RCA` + `## Evolution`):
      `agents/context/lib/init.sh:108` runs `grep -rl "tags:.*onboarding" "$TASKS_DIR/active" | wc -l` inside
      `context init`'s first-session welcome path. Under `set -euo pipefail`, when **no** onboarding tasks
      exist yet (the greenfield case — they are created *after* activation), `grep` matches nothing → exits 1
      → `pipefail` propagates → `set -e` aborts `context init` with RC=1 **after it has already done all its
      work** (session.yaml/focus.yaml written, banner printed). The non-zero RC is what `lib/init.sh` reported
      as "Session init failed". Proven live via TermLink: combined-output capture showed RC=1 with the full
      success banner, aborting exactly at the welcome block's grep|wc line.
- [x] Real fix: guard the grep with `|| true` so a no-match counts as 0, not a fatal pipefail
      (`agents/context/lib/init.sh:108` → `$({ grep … || true; } | wc -l)`). L-387 pattern. Live-verified:
      fresh `fw init` now prints `✓ Session initialized (governance active)`.
- [x] Defense-in-depth (committed `102db4ff2`, retained): inline activation routes through the project's
      vendored fw and **surfaces** stderr instead of `2>/dev/null` (`lib/init.sh:452-461`). This did NOT fix
      the bug (the original RCA was wrong) but is good Directive-2 hygiene — and is exactly what made the real
      error visible during this investigation.
- [x] Greenfield regression test added (`tests/unit/init_fresh_session_activation.bats`, contract + e2e).
      **Verified live via TermLink** (OBS-080 Bash gate bypassed): `bats tests/unit/init_fresh_session_activation.bats`
      → 2/2 pass; fresh `fw init` reaches `✓ Session initialized` with `session.yaml` present.

<!-- ### Human
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

# --- F5 verification (target state — pass after the fix) ---
# REAL FIX: the onboarding grep is guarded against a pipefail no-match abort (L-387):
grep -q 'onboarding".*|| true' agents/context/lib/init.sh
# Defense-in-depth: old silent direct-script call is gone, activation routes through fw:
! grep -nE 'context\.sh" init 2>/dev/null' lib/init.sh
grep -q 'context init' lib/init.sh
# Greenfield regression (verified live via TermLink, OBS-080 bypassed — 2/2 pass):
bats tests/unit/init_fresh_session_activation.bats

## RCA

**Symptom:** Every fresh `fw init` prints `⚠ Session init failed — run 'fw context init' manually`.
The manual recovery succeeds, so a first run should not need it.

**Root cause (CORRECTED — the original hypothesis below was wrong; see `## Evolution`):**
`agents/context/lib/init.sh:108` — in `context init`'s first-session welcome path — runs
`onboard_count=$(grep -rl "tags:.*onboarding" "$TASKS_DIR/active" 2>/dev/null | wc -l)`. `context.sh`
runs under `set -euo pipefail`. During `fw init`, session activation happens **before** the onboarding
tasks are copied in, so `grep` matches nothing and exits 1; `pipefail` makes the whole pipeline exit 1;
`set -e` then aborts `context init` with RC=1 — *after* it has already written `session.yaml`,
`focus.yaml`, the tool-counter, and printed the full success banner. That non-zero RC is the only thing
wrong; `lib/init.sh` faithfully reported it as "Session init failed". The manual recovery succeeded only
because by then onboarding tasks (or >1 commit) existed, so the first-session welcome block was skipped
entirely and line 108 never ran.

**(Original, wrong RCA — retained for the lesson):** "`context.sh` aborts because the bare invocation
lacks the env `bin/fw` assembles." Disproven live: the vendored fw was reached, the env was present, and
`context init` did all its work — it just exited 1 at the grep|wc line. Routing through the vendored fw
(the committed `102db4ff2` change) did NOT fix it. Second time in this batch a plan's named fix was the
first hypothesis to disprove (cf. F9/T-2445, `feedback_remediation_plans_are_hypotheses`).

**Why structurally allowed:** (1) init's session-activation happy path had no test
(`upgrade_fresh_machine_simulation.bats` covers upgrade, not init), so the greenfield grep|wc abort shipped
unseen; (2) the original `2>/dev/null` on the activation call discarded the real error, making it silent
and undiagnosable; (3) the grep|wc-under-pipefail no-match trap is a known class (L-387) but lived in a
rarely-exercised first-session-only branch. The bug was only catchable by running a *fresh* `fw init` and
reading the actual exit code — which the in-worktree Bash gate (OBS-080) blocks, so it took a TermLink
shell to surface.

**Prevention:** (a) guard the grep with `|| true` so a no-match counts as 0 (the real fix, L-387);
(b) the `tests/unit/init_fresh_session_activation.bats` e2e asserts a fresh `fw init` reaches
`✓ Session initialized` — which now exercises exactly the greenfield branch that was broken;
(c) defense-in-depth: surface activation stderr instead of swallowing it (committed), so a future
regression here is visible, not silent.

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

### 2026-06-21 — original fix shipped, then disproven by live test
- **What changed:** The first fix (commit `102db4ff2`, routing inline activation through the vendored fw)
  was shipped as "done" on a *static* RCA — never run against a real fresh `fw init`. When the operator
  asked "can we test this using termlink", a TermLink shell (outside the OBS-080 Bash gate) ran the e2e
  bats and it FAILED: `fw init` still printed "Session init failed". The real cause was a grep|wc pipefail
  no-match abort in `context init`'s greenfield welcome path (`agents/context/lib/init.sh:108`), not the
  activation wrapper.
- **Plan impact:** The committed wrapper change does not fix the bug — it's retained as Directive-2
  defense-in-depth (and is what made the real error visible). The actual fix is a one-line L-387 grep guard
  in a *different* file (`agents/context/lib/init.sh`).
- **Triggered:** RCA + ACs corrected in place; F5 re-verified live (2/2 bats). Lesson reinforced:
  `feedback_verify_live_before_ship` (I claimed F5 shipped without a live run) +
  `feedback_remediation_plans_are_hypotheses` (the plan's named fix was the first hypothesis to disprove).

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

### 2026-06-21T08:49:04Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.claude/worktrees/inception-gov-payload-mediation/.tasks/active/T-2444-fix-fw-init-inline-session-activation-fa.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-ba91214d
- **Timestamp:** 2026-06-21T10:03:49Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **mock-only-integration** (partial, heuristic) @ AC vs Verification cross-check
     - evidence: `bats tests/unit/init_fresh_session_activation.bats`

### 2026-06-21T10:03:46Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
