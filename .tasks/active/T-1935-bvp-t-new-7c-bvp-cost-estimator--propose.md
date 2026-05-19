---
id: T-1935
name: "BVP T-NEW-7c: bvp-cost-estimator — propose cost_estimate (blast_radius / tier / effort) per task"
description: >
  Companion to T-1922 bvp-estimator. Where T-1922 proposes BVP scores per directive, T-1935 proposes cost_estimate per task (the F8 x-axis). Without it, T-1934 dots cluster at default-medium. v1 heuristic: blast_radius from fw fabric blast-radius (only when source file is touched, else 0), tier from tags+workflow_type lookup, effort from content-length heuristic (AC count + body line count). Sovereignty: writes only to cost_estimate_proposed: (advisory). Human confirms via fw bvp confirm-cost. Deterministic R3 contract. Q4 SLA: 10s synchronous cap. Same TermLink worker harness as T-1922.

status: captured
workflow_type: build
owner: agent
horizon: next
tags: [bvp, build, slice-7c, termlink, cost, arc-006]
components: [agents/termlink/bvp-estimator/, web/blueprints/bvp.py, lib/bvp.sh]
related_tasks: [T-1915, T-1916, T-1922, T-1923, T-1934]
arc_id: value-prioritisation
created: 2026-05-19T19:01:40Z
last_update: 2026-05-19T19:01:40Z
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

# T-1935: BVP T-NEW-7c — bvp-cost-estimator (propose cost_estimate per task)

## Context

T-1922 proposes BVP scores per directive. T-1934 ships the proposed-mode
scatter. But 60+ tasks today carry `bvp_scores_proposed:` and zero
carry `cost_estimate:` — so without an estimator, T-1934 falls back to
`default-medium` (x=4) for every point and the scatter clusters at a
single x-coordinate.

T-1935 closes the F8 cost-axis gap with the same harness pattern as
T-1922: deterministic heuristic engine, advisory-only writes,
sovereignty-preserving, R3-bit-deterministic.

**Source:** arc-006 (value-prioritisation) §F8; T-1934 §Limitations.

**Engine choice:** v1-heuristic (same rationale as T-1922 — bit-deterministic
satisfies R3; ~10ms latency; zero token cost; auditable). v2-LLM is a
clean follow-up.

**Heuristic per component:**
- `blast_radius` — from `fw fabric blast-radius HEAD` only when the
  task body cites changed files. Else 0 (no work touches source) or
  fallback to T-shirt size if author specified one.
- `tier` — table lookup: `tags ∩ {tier-0, tier-1, ...}` → integer; else
  workflow_type heuristic (build=2, refactor=3, test=1, inception=4
  while exploring).
- `effort` — `min(8, max(1, body_line_count / 50 + ac_count))`. Capped
  at 8 to stay within T-shirt-XL bound.

## Acceptance Criteria

### Agent
- [ ] `agents/termlink/bvp-estimator/estimator.py:estimate_cost(task_path) -> dict` returns `{cost_estimate, evidence, version, rubric_sha, latency_s}` with `cost_estimate` shape `{blast_radius, tier, effort}` integers.
- [ ] Sovereignty: estimator writes ONLY to `cost_estimate_proposed:` (advisory list, parallel structure to `bvp_scores_proposed:`). `cost_estimate:` (confirmed) is human-only via `fw bvp confirm-cost`.
- [ ] M3 v2-delta semantics: skip writing when proposal is within ±1 on every component vs. confirmed.
- [ ] Determinism R3: 10 consecutive `estimate_cost` calls on the same task yield bit-identical output (latency excluded).
- [ ] CLI verbs added: `fw bvp estimate-cost T-XXX`, `fw bvp estimate-cost all`, `fw bvp estimate-cost sweep --cron`, `fw bvp estimate-cost determinism T-XXX`.
- [ ] Cron entry `bvp-cost-estimator-sweep-15m` added to `.context/cron-registry.yaml` (mirrors T-1923's sweep entry); `fw doctor` reports "Cron registry in sync".
- [ ] `web/blueprints/bvp.py:_compute_cost` reads `cost_estimate_proposed:` (latest entry) when `cost_estimate:` is absent and `default_when_absent=True` is set; the default-medium fallback then becomes a last-resort instead of the common case.
- [ ] Unit tests pin: per-component shape contract, determinism (10-run delta=0), M3 v2-delta (skip/no-skip), sovereignty (writes only to proposed), `_compute_cost` reads proposed path.
- [ ] After full sweep, `curl /bvp` returns >0 task points NOT at x=4 (i.e., the dots spread across the x-axis).

### Human
<!-- All ACs above are deterministic/structural — no [REVIEW] Human ACs required.
     If visual blast-radius distribution looks wrong on the scatter, that's
     fed back as a follow-up rather than blocking this slice. -->

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

grep -q "estimate_cost" agents/termlink/bvp-estimator/estimator.py
grep -q "cost_estimate_proposed" agents/termlink/bvp-estimator/estimator.py
grep -q "bvp-cost-estimator-sweep-15m" .context/cron-registry.yaml
out=$(bin/fw doctor 2>&1 || true); [ "$(printf %s "$out" | grep -c 'Cron registry in sync')" -ge 1 ]
out=$(python3 -m pytest tests/unit/test_bvp_estimator.py tests/unit/test_bvp_blueprint_cost.py 2>&1 || true); [ "$(printf %s "$out" | grep -cE 'passed')" -ge 1 ]
out=$(bin/fw bvp estimate-cost determinism T-1922 2>&1 || true); [ "$(printf %s "$out" | grep -cE 'delta=0|deterministic')" -ge 1 ]

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

### 2026-05-19T19:01:40Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1935-bvp-t-new-7c-bvp-cost-estimator--propose.md
- **Context:** Initial task creation
