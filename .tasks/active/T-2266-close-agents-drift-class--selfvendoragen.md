---
id: T-2266
name: "close agents/ drift class — _self_vendor_agents sibling"
description: >
  T-2240 closure-arc 5th class. Audit (`agents/audit/audit.sh:1534`) scans
  `.agentic-framework/{bin,lib,agents,web}/` for libs-class drift, but
  `fw vendor self` only syncs bin+lib+templates+policy (T-2095/T-2241/T-2263/T-2264).
  Drift in vendored `agents/` would FAIL the daily audit but `fw vendor self`
  cannot fix it — mitigation pointer says "Run: fw vendor" (full consumer-direction
  vendor with different semantics). Add `_self_vendor_agents()` sibling so the
  T-2240 pre-push gate catches the class on the same "would sync" regex.

  Web/ is a separate 6th class (20M static assets, different shape — own design
  pass, separate task). agents/ first because (a) it's lib-like (*.sh + *.py),
  mirroring existing helper pattern; (b) it's smaller (1.6M); (c) it's higher
  drift risk because agent scripts are edited more frequently than web assets.

status: captured
workflow_type: build
owner: agent
horizon: later
tags: [closure-arc, self-vendor]
components: [lib-upgrade, bin-fw, agents-audit]
related_tasks: [T-2240, T-2241, T-2242, T-2244, T-2263, T-2264]
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-06-08T15:04:46Z
last_update: 2026-06-08T15:06:21Z
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

# T-2266: close agents/ drift class — _self_vendor_agents sibling

## Context

T-2240 closure-arc continues. The audit's `check_self_vendor_drift()`
(agents/audit/audit.sh:1512-1571) scans four subdirs of `.agentic-framework/`
for libs-class drift but `fw vendor self` only handles four classes
(libs/templates/policy/bin). agents/ is the 5th class.

**Design references** (read these before starting):
- `agents/audit/audit.sh:1512-1571` — `check_self_vendor_drift()` scans
  `.agentic-framework/{bin,lib,agents,web}` for `*.sh|*.py|fw` files.
  agents/ drift FAILs but mitigation points at full `fw vendor` (not `vendor self`).
- `lib/upgrade.sh:141-178` — `_self_vendor_libs()` source-of-truth pattern.
- `lib/upgrade.sh:179-228` — `_self_vendor_templates()` sibling shape (T-2241).
- `lib/upgrade.sh:229-281` — `_self_vendor_policy()` sibling shape (T-2263).
- `lib/upgrade.sh:282-345` — `_self_vendor_shim()` sibling shape (T-2264).
- `bin/fw:5889-5934` — `vendor)` case wiring (4 calls to mirror).
- T-2264 task body — three-site wiring discipline.

**Three-site wiring (per T-2263 Evolution insight):**
1. `lib/upgrade.sh` — `_self_vendor_agents()` helper definition + call inside
   `do_upgrade()` after `_self_vendor_shim` (line ~625-ish region).
2. `bin/fw` — `vendor)` case — add `_self_vendor_agents "$_vs_dry"` after
   `_self_vendor_shim "$_vs_dry"` (around line 5930).
3. `bin/fw` — `--help` text — list `.agentic-framework/agents/` as fifth class.

**Helper contract** (mirror `_self_vendor_libs` shape):
- Source: `$FRAMEWORK_ROOT/agents/`
- Target: `$FRAMEWORK_ROOT/.agentic-framework/agents/`
- File filter: `*.sh -o -name "*.py"` (matches audit's drift-scan pattern at line 1534)
- Structural guard: early-return if `$FRAMEWORK_ROOT/.agentic-framework/agents/`
  doesn't exist (consumer's vendored fw running `vendor self` has no nested
  vendored agents/).
- Dry-run wording: `Self-vendor: would sync N agents/ file(s)` (same prefix
  pattern as `Self-vendor: would sync N file(s)` so T-2240 pre-push gate's
  existing regex `would sync` catches it).
- Real-run wording: `Self-vendor: synced N agents/ file(s)`.

**Scope fence:**
- IN: `_self_vendor_agents()` helper, 3-site wiring (lib/upgrade.sh helper +
  do_upgrade call, bin/fw vendor case + --help), integration test for the
  new class, live smoke test (mutate-then-revert), reviewer PASS.
- OUT: web/ class (T-2267 sibling, separate task, 20M static-asset shape),
  filtering decisions beyond `*.sh + *.py` (mirror audit's filter exactly),
  agents/ subdirectory exclusions (vendor everything that audit scans).

**Audit coverage:** the post-T-2266 audit check should remain semantically
identical — same find pattern, same `cmp -s` shape, no audit-side changes.
Helper just makes `fw vendor self` cover what audit was already scanning.

## Acceptance Criteria

### Agent
- [ ] `_self_vendor_agents()` helper exists in `lib/upgrade.sh`, mirrors
      `_self_vendor_libs` shape (dry-run/real-run split, structural guard,
      explicit file filter)
- [ ] `do_upgrade()` calls `_self_vendor_agents "$dry_run"` after
      `_self_vendor_shim` (one-line addition matching the existing pattern)
- [ ] `bin/fw vendor)` case calls `_self_vendor_agents "$_vs_dry"` after
      `_self_vendor_shim "$_vs_dry"` (line ~5930)
- [ ] `fw vendor self --help` lists `.agentic-framework/agents/` as fifth
      sync class with `(T-2266)` annotation
- [ ] Smoke test passes: with no drift, `fw vendor self --dry-run` is silent
      on agents/; mutate `.agentic-framework/agents/audit/audit.sh` then
      `fw vendor self --dry-run` emits `Self-vendor: would sync 1 agents/ file(s)`;
      `fw vendor self` (real-run) restores parity
- [ ] After helper lands, `bin/fw audit` reports `Self-vendor drift: vendored
      .agentic-framework/ in sync with source (libs + templates)` PASS
      (no FAIL on agents/) — verifies coverage parity
- [ ] T-2240 pre-push gate's `would sync` regex matches `_self_vendor_agents`
      output (verify by running `agents/git/pre-push-self-vendor-check.sh`
      in dry-run mode with a mutated agents/ file)
- [ ] Integration test added: `tests/unit/t2266_self_vendor_agents.bats`
      with at least 3 cases (helper-exists, dry-run-detects-drift,
      real-run-syncs)
- [ ] `bin/fw reviewer T-2266` returns Overall PASS

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
out=$(grep -c "^_self_vendor_agents()" lib/upgrade.sh); test "$out" = "1"
grep -q "_self_vendor_agents \"\$dry_run\"" lib/upgrade.sh
grep -q "_self_vendor_agents \"\$_vs_dry\"" bin/fw
grep -q ".agentic-framework/agents/" bin/fw
bats tests/unit/t2266_self_vendor_agents.bats
out=$(bin/fw audit 2>&1); echo "$out" | grep -q "Self-vendor drift: vendored .agentic-framework/ in sync"
test "$(echo "$out" | grep -c "Self-vendor drift.*agents class" || true)" = "0"
out=$(bin/fw reviewer T-2266 2>&1); echo "$out" | grep -qE "Overall:.*(PASS|CONCERN)"

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

### 2026-06-08T15:04:46Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2266-close-agents-drift-class--selfvendoragen.md
- **Context:** Initial task creation

### 2026-06-08T15:06:21Z — status-update [task-update-agent]
- **Change:** horizon: now → later
- **Change:** status: started-work → captured (auto-sync)
