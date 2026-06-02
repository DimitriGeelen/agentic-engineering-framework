---
id: T-2175
name: "Reviewer FAIL fix batch B — mock-only-integration per-task triage (T-1897,
  T-2072 from T-2173 Cluster 5)"
description: >
  T-1897 + T-2072 fire mock-only-integration at FAIL severity (partial+heuristic).
  Per-task decision: (a) add a real integration smoke if AC genuinely needs end-to-end
  proof, OR (b) file fw reviewer override add --pattern mock-only-integration --ac
  N --reason '...' --ttl 90 if the mock is sufficient coverage. Decision is per-task
  — no batchable shape.

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: [reviewer-quality, fail-fix, mock-only-integration, T-2173-child]
components: []
related_tasks: [T-2173, T-1897, T-2072, T-1443]
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-06-02T08:40:56Z
last_update: 2026-06-02T15:27:00Z
date_finished: 2026-06-02T15:27:00Z
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
  - ts: '2026-06-02T08:45:02Z'
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
cost_estimate_proposed:
  - ts: '2026-06-02T08:45:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 7
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=7 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2175: Reviewer FAIL fix batch B — mock-only-integration per-task triage (T-1897, T-2072 from T-2173 Cluster 5)

## Context

Parent: T-2173 Cluster 5. Two completed tasks fire `mock-only-integration` at FAIL severity:
- T-1897 — context to be re-read at triage time
- T-2072 — fires mock-only-integration *and* skip-as-pass (the latter is handled in Fix A / T-2174; this task handles the mock leg only)

