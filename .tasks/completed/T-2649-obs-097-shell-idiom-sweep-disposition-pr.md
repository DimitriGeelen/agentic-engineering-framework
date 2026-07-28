---
id: T-2649
name: "OBS-097 shell-idiom sweep: disposition PROJECT_ROOT resolution of framework assets in shell (bin/fw, agents/, lib/)"
description: >
  OBS-097 shell-idiom sweep: disposition PROJECT_ROOT resolution of framework assets in shell (bin/fw, agents/, lib/)

status: work-completed
workflow_type: build
owner: agent
horizon: null
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
created: 2026-07-28T08:32:10Z
last_update: 2026-07-28T08:38:23Z
date_finished: 2026-07-28T08:38:23Z
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

# T-2649: OBS-097 shell-idiom sweep: disposition PROJECT_ROOT resolution of framework assets in shell (bin/fw, agents/, lib/)

## Context

Shell-idiom leg of OBS-097 (T-2648 shipped the Python lint). Survey found 23
sites resolving framework-owned dirs (lib/agents/policy/web) via
$PROJECT_ROOT in shell (bin/fw, agents/, lib/*.sh). In split-root consumers
PROJECT_ROOT is the consumer root, so these paths dangle — some sites are
real defects on the designer/govd seams (bin/fw designer pin, govd_policy.py
invocations), others are deliberate fallback chains or per-project policy
instances (T-2229 model). This task dispositions all 23 and fixes the
confirmed defects. A shell variant of the audit lint is explicitly OUT of
scope (calibration first — this sweep IS the calibration).

## Acceptance Criteria

### Agent
- [x] All 23 surveyed shell sites dispositioned in the task Decisions section: fixed to FRAMEWORK_ROOT, kept-with-reason (fallback chain / per-project instance / cosmetic), with file:line each
- [x] Confirmed defects fixed and the touched fw verbs smoke-tested live (designer pin read, govd status, mcp manifest path)
- [x] Re-run of the survey grep shows only kept-with-reason sites remain
- [x] OBS-097 concern entry updated: shell leg calibrated (sweep done), lint-for-shell disposition recorded

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

bash -n bin/fw && bash -n agents/designer/designer.sh && bash -n agents/monitor/liveness-check.sh && bash -n lib/arc.sh
bin/fw policy emit > /dev/null
rc=0; bin/fw mcp check > /dev/null || rc=$?; test "$rc" = "0"
out=$(bin/fw mcp wire-fragment 2>&1); echo "$out" | grep -q '"fw"'
out=$(bash agents/designer/designer.sh status 2>&1); echo "$out" | grep -q "sha256"
n=$(grep -rnE '\$\{?PROJECT_ROOT\}?/(lib|agents|policy|web)/' agents/ lib/*.sh bin/fw 2>/dev/null | grep -v ".agentic-framework" | grep -cv "FRAMEWORK_ROOT:-"); test "$n" = "12"

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

### 2026-07-28 — Full disposition of the 23 surveyed sites (+1 found during fix)

**Fixed — hard FRAMEWORK_ROOT (framework-owned asset, PROJECT_ROOT dangles in split-root):**
- bin/fw:2489/2492/2508 (now ~2493+) — `fw policy emit|status|install` invoked `$PROJECT_ROOT/lib/govd_policy.py` with `PYTHONPATH=$PROJECT_ROOT`; consumer `fw policy status` would crash. → FRAMEWORK_ROOT both.
- bin/fw:1496 (doctor proxy-policy drift, NOT in the original 23 — same defect found while fixing) — `PYTHONPATH=$PROJECT_ROOT` import of lib.govd_policy → FRAMEWORK_ROOT.
- bin/fw:5088 — `_mcp_manifest=$PROJECT_ROOT/agents/mcp/...json` but manifest.py emits relative to framework_root() (T-2459): producer/consumer path mismatch in split-root. → `$AGENTS_DIR/mcp/...`.
- bin/fw:5110 — mcp wire-fragment read same mismatch → `$AGENTS_DIR/mcp/...`.

**Fixed — FRAMEWORK_ROOT-first fallback shape (`${FRAMEWORK_ROOT:-$PROJECT_ROOT}`), safe under direct invocation:**
- agents/designer/designer.sh:29 — PIN_FILE (pin is framework-owned, vendored; consumer read dangled).
- agents/designer/designer.sh:310/312 — lib/notify.sh source (silent notify loss in consumers).
- agents/monitor/liveness-check.sh:57/59 — lib/config.sh source (silent FW_PORT loss → wrong :3000 fallback in consumers).
- lib/arc.sh:590 — update-task.sh resolution (consumers silently dropped to the inline-python fallback, skipping update-task guard rails); also switched relative `./agents/...` invocation to absolute path.

**Kept with reason (12 remaining survey hits):**
- agents/git/lib/hooks.sh:752 + agents/audit/audit.sh:4894 — `[ -x $PROJECT_ROOT/bin/fw ] && [ -f $PROJECT_ROOT/agents/mcp/manifest.py ]` IS the framework-repo detection (documented "framework repo only"); consumers deliberately skip.
- agents/git/lib/hooks.sh:786/798/799/809 — documented 3-tier audit-script fallback chain (T-1396): framework_path → PROJECT_ROOT source-of-truth → vendored; PROJECT_ROOT leg is the framework-repo case by design (809 is the error message).
- agents/handover/handover.sh:1088/1089 — already the correct FRAMEWORK_ROOT-first chain; PROJECT_ROOT is the explicit fallback leg.
- agents/audit/audit.sh:834 — value-drivers.yaml is a PER-PROJECT policy instance (T-2229 --init model); PROJECT_ROOT correct.
- bin/fw:1467 — designer-pin doctor check: comment documents deliberate PROJECT_ROOT + graceful consumer SKIP (T-2547); flipping it is a design change, not a bug fix.
- bin/fw:1492/2486 — proxy-policy.yaml SOURCE is per-project governance state (AEF_PROXY_POLICY override + `-f` guard); only the lib/ interpreter path was the bug (fixed above).

**Shell lint disposition:** NOT built. Calibration verdict: 12/23 legitimate sites with 4 distinct keep-reasons (repo-detection guards, documented fallback chains, per-project instances, documented design choices) — a grep-shape lint would need per-site annotations on majority-legitimate hits, inverting the signal/noise of the Python lint (where 8/11 were violations). The LIVE ratchet is a permanent bats test (tests/unit/audit_split_root_asset_lint.bats, "shell-idiom ratchet"): baseline count 12 pinned against the real repo — a NEW unreviewed site bumps the count and fails the suite; the ## Verification copy of the grep is the completion-time check only. Recorded in OBS-097.

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-07-28T08:32:10Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2649-obs-097-shell-idiom-sweep-disposition-pr.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-cd31ad2c
- **Timestamp:** 2026-07-28T08:38:25Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **empty-output-success** (partial, heuristic) @ Verification:line 33
     - evidence: `bin/fw policy emit > /dev/null`

### 2026-07-28T08:38:23Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
