---
id: T-2680
name: "silent-zero store-grep detector (T-2679 Slice 1)"
description: >
  Static detector for the silent-drift grep family: fixed-indent greps against .context/
  stores and zero-fallback count patterns. Ships as an audit WARN section plus a reviewer
  static-scan pattern. First slice authorised by the T-2679 GO.

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
created: 2026-07-29T16:40:31Z
last_update: '2026-10-20T22:00:20Z'
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
  - ts: '2026-07-29T16:45:05Z'
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
  - ts: '2026-10-20T22:00:20Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=152,acs=8)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-07-29T16:45:08Z'
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
  - ts: '2026-10-20T22:00:20Z'
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

# T-2680: silent-zero store-grep detector (T-2679 Slice 1)

## Context

Slice 1 / Candidate C of the T-2679 GO (`docs/reports/T-2679-determinism-graduation-tripwire.md`):
a static detector for the grep family behind T-2676 and T-2677. Re-checked at HEAD
2026-10-21: nothing of the kind existed (no `silent_zero`/`fixed-indent` scanner in
`agents/audit/`, `lib/reviewer/`, `lib/`, `tools/`), so it was built rather than closed.

**Live findings at introduction (16; `python3 lib/silent_zero_scan.py`)** — NOT fixed
here (one bug = one task; parent to triage). Two are already dead today:
- `lib/harvest.sh:427,436` — `grep "^    name:"` against practices.yaml, whose live shape
  is `^  name:` (2-space) → the practices sub-stage of harvest matches 0.
- `agents/audit/audit.sh:8295` — `grep -c "^  - type:"` on patterns.yaml → 0 live
  (`grep -c "^  - type:" .context/project/patterns.yaml` prints 0).
The rest (harvest decisions, decision.sh/pattern.sh next-id, init.sh cron counts,
5 zero-fallback counts) currently match but are shape-pinned.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] Detector module `lib/silent_zero_scan.py` flags (a) fixed-indent greps (`^` + 2+ literal spaces + YAML key) against a YAML store (a `.context/` path, a `*.yaml` literal, or a variable resolving to / named as one), and (b) zero-fallback counts (`grep -c … || echo 0` / `|| n=0`) against a `.context/` store; prints `file:line: <rule>: <snippet>` and exits 0 (findings are advisory)
- [x] Detector does NOT flag indent-tolerant greps (`^[[:space:]]*`, `^ *`, `^ +`, `^\s*`), stdin greps, comments, nor greps of non-store files
- [x] `fw audit` (structure section, check id `silent-zero-store-greps`) emits one summarised WARN with count + first 3 findings, and a PASS line when none are found
- [x] Reviewer static scan exposes the same rules as pattern `silent-zero-store-grep` over the task's `## Verification` lines (lie_severity partial → CONCERN, not FAIL), catalogued in `policy/anti-patterns.yaml`
- [x] Regression tests `tests/unit/test_silent_zero_scan.py` cover both rules, the tolerant-grep negatives, and the T-2676/T-2677 verbatim shapes; all pass (19 passed)
- [x] `bin/fw vendor self --check --task T-2680` clean

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

python3 -m pytest -q tests/unit/test_silent_zero_scan.py
python3 lib/silent_zero_scan.py --root . lib agents bin
python3 -m pytest -q tests/unit/test_reviewer_static_scan.py
bash -n agents/audit/audit.sh
out=$(bash agents/audit/audit.sh --check silent-zero-store-greps 2>&1); echo "$out" | grep -qE "\[(WARN|PASS)\] Silent-zero store greps"
python3 -c "import yaml; c=yaml.safe_load(open('policy/anti-patterns.yaml')); assert any(p['id']=='silent-zero-store-grep' for p in c['patterns'])"
bin/fw vendor self --check --task T-2680

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

**Symptom:** shell components that read `.context/` YAML stores with greps reported
"none"/0 for months while the store held hundreds of entries (T-2676 harvest.sh 549:0;
T-2677 audit graduation counter, `agents/audit/audit.sh` then-line `grep -c '^  - id: L-'`,
never fired in its life).

**Root cause:** the greps encode the store serializer's indentation (`^  ` / `^    `) as if
it were a contract, and fold "no match"/"unreadable" into 0 (`|| echo 0`, `|| n=0`). When
the store's shape changes, the grep matches nothing, exits 0, and its output is a
plausible empty result.

**Why structurally allowed:** nothing scanned for the shape. Each instance was found by
accident (T-2667 knowledge-leveling baseline) and fixed site-by-site; the family itself
had no detector, so the same shape remained at 16 other sites (see Context), two of them
already dead (`lib/harvest.sh:427,436`, `agents/audit/audit.sh:8295`).

**Prevention:** `lib/silent_zero_scan.py` + `fw audit` check `silent-zero-store-greps`
(structure section, runs daily and at pre-push, WARN) surfaces every site; reviewer
pattern `silent-zero-store-grep` catches the shape in task `## Verification` lines;
`tests/unit/test_silent_zero_scan.py` pins the T-2676/T-2677 verbatim shapes and the
tolerant negatives. Whether a flagged grep currently matches live data is Slice 2's probe
registry (T-2681).

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

### 2026-07-29T16:40:31Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2680-silent-zero-store-grep-detector-t-2679-s.md
- **Context:** Initial task creation

### 2026-10-20T21:57:59Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-fee5852b
- **Timestamp:** 2026-10-20T22:10:13Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
