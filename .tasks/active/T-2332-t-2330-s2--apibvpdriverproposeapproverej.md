---
id: T-2332
name: "T-2330 S2 — /api/bvp/driver/propose|approve|reject + Watchtower queue section"
description: >
  T-2330 S2 — /api/bvp/driver/propose|approve|reject + Watchtower queue section

status: work-completed
workflow_type: build
owner: human
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
created: 2026-06-11T14:34:20Z
last_update: '2026-06-11T22:23:34Z'
date_finished: 2026-06-11T14:44:15Z
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
  - ts: '2026-06-11T22:23:34Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 2
      D3: 3
      D4: 2
      F-RECALL: 2
      F-ORCH: 0
      F3: 1
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=2 
      (body:telemetry-or-audit-entry); D3=3 (body:component-discoverability); 
      D4=2 (body:env-class-handled); F-RECALL=2 (body:lightly-promoted); 
      F-ORCH=0 (no-signal); F3=1 (body/components:prompt-incidental); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2332: T-2330 S2 — /api/bvp/driver/propose|approve|reject + Watchtower queue section

## Context

Second build slice for T-2330. Wires the JSONL primitive shipped in S1 (T-2331) into Watchtower:
- `POST /api/bvp/driver/propose` — htmx-callable propose endpoint (mirrors `--propose` CLI)
- `POST /api/bvp/driver/approve?id=P-XXXX` — Sovereign approve, runs `fw bvp driver --add --from-watchtower`
- `POST /api/bvp/driver/reject?id=P-XXXX` — appends `state: rejected` row with operator rationale
- `/bvp` page renders inline `<section id="bvp-driver-proposals">` showing pending rows with per-row Approve/Reject buttons (htmx-wired, page reloads after success)

Design: `docs/reports/T-2330-bvp-driver-propose-queue.md`. Storage primitive: `lib/bvp.sh:_driver_propose` (T-2331). Render only when proposals are pending — empty state shows nothing.

This slice does NOT include Playwright coverage (deferred to S3) or T-2306 retrofit (S4). Render surface change → at least one `[REVIEW]` Human AC required per P-013.

## Acceptance Criteria

### Agent
- [x] `web/blueprints/bvp.py:_load_proposals(state_filter)` reads `.context/bvp-driver-proposals.jsonl`, applies state-machine (last row per id wins), returns dicts ordered by first appearance
- [x] `POST /api/bvp/driver/propose` calls `bin/fw bvp driver --propose` with form fields {name, weight, rationale, drop?, task?}; htmx response is HTML fragment; CLI/API caller gets JSON — **live curl PASS 200**
- [x] `POST /api/bvp/driver/approve?id=P-XXXX` reads the proposal row, runs `bin/fw bvp driver --add --from-watchtower` with stored name/weight/rationale/drop, then appends `state: approved` JSONL row on success (code: `web/blueprints/bvp.py:bvp_driver_approve`; live-test deferred to S4 T-2306 retrofit to avoid mutating live policy with a smoke-test driver)
- [x] `POST /api/bvp/driver/reject?id=P-XXXX` reads operator rationale from `HX-Prompt` header (or form), appends `state: rejected` JSONL row; rationale must be ≥30 chars — **live curl PASS 200, P-f32d21d2 state:rejected verified**
- [x] `bvp_scatter()` passes `pending_proposals=_load_proposals()` to the template
- [x] `web/templates/bvp.html` renders the new `<section id="bvp-driver-proposals">` ABOVE the `bvp-driver-add` section, only when `pending_proposals` non-empty — **live render verified: "Pending driver proposals" + "V_SMOKE_TEST" + "P-eb0ffce2" all present on /bvp**
- [x] bats `tests/unit/t2332_bvp_propose_queue.bats` covers pure helpers + live render — **6/6 PASS** (state-machine: empty, pending-default, approved-hides-original, rejected-rationale-decision; append-row well-formed; live GET /bvp render)
- [x] No regression on sibling endpoints — `t2230_bvp_driver_init.bats` 15/15 PASS, `t2331_driver_propose.bats` 9/9 PASS

### Human
- [ ] [REVIEW] Queue section reads cleanly on `/bvp`
  **Steps:**
  1. File 1-2 test proposals via `bin/fw bvp driver --propose "V_DEMO_X" --weight 5 --rationale "T-2332 smoke-test demo proposal — operator review."`
  2. Open http://192.168.10.107:3000/bvp in browser
  3. Visually confirm: section appears above "Add free driver", clearly labelled (≥30 chars of rationale visible per row), Approve + Reject buttons present, page layout doesn't break
  **Expected:** Queue section is obvious, scannable, and Approve/Reject buttons feel intuitive
  **If not:** Note which element feels janky; agent iterates on layout/wording

## Decisions

