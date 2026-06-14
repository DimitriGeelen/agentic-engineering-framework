---
id: T-2306
name: "T-2305 GO: implement 3 BVP drivers (V_PROMPT_QUALITY w=7, V_CONTEXT_FABRIC
  w=7, V_COMPONENT_FABRIC w=6)"
description: >
  T-2305 GO: implement 3 BVP drivers (V_PROMPT_QUALITY w=7, V_CONTEXT_FABRIC w=7,
  V_COMPONENT_FABRIC w=6)

status: started-work
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
created: 2026-06-10T10:27:09Z
last_update: '2026-06-13T18:00:05Z'
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
cost_estimate_proposed:
  - ts: '2026-06-10T10:30:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-06-10T10:30:03Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 2
      D3: 0
      D4: 2
      F-RECALL: 2
      F-ORCH: 0
    rationale: D1=4 (body:structural-gate); D2=2 
      (body:telemetry-or-audit-entry); D3=0 (no-signal); D4=2 
      (body:env-class-handled); F-RECALL=2 (body:lightly-promoted); F-ORCH=0 
      (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T10:30:03Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
      F-RECALL: 2
      F-ORCH: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled); F-RECALL=2 (body:lightly-promoted); 
      F-ORCH=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:23:34Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
      F-RECALL: 2
      F-ORCH: 4
      F3: 1
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled); F-RECALL=2 (body:lightly-promoted); 
      F-ORCH=4 (body:rubric-routable); F3=1 (body/components:prompt-incidental);
      F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-13T18:00:05Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
      F-RECALL: 2
      F-ORCH: 4
      F-AUTONOMY: 0
      F3: 1
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled); F-RECALL=2 (body:lightly-promoted); 
      F-ORCH=4 (body:rubric-routable); F-AUTONOMY=0 (no-signal); F3=1 
      (body/components:prompt-incidental); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2306: T-2305 GO: implement 3 BVP drivers (V_PROMPT_QUALITY w=7, V_CONTEXT_FABRIC w=7, V_COMPONENT_FABRIC w=6)

## Context

Implements T-2305 GO (BVP driver batch inception, decided GO by operator 2026-06-10 verbally). Three global free drivers land in `policy/value-drivers.yaml` per the pickup prompt at `docs/reports/T-2305-bvp-drivers-batch-2026-06-10.md` §9. Pre-action checks all green at filing: BVP v3 yaml shipped (F-RECALL + F-ORCH), 2/5 free slots used, 3 open — exact fit. Execution is three `fw bvp driver --add` invocations followed by a human-confirmed global recompute (D5 prompt-confirm). No source edits beyond the `policy/value-drivers.yaml` mutations driven by the canonical verb.

## Acceptance Criteria

### Agent
- [x] `V_PROMPT_QUALITY` (w=7) added to `policy/value-drivers.yaml` `free_drivers:` via `fw bvp driver --add` with rationale citing `docs/reports/T-2305-bvp-drivers-batch-2026-06-10.md`
- [x] `V_CONTEXT_FABRIC` (w=7) added to `policy/value-drivers.yaml` `free_drivers:` via `fw bvp driver --add` with rationale citing the artefact
- [x] `V_COMPONENT_FABRIC` (w=6) added to `policy/value-drivers.yaml` `free_drivers:` via `fw bvp driver --add` with rationale citing the artefact
- [x] Free-driver pool reaches exactly 5/5 after the three additions (F-RECALL + F-ORCH + the three new)
- [x] Each `fw bvp driver --add` writes a weight-history entry to `.context/bvp-weight-history.yaml`
- [x] `bin/fw bvp driver --help` parses without error post-add (yaml integrity check)

### Human
- [ ] [REVIEW] Global BVP recompute confirmation
  **Steps:**
  1. Follow `docs/reports/T-2306-operator-quickstart.md` §1 (driver-add Sovereign) and §2 (bulk re-estimate via `bash agents/termlink/bvp-estimator/bvp-estimator.sh all`). The quickstart documents the actually-shipped path; T-2305 §8's `fw bvp recompute --scope global` is the deferred verb (T-2245 IW-3) and the quickstart's §2 is the verified substitute.
  2. Open Watchtower `/bvp` to see post-add state and ranking impact.
  3. Optional: run quickstart §3 (per-task `fw bvp confirm` for the 4-task baseline) to surface ranking signal in default `fw bvp` HV-LC sweep.
  **Expected:** Drivers added, estimator sweep completed (one row added to each `.tasks/{active,completed}/T-*.md` `bvp_scores_proposed:` list against the new dimensions), `.context/bvp-weight-history.yaml` has the three add-entries.
  **If not:** Drivers are landed and usable as scoring dimensions immediately; recompute is recommended within 7 days but not blocking.

## Verification

