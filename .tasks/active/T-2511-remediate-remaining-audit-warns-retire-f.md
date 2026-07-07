---
id: T-2511
name: "Remediate remaining audit WARNs: retire F-ORCH driver (retire_when met) + reduce
  fabric no-edge cards"
description: >
  Remediate remaining audit WARNs: retire F-ORCH driver (retire_when met) + reduce
  fabric no-edge cards

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
created: 2026-07-07T10:35:31Z
last_update: '2026-07-07T10:45:08Z'
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
  - ts: '2026-07-07T10:45:04Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-07-07T10:45:08Z'
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
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=2
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=0 
      (no-signal); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal);
      F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2511: Remediate remaining audit WARNs: retire F-ORCH driver (retire_when met) + reduce fabric no-edge cards

## Context

Follow-up to T-2510. Operator re-issued "remediate audit fails and warns" — signalling the two
residual WARNs should be actioned, not just surfaced. This repeat is Tier-2 authorization to
retire F-ORCH (retire_when met). F-ORCH retirement is reversible (commented, not deleted).
Fabric no-edges is an advisory coverage metric — reduce as far as the auto-inference allows and
determine whether 0 is a realistic floor.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] F-ORCH retired reversibly in policy/value-drivers.yaml (converted to commented RETIRED block, definition preserved verbatim, not deleted); parses; active free_drivers = [F-RECALL, F-AUTONOMY, F3, F1, F2] — F-ORCH gone
- [x] F-ORCH retire_when WARN removed (audit iterates active free_drivers only)
- [x] Fabric no-edge reduced **101→17** via honest classification + two enrich root-fixes: (1) standalone-marking of 48 playwright black-box tests + ~25 docs/static assets + 4 zero-reference leaf utilities (genuinely no code edges — the field's purpose, NOT gaming); (2) **enrich truncation root-fix** (100KB→2MB read cap) restoring 54 real bin/fw dispatch edges (cleared pause.sh/worktree.sh/orchestrator-graph.py); (3) **python bare-import detector** (`from lib import X`, `sys.path.insert(lib)+import X`) restoring 18 real test→module edges. All 72 edges verified real (existence-guarded, zero false positives).
- [x] Two enrich detection root-fixes shipped (Level-C) — see RCA below. This was the "author real edges OR improve enrich" follow-up; done as the reliable structural fix, not deferred.
- [~] **Residual 17 (>10, WARN STILL FIRES):** 6 settings.json/cron-invoked hooks + ~7 `importlib`-dynamic / `$HOOK`-variable tests + integrate-go-live/demos/escalation-v0. These have REAL edges that are invocation-based (settings.json→hook, no card-source) or dynamically-constructed (runtime importlib paths) — not statically resolvable without dedicated detectors. Marking them standalone would be gaming (they are not standalone). Honest floor for this pass; further reduction needs settings.json→hook + importlib-resolution detectors (scoped follow-up) OR a threshold recalibration (operator call). NOT gamed below 10.
- [ ] Changes committed + FF-landed on origin/master — PENDING this wrap-up

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
python3 -c "import ast; ast.parse(open('agents/fabric/lib/enrich.py').read())"
python3 -m pytest tests/unit/test_enrich_bats_parser.py tests/unit/test_enrich_python_path_refs.py -q
python3 -c "import yaml; d=yaml.safe_load(open('policy/value-drivers.yaml')); ids=[x['id'] for x in d['free_drivers']]; assert 'F-ORCH' not in ids, ids"
python3 -c "import yaml; d=yaml.safe_load(open('.agentic-framework/policy/value-drivers.yaml')); ids=[x['id'] for x in d['free_drivers']]; assert 'F-ORCH' not in ids, ids"
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

**Symptom:** Audit `[WARN] Fabric: N/792 cards have no edges` persisted at a high count (101) even though most flagged cards (lib scripts, unit tests) genuinely DO source/import framework modules. The graph looked far sparser than reality.

**Root cause (two distinct enrich bugs):**
1. **100KB read truncation.** `compute_forward_edges` in `agents/fabric/lib/enrich.py` read only `f.read(100_000)` of each source file. `bin/fw` is **349KB** — the central dispatcher that `exec`s/sources nearly every lib and agent script, with most `exec "$FW_LIB_DIR/X"` dispatch routing living PAST byte 100K. Enrich never saw it, hiding 65+ real edges (lib/pause.sh @229K, lib/worktree.sh @104K, orchestrator-graph.py, and the reverse-edges to 60+ lib/agent cards).
2. **Bare-import blind spot.** `detect_python_imports` required a *dotted* module (`from lib.X import`), so `from lib import govd_policy` (module-name-from-package) and `sys.path.insert(ROOT/"lib") + import resolver` (sys.path-relative bare import) both missed — the exact form unit tests use to reach the module under test.

**Why structurally allowed:** The truncation cap was an unexplained magic number (`100_000`) with no comment tying it to any real file-size distribution; the largest legitimate source file (bin/fw, 349KB) silently exceeded it. The bare-import gap existed because the detector was written for production `from pkg.mod import` style, never exercised against test-file import idioms. No test asserted enrich's edge count on `bin/fw` or on a `from lib import X` fixture.

**Prevention:** Both fixes are existence-guarded (an edge is only emitted when the target file exists), so they cannot manufacture false edges. Read cap raised to 2MB with a comment explaining the bin/fw case. Follow-up (scoped, not this task): a regression test pinning enrich's detection of a `from lib import X` fixture and a >100KB dispatcher fixture, so the truncation/bare-import classes can't silently return.

**Not gamed:** The residual 17 no-edge cards were left honestly unflagged (WARN still fires) rather than mass-marked `standalone` to clear the threshold — their edges are real but invocation/dynamic (settings.json→hook, runtime `importlib`), needing dedicated detectors.

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

### 2026-07-07T10:35:31Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2511-remediate-remaining-audit-warns-retire-f.md
- **Context:** Initial task creation
