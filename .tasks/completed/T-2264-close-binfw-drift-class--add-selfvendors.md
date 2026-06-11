---
id: T-2264
name: "Close bin/fw drift class — add _self_vendor_shim sibling to T-2240 gate"
description: >
  T-2240 closure-arc 4th class: bin/fw shim drift. T-2240+T-2241+T-2263 closed
  drift for lib/, .tasks/templates/, and policy/ respectively — all three caught
  by the same pre-push regex (`would sync`). bin/fw itself is not covered: when
  a developer edits bin/fw without re-vendoring, the pre-push gate stays silent
  and consumers vendoring from origin inherit the stale shim. Same shape sibling
  fix: `_self_vendor_shim()` helper, wired into `do_upgrade` and `bin/fw vendor)`.

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: [self-vendor-drift, t2240-closure-arc]
components: [lib-upgrade, fw-shim]
related_tasks: [T-2240, T-2241, T-2242, T-2263]
created: 2026-06-08T14:19:34Z
last_update: '2026-06-11T22:24:13Z'
date_finished: 2026-06-08T14:22:16Z
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
  - ts: '2026-06-11T22:24:13Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
      F3: 1
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal); F3=1 (body/components:prompt-incidental); F1=0 (no-signal); 
      F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2264: Close bin/fw drift class — add _self_vendor_shim sibling to T-2240 gate

## Context

Observed during T-2263 (Slice 2C) close: `git diff bin/fw .agentic-framework/bin/fw`
showed 13 lines of drift after I edited bin/fw to wire `_self_vendor_policy()`
into the `vendor)` case. The push proceeded — T-2240's pre-push gate didn't see
bin/fw drift because `_self_vendor_libs` covers `lib/*.sh`, `_self_vendor_templates`
covers `.tasks/templates/`, and `_self_vendor_policy` covers `policy/{value-drivers,bvp-scoring-rubric}`.
None cover bin/fw.

Fourth-class fix matches the pattern proven by T-2263:
- Add `_self_vendor_shim()` helper (sibling shape).
- Wire into `do_upgrade` (line ~575) AND `bin/fw vendor)` case (line ~5921).
- Update `fw vendor self --help` text to list bin/fw as fourth sync class.
- T-2240 gate's existing regex (`would sync`) catches this for free.

NOT covering agents/ in this slice — that's a larger surface (~30 directories,
many subprocess invocations) that needs its own design pass. This slice closes
ONLY the bin/fw single-file class.

## Acceptance Criteria

### Agent
- [x] `lib/upgrade.sh` defines `_self_vendor_shim()` (sibling of `_self_vendor_libs` / `_self_vendor_templates` / `_self_vendor_policy`)
- [x] `_self_vendor_shim()` syncs `bin/fw` from `$FRAMEWORK_ROOT/bin/fw` to `$FRAMEWORK_ROOT/.agentic-framework/bin/fw` when missing or differing
- [x] `_self_vendor_shim()` preserves executable permission on the destination (`chmod +x` matching the source)
- [x] `_self_vendor_shim()` honours `dry_run`: dry-run emits `Self-vendor: would sync 1 file(s) to .agentic-framework/bin/`; real-run emits `Self-vendor: synced 1 ...`
- [x] `do_upgrade()` invokes `_self_vendor_shim "$dry_run"` after the existing self-vendor calls
- [x] `bin/fw vendor)` case invokes `_self_vendor_shim "$_vs_dry"` after the existing self-vendor calls
- [x] `fw vendor self --help` lists `.agentic-framework/bin/` as a fourth sync class
- [x] After `bin/fw vendor self`, vendored bin/fw is byte-identical to source bin/fw (`diff -q` returns clean)
- [x] Mutating `bin/fw` (then reverting) causes `bin/fw vendor self --dry-run` to report exactly one `would sync 1 file(s) to .agentic-framework/bin/` line — proving the T-2240 pre-push gate sees bin/fw drift
- [x] `fw reviewer T-2264` returns Overall PASS

<!-- No Human section: all ACs above are deterministic / shell-verifiable. -->

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

# --- T-2264 ACs ---
grep -q "_self_vendor_shim" lib/upgrade.sh
grep -q "would sync .* to .agentic-framework/bin/" lib/upgrade.sh
grep -q "_self_vendor_shim" bin/fw
grep -q ".agentic-framework/bin/" bin/fw
diff -q bin/fw .agentic-framework/bin/fw
test -x .agentic-framework/bin/fw
out=$(bin/fw vendor self --dry-run 2>&1); test "$(echo "$out" | grep -c "would sync" || true)" = "0"
TMP_FILE=$(mktemp -p /tmp fw-t2264-mutate-XXXXXX); cp bin/fw "$TMP_FILE"; echo "# T-2264 smoke mutation" >> bin/fw; out=$(bin/fw vendor self --dry-run 2>&1); cp "$TMP_FILE" bin/fw; echo "$out" | grep -qE "would sync 1 file\(s\) to .agentic-framework/bin/"
out=$(bin/fw reviewer T-2264 --no-write 2>&1); echo "$out" | grep -qE "Overall:.*(PASS|CONCERN)" && ! echo "$out" | grep -q "Overall:.*FAIL"

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

### 2026-06-08T14:19:34Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2264-close-binfw-drift-class--add-selfvendors.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-2a55af85
- **Timestamp:** 2026-06-08T14:22:17Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-06-08T14:22:16Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
