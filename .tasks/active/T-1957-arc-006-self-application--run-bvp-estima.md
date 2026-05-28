---
id: T-1957
name: "arc-006 self-application — run BVP estimator on anchor T-1915 to populate proposed_scoped_drivers"
description: >
  arc-006 (value-prioritisation) has proposed_scoped_drivers=[] so the /arcs/arc-006
  Approve-driver form is hidden — only 'Approve none' renders. The BVP estimator (T-1922)
  is supposed to propose scoped drivers based on the arc anchor task, but hasn't been
  invoked on T-1915 (the arc-006 anchor). This is the arc-self-application gap: the
  arc that BUILDS the BVP estimator hasn't had its own anchor estimated. Action: invoke
  estimator on T-1915, populate proposed_scoped_drivers (or write --none with justification
  if global D1-D4 cover the arc). Origin: human BVP arc human-review (2026-05-20).

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: []
components: []
related_tasks: []
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-20T11:46:22Z
last_update: '2026-05-28T22:54:10Z'
date_finished: 2026-05-20T12:31:49Z
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
  - ts: '2026-05-20T12:00:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-05-20T12:00:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled)
    rubric_sha: e4a00f38e801
  - ts: '2026-05-28T22:54:10Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F1=0 (no-signal); 
      F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1957: arc-006 self-application — run BVP estimator on anchor T-1915 to populate proposed_scoped_drivers

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] Invoke BVP estimator on T-1915 (arc-006 anchor) via `fw bvp estimate T-1915` — wrote `bvp_scores_proposed: D1=4 D2=4 D3=0 D4=2` (BVP total 70, norm 0.58). Quadrant: medium-value × high-cost (composite 6.10).
- [x] `.context/arcs/value-prioritisation.yaml` `proposed_scoped_drivers:` populated with 3 candidates per T-1925 workflow (each with name, weight, rationale, source: agent, ts)
- [x] Each candidate rationale articulates what it distinguishes that global D1-D4 do not (D6 quality criterion) — sovereignty-preservation vs D2 audit-framing; adoption-friction vs D3 generic-usability; estimator-fidelity vs D2 doesn't-crash framing
- [x] /arcs/arc-006 now renders the Approve-driver form — verified: `curl -sf http://localhost:3000/arcs/arc-006` returns HTML containing `approve-driver` form plus all 3 driver names
- [N/A] `--none` justification block — not applicable. 3 proposals shipped. Per T-1925: human may still approve `--none` on this set; that decision is on the Human AC below.

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

- [ ] [REVIEW] Approve, reject, or `--none` the 3 proposed scoped drivers for arc-006
  **Steps:**
  1. Open http://192.168.10.107:3000/arcs/arc-006 in browser
  2. Read each rationale for the 3 proposed drivers — sovereignty-preservation (weight 5), adoption-friction (weight 4), estimator-fidelity (weight 3)
  3. For each driver, decide: meaningful distinction from global D1-D4 (approve) or duplicative/manufactured (reject)
  4. Approve up to 3 via the Approve-driver form, OR run `--none` if you find none of them distinguish enough:
     - Approve: click Approve-driver button on the Watchtower form (one per driver, optionally tweak weight ≤6)
     - Reject all: CLI `cd /opt/999-Agentic-Engineering-Framework && bin/fw arc approve-driver value-prioritisation --none --justification "<≥30 chars stating why global D1-D4 already capture what these candidates measure>" --i-am-human`
  5. After at least one approval (or `--none`), the arc transitions from `draft` to `in-progress` (D-Lifecycle in T-NEW-10).
  **Expected:** Driver decisions land in `.context/arcs/value-prioritisation.yaml` `scoped_drivers:` (or stay `[]` if `--none`). Arc status flips to `in-progress`.
  **If not:** Form 500 or CLI rejects — open T-1958 (driver CRUD UI inception) for follow-up, or file a bug if it's the §ACD gate refusing your invocation.

## Recommendation

**Recommendation:** GO (for arc-006 self-application; final driver-approval decision sits with the human via the Human AC above)

**Rationale:** Three driver candidates ship with D6-quality rationales — each explicitly articulates what it distinguishes that global D1-D4 do not, and each cites a concrete arc-006 instance proving the distinction is load-bearing (Goodhart's-law risk on sovereignty; T-1934 §ACD precedent on adoption-friction; M3 v2-delta semantic on estimator-fidelity). Per T-1925 R5 ("manufacturing drivers to look thorough is worse than proposing zero"), the bar was honestly applied — I considered and rejected a 4th driver (`measurement-meta-validity`) as too overlapping with D1.

**Evidence:**
- `.context/arcs/value-prioritisation.yaml` `proposed_scoped_drivers:` 3 entries, validated by `python3 -c "import yaml; yaml.safe_load(open('...'))"`
- `bin/fw arc show-suggestions value-prioritisation` renders all 3 with rationale text
- `bin/fw bvp estimate T-1915` → wrote D1=4 D2=4 D3=0 D4=2 (BVP norm 0.58), 0.03s
- `bin/fw bvp T-1915` → renders full per-driver breakdown + cost composite
- /arcs/arc-006 renders the Approve-driver form (curl-verified, all 3 driver names present in HTML)

**Caveat on T-1915 D3=0:** The heuristic estimator scored Usability=0 for the BVP inception itself. That looks wrong on its face (arc-006 is *about* prioritisation usability), and is itself a small data point for the proposed `estimator-fidelity` driver — the kind of mis-scoring this driver would surface. Worth flagging at the next `fw bvp confirm T-1915` whether the human's confirmed score diverges by ≥2.

**Recommended approval set:** all 3 (the most informative outcome — arc-006's success can then be tracked along axes the global drivers can't measure). If you find one weakest, sovereignty-preservation and adoption-friction are the two most independently load-bearing — estimator-fidelity is somewhat narrow.

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

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-05-20T11:46:22Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1957-arc-006-self-application--run-bvp-estima.md
- **Context:** Initial task creation

### 2026-05-20T12:26:51Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.4)

- **Scan ID:** R-48910dcb
- **Timestamp:** 2026-05-20T12:31:50Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#2 (Agent)** — `.context/arcs/value-prioritisation.yaml` `proposed_scoped_drivers:` populated with 3 candidates per T-1925 workflow (each with name, weight, rationale, source: agent, ts)
  - **AC-verify-mismatch** (narrow, heuristic) — `path=context/arcs/value-prioritisation.yaml in: `.context/arcs/value-prioritisation.yaml` `proposed_scoped_drivers:` populated with 3 candidates per T-1925 workflow (each with name, weight, rational`

### 2026-05-20T12:31:49Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
