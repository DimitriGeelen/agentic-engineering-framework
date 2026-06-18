---
id: T-2437
name: "worktree audit content-vs-environment keystone: guard cron-misload lint + codify principle (OBS-077)"
description: >
  worktree audit content-vs-environment keystone: guard cron-misload lint + codify principle (OBS-077)

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
created: 2026-06-18T22:46:06Z
last_update: 2026-06-18T22:50:29Z
date_finished: 2026-06-18T22:50:29Z
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
---

# T-2437: worktree audit content-vs-environment keystone: guard cron-misload lint + codify principle (OBS-077)

## Context

T-C / keystone of the worktree pre-push audit remediation (after T-2435/T-A cron-registry and T-2436/T-B self-vendor). Generalizes the worktree-skip into an explicit **content-vs-environment classification** and closes the leg T-2435 missed.

Diagnosis (during T-2436) refined the original framing: self-vendor is *content* (the vendored `.agentic-framework/` is committed) and correctly stays a FAIL — only *host-environment* state should be worktree-skipped. Surveying the audit's host-environment reads found a second, **unguarded** cron block: the T-1722 cron-misload lint (`agents/audit/audit.sh:1509`) reads `/etc/cron.d/` for an install under the *worktree* slug that never exists (cron is installed once from main under the MAIN slug). It is latent today (only `agentic-audit.crontab` present, which it skips) but false-FAILs the moment any other USER-field crontab lands in `.context/cron/` (release-mirror-canary, heartbeat, …).

**The keystone:** an audit/pre-push check may FAIL in a linked worktree ONLY when it measures committed CONTENT drift; checks measuring HOST/working-copy ENVIRONMENT state (cron install) INFO-skip. Codified in-source + L-486.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] `agents/audit/audit.sh` cron-misload lint block (line ~1509) is worktree-guarded with `fw_is_linked_worktree`, INFO-skips in a linked worktree (sibling of the T-2435 registry block)
- [x] The content-vs-environment classification keystone is documented in-source (the comment block at the guard) and as a learning (L-486)
- [x] Self-vendor (CONTENT) is verified to remain un-skipped — `check_self_vendor_drift()` contains zero worktree-skips, so real un-vendored drift still FAILs
- [x] Tests: `tests/unit/t2437_audit_cron_worktree_skip.bats` (4 — both cron legs guarded + self-vendor NOT guarded + keystone documented) green
- [x] `bash -n` clean on `agents/audit/audit.sh`; vendored copy re-synced (`fw vendor self --check` exits 0); worktree `fw audit` still zero-FAIL

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

bash -n agents/audit/audit.sh
bats tests/unit/t2437_audit_cron_worktree_skip.bats
out=$(bin/fw vendor self --check 2>&1); echo "$out" | grep -q "in sync with source"
grep -q "content-vs-environment classification" agents/audit/audit.sh

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

## RCA

**Symptom:** the pre-push audit false-FAILs on every push from a linked worktree (OBS-077). T-2435 fixed the cron-registry leg but the class was not closed — a sibling cron block remained unguarded.

**Root cause:** the cron host-environment surface in `agents/audit/audit.sh` is *two* blocks — the registry→generated→deployed drift check (line ~1448) and the T-1722 cron-misload lint (line ~1509). Both read `/etc/cron.d/` under the project slug. T-2435 guarded only the first; the second still ran unconditionally, so any worktree carrying a non-`agentic-audit` USER-field crontab in `.context/cron/` would FAIL on a dormant-install that is expected (the install lives under the main slug, not the worktree slug).

**Why structurally allowed:** T-2435 fixed the *instance* (the registry block that was actively FAILing) without enumerating the *class* (every check that reads host-environment state). There was no classification rule distinguishing content checks (must FAIL in a worktree) from environment checks (must skip), so the second cron leg's miss was invisible — and latent, since the corpus happened to contain only the self-skipping `agentic-audit.crontab` that day.

**Prevention:**
- The keystone is now explicit: an audit/pre-push check FAILs in a linked worktree only for committed CONTENT drift; HOST-ENVIRONMENT checks INFO-skip. Recorded in-source (the guard comment) + L-486.
- `tests/unit/t2437_audit_cron_worktree_skip.bats` pins the classification three ways: both cron legs are worktree-guarded (regression guard for T-2435 + the new fix), AND `check_self_vendor_drift` is NOT worktree-guarded (so content drift can never be silenced by mis-applying the skip). A future host-environment check added without a guard, or a content check that wrongly adds one, breaks a test.

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

### 2026-06-18T22:46:06Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.claude/worktrees/inception-gov-payload-mediation/.tasks/active/T-2437-worktree-audit-content-vs-environment-ke.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-4d8cc183
- **Timestamp:** 2026-06-18T22:50:31Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-06-18T22:50:29Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
