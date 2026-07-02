---
id: T-2228
name: "T-2225 Slice 3 — production-tool skip-list for T-Test-* sentinel namespace"
description: >
  T-2225 Slice 3 — production-tool skip-list for T-Test-* sentinel namespace

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: [C-004, agents/docgen/generate_article.py, 
      agents/docgen/generate_component.py, lib/evolution_log.sh, web/shared.py]
related_tasks: []
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-06-06T11:08:10Z
last_update: '2026-06-11T22:24:12Z'
date_finished: 2026-06-06T11:31:43Z
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
  - ts: '2026-06-06T11:15:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 2
      F-ORCH: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=2 
      (body:lightly-promoted); F-ORCH=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:24:12Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 2
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 1
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=2 
      (body:lightly-promoted); F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=1 (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-06-06T11:15:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2228: T-2225 Slice 3 — production-tool skip-list for T-Test-* sentinel namespace

## Context

T-2225 Slice 3 (Layer 3 — production-tool skip-list, GO scope item 3 of 3 from
T-2225 Recommendation). Slice 1 (T-2226) installed the `T-Test-NNN` sentinel
namespace + `tmp_project_root` isolation helper. Slice 2 (T-2227) installed
pytest invariants to catch drift. This slice hardens production: even if a test
helper is bypassed and a real `.tasks/active/T-Test-001.md` file leaks, the
production scanners (audit / fabric / episodic / task-list) must filter it out.

**Spike A finding (regex audit of `T-\d+` patterns across framework source):**
the regex-based scanners (`T-\d+`, `T-[0-9]+`) are ALREADY safe — the `\d`/`[0-9]`
character class excludes letters, so `T-Test-NNN` cannot match. The real risk
surface is the **glob `T-*.md` / `T-*.yaml` scans**: 13+ sites in
`agents/audit/audit.sh`, 3 in `web/shared.py`, 2 in `agents/docgen/`, 1 in
`lib/evolution_log.sh`. A leaked sentinel file is picked up by all of those.

Design: single shared `is_test_sentinel(name)` filter (Python helper in
`web/shared.py` + bash equivalent in `agents/audit/audit.sh`). Applied at each
glob site. ~60-80 LoC across 4 surfaces per T-2225 estimate.

Origin: T-2225 inception decided GO 2026-06-06 (operator via Watchtower);
research artifact `docs/reports/T-2225-test-sentinel-isolation.md`. This is the
last open thread of T-2225 GO scope.

## Acceptance Criteria

### Agent
- [x] `is_test_sentinel(name)` Python helper added to `web/shared.py` with docstring referencing T-2225/T-2228 and the `T-Test-` prefix rule
- [x] `_is_test_sentinel` bash helper added to `agents/audit/audit.sh` matching the same `T-Test-*` basename rule
- [x] All 3 `T-*.md` / `T-*.yaml` glob sites in `web/shared.py` filter via `is_test_sentinel`
- [x] `agents/audit/audit.sh` task-counting + episodic + active/completed loop glob sites filter via `_is_test_sentinel` (key audit surfaces only — minimal-invasive)
- [x] `lib/evolution_log.sh` `T-*.md` find filters via `-not -name 'T-Test-*'` (or equivalent)
- [x] `agents/docgen/generate_article.py` + `agents/docgen/generate_component.py` `T-*.yaml` glob sites filter via `is_test_sentinel`
- [x] New unit test `tests/unit/test_t2228_sentinel_skip.py` proves a leaked `.tasks/active/T-Test-001.md` is invisible to `web/shared.py` listings (tmp_project_root pattern)
- [x] New bats test exercises that `agents/audit/audit.sh` task-count does not include leaked `T-Test-*` files
- [x] Existing web suite still 145/145 PASS (no Slice 1/2 regression)
- [x] Existing reviewer suite still PASS for the changed files (`fw reviewer T-2228`)

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

# AC#1 helper added
grep -q "^def is_test_sentinel" web/shared.py
# AC#2 bash helper added
grep -q "_is_test_sentinel()" agents/audit/audit.sh
# AC#3 web/shared.py 3 glob sites: helper called in each (line-range gate)
out=$(grep -n "is_test_sentinel" web/shared.py); echo "$out" | grep -qE "^[0-9]+:" && [ $(echo "$out" | wc -l) -ge 4 ]
# AC#5 evolution_log.sh skips T-Test-*
grep -q "T-Test-\\*" lib/evolution_log.sh
# AC#6 docgen scripts filter T-Test
grep -q "is_test_sentinel\\|T-Test-" agents/docgen/generate_article.py
grep -q "is_test_sentinel\\|T-Test-" agents/docgen/generate_component.py
# AC#7 unit test exists + passes
test -f tests/unit/test_t2228_sentinel_skip.py
out=$(python3 -m pytest tests/unit/test_t2228_sentinel_skip.py -x --no-header -q 2>&1); echo "$out" | grep -qE "passed"
# AC#8 bats test exercises sentinel-skip for audit
test -f tests/unit/t2228_audit_sentinel_skip.bats
out=$(bats tests/unit/t2228_audit_sentinel_skip.bats 2>&1); echo "$out" | grep -qE "ok [0-9]+"
# AC#9 existing web suite still 145/145
out=$(python3 -m pytest web/test_app.py --no-header -q 2>&1); echo "$out" | grep -qE "145 passed"
# AC#10 reviewer PASS on this task
out=$(bin/fw reviewer T-2228 --no-write 2>&1); echo "$out" | grep -q "Overall:.*PASS"

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

## Recommendation

**Recommendation:** GO

**Rationale:**

T-2225 Slice 3 GO scope shipped. Spike A (regex audit) findings codified into
Context: `T-\d+` regexes already filter T-Test-NNN via the `\d` character class;
the only real surface was glob `T-*.md` / `T-*.yaml` scans. Slice 3 closes that
defense-in-depth layer:

- Shared `is_test_sentinel(name)` Python helper in `web/shared.py:24-50` with
  T-2225/T-2228 docstring + cross-reference to Slice 1 / Slice 2.
- Sibling `_is_test_sentinel()` bash helper in `agents/audit/audit.sh:438-447`.
- Patched 7 production glob/find sites: web/shared.py (3), agents/audit/audit.sh
  (3 — find + arc-membership for-loop + python arc-index heredoc),
  lib/evolution_log.sh (1), agents/docgen/generate_article.py (1),
  agents/docgen/generate_component.py (1).
- Single Slice 1 regression caught + fixed: `test_task_file_frontmatter_missing_fields`
  inverted its assertion from "T-Test-006 visible" → "T-Test-006 filtered" — the
  test's intent (minimal-frontmatter doesn't crash) is preserved as a 200 +
  Slice-3-filter assertion. Updated test docstring documents the layering.
