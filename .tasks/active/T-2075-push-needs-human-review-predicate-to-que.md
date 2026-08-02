---
id: T-2075
name: "push 'needs human review' predicate to queue-build layer via shared helper
  (T-2064 GO scope)"
description: >
  Implements T-2064 inception GO. Symptom: tasks appear in /approvals review queue
  despite zero unchecked Human ACs — per-surface predicate drift between /approvals
  (web) and fw review-queue (CLI). Fix: centralise the needs_human_review() predicate
  at queue-build time. Both surfaces consume the queue; render-time only displays
  what's there. ACs: shared helper added in web/shared.py or lib/, both surfaces refactored
  to use it, test pinned for zero-Human-AC case + checked-Human-AC case + unchecked-Human-AC
  case, no behavioural regression on the 20+ arc-007 partial-completes currently queued
  for human review.

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: []
components: [bin/fw, web/blueprints/approvals.py, web/shared.py]
related_tasks: []
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-28T18:03:55Z
last_update: '2026-06-11T22:23:31Z'
date_finished: 2026-05-28T22:41:58Z
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
  - ts: '2026-05-28T18:15:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled)
    rubric_sha: e4a00f38e801
  - ts: '2026-05-28T22:54:12Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 2
      F1: 1
      F2: 0
    rationale: "D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 (body:component-discoverability);
      D4=2 (body:env-class-handled); F1=1 (body/tag hits for 'F1': 1); F2=0 (no-signal)"
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:23:31Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-05-28T18:15:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2075: push 'needs human review' predicate to queue-build layer via shared helper (T-2064 GO scope)

## Context

Implements T-2064 GO scope. The "needs human review?" predicate lived as two parallel implementations: `web/blueprints/approvals.py:_load_pending_human_acs()` used a `_parse_acceptance_criteria` → `section == "human"` → `not checked` chain; `bin/fw review-queue` used an inline regex (`## Acceptance Criteria` → `### Human` → comment-strip → count `- [ ]`). Either could drift independently — the L-298 / T-1581 HTML-comment-strip fix already had to be applied twice on the CLI side after the web side caught the same class. Centralised at the queue-build layer so both surfaces consume one helper. Downstream display (per-AC details, confidence prefix, sort priority) keeps its existing parse on the web side; the CLI never needed the detail.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] `web/shared.py` exports `count_unchecked_human_acs(body) -> int` + `needs_human_review(body) -> bool`. Strips HTML comments (T-1581 class), matches `### Human` subsection of `## Acceptance Criteria` only — not `### Agent`, not `## Verification`.
- [x] `web/blueprints/approvals.py:_load_pending_human_acs()` filters via the new helper for the queue-membership decision; downstream display-detail parse keeps using `_parse_acceptance_criteria`.
- [x] `bin/fw review-queue` Python block replaced with a call to the shared helper (inline regex deleted). Plus the consumer-fallback inline definition for environments without `web/` on the path.
- [x] pytest `tests/unit/test_count_unchecked_human_acs.py` — 6 tests covering the 5 inception fixtures plus the all-checked partial-complete case. All green.

### Human
- [ ] [REVIEW] /approvals page shows the same set of partial-complete tasks as before the refactor — no regression in queue membership.
  **Steps:**
  1. Open http://192.168.10.107:3000/approvals
  2. Scroll the "VERDICT — Human ACs awaiting verification" / "Awaiting Your Action" section.
  3. Spot-check a few previously-queued tasks (e.g., T-1701, T-1947, T-1988) — confirm they still appear with their existing verdict prefixes.
  4. Cross-reference with `cd /opt/999-Agentic-Engineering-Framework && bin/fw review-queue` in a terminal — same task IDs should appear in both surfaces.

  **Expected:** Surface parity. Same task IDs appear in both web and CLI lists. No drift in counts beyond ±1 (live changes during the spot check).

  **If not:** Note the divergent task ID(s) and inspect their `### Human` block — the refactor should preserve every previously-queued task's eligibility.

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# The completion gate runs each command — if any exits non-zero, completion is blocked.
bash -n bin/fw
python3 -c "import ast; ast.parse(open('web/shared.py').read()); ast.parse(open('web/blueprints/approvals.py').read())"
out=$(python3 -m pytest tests/unit/test_count_unchecked_human_acs.py -q 2>&1); echo "$out" | tail -3 | grep -q "passed" && ! echo "$out" | grep -qE "[0-9]+ (failed|error)"
out=$(bin/fw review-queue 2>&1 | head -5); echo "$out" | grep -q "VERDICT\|DECISIONS\|No tasks"
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

## Recommendation

**Recommendation:** GO (complete)

**Rationale:** Cleanly centralises the queue-membership predicate. Two parallel implementations are now one shared helper; the L-298 / T-1581 HTML-comment-strip fix can only be applied (or broken) in one place. Downstream display detail on the web side keeps its existing parse — no behavioural change beyond consistency. One [REVIEW] AC pending for surface parity (eyeball /approvals vs `fw review-queue` showing the same task IDs).

**Evidence:**
- `web/shared.py` gains `count_unchecked_human_acs(body)` + `needs_human_review(body)` — single-source predicate.
- `web/blueprints/approvals.py:_load_pending_human_acs` gates on `needs_human_review(body)` first; full per-AC parse still runs for display detail.
- `bin/fw review-queue` Python block replaced the 14-line inline scan with `count_unchecked_human_acs(text)`; consumer-fallback inline definition kept in lockstep for projects without `web/`.
- `tests/unit/test_count_unchecked_human_acs.py`: 6 tests covering the five inception fixtures (a-e) + an all-checked partial-complete case. All green in 0.16s.
- Live smoke: `fw review-queue` renders 124 VERDICT rows; `/approvals` renders cleanly. Bash + Python syntax checks both pass.

## Updates

### 2026-05-28T18:03:55Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2075-push-needs-human-review-predicate-to-que.md
- **Context:** Initial task creation

### 2026-05-28T18:51:17Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-f1757218
- **Timestamp:** 2026-05-28T22:41:59Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 6
     - evidence: `out=$(python3 -m pytest tests/unit/test_count_unchecked_human_acs.py -q 2>&1); echo "$out" | tail -3 | grep -q "passed"`

### 2026-05-28T22:41:58Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
