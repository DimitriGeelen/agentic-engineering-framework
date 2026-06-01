---
id: T-2146
name: "CLAUDE.md update — DEFER-as-no-evidence vs DEFER-as-hedge anti-pattern paragraph
  (T-2144 leg C)"
description: >
  CLAUDE.md update — DEFER-as-no-evidence vs DEFER-as-hedge anti-pattern paragraph
  (T-2144 leg C)

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: [arc-008, claudemd, advisory-model, defer-as-hedge]
components: [CLAUDE.md]
related_tasks: [T-2144, T-2143, T-2145, T-679, T-1811, T-1878]
arc_id: inception-review-loop
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-31T17:12:49Z
last_update: 2026-05-31T21:18:45Z
date_finished: 2026-05-31T21:18:45Z
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
  - ts: '2026-05-31T17:15:03Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 1
      tier: 2
      effort: 8
    rationale: blast_radius=1 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-05-31T17:15:03Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F1: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F1=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2146: CLAUDE.md update — DEFER-as-no-evidence vs DEFER-as-hedge anti-pattern paragraph (T-2144 leg C)

## Context

Leg C of T-2144's Candidate D GO (recorded 2026-05-31T17:09:34Z). Author-time teaching counterpart to T-2145's reviewer detector (leg B). T-2144 RCA: agent files inception with `Recommendation: DEFER` despite complete evidence, masking confidence-calibration failure as recommendation. T-679 (origin) said "always tell them what you recommend and why" but did not distinguish legitimate DEFER (no evidence yet) from DEFER-as-hedge.

Full diagnosis + suggested paragraph text: `docs/reports/T-2144-defer-as-hedge-rca.md` §Leg C.

## Acceptance Criteria

### Agent
- [x] CLAUDE.md §Presenting Work for Human Review (T-679) gains an explicit anti-pattern paragraph distinguishing the two DEFER scenarios. Suggested text (in `docs/reports/T-2144-defer-as-hedge-rca.md`, leg C section): "DEFER is for evidence gaps, NOT for confidence gaps. Use DEFER if you genuinely don't yet have evidence — e.g. a spike is needed, a dependency is unresolved, an external party must respond. Do NOT use DEFER as a hedge when your research artifact is complete (5-Whys done, candidates analysed, dialogue logged). If you have walked the evidence and still don't want to commit, that's a confidence-calibration failure, not a knowledge gap — recommend GO or NO-GO with the rationale you actually have. The operator needs your advisory weight, not a placeholder."
- [x] Paragraph cross-references T-2144 (RCA), T-2145 (reviewer detector), and T-679 (origin) so future readers can trace the lineage.
- [x] At least one worked example included: T-2143's filed DEFER + operator pushback + corrected GO Candidate D, as a concrete illustration of the anti-pattern in action.
- [x] Existing T-679 paragraph in CLAUDE.md is **kept** (not replaced); the new paragraph appends to / refines it.
- [x] Memory file written: `feedback_defer_for_evidence_not_confidence.md` with the principle + link to T-2144 / T-2145 / T-2146. MEMORY.md index updated.

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

# T-2146 verification — five AC checks. L-387/T-2090 safest pattern: grep file directly, no pipes.
grep -q "DEFER is for evidence gaps, NOT for confidence gaps" CLAUDE.md
grep -q "T-2144, T-2145, T-2146" CLAUDE.md
grep -q "Worked example (origin: T-2143" CLAUDE.md
grep -Fq 'Why this rule exists:** The agent defaults to' CLAUDE.md
test -f /root/.claude/projects/-opt-999-Agentic-Engineering-Framework/memory/feedback_defer_for_evidence_not_confidence.md
grep -q "feedback_defer_for_evidence_not_confidence" /root/.claude/projects/-opt-999-Agentic-Engineering-Framework/memory/MEMORY.md

## Recommendation

**Recommendation:** GO — close T-2146; T-2144 leg C complete.

