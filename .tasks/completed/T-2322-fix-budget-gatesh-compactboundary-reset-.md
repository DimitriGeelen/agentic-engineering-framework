---
id: T-2322
name: "Fix budget-gate.sh compact_boundary reset (T-1088 sidecar-degradation defense-in-depth)"
description: >
  Inbound bug report from proxmox-ring20-management framework-agent (commit bea5c9bc): when .session-start-ts sidecar is missing/stale/empty, the T-1088 filter degrades to no-op and pre-compact 290K-token usage entries surface as 'critical' post-/compact. Apply 3-line patch to slow-path Python loop in agents/context/budget-gate.sh at line 207 — detect type=system + subtype=compact_boundary JSON event, reset t=0, continue. Complements (not replaces) T-1088 sidecar filter.

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: [bug, context, budget-gate, inbound, proxmox-ring20]
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
created: 2026-06-10T19:50:28Z
last_update: 2026-06-10T19:55:02Z
date_finished: 2026-06-10T19:55:02Z
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

# T-2322: Fix budget-gate.sh compact_boundary reset (T-1088 sidecar-degradation defense-in-depth)

## Context

Inbound bug report from `framework-agent` (proxmox-ring20-management project, commit `bea5c9bc` local) received via TermLink session `tl-qmusmi7l` 2026-06-10. Repro: post-`/compact` shows `critical 290000` when real budget is ~0. Root cause: T-1088 sidecar filter at `agents/context/budget-gate.sh:212-215` only fires when `.session-start-ts` file is present + non-empty. If sidecar is missing/stale/empty (fresh install, deleted, racing the session-start), filter degrades to no-op and the loop counts pre-compact 290K-token entries. The proposed patch detects the JSONL `compact_boundary` event itself (single source of truth) and resets `t=0`, complementing the T-1088 sidecar (defense-in-depth, not replacement).

## Acceptance Criteria

### Agent
- [x] `agents/context/budget-gate.sh` slow-path Python loop (line ~207) has a `compact_boundary` detector that resets `t=0` and `continue`s before token-counting logic
- [x] Inline test: synthetic JSONL with a `compact_boundary` event followed by a post-compact `usage:{input_tokens:5000}` entry returns `level=ok` (verified live 2026-06-10: tokens=6000 level=ok)
- [x] Patch does NOT remove T-1088 sidecar filter (defense-in-depth: both run inside the same parser loop — verified by `grep -n "session_start_ts\|compact_boundary" agents/context/budget-gate.sh`)
- [x] `bin/fw doctor` PASSES (no regression — 24 WARN no FAIL, same baseline as pre-edit)
- [x] `bin/fw reviewer T-2322` returns PASS|CONCERN with no FAIL

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
grep -q "T-2322: detect compact_boundary" agents/context/budget-gate.sh
grep -q "subtype.*compact_boundary" agents/context/budget-gate.sh
grep -q "session_start_ts" agents/context/budget-gate.sh
out=$(bin/fw doctor 2>&1); echo "$out" | grep -q "no failures"
out=$(bin/fw reviewer T-2322 2>&1); echo "$out" | grep -qE "Overall:.*(PASS|CONCERN)" && ! echo "$out" | grep -q "Overall:.*FAIL"
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

**Symptom:** Post-`/compact` the budget-gate reports `critical 290000` (= pre-compact token count from same JSONL file) even though `/compact` reset the live conversation to ~0 tokens. Result: spurious `critical`-level warnings + blocked Write/Edit on fresh-compacted sessions.

**Root cause:** Two-defense system that has only one working defense. T-1088 added a sidecar timestamp filter (`.session-start-ts` file) to skip JSONL entries older than session start. But when the sidecar is missing/stale/empty (fresh install, file deletion, hook race), the filter degrades to no-op (line 212 guard: `if session_start_ts:`). The slow-path Python loop then sees every usage entry in the tailed transcript chunk — including the pre-compact 290K-token one — and the unconditional `t = u['input_tokens'] + ...` assignment (line 218) overwrites `t` with whatever the LAST usage entry was. If `claude -c` re-reads a JSONL with the pre-compact 290K entry near the tail, `t = 290000` survives.

**Why structurally allowed:** Single-defense-with-sidecar pattern is brittle by design — the sidecar is the source of truth for "where does the session start?", but the sidecar can disappear or race the gate. The JSONL itself carries the answer in a `{type: system, subtype: compact_boundary}` event that `/compact` emits — but budget-gate.sh wasn't reading it. T-1088 mitigated the symptom (sidecar-present case) without addressing the source-of-truth gap.

**Prevention:** This patch reads the source of truth (`compact_boundary` event in the transcript itself) and resets `t=0` whenever the loop crosses a boundary. T-1088 sidecar remains as secondary defense. The patch composes — both filters run in the same loop, and either catches the bug. Reusable pattern: when a sidecar file mediates source-of-truth, also wire a check against the canonical source so sidecar miss/stale isn't a silent failure. Cross-link: L-477 (TermLink inject without delivery-verify is silent-failure class — same shape: "trust-the-sidecar" without "verify-the-source").
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

### 2026-06-10T19:50:28Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2322-fix-budget-gatesh-compactboundary-reset-.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-a705a86f
- **Timestamp:** 2026-06-10T19:57:01Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-06-10T19:55:02Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
