---
id: T-2716
name: "Draft the arc lifecycle + exit workflow map (pair-draft)"
description: >
  Draft the arc lifecycle + exit workflow map (pair-draft)

status: started-work
workflow_type: design
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
created: 2026-08-01T19:41:40Z
last_update: 2026-08-12T19:15:17Z
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
  - ts: '2026-08-01T19:45:05Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 3
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=3 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-02T19:45:05Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 3
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=3 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-01T19:45:09Z'
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
  - ts: '2026-08-02T20:00:10Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 1
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=2 
      (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=1 
      (body/components:prompt-incidental); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2716: Draft the arc lifecycle + exit workflow map (pair-draft)

## Context

Draft the arc lifecycle + exit workflow as a designer map, align with the operator via the
arc-014 pair-draft ritual, **then** build. Operator direction 2026-08-01: *"my thinking is we
draft the workflow first, align on that, then build."*

The mechanism being drawn comes out of the T-2715 grill (D-6, IW-21/IW-22) — see
`docs/reports/T-2715-first-run-experience.md` §D-6. What the map encodes:

- **Recompute at the decision point**, not on write events. Compares *state*, so it is indifferent
  to whether `arc_id` was set by a hook, by `fw arc tag`, or by hand-editing frontmatter. Every
  event-based alternative had a bypass path.
- **`recalc-then-pick` is one primitive** — the pick must recalc first or it reads the stale scores
  the mechanism exists to escape. Empty pick *is* the exit condition; no close-readiness heuristic.
- **Exit is a gate, not a formality** — the exit recalc can promote an LV task to HV, at which point
  the arc is not done and the workflow returns to it, reporting which tasks re-surfaced and which
  driver moved them.
- **Priority flag replaces human-confirmed `bvp_scores:`** — sovereignty moves from *arithmetic* to
  *intent*, with a direction (up **and** down) and a mandatory rationale.

**Scope fence:** this task produces a *draft map and operator alignment*. It does not implement the
mechanism — no estimator, sweep, `fw arc close` or flag changes. Implementation is a separate task
gated on the operator promoting this draft (IW-23 also still open on where that build lives).

## Acceptance Criteria

### Agent
- [x] v1 skeleton seeded at `.context/designer/projects/draft-arc-lifecycle/` (meta.json + v1.bpmn),
      following the established dialect: three authority lanes, `aef:uid` on every element,
      `aef:position` for layout, no BPMN DI section
- [x] The map encodes all four D-6 parts — recalc-then-pick split across the authority/initiative
      lanes, the exit recalc gate with its RETURN TO ARC edge, the bounce-back report, and the
      priority flag as an in-process human action
- [x] Open decision points are carried in node `aef:meta` rather than lost — recalc placement
      (drop the sweep's staleness gate vs inline on the completion trigger vs both) and the
      agent-completion-only trigger gap requiring an `fw arc close` backstop
- [x] Structurally sound: XML parses, every node is lane-assigned, no dangling flows, no unreachable
      node and no dead end (v3, the current latest: 17 nodes / 22 flows, all clean — v1 was 16/20
      before the driver-approval gate was replaced by decide+inform in v3)
- [x] Layout is clean: every node contained in its lane band, no overlapping node boxes
- [x] The draft is visible in the **live** designer, not merely committed — `/designer` on the
      running Watchtower lists `draft-arc-lifecycle`

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

- [ ] [REVIEW] The drawn workflow matches how you actually intend arcs to run

  **Steps:**
  1. Open `http://192.168.10.107:3001/designer` and select `draft-arc-lifecycle`
  2. Walk the happy path: open arc → agent **decides** scoped drivers → agent **informs** you what it
     adopted and how to change it → recalc → pick → work → recalc (loop). Note this changed in v3 on
     your 2026-08-01 instruction: driver approval is no longer a gate, sovereignty is preserved by
     availability (`hum_2_adjust`, optional, re-entering through recalc) rather than by a checkpoint.
     **This conflicts with CLAUDE.md §Arc-Scoped Driver Suggestion Workflow (M6/D8) and with
     `lib/arc.sh`, which gates `scoped_drivers:` behind `fw arc approve-driver` (T-1926, §ACD).**
     The conflict is flagged, not silently resolved — if you tick this AC, code and CLAUDE.md must
     follow. If you'd rather keep the approval gate, say so and the agent restores it in v4.
  3. Walk the exit path: pick finds nothing → exit recalc → **re-surfaced?** → yes returns to the arc,
     no proceeds to the G-062 close gates → you close via Watchtower
  4. Walk the two escapes: file-and-continue (a bug found mid-work is filed, not fixed, and simply
     appears in the next recalc), and the priority flag (you dispute a promotion and flag it down)
  5. Correct anything wrong **directly in the editor** and save — that is the pair-draft ritual;
     the agent re-reads your version and normalises rather than arguing in chat

  **Expected:** the map is how you want arcs run. Specifically: exit *can* refuse to close;
  low-value tasks never hold an arc open; the flag can push in both directions; and the operator
  holds arc creation, driver approval, the flag, and closure — nothing else.

  **If not:** edit in the UI and save a new version, or say what is wrong and the agent redraws.
  This AC is the alignment gate — the build task is not created until it is ticked.

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

# Structure + lane geometry: `fw corpus lint` is the AUTHORITY here, not a hand-rolled
# check. This task first shipped its own checker; it disagreed with corpus lint on 9 of
# 11 projects (its band model was wrong) — a second green surface contradicting the
# first is the exact failure T-2715 exists to study. Checker deleted, lint used instead.
# Falsified 2026-08-01: a dangling targetRef fires dangling-flow-ref, and a node pushed
# out of its band fires lane-geometry + lane-overflow. Known gap OBS-113: a node in NO
# lane still reports clean — the fix belongs in the lint, not in a parallel checker.
# Pin resolves from meta.json `latest` — NOT hard-coded to a version. Fixed 2026-08-02:
# this line read v1.bpmn while meta.json latest was 3 and the Human AC asks the operator
# to walk v3. A green check on v1 says nothing about the object under review — the exact
# "check reports success about the wrong object" class T-2715 catalogued (12 instances).
# Verified before landing: v1/v2/v3 all lint CLEAN; a dangling-targetRef mutant of v3
# produces 22 findings and NO "CLEAN" substring (predicate discriminates); and a missing
# path exits 2 with "not a file and not a store map id" (no silent pass if resolution breaks).
P=.context/designer/projects/draft-arc-lifecycle; F="$P/v$(python3 -c "import json;print(json.load(open('$P/meta.json'))['latest'])").bpmn"; echo "linting $F"; out=$(bin/fw corpus lint --summary "$F" 2>&1); echo "$out" | grep -q "CLEAN"

# meta.json is valid JSON and its `latest` points at a version file that exists on disk
python3 -c "import json,os;p='.context/designer/projects/draft-arc-lifecycle';m=json.load(open(p+'/meta.json'));f=p+'/v%d.bpmn'%m['latest'];assert os.path.isfile(f),'meta.json latest points at missing '+f;print('meta OK v%d'%m['latest'])"

# The draft is served by the LIVE designer, not merely committed to disk
out=$(curl -sf "$(bin/fw watchtower url)/designer" 2>&1); echo "$out" | grep -q "draft-arc-lifecycle"

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

### 2026-08-01T19:41:40Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2716-draft-the-arc-lifecycle--exit-workflow-m.md
- **Context:** Initial task creation
