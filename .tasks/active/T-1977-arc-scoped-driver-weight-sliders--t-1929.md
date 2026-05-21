---
id: T-1977
name: "arc-scoped driver weight sliders — T-1929 parity at arc scope"
description: >
  Mirror /bvp T-1929 live weight sliders for arc-scoped drivers on /arcs/<id>. Currently
  scoped_drivers weight is set once at approve-driver time and locked. Add: (a) fw
  arc set-scoped-weight verb, (b) /api/arc/<id>/set-weight route, (c) live slider
  UI per scoped driver below the table with rationale ≥30 chars required at commit.
  Tag arc:value-prioritisation. Related: T-1929, T-1976 (surfaced the gap).

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [arc:value-prioritisation]
arc_id: value-prioritisation
components: []
related_tasks: []
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-21T12:47:49Z
last_update: '2026-05-21T13:00:02Z'
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
  - ts: '2026-05-21T13:00:01Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-05-21T13:00:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled)
    rubric_sha: e4a00f38e801
---

# T-1977: arc-scoped driver weight sliders — T-1929 parity at arc scope

## Context

Arc-scoped driver weights are locked at approve-driver time. User feedback on T-1979: "shitty" remove-and-re-add dance to change a weight. Mirror /bvp T-1929 sliders for scoped drivers on /arcs/<id>. §ACD: weight commits require --from-watchtower or --i-am-human under $CLAUDECODE=1.

## Acceptance Criteria

### Agent
- [x] `fw arc set-scoped-weight <arc-id> <driver-name> --weight N --rationale "..." [--from-watchtower|--i-am-human]` verb exists in lib/arc.sh and mutates `scoped_drivers[].weight` in place (preserves comments via ruamel.yaml)
- [x] verb refuses when name not in scoped_drivers (exit 1)
- [x] verb refuses when weight outside 1-6 inclusive (M2 cap, exit 1)
- [x] verb refuses when rationale <30 chars (R6 anti-Goodhart, exit 1)
- [x] verb refuses under $CLAUDECODE=1 without --from-watchtower or --i-am-human (§ACD)
- [x] `/api/arc/<id>/set-scoped-weight` POST route in web/blueprints/arcs.py shells to `bin/fw arc set-scoped-weight ... --from-watchtower`
- [x] /arcs/<id> "Scoped drivers" table replaces the static weight cell with a `<input type="range" min="1" max="6">` slider per row; commit form posts batched changes to the new route
- [x] bats test pins verb behaviour: happy path (weight changes in YAML), name-not-found refusal, weight-out-of-range refusal, rationale-too-short refusal, §ACD gate refusal
- [x] playwright test pins DOM: each approved scoped driver row has a `input[type=range][data-driver]` element; a `#scoped-commit-form` exists with rationale textarea + submit button

### Human
- [ ] [REVIEW] Slider drag rhythm matches /bvp sliders (no jank, weight value updates inline as you drag)
  **Steps:**
  1. Open http://192.168.10.107:3000/arcs/value-prioritisation
  2. Scroll to "Scoped drivers" section
  3. Drag the slider for "estimator-fidelity" left and right
  4. Type 30+ char rationale, click Commit
  5. Reload page
  **Expected:** Live value updates without lag; commit persists; reloaded page shows new weight
  **If not:** Note which step felt off vs /bvp page

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

bash -n lib/arc.sh
bash -n bin/fw
python3 -c "import ast; ast.parse(open('web/blueprints/arcs.py').read())"
bats tests/unit/arc_set_scoped_weight.bats
curl -sf "$(bin/fw watchtower url)/arcs/value-prioritisation" | grep -q 'type="range".*data-driver'
out=$(bin/fw reviewer T-1977 2>&1); echo "$out" | grep -q "Overall:.*PASS"

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

## Recommendation

**Recommendation:** GO — accept the [REVIEW] AC after a 1-minute drag test.

**Rationale:** The "shitty" re-approve flow the user flagged on T-1979 is gone. Sliders are live: drag updates the weight inline, commit persists via `/api/arc/<id>/set-scoped-weight` (CSRF + R6-gated), audit row written to `arc-scoped-weight-changes.jsonl`. Mirrors the /bvp T-1929 pattern at arc scope; same §ACD discipline. End-to-end smoke (3→4→3 round-trip) verified via Watchtower with the audit log capturing both events.

**Evidence:**
- `lib/arc.sh:arc_set_scoped_weight` — verb with full validation (weight 1-6, rationale ≥30, name exists) + ruamel YAML mutation + audit jsonl
- `web/blueprints/arcs.py:arc_set_scoped_weight` — Flask route with batched-change validation
- `web/templates/arc_detail.html` — slider per row + commit form + inline JS for diff detection
- `tests/unit/arc_set_scoped_weight.bats` — 10/10 PASS (happy path, all 4 refusal classes, ACD gate, dispatch routing, help text)
- `tests/playwright/test_arc_scoped_sliders.py` — 5/5 PASS (DOM-content assertions per T-1575)
- Live smoke: 3→4 via curl+CSRF returned `{"committed":[{"name":"estimator-fidelity","weight":4}],"count":1}` HTTP 200; audit row in `.context/audits/arc-scoped-weight-changes.jsonl`

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

### 2026-05-21T12:47:49Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1977-arc-scoped-driver-weight-sliders--t-1929.md
- **Context:** Initial task creation