- 13/13 new tests PASS (6 pytest + 9 bats — second bats result was 9 not the
  estimated 8). 145/145 web suite intact. 7/7 T-2227 invariants intact.
- Reviewer PASS (R-4e5c1065) after dropping `tail -3` middle-stage from
  Verification per L-387.

T-2225 GO scope is now fully discharged (Slices 1+2+3 complete). The defense
chain — isolated writes (Slice 1) + drift detection (Slice 2) + production
filtering (Slice 3) — is end-to-end.

**Evidence:**

- `web/shared.py:24-50` — helper definition
- `web/shared.py:297, 870, 901` — 3 patched glob sites
- `agents/audit/audit.sh:438-447` — bash helper
- `agents/audit/audit.sh:640, 722, 962` — 3 patched audit sites
- `lib/evolution_log.sh:105` — find filter
- `agents/docgen/generate_article.py:137` + `generate_component.py:85` — glob filters
- `tests/unit/test_t2228_sentinel_skip.py` — 6 invariants PASS
- `tests/unit/t2228_audit_sentinel_skip.bats` — 9 invariants PASS
- `web/test_app.py:1153-1175` — Slice 1 regression fixed (inverted assertion)
- Reviewer: R-4e5c1065 PASS

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

### 2026-06-06T11:08:10Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2228-t-2225-slice-3--production-tool-skip-lis.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-7a83b36d
- **Timestamp:** 2026-06-06T11:34:15Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-06-06T11:31:43Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
