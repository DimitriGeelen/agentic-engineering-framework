---
id: T-2436
name: "self-vendor drift sync + --check silent-mutation trap (OBS-076)"
description: >
  self-vendor drift sync + --check silent-mutation trap (OBS-076)

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
# demo_target: true               # T-2286: optional — marks task as reserved for an orchestrated demo
#                                 # worker (e.g. arc-010 HM-A dispatches via mcp__fw__work_on). When set,
#                                 # `fw work-on T-XXX` refuses unless --i-am-demo-orchestrator (CLI) or
#                                 # FW_I_AM_DEMO_ORCHESTRATOR=1 (env) is passed. Prevents the parent
#                                 # session from consuming the captured→started-work transition the demo
#                                 # worker expects to drive. Origin OBS-057.
created: 2026-06-18T22:29:00Z
last_update: 2026-06-18T22:29:00Z
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

# T-2436: self-vendor drift sync + --check silent-mutation trap (OBS-076)

## Context

T-B of the worktree pre-push audit remediation (sibling of T-2435/T-A, OBS-077). The 3rd/last worktree-push-blocking audit FAIL was the T-2244 self-vendor drift check. Diagnosis split it into two real defects:

1. **Real drift** — my T-2435 source edits (`lib/paths.sh`, `bin/fw`, `agents/audit/audit.sh`) were never propagated to the vendored `.agentic-framework/` copy, so the audit correctly FAILed. Fix: `fw vendor self` + commit the vendored sync.
2. **`--check` silent-mutation trap** — `fw vendor self --check` accepted `--check` but matched neither `--dry-run` nor a real flag, falling through to a REAL mutating sync that exited 0. A caller running `--check` to *verify* actually *mutated* the vendored tree and saw a misleading "clean". This is the OBS-076 "audit and `vendor self --check` disagree": `--check` made it clean (uncommitted) then reported clean. Fix: `--check` → read-only dry-run that exits non-zero on drift.
3. **Stale audit recommendation** — the libs-class FAIL recommended full `fw vendor` on the (T-2247) premise that `fw vendor self` only syncs `lib/`. That premise went stale at T-2264/T-2266/T-2267 when `vendor self` was extended to bin+agents+web. Corrected to recommend `fw vendor self` (+ `--check` to verify).

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] Real drift synced: `fw vendor self` propagated `lib/paths.sh` + `bin/fw` + `agents/audit/audit.sh` to `.agentic-framework/`; `fw vendor self --check` exits 0 (in sync)
- [x] `bin/fw` `vendor self --check` is read-only (dry-run mode) and exits non-zero when any class is out of sync; `--dry-run` keeps its prior exit-0 semantics
- [x] Stale T-2247 audit recommendation corrected: libs-class FAIL recommends `fw vendor self` (now full-scope), not bare `fw vendor`; comment records the T-2436 correction
- [x] Tests: `tests/unit/t2436_vendor_self_check.bats` (5 tests — static routing + no-mutation + exit-code-agrees-with-dry-run + help) green; `tests/unit/t2247_*.bats` updated to corrected premise (3 green)
- [x] `bash -n` clean on `bin/fw` + `agents/audit/audit.sh`; worktree `fw audit` shows zero FAIL (self-vendor PASS, cron INFO-skipped from T-2435)

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

bash -n bin/fw
bash -n agents/audit/audit.sh
bash -n lib/paths.sh
out=$(bin/fw vendor self --check 2>&1); echo "$out" | grep -q "in sync with source"
grep -q "fw vendor self  (syncs all vendored .agentic-framework/ classes" agents/audit/audit.sh
bats tests/unit/t2436_vendor_self_check.bats
bats tests/unit/t2247_audit_self_vendor_mitigation.bats

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

**Symptom:** `git push` from a git worktree was blocked by an audit FAIL "Self-vendor drift: libs class". A prior session ran `fw vendor self --check` to verify, saw exit 0 ("clean"), yet the audit kept FAILing — "they disagree".

**Root cause (two joined defects):**
1. The vendored `.agentic-framework/` copy genuinely lagged the source (`lib/paths.sh`/`bin/fw`/`agents/audit/audit.sh` edited in T-2435 but never re-vendored). The audit was *correct*.
2. `fw vendor self --check` was not a verifier. The `vendor self` routing in `bin/fw` mapped only `--dry-run` to read-only mode; `--check` matched no case and fell through to `_vs_dry=false` → a **real mutating sync** that exited 0. So `--check` *made the tree clean* (uncommitted) and then reported "clean" — a self-fulfilling false negative. That is why it "disagreed" with the audit: the audit measured committed state; `--check` silently mutated the working tree and measured its own side effect.

**Why structurally allowed:** a flag named `--check` carries a read-only contract by convention (cf. `black --check`, `gofmt -l`). The routing silently accepted unknown flags and defaulted to mutate-mode, so a verification verb became a mutation verb with no error. Compounding it, the audit's fix recommendation ("Run: fw vendor") and its explanatory comment encoded a scope premise ("`fw vendor self` only syncs lib/") that went stale three tasks earlier (T-2264/T-2266/T-2267 extended `vendor self` to bin+agents+web) — so even an operator following the audit verbatim would not converge on the canonical verb.

**Prevention:**
- `tests/unit/t2436_vendor_self_check.bats` pins the read-only contract: `--check` never mutates the vendored tree (git-status before==after) and its exit code agrees with `--dry-run` drift state. A regression that re-introduces mutate-on-check fails t3/t4.
- `tests/unit/t2247_*.bats` updated so the audit recommendation can't silently drift back to the stale "lib-only" premise.
- The `--check` verifier itself is now the structural reconciliation point: audit FAIL ⇔ `fw vendor self --check` exit 1, with the FAIL recommending exactly that verify command. The sibling keystone (T-C) generalises content-vs-environment gating; self-vendor is *content* drift and correctly stays a FAIL (only cron, host-environment, was worktree-skipped in T-2435).

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

### 2026-06-18T22:29:00Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.claude/worktrees/inception-gov-payload-mediation/.tasks/active/T-2436-self-vendor-drift-sync----check-silent-m.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-74aaee10
- **Timestamp:** 2026-06-18T22:41:21Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
