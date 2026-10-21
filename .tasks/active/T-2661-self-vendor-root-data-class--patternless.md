---
id: T-2661
name: "self-vendor root-data class + patternless sim tests (T-2656 follow-up)"
description: >
  T-2656 shipped do_vendor includes (.secret-scan-patterns/.secret-scan-allowlist)
  + loud patternless warning + direct mirror copy. Structural remainder: (1) _self_vendor_root_data()
  helper class in lib/upgrade.sh (siblings: libs/templates/policy/shim/agents/web)
  + audit check_self_vendor_drift parity so the mirrored data files cannot silently
  drift; (2) fresh-machine sim test 6 extension to script DATA files (patterns present
  in vendored tree) + test 7 present-but-patternless case (scanner runs, unmissable
  WARNING fires, FW_SECRET_SCAN_STRICT=1 blocks). GOTCHA: sim tests run against COMMITTED
  bytes — commit source before verifying. Interplay w/ T-2657: includes added here
  do not reach consumers via fw update until the chicken-and-egg re-exec lands.

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
created: 2026-07-28T11:51:29Z
last_update: 2026-10-21T07:00:25Z
date_finished:
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
  - ts: '2026-07-28T12:00:06Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-17T12:36:08Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 6
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=6 (lines=145,acs=4)
    rubric_sha: e4a00f38e801
  - ts: '2026-10-20T22:15:12Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=159,acs=8)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-07-28T12:00:09Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=0 
      (no-signal); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal);
      F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-10-20T22:15:11Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 2
      D4: 5
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=2
      (body:default-change); D4=5 (body:class-neutral); F-RECALL=0 (no-signal); 
      F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2661: self-vendor root-data class + patternless sim tests (T-2656 follow-up)

## Context

Reproduced at HEAD 1ff8ea451 (2026-10-21): `diff <(git show HEAD:.secret-scan-allowlist) <(git show HEAD:.agentic-framework/.secret-scan-allowlist)` → lines 101-113 (T-3040 block) missing from the mirror; `git show HEAD:lib/upgrade.sh | grep -c _self_vendor_root_data` → 0. The audit parity half had already landed, riding in 1731e3e2a (T-2680). Writing sim test 7 surfaced a second defect: the installed pre-commit hook swallowed the patternless WARNING (see RCA).

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] Reproduction checked at HEAD: whether root `.secret-scan-patterns`/`.secret-scan-allowlist` and their `.agentic-framework/` mirrors can drift with `fw vendor self --check` and `fw audit` silent
- [x] `lib/upgrade.sh` has a `_self_vendor_root_data` helper (sibling of `_self_vendor_libs` …) wired into `fw vendor self`, syncing both root data files; `--check` reports drift in them
- [x] `agents/audit/audit.sh check_self_vendor_drift` covers the same two root data files (parity)
- [ ] Regression bats `tests/unit/t2661_self_vendor_root_data.bats` fails without the fix and passes with it
- [ ] Fresh-machine sim: test asserting the vendored tree ships both data files, and a present-but-patternless case (scanner runs, WARNING fires, `FW_SECRET_SCAN_STRICT=1` blocks)
- [x] Installed pre-commit hook passes a passing scan's warning through to stderr (`agents/git/lib/hooks.sh`), so the patternless WARNING is not swallowed in the fail-open default
- [ ] `bin/fw vendor self --check --task T-2661` clean

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
bash -n lib/upgrade.sh && bash -n bin/fw && bash -n agents/audit/audit.sh
grep -q '^_self_vendor_root_data()' lib/upgrade.sh
bats tests/unit/t2661_self_vendor_root_data.bats
bats -f "T-2661" tests/unit/upgrade_fresh_machine_simulation.bats
cmp -s .secret-scan-allowlist .agentic-framework/.secret-scan-allowlist
grep -q 'T-2661: a passing scan can still carry a warning' agents/git/lib/hooks.sh
python3 tools/bats-dead-negation-lint.py tests/
bin/fw vendor self --check --task T-2661

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

## RCA

**Symptom:** `.agentic-framework/.secret-scan-allowlist` sat behind its root source (13 lines at HEAD 1ff8ea451, 666 bytes at filing), and `fw vendor self --check` stayed green. A consumer whose vendored scanner had no `.secret-scan-patterns` committed with no visible warning, even though T-2656 had added an "unmissable" one.

**Root cause:** (1) `do_vendor` ships four root single files (`.secret-scan-patterns`, `.secret-scan-allowlist`, `status-transitions.yaml`, `metrics.sh`), but every `_self_vendor_*` sibling in `lib/upgrade.sh` syncs a tree (libs/templates/policy/shim/agents/web/tools). None owned root files, so they were never synced or checked. (2) `agents/git/lib/hooks.sh:577`: the pre-commit hook captures the scanner with `_hits=$(… 2>&1)` and prints `$_hits` only when `_rc -ne 0`. T-2656's patternless warning goes to stderr with rc 0, so it was captured and dropped.

**Why structurally allowed:** the self-vendor check knows only the classes its helpers enumerate, so a file class with no helper reads as in sync. T-2656's tests called `_secret_scan_run_patterns` directly and never went through the installed hook, which is the only path that swallowed the warning.

**Prevention:** `_self_vendor_root_data` syncs the four files and reports drift with the siblings' "would sync" wording, which `--check` and the pre-push gate already parse. `check_self_vendor_drift` scans the same list. `t2661_self_vendor_root_data.bats` t5 pins that the audit and the helper list the same files. Two fresh-machine sim tests drive the *installed* hook against committed bytes: one checks the vendored tree ships the data files, the other that a patternless scanner WARNs in default mode and blocks under strict.

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

### 2026-07-28T11:51:29Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2661-self-vendor-root-data-class--patternless.md
- **Context:** Initial task creation

### 2026-10-20T22:06:05Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