# All three V_* drivers present in free_drivers by NAME. lib/bvp.sh:935 auto-assigns
# slot-positional F-N IDs (F1/F2/F3) — the V_* identity lives in the `name:` field per
# the shipped policy convention (F-RECALL/F-ORCH also use semantic names vs slot IDs).
# Assert on names + count (5/5 free-driver pool — F-RECALL + F-ORCH + 3 V_* new).
python3 -c "import yaml; d=yaml.safe_load(open('policy/value-drivers.yaml')); fd=d.get('free_drivers') or []; assert len(fd)==5, f'expected 5 free drivers, got {len(fd)}'; names={e['name'] for e in fd}; assert {'Recall Leverage','Orchestration Leverage','V_PROMPT_QUALITY','V_CONTEXT_FABRIC','V_COMPONENT_FABRIC'}<=names, f'missing: {names}'"
# Weight-history captured the three additions (file is YAML — grep is safe)
test -f .context/bvp-weight-history.yaml && grep -q "V_PROMPT_QUALITY" .context/bvp-weight-history.yaml
grep -q "V_CONTEXT_FABRIC" .context/bvp-weight-history.yaml
grep -q "V_COMPONENT_FABRIC" .context/bvp-weight-history.yaml

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

## Recommendation

**Recommendation:** GO

**Rationale:** All 6 Agent ACs verified satisfied live: `policy/value-drivers.yaml` ships exactly 5 free drivers (F-RECALL, F-ORCH, V_PROMPT_QUALITY, V_CONTEXT_FABRIC, V_COMPONENT_FABRIC) at the documented weights (6/5/7/7/6). Weight-history records three `driver_add` entries from `agent_session: true` (the Sovereign rail Watchtower/--i-am-human path, per the 2026-06-10 Decisions block). `fw bvp driver --help` parses. The original Verification block asserted on driver `id:` (V_PROMPT_QUALITY etc.) but `lib/bvp.sh:935` auto-assigns slot-positional `F{next_n}` IDs — the V_* identity lives in the `name:` field per the shipped convention (F-RECALL/F-ORCH also use semantic names vs slot IDs). Spec/impl mismatch in the Verification block was fixed at the same time (assert on `name:` + count, preserves intent without lowering the bar). Only the [REVIEW] Human AC remains: open `/bvp`, verify post-add state and ranking impact.

**Evidence:**
- `policy/value-drivers.yaml` lines 204/227/252: id=F3/F1/F2 with name=V_PROMPT_QUALITY/V_CONTEXT_FABRIC/V_COMPONENT_FABRIC, weights 7/7/6, rationale citing `docs/reports/T-2305-bvp-drivers-batch-2026-06-10.md`
- `.context/bvp-weight-history.yaml`: three `verb: driver_add` entries (2026-06-11T16:01:24Z / 16:01:54Z / 16:01:58Z) with `who: root` + `agent_session: true` matching the Sovereign rail
- `fw bvp` HV-LC ranking shows V_*-active scoring (top entries score against F1/F2/F3 dimensions)
- Verification block (this task) re-runs PASS post-mismatch fix
- BVP estimator V_* dedicated handlers shipped sibling (T-2328 commits `db90137e2`+`e0a97b7ee`+`d06186be5`)

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

### 2026-06-10 — Sovereign gate refuses agent-driven driver-add
- **Chose:** Surface operator-facing handoff; do NOT proceed with the three `fw bvp driver --add` invocations under agent control even given the operator's verbal "implement" directive
- **Why:** `fw bvp driver --add` refuses under `$CLAUDECODE=1` (D8 policy-edit sovereignty). Per CLAUDE.md §Autonomous Mode Boundaries: *"Broad directives delegate initiative, NOT authority. When a structural gate blocks an action, the gate wins — always ask, never force."* The verbal "implement" is initiative (which build task to file), not authority (to bypass the Sovereign rail). Same shape as `fw inception decide` / `fw arc close` / `fw tier0 approve`.
- **Rejected:** `--i-am-human` flag from agent control (violates the override semantics — that flag is for human-typing-into-agent-session contexts, not for an agent invoking it on behalf of a verbal "go ahead")
- **Operator path:** Run the three `fw bvp driver --add` invocations from §8 of `docs/reports/T-2305-bvp-drivers-batch-2026-06-10.md` in a non-CLAUDECODE shell, OR use Watchtower `/bvp` add-driver form (if shipped), OR add `--i-am-human` to each command when typing them yourself. Verification block in this task will close the gate once the three drivers land.

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-06-10T10:27:09Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2306-t-2305-go-implement-3-bvp-drivers-vpromp.md
- **Context:** Initial task creation

### 2026-06-10T10:29:14Z — status-update [task-update-agent]
- **Change:** owner: agent → human

## Reviewer Verdict (v1.5)

- **Scan ID:** R-140a591f
- **Timestamp:** 2026-06-11T21:29:51Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
