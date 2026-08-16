---
id: T-2295
name: "OBS-054 leg A — orchestrator-mcp baseline ratchet (8th batch: read-shape suffixes)"
description: >
  OBS-054 leg A — orchestrator-mcp baseline ratchet (8th batch: read-shape suffixes)

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: [orchestrator-mcp, baseline-ratchet, obs-054]
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
created: 2026-06-09T19:39:55Z
last_update: '2026-08-16T22:25:00Z'
date_finished: 2026-06-09T19:43:27Z
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
  - ts: '2026-06-11T22:24:14Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 3
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=3 (body:portability-abstraction); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:25:00Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 3
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=3 (body:portability-abstraction); F-RECALL=0 (no-signal); F-AUTONOMY=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2295: OBS-054 leg A — orchestrator-mcp baseline ratchet (8th batch: read-shape suffixes)

## Context

OBS-054 leg A: the orchestrator-mcp scan (2026-06-09 post-T-2292 re-run) auto-classifies 12 tools via the T-1761 convention: 5 channel-claim mutators (the 8th-batch domain T-2292 extended the classifier for) PLUS 7 read-shape readonly_exempts. `--apply` ratchets all 12 into `.context/audits/orchestrator-mcp-baseline.yaml` in one pass. The 7-batch zero-misclassification track record (T-1755..T-2150) plus T-2292's 8th-batch validator cover exactly this verb/suffix vocabulary. This task is the 8th-batch ratchet sibling to T-2292's classifier extension.

5 mutators ratched (channel-claim domain, T-2292):
- `termlink_channel_claim`, `termlink_channel_claim_force_release`, `termlink_channel_claim_transfer`, `termlink_channel_release`, `termlink_channel_renew`

7 readonly_exempts ratched (read-shape suffixes, all in `termlink_agent_*` / `termlink_channel_*` namespaces — convention scope):
- `termlink_agent_find_idle` (read: discover idle agents)
- `termlink_agent_find_idle_history` (read: history of find_idle calls)
- `termlink_channel_claims` (read: list claims)
- `termlink_channel_claims_history` (read: history of claims)
- `termlink_channel_claims_summary` (read: summary)
- `termlink_channel_claims_summary_all` (read: summary across all)
- `termlink_channel_queue_history` (read: queue history)

Baseline went from 251 → 263 tools (+12). Backup at `.context/audits/orchestrator-mcp-baseline.yaml.bak`.

Leg B (4 unclassified: `termlink_fleet_governor_history`, `termlink_fleet_governor_status`, `termlink_hub_governor_status`, `termlink_whoami`) is OUT OF SCOPE — those are outside T-1761's convention namespaces and need a separate convention-extension decision.

## Acceptance Criteria

### Agent
- [x] `bash agents/audit/orchestrator-mcp-scan.sh --apply` ran successfully; `apply_result:` in LATEST.yaml contains both `applied_mutators` (5) and `applied_readonly` (7) with baseline 251→263.
- [x] `.context/audits/orchestrator-mcp-baseline.yaml` `readonly_exempt.tools` count increased by exactly 7 over pre-apply (189→196) and `mutators_ungated.tools` by exactly 5 (58→63), each containing all 12 named candidates.
- [x] Re-run scan (no `--apply`) shows the 12 candidates do NOT appear in `findings.auto_classified` (they're now baseline). Remaining warnings limited to the 4 unclassified `_governor_*`/`_whoami` tools + tag-format-drift.
- [x] Update OBS-054 status: leg A actioned via `promoted_to: T-2295`, status flips `pending → promoted`. Leg B residual (4 unclassified outside convention scope) noted for operator decision.
- [x] [REVIEWER] Reviewer PASS — verified via `bin/fw reviewer T-2295`.

## Verification

# Re-scan post-apply should NOT re-classify the 7 ratched names (they're in baseline now)
out=$(bash agents/audit/orchestrator-mcp-scan.sh 2>&1); echo "$out" | grep -qE "orchestrator-mcp-scan \((warn|pass)\)"
# Baseline must contain all 7 ratched names
python3 -c "import yaml; b=yaml.safe_load(open('.context/audits/orchestrator-mcp-baseline.yaml')); ro=set(b['readonly_exempt']['tools']); want={'termlink_agent_find_idle','termlink_agent_find_idle_history','termlink_channel_claims','termlink_channel_claims_history','termlink_channel_claims_summary','termlink_channel_claims_summary_all','termlink_channel_queue_history'}; missing=want-ro; assert not missing, f'missing from baseline: {missing}'"
# LATEST.yaml's auto_classified.readonly_exempt should NOT contain the 7 names (they're baseline now)
python3 -c "import yaml; r=yaml.safe_load(open('.context/audits/orchestrator-LATEST.yaml')); ac=set(r['findings']['auto_classified'].get('readonly_exempt') or []); leaked={'termlink_agent_find_idle','termlink_agent_find_idle_history','termlink_channel_claims','termlink_channel_claims_history','termlink_channel_claims_summary','termlink_channel_claims_summary_all','termlink_channel_queue_history'}&ac; assert not leaked, f'still in auto_classified: {leaked}'"
# OBS-054 must be promoted_to: T-2295
python3 -c "import yaml; inb=yaml.safe_load(open('.context/inbox.yaml')); obs=inb['observations'] if isinstance(inb, dict) else inb; rec=[o for o in obs if o['id']=='OBS-054'][0]; assert rec['promoted_to']=='T-2295', f'OBS-054 promoted_to={rec.get(\"promoted_to\")!r}'; assert rec['status']=='promoted', f'OBS-054 status={rec.get(\"status\")!r}'"

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

### 2026-06-09T19:39:55Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2295-obs-054-leg-a--orchestrator-mcp-baseline.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-21e8baa7
- **Timestamp:** 2026-06-09T19:43:28Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-06-09T19:43:27Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
