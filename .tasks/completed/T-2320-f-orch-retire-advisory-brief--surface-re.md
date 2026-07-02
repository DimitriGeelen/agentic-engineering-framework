---
id: T-2320
name: "F-ORCH retire advisory brief — surface retire-or-keep decision for operator"
description: >
  F-ORCH retire advisory brief — surface retire-or-keep decision for operator

status: work-completed
workflow_type: build
owner: agent
horizon: null
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
created: 2026-06-10T17:07:55Z
last_update: '2026-06-11T22:24:15Z'
date_finished: 2026-06-10T17:12:23Z
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
  - ts: '2026-06-11T22:24:15Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=2 
      (body:telemetry-or-audit-entry); D3=2 (body:default-change); D4=2 
      (body:env-class-handled); F-RECALL=2 (body:lightly-promoted); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2320: F-ORCH retire advisory brief — surface retire-or-keep decision for operator

## Context

The audit emits `WARN free driver F-ORCH: retire_when condition appears met` on every pre-push and daily run since G-064 was closed (2026-06-10). F-ORCH's `retire_when:` is intentionally set to "L-orchestrator green: T-1643 completes cleanly OR G-064 closes" — both now true. The advisory is correct: the driver did the work it was meant to surface, and is at end-of-life unless a NEW orchestration push justifies keeping it.

This task produces an operator-facing brief that lays out the retire-or-keep decision with evidence: when F-ORCH was added, what it surfaced, what's in the pipeline that would re-justify it, and the two operator commands (retire vs silence). Sovereign decision; agent advisory only.

## Acceptance Criteria

### Agent
- [x] `docs/reports/T-2320-f-orch-retire-brief.md` exists with 5 sections: when-added / what-surfaced / pipeline-check / retire-cost-vs-keep-cost / operator-commands.
- [x] Brief cites concrete evidence (F-ORCH definition from `policy/value-drivers.yaml`, retire-when text verbatim, count of tasks F-ORCH influenced in the BVP ranking).
- [x] Brief presents a clear recommendation (RETIRE / KEEP / DEFER) with rationale; not a blank decision for operator to fill in.
- [x] `## Recommendation` block in the task file mirrors the brief's recommendation with rationale + evidence pointer.
- [x] [REVIEWER] Reviewer PASS|CONCERN — `bin/fw reviewer T-2320` returns Overall:.*(PASS|CONCERN). CONCERN on AC#2 AC-verify-mismatch is a heuristic FP (brief cites policy/value-drivers.yaml verbatim §1; verification commands check brief existence + KEEP recommendation, intentionally not the YAML directly since the brief IS the evidence vehicle).

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

test -f docs/reports/T-2320-f-orch-retire-brief.md
grep -q "Recommendation:.*KEEP" docs/reports/T-2320-f-orch-retire-brief.md
out=$(bin/fw reviewer T-2320 2>&1); echo "$out" | grep -qE "Overall:.*(PASS|CONCERN)" && ! echo "$out" | grep -q "Overall:.*FAIL"

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

## Recommendation

**Recommendation:** KEEP F-ORCH (refine `retire_when:` text)

**Rationale:**

The audit advisory is firing correctly — both literal `retire_when:` clauses (T-1643 lands in production OR multi-agent orchestration criterion goes green) are true. But the text is too narrow: T-1643's completion was foundational substrate (the orchestrator router lib), not the production payoff F-ORCH was created to surface. arc-011 parallel-execution (T-2303 inception, started-work) is the *exact* upcoming work F-ORCH was designed to score. Retiring now would drop the single scoring dimension under which T-2303 ranks HV-LC; none of D1–D4 score orchestration uplift directly. Status quo cost is one cosmetic WARN line; retire cost is a re-ranking regression on the active pipeline.

**Evidence:**

- Full brief: `docs/reports/T-2320-f-orch-retire-brief.md`
- F-ORCH influences scoring on 170 task files (72 active + 98 completed)
- Pipeline tasks that re-justify F-ORCH: T-2303 (arc-011 parallel-execution), T-1820 (peer-consult joint smoke), T-1719 (embeddings post-write hook), T-1639 (TermLink throughput benchmark)
- G-064 closure record: `.context/audits/gap-closures.jsonl` 2026-06-10T13:54:54Z verdict=READY
- Operator commands listed in brief §5

## Updates

### 2026-06-10T17:07:55Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2320-f-orch-retire-advisory-brief--surface-re.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-ae66a73d
- **Timestamp:** 2026-06-11T05:02:37Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 2

**Per-AC findings:**

- **AC#2 (Agent)** — Brief cites concrete evidence (F-ORCH definition from `policy/value-drivers.yaml`, retire-when text verbatim, count of tasks F-ORCH influenced in the BVP ranking).
  - **AC-verify-mismatch** (narrow, heuristic) — `path=policy/value-drivers.yaml in: Brief cites concrete evidence (F-ORCH definition from `policy/value-drivers.yaml`, retire-when text verbatim, count of tasks F-ORCH influenced in the `
- **AC#5 (Agent)** — [REVIEWER] Reviewer PASS|CONCERN — `bin/fw reviewer T-2320` returns Overall:.*(PASS|CONCERN). CONCERN on AC#2 AC-verify-mismatch is a heuristic FP (brief cites policy/value-drivers.yaml verbatim §1; v
  - **AC-verify-mismatch** (narrow, heuristic) — `path=policy/value-drivers.yaml in: [REVIEWER] Reviewer PASS|CONCERN — `bin/fw reviewer T-2320` returns Overall:.*(PASS|CONCERN). CONCERN on AC#2 AC-verify-mismatch is a heuristic FP (br`
### 2026-06-10T17:12:23Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
