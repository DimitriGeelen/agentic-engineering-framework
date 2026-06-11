---
id: T-2051
name: "Watchtower POST /inception/<id>/decide returns 500 + leaves decision uncommitted
  when decide git-commit fails"
description: >
  Found during T-2030 GO. Human clicked decide 3× via Watchtower: two POST /inception/T-2030/decide
  returned 500, third returned 200 but the decision (Decision: GO written to file,
  moved to completed/) was NEVER git-committed — left as uncommitted working-tree
  changes (D active, AM completed, ?? episodic). Agent had to commit manually. Root-cause
  hypothesis: the decide handler's git commit fails (e.g. commit-msg inception-commit-limit
  hook rejects, or other non-zero) and the handler 500s instead of surfacing a clear
  error, and on eventual success does not verify/commit. Bug-class: needs RCA. Fix:
  decide handler must (a) not 500 on commit failure, (b) ensure the decision is committed
  or report clearly that it wasn't.

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: [bug]
components: [web/blueprints/inception.py]
related_tasks: [T-2030, T-2053]
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-25T19:51:15Z
last_update: '2026-06-11T22:23:31Z'
date_finished: 2026-05-26T22:09:33Z
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
  - ts: '2026-05-25T20:00:03Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-05-26T20:15:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 1
      tier: 2
      effort: 8
    rationale: blast_radius=1 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-05-25T20:00:03Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled)
    rubric_sha: e4a00f38e801
  - ts: '2026-05-25T20:34:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 2
      D3: 0
      D4: 2
    rationale: D1=4 (body:structural-gate); D2=2 
      (body:telemetry-or-audit-entry); D3=0 (no-signal); D4=2 
      (body:env-class-handled)
    rubric_sha: e4a00f38e801
  - ts: '2026-05-26T20:45:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 2
      D3: 3
      D4: 2
    rationale: D1=4 (body:structural-gate); D2=2 
      (body:telemetry-or-audit-entry); D3=3 (body:component-discoverability); 
      D4=2 (body:env-class-handled)
    rubric_sha: e4a00f38e801
  - ts: '2026-05-28T22:54:12Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 2
      D3: 3
      D4: 2
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=2 
      (body:telemetry-or-audit-entry); D3=3 (body:component-discoverability); 
      D4=2 (body:env-class-handled); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:23:31Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 2
      D3: 3
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=2 
      (body:telemetry-or-audit-entry); D3=3 (body:component-discoverability); 
      D4=2 (body:env-class-handled); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2051: Watchtower POST /inception/<id>/decide returns 500 + leaves decision uncommitted when decide git-commit fails

## Context

The Watchtower decide button posts from two surfaces: `inception_detail.html` (plain
`<form method=post>` → non-htmx) and `_approvals_content.html:174` (`hx-post`, `hx-swap=outerHTML`).
The non-htmx path was given a graceful `?error=` redirect banner (T-1454); the htmx path
was not — it still returns the error fragment with **HTTP 500**. htmx does not swap non-2xx
responses, so on a pre-decision validation rejection the `.go-decision` block is never
replaced: the human sees the unchanged GO button and re-clicks. (T-2030: 2× 500 then 200.)

Scope: this task fixes the **500 / no-inline-error** bug only. The separate
"decision left uncommitted on success" defect (distinct root cause — Watchtower handlers
never `git commit`) is filed as its own task per one-bug-one-task.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] htmx decide-failure path (HX-Request present, `not ok` and primary not landed) returns HTTP **200** with a swappable `.go-decision` error fragment — NOT 500 — so htmx replaces the block and the human sees the result
- [x] The error fragment body contains the underlying failure reason from `fw inception decide` (stderr/stdout, e.g. "Recommendation section required"), truncated, so the human sees *why* the decision was rejected
- [x] Server-side `logging.error(...)` on failure is preserved (observability unchanged) independent of the client-facing 200
- [x] Success and side-effect-warning htmx paths are unchanged (200 + decision/warning card)
- [x] `tests/unit/test_inception_decide_htmx_error.py` pins: htmx failure → 200 + error fragment containing the reason; htmx success → decision card; regression guard that validation rejection is no longer 500

### Human
- [ ] [REVIEW] Decision-rejection error renders legibly in /approvals
  **Steps:**
  1. Open http://192.168.10.107:3000/approvals in a browser
  2. Find a GO-ready inception whose task is *not* decide-ready (or use a test task missing its `## Recommendation`), click GO
  3. Observe the card that replaces the GO button
  **Expected:** The `.go-decision` block is replaced inline with a clearly-styled error card showing the reason (e.g. "Recommendation section required"); the page does not appear to do nothing
  **If not:** Note whether the block updated at all (htmx swap) and whether the reason text is readable; screenshot it

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
# Enforcement-baseline hint (L-398, T-1886): if you edited `.claude/settings.json`
# (added/removed/reorganised hooks), add `bin/fw enforcement baseline` to your
# Verification block. Otherwise the canonical hash diverges and `fw doctor`
# reports a FAIL ("Enforcement baseline CHANGED") that accumulates silently.
# Origin: T-1849/T-1730/T-1731 each added a legitimate hook without refreshing
# the baseline — FAIL sat for multiple sessions until T-1886 cleaned up.
python3 -m py_compile web/blueprints/inception.py
python3 -m pytest tests/unit/test_inception_decide_htmx_error.py -q

