---
id: T-2555
name: "designer-corpus D1: task-lifecycle process diagram (draft BPMN + gallery + compile dogfood)"
description: >
  designer-corpus D1: task-lifecycle process diagram (draft BPMN + gallery + compile dogfood)

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: []
components: []
related_tasks: []
arc_id: designer-corpus
# arc_id (template note):                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
# demo_target: true               # T-2286: optional — marks task as reserved for an orchestrated demo
#                                 # worker (e.g. arc-010 HM-A dispatches via mcp__fw__work_on). When set,
#                                 # `fw work-on T-XXX` refuses unless --i-am-demo-orchestrator (CLI) or
#                                 # FW_I_AM_DEMO_ORCHESTRATOR=1 (env) is passed. Prevents the parent
#                                 # session from consuming the captured→started-work transition the demo
#                                 # worker expects to drive. Origin OBS-057.
created: 2026-07-19T20:02:57Z
last_update: 2026-07-19T20:09:08Z
date_finished: 2026-07-19T20:09:08Z
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

# T-2555: designer-corpus D1: task-lifecycle process diagram (draft BPMN + gallery + compile dogfood)

## Context

First corpus diagram of arc designer-corpus (arc-014, anchor T-2553, GO recorded 2026-07-19):
the AEF task lifecycle (captured → started-work ↔ issues → work-completed, incl. P-011
verification gate and the T-193 partial-complete Human-AC path) drawn as BPMN, saved to the
designer gallery via POST /api/save (dogfoods the API), compiled via `fw bpmn compile` with every
WARN/semantic loss logged as an arc gap. Pair-draft model (grill 2d): agent drafts, operator
reviews/corrects in the designer UI at /designer.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] Diagram drafted covering the real lifecycle: captured, started-work, work loop with progressive AC ticking, issues↔healing loop, P-011 verification gate, Human-AC decision (partial-complete → human review) vs direct completion; every task node carries an aef:uid; lanes carry aef:laneMeta authority (initiative=agent / sovereignty=human)
- [x] Saved to the gallery through the live POST /api/save endpoint (not by writing the store file directly); /api/list shows the map id and /designer serves it
- [x] `fw bpmn compile` runs on the saved BPMN; exit code and every WARN captured verbatim in this task's Updates/report
- [x] Every semantic loss or vocabulary gap discovered is filed (arc gap list started — as arc-014 constituent task(s) or documented gap entries in the compile report), not silently absorbed

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

- [ ] [REVIEW] Diagram truthfully represents the task lifecycle as you operate it (corpus-fidelity)
  **Steps:**
  1. Open the designer: paste the URL emitted by `cd /opt/999-Agentic-Engineering-Framework && bin/fw watchtower url` + `/designer`, open map `aef-task-lifecycle`
  2. Walk the flow: capture → start → work/AC-ticking → issues↔healing loop → verification gate → Human-AC branch (partial-complete review) vs direct completion
  3. Correct anything wrong directly in the UI and save (a new version is created — the pair-draft loop)
  **Expected:** The flow matches how tasks actually move; lane split (Agent initiative / Human sovereignty) reads right; nothing important missing
  **If not:** Edit in the UI and save, or tell the agent what is wrong — corrections are the exercise working, not a failure

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
curl -sf "$(bin/fw watchtower url)/api/list" > /tmp/.t2555-list && grep -q aef-task-lifecycle /tmp/.t2555-list
bin/fw bpmn compile .context/designer/projects/aef-task-lifecycle/v1.bpmn > /dev/null
test -f docs/reports/T-2555-d1-compile-log.md
grep -q "T-2556" docs/reports/T-2555-d1-compile-log.md && grep -q "T-2557" docs/reports/T-2555-d1-compile-log.md

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

- Compile of a documentation diagram was expected to produce WARN noise; instead it produced ZERO WARNs and 7 clean promotable skeletons — the surprise is the opposite of the anticipated one: the pipeline is too willing, not too brittle. That reframed gap #1 from "vocabulary can't express the process" to "vocabulary can't express the diagram's INTENT (documentation vs work-plan)" → T-2556.
- The issues↔work back-edge was drafted as a deliberate stress-probe (loops were a suspected breaker per the inception's Technical Constraints); it survived flow-order derivation intact — one anticipated corpus risk retired on D1.
- Gateway silent-loss (T-2557) was not on the anticipated gap list at filing; it emerged only by diffing the drafted semantics against compile output — evidence the corpus exercise finds what fixture tests structurally cannot.

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

## Recommendation

**Recommendation:** GO — approve D1 after your UI review pass

**Rationale:** All four Agent ACs verified live: diagram drafted in the canonical 832 dialect (laneMeta authority, aef:uid on every node), saved through the real POST /api/save (v1, listed by /api/list, /designer serves 200), compiled exit 0 with the issues↔work loop intact and correct owner derivation (human for the review step). The two discovered gaps are filed as arc constituents (T-2556 diagram-kind vocabulary, T-2557 silent gateway loss) — the accumulator model working as scoped. The only open item is yours by design (pair-draft 2d): walk the flow in the designer UI and correct anything that does not match how you operate the lifecycle.

**Evidence:**
- Gallery save: `{"ok":true,"v":1}`; `/api/list` shows `aef-task-lifecycle`
- Compile: exit 0, 7 skeletons, 0 WARNs — verbatim log in `docs/reports/T-2555-d1-compile-log.md`
- Gaps filed: T-2556, T-2557 (both tagged arc:designer-corpus, horizon later)

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

### 2026-07-19T20:02:57Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2555-designer-corpus-d1-task-lifecycle-proces.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-116584f7
- **Timestamp:** 2026-07-19T20:09:10Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **empty-output-success** (partial, heuristic) @ Verification:line 11
     - evidence: `bin/fw bpmn compile .context/designer/projects/aef-task-lifecycle/v1.bpmn > /dev/null`

### 2026-07-19T20:09:08Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
