---
id: T-2267
name: "close web/ drift class — _self_vendor_web sibling (6th class)"
description: >
  T-2240 closure-arc 6th class. Audit (`agents/audit/audit.sh:1534`) scans
  `.agentic-framework/web/` recursively for `*.sh|*.py` files (70 candidates
  in source: web/app.py, web/blueprints/*.py, etc.). `fw vendor self`
  currently covers 5 classes (libs/templates/policy/bin via T-2095/T-2241/T-2263/T-2264
  + agents/ via T-2266). web/ is the 6th — same shape as T-2266 (recursive
  find for *.sh + *.py, mirror audit's filter exactly).

  Filed as sibling to T-2266 because both close drift classes the audit
  scans but `fw vendor self` doesn't cover. Order: T-2266 first (smaller
  surface, ~30 files), T-2267 second (~70 files). Either could land first
  on operator promotion; they're independent — no shared lib edits.

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: [lib-upgrade, bin-fw, agents-audit]
related_tasks: [T-2240, T-2241, T-2242, T-2244, T-2263, T-2264, T-2266]
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-06-08T15:21:13Z
last_update: '2026-06-11T22:24:13Z'
date_finished: 2026-06-08T19:05:50Z
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
  - ts: '2026-06-08T15:30:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 2
      effort: 8
    rationale: blast_radius=3 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-06-08T15:30:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 0
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=0
      (no-signal); D4=2 (body:env-class-handled); F-RECALL=0 (no-signal); 
      F-ORCH=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:24:13Z'
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
---

# T-2267: close web/ drift class — _self_vendor_web sibling (6th class)

## Context

T-2240 closure-arc 6th and final class (under the current audit drift-scan
shape). With T-2266 (agents/) and T-2267 (web/) shipped, `fw vendor self`
covers everything `check_self_vendor_drift()` scans, closing the libs-class
N×M product completely.

**Design references** (read these before starting):
- `agents/audit/audit.sh:1512-1571` — drift-scan logic (web/ included on
  the find line; *.sh + *.py filter).
- `lib/upgrade.sh:141-178` — `_self_vendor_libs()` baseline pattern.
- `lib/upgrade.sh:179-228` — `_self_vendor_templates()` sibling shape.
- `lib/upgrade.sh:229-281` — `_self_vendor_policy()` sibling shape.
- `lib/upgrade.sh:282-345` — `_self_vendor_shim()` sibling shape.
- `.tasks/active/T-2266-*.md` — sibling task (agents/) — same shape, same
  three-site wiring.

**Helper contract** (mirror T-2266's `_self_vendor_agents`):
- Source: `$FRAMEWORK_ROOT/web/`
- Target: `$FRAMEWORK_ROOT/.agentic-framework/web/`
- File filter: `*.sh -o -name "*.py"` (mirrors audit's pattern at line 1534)
- Recursive find (web/ has subdirs: blueprints/, templates/, static/ —
  but only *.py + *.sh matched; templates/static stay untouched here).
- Structural guard: early-return if `$FRAMEWORK_ROOT/.agentic-framework/web/`
  doesn't exist.
- Wording: `Self-vendor: would sync N web/ file(s)` / `synced N web/ file(s)`
  (same `would sync` prefix so T-2240 pre-push gate catches it on one regex).

**Three-site wiring (per T-2263 Evolution insight):**
1. `lib/upgrade.sh` — `_self_vendor_web()` helper + `do_upgrade()` call
   after `_self_vendor_agents`.
2. `bin/fw` — `vendor)` case — `_self_vendor_web "$_vs_dry"` after
   `_self_vendor_agents "$_vs_dry"`.
3. `bin/fw` — `--help` text — list `.agentic-framework/web/` as sixth class.

**Scope fence:**
- IN: helper, 3-site wiring, integration test, smoke test, reviewer PASS.
- OUT: web/templates/*.html, web/static/*.{css,js,svg,png} (separate class
  if filed — different drift profile; audit doesn't scan them today).
- OUT: web/blueprints subdirs filtering (vendor everything *.sh + *.py
  matches; mirror audit's filter exactly).

**Audit coverage parity** (the closure invariant): after T-2266+T-2267
land, the post-helper audit verdict should remain semantically identical
— same find pattern, same `cmp -s` shape, no audit-side changes. Helpers
just make `fw vendor self` cover everything `check_self_vendor_drift()`
already scans.

## Acceptance Criteria

### Agent
- [x] `_self_vendor_web()` helper exists in `lib/upgrade.sh`, mirrors
      `_self_vendor_agents` shape (dry-run/real-run split, structural guard,
      recursive *.sh + *.py filter)
- [x] `do_upgrade()` calls `_self_vendor_web "$dry_run"` after
      `_self_vendor_agents`
- [x] `bin/fw vendor)` case calls `_self_vendor_web "$_vs_dry"` after
      `_self_vendor_agents "$_vs_dry"`
- [x] `fw vendor self --help` lists `.agentic-framework/web/` as sixth
      sync class with `(T-2267)` annotation
- [x] Smoke test passes: with no drift, `fw vendor self --dry-run` is
      silent on web/; mutate `.agentic-framework/web/app.py` then
      `fw vendor self --dry-run` emits `Self-vendor: would sync 1 web/ file(s)`;
      `fw vendor self` (real-run) restores parity
- [x] After helper lands, `bin/fw audit` reports `Self-vendor drift:
      vendored .agentic-framework/ in sync with source` PASS (no FAIL on
      web/) — verifies coverage parity
- [x] T-2240 pre-push gate's `would sync` regex matches `_self_vendor_web`
      output (gate at `agents/git/lib/hooks.sh:679` — class-agnostic
      `would sync` regex catches web/ output by construction; verified
      live: mutate→fire→real-run→idempotent)
- [x] Integration test added: `tests/unit/t2267_self_vendor_web.bats`
      with at least 3 cases (helper-exists, dry-run-detects-drift,
      real-run-syncs)
- [x] `bin/fw reviewer T-2267` returns Overall PASS (override OV-3c8b2ee8
      applied for canonical `mock-only-integration` FP — same class as
      T-2266 OV-3fc5133e and prior siblings)

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
out=$(grep -c "^_self_vendor_web()" lib/upgrade.sh); test "$out" = "1"
grep -q "_self_vendor_web \"\$dry_run\"" lib/upgrade.sh
grep -q "_self_vendor_web \"\$_vs_dry\"" bin/fw
grep -q ".agentic-framework/web/" bin/fw
bats tests/unit/t2267_self_vendor_web.bats
out=$(bin/fw audit 2>&1); echo "$out" | grep -q "Self-vendor drift: vendored .agentic-framework/ in sync"
test "$(echo "$out" | grep -c "Self-vendor drift.*web class" || true)" = "0"
out=$(bin/fw reviewer T-2267 2>&1); echo "$out" | grep -qE "Overall:.*(PASS|CONCERN)"

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

**Rationale:** T-2240 closure-arc 6th and current-final class shipped, closing
the libs-class N×M product end-to-end. With T-2267 (web/) landing alongside
T-2266 (agents/), `fw vendor self` now covers everything
`check_self_vendor_drift()` scans at `agents/audit/audit.sh:1534`
(bin + lib + agents + web). Helper is mechanical sibling of
`_self_vendor_agents` — same recursive `*.sh + *.py` filter, same dry-run/
real-run split, same `would sync` prefix so T-2240's pre-push gate catches
web/ on the existing class-agnostic regex (no gate-side edit).

**Evidence:**
- `lib/upgrade.sh` — `_self_vendor_web()` helper + `do_upgrade()` 6th-sibling
  invocation.
- `bin/fw` — `vendor self --help` lists web/ class with `(T-2267)` annotation;
  `vendor)` case invokes the helper.
- `tests/unit/t2267_self_vendor_web.bats` — 7/7 PASS.
- Live smoke: mutate `.agentic-framework/web/app.py` → dry-run emits
  `would sync 1 web/ file(s)` → pre-push regex matches → real-run restores
  parity → idempotent on clean.
- `bin/fw audit` Self-vendor drift section PASSes after T-2267 (coverage
  parity verified).
- Reviewer Overall PASS with override OV-3c8b2ee8 for the canonical
  `mock-only-integration` FP on self-vendor bats suites.

**Next:** Closure-arc complete (6/6 classes: libs / templates / policy /
bin / agents / web). Future drift classes (e.g. web/templates/,
web/static/) would each be a separate task with its own design pass —
audit doesn't scan them today, so no current parity gap.

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

### 2026-06-08T15:21:13Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2267-close-web-drift-class--selfvendorweb-sib.md
- **Context:** Initial task creation

### 2026-06-08T15:23:49Z — status-update [task-update-agent]
- **Change:** horizon: now → later
- **Change:** status: started-work → captured (auto-sync)

### 2026-06-08T15:58:46Z — status-update [task-update-agent]
- **Change:** horizon: later → next

### 2026-06-08T18:49:08Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-55cdb206
- **Timestamp:** 2026-06-08T19:15:53Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

- **Suppressed:** 1 (by override)
  - mock-only-integration @ AC vs Verification cross-check

### 2026-06-08T19:05:50Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
