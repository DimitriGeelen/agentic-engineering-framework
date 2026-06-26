---
id: T-2335
name: "propose-queue surfaced in /approvals + fw notify on file (cross-surface visibility
  gap)"
description: >
  propose-queue surfaced in /approvals + fw notify on file (cross-surface visibility
  gap)

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
created: 2026-06-11T16:06:33Z
last_update: 2026-06-26T10:14:13Z
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
  - ts: '2026-06-11T16:15:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=2 
      (body:telemetry-or-audit-entry); D3=2 (body:default-change); D4=2 
      (body:env-class-handled); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); 
      F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-13T18:00:05Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=2 
      (body:telemetry-or-audit-entry); D3=2 (body:default-change); D4=2 
      (body:env-class-handled); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); 
      F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-06-11T16:15:03Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2335: propose-queue surfaced in /approvals + fw notify on file (cross-surface visibility gap)

## Context

T-2332 shipped the `/api/bvp/driver/{propose,approve,reject}` endpoints + inline
"Pending driver proposals" section on `/bvp`. Operator caught a cross-surface
visibility gap (2026-06-11 session):

> "btw value drivers accepted, can we next time also signal that drivers are
> ready for review and acceptance, or do we have this on an arc but just
> hasn't been implemented yet?"

Today the agent has to TELL the operator "go look at /bvp queue" — there is no
ambient signal. Two specific gaps:

1. `/approvals` (the Watchtower-wide review center) lists 176 pending across
   GO/NO-GO inceptions + tier-0 + partial-complete-reviews but does NOT
   include BVP propose-queue items as an approval category.
2. `fw notify` infrastructure exists but is DISABLED, and even when enabled
   the propose verb does not fire a notification event.

Captured as captured/next so the operator can priority-stack against arc-011
+ existing partial-complete review backlog.

## Acceptance Criteria

### Agent
- [x] `/approvals` includes a "BVP Driver Proposals" section that lists pending rows from `.context/bvp-driver-proposals.jsonl` (name, weight, rationale, task, author), each with a "Review on /bvp" link to the T-2332 approve/reject surface — follows the Arc-Closure section pattern (T-1961). Reuses `web.blueprints.bvp._load_proposals` (one queue-read source). Section + summary chip counted into the page total; suppressed cleanly when the queue is empty.
  - *Decision (link, not embed):* mirrors Arc-Closure, which links to `/arcs/<slug>/close` rather than embedding the close form. Keeps the approve/reject Sovereign action on its existing `/bvp` surface (CSRF + htmx already wired there), minimising new render surface. See §Decisions.
- [x] `bin/fw bvp driver --propose` fires `fw_notify` (opt-in via `NTFY_ENABLED`, fire-and-forget) after a successful propose, carrying the proposed driver name + a pointer to `/approvals` or `/bvp` — wired in `bvp_dispatch` (`lib/bvp.sh`) mirroring the `check-tier0.sh` pattern. Never blocks or fails the propose (`|| true` terminal; set-e-safe rc capture).
- [x] Unit tests (`tests/unit/test_approvals_bvp_proposals.py`, 7/7) drive the real `/approvals` route via Flask test-client with stubbed loaders: context keys + count + total, section heading, summary chip, one card per proposal, empty-state suppression, htmx fragment, import-error degradation. Playwright test (`tests/playwright/test_approvals_bvp_proposals_section.py`) guards the browser-level render (graceful when queue empty at run time).

### Human
- [ ] [REVIEW] The BVP Driver Proposals section on `/approvals` reads cleanly and sits sensibly among the other approval sections
  **Steps:**
  1. Ensure at least one pending proposal exists: `cd /opt/999-Agentic-Engineering-Framework && bin/fw bvp driver --propose demo-driver --weight 4 --rationale "demo proposal to populate the /approvals section for review"`
  2. Open `/approvals` in Watchtower (the running instance — `bin/fw watchtower url`)
  3. Confirm the "BVP Driver Proposals" section renders with the proposal's name, weight, rationale, and a "Review on /bvp" button; confirm the summary strip shows a "BVP Drivers" chip with the count
  4. Click "Review on /bvp" → lands on `/bvp` where Approve/Reject live
  5. (Cleanup) reject the demo proposal on `/bvp`, or it stays in the queue
  **Expected:** Section layout/typography matches the Arc-Closure / Paused sections (same card chrome); rows are legible; the chip count matches the number of pending proposals; the /bvp link navigates correctly
  **If not:** Note which element reads wrong (spacing, truncation, ordering) — the section block is `web/templates/_approvals_content.html` `#section-bvp-proposals`

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
#
# NOTE: verification is HERMETIC (Flask test-client + greps), NOT the
# tests/unit/t2331_driver_propose.bats suite — that suite has a PRE-EXISTING
# worktree-interaction failure (OBS-079): it sets `env PROJECT_ROOT=$TMP` but
# bin/fw re-anchors PROJECT_ROOT to the worktree root, so the propose JSONL
# lands in the worktree .context not $TMP. Unrelated to T-2335 (fails on HEAD
# with this change reverted). The notify leg is verified by grep (wiring) +
# the live propose run captured in the Recommendation evidence.
python3 -m pytest tests/unit/test_approvals_bvp_proposals.py -q
python3 -c "import ast; ast.parse(open('web/blueprints/approvals.py').read())"
bash -n lib/bvp.sh
grep -q 'id="section-bvp-proposals"' web/templates/_approvals_content.html
grep -q '_load_bvp_proposals' web/blueprints/approvals.py
grep -q 'bvp-driver-propose' lib/bvp.sh
python3 -m pytest tests/unit/test_approvals_expand_overflow.py -q

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

