---
id: T-2502
name: "Vendored claude-fw drift uncovered — audit filter + vendor-self helper parity
  (sibling of T-2501)"
description: >
  Sibling of T-2501. In-repo vendored .agentic-framework/bin/claude-fw drifts undetected:
  check_self_vendor_drift (audit.sh:1698) filter excludes claude-fw, and fw vendor
  self _self_vendor_shim (lib/upgrade.sh) syncs bin/fw only. Ship filter widen + helper
  extend TOGETHER (L-399 parity, L-491 unresolvable-block avoidance).

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [C-004, lib/upgrade.sh]
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
created: 2026-06-25T13:06:11Z
last_update: '2026-08-16T22:25:08Z'
date_finished: 2026-07-01T10:09:38Z
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
  - ts: '2026-08-16T22:25:08Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 2
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 1
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=2
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=0 
      (no-signal); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal);
      F2=1 (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
---

# T-2502: Vendored claude-fw drift uncovered — audit filter + vendor-self helper parity (sibling of T-2501)

## Context

Sibling of T-2501. T-2501 shipped on-PATH wrapper drift detection in `fw doctor` (operator-facing copy). This task closes the *in-repo vendored* leg: `agents/audit/audit.sh:1698` `check_self_vendor_drift` uses a find filter `-name "*.sh" -o "*.py" -o "fw" -o "*.md"` that matches `bin/fw` (name `fw`) but NOT `claude-fw` (extensionless, name≠`fw`); and `lib/upgrade.sh:325` `_self_vendor_shim` hard-syncs only `bin/fw`. So the vendored `.agentic-framework/bin/claude-fw` can drift undetected AND has no sync path. Fix both TOGETHER (L-399: widening the audit filter alone would FAIL with nothing to clear via `fw vendor self`).

## Acceptance Criteria

### Agent
- [x] `_self_vendor_shim` (lib/upgrade.sh) syncs `claude-fw` in addition to `fw` — both bin shims mirror source, with dry-run/real-run parity and an accurate file count in the `would sync`/`synced` message
- [x] `check_self_vendor_drift` find filter (agents/audit/audit.sh) includes `-name "claude-fw"` so vendored `.agentic-framework/bin/claude-fw` drift is detected (parity with the helper that now syncs it)
- [x] After `bin/fw vendor self`, `.agentic-framework/bin/claude-fw` is byte-identical to `bin/claude-fw` (`cmp -s`)
- [x] `bin/fw audit` self-vendor drift check PASSES (no FAIL) after sync — filter+helper parity holds end-to-end; negative test (re-inject drift) now produces a FAIL that pre-fix was invisible
- [x] `bash -n lib/upgrade.sh && bash -n agents/audit/audit.sh` clean (no syntax regression)

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

bash -n lib/upgrade.sh
bash -n agents/audit/audit.sh
bin/fw vendor self >/dev/null 2>&1; cmp -s bin/claude-fw .agentic-framework/bin/claude-fw
# here-string (not `echo|grep`) — audit output is large; grep -q matches early and
# SIGPIPEs the writer under set -eo pipefail (L-387/T-2090, exit 141). No pipe = no SIGPIPE.
out=$(bin/fw audit 2>&1); grep -q "Self-vendor drift: vendored .agentic-framework/ in sync" <<<"$out"
grep -q 'name "claude-fw"' agents/audit/audit.sh

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

## RCA

**Symptom:** The vendored `.agentic-framework/bin/claude-fw` was stale (14453 bytes, dated Jun 18) while source `bin/claude-fw` (14971 bytes, dated Jun 25) carried the T-2499 supervision export. Both are git-tracked, yet no framework surface flagged the divergence and `fw vendor self` could not repair it.

**Root cause:** Two coupled omissions, both keyed on `claude-fw`'s file *shape* (extensionless, basename ≠ `fw`):
1. `agents/audit/audit.sh:check_self_vendor_drift` find filter matched `*.sh -o *.py -o "fw" -o *.md` — `claude-fw` matches none (not an extension, and the literal `-name "fw"` is an exact match, not a prefix). So drift in the vendored wrapper was structurally invisible to the audit's drift check.
2. `lib/upgrade.sh:_self_vendor_shim` hard-coded a single `bin/fw` src→dst pair, so `fw vendor self` never touched `claude-fw` — no sync path existed.

**Why structurally allowed:** The self-vendor detect+repair pair (T-2264 shim helper, T-2244 audit check) was authored when `bin/fw` was the *only* executable shim. `claude-fw` (the auto-restart wrapper, T-179) was added later and vendored into git once, but neither the detector's filter nor the repair helper was widened to include it. The two surfaces share the same blind spot — a filter that enumerates known names rather than "every tracked executable under bin/" — so nothing caught the omission. Sibling of T-2501, which fixed the *on-PATH* wrapper drift (`fw doctor`); this fixes the *in-repo vendored* copy.

**Prevention:** (a) Filter widened to include `-name "claude-fw"` so future vendored-wrapper drift FAILs the audit — proven by the negative test (re-injected drift → FAIL). (b) `_self_vendor_shim` now iterates `for _shim in fw claude-fw`, so `fw vendor self` repairs any future drift — the FAIL is now clearable (L-399 producer/consumer parity: detector and repairer widened in the same commit). (c) Both edits self-vendored in the same commit so the vendored audit/upgrade copies also carry the fix.

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

### 2026-06-25T13:06:11Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.claude/worktrees/inception-gov-payload-mediation/.tasks/active/T-2502-vendored-claude-fw-drift-uncovered--audi.md
- **Context:** Initial task creation

### 2026-07-01T09:42:19Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: later → now (auto-sync)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-396198cd
- **Timestamp:** 2026-07-01T10:17:06Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-07-01T10:09:38Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
