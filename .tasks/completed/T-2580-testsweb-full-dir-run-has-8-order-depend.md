---
id: T-2580
name: "tests/web full-dir run has 8 order-dependent failures (all inception decide/verdict/rationale
  tests) — each passes in isolation; reproduced WITHOUT the T-2574/T-2575 new test
  files, so pre-existing state leak (likely shared web.app config/monkeypatch bleed
  between files). Fix = isolate the leaking fixture, not the failing tests."
description: >
  Promoted from observation OBS-094

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: [bug, testing]
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
created: 2026-07-21T05:42:12Z
last_update: '2026-08-16T22:25:10Z'
date_finished: 2026-07-21T05:54:49Z
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
  - ts: '2026-07-21T05:42:25Z'
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
  - ts: '2026-08-16T22:25:10Z'
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
      F2: 1
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=0 
      (no-signal); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal);
      F2=1 (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-07-21T05:45:06Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2580: tests/web full-dir run has 8 order-dependent failures (all inception decide/verdict/rationale tests) — each passes in isolation; reproduced WITHOUT the T-2574/T-2575 new test files, so pre-existing state leak (likely shared web.app config/monkeypatch bleed between files). Fix = isolate the leaking fixture, not the failing tests.

## Context

Full-dir `pytest tests/web` shows 8 order-dependent failures (inception decide/verdict/rationale tests) that each pass in isolation. Reproduced without the T-2574/T-2575 designer test files, so the leak pre-dates them — likely shared `web.app` module state or monkeypatch bleed between files. This noise forced repeated "is this my regression?" re-runs during the T-2571/T-2579 designer seam work. Fix the leaking fixture, not the failing tests (OBS-094).

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] Root cause of the cross-file state leak identified and named in ## RCA (which fixture/module state bleeds, from which file to which)
- [x] Fix isolates the leaking state at its source (shared conftest repair fixture) — none of the failing tests are weakened or skipped
- [x] The order-dependent class is cured: the 4 TemplateNotFound verdict-render failures pass full-dir; the full-dir failure set reduces to exactly the 4 standalone (non-order-dependent) failures, identical across two consecutive runs
- [x] The 4 residual standalone failures are proven NOT order-dependent (fail alone on clean tree) and are filed as their own tasks per "one bug = one task" (NO_GO verdict-regex regression; stale T-2051/T-2026 test pins)
- [x] The five leaker files (build_ambient, fabric_loader, load_latest_audit, secret_key, project_root_discovery) still pass alone and full-dir

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

# Leak reproduction: leaker files run alphabetically before verdict_render; before
# the conftest fix this exact invocation failed with TemplateNotFound. Deselects
# the one standalone (non-order-dependent) failure filed separately.
timeout 300 python3 -m pytest tests/web/test_build_ambient.py tests/web/test_fabric_loader.py tests/web/test_load_latest_audit.py tests/web/test_secret_key.py tests/web/test_project_root_discovery.py tests/web/test_inception_verdict_render.py -q --deselect tests/web/test_inception_verdict_render.py::test_inception_card_badge_colour_matches_verdict > /tmp/.t2580-verify.txt 2>&1
grep -q " passed" /tmp/.t2580-verify.txt
! grep -q "failed" /tmp/.t2580-verify.txt

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

**Symptom:** Full-dir `pytest tests/web` failed 8 inception decide/verdict/rationale tests; 4 of them passed in isolation (TemplateNotFound: `_approvals_content.html` for a template that exists on disk).

**Root cause:** Five test files (test_build_ambient, test_fabric_loader, test_load_latest_audit, test_secret_key, test_project_root_discovery) reload or `sys.modules.pop` `web.shared` (± `web.config`/`web.app`) under a tmp `PROJECT_ROOT` to exercise module-level root resolution. `monkeypatch.setenv` restores the *env var* at teardown but nothing restores the *module constant* — `web.shared.PROJECT_ROOT` keeps pointing at the (deleted) tmp dir for every later file. Any test that lazily builds paths from it (test_inception_verdict_render constructs a Flask `template_folder` from `web.shared.PROJECT_ROOT` at call time) then fails.

**Why structurally allowed:** monkeypatch's teardown contract covers attributes and env it set itself; a reload creates *new* module state monkeypatch never saw. No shared conftest owned cross-file module hygiene, so each file's cleanup ended at its own env vars. The damage lands in *other* files, so per-file review never sees it.

**Prevention:** `tests/web/conftest.py` autouse fixture `_restore_web_shared_root` — snapshots `PROJECT_ROOT` env before each test; at teardown restores it and, if `web.shared.PROJECT_ROOT` drifted from what the restored env resolves to, reloads `web.config` + `web.shared` **in place** (identity-preserving, so monkeypatch targets elsewhere stay coherent). Fires only on drift — zero cost for the ~96 clean tests. Additional finding: the other 4 of the 8 are NOT order-dependent (fail alone on clean tree) — filed separately per one-bug-one-task (NO_GO verdict-regex regression from T-1575 consolidation; 3 stale test pins from T-2051 htmx-200 and T-2026 semantic-token changes).

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

### 2026-07-21 — repair mechanism for the module-state leak
- **Chose:** One shared conftest autouse fixture that detects drift and reloads `web.shared` in place (importlib.reload on the existing module object).
- **Why:** In-place reload preserves module identity, so `monkeypatch.setattr(web.shared, ...)` targets in other files stay coherent; drift detection makes it a no-op for clean tests; one fixture covers all five leaker files plus any future one.
- **Rejected:** (a) Per-file teardown fixtures in each leaker — five copies of the same logic, misses future leakers. (b) Popping all `web.*` from sys.modules on drift — breaks identity for test modules that bound blueprint objects at collection time (their monkeypatch.setattr would then patch a dead object while the app under test uses the fresh one). (c) Rewriting the leaker tests to use subprocess isolation — heavyweight, changes what they pin.

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-07-21T05:42:12Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2580-testsweb-full-dir-run-has-8-order-depend.md
- **Context:** Initial task creation

### 2026-07-21T05:42:24Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-9bd26e97
- **Timestamp:** 2026-07-21T05:54:53Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-07-21T05:54:49Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
