---
id: T-2226
name: "T-2225 Slice 1: T-Test-NNN sentinel namespace + autouse client_isolation fixture"
description: >
  T-2225 Slice 1: T-Test-NNN sentinel namespace + autouse client_isolation fixture

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-06-06T08:56:07Z
last_update: '2026-06-06T09:00:03Z'
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
  - ts: '2026-06-06T09:00:03Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 2
      F-RECALL: 2
      F-ORCH: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=2 (body:lightly-promoted); F-ORCH=0 (no-signal)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-06-06T09:00:03Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2226: T-2225 Slice 1: T-Test-NNN sentinel namespace + autouse client_isolation fixture

## Context

T-2225 inception GO (decided 2026-06-06). Slice 1 of the 3-slice steelman path: Layer 1 (namespace) + Layer 2 (cache-leak prevention).

**Live evidence (2026-06-06):**
- 4 distinct sentinel IDs in `web/test_app.py` (artifact catalogued 3; T-996 at line 1127 was missed): T-996/997/998/999
- 7 hardcode sites: lines 170, 282, 1018, 1098, 1106, 1113, 1121 (+ T-996 at 1127)
- 5 dual-patch-missing sites: 1023, 1057, 1066, 1103, 1118 — patch only one of `(web.shared.PROJECT_ROOT, web.blueprints.tasks.PROJECT_ROOT)`. Cache leaks consumer-state into tests.
- 1 canonical-correct site: lines 1134-1139 (T-1239 dual-patch + `_task_cache["data"] = None` invalidation)

**Research artifact:** `docs/reports/T-2225-test-sentinel-isolation.md`
**Inception decision:** GO toward steelman (T-2225 in `.tasks/completed/`).

## Acceptance Criteria

### Agent
- [x] All sentinel-id hardcodes in `web/test_app.py` migrated from `T-996/997/998/999` (3-digit) to `T-Test-NNN` namespace (001..006 assigned). Verified by `grep -nE "T-(996|997|998|999)\b" web/test_app.py` returning zero matches. The T-9999 route-format-check on line 331 is NOT a sentinel write — see inline rationale.
- [x] New helper fixture `tmp_project_root` defined in `web/test_app.py` that: (a) scaffolds `.tasks/{active,completed}` + `.context/episodic` under tmp_path, (b) monkeypatches BOTH `web.shared.PROJECT_ROOT` and `web.blueprints.tasks.PROJECT_ROOT`, (c) invalidates `_task_cache["data"] = None`. Verified by `grep -nE "def tmp_project_root|tmp_project_root\(" web/test_app.py` showing definition + uses.
- [x] All 5 previously-dual-patch-missing sites (line 1014, 1055, 1061, 1094, 1109 in the migrated file) use `tmp_project_root` instead of manual `tmp_path + monkeypatch` — closes the cache-leak class structurally within those tests.
- [x] `python3 -m pytest web/test_app.py -q --tb=no` exits 0 (regression-net: pre-baseline pass count is preserved or improved; no new failures introduced).
- [x] `bin/fw reviewer T-2226 2>&1 \| grep -q "Overall:.*PASS"` — reviewer static-scan PASS (no anti-patterns introduced; T-Test-* IDs not flagged as numeric-task-id collisions because the namespace is distinct).
- [x] Inline comment block above the migrated sentinel sites documents the `T-Test-NNN` convention (4-line block: namespace purpose, why isolated from operational tooling, where Slice 3 will add the production-tool skip-list, pointer to T-2225 artifact).

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

# AC#1: namespace migration completed (zero T-(996|997|998|999) word-boundary remaining)
out=$(grep -nE "T-(996|997|998|999)\b" web/test_app.py 2>&1 || true); test -z "$out"
# AC#2: tmp_project_root helper fixture defined
grep -nE "def tmp_project_root" web/test_app.py
# AC#3: 5 dual-patch-missing sites now use the helper (count of tmp_project_root uses ≥ 5)
test "$(grep -cE "tmp_project_root" web/test_app.py)" -ge 6
# AC#4: pytest exits 0 (regression-net: no new failures)
python3 -m pytest web/test_app.py -q --tb=no
# AC#5: reviewer PASS
out=$(bin/fw reviewer T-2226 --no-write 2>&1); echo "$out" | grep -q "Overall:.*PASS"
# AC#6: inline comment block exists above migrated sentinels (anchor: "T-Test-NNN convention")
grep -q "T-Test-NNN convention" web/test_app.py

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

