---
id: T-2243
name: "fw doctor self-vendor drift WARN — F2 N×M any-time inspection surface"
description: >
  fw doctor self-vendor drift WARN — F2 N×M any-time inspection surface

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
created: 2026-06-07T20:28:24Z
last_update: '2026-06-11T22:24:12Z'
date_finished: 2026-06-07T21:03:28Z
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
  - ts: '2026-06-07T20:30:03Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-06-07T20:30:03Z'
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
      D3: 0
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2243: fw doctor self-vendor drift WARN — F2 N×M any-time inspection surface

## Context

The F2 N×M chain (T-2240 push-time + T-2241 templates-class) closed at the dev push surface. `fw doctor` Check 2b (T-1434) already walks `.agentic-framework/{bin,lib,agents,web}` for libs drift — but NOT `.agentic-framework/.tasks/templates/` for the templates class. This is the any-time inspection asymmetry: doctor catches libs drift, misses templates drift. Same class as T-2241's pre-push fix, distinct surface (inspection vs gate).

Scope: extend Check 2b to also walk `.tasks/templates/*.md`. One file, one helper inline-extension, no new flag. Block message stays class-agnostic ("vendored-source drift") with one bullet per affected class.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] Check 2b in `bin/fw` `do_doctor` (around line 794-849) also walks `$FRAMEWORK_ROOT/.agentic-framework/.tasks/templates/*.md` and counts diffs against `$FRAMEWORK_ROOT/.tasks/templates/*.md`.
- [x] WARN message stays class-agnostic (`Vendored-source drift: N file(s) out of sync` + `Run: fw vendor` hint). Per-class breakdown (`libs (N)` / `templates (N)` first-5 lines) makes both classes visible regardless of which one drifted more — pre-T-2243 the global "first 5" bucket could bury small templates drift behind large libs drift.
- [x] Bats test `tests/unit/t2243_doctor_self_vendor_templates.bats` exercises four states: no-templates-drift (templates class absent from WARN), templates-only drift (templates count==1 named), per-class split (libs and templates counted separately), remediation hint preserved — 4/4 PASS.
- [x] [REVIEWER] Reviewer PASS — verified via `bin/fw reviewer T-2243` after L-387 Verification cleanup.

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

# Verify the templates path is in Check 2b's find arglist.
# Direct grep on file — no pipe, no SIGPIPE risk. `bin/fw` is large enough
# that even the L-387 capture-then-grep pattern (`out=$(cat bin/fw); echo
# "$out" | grep -q PATTERN`) SIGPIPEs at exit 141 because grep closes stdin
# the instant it finds the match while echo is still writing. Direct file
# grep avoids the pipe entirely.
grep -q ".tasks/templates" bin/fw

# Bats coverage for both classes (libs + templates)
bats tests/unit/t2243_doctor_self_vendor_templates.bats

# Reviewer verdict (L-387 capture-then-grep)
out=$(bin/fw reviewer T-2243 2>&1); echo "$out" | grep -qE "Overall:.*PASS"

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

### 2026-06-07 — Per-class split vs. global counter

- **Chose:** Split Check 2b into `_vdrift_libs` and `_vdrift_tpl` counters with separate WARN lines (`libs (N) — first M: ...` and `templates (N) — first M: ...`).
- **Why:** A single global "first 5" bucket let large libs drift bury small templates drift entirely (the framework's `.agentic-framework/` carries 64 pre-existing libs drifts day-to-day; 1 templates drift would land at position 65 and never appear in the list). Per-class lists mirror the pre-push gate's `would sync N <class>(s)` shape from T-2240/T-2241, so dev mental model is identical between the inspection (doctor) and gate (pre-push) surfaces.
- **Rejected:** Bump the global cap from 5 to 20 — keeps the bury risk just one regression away; doesn't structurally fix the asymmetry.

## Recommendation

**Recommendation:** GO

**Rationale:** T-2243 closes the any-time inspection asymmetry left by the F2 N×M leg (T-2240 push-time gate + T-2241 templates-class verb). `fw doctor` Check 2b now counts both classes — libs (T-1434) AND templates (T-2241) — with per-class WARN visibility so neither class can bury the other. Same regex shape as pre-push (`Vendored-source drift: N`), so dev mental model is identical across inspection and gate surfaces.

**Evidence:**
- `bin/fw:797-849` — Check 2b refactored into per-class counters + lists
- `tests/unit/t2243_doctor_self_vendor_templates.bats` — 4 tests (no-drift / templates-only / per-class split / remediation hint)
- F2 N×M chain: T-2095 → T-2232 → T-2237 → T-2239 → T-2240 → T-2241 → T-2242 → **T-2243**
- `fw vendor self` (T-2095) still only refreshes `lib/*.sh` — the doctor surface catches the rest (bin/fw, agents/, web/), which is exactly its purpose

**Follow-on candidate:** `agents/audit/audit.sh` has no self-vendor drift check either — daily cron'd backstop slice (T-2244 candidate, NOT in this scope).

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

### 2026-06-07T20:28:24Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2243-fw-doctor-self-vendor-drift-warn--f2-nm-.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-d9e09a76
- **Timestamp:** 2026-06-07T21:11:08Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-06-07T21:03:28Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
