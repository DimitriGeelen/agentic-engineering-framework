---
id: T-2094
name: "V1-c fw upgrade: pre-flight tooling check + post-upgrade fw doctor advisory
  (T-2078 GO, closes F8/F10)"
description: >
  V1 slice from T-2078 GO. Closes F8, F10: upgrade.sh doesn't validate the host has
  required tooling before mutating, and doesn't suggest fw doctor after completion.
  Add pre-flight check (jq, python3, etc.) and post-upgrade advisory line. Spec: docs/reports/T-2078-fw-upgrade-reliability-review.md
  F8/F10. Sequence after V1-b.

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: [fw-upgrade, reliability, v1, T-2078-slice]
components: [lib/upgrade.sh]
related_tasks: [T-2078, T-2092]
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-29T11:58:34Z
last_update: '2026-08-16T22:24:53Z'
date_finished: 2026-06-06T20:18:54Z
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
  - ts: '2026-06-05T18:00:03Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-06T20:15:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-06-05T18:00:03Z'
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
  - ts: '2026-06-06T20:15:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 5
      F-RECALL: 2
      F-ORCH: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=5 (body:class-neutral); F-RECALL=2 (body:lightly-promoted); F-ORCH=0 
      (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:24:07Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 2
      D3: 0
      D4: 5
      F-RECALL: 2
      F-ORCH: 0
      F3: 0
      F1: 1
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=2 
      (body:telemetry-or-audit-entry); D3=0 (no-signal); D4=5 
      (body:class-neutral); F-RECALL=2 (body:lightly-promoted); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=1 
      (body/components:context-fabric-incidental); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:53Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 2
      D3: 0
      D4: 5
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 1
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=2 
      (body:telemetry-or-audit-entry); D3=0 (no-signal); D4=5 
      (body:class-neutral); F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0 
      (no-signal); F3=0 (no-signal); F1=1 
      (body/components:context-fabric-incidental); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2094: V1-c fw upgrade: pre-flight tooling check + post-upgrade fw doctor advisory (T-2078 GO, closes F8/F10)

## Context

V1-C slice of T-2078 GO. Closes F8 (no pre-flight tooling check — `fw upgrade` on a minimal LXC / Alpine container crashes mid-step on a missing `python3`/`git`/`diff`/`sed`/`mktemp` with no rollback) and F10 (no post-upgrade verification — `do_upgrade` prints "Upgrade Complete" without ever asking whether the consumer is healthy; first sign of "sideways" is the *next* operator action, by which point working memory is gone).

Spec: `docs/reports/T-2078-fw-upgrade-reliability-review.md` §F8 (line 146) and §F10 (line 162). Sequence after V1-B (T-2093, `failed_steps` + `--strict` + dry-run PARTIAL parity shipped). V1-C composes on that substrate: pre-flight aborts pre-mutation (no `failed_steps` involvement); the post-upgrade `fw doctor` advisory is non-blocking by spec ("doctor exit code does not affect upgrade success"), so it surfaces as a printed advisory rather than incrementing `failed_steps`.

## Acceptance Criteria

### Agent
- [x] **F8 — pre-flight tooling check loop in `lib/upgrade.sh:do_upgrade`** — Loop names `python3 git diff sed mktemp`; missing tool emits `ERROR: required tool missing: <cmd>` on stderr and returns 1. **Evidence:** `lib/upgrade.sh:202-220`; `grep "required tool missing" lib/upgrade.sh` → line 214.
- [x] **F8 — missing-tool path aborts before mutation** — Bats stubs PATH to omit `mktemp`; do_upgrade returns non-zero with diagnostic + "Aborting before any file mutation"; trip-wire do_vendor never fires. **Evidence:** `tests/unit/t2094_upgrade_preflight_doctor_advisory.bats:t3` PASS.
- [x] **F8 — happy path proceeds past pre-flight unchanged** — All 5 tools present; do_vendor stub fires AFTER pre-flight. **Evidence:** `t4` PASS, "do_vendor invoked AFTER pre-flight passed".
- [x] **F10 — post-upgrade `fw doctor` advisory invoked on live success** — Helper `_t2094_emit_doctor_advisory` runs `PROJECT_ROOT="$target_dir" "$FRAMEWORK_ROOT/bin/fw" doctor` and emits `Post-upgrade health check (advisory):` header. **Evidence:** call site `lib/upgrade.sh:1458` (inside `if [ "$changes" -gt 0 ]` of non-dry-run else); helper at `lib/upgrade.sh:1483-1513`; bats `t5` PASS.
- [x] **F10 — dry-run skips advisory** — Helper has exactly one call site, gated structurally on `changes > 0` inside the non-dry-run else branch. **Evidence:** structural `t8` PASS (`call_count == 1` and call line > `if [ "$changes" -gt 0 ]` line).
- [x] **F10 — doctor exit code is non-blocking** — Helper ends `return 0`; stubbed doctor exit 3 surfaces `doctor exited 3 — doctor exit code does not affect upgrade success` and helper still exits 0. **Evidence:** bats `t6` PASS.
- [x] **F10 — advisory runs in `target_dir` PROJECT_ROOT context** — Single line `PROJECT_ROOT="$target_dir" "$FRAMEWORK_ROOT/bin/fw" doctor` adjacency. **Evidence:** `lib/upgrade.sh:1503`; bats `t7` PASS.
- [x] **Bats suite passes** — `bats tests/unit/t2094_upgrade_preflight_doctor_advisory.bats` → 8/8 PASS on first run.
- [x] **Fresh-machine regression unaffected** — `bats tests/unit/upgrade_fresh_machine_simulation.bats` → 3/3 PASS; T-2093 6/6 PASS; T-2232 8/8 PASS — **25/25 PASS across the V1-ladder regression net**.
- [x] **Reviewer PASS** — `bin/fw reviewer T-2094 --no-write` → R-ceaa883a 2026-06-06T20:14:25Z, **Overall: PASS**, Findings: none, Needs Human: no.

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

# T-2094 verification commands:
# F8 structural — pre-flight loop names each required tool
grep -nE "required tool missing" lib/upgrade.sh
for cmd in python3 git diff sed mktemp; do grep -qE "\\b${cmd}\\b" lib/upgrade.sh || { echo "MISSING required-tool token: ${cmd}"; exit 1; }; done; echo "all 5 required tools named in lib/upgrade.sh"
# F10 structural — advisory runs in target_dir PROJECT_ROOT context
grep -nE 'PROJECT_ROOT="\$target_dir"' lib/upgrade.sh
grep -q "Post-upgrade health check" lib/upgrade.sh && echo "F10 advisory header present"
grep -q "doctor exit code does not affect upgrade success" lib/upgrade.sh && echo "F10 non-blocking semantic explicit"
# Bats suites
bats tests/unit/t2094_upgrade_preflight_doctor_advisory.bats
bats tests/unit/upgrade_fresh_machine_simulation.bats
# Reviewer (markdown output uses **Overall:** PASS — the .* between : and PASS/CONCERN absorbs the bold asterisks)
out=$(bin/fw reviewer T-2094 --no-write 2>&1); echo "$out" | grep -qE "Overall:.*(PASS|CONCERN)" && ! echo "$out" | grep -q "Overall:.*FAIL"

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

**Rationale:** V1-C closes both T-2078 §F8 (no pre-flight tooling check) and §F10 (no post-upgrade verification) in one slice, composes cleanly on the T-2093 V1-B substrate (`failed_steps` counter + `--strict` + dry-run PARTIAL parity, all in place), and ships with a complete regression-net (8 new bats + 17 across siblings, all PASS; reviewer PASS; fresh-machine simulation green under `env -i`). F8 is a pure pre-mutation guard; F10 is a non-blocking advisory by spec — neither changes existing success paths. The framework is now durable against the two field-failure classes T-2078 named as "the High and Medium correctness + observability fixes" for V1, and the next slice (V1-D, T-2095) is a refactor decoupled from this surface.

**Evidence:**
- **F8 implementation:** `lib/upgrade.sh:202-220` (pre-flight loop names `python3 git diff sed mktemp`, missing tool emits `ERROR: required tool missing: <cmd>` + `Aborting before any file mutation`, returns 1)
- **F10 implementation:** `lib/upgrade.sh:1457-1458` (call site inside `if [ "$changes" -gt 0 ]` of non-dry-run else) + `:1483-1513` (`_t2094_emit_doctor_advisory` helper — `PROJECT_ROOT="$target_dir" "$FRAMEWORK_ROOT/bin/fw" doctor`, awk single-stage trim+indent per L-387, explicit `return 0` for non-blocking)
- **New tests:** `tests/unit/t2094_upgrade_preflight_doctor_advisory.bats` — 8/8 PASS first run
- **Sibling regression:** T-2093 6/6 PASS, T-2232 8/8 PASS, fresh-machine 3/3 PASS — **25/25 across V1 ladder**
- **Reviewer:** R-ceaa883a — Overall: PASS, Findings: none, Needs Human: no
- **L-387 discipline:** awk reads-all-print-first-20 rather than `head -20 | sed` (no SIGPIPE risk on the upstream `echo "$_doctor_out"`)
- **Authority boundary:** PROJECT_ROOT override scopes doctor to the consumer's `.framework.yaml`, not the framework repo's — confirmed by `grep -nE 'PROJECT_ROOT="\$target_dir".*doctor' lib/upgrade.sh` → line 1503

**V1 ladder status after T-2094:**
- V1-A (F3): docker live-sim coverage — T-2092 SHIPPED
- V1-B (F4/F5/F6): exit-code discipline — T-2093 SHIPPED (this session, prior leg)
- **V1-C (F8/F10): pre-flight + post-upgrade advisory — T-2094 SHIPPED (this slice)**
- V1-D (F2): self-vendor extraction refactor — T-2095 captured + `horizon: now`
- T-2232 durable in-consumer upgrade fix — SHIPPED (out-of-ladder operator-directed slice; ring20-dashboard recovery awaits operator-call between Option A/B)

**What's next:** V1-D (T-2095) is the natural HV-LC follow-on (last V1 slice). After V1-D ships, V1 closes and V2 (F1+F13+F15 step-driver refactor) can be filed gated on V1 telemetry showing no field regression.

## Updates

### 2026-05-29T11:58:34Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2094-v1-c-fw-upgrade-pre-flight-tooling-check.md
- **Context:** Initial task creation

### 2026-06-06T13:27:33Z — status-update [task-update-agent]
- **Change:** horizon: later → now

### 2026-06-06T20:05:22Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-ea4cc30a
- **Timestamp:** 2026-06-06T20:19:05Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-06-06T20:18:54Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
