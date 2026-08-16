---
id: T-2331
name: "T-2330 S1 — fw bvp driver --propose verb + .context/bvp-driver-proposals.jsonl
  storage"
description: >
  T-2330 S1 — fw bvp driver --propose verb + .context/bvp-driver-proposals.jsonl storage

status: work-completed
workflow_type: build
owner: agent
horizon:
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
created: 2026-06-11T14:26:14Z
last_update: '2026-08-16T22:25:02Z'
date_finished: 2026-06-11T14:30:50Z
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
  - ts: '2026-06-11T14:30:03Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-06-11T14:30:03Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-ORCH: 0
    rationale: D1=4 (body:structural-gate); D2=2 
      (body:telemetry-or-audit-entry); D3=2 (body:default-change); D4=2 
      (body:env-class-handled); F-RECALL=2 (body:lightly-promoted); F-ORCH=0 
      (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:24:16Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=2 
      (body:telemetry-or-audit-entry); D3=2 (body:default-change); D4=2 
      (body:env-class-handled); F-RECALL=2 (body:lightly-promoted); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:25:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=2 
      (body:telemetry-or-audit-entry); D3=2 (body:default-change); D4=2 
      (body:env-class-handled); F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2331: T-2330 S1 — fw bvp driver --propose verb + .context/bvp-driver-proposals.jsonl storage

## Context

First build slice for the T-2330 GO inception. Adds the non-Sovereign `fw bvp driver --propose` verb that writes proposal entries to `.context/bvp-driver-proposals.jsonl` (append-only, race-free by construction). Does NOT ship the Watchtower surface (S2) or wire Approve/Reject backend (S2). Slice scope is the storage primitive + propose verb + bats coverage. Design: `docs/reports/T-2330-bvp-driver-propose-queue.md`.

**Why JSONL + .context/ (sharpened from IW-1 lean):** Existing `_driver_add` mutates `policy/value-drivers.yaml` directly via ruamel.yaml round-trip — that's the *live policy* edit path. Proposals are *working state*, not policy, so they belong in `.context/` (same convention as `.context/bvp-weight-history.yaml`, `.context/dispatches.jsonl`, `.context/inbox.yaml`). JSONL chosen over YAML for append-only race-freedom — two agents writing concurrently each get a clean line, no merge logic needed.

## Acceptance Criteria

### Agent
- [x] `lib/bvp.sh:_driver_propose(args)` implemented — non-Sovereign (no `acd_gate` call), writes JSONL row to `.context/bvp-driver-proposals.jsonl`, returns 0 on success / 2 on bad args
- [x] Each JSONL row contains: `id` (P-NNNN unique), `ts` (ISO8601 UTC), `name`, `weight` (0-9), `rationale` (≥30 chars enforced), `drop` (optional), `author` (env: USER + CLAUDECODE session-id or "human"), `task` (optional task-id reference), `state: pending`
- [x] `cmd_driver()` routes `--propose` to `_driver_propose` before the Sovereign-gated `--add`/`--remove` branches
- [x] `fw bvp driver` invocation with no args prints usage line including the new `--propose` shape
- [x] bats test `tests/unit/t2331_driver_propose.bats` covers: (1) propose appends row + cat shows valid JSON; (2) propose under `CLAUDECODE=1` succeeds without `--i-am-human` (non-Sovereign); (3) two sequential proposes for same driver-id append 2 rows (race-free fixture); (4) rationale <30 chars rejected with exit 2; (5) bad `--weight` rejected with exit 2 — **9/9 PASS**
- [x] No regression on sibling `tests/unit/t2230_bvp_driver_init.bats` (run + report PASS) — **15/15 PASS**

### Human
<!-- No Human ACs — slice is pure backend storage primitive with deterministic tests. Slice 2 (Watchtower UI) is where Human [REVIEW] lands. -->

## Decisions

### 2026-06-11 — Storage shape (IW-1)
- **Chose:** `.context/bvp-driver-proposals.jsonl` (append-only JSONL in working-state dir)
- **Why:** Proposals are working state, not policy. Mirrors `.context/bvp-weight-history.yaml` (audit log), `.context/dispatches.jsonl` (queue), `.context/inbox.yaml` (proposal-style data). JSONL append-only eliminates the race semantics IW-3 was scoped for — no file lock, no merge logic.
- **Rejected:** In-place `bvp_drivers_proposed:` list inside `policy/value-drivers.yaml` (muddies policy audit story — policy file should change only on Approve); sidecar `policy/value-drivers.proposed.yaml` (still mixes policy/working concerns by location)

### 2026-06-11 — Race semantics (IW-3, dissolved)
- **Chose:** Append-only JSONL — two agents proposing same driver-id produce 2 rows, both surface in queue, operator picks one to Approve. No merge logic needed.
- **Why:** The JSONL storage choice (IW-1) makes race a non-issue. Originally feared file-lock / merge-on-conflict territory; the append-only primitive dissolves the question.
- **Rejected:** File lock + in-place YAML mutation (complex, lock-leak risk); reject-conflicting (loses signal from second proposer)

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

# T-2331 verification
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

### 2026-06-11T14:26:14Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2331-t-2330-s1--fw-bvp-driver---propose-verb-.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-dd8b04d7
- **Timestamp:** 2026-06-11T14:30:57Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#1 (Agent)** — `lib/bvp.sh:_driver_propose(args)` implemented — non-Sovereign (no `acd_gate` call), writes JSONL row to `.context/bvp-driver-proposals.jsonl`, returns 0 on success / 2 on bad args
  - **AC-verify-mismatch** (narrow, heuristic) — `path=context/bvp-driver-proposals.jsonl in: `lib/bvp.sh:_driver_propose(args)` implemented — non-Sovereign (no `acd_gate` call), writes JSONL row to `.context/bvp-driver-proposals.jsonl`, return`

### 2026-06-11T14:30:50Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
