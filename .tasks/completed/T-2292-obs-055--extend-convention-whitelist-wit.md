---
id: T-2292
name: "OBS-055 — extend convention whitelist with channel-claim mutator verbs (claim/release/renew/transfer)"
description: >
  OBS-055 — extend convention whitelist with channel-claim mutator verbs (claim/release/renew/transfer)

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: [governance, mcp-classifier]
components: [agents/audit/orchestrator-mcp-scan.sh, 
      tests/unit/test_orchestrator_mcp_classify.py]
related_tasks: [T-1761, T-2154, T-2150, T-2073]
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
created: 2026-06-09T18:57:03Z
last_update: '2026-08-16T22:25:00Z'
date_finished: 2026-06-09T19:01:58Z
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
  - ts: '2026-06-09T19:00:03Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 2
      effort: 8
    rationale: blast_radius=3 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-06-09T19:00:03Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 3
      F-RECALL: 0
      F-ORCH: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=3 (body:portability-abstraction); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal)
    rubric_sha: e4a00f38e801
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

# T-2292: OBS-055 — extend convention whitelist with channel-claim mutator verbs (claim/release/renew/transfer)

## Context

OBS-055 — running `agents/audit/orchestrator-mcp-scan.sh --apply` revealed nine
`termlink_channel_*` tools classified as `readonly_exempt` by the T-1761
convention auto-classifier (`CONVENTION_MUTATOR_VERBS_SINGLE` at
`agents/audit/orchestrator-mcp-scan.sh:166`). Five of them are state-mutating:
`termlink_channel_claim`, `termlink_channel_claim_force_release`,
`termlink_channel_claim_transfer`, `termlink_channel_release`,
`termlink_channel_renew`. The whitelist was built from chat-system verbs
(`post/send/edit/react/...`) across 7 batches with a 196-tool / zero-
misclassification track record — but channel-claim/lease is a new domain. Under
`--apply` this would silently flip those five into `readonly_exempt` in
`.context/audits/orchestrator-mcp-baseline.yaml`, which is precisely the
sovereignty surface the auto-classifier is supposed to protect (a state-mutating
tool tagged `readonly` slips past §ACD/operator review and becomes callable from
any agent that consumes the baseline as a capability gate).

OBS-055 offered two fix shapes: (a) extend the verb whitelist with claim-domain
mutators, or (b) exclude `termlink_channel_claim*` from `CONVENTION_NAMESPACES`.
This task ships (a) — it codifies the convention discipline (claim/release/renew/
transfer are universally state-mutating across domains) rather than carving a
hole in the namespace coverage. The four legitimately-readonly tools
(`termlink_channel_claims`, `claims_history`, `claims_summary`,
`claims_summary_all`) keep their `readonly_exempt` classification because their
last-segment suffix (`claims`/`history`/`summary`/`all`) is read-shape.

## Acceptance Criteria

### Agent
- [x] `CONVENTION_MUTATOR_VERBS_SINGLE` in `agents/audit/orchestrator-mcp-scan.sh` includes the four new single-word verbs `claim`, `release`, `renew`, `transfer` (channel-claim/lease domain).
- [x] A one-line code comment immediately above the extended verbs documents the new domain so the next 8th-batch author sees why these verbs were added.
- [x] `tests/unit/test_orchestrator_mcp_classify.py` pins all five state-mutating tools as `mutators_ungated` (`termlink_channel_claim`, `termlink_channel_claim_force_release`, `termlink_channel_claim_transfer`, `termlink_channel_release`, `termlink_channel_renew`) and all four legitimate read-only tools stay `readonly_exempt` (`termlink_channel_claims`, `termlink_channel_claims_history`, `termlink_channel_claims_summary`, `termlink_channel_claims_summary_all`). All 9 new tests + existing 13 PASS.
- [x] OBS-055 promoted to T-2292 in `.context/inbox.yaml` (status: promoted).
- [x] [REVIEWER] Reviewer PASS — verified via `bin/fw reviewer T-2292`.

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

# 1. The four new verbs are present in the whitelist (parse frozenset body — one line).
python3 -c "import re; s=open('agents/audit/orchestrator-mcp-scan.sh').read(); m=re.search(r'CONVENTION_MUTATOR_VERBS_SINGLE = frozenset.\{(.*?)\}.', s, re.DOTALL); assert m, 'frozenset block'; b=m.group(1); assert all(repr(v) in b for v in ['claim','release','renew','transfer']), b; print('verbs present')"

# 2. All classifier tests pass (existing + the 9 new ones).
python3 -m pytest tests/unit/test_orchestrator_mcp_classify.py -q

# 3. Reviewer PASS or CONCERN, never FAIL. L-387 capture-first single pipe.
rev=$(bin/fw reviewer T-2292 2>&1); echo "$rev" | grep -qE "Overall:.*(PASS|CONCERN)"
rev=$(bin/fw reviewer T-2292 2>&1); ! echo "$rev" | grep -qE "Overall:.*FAIL"

# 4. OBS-055 promoted to T-2292 in inbox (one line).
python3 -c "import yaml; d=yaml.safe_load(open('.context/inbox.yaml')); o=next(x for x in d['observations'] if x['id']=='OBS-055'); assert o['status']=='promoted' and o['promoted_to']=='T-2292', o; print('OBS-055 promoted')"

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

### 2026-06-09T18:57:03Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2292-obs-055--extend-convention-whitelist-wit.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-23879bc8
- **Timestamp:** 2026-06-09T19:02:00Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

- **Suppressed:** 1 (by override)
  - l387-sigpipe-risk @ Verification:line 40

### 2026-06-09T19:01:58Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
