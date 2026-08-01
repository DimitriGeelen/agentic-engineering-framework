---
id: T-2702
name: "Gate deadlock: budget-gate blocks the fw context focus that check-active-task
  prescribes"
description: >
  Gate deadlock: budget-gate blocks the fw context focus that check-active-task prescribes

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [C-007, tests/lint/prescribed-commands-are-allowed.bats]
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
created: 2026-07-31T11:01:31Z
last_update: 2026-07-31T11:43:15Z
date_finished: 2026-07-31T11:43:15Z
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
  - ts: '2026-07-31T11:15:06Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-07-31T11:15:09Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 1
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=1 
      (body:episodic-only); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2702: Gate deadlock: budget-gate blocks the fw context focus that check-active-task prescribes

## Context

Reported by 832 as a consumer of this framework — they hit it at wrap-up and could
not file it, because filing required the path the deadlock blocks. A defect that
suppresses its own bug report is worth treating as a priority class.

Verified here, and the verified form is sharper than the report:

- `check-active-task.sh:239` PRINTS the remedy in its own block message:
  `2. Set focus:  <fw> context focus T-XXX`
- `check-active-task.sh:98` safe-lists `fw context focus` deliberately, and :303
  documents that focus-drift does not gate it either.
- `budget-gate.sh`'s allowed-command regex lists `fw\s+(handover|git|context\s+init|
  resume|task)` — `context init` is present, `context focus` is not.

So at critical budget, one gate instructs the agent to run exactly the command the
other gate refuses. The agent is told the remedy and denied it in the same breath.

This is the producer/consumer parity class (L-399, T-1890): a contract shipped on
one side only. L-433 (T-2054) warned about the neighbouring case — allowlisting in
`is_bash_safe_command` short-circuits focus-drift — but that concern does not
transfer here: budget-gate and check-active-task are separate PreToolUse hooks, so
budget-gate exiting 0 still leaves check-active-task to run, and focus-drift already
exempts `fw context focus` by design.

## Acceptance Criteria

### Agent
- [x] `fw context focus T-XXX` is permitted by `budget-gate.sh` at critical, so the
      remedy `check-active-task.sh` prints is actually reachable
- [x] The block message and the allowlist are pinned to each other by a test — any
      command a gate PRESCRIBES must be one the budget gate ALLOWS
- [x] Negative-controlled: test proven RED when the allowlist entry is removed
      (names `fw context focus` exactly)
- [x] No new red in `bin/fw test invariants` (T-2698/T-2699 remain the only reds)

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
out=$(bin/fw test invariants 2>&1); echo "$out" | grep -qE '^ok .* prescribed in a block message is allowed'
out=$(bin/fw test invariants 2>&1); echo "$out" | grep -qE '^ok .* allowlist regex is still locatable'
grep -q 'context\\s+(init|focus)' agents/context/budget-gate.sh

## RCA

**Symptom:** at critical budget with an empty focus (the state a just-completed
task leaves behind), `check-active-task.sh` blocks and prints `fw context focus
T-XXX` as remedy step 2 — and `budget-gate.sh` refuses that exact command. The
agent is told the remedy and denied it in the same breath. Reported by 832 as a
consumer; they escaped via Edit to `.context/`, which the wrap-up gate permits.

**Root cause:** budget-gate's allowed-command allowlist carried `fw context init`
but not `fw context focus`. Both gates are correct in isolation — check-active-task
deliberately safe-lists `fw context focus` (:98) and exempts it from focus-drift
(:303); budget-gate deliberately narrows commands at critical. The defect is in the
join: neither gate knows what the other prescribes.

**Why structurally allowed:** producer/consumer parity (L-399, T-1890) — a contract
shipped on one side only. Nothing related a block message's remedy text to the
allowlist that governs whether the remedy is runnable. The two files were edited by
different tasks for different reasons and never read together.

Aggravating: **the defect suppressed its own bug report.** 832 hit it and did not
file, because filing required the blocked path. Defects in wrap-up gates are
systematically under-reported for this reason — the moment you can observe them is
the moment you cannot act. That argues for a standing check rather than waiting for
a report to arrive.

**Prevention:**
- `tests/lint/prescribed-commands-are-allowed.bats` extracts every fw command
  prescribed in a `check-active-task.sh` block message and asserts budget-gate
  allows it. Reads budget-gate's ACTUAL regex rather than restating it — a copy
  would drift and then agree with itself while the gate disagreed.
- Extraction is positional (numbered remedy step → optional label → command
  position), not lexical. The first cut matched any `fw <verb>` in an echoed
  string and pulled in "fw command" from "Append --switch-focus to a fw command".
  Same correction T-2700 made to the bare-fw detector, for the same reason: a
  guard that fires on prose gets ignored (L-527).
- Second test asserts the regex remains locatable, so a restructure cannot make
  the first test pass by silently checking nothing.
- Negative-controlled: removing the allowlist entry turns it red, naming
  `fw context focus`.

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

### 2026-07-31T11:01:31Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2702-gate-deadlock-budget-gate-blocks-the-fw-.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-68a96ed6
- **Timestamp:** 2026-07-31T11:43:26Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-07-31T11:43:15Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