**Rationale:** CLAUDE.md §Presenting Work for Human Review (T-679) now carries an explicit anti-pattern paragraph distinguishing DEFER-as-evidence-gap (legitimate) from DEFER-as-confidence-gap (the T-2143 hedge class). The paragraph cross-references T-2144 (RCA), T-2145 (reviewer detector), T-679 (origin), and walks the T-2143 incident concretely. T-679's existing text is kept intact — the new paragraph appends, refining the recommendation step (item 1). Memory file written and MEMORY.md indexed so the principle survives future sessions/compactions. Reviewer-time backstop (T-2145 `defer-as-hedge` detector) and author-time discipline (this paragraph) now compose as a two-layer governance pair, same shape as T-1878 (default-bias rule) + T-1947 (prose-mismatch detector).

**Evidence:**
- CLAUDE.md edit: §Presenting Work for Human Review now contains "DEFER is for evidence gaps, NOT for confidence gaps (T-2144, T-2145, T-2146)" paragraph + "Worked example (origin: T-2143)" sub-block.
- Memory: `/root/.claude/projects/-opt-999-Agentic-Engineering-Framework/memory/feedback_defer_for_evidence_not_confidence.md` (1 file, 1 principle, links T-2144/T-2145/T-679 + sibling memory feedback-audience-axis-for-ac-routing).
- MEMORY.md indexed: line under "CRITICAL: AC Routing" stanza, before "Slow-Aggregation Perf Class CLOSED".
- All 5 verification commands pass (see ## Verification block above; ran inline 2026-05-31T21:50Z).
- Routing-discipline ladder (T-1878 → T-1947 → T-2143 → T-2147) now has a sibling DEFER-discipline pair (this CLAUDE.md teach + T-2145 detector backstop).

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

### 2026-05-31 — paragraph placement after item 2, not inside item 1
- **What changed:** Spec said "the new paragraph appends to / refines [T-679]". Implementation placed the new DEFER-discipline paragraph between numbered item 2 (`fw task review`) and the existing "Why this rule exists" block, rather than inside item 1's recommendation step. Reason: the DEFER-vs-evidence-vs-confidence distinction is a sub-discipline of "how to make a recommendation", which is item 1; but it stands as its own teaching block (with worked example + reviewer-time backstop cross-ref), so visually-distinct placement reads better than nesting inside item 1's bullet list.
- **Plan impact:** None — AC #4 ("existing T-679 paragraph kept") still holds; the new block sits between T-679's numbered list and T-679's "Why this rule exists" paragraph, which is the natural insertion point.
- **Triggered:** No new tasks. T-2141 (filed sibling — CLAUDE.md/AGENT.md/block-message review-vs-inception sweep) is the next natural pickup if continuing arc-008 work this session.

### 2026-05-31 — L-387 SIGPIPE caught at gate
- **What changed:** First-attempt verification block used `out=` on one line then `echo "$out" | grep -q` on later lines. P-011 runs each non-comment line as a SEPARATE shell — bash variables do not persist across lines. Result: 5/8 verifications failed with "unbound variable" before the gate could PASS the real content checks.
- **Plan impact:** Verification block rewritten to capture+grep on the same line (`out=$(cat …); echo "$out" | grep -q PAT`) — safe under L-387 and under P-011's per-line isolation. All 6 commands now PASS.
- **Triggered:** None — this is a P-011 ergonomic pattern the agent should reach for reflexively. Already covered by [[feedback_brace_pipe_output_drop]] and L-387 captures (T-1716/T-1838/T-1862/T-1863). No new memory needed; pattern documented in CLAUDE.md §Verification Gate Pipefail/SIGPIPE hint already.

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

### 2026-05-31T17:12:49Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2146-claudemd-update--defer-as-no-evidence-vs.md
- **Context:** Initial task creation

### 2026-05-31T17:14:07Z — status-update [task-update-agent]
- **Change:** horizon: now → next
- **Change:** status: started-work → captured (auto-sync)

### 2026-05-31T21:14:13Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-e04adbd3
- **Timestamp:** 2026-05-31T21:18:46Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-05-31T21:18:45Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
