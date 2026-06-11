---
id: T-2171
name: "BVP T-NEW-E: F-AUTONOMY activation gate — uncomment carve when continuous-run
  arc lands"
description: >
  v3 schema (T-2166) ships F-AUTONOMY carved (commented) in policy/value-drivers.yaml
  lines ~171-200. Activation requires (a) T-2158 continuous-run arc demonstrating
  mechanical compact→resume autonomy AND (b) L5/L6 autonomy criteria green (auto-issue
  gen, auto-merge, closed production-feedback loop). When both conditions hold, T-NEW-E
  uncomments the carve, sets weight=4, and validates the rubric ZERO-NEGATIVE guardrail
  (autonomy that removes Tier-0 gates scores ≤0).

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [v3-followup-E, f-autonomy-activation, arc:value-prioritisation, 
      blocked-on-T-2158]
components: []
related_tasks: [T-2158, T-2166, T-2168, T-2170]
arc_id: value-prioritisation
created: 2026-06-01T22:22:20Z
last_update: '2026-06-12T01:05:00Z'
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
  - ts: '2026-06-01T22:30:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 1
      F-ORCH: 1
    rationale: "D1=4 (body:structural-gate); D2=2 (body:telemetry-or-audit-entry);
      D3=2 (body:default-change); D4=2 (body:env-class-handled); F-RECALL=1 (body/tag
      hits for 'F-RECALL': 1); F-ORCH=1 (body/tag hits for 'F-ORCH': 1)"
    rubric_sha: e4a00f38e801
  - ts: '2026-06-05T18:00:04Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 2
      D3: 0
      D4: 2
      F-RECALL: 2
      F-ORCH: 4
    rationale: D1=4 (body:structural-gate); D2=2 
      (body:telemetry-or-audit-entry); D3=0 (no-signal); D4=2 
      (body:env-class-handled); F-RECALL=2 (body:lightly-promoted); F-ORCH=4 
      (body:rubric-routable)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T16:00:03Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 2
      D3: 0
      D4: 2
      F-RECALL: 2
      F-ORCH: 4
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=2 
      (body:telemetry-or-audit-entry); D3=0 (no-signal); D4=2 
      (body:env-class-handled); F-RECALL=2 (body:lightly-promoted); F-ORCH=4 
      (body:rubric-routable); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:23:32Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 2
      D3: 0
      D4: 2
      F-RECALL: 2
      F-ORCH: 4
      F3: 1
      F1: 0
      F2: 1
    rationale: D1=4 (body:structural-gate); D2=2 
      (body:telemetry-or-audit-entry); D3=0 (no-signal); D4=2 
      (body:env-class-handled); F-RECALL=2 (body:lightly-promoted); F-ORCH=4 
      (body:rubric-routable); F3=1 (body/components:prompt-incidental); F1=0 
      (no-signal); F2=1 (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-06-01T22:30:03Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2171: BVP T-NEW-E: F-AUTONOMY activation gate — uncomment carve when continuous-run arc lands

## Context

F-AUTONOMY is carved (commented) in `policy/value-drivers.yaml` lines ~171-200 with full rubric, guardrails, and retire_when blocks already written. The carve waits on the continuous-run-arc dogfood (T-2158) plus a downstream L5/L6 autonomy milestone. v3 verdict reasoning is captured in `docs/reports/T-2157-value-drivers-v3-redesign.md §F-AUTONOMY Verdict`.

**Activation preconditions (gate this task):**
1. T-2158 (continuous-run arc) has shipped at least one compact→resume cycle without operator intervention end-to-end (evidence: dispatch log + at least one resumed cycle in `.context/dispatches.jsonl` or equivalent).
2. At least one L5/L6 milestone is operational — pick whichever lands first: auto-issue gen, auto-merge, closed production-feedback loop.

**Activation steps (when preconditions met):**
- Uncomment the F-AUTONOMY block in `policy/value-drivers.yaml`.
- Confirm weight=4 (below F-ORCH=5, F-RECALL=6).
- Verify Sovereignty guardrail: rubric level-0 explicitly scores ZERO-or-NEGATIVE when a Tier-0 gate is removed.
- Run smoke: `fw bvp`, `fw bvp --include-proposed`, `fw bvp T-XXX` all rc=0 (same walk as T-2166).
- Update `bvp-estimator` (T-2168 follow-on) to score F-AUTONOMY using the policy rubric.

## Acceptance Criteria

### Agent
- [ ] `policy/value-drivers.yaml` `free_drivers:` list contains an active `id: F-AUTONOMY` entry (uncommented), `weight: 4`, `polarity: positive`, rubric levels 0-5 present, guardrails block present, retire_when block present. Verification: `python3 -c "import yaml; d=yaml.safe_load(open('policy/value-drivers.yaml')); ids=[fd['id'] for fd in d.get('free_drivers',[])]; assert 'F-AUTONOMY' in ids, ids"`
- [ ] Level-0 rubric text explicitly names the Sovereignty-violation case (removing a safety-critical human gate scores ZERO, never high). Verification: `grep -A 3 "F-AUTONOMY" policy/value-drivers.yaml | grep -A 2 "^[[:space:]]*0:" | grep -qi "sovereignty\|tier 0\|zero"`
- [ ] guardrails text explicitly forbids positive scoring for reducing oversight on Tier-0 / irreversible / high-blast-radius actions. Verification: `awk '/F-AUTONOMY/,/retire_when:/' policy/value-drivers.yaml | grep -qi "tier 0\|irreversible\|high-blast"`
- [ ] Pre-activation gate evidence captured in a `## Decisions` entry on this task: T-2158 cycle reference + L5/L6 milestone reference, each as a one-line citation.
- [x] BVP estimator (`agents/termlink/bvp-estimator/estimator.py`) has a `score_f_autonomy` scorer registered in the dispatch map, or a documented decision to defer that to a sibling task. **Pre-flight evidence:** T-2329 (commit `9d5377baa`) defines `score_f_autonomy` at `agents/termlink/bvp-estimator/estimator.py:889` and registers it in the dispatch `handlers` dict at line 1086. Handler is shipped DORMANT — `_load_drivers()` won't yield `F-AUTONOMY` while the policy carve is commented, so `estimate_task()` won't dispatch here (see comment at estimator.py:894-896). 89 PASS (+14 new tests) per T-2329 commit message. AC's affirmative branch satisfied; documented-deferral branch not needed.
- [x] No regression on the v3 smoke: `fw bvp` rc=0, `fw bvp --include-proposed` rc=0, `fw bvp T-2158` rc=0. Verification: `out=$(bin/fw bvp 2>&1); echo $?` == 0 (and similar for the other two calls). **Pre-flight evidence (2026-06-12):** All three smoke commands returned rc=0 with V_* trio active in policy and F-AUTONOMY still carved (pre-activation baseline). `fw bvp` returns "No tasks have bvp_scores: set yet" (expected — no Sovereign confirms yet); `fw bvp --include-proposed` renders HV-LC rank with V_*-aware scores; `fw bvp T-2158` returns per-driver detail. Smoke confirms V_* trio addition (T-2306) did not regress the BVP CLI. Activation-time re-run remains required (the carve uncomment changes `_load_drivers()` output by one driver) — this pre-flight establishes the baseline.
- [ ] Single-driver removal smoke: `bin/fw bvp confirm T-2158 --F-AUTONOMY 3 --i-am-human` updates the task frontmatter (`bvp_scores.F-AUTONOMY: 3`). Reverts cleanly via subsequent `--F-AUTONOMY ""` or unset path (verifies the activation didn't break the confirm flow).

### Human
- [ ] [REVIEW] F-AUTONOMY activation is the right call right now (preconditions genuinely met, not just nominally met).
  **Steps:**
  1. Read the `## Decisions` entry on this task (T-2158 cycle citation + L5/L6 milestone)
  2. Confirm the cited cycle actually shipped without operator touch end-to-end
  3. Confirm the L5/L6 milestone cited is operational, not just shipped-code
  **Expected:** Both preconditions are real; activating now adds signal without inviting Sovereignty erosion.
  **If not:** Set this task back to `captured` and document which precondition is unmet.

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

### 2026-06-12 — Pre-flight strategy (partial closure under captured ACs)
- **Chose:** Tick AC#5 + AC#6 now with cited pre-flight evidence; leave AC#1-4 + AC#7 for the operator-gated activation pass.
- **Why:** AC#5 became mechanically satisfiable when T-2329 (`9d5377baa`) shipped `score_f_autonomy` in `handlers[]`. AC#6 is a baseline smoke that can re-run at activation. Surfacing the pre-flight separates the "tooling-ready" half (agent-doable) from the "activation-decision" half (Sovereign + T-2158 precondition), so the operator pass has half the work pre-staged.
- **Rejected:** Wait for full activation. Reason: leaves AC#5 + AC#6 in a "tickable but unticked" state for an unbounded time. Pre-flight reduces that window without forcing any Sovereign decision.

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

### 2026-06-01T22:22:20Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2171-bvp-t-new-e-f-autonomy-activation-gate--.md
- **Context:** Initial task creation

### 2026-06-08T15:58:46Z — status-update [task-update-agent]
- **Change:** horizon: later → next

### 2026-06-11T23:03:52Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)
