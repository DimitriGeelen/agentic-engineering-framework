---
id: T-1975
name: "audit: stale-slice-reference scan — flag 'ship in T-NNNN' where T-NNNN completed
  (L-417 prevention)"
description: >
  Codify L-417: scan web/templates, web/blueprints, lib/ for 'ship in T-NNNN' where
  T-NNNN resolves to .tasks/completed/. WARN class. Prevents stale-slice-reference
  cluster (T-1971/1972/1973/1974).

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: [agents/audit/audit.sh, tests/unit/audit_stale_slice_reference.bats]
related_tasks: [T-1971, T-1972, T-1973, T-1974]
arc_id: arc-grooming
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-21T07:41:37Z
last_update: '2026-06-11T22:24:04Z'
date_finished: 2026-05-21T07:52:18Z
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
  - ts: '2026-05-21T07:42:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:24:04Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 0
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=0
      (no-signal); D4=2 (body:env-class-handled); F-RECALL=0 (no-signal); 
      F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-05-21T07:45:01Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 2
      effort: 8
    rationale: blast_radius=3 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1975: audit: stale-slice-reference scan — flag 'ship in T-NNNN' where T-NNNN completed (L-417 prevention)

## Context

**L-417 origin (T-1971/T-1972/T-1973/T-1974, 2026-05-21):** Four stale-slice-reference instances landed in BVP arc code within 20 minutes:

- `web/templates/bvp.html:8` — "Read-only — live weight sliders ship in T-1929." (T-1929 had shipped)
- `web/blueprints/bvp.py:12` — "Live weight sliders + commit ship in T-1929 (T-NEW-12b)." (same)
- `lib/bvp.sh:286-288` — "Score tasks via fw bvp confirm T-<id> (T-1924) once that slice ships." (T-1924 had shipped)
- `tests/playwright/test_bvp_scatter.py` — selector for `<details>/<summary>` "Current driver weights" (T-1928 surface, replaced by T-1929 sliders)

Pattern: substrate ships → satellite text/test stays frozen → contradicts reality → ad-hoc grep cycle to find them only after human or estimator notices.

**Prevention:** audit-time scan over source surfaces (`web/templates/`, `web/blueprints/`, `lib/*.sh`, `lib/*.py`) for `ship[s]?\s+in\s+T-\d{2,5}` and `once\s+(?:that\s+)?slice\s+ships` phrasings; cross-reference matched `T-NNNN` against `.tasks/completed/`; WARN on any hit. False-positive class: prose that *also* references a still-active task (e.g. "we'll ship in T-9999" where 9999 is open) — those won't trigger because T-NNNN won't be in `.tasks/completed/`.

## Acceptance Criteria

### Agent
- [x] New audit check added under `if should_run_section "structure"` in `agents/audit/audit.sh`, after the inline-arc-tag check (T-1881 pattern)
- [x] Scan scope: `$PROJECT_ROOT/web/templates`, `$PROJECT_ROOT/web/blueprints`, `$PROJECT_ROOT/lib` (recursive, `*.html`, `*.py`, `*.sh`)
- [x] Pattern: case-insensitive regex matching `\<(ship|ships|shipping)\>\s+in\s+T-[0-9]{2,5}` AND `once\s+(?:that\s+)?slice\s+ships?` — past-tense `shipped` deliberately excluded (historical references are correct documentation, not stale forecasts)
- [x] For each match: extract `T-NNNN`, check `.tasks/completed/T-NNNN-*.md` exists; flag only when completed task is referenced
- [x] Failure mode: WARN (not FAIL — first deployment, conservative; FP rate unknown)
- [x] Allowlist: `tests/`, `docs/`, `.fabric/`, `.context/`, `.tasks/`, `agents/audit/audit.sh` itself
- [x] PASS line emitted when zero stale references found: `pass "No stale-slice-references (L-417)"`
- [x] Unit test `tests/unit/audit_stale_slice_reference.bats` covering: clean tree PASS, seeded stale ref WARN, reference to active task does NOT WARN, allowlisted paths skipped, past-tense excluded (13 tests, all green)
- [x] `bin/fw audit --section structure` exits 0 (clean tree) AND PASS line present in output

### Human
<!-- All checks are deterministic — no [REVIEW] needed. Audit infra change is internal. -->

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
# Enforcement-baseline hint (L-398, T-1886): if you edited `.claude/settings.json`
# (added/removed/reorganised hooks), add `bin/fw enforcement baseline` to your
# Verification block. Otherwise the canonical hash diverges and `fw doctor`
# reports a FAIL ("Enforcement baseline CHANGED") that accumulates silently.
# Origin: T-1849/T-1730/T-1731 each added a legitimate hook without refreshing
# the baseline — FAIL sat for multiple sessions until T-1886 cleaned up.

bats tests/unit/audit_stale_slice_reference.bats
out=$(bin/fw audit --section structure 2>&1); grep -q "No stale-slice-references (L-417)" <<<"$out"

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

### 2026-05-21 — past-tense regex narrowing

- **What changed:** First-deployment dry-run on the live tree caught `web/blueprints/arcs.py:3 "Generic operator-facing surface for the Arc system shipped in T-1661."` as a stale-slice-reference. False positive: past-tense "shipped in T-NNNN" is *historical documentation*, not a *forecast that turned stale*. The L-417 anti-pattern is specifically about ship-promises that the substrate fulfilled while the satellite text didn't update.
- **Plan impact:** Regex narrowed from `ship(s|ping|ped)?` to `\<(ship|ships|shipping)\>` (word-boundary anchored). Past-tense excluded. New test case 12 pins the exclusion.
- **Triggered:** No new task — caught and corrected within the build window via dry-run.

## Recommendation

**Recommendation:** GO

**Rationale:** L-417 captured the anti-pattern as a learning but had no structural prevention — the same class hit 4 times in 20 minutes during the BVP cluster (T-1971/T-1972/T-1973/T-1974). This adds a `fw audit` structure-section check that flags forecast-style ship references whose target T-NNNN already lives in `.tasks/completed/`. Past-tense historical references are excluded (caught on first deployment via dry-run). 13/13 unit tests green, live audit emits PASS on clean tree.

**Evidence:**
- New check at `agents/audit/audit.sh` lines ~864-915 (between inline-arc-tag check and fabric-drift)
- Test suite `tests/unit/audit_stale_slice_reference.bats` — 13/13 PASS
- Live `bin/fw audit --section structure` emits `[PASS] No stale-slice-references (L-417)`
- Verification block re-runs both bats suite and live audit at completion gate

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

### 2026-05-21T07:41:37Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1975-audit-stale-slice-reference-scan--flag-s.md
- **Context:** Initial task creation

### 2026-05-21T07:42:02Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-ba3172d2
- **Timestamp:** 2026-06-02T15:00:43Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-21T07:52:18Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
