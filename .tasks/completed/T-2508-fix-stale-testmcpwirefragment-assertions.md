---
id: T-2508
name: "Fix stale test_mcp_wire_fragment assertions (framework-mcp -> fw key, T-2283
  drift)"
description: >
  OBS-089: tests/unit/test_mcp_wire_fragment.bats t2/t3/t4 assert the fragment top-key
  'framework-mcp', but T-2283 (commit fcd0ca0e8) intentionally renamed it to 'fw'
  for arc-010 prefix match. Fragment is correct; test assertions are stale. Update
  t2/t3/t4 + comments to assert 'fw'.

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [tests/unit/test_mcp_wire_fragment.bats]
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
created: 2026-07-06T12:37:02Z
last_update: '2026-08-16T22:25:08Z'
date_finished: 2026-07-06T12:39:56Z
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
  - ts: '2026-08-16T22:25:08Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 3
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 1
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=3 (body:portability-abstraction); F-RECALL=0 
      (no-signal); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal);
      F2=1 (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
---

# T-2508: Fix stale test_mcp_wire_fragment assertions (framework-mcp -> fw key, T-2283 drift)

## Context

Surfaced via OBS-089. `tests/unit/test_mcp_wire_fragment.bats` (T-2272) t2/t3/t4 assert the
fragment's JSON top-key is `framework-mcp`. T-2283 (commit `fcd0ca0e8`) intentionally renamed
that key to `fw` so the MCP tool prefix resolves to `mcp__fw__*` (L-467: prefix derives from the
`.mcp.json` server KEY). The fragment file is correct; the test assertions drifted. Fix = update
the 4 stale KEY assertions (t2 shape, t3 args-path, t4 stdout, + t2 comment/name) from
`framework-mcp` to `fw`. The *filename* `framework-mcp.mcp-fragment.json` is unchanged (only the
key inside it was renamed), so filename references stay.

## Acceptance Criteria

### Agent
- [x] t2/t3/t4 assert the fragment top-key is `fw` (not `framework-mcp`)
- [x] Filename references (`framework-mcp.mcp-fragment.json`) are left intact — only the JSON key changed
- [x] Full test file passes: `bats tests/unit/test_mcp_wire_fragment.bats` → 6/6 ok

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
bats tests/unit/test_mcp_wire_fragment.bats
! grep -q "'framework-mcp' in d" tests/unit/test_mcp_wire_fragment.bats

## RCA

**Symptom:** `bats tests/unit/test_mcp_wire_fragment.bats` fails t2/t3/t4 on master (AssertionError:
`'framework-mcp' in d` / `d['framework-mcp']`). t1/t5/t6 pass. Pre-existing (`git diff HEAD` = 0 lines).

**Root cause:** T-2283 (commit `fcd0ca0e8`) renamed the fragment's JSON top-key `framework-mcp` → `fw`
to make the MCP tool prefix `mcp__fw__*` (L-467). The rename updated the fragment file but not the
T-2272 test that pins the fragment's shape. Classic contract-renamed / test-not-updated drift.

**Why structurally allowed:** T-2283's `## Verification` did not re-run the T-2272 fragment test, so
the completion gate never executed the assertions that its own change broke. The two tasks touch the
same contract (`framework-mcp.mcp-fragment.json`) but T-2283's verification scope didn't include the
downstream test file. Nothing links a contract-key change to the test that pins that key.

**Prevention:** This task's own Verification pins both directions — the test passes AND the stale
string `'framework-mcp' in d` is absent from the file (guards against a partial re-drift). The deeper
class (rename-a-contract-without-running-its-pinning-test) is a known pattern; the fabric blast-radius
check (`fw fabric blast-radius`) on the fragment card would surface the test as a dependant — noting
as the durable rail rather than adding a bespoke lint for this one key.

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

### 2026-07-06T12:37:02Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.claude/worktrees/t100199-close/.tasks/active/T-2508-fix-stale-testmcpwirefragment-assertions.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-75c93222
- **Timestamp:** 2026-07-06T12:39:58Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-07-06T12:39:56Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
