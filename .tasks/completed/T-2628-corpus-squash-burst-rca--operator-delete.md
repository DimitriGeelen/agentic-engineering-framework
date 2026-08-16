---
id: T-2628
name: "Corpus squash burst RCA — operator delete-all+resave regressed task-lifecycle
  to v4-era content and dropped workflowMeta uuids"
description: >
  Corpus squash burst RCA — operator delete-all+resave regressed task-lifecycle to
  v4-era content and dropped workflowMeta uuids

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
created: 2026-07-27T17:56:52Z
last_update: '2026-08-16T22:25:12Z'
date_finished: 2026-07-27T18:01:16Z
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
  - ts: '2026-07-27T18:00:05Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-07-27T18:00:08Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=0 
      (no-signal); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal);
      F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:25:12Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 1
      D3: 2
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=1 (body:log-or-error-line); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=0 
      (no-signal); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal);
      F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2628: Corpus squash burst RCA — operator delete-all+resave regressed task-lifecycle to v4-era content and dropped workflowMeta uuids

## Context

While picking up the T-2620 GO, git status showed 13 tracked corpus version files deleted (all v2+ of the five real maps, incl. task-lifecycle v5 with the state carriers) and Watchtower logged a 13-call `POST /api/delete` burst at 18:58:5x local. Task filed under the initial regression hypothesis; investigation disproved it — see RCA. Title's "regressed to v4-era / dropped uuids" reflects the initial (wrong) read, kept for honesty.

## Damage assessment (AC-1)

| Map | New v1 canonically matches | In-file uuid (before → after) | meta.json uuid |
|-----|---------------------------|-------------------------------|----------------|
| aef-audit-cron | old v3 (latest) | absent → absent | preserved |
| aef-dispatch-loop | old v1/v2/v3 (all canon-equal) | absent → absent | preserved |
| aef-inception-flow | old v3/v4 (v4 = latest) | absent → absent | preserved |
| aef-session-lifecycle | old v2/v3 (v3 = latest) | absent → absent | preserved |
| aef-task-lifecycle | old v5 (latest, **all 7 state carriers intact**) | absent → absent | preserved (1f9b5f0c…) |

Canonical signature = node uids/types/names/states + flow triples, layout/version ignored. Ghost registry unchanged (1 pre-existing t2584 ghost). draft-trigger-handling untouched (v1-v3 intact).

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] Full damage assessment recorded: per map — content era of the re-saved v1 (which pre-burst version it matches), uuid presence in workflowMeta and meta.json, ghost-registry impact of any uuid loss — see §Damage assessment table: zero content loss, every v1 = latest pre-burst content
- [x] RCA section filled: what fired the 13-delete burst (operator flow vs editor bug), why the content looked regressed, why uuid looked dropped — both initial reads disproven with evidence
- [x] Restore path decided: NO restore needed — zero content loss proven canonically; squash committed to git as the operator's intended store state (not silently reverted); finding reported to operator in session summary
- [x] Conformance rail + corpus lint state after resolution: rail alive (same DIVERGENT 2-pair signal, carriers intact), lint at 2-finding baseline, prove PASS with uuid preserved — nothing silently dormant
- [x] 832-side defect check: DISPROVED — pre-burst latest versions also had no in-file workflowMeta uuid, so the editor dropped nothing; no rail report warranted

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

python3 tools/corpus_conformance.py > /tmp/.t2628-conf.out 2>&1; grep -q "DIVERGENT" /tmp/.t2628-conf.out
out=$(python3 tools/corpus_lint.py 2>&1); echo "$out" | grep -q "2 finding(s)"
out=$(bin/fw corpus prove aef-task-lifecycle 2>&1); echo "$out" | grep -q "prove: PASS"
test "$(grep -c 'state="' .context/designer/projects/aef-task-lifecycle/v1.bpmn)" = "7"

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

**Symptom:** 13 tracked corpus version files deleted from the working tree (all v2+ across the five real maps, incl. task-lifecycle v5 carrying the T-2621 state annotations); Watchtower access log shows 13 `POST /api/delete` in ~2s at 18:58:5x local from 192.168.10.107, each map following the pattern GET-latest → delete×N → save → GET-v1. Initial reads suggested content regression (grep found 0 state carriers in new v1) and in-file uuid loss.

**Root cause:** intentional operator history-squash via the designer UI — per map: load latest, delete all server versions, re-save current editor content as fresh v1. Canonical comparison (node uids/types/names/states + flows) proves every re-saved v1 equals the latest pre-burst version — zero content loss, all 7 task-lifecycle state carriers intact. Both alarming initial reads were investigation artifacts: (1) the "0 carriers" grep used `'aef:meta state='` but the attribute order is `note="…" state="…"`; (2) "uuid dropped" — pre-burst latest versions never had an in-file `workflowMeta uuid=` either (identity lives in meta.json, which the squash preserved on all five maps).

**Why structurally allowed:** /api/delete is an intentional operator affordance (T-2529 gallery API) — nothing wrong happened structurally. The gap this incident actually exposed is observational: a burst of destructive store operations is only visible as raw access-log lines and untracked git deletions; nothing correlates "store changed outside fw corpus" into an operator/agent-visible signal, so the next agent to touch the store discovers it cold, mid-task, and has to reconstruct intent forensically (this RCA cost a full investigation cycle to conclude "no action needed").

**Prevention:** the canonical-comparison method used here (parse both, compare node/flow signature, layout/version ignored) is the reusable tool — recorded in this task + session memory; `git`-tracked store means any future squash is always recoverable and diffable. No new gate warranted: the operation was legitimate, rails (conformance/lint/prove/ghosts) all held, and adding friction to an operator store affordance would violate sovereignty. If a second squash-scare recurs, revisit as a store-changelog signal (fw note obs candidate), per G-019 two-strike rule.

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

### 2026-07-27T17:56:52Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2628-corpus-squash-burst-rca--operator-delete.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-7f62e5ed
- **Timestamp:** 2026-07-27T18:01:18Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-07-27T18:01:16Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
