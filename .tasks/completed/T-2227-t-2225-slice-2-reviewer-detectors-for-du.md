---
id: T-2227
name: "T-2225 Slice 2: reviewer detectors for dual-patch-missing + hardcoded numeric
  task-id sentinels"
description: >
  T-2225 Slice 2: reviewer detectors for dual-patch-missing + hardcoded numeric task-id
  sentinels

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
created: 2026-06-06T09:35:13Z
last_update: '2026-06-11T22:24:12Z'
date_finished: 2026-06-06T09:44:20Z
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
  - ts: '2026-06-06T09:45:02Z'
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
  - ts: '2026-06-11T22:24:12Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=0 
      (no-signal); F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); 
      F2=0 (no-signal)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-06-06T09:45:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2227: T-2225 Slice 2: reviewer detectors for dual-patch-missing + hardcoded numeric task-id sentinels

## Context

T-2225 inception GO Slice 2 — Layer 4 of the steelman path. Spec said "reviewer detector"; this slice **pivots to pytest invariants** as a strictly-stronger form of the same Layer-4 intent. Rationale:

- **Reviewer architecture is task-scoped** (each detector receives section text from one task file). Drift in `web/test_app.py` doesn't naturally attribute to a specific task — false-positive risk across every task scan.
- **Pytest invariants fail CI immediately**, blocking the test suite and the close gate. Reviewer findings are advisory (CONCERN level at best).
- **Same Layer-4 intent**: structural-scan prevention that fires on drift introduction, not at PR-review time only.
- Per L-324 (surfaced in task briefing): *"Static task-ID fixtures in tests decay because the daily reviewer scan rewrites…"* — pytest invariants are decay-proof; daily-scan rewrites can't silently update them.

**Spec source:** T-2225 research artifact §3.2 Layer 4 + Evolution log entry on T-2226.
**Predecessor:** T-2226 Slice 1 shipped sentinel namespace + `tmp_project_root` helper. Slice 2 prevents drift back.

## Acceptance Criteria

### Agent
- [x] New test file `tests/unit/test_t2225_isolation_invariants.py` exists with at least 2 invariant test functions.
- [x] Invariant A — sentinel namespace pristine: scans `web/test_app.py` for `T-(996|997|998|999)` word-boundary matches. Asserts zero matches. Catches Layer-1 drift (new test author adds a `T-997`-style sentinel instead of `T-Test-NNN`).
- [x] Invariant B — file-writing tests use the helper: scans `web/test_app.py` to find every function that calls `.write_text(` inside a test body AND patches `web.shared.PROJECT_ROOT` or `web.blueprints.tasks.PROJECT_ROOT`. For each such function, asserts that `tmp_project_root` appears in its parameter list. Excludes the `tmp_project_root` fixture's own definition.
- [x] Both invariants PASS on current HEAD (post-T-2226 state) — verified by `python3 -m pytest tests/unit/test_t2225_isolation_invariants.py -q` exit 0.
- [x] Regression-net unit tests prove invariants fire on synthetic drift: `test_invariant_a_catches_drift` constructs a string containing `T-997` and asserts the detector flags it; `test_invariant_b_catches_drift` constructs a synthetic test-function string with the anti-pattern and asserts the detector flags it. Uses controlled string fixtures, not edits to the live file.
- [x] `bin/fw reviewer T-2227 2>&1 \| grep -q "Overall:.*PASS"` — reviewer static-scan PASS.
- [x] No regression in `python3 -m pytest web/test_app.py -q --tb=no` (still 145/145 PASS — Slice 1's hygiene preserved).

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

# AC#1: invariants test file exists
test -f tests/unit/test_t2225_isolation_invariants.py
# AC#2+#3+#5: invariants + regression-net tests all PASS
python3 -m pytest tests/unit/test_t2225_isolation_invariants.py -q --tb=short
# AC#6: reviewer PASS
out=$(bin/fw reviewer T-2227 --no-write 2>&1); echo "$out" | grep -q "Overall:.*PASS"
# AC#7: web suite regression — still 145/145
python3 -m pytest web/test_app.py -q --tb=no

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

**Recommendation:** GO

**Rationale:** Slice 2 ships Layer-4 structural prevention in its strictly-stronger pytest-invariant form. Reviewer-detector spec from the artifact was a means; the end is "drift-on-next-test prevented by static scan before merge" — pytest invariants achieve that with CI-blocking enforcement instead of advisory CONCERNs. 7/7 tests PASS (2 live invariants + 5 regression-net). Web suite still 145/145.

**Evidence:**
- `tests/unit/test_t2225_isolation_invariants.py` (171 LoC) — 2 live invariants + 5 regression-net synthetic-drift tests
- Invariant A (`test_invariant_a_sentinel_namespace_pristine`): word-boundary regex `T-(996|997|998|999)\b`, asserts zero matches in `web/test_app.py`
- Invariant B (`test_invariant_b_file_writing_tests_use_helper`): AST-walk to find functions with `.write_text(...)` AND `monkeypatch.setattr(...PROJECT_ROOT...)` but without `tmp_project_root` parameter; excludes the helper's own definition
- Regression-net: `test_invariant_*_catches_drift` (positive cases — synthetic drift correctly flagged), `test_invariant_*_ignores_*` (negative cases — pristine patterns correctly ignored)
- Live test results: 7 passed in 0.13s
- Reviewer (latest scan): PASS, zero findings
- Web suite: 145/145 PASS in 151.27s (unchanged from post-Slice-1 baseline)

## Evolution

### 2026-06-06 — Slice 2 spec pivot (reviewer → pytest invariants)

- **What changed:** Slice 2 specced "reviewer detectors" in the T-2225 artifact §3.2 Layer 4. On implementation, the reviewer's task-scoped architecture (each detector receives task-section text) doesn't naturally attribute file-level drift to a specific task — would false-positive across every task scan after drift lands.
- **Plan impact:** Pivoted to pytest invariants (`tests/unit/test_t2225_isolation_invariants.py`). Strictly-stronger form: pytest invariants fail CI immediately rather than emit advisory CONCERNs at PR-review time. The artifact's "drift-on-next-test prevented by static scan before merge" intent is preserved.
- **Triggered:** No new task — Slice 2 scope absorbed the pivot. Documented in this Evolution log so Slice 3's spec doesn't re-propose reviewer detectors.

### 2026-06-06 — L-324 reinforcement

- **What changed:** Task briefing surfaced L-324: *"Static task-ID fixtures in tests decay because the daily reviewer scan rewrites…"* Directly relevant to the namespace-pristine invariant.
- **Plan impact:** None — the pytest-invariant approach is decay-proof by construction (the test file IS the fixture; the reviewer can't silently rewrite assertion targets). But the rationale section now explicitly cites L-324 as the prior-art that motivates the pytest-over-reviewer choice.
- **Triggered:** No new task.

## Updates

### 2026-06-06T09:35:13Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2227-t-2225-slice-2-reviewer-detectors-for-du.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-69e61529
- **Timestamp:** 2026-06-06T09:46:41Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-06-06T09:44:20Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
