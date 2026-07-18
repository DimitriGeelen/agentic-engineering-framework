---
id: T-2542
name: "fw bpmn promote: staged BPMN proposal to gated .tasks/ write (owner=human,
  aef_provenance, G4 reconcile)"
description: >
  fw bpmn promote: staged BPMN proposal to gated .tasks/ write. Reads the T-2539 proposal
  manifest, delegates each write to fw task create forcing owner=human + status=captured,
  stamps aef_provenance frontmatter (832 IW-2 contract §3b), reconciles idempotently
  on
  (uid, source_bpmn_sha). AEF compiler-side half of the write-out promotion (joint
  w/ 832 T-201).

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: [bpmn, workflow-designer, "832-integration"]
components: [agents/bpmn/bpmn.sh, tests/unit/test_bpmn_promote.py, tools/bpmn_promote.py]
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
created: 2026-07-18T09:43:31Z
last_update: 2026-07-18T09:55:35Z
date_finished: 2026-07-18T09:55:35Z
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
  - ts: '2026-07-18T09:45:06Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-07-18T09:45:09Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=2 
      (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2542: fw bpmn promote: staged BPMN proposal to gated tasks write (owner:human, aef_provenance, G4 reconcile)

## Context

Build the AEF compiler-side half of the write-out **promotion** layer: `fw bpmn promote`,
which turns T-2539 staged proposals (`.context/bpmn-staged/<diagram>/<uid>.md`, `status: proposal`)
into real `.tasks/` files. Both inceptions are GO (AEF T-2541 via Watchtower, commit 284bfd90f;
832 T-201 via 832-operator, rail offset 59). The seam and id-mapping contract are settled with 832
(rail offsets 58/59): **content authority = 832, gated write = AEF**. The load-bearing guardrail (G3)
is that the `.tasks/` write goes THROUGH `fw task create` (the one governed writer) — never around it —
so it inherits the task-gate + G-020 build-readiness. Framing: `docs/reports/T-2541-writeout-promotion-inception.md`.
832's IW-2 contract (rail offset 58 §3b): task frontmatter `aef_provenance` is authoritative, the ledger
is a derived/rebuildable cache; reconcile keyed on `(uid, source_bpmn_sha)`.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] `fw bpmn promote <uid>` and `fw bpmn promote all` read the T-2539 proposal manifest and, in **dry-run (default)**, list what would be promoted with **zero** `.tasks/` writes
- [x] `--write` promotes each proposal by delegating to `fw task create` with **un-overridable** `owner: human` + `status: captured` (G2/G3 — the write never leaves the task-gate perimeter)
- [x] Every promoted task carries an `aef_provenance:` frontmatter block — `uid`, `source_diagram`, `source_bpmn_sha`, `promoted_at` — persisted as-is (832 §3b; `uid` = join key)
- [x] G4 reconcile keyed on `(uid, source_bpmn_sha)`: **new** (uid absent) → create; **unchanged** (sha equal) → NO-OP; **changed** (sha differs) → refuse-clobber on `started-work`/human-touched (refresh allowed only on `captured`+untouched under `--write`); **deleted** (uid gone) → orphan + flag, never auto-delete
- [x] Unit tests cover new-create, idempotent no-op, changed-refuse-clobber, orphan-flag — all green
- [x] `fw bpmn promote --help` documents the verb; roadmap in `agents/bpmn/AGENT.md` updated + vendored copy synced (`fw vendor self`)

**Evidence (all live-verified 2026-07-18):** 13/13 promote unit tests + 31/31 compiler tests green;
live e2e (isolated tasks tree) staged 3 proposals → dry-run (0 writes) → `--write` created T-001/2/3
through the real `fw task create` with `owner: human` + `captured` (proposal `owner: agent` on
u-compile-002 was overridden to human — G2 proven); `aef_provenance` block present inside frontmatter;
re-run `--write` = 3 no-ops, task count still 3 (G4 idempotency, no duplicates).

### Human
All acceptance criteria are agent-verifiable (deterministic CLI verb + unit tests).
The joint end-to-end integration with 832's `.bpmn` export is a SEPARATE task (832
noted "the end-to-end integration test waits on your T-2541 promote + Spike-1").

## Verification

python3 -m pytest tests/unit/test_bpmn_promote.py -q
out=$(bin/fw bpmn promote --help 2>&1); echo "$out" | grep -qi "dry-run"
out=$(bin/fw bpmn promote --help 2>&1); echo "$out" | grep -q -- "--write"

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

### 2026-07-18 — Provenance injection: post-create edit, not a shared-writer pass-through
- **Chose:** `promote` calls `fw task create` (gated write, forces owner:human + captured), then
  injects the `aef_provenance:` frontmatter block into the just-created file atomically within the
  promote transaction — before promote returns.
- **Why:** Spike-1 found `create-task.sh` templates frontmatter via fixed `str.replace()` on known
  fields only (`:389-399`) — no arbitrary-frontmatter pass-through. Post-create edit keeps the shared
  writer UNTOUCHED (zero blast radius on every other `fw task create` caller) while still routing the
  `.tasks/` write THROUGH the gate (G3 intact). The window between create and provenance-stamp is
  benign: captured+owner:human triggers zero automation (Spike-2: auto-promote off-by-default + D8-gated
  + needs confirmed bvp_scores). 832's "frontmatter authoritative" contract (§3b) is satisfied — the
  persisted file carries the block; who writes it (promote vs create-task.sh) is immaterial to the contract.
- **Rejected:** Adding `--extra-frontmatter` to `create-task.sh` (Option B) — atomic single-write, but
  invasive on the shared writer for a single caller's need + touches the fresh-machine surface. Defer
  unless post-create edit proves inadequate.

### 2026-07-18 — Idempotency floor: new+unchanged ship together
- **Chose:** `new→create` and `unchanged(sha)→NO-OP` are one indivisible slice; `changed→refuse-clobber`
  and `deleted→orphan+flag` complete G4 in the same task.
- **Why:** shipping `new→create` without the `unchanged` guard makes a second `promote --write` run
  duplicate every task (violates C3 idempotency + 832 §3b). The reconcile keyed on `(uid, source_bpmn_sha)`
  is the load-bearing safety, not a follow-up.

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-07-18T09:43:31Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2542-fw-bpmn-promote-staged-bpmn-proposal-to-.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-83b51b6f
- **Timestamp:** 2026-07-18T09:55:37Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **mock-only-integration** (partial, heuristic) @ AC vs Verification cross-check
     - evidence: `python3 -m pytest tests/unit/test_bpmn_promote.py -q`

### 2026-07-18T09:55:35Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
