---
id: T-2507
name: "Surface recorded-not-surfaced failure sinks in fw doctor (OBS-090)"
description: >
  Surface recorded-not-surfaced failure sinks in fw doctor (OBS-090)

status: started-work
workflow_type: build
owner: agent
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
created: 2026-07-06T10:32:03Z
last_update: 2026-07-06T10:32:03Z
date_finished: null
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
---

# T-2507: Surface recorded-not-surfaced failure sinks in fw doctor (OBS-090)

## Context

T-2506 traced the operator's "we keep losing memory" to a *recorded-but-not-surfaced*
failure: the pre-compact handover died and wrote a `FAILED` line to `.compact-log`, but
nothing surfaced it, so memory-capture could fail across every `/compact` while `/compact`
reported success. OBS-090 generalises the class: **any error path that records a failure
to a persistent file but is not surfaced by `fw doctor`/audit is blindness with a paper
trail.** This task audits for other such sinks and surfaces the highest-value invisible
ones. Sibling in spirit to T-2374 (which *created* the honest log line) — this closes the
*surfacing* leg.

## Acceptance Criteria

### Agent
- [x] AC1: Enumerated persistent failure-recording sinks in `lib/`, `agents/`, `bin/fw`. Findings in RCA below (file:line).
- [x] AC2: Classified surfaced vs invisible. Result: surfacing is well-covered post-T-2506 — the only genuine *not-surfaced/not-recorded* failure found was checkpoint.sh's budget-critical auto-handover.
- [x] AC3: Surfaced it — checkpoint.sh now records `[checkpoint] Handover generated|FAILED` to `.compact-log`; doctor Check 5d broadened to catch both `[pre-compact]` and `[checkpoint]` and name the source. No manufactured surfacing (generic `*.stderr` sweep was evaluated and rejected — stale-content false positives, inferior to the semantic compact-log check).
- [x] AC4: `tests/governance/test_checkpoint_handover_recorded.bats` (6/6) + no regression to T-2506's suite (12/12 combined).
- [x] AC5: Out-of-scope sinks noted in RCA: `notify` ntfy failures are advisory-by-design (not recorded — a deliberate choice, not blindness); `.hook-crashes.log`, mirror divergence, bypass-log are all already surfaced.

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

bash -n agents/context/checkpoint.sh
grep -Eq '\[checkpoint\] \[auto\] Handover FAILED' agents/context/checkpoint.sh
bats tests/governance/test_checkpoint_handover_recorded.bats
bats tests/governance/test_precompact_handover_robust.bats

## RCA

**Symptom:** OBS-090 follow-up to T-2506. Audit question: where else does the framework
record a failure to a file but never surface it (the class that caused the operator's
memory loss)?

**Audit findings (AC1/AC2) — failure-recording sinks and their surfacing:**
- `.compact-log` / `.pre-compact.handover.stderr` — **surfaced** (T-2506 doctor Check 5d).
- `.hook-crashes.log` — **surfaced** (doctor Check, T-821: WARN today / INFO historical).
- `.gate-bypass-log.yaml`, `bypass-log.yaml` — **surfaced** (audit.sh:1958/1971/2006).
- mirror `push-failed` (`.mirror-sync.log`) — **surfaced** (doctor mirror-divergence check, bin/fw:2212 — checks divergence directly, stronger than reading the log).
- `notify` ntfy push failure — **not recorded, advisory-by-design** (notify.sh:16 — a deliberate choice; not blindness).
- `.context/bus/handler.log` — dormant T-110 spike stub; logs operations only, no failure records.
- **checkpoint.sh budget-critical auto-handover (T-179) — NOT RECORDED, echo-to-stderr only.** ← the one genuine gap.

**Root cause (the gap fixed):** `agents/context/checkpoint.sh` auto-triggers a handover
at budget-critical (~95%, just before the T-179 auto-restart). On failure it did only
`echo "AUTO-HANDOVER: Failed …" >&2` — ephemeral stderr, no durable record, no doctor
surfacing. This is the *not-even-recorded* variant of the T-2506 class, on the MOST
catastrophic memory path: the session is about to restart, and if the capture failed
there is zero trace. (The sibling `2>&1 | tail -5 >&2` form also masked the handover's
exit code without pipefail — checkpoint.sh happens to `set -euo pipefail`, so the failure
branch was reachable, but the capture-to-file refactor removes the fragility regardless.)

**Why structurally allowed:** T-2374/T-2506 hardened the pre-compact path but the
budget-critical twin was never given the same honest-log + surfacing treatment. Two
capture paths, one hardened — classic producer/consumer parity gap (L-399 shape).

**Prevention:**
1. checkpoint.sh records `[checkpoint] Handover generated|FAILED` to the same `.compact-log`.
2. doctor Check 5d broadened to surface both `[pre-compact]` and `[checkpoint]` failures, naming the source (budget-critical vs pre-compact).
3. `tests/governance/test_checkpoint_handover_recorded.bats` pins record-on-both-branches, true-rc branching, doctor WARN, last-entry-wins, and no T-2506 regression.
4. L-498 (invoke via bash) + OBS-090 (recorded-not-surfaced class) already captured under T-2506; this task closes the surfacing leg for the second path.

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

### 2026-07-06T10:32:03Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.claude/worktrees/t100199-close/.tasks/active/T-2507-surface-recorded-not-surfaced-failure-si.md
- **Context:** Initial task creation