## RCA

**Symptom:** On T-2030, the human clicked GO from /approvals 3×; the first two POSTs
returned HTTP 500, the page did not visibly change, and no reason was shown. (Access log:
two `POST /inception/T-2030/decide HTTP/1.1 500` at 21:19, then `200` at 21:43 after the
`## Recommendation` section was added.)

**Root cause:** The htmx branch of `record_decision` (`web/blueprints/inception.py:539`)
returns the error fragment with status **500** for the `not ok and not primary_landed`
case. The two 500s were a legitimate *pre-decision validation rejection* —
`fw inception decide` exited non-zero with "## Recommendation section required" because the
task was an empty stub (not a server fault). htmx with `hx-swap="outerHTML"` does not swap
non-2xx responses by default, so `.go-decision` was never replaced; the human saw the
unchanged GO button and re-clicked. The reason text *was* in the 500 body but was never
rendered.

**Why structurally allowed:** When T-1454 added graceful error surfacing it fixed only the
**non-htmx** form path (`?error=` redirect → banner on the detail page). The **htmx** path
(/approvals) kept its raw 500. The two decide surfaces diverged and the htmx error UX was
never brought to parity. No test pinned the htmx-failure HTTP status, so the divergence was
invisible.

**Prevention:** `tests/unit/test_inception_decide_htmx_error.py` pins the htmx-failure
response to 200 + a swappable error fragment containing the reason, and guards against a
regression back to 500. Both decide surfaces now surface the rejection reason inline.

**Scope note:** This task fixes the 500 / no-inline-error defect only. The second defect
observed in the same incident — the decision recorded at 21:43 was never `git commit`ed
(Watchtower mutation handlers don't commit) — is a distinct root cause filed as its own
task (see Decisions).

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

### 2026-05-25 — Split the incident into two tasks (one bug = one task)
- **Chose:** Fix the 500 / no-inline-error defect here (T-2051); file the "decision left uncommitted on success" defect separately as **T-2053**.
- **Why:** The two symptoms in the T-2030 incident have **distinct root causes** — the 500 is an htmx error-response-semantics bug in the decide handler; the uncommitted decision is a missing-commit pattern affecting *all* Watchtower mutation handlers. Compounding them would dilute causality and the RCA. The access log confirms the 500s (21:19) were a pre-decision validation rejection, not a commit failure; the commit gap manifested only on the later 200 (21:43).
- **Rejected:** Fixing both under one task — violates one-bug-one-task and would couple a bounded htmx fix to a broader commit-policy question (should every Watchtower mutation auto-commit?) that T-2053 can scope on its own.

### 2026-05-25 — Return 200 (not 4xx) on the htmx failure path
- **Chose:** Return HTTP 200 with a swappable `.go-decision` error fragment.
- **Why:** htmx (`hx-swap="outerHTML"`) only swaps 2xx responses by default; a 4xx would require global htmx response-handling config and would still not display the reason. The existing success/warning htmx paths already return 200 fragments — 200+error-card is consistent. A pre-decision validation rejection is an *expected* outcome, not a server fault; server-side `logging.error` is preserved for observability.
- **Rejected:** 422 + htmx `responseHandling` config (fragile, version-dependent); keeping 500 (htmx silently drops it — the original bug).

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Recommendation

**Recommendation:** GO — ready for human review.

**Rationale:** The titled defect is fixed and pinned. The /approvals htmx decide path
now returns a swappable 200 error fragment instead of a silently-dropped 500, so a
not-ready decision (the T-2030 case) shows its reason inline instead of appearing to do
nothing. Server-side error logging is unchanged. One `[REVIEW]` Human AC remains — the
visual legibility of the error card in the browser — which only a human can judge
(render-surface gate, P-013).

**Evidence:**
- `web/blueprints/inception.py` htmx branch: 500 → 200 swappable `.go-decision` error fragment with the escaped reason (`Decision not recorded` + stderr/stdout).
- `tests/unit/test_inception_decide_htmx_error.py` — 3 tests pass: failure→200 (regression guard vs 500), fragment-contains-reason, success→decision card.
- 13 related inception/approvals tests pass — no regression.
- Root cause grounded in the live access log (two `POST …/decide 500` at 21:19 = "## Recommendation section required" validation rejection; `200` at 21:43 after fix).
- Scope split: uncommitted-decision defect filed as **T-2053** (distinct root cause).

## Updates

### 2026-05-25T19:51:15Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2051-watchtower-post-inceptioniddecide-return.md
- **Context:** Initial task creation

### 2026-05-25T20:34:02Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-a4c6e34e
- **Timestamp:** 2026-05-26T22:09:35Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-05-26T22:09:33Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
