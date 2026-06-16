---
id: T-2427
name: "G-070 fix: fabric drift resolver — distinguish data-artifact deps from real drift (target exists on disk → silent; missing → stale)"
description: >
  G-070 fix: fabric drift resolver — distinguish data-artifact deps from real drift (target exists on disk → silent; missing → stale)

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [agents/fabric/lib/drift.sh]
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
created: 2026-06-16T16:30:53Z
last_update: 2026-06-16T16:36:45Z
date_finished: 2026-06-16T16:36:45Z
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

# T-2427: G-070 fix: fabric drift resolver — distinguish data-artifact deps from real drift (target exists on disk → silent; missing → stale)

## Context

G-070 (concerns.yaml:2207) — `fw fabric drift` reports 20 stale edges all targeting legitimate runtime data artifacts (`.context/handovers/LATEST.md`, `.tasks/active/`, `.context/bus/blobs/`, etc.). Resolver in `agents/fabric/lib/drift.sh:65-115` treats "no card registered" identically to "target missing on disk" — both emit `unresolved`. Real drift (a card pointing at a deleted source) is drowned by data-artifact noise. Resolution path (G-070 entry): distinguish (a) target exists on disk → silent and (b) target missing on disk → STALE. Sibling: G-070 status was `watching` since 2026-05-28.

## Acceptance Criteria

### Agent
- [x] Python block in `agents/fabric/lib/drift.sh` distinguishes target-exists-on-disk (silent) from target-missing (stale)
- [x] PROJECT_ROOT passed to Python block so target paths can be resolved against it (handles relative + absolute)
- [x] `fw fabric drift` reports 0 stale edges when all 20 current targets exist on disk (live verification; 20 → 0)
- [x] Regression test: bats `tests/unit/fabric_drift_data_artifact.bats` — fixture card with depends_on to existing dir/file = silent, fixture card with depends_on to nonexistent path = stale (6/6 PASS)
- [x] No fabric drift behavioral regressions — sibling `tests/unit/fabric_globstar.bats` and `tests/unit/fabric_register_slug.bats` show no new failures (pre-existing `shopt -s globstar` test failures predate this edit; verified via `git stash` baseline)

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

bash -n agents/fabric/lib/drift.sh
out=$(bin/fw fabric drift 2>&1); echo "$out" | grep -q "stale: 0"
bats tests/unit/fabric_drift_data_artifact.bats

## RCA

**Symptom:** `fw fabric drift` reported 20 stale edges every invocation; same 20 edges showed up in `fw audit` output. All 14 of the targets were legitimate runtime artifacts that exist on disk (`.context/handovers/LATEST.md` symlink, `.tasks/active/` dir, `.context/bus/blobs/` dir, etc.); the other 6 were `type: writes` edges declaring lazy-create intent. Real drift (a card pointing at a deleted source) was indistinguishable in the noise.

**Root cause:** The Python block in `agents/fabric/lib/drift.sh:65-115` (T-1674's single-pass optimisation) checked only one signal: "is `target` present in `known`?" where `known` was the set of all registered `id|name|location` values. If a target wasn't a registered card, it emitted `unresolved` regardless of whether the target was a real on-disk artifact, a write-target the script creates lazily, or a system binary. The resolver had no model of "data-artifact dependency" — every non-card target was treated as broken-pointer drift.

**Why structurally allowed:** The fabric format documents `depends_on.type` (calls|reads|writes|triggers|renders) but the drift resolver never read `type` — it only matched `target`. The semantic distinction between "I read from this file" (must exist) and "I write to this file" (created on first run) was in the data model but not the validator. The 20 false-positive lines accumulated silently from 2026-05-28 (G-070 filed) until 2026-06-16 — 19 days of audit noise drowning any real drift signal.

**Prevention:** (1) Resolver now branches on `_resolves_on_disk(target, root)` — relative paths joined with `PROJECT_ROOT`, absolute paths checked verbatim, bare names checked in `$PATH`. (2) Resolver now reads `dep.type` and skips `WRITE_TYPES = {writes, writes_data, writes_runtime}` (write-targets are intent, not drift). (3) Regression test `tests/unit/fabric_drift_data_artifact.bats` pins all four cases (A: existing dir silent, B: existing file silent, C: missing reads STALE, D: missing writes silent, E: system binary silent, F: missing bare name STALE) — any regression that re-broadens "no card → stale" will fail one of these.

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

### 2026-06-16T16:30:53Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2427-g-070-fix-fabric-drift-resolver--disting.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-c8dae3bc
- **Timestamp:** 2026-06-16T16:36:51Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-06-16T16:36:45Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
