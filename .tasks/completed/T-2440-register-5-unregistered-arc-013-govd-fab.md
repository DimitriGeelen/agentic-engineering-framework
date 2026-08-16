---
id: T-2440
name: "register 5 unregistered arc-013 govd fabric components (drift hygiene)"
description: >
  register 5 unregistered arc-013 govd fabric components (drift hygiene)

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
created: 2026-06-20T06:51:40Z
last_update: '2026-08-16T22:25:06Z'
date_finished: 2026-06-20T06:58:45Z
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
  - ts: '2026-08-16T22:25:06Z'
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
      F2: 1
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=0 
      (no-signal); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal);
      F2=1 (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
---

# T-2440: register 5 unregistered arc-013 govd fabric components (drift hygiene)

## Context

`fw fabric drift` reported 5 unregistered components — all arc-013 govd files (govd.sh,
agents/git/lib/commit.sh, lib/govd_relay.py, lib/govd_envelope.py, lib/govd_holder.py)
committed 2026-06-18 by T-2430/T-2431/T-2432 whose build tasks never ran
`fw fabric register`. Drift is a standing audit-adjacent signal; clearing it keeps the
topology map honest. Pure fabric hygiene — registers cards, advances no arc deliverable
(arc-013 stays sovereign/human-gated).

## Acceptance Criteria

### Agent
- [x] 5 govd components registered (4 new cards created; agents/git/lib/commit.sh already had a card)
- [x] `govd.sh` card enriched — subsystem `framework-core` (was `unknown`), accurate purpose, 5 depends_on edges (3 calls to govd_*.py + 2 reads of policy files)
- [x] `fw fabric drift` reports 0 unregistered / 0 orphaned / 0 stale
- [x] All new/edited fabric cards parse as valid YAML

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
# V1: drift clean. Retry up to 3x — fw fabric drift intermittently emits a spurious
# false-positive that clears on re-run (OBS-080); the retry makes this gate robust to it.
for i in 1 2 3; do out=$(bin/fw fabric drift 2>&1); echo "$out" | grep -q "unregistered: 0, orphaned: 0, stale: 0" && break; done; echo "$out" | grep -q "unregistered: 0, orphaned: 0, stale: 0"
python3 -c "import yaml; yaml.safe_load(open('.fabric/components/agents-govd-govd.yaml'))"
grep -q "^subsystem: framework-core" .fabric/components/agents-govd-govd.yaml
test -f .fabric/components/lib-govd_relay.yaml -a -f .fabric/components/lib-govd_envelope.yaml -a -f .fabric/components/lib-govd_holder.yaml

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

### 2026-06-20 — file under no arc, not arc-013
- **Chose:** unassigned hygiene build task (no `arc_id`).
- **Why:** registering fabric cards is framework topology hygiene; it advances no arc-013 deliverable. arc-013 is sovereign/human-gated (must not be advanced or closed by the agent). Entangling a hygiene commit with the arc would muddy its closure ledger.
- **Rejected:** `arc_id: arc-013` — would imply the commit is arc progress, which it is not.

### 2026-06-20 — intermittent drift false-positive → filed OBS-080
- **Observed (2×):** (1) Right after the batch of 4 `fw fabric register` writes, one `fw fabric drift` run flagged `lib/config-file.sh` as unregistered — despite its card (`lib-config-file.yaml`, `id: lib/config-file.sh`) existing intact and the compaction audit minutes earlier reporting "0 unregistered". (2) The V1 verification command failed once, then passed 3/3 on immediate re-run. No duplicate card id; card correctly keyed.
- **Chose:** file OBS-080 (lightweight observation, not a task/concern); do NOT fix in T-2440.
- **Why:** it's a false-*positive* (over-reports; never hides real drift) so low-risk, and it self-clears on re-run. Likely an index-rebuild/scan race in `agents/fabric/lib/drift.sh`. Per "one bug = one task" it's out of T-2440's scope; OBS-080 carries the "promote to a real task if it recurs persistently or reds an audit" trigger.

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-06-20T06:51:40Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.claude/worktrees/inception-gov-payload-mediation/.tasks/active/T-2440-register-5-unregistered-arc-013-govd-fab.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-0c3dbf4c
- **Timestamp:** 2026-06-20T06:58:50Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#1 (Agent)** — 5 govd components registered (4 new cards created; agents/git/lib/commit.sh already had a card)
  - **AC-verify-mismatch** (narrow, heuristic) — `path=agents/git/lib/commit.sh in: 5 govd components registered (4 new cards created; agents/git/lib/commit.sh already had a card)`

### 2026-06-20T06:58:45Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