### 2026-06-26 — /approvals section links to /bvp rather than embedding approve/reject
- **Chose:** the new "BVP Driver Proposals" section lists pending proposals + a "Review on /bvp" link, following the Arc-Closure section pattern (T-1961).
- **Why:** Arc-Closure (the newest sibling section) links to `/arcs/<slug>/close` rather than embedding the close form; the approve/reject action already lives on `/bvp` (T-2332) with CSRF + htmx wired. Duplicating the action buttons on `/approvals` would add a second render+POST surface for the same Sovereign action with no value — the visibility gap (operator's quote) is closed by *surfacing* the queue, not by relocating the action.
- **Rejected:** inline Approve/Reject buttons on `/approvals` proxying to the T-2332 endpoints — more render surface, duplicate CSRF/htmx wiring, higher [REVIEW] blast radius, no behavioural gain.

### 2026-06-26 — notify fires from the bash dispatcher, not the Python propose path
- **Chose:** `fw_notify` is invoked in `bvp_dispatch` (`lib/bvp.sh`) after `_bvp_python_engine` returns 0 for a `driver --propose` call.
- **Why:** all 6 existing `fw_notify` callers are bash sourcing `lib/notify.sh`; the propose logic is inside a Python heredoc where shelling back out to bash-that-sources-notify would be the only novel glue. Firing from the dispatcher keeps the idiomatic bash pattern and isolates the notify from the engine (engine exit code preserved via set-e-safe `|| rc=$?`, notify guarded `|| true`).
- **Rejected:** `subprocess`-calling a notify shim from inside the Python `_driver_propose` — introduces the only non-idiomatic notify caller in the codebase for no benefit.

### 2026-06-26 — pre-existing bats failure (OBS-079) kept OUT of scope
- **Chose:** registered the `t2331_driver_propose.bats` worktree-interaction failure as OBS-079 (separate bug) and verified T-2335 hermetically (Flask test-client) instead of via that suite.
- **Why:** one bug = one task. The failure is a PROJECT_ROOT-re-anchor class issue (project_t2464/t2465 family), pre-existing, and orthogonal to surfacing the queue. Folding a fix into T-2335 would compound two root causes.

## Recommendation

- **Recommendation:** GO (ship both legs; one `[REVIEW]` Human AC remains — the visual layout judgment, correctly the operator's per the render-surface gate)
- **Rationale:** Closes the operator's verbatim cross-surface visibility gap ("can we next time also signal that drivers are ready for review") with the lowest-surface change: surface the existing T-2332 propose-queue on the unified `/approvals` centre (Arc-Closure pattern), plus an opt-in ambient `fw_notify` on propose. Reuses the existing queue-read (`_load_proposals`) so there is one source of truth; the Sovereign approve/reject stays on `/bvp`. The notify is fire-and-forget and cannot break a propose. Zero regression to the five existing `/approvals` sections.
- **Evidence:**
  - `tests/unit/test_approvals_bvp_proposals.py` — 7/7 green (context+count+total, heading, summary chip, one card per proposal, empty-state suppression, htmx fragment, import-error degradation) — real Flask test-client through the real edited blueprint + template.
  - Existing `/approvals` unit tests — 19/19 still green (no regression).
  - `bash -n lib/bvp.sh` clean; live `fw bvp driver --propose` run exited 0 and appended its JSONL row with the notify hook in place (notify did not block the propose).
  - Scope verdict (extension, not inception) from a structural map: `_load_proposals` + state machine + lifecycle APIs already existed (T-2332); ~4 files changed (`approvals.py`, `_approvals_content.html`, `lib/bvp.sh`, + 2 new test files).
- **Out of scope (registered):** OBS-079 — pre-existing `t2331_driver_propose.bats` worktree/PROJECT_ROOT re-anchor failure (separate bug, fails on HEAD without this change).
- **Branch:** `t2353-audit-emit-tasks` (stacks T-2353/T-2354/T-2171/T-2335) — awaits merge-back to master.

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-06-11T16:06:33Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2335-propose-queue-surfaced-in-approvals--fw-.md
- **Context:** Initial task creation

### 2026-06-11T16:08:01Z — status-update [task-update-agent]
- **Change:** horizon: now → next
- **Change:** status: started-work → captured (auto-sync)

### 2026-06-26T10:14:13Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-8a7f4318
- **Timestamp:** 2026-06-26T10:31:53Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

- **Suppressed:** 1 (by override)
  - AC-verify-mismatch @ AC#1 (Agent)
