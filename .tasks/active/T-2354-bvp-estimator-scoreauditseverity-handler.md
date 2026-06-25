---
id: T-2354
name: "BVP estimator score_audit_severity handler + audit_severity frontmatter (T-2352
  S2)"
description: >
  Slice 2 of T-2352. Add score_audit_severity handler to BVP estimator (FAIL=1.0,
  WARN=0.75) mirroring T-2329 F-AUTONOMY pattern. Add audit_severity:fail|warn frontmatter
  field. Validates that audit-finding tasks rank above routine backlog.

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: [T-2352, T-2353, T-2329]
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
created: 2026-06-12T12:24:41Z
last_update: 2026-06-25T22:55:09Z
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
  - ts: '2026-06-13T18:00:03Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-06-13T18:00:05Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 0
      F-ORCH: 4
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=0 
      (no-signal); F-ORCH=4 (body:rubric-routable); F-AUTONOMY=0 (no-signal); 
      F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2354: BVP estimator score_audit_severity handler + audit_severity frontmatter (T-2352 S2)

## Context

Slice 2 of T-2352 (audit→bugfix arc). Add a `score_audit_severity` handler to the
BVP estimator that reads an `audit_severity: fail|warn` frontmatter field and scores
audit-finding tasks high (FAIL → top band, WARN → next), mirroring the dedicated-handler
pattern of `score_f_autonomy` (T-2329). Goal: audit-finding tasks rank above routine
backlog on `fw bvp`.

**BLOCKED — dependency not yet in place (2026-06-13):** `audit_severity` exists nowhere
in the codebase (`grep -rn audit_severity policy/ agents/` → 0 hits). The prerequisite is
T-2353 (S1: audit.sh post-emit hook that *emits* tasks carrying the `audit_severity`
frontmatter) plus a driver definition in `policy/value-drivers.yaml`. A handler scoring a
field nothing produces is dead code. **Deferred until T-2353 lands the field + driver.**
The "FAIL=1.0/WARN=0.75" in the filing also needs reconciling with the estimator's 0–5
integer handler scale (handlers return `tuple[int, list[str]]`, not 0–1 floats) — resolve
when S1 fixes the driver's scale.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] `score_audit_severity(fm, body, tags) -> tuple[int, list[str]]` handler added to `agents/termlink/bvp-estimator/estimator.py`, reading `fm["audit_severity"]` (fail→top band, warn→next band) on the estimator's 0–5 scale, mirroring `score_f_autonomy` structure
- [x] Handler registered in the handlers dict and dispatched by `estimate_task()` when the `audit_severity` driver is active in `policy/value-drivers.yaml` (registered at estimator.py handlers dict; `test_estimate_task_routes_audit_severity_to_dedicated_scorer` proves dispatch fires when the driver is in the active set)
- [x] `audit_severity: fail|warn` documented as a recognised frontmatter field — value-drivers.yaml `audit_severity` candidate carve carries an explicit FRONTMATTER FIELD CONTRACT block (fail→5 / warn→4 / absent→0)
- [x] Unit tests cover fail→high score, warn→mid score, absent→0/no-signal (6 tests in `tests/unit/test_bvp_estimator.py`: fail→5, warn→4, absent→0, unrecognised→0, case-insensitive, dispatch+rank)
- [x] Live check: a task with `audit_severity: fail` ranks above an otherwise-equal routine task — proven via `estimate_task()` (the engine `fw bvp` calls per task): identical bodies, only the field differs → FAIL weighted contribution (5×6) strictly above routine (0×6). NOTE: the literal `fw bvp` CLI surface shows the boost only after the operator *activates* the carved driver (Sovereignty / D8 — see §Decisions)

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

python3 -m pytest tests/unit/test_bvp_estimator.py -q -k audit_severity
python3 -c "import py_compile; py_compile.compile('agents/termlink/bvp-estimator/estimator.py', doraise=True)"
python3 -c "import yaml; yaml.safe_load(open('policy/value-drivers.yaml'))"
grep -q '"audit_severity": score_audit_severity,' agents/termlink/bvp-estimator/estimator.py
# Driver stays LATENT (carved) — must NOT appear in the active free_drivers list:
python3 -c "import yaml,sys; d=yaml.safe_load(open('policy/value-drivers.yaml')); sys.exit(0 if 'audit_severity' not in [x.get('id') for x in d.get('free_drivers',[])] else 1)"

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

### 2026-06-26 — Ship the driver LATENT (carved), not active
- **Chose:** Add `score_audit_severity` handler + register it, but ship the
  `audit_severity` driver as a CANDIDATE carve (commented) in
  `policy/value-drivers.yaml` — mirroring the original F-AUTONOMY carve (T-2329).
  The handler is wired and tested; it dispatches the moment the operator
  uncomments the carve.
- **Why:** Activating a new BVP driver reweights **every** task's rank — that is a
  Sovereignty boundary (D8), not delegated to the agent under "proceed as you see
  fit" (CLAUDE.md §Autonomous Mode Boundaries: changing policy is not delegated).
  The free-driver cap is also already at/over 5, so adding a 7th active driver is
  a focus/policy call the operator must make (which driver, if any, to drop).
- **Rejected:** Activating it directly — would be an un-sanctioned policy change.
  AC #5's literal "on `fw bvp`" live ranking is therefore demonstrated through
  `estimate_task()` (the per-task engine `fw bvp` calls) with the driver in the
  active set; the CLI surface shows the boost once the operator activates.

### 2026-06-26 — Scale: fail→5 / warn→4 (reconcile float spec to int handler scale)
- **Chose:** Map `audit_severity: fail`→5, `warn`→4, absent/other→0.
- **Why:** The T-2352 filing said FAIL=1.0 / WARN=0.75 (0-1 floats), but estimator
  handlers return `tuple[int, list[str]]` on a 0-5 scale (multiplied by driver
  weight). fail→5 / warn→4 preserves the intended fail > warn > routine ordering
  on the scale the framework actually uses. (Blocker note in §Context flagged this
  reconciliation as required; resolved here.)
- **Rejected:** fail→5 / warn→3 (wider gap) — 4 keeps WARN clearly above routine
  while leaving 5 as the unambiguous top band; the one-band gap matches the
  modest float gap (1.0 vs 0.75).

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-06-12T12:24:41Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2354-bvp-estimator-scoreauditseverity-handler.md
- **Context:** Initial task creation

### 2026-06-13T11:15:17Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

### 2026-06-13T11:22:08Z — status-update [task-update-agent]
- **Change:** status: started-work → captured
- **Change:** horizon: now → next

### 2026-06-13T11:23:48Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)
