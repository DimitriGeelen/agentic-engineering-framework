---
id: T-2183
name: "T-2181 Slice 2: chat-bare-path Stop-hook scanner + UserPromptSubmit warning
  injector"
description: >
  Per T-2181 GO Candidate D. agents/context/chat-bare-path-scan.sh (Stop hook): regex-scan
  just-completed assistant turn from session JSONL for bare /review/T-XXX /inception/T-XXX
  /approvals /arcs/<slug> /gaps in markdown bullet/table-cell contexts (after stripping
  code blocks). Write to .context/working/.bare-path-violations.yaml. UserPromptSubmit
  handler reads + injects system-reminder + consumes entry. Wire into .claude/settings.json.
  Run fw enforcement baseline. Evidence: bats regex tests + E2E next-prompt test +
  FP-rate <5% backtest + consumer-fresh bats green.

status: captured
workflow_type: build
owner: agent
horizon: next
tags: []
components: []
related_tasks: []
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-06-02T19:25:55Z
last_update: '2026-06-05T18:00:04Z'
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
  - ts: '2026-06-02T19:30:02Z'
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
  - ts: '2026-06-05T18:00:04Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
      F-RECALL: 2
      F-ORCH: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled); F-RECALL=2 (body:lightly-promoted); 
      F-ORCH=0 (no-signal)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-06-02T19:30:03Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-05T18:00:03Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2183: T-2181 Slice 2: chat-bare-path Stop-hook scanner + UserPromptSubmit warning injector

## Context

Predecessor: T-2181 (GO Candidate D, 2026-06-02 19:24Z by operator) → research
artifact `docs/reports/T-2181-chat-output-bare-path-rca.md`. Slice 1 (T-2182,
work-completed 2026-06-02) shipped the `fw task review-batch` helper + CLAUDE.md
ladder. This Slice 2 is the **structural backstop** — catches regressions even
when the helper isn't used (defence in depth).

**Filed and ACs locked, build deferred to next session.** Reason: Slice 2 is ≥8
ACs including new hook scripts, .claude/settings.json edit, enforcement-baseline
refresh, two bats suites (regex + E2E), and an FP-rate empirical measurement.
Started here at 85% context budget — per CLAUDE.md work-proposal rule, building
this slice at urgent budget risks losing partial state. ACs are stable and
verification commands well-specified; pickup in a fresh session is clean.

Empirical evidence already established in the inception artifact: the prototype
regex caught 22 historical bare-path occurrences in this session's transcript
with zero apparent FPs. The build is implementation only.

## Acceptance Criteria

### Agent
- [ ] `agents/context/chat-bare-path-scan.sh` exists: reads `$CLAUDE_TRANSCRIPT_PATH` (Stop-hook input), extracts the just-completed assistant turn's text, strips code blocks + inline code, regex-scans for bare `/(review|inception|approvals|arcs|gaps|fabric|cockpit|settings)/T?-?[A-Za-z0-9_-]+` in markdown bullet/table-cell contexts where the same line does NOT start with `http`, and appends violations as YAML entries to `.context/working/.bare-path-violations.yaml`.
- [ ] `agents/context/chat-bare-path-warn.sh` exists: reads `.context/working/.bare-path-violations.yaml` on UserPromptSubmit, emits a `<system-reminder>` block to stdout per outstanding entry, then truncates the file (consume-on-show semantics).
- [ ] Both scripts wired into `.claude/settings.json` — Stop hook adds `chat-bare-path-scan.sh`; UserPromptSubmit hook adds `chat-bare-path-warn.sh`.
- [ ] `bin/fw enforcement baseline` re-run after the settings edit (L-398); `bin/fw doctor` reports clean "Enforcement baseline matches".
- [ ] bats regex test (`tests/unit/chat_bare_path_regex.bats`) — positive corpus (≥5 real bare-path samples from prior session transcripts) + negative corpus (≥5 legitimate references: code block, inline backtick, prose mention with leading `http`, the documentation table inside CLAUDE.md, the regex literal itself).
- [ ] E2E test (`tests/unit/chat_bare_path_e2e.bats`) — synthesises a transcript JSONL containing a bare-path assistant turn, runs `chat-bare-path-scan.sh` against it, asserts the violations YAML grows by one entry; then runs `chat-bare-path-warn.sh`, asserts stdout contains `<system-reminder>` block AND the YAML file is truncated.
- [ ] FP-rate measurement: run the scanner against the last 30 assistant turns in this session's transcript; record (true-positives, false-positives) tuple in task body; FP-rate must be <5% to ship.
- [ ] Consumer-fresh simulation (`tests/unit/upgrade_fresh_machine_simulation.bats`) green: 3/3 PASS after the hook additions.

### Human
         **If not:** Inspect hook block-message string and add missing mechanism
       Conversion: this AC should be moved to ### Agent and
       `bin/fw reviewer T-XXX 2>&1 | grep -q "Overall:.*PASS"` added to ## Verification.
-->

(none — pure-agent Slice 2; Slice 2's success is structural enforcement evidenced by bats)

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

### 2026-06-02T19:25:55Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2183-t-2181-slice-2-chat-bare-path-stop-hook-.md
- **Context:** Initial task creation

### 2026-06-02T19:38:46Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-06-02T19:42:29Z — status-update [task-update-agent]
- **Change:** status: started-work → captured
- **Change:** horizon: now → next