**Rationale:** Slice 1 ships the namespace migration (Layer 1) + helper fixture (Layer 2 helper form) end-to-end. Pre-baseline was 145/145 PASS (not 135/145 as the artifact claimed — stale evidence); post-implementation is still 145/145. Two regressions hit during edit (TestTimeline route-format check; missing `_task_cache` import) caught + fixed before close gate. Reviewer PASS. The "autouse" interpretation of Layer 2 (T-2225 artifact §3.2) was *softened* to "helper-fixture as path-of-least-resistance" for this slice — Slice 2's reviewer detector turns the soft pattern into structural enforcement.

**Evidence:**
- `web/test_app.py:33-79`: new T-Test-NNN convention comment block + `tmp_project_root` helper fixture (T-1239 dual-patch + cache-invalidation in one place)
- Sentinel migration: 8 hardcode sites + 6 test signatures (T-996/997/998/999 → T-Test-001..006)
- 5 dual-patch-missing sites (1014, 1055, 1061, 1094, 1109) now use `tmp_project_root` — drift impossible within fixture scope
- Pre-baseline: 145/145 PASS in 167.98s
- Post-implementation: 145/145 PASS in 158.01s (no new failures; net faster because dropped redundant per-test mkdir scaffolding)
- Reviewer R-02ec481b: PASS, zero findings, Needs Human: no
- Two regressions caught + fixed: (1) TestTimeline T-Test-NNN broke route-format semantic (reverted to T-9999 with rationale comment), (2) missing `from web.shared import _task_cache` after dual-patch block deletion (re-added inside test body)

## Evolution

### 2026-06-06 — Slice 1 implementation

- **What changed:** Pre-baseline pytest = 145/145 PASS (artifact §1 claimed "current 135/145" — stale; cache-leak class is non-deterministic in CI but doesn't reliably fail at HEAD).
- **Plan impact:** Layer 2's "autouse" structural-prevention claim softens to "helper-fixture-as-canonical-pattern". True autouse module-wide would risk breaking the 140 tests that rely on the real PROJECT_ROOT. Slice 2's reviewer detector becomes more important — it's the layer that turns the soft pattern into structural enforcement.
- **Triggered:** Slice 2 ACs should explicitly include a `detect_test_isolation_missing_helper` reviewer detector — when a file-writing test does NOT use `tmp_project_root` AND patches PROJECT_ROOT manually, flag CONCERN. Filed for Slice 2 scope.

### 2026-06-06 — sentinel scope correction

- **What changed:** Artifact catalogued 3 sentinels (T-997/998/999); live grep found 4 (T-996 at line 1127).
- **Plan impact:** Sentinel namespace IDs went to 001..006 instead of 001..004. AC#1 expanded to cover all 8 hardcode sites.
- **Triggered:** No new task. Slice 1 scope absorbed the additional site.

### 2026-06-06 — Layer 1 overreach (URL parameter ≠ sentinel write)

- **What changed:** `test_timeline_task_nonexistent` used `T-999` as a URL parameter to test "valid `T-\d+` format, no data → 200". Migrating to `T-Test-002` changed the test semantic to "namespaced ID rejected → 404", duplicating the sibling `test_timeline_task_invalid_id`.
- **Plan impact:** Layer 1's "T-NNNN → T-Test-NNN" applies to *sentinel writes* (fixtures on disk), not URL parameters.
- **Triggered:** Inline comment at the call site documenting the distinction. AC#1 regex tightened to `T-(996|997|998|999)\b` (word boundary) to exclude T-9999 4-digit IDs.

## Updates

### 2026-06-06T08:56:07Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2226-t-2225-slice-1-t-test-nnn-sentinel-names.md
- **Context:** Initial task creation
