---
id: T-2205
name: "T-2204 Slice B — PreToolUse Write/Edit hook refuses save when inception has
  template-only Recommendation block (under $CLAUDECODE=1)"
description: >
  T-2204 Slice B — PreToolUse Write/Edit hook refuses save when inception has template-only
  Recommendation block (under $CLAUDECODE=1)

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
created: 2026-06-04T19:50:22Z
last_update: '2026-06-11T22:23:33Z'
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
  - ts: '2026-06-04T20:00:03Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=0 
      (no-signal); F-ORCH=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-05T20:15:03Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T16:00:03Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:23:33Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-06-04T20:00:03Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2205: T-2204 Slice B — PreToolUse Write/Edit hook refuses save when inception has template-only Recommendation block (under $CLAUDECODE=1)

## Context

T-2204 GO Slice B (the producer-side leg of the L-399 producer/consumer parity fix). Closes the bypass path where `fw task create --type inception`, `fw work-on --type inception`, or direct YAML write produce a task with `workflow_type: inception` and a template-only `## Recommendation` block under `$CLAUDECODE=1`.

Mirrors T-1716's check shape (`lib/inception.sh:107-120`) — but the surface is Write/Edit on `.tasks/{active,completed}/T-*.md` files instead of the `fw inception start` CLI verb. Symmetric to the existing `check-arc-id` and `check-inception-decisions` hooks.

unlocks_inception_decision: [T-2204:slice-b]

## Acceptance Criteria

### Agent
- [x] Hook script `agents/context/check-inception-recommendation.sh` exists and is executable. (Moved from `agents/task-create/` to canonical hook location during build — `fw hook` dispatcher only loads from `agents/context/`.)
- [x] Hook script reads the target file's YAML frontmatter; if `workflow_type` ≠ `inception`, exits 0 (pass-through). Verified by bats test 2.
- [x] Hook script inspects the `## Recommendation` body; if it contains a non-template `**Recommendation:**` line (value GO|NO-GO|DEFER), exits 0 (pass). Verified by bats test 3.
- [x] Hook script refuses with exit 2 + block-message when block is empty/template-only AND `$CLAUDECODE=1`. Block message names BOTH bypass mechanisms per T-1890 producer/consumer parity rule. Verified by bats test 4.
- [x] Hook script silent pass when `$CLAUDECODE` is unset (operator session is sovereign). Verified by bats test 6.
- [x] Hook script silent pass when `FW_ALLOW_EMPTY_RECOMMENDATION=1`; logs Tier-2 entry to `.context/working/.gate-bypass-log.yaml` with `task_id`, `caller`, `reason`. Verified by bats test 5.
- [x] Unit tests in `tests/unit/check_inception_recommendation.bats` — 7 tests, all pass.
- [x] Block-message stderr (agent-facing) names: (a) `FW_ALLOW_EMPTY_RECOMMENDATION=1` env-var bypass, (b) `--allow-empty-recommendation` flag (named as the future fw-verb leaf), (c) `fw inception start --recommendation GO|NO-GO|DEFER --rationale` as the canonical filing path, (d) the rationale link to T-679 / T-1715 / T-1716 / T-2204. Self-eval — agent re-read the block message at `agents/context/check-inception-recommendation.py:178-211`; all four are present.

### Human
- [ ] [RUBBER-STAMP] Wire the hook into `.claude/settings.json`. The agent is hard-blocked from editing this file (B-005 enforcement-config protection — sovereign boundary). One-line patch shown below.
  **Steps:**
  1. Open `/opt/999-Agentic-Engineering-Framework/.claude/settings.json`
  2. Find the PreToolUse `Write|Edit` matcher block (currently contains `check-arc-id`, `check-inception-decisions`, `check-heredoc-cmd-sub`, `check-inception-schema`).
  3. Insert this object after the `check-inception-decisions` entry (preserve JSON syntax, comma between objects):
     ```json
     {
       "type": "command",
       "command": "/opt/999-Agentic-Engineering-Framework/bin/fw hook check-inception-recommendation"
     },
     ```
  4. Save the file.
  5. Run: `cd /opt/999-Agentic-Engineering-Framework && bin/fw enforcement baseline` to refresh the canonical hash.
  6. Verify the hook is live: `cd /opt/999-Agentic-Engineering-Framework && bin/fw doctor 2>&1 | grep -E "Enforcement baseline|hook"`.
  **Expected:** `fw doctor` reports `OK Enforcement baseline matches`. Settings file contains `check-inception-recommendation` between `check-inception-decisions` and `check-heredoc-cmd-sub`.
  **If not:** Verify the JSON syntax (commas, braces). The hook script itself is tested green; only the wire-up is your half.

<!-- Audience-axis (T-2143): block-message clarity is agent-audience —
     moved to Agent self-eval AC above ("Block-message stderr...").
     No Human [REVIEW] on agent-facing stderr per CLAUDE.md §AC routing. -->

## Recommendation

**Recommendation:** GO — wire the hook into `.claude/settings.json` when convenient (B-005 sovereign boundary; one-line patch in the Human AC).

**Rationale:** 7 of 8 ACs ship-ready. Hook script (`agents/context/check-inception-recommendation.py`) tested green (7 bats), block-message stderr names all four bypass mechanisms per T-1890 producer/consumer parity rule, and the Reviewer scan returned PASS with zero findings on 2026-06-04 (cached: R-93c4dc94). The 8th AC is operator-only (.claude/settings.json edit) because the agent is hard-blocked at `agents/context/check-active-task.sh:112`. Until wired, the empty-Recommendation gate is enforced only via the producer-side leg (T-1716 `do_inception_start` + T-2207 `create-task.sh`); wiring Slice B closes the Write/Edit-direct producer leg per the 4-producer table in CLAUDE.md §Recommendation-completeness gate.

**Evidence:**
- Hook script: `agents/context/check-inception-recommendation.py:1-220` (`grep -n "FW_ALLOW_EMPTY_RECOMMENDATION\|--allow-empty-recommendation\|--recommendation" agents/context/check-inception-recommendation.py | head -10`)
- Tests: `tests/unit/check_inception_recommendation.bats` — 7 tests, all pass (`bats tests/unit/check_inception_recommendation.bats`)
- Reviewer verdict: R-93c4dc94 PASS, Needs Human=no, findings=none (cached 2026-06-04T20:02:18Z)
- Bypass-log parity: `lib/inception.sh` + `agents/task-create/create-task.sh` (T-2207) both log Tier-2 via the unified `FW_ALLOW_EMPTY_RECOMMENDATION=1` env var per L-399 producer/consumer rule
- Wire patch: see `### Human` AC #1 above — exact JSON object + insertion location

**Open question:** None. The 8th AC is a mechanical rubber-stamp; agent cannot self-serve.

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

test -x agents/context/check-inception-recommendation.sh
test -x agents/context/check-inception-recommendation.py
bats tests/unit/check_inception_recommendation.bats
out=$(bin/fw reviewer T-2205 2>&1); echo "$out" | grep -q "Overall:.*PASS"

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

### 2026-06-04T19:50:22Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2205-t-2204-slice-b--pretooluse-writeedit-hoo.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-93c4dc94
- **Timestamp:** 2026-06-04T20:02:18Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
