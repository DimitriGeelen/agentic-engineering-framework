---
id: T-2461
name: "fw doctor MCP check is framework-only — SKIPs misleadingly on consumers (T-2459
  follow-on)"
description: >
  fw doctor MCP check is framework-only — SKIPs misleadingly on consumers (T-2459
  follow-on)

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [bin/fw]
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
created: 2026-06-22T10:32:05Z
last_update: '2026-08-16T22:25:06Z'
date_finished: 2026-06-22T19:25:40Z
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
      D4: 3
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=3 (body:portability-abstraction); F-RECALL=0 
      (no-signal); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal);
      F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2461: fw doctor MCP check is framework-only — SKIPs misleadingly on consumers (T-2459 follow-on)

## Context

T-2459 split framework_root from project_root for the MCP server, but `fw doctor`'s
framework-MCP-manifest check still resolved its asset paths (manifest, tool-set.yaml,
manifest.py) against `$PROJECT_ROOT`. In a vendored consumer those assets live under
`$FRAMEWORK_ROOT` (`.agentic-framework/agents/mcp/`), so doctor SKIPped misleadingly
("manifest absent — run: fw mcp emit-manifest") even though the manifest IS present
(vendored) and `emit-manifest` can't run there (no tool-set.yaml). Last T-2458 follow-on
for consumer-awareness of the MCP surface (sibling to T-2459/T-2460). bin/fw:1375-1423.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] doctor MCP-manifest asset paths (manifest, tool-set.yaml, manifest.py) resolve via `_fw_root="${FRAMEWORK_ROOT:-$PROJECT_ROOT}"` — no-op when the two roots are equal (framework repo = no regression), vendored path on a consumer (bin/fw:1382-1384, 1402)
- [x] runtime pid file stays per-project on `$PROJECT_ROOT` (RUNTIME state, not a vendored asset) (bin/fw:1389)
- [x] absent-manifest SKIP branch is consumer-aware: vendored framework (`_fw_root != PROJECT_ROOT`) → "run: fw upgrade"; framework repo → "run: fw mcp emit-manifest" (bin/fw:1414-1422)
- [x] regression test `t2461_doctor_mcp_consumer_path.bats` pins the resolution source + replays consumer/framework layouts (proves the bug under old logic), 6/6 green

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
out=$(bats tests/unit/t2461_doctor_mcp_consumer_path.bats 2>&1); echo "$out" | grep -q "^ok 6 " && ! echo "$out" | grep -q "^not ok"

## RCA

**Symptom:** On a vendored consumer, `fw doctor`'s framework-MCP check prints
`SKIP framework MCP manifest absent — run: fw mcp emit-manifest` even though the
manifest is present (vendored under `.agentic-framework/agents/mcp/`) and
`emit-manifest` cannot run there (no `tool-set.yaml` on consumers). Invisible in the
framework repo, wrong on every consumer.

**Root cause:** The doctor block resolved framework ASSET paths against `$PROJECT_ROOT`.
After T-2459 split framework_root (assets) from project_root (operating dir), those roots
diverge on a consumer — assets are under `$FRAMEWORK_ROOT`, project under the checkout —
but this one check block was never migrated to the split. Same conflation class as the
T-2459 server bug, one surface downstream.

**Why structurally allowed:** `fw doctor` is slow (~150s, network-coupled) so it is never
run in bats; the framework repo (where the agent develops) has `FRAMEWORK_ROOT==PROJECT_ROOT`,
so the wrong path is identical to the right one — the bug is invisible at the only place it
gets exercised. Pure framework-only-test blindness (sibling to T-2459's own gap).

**Prevention:** `t2461_doctor_mcp_consumer_path.bats` replays the exact resolution snippet
against a synthetic consumer layout (vendored manifest under `.agentic-framework/`) and
asserts the OLD `$PROJECT_ROOT` logic reports ABSENT while the new `_fw_root` logic reports
FOUND — pinning both the fix and the bug without invoking slow `fw doctor`. Source-pins lock
the `${FRAMEWORK_ROOT:-$PROJECT_ROOT}` form so a future refactor can't silently revert it.

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

### 2026-06-22T10:32:05Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.claude/worktrees/inception-gov-payload-mediation/.tasks/active/T-2461-fw-doctor-mcp-check-is-framework-only--s.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-cd11c119
- **Timestamp:** 2026-06-22T19:25:41Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-06-22T19:25:40Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
