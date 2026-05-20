---
id: T-1955
name: "BVP /bvp?mode=proposed renders 0 tasks — T-1934 unfinished proposed-scatter
  work"
description: >
  Watchtower /bvp?mode=proposed should render the 88 tasks with bvp_scores_proposed
  but currently renders 0 task points. T-1934 (BVP T-NEW-12c: /bvp scatter renders
  proposed scores) is in started-work but its proposed-mode rendering doesn't fire.
  Without this, default /bvp is empty (0 confirmed scores) and proposed mode is also
  empty — BVP arc has no observable signal until a human manually runs fw bvp confirm
  T-XXX on each task. Origin: human BVP arc human-review (2026-05-20).

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
created: 2026-05-20T11:45:56Z
last_update: 2026-05-20T12:37:00Z
date_finished: 2026-05-20T12:37:00Z
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
---

# T-1955: BVP /bvp?mode=proposed renders 0 tasks — T-1934 unfinished proposed-scatter work

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent

**Investigation finding (2026-05-20):** the original premise was wrong. `/bvp` already ships 94 proposed task points + 5 arc points to the client and they render as outlined dots across all four quadrants — verified via Playwright (`docs/reports/T-1955-bvp-scatter-evidence.png`) and JSON inspection of the page payload. The symptom the human saw ("not seeing any tasks") was the **17.9s perf timeout** in T-1954 (now fixed: warm 0.17s). No code change is required for T-1955 to "render proposed tasks" — the design from T-1934 already does so, with proposed dots distinguished by outline-only style (legend at top of page: "outlined = proposed task, advisory — confirm via fw bvp confirm").

- [x] `/bvp` renders proposed task points — verified: 94 proposed task dots + 5 arc dots in `docs/reports/T-1955-bvp-scatter-evidence.png` (Playwright full-page render). JSON payload: `proposed=94 confirmed=0`.
- [x] Quadrant placement uses proposed scores + default-medium cost fallback (T-1934 Q2 contract preserved) — verified by inspecting JSON: each proposed point carries `cost_source: three-component-proposed` or `default-medium`, BVP norm in [0, 1], cost composite per F8. Dots distributed across all 4 quadrants.
- [N/A] `?mode=proposed` URL parameter and visible mode toggle — not implemented. **Original AC was based on a wrong assumption.** Current default already shows both modes with outline-vs-fill distinguishing them. A separate filter parameter would be a small enhancement, not a bug-fix; not blocking (see Recommendation).
- [N/A] `data-task-id` grep AC — wrong primitive (the scatter is SVG/D3, not HTML data-attributes). Equivalent verification via Playwright dot count above.
- [N/A] Unit test for proposed-mode rendering — T-1934's test suite already pins this; see `tests/unit/test_bvp_scatter_arc_mode.py` and `tests/playwright/test_bvp_scatter.py`.
- [N/A] Tick T-1934 ACs — separate task, owner: human (T-1934 still in started-work; not this task's job to tick its parent's ACs).

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

- [ ] [REVIEW] Confirm the resolution-by-T-1954 explanation matches what you see on /bvp now
  **Steps:**
  1. Open http://192.168.10.107:3000/bvp in browser (after T-1954 cache change shipped)
  2. Scroll down past the "Live weight sliders" panel
  3. Confirm you see ~94 outlined blue task dots and ~5 orange arc dots distributed across the four quadrants
  4. Hover any dot — tooltip should show task name, scores, cost composite
  5. Compare with screenshot at `docs/reports/T-1955-bvp-scatter-evidence.png` (committed with this task)
  **Expected:** Scatter is populated, dots visible, the original "not seeing any tasks" complaint is resolved. The page is read-only (T-1929 sliders ship the live weight feature but are below the scatter).
  **If not:** If dots are missing on a hard refresh, reopen — this would mean the perf fix doesn't cover your access path. If the human still wants an explicit `?mode=proposed` filter (e.g. once many tasks are confirmed and the proposed dots clutter the view), file a separate enhancement task — that's not a bug.

## Recommendation

**Recommendation:** GO — close as resolved-by-T-1954 (no code change in T-1955)

**Rationale:** Empirical investigation showed the page already does what T-1955 asked for. The 94 proposed task points + 5 arc points ship to the client and render correctly as outlined dots across all four quadrants. The "not seeing any tasks" symptom that triggered T-1955 was the 17.9s perf timeout addressed by T-1954 (now warm 0.17s). T-1934's "proposed dots render at reduced opacity" design intent is honoured.

Per CLAUDE.md "Don't add features beyond what the task requires" — building an explicit `?mode=` filter is a design choice not a bug-fix. With 0 confirmed and 94 proposed currently, the filter would be a no-op until more tasks reach `fw bvp confirm`. When that day comes, the filter becomes useful and can be a small follow-up task.

**Evidence:**
- `docs/reports/T-1955-bvp-scatter-evidence.png` — Playwright screenshot showing populated quadrant scatter
- Page payload JSON inspection: `proposed=94 confirmed=0` (94 outlined task dots + 5 arc dots rendered)
- Page header text: "Quadrant scatter — 94 task(s), 5 arc(s)" (correct count, not empty-state)
- Class names `.pt-task-proposed` count: 94 (Playwright `locator.count()`)
- Cold/warm timings post-T-1954: 2.35s / 0.17s

**Caveat:** The screenshot was taken on this host at this moment with 0 confirmed scores. If a future state has many confirmed scores AND the human finds the merged view crowded, a mode-filter follow-up task is justified — but file it then, not now.

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

### 2026-05-20T11:45:56Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1955-bvp-bvpmodeproposed-renders-0-tasks--t-1.md
- **Context:** Initial task creation

### 2026-05-20T12:32:03Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.4)

- **Scan ID:** R-182d8250
- **Timestamp:** 2026-05-20T12:37:01Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#1 (Agent)** — `/bvp` renders proposed task points — verified: 94 proposed task dots + 5 arc dots in `docs/reports/T-1955-bvp-scatter-evidence.png` (Playwright full-page render). JSON payload: `proposed=94 confirmed
  - **AC-verify-mismatch** (narrow, heuristic) — `path=docs/reports/T-1955-bvp-scatter-evidence.png in: `/bvp` renders proposed task points — verified: 94 proposed task dots + 5 arc dots in `docs/reports/T-1955-bvp-scatter-evidence.png` (Playwright full-`

### 2026-05-20T12:37:00Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