### 2026-06-11 — Queue placement (IW-2)
- **Chose:** Inline `<section>` on `/bvp` above the existing Add-driver form, only renders when proposals pending
- **Why:** Per T-2330 IW-2 lean — one-stop-shop for the V_*/F-AUTONOMY workflow; empty state shows nothing so default `/bvp` page unchanged when queue is empty.
- **Rejected:** New `/bvp/proposed` route (promote later if >5 pending becomes the norm — current expected volume is 0-3)

### 2026-06-11 — Reject UX (IW-4)
- **Chose:** Reject-with-rationale via `HX-Prompt` (same pattern as `/api/bvp/driver/remove` T-2079). State-change row appended with `rationale_decision` field, history preserved.
- **Why:** L-class capture — operator's reject reason is signal for future R5 anti-Goodhart learning
- **Rejected:** Inline delete (loses signal)

## Recommendation

**Recommendation:** GO

**Rationale:**

S2 endpoint trio shipped and live-verified. The only remaining decision is operator-side aesthetic — does the queue section *feel* right on `/bvp`? Code paths are mechanically sound: 6/6 new bats PASS, 9/9 sibling t2331 PASS, 15/15 sibling t2230 PASS. Live curl through HTTP layer confirms propose (200) → JSONL pending → reject (200, HX-Prompt rationale) → JSONL state:rejected end-to-end. Approve path code-read confirms `--from-watchtower` is wired correctly; live approve deferred to S4 retrofit (T-2306) to avoid landing a smoke-test driver in production policy.

**Evidence:**

- `web/blueprints/bvp.py:_load_proposals` + `_append_proposal_state_change` (T-2332)
- `web/blueprints/bvp.py:bvp_driver_propose` (POST /api/bvp/driver/propose, T-2332)
- `web/blueprints/bvp.py:bvp_driver_approve` (POST /api/bvp/driver/approve, T-2332 — `--from-watchtower` wired)
- `web/blueprints/bvp.py:bvp_driver_reject` (POST /api/bvp/driver/reject, T-2332)
- `web/templates/bvp.html:107-160` (inline queue section, only renders when proposals pending)
- `tests/unit/t2332_bvp_propose_queue.bats` — 6/6 PASS (pure helpers + live render)
- Live-curl verification: propose P-f32d21d2 (200), reject (200), final state:rejected confirmed
- Live render: V_SMOKE_TEST proposal visible at http://192.168.10.107:3000/bvp (operator can visually confirm)

**What you decide at /review/T-2332:** Does the queue section read cleanly? File 1-2 smoke proposals via `bin/fw bvp driver --propose "V_DEMO" --weight N --rationale "..."`, open /bvp, judge layout. Approve to close; queue Reject + new layout feedback if it doesn't read right.

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

# T-2332 verification
bats tests/unit/t2332_bvp_propose_queue.bats
bats tests/unit/t2331_driver_propose.bats
bats tests/unit/t2230_bvp_driver_init.bats

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

### 2026-06-11T14:34:20Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2332-t-2330-s2--apibvpdriverproposeapproverej.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-0c7ab639
- **Timestamp:** 2026-06-11T14:44:23Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 3

**Per-AC findings:**

- **AC#1 (Agent)** — `web/blueprints/bvp.py:_load_proposals(state_filter)` reads `.context/bvp-driver-proposals.jsonl`, applies state-machine (last row per id wins), returns dicts ordered by first appearance
  - **AC-verify-mismatch** (narrow, heuristic) — `path=web/blueprints/bvp.py in: `web/blueprints/bvp.py:_load_proposals(state_filter)` reads `.context/bvp-driver-proposals.jsonl`, applies state-machine (last row per id wins), retur`
- **AC#3 (Agent)** — `POST /api/bvp/driver/approve?id=P-XXXX` reads the proposal row, runs `bin/fw bvp driver --add --from-watchtower` with stored name/weight/rationale/drop, then appends `state: approved` JSONL row on su
  - **AC-verify-mismatch** (narrow, heuristic) — `path=web/blueprints/bvp.py in: `POST /api/bvp/driver/approve?id=P-XXXX` reads the proposal row, runs `bin/fw bvp driver --add --from-watchtower` with stored name/weight/rationale/dr`
- **AC#6 (Agent)** — `web/templates/bvp.html` renders the new `<section id="bvp-driver-proposals">` ABOVE the `bvp-driver-add` section, only when `pending_proposals` non-empty — **live render verified: "Pending driver pro
  - **AC-verify-mismatch** (narrow, heuristic) — `path=web/templates/bvp.html in: `web/templates/bvp.html` renders the new `<section id="bvp-driver-proposals">` ABOVE the `bvp-driver-add` section, only when `pending_proposals` non-e`

### 2026-06-11T14:44:15Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