`mock-only-integration` is a *heuristic* + *partial* finding — it flags an AC mentioning integration semantics whose Verification only mocks/stubs the dependency. The heuristic has known FP cases (e.g., a unit test against a mock IS the agreed coverage, and the AC's "integrates with X" phrase is structural-not-behavioural).

**Triage per task:**
1. Read the AC + Verification block
2. Decide: real integration smoke needed, OR mock is sufficient coverage
3. If real-smoke: write the integration test and update Verification
4. If mock-sufficient: file `fw reviewer override add T-XXX --pattern mock-only-integration --ac <N> --reason "..." --ttl 90`

## Acceptance Criteria

### Agent
- [x] T-1897 triaged. Decision recorded in this task's `## Decisions` section: "real-smoke" OR "mock-sufficient (override OV-NNNN filed)". Verification: `bin/fw reviewer T-1897 --no-write --json | python3 -c "import sys,json; d=json.loads(sys.stdin.read()); ok = all(f.get('pattern_id') != 'mock-only-integration' for f in d.get('findings',[])); print(ok)"` returns `True`.
- [x] T-2072 triaged. Same decision shape. Verification: same JSON check on T-2072 returns `True`.
- [x] If override filed for either task, the override has `--ttl 90` (default) and a substantive `--reason` (not "FP, override"). Verification: `bin/fw reviewer override list 2>&1 | grep -E "T-1897|T-2072"` — entries present with substantive reason text.
- [x] If integration smoke added for either task, the new test lives in the appropriate `tests/` directory and is discoverable by `fw test`. Verification: `fw test all` includes the new test file in its output.

### Human
- [ ] [REVIEW] Triage decisions match operator's intuition — "real-smoke" decisions are genuine integration gaps; "mock-sufficient" decisions don't hide real coverage loss.
  **Steps:**
  1. Read this task's `## Decisions` section
  2. For each "mock-sufficient" decision, sanity-check the `--reason` against the AC text
  3. For each "real-smoke" decision, sanity-check the new test exists and asserts something meaningful
  **Expected:** Decisions are defensible per task.
  **If not:** Push back with specific case; agent re-triages.

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

# T-2175 verification (capture-then-grep per L-387):
out=$(bin/fw reviewer T-1897 --no-write --json 2>&1); echo "$out" | python3 -c "import json,sys; d=json.load(sys.stdin); sys.exit(0 if all(f['pattern_id'] != 'mock-only-integration' for f in d.get('findings',[])) else 1)"
out=$(bin/fw reviewer T-2072 --no-write --json 2>&1); echo "$out" | python3 -c "import json,sys; d=json.load(sys.stdin); sys.exit(0 if all(f['pattern_id'] != 'mock-only-integration' for f in d.get('findings',[])) else 1)"
out=$(bin/fw reviewer override list 2>&1); echo "$out" | grep -q "OV-49013554.*T-1897.*mock-only-integration"
out=$(bin/fw reviewer override list 2>&1); echo "$out" | grep -q "OV-28fe3d5a.*T-2072.*mock-only-integration"

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

**Symptom:** T-1897 and T-2072 fired `mock-only-integration` at FAIL severity in T-2173's corpus extraction — the heuristic flagged "AC mentions integration; Verification only invokes unit tests" for two tasks whose deliverables are inherently mock-free.

**Root cause:** The `mock-only-integration` detector compares AC text (integration keywords) against Verification commands (looks for `pytest`/`bats` in `tests/unit/`). It cannot distinguish (a) "unit-only coverage of an integration AC" from (b) "the unit test IS the integration test for a deliverable that has no external dependency". For static analysers and CLI verbs, the unit-test directory location is convention, not semantic coverage class — but the detector has no view into the deliverable's nature.

**Why structurally allowed:** The detector is `heuristic + partial` by design — it surfaces candidates for human review, not deterministic FAIL evidence. T-2173's batch-extraction logic treated `mock-only-integration` fires uniformly as FAILs (per the audit YAML schema) without consulting `lie_severity` or `detection_confidence`. That bucketing was the routing failure; the detector behaved as documented.

**Prevention:** Three legs:
1. **This task** — per-task triage with file-an-override-or-add-integration-smoke decision. Overrides carry substantive rationale (not "FP, override") so future audits know why the suppression is principled.
2. **Detector confidence/severity surfaced at routing time** — when T-2173 (or future cluster extractors) builds the FAIL list, segregate heuristic+partial fires from deterministic+severe ones. Heuristic findings should land in a separate "needs-human-eye" bucket, not the auto-batch-fix queue. Deferred — would be a refactor of `lib/reviewer/audit.py` cluster-totals logic.
3. **Override pattern as living documentation** — the reason text on overrides explains the FP class so future similar tasks can either avoid the trigger or reference an existing override pattern. (See T-1820 OV-22a57a31 "joint-smoke task: integration evidence is the demo" as a precedent.)

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

### 2026-06-02 — Post-T-2177 severity drop changed both tasks from FAIL to CONCERN

- **What changed:** Fresh `bin/fw reviewer T-XXX --no-write --json` shows both T-1897 and T-2072 at `overall: CONCERN` (not FAIL). T-2177's `skip-as-pass` tightening cleared the FAIL-severity drivers; the `mock-only-integration` finding remains but at its native `partial` severity, which bubbles to CONCERN not FAIL. So the urgency dropped — these are no longer blocking-class. Override-based mock-sufficient routing is still appropriate to clear the CONCERN, but the §ACD pivot from T-2174 ("Cluster 1+2 detector-FP-dominant") extends to Cluster 5: this is detector heuristic-FP, not real coverage gap.
- **Plan impact:** No change — overrides still warranted. The plan's two-path triage (real-smoke vs mock-sufficient) collapsed to mock-sufficient for both. Decision recorded below.
- **Triggered:** No new tasks. RCA captures the prevention rail (heuristic-severity routing).

## Decisions

### 2026-06-02 — T-1897 mock-sufficient (OV-49013554)

- **Chose:** File override — `mock-only-integration` is FP for this task.
- **Why:** T-1897's deliverable IS a static analyser detector (`lib/reviewer/static_scan.py` widening of `_HUMAN_AC_MECHANICAL_RE`). The "integration" surface is task-file corpus regression, verified by python+bats unit tests + a real corpus regression run (`fw reviewer audit` cited in AC#6). No external system exists to integration-test against — the detector reads YAML+Markdown and produces JSON. Unit tests of synthetic fixtures + real corpus invocation IS the integration coverage.
- **Rejected:** Adding "integration smoke" — there's nothing to smoke. The detector has no network/DB/external API dependency. A new test wouldn't add coverage, just bureaucratic compliance.
- **Override:** OV-49013554, TTL 89 days (default).

### 2026-06-02 — T-2072 mock-sufficient (OV-28fe3d5a)

- **Chose:** File override — `mock-only-integration` is FP for this task.
- **Why:** T-2072 ships `fw pickup promote-deferred` verb. AC#(d) explicitly covers an integration scenario: "integration via `fw pickup process` auto-fires promote then processes promoted envelope in the same tick". The bats test invokes the real `fw pickup` CLI in subshell — not a mock, not a stub. The `tests/unit/` location is convention (bats lives in unit/), not coverage type. The pickup pipeline IS the SUT; bats exercises it end-to-end through the public CLI.
- **Rejected:** Moving the test to `tests/integration/` — the test is functionally an integration test; the directory rename would be cosmetic. Adding a new "true integration" test would duplicate what the existing bats already does.
- **Override:** OV-28fe3d5a, TTL 89 days (default).

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Recommendation

**Recommendation:** GO

**Rationale:** Both T-1897 and T-2072 triaged as "mock-sufficient" with substantive rationale (the detector heuristic genuinely mis-classes deliverables whose unit-test IS the integration test). Two overrides filed (OV-49013554, OV-28fe3d5a) with TTL 89 days; cached verdicts on both refreshed to `Overall: PASS`. The §ACD pivot from T-2174 (Cluster 1+2 detector-FP-dominant) extends to Cluster 5: `mock-only-integration` at heuristic+partial severity is appropriately routed via principled overrides, not by adding ceremonial integration tests with no real coverage value.

**Evidence:**
- **T-1897 cached verdict:** `Overall: PASS` (post-override).
- **T-2072 cached verdict:** `Overall: PASS` (post-override).
- **Overrides recorded:** `bin/fw reviewer override list | grep -E "T-1897|T-2072"` → OV-49013554 (T-1897, ttl 89), OV-28fe3d5a (T-2072, ttl 89), both with multi-sentence FP rationales.
- **Verification block:** 4 capture-then-grep commands, all green (per L-387 SIGPIPE-safe pattern).

**What's next (operator-facing):**
- **T-2174** (Cluster 1+2 §ACD pivot) — surfaced via `/review/T-2174`.
- **T-2176** (Cluster C corpus-rescan + cache-gap close) — surfaced via `/review/T-2176` this session.
- **T-2179** (Cluster D tautology) — captured horizon: later, awaiting prioritisation.
- **T-2173 parent** can close once human reviews this batch.

## Updates

### 2026-06-02T08:40:56Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2175-reviewer-fail-fix-batch-b--mock-only-int.md
- **Context:** Initial task creation

### 2026-06-02T14:36:41Z — status-update [task-update-agent]
- **Change:** horizon: later → now

### 2026-06-02T15:20:07Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-609f193b
- **Timestamp:** 2026-06-02T15:27:01Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-06-02T15:27:00Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
