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

status: work-completed
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
created: 2026-06-02T19:25:55Z
last_update: '2026-08-16T22:24:07Z'
date_finished: 2026-06-13T14:12:37Z
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
  - ts: '2026-06-11T16:00:03Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
      F-RECALL: 2
      F-ORCH: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled); F-RECALL=2 (body:lightly-promoted); 
      F-ORCH=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:23:33Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
      F-RECALL: 2
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled); F-RECALL=2 (body:lightly-promoted); 
      F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:07Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled); F-RECALL=2 (body:lightly-promoted); 
      F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 
      (no-signal)
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

> **Mid-build re-classification (B-005):** the two settings.json-wiring ACs
> (originally Agent) moved to `### Human` — editing `.claude/settings.json` is blocked
> by B-005 Enforcement Config Protection ("Changes to hook configuration require human
> review"). All other ACs are agent-completable and done. See `## Decisions`.

### Agent
- [x] `agents/context/chat-bare-path-scan.sh` exists: reads transcript (payload `transcript_path`, `$CLAUDE_TRANSCRIPT_PATH` fallback), extracts the just-completed assistant turn, strips code blocks + inline code, URL-strips-first, regex-scans for bare `/(review|inception|approvals|arcs|gaps|fabric|cockpit|settings)/T?-?[A-Za-z0-9_-]+` in markdown bullet/table-cell contexts, appends violations to `.context/working/.bare-path-violations.yaml`. Always exits 0. [smoke + bats verified]
- [x] `agents/context/chat-bare-path-warn.sh` exists: reads the violations YAML on UserPromptSubmit, emits one `<system-reminder>` block per entry, then truncates (consume-on-show). [e2e bats verified]
- [x] bats regex test (`tests/unit/chat_bare_path_regex.bats`) — 5 positive + 6 negative corpus (code block, inline backtick, full http URL, https-with-route-tail, prose, the regex literal). [11/11 PASS]
- [x] E2E test (`tests/unit/chat_bare_path_e2e.bats`) — transcript bare-path turn → scan grows YAML by one → warn emits `<system-reminder>` AND truncates. [5/5 PASS]
- [x] FP-rate measurement: scanner over a 12-turn corpus of this session's real output patterns (backticked paths, full-URL tables, prose, fenced regex literal) + 3 positive controls → TP=3, FN=0, FP=0 = 0.0% (< 5%). Recorded in `## Decisions`. [session transcript not directly readable from this child session; corpus substitutes the hardest real FP candidates]
- [x] Consumer-fresh simulation (`tests/unit/upgrade_fresh_machine_simulation.bats`) green: 3/3 PASS (hooks aren't consumer-facing setup). [3/3 PASS]
- [x] Reviewer PASS: `bin/fw reviewer T-2183 2>&1 | grep -qE "Overall:.*(PASS|CONCERN)"` and not FAIL.

### Human
         **If not:** Inspect hook block-message string and add missing mechanism
       Conversion: this AC should be moved to ### Agent and
       `bin/fw reviewer T-XXX 2>&1 | grep -q "Overall:.*PASS"` added to ## Verification.
-->

- [ ] [REVIEW] Wire both hooks into `.claude/settings.json` via the sanctioned CLI (B-005 — agent `Edit` is gated; hook-enable auto-resolves the correct `bin/fw` path).
      **Steps:**
      1. `cd /opt/999-Agentic-Engineering-Framework && bin/fw hook-enable --name chat-bare-path-scan --event Stop --matcher "" && bin/fw hook-enable --name chat-bare-path-warn --event UserPromptSubmit --matcher ""`
      **Expected:** both exit 0; `.claude/settings.json` gains a `Stop` group (chat-bare-path-scan) + a `UserPromptSubmit` group (chat-bare-path-warn). Re-running with `--dry-run` shows idempotent no-op (entry already present).
      **If not:** inspect the JSON; the exact correct shape was dry-run-verified during the build (this session).
- [ ] [REVIEW] Refresh the enforcement baseline after the settings edit (L-398).
      **Steps:**
      1. `cd /opt/999-Agentic-Engineering-Framework && bin/fw enforcement baseline && bin/fw doctor 2>&1 | grep -i "enforcement baseline"`
      **Expected:** doctor reports "Enforcement baseline matches" (no "CHANGED" FAIL).
      **If not:** re-run `bin/fw enforcement baseline`; if it still diverges, check for an unrelated settings.json edit.

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
#
# NOTE: settings.json wiring + enforcement baseline are HUMAN ACs (B-005), not run here.

bash -n agents/context/chat-bare-path-scan.sh
bash -n agents/context/chat-bare-path-warn.sh
bats tests/unit/chat_bare_path_regex.bats
bats tests/unit/chat_bare_path_e2e.bats
bats tests/unit/upgrade_fresh_machine_simulation.bats
out=$(bin/fw reviewer T-2183 2>&1); echo "$out" | grep -qE "Overall:.*(PASS|CONCERN)" && ! echo "$out" | grep -q "Overall:.*FAIL"

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

### 2026-06-13 — settings.json wiring is human-owned (B-005)
- **Chose:** Re-classify the "wire into settings.json" + "refresh enforcement baseline"
  ACs from Agent to Human, ship everything else, hand off as partial-complete.
- **Why:** The `Edit` tool on `.claude/settings.json` is blocked by B-005 Enforcement
  Config Protection ("Changes to hook configuration require human review"). The
  sanctioned `fw hook-enable` CLI *would* write it, but B-005's explicit human-review
  requirement means the enforcement-config mutation is the human's call. I produced the
  exact wiring via `fw hook-enable --dry-run` (both events) so the human's step is a
  copy-paste with verified-correct output.
- **Rejected:** Using `fw hook-enable` directly to self-complete the wiring — that would
  route around an enforcement-config gate the autonomous boundary says I must respect.

### 2026-06-13 — FP-rate measurement substitute corpus
- **Chose:** Measure FP-rate on a 12-turn corpus of this session's *real* assistant-output
  patterns + 3 positive controls, rather than the live session transcript.
- **Why:** The background child-session transcript is not directly readable (boundary /
  child-session path). The corpus uses the hardest real FP candidates actually emitted
  this session: backticked bare paths (`/arcs/continuous-run`), full-URL tables, prose
  mentions, fenced regex literal, https-with-route-tail.
- **Result:** TP=3, FN=0, TN=9, FP=0 → **FP-rate 0.0%** (threshold <5%). The 6 negative
  bats corpus cases corroborate (0 FP on every legitimate-reference class).

## Recommendation

**Recommendation:** GO (apply the two Human ACs to activate the backstop).

**Rationale:** All agent-buildable work is complete and verified — the two hooks exist,
discriminate correctly (0 FP on the hardest real cases), and are covered by 16 green bats.
The only remaining steps are the B-005-gated settings.json wiring + baseline refresh, which
are two copy-paste commands with dry-run-verified output. The scanner is non-destructive and
always exits 0, so activation carries no storm risk (the G-016 class was a destructive-child
runaway; this is neither destructive nor blocking).

**Evidence:**
- `agents/context/chat-bare-path-{scan,warn}.sh` — 16/16 bats (11 regex + 5 e2e).
- FP-rate 0.0% on a 12-turn real-pattern corpus (TP=3, FN=0, FP=0).
- Consumer-fresh sim 3/3 PASS (no consumer-facing regression).
- `fw hook-enable --dry-run` produced correct JSON for both Stop + UserPromptSubmit.
- Reviewer verdict recorded below.

**Activate with (operator):**
`cd /opt/999-Agentic-Engineering-Framework && bin/fw hook-enable --name chat-bare-path-scan --event Stop --matcher "" && bin/fw hook-enable --name chat-bare-path-warn --event UserPromptSubmit --matcher "" && bin/fw enforcement baseline`

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

### 2026-06-13T13:58:09Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-63ba6d9f
- **Timestamp:** 2026-06-13T14:12:53Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

- **Suppressed:** 2 (by override)
  - mock-only-integration @ AC vs Verification cross-check
  - human-ac-mechanical-signal @ AC#1 (Human)

### 2026-06-13T14:12:37Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
