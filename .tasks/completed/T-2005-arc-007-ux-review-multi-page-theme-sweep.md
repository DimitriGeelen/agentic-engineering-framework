---
id: T-2005
name: "arc-007 ux-review multi-page theme sweep — verify headline mechanic across
  Cockpit Tasks Approvals Fabric Arcs"
description: >
  arc-007 ux-review multi-page theme sweep — verify headline mechanic across Cockpit
  Tasks Approvals Fabric Arcs

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: [ux, css, arc-007, tooling]
components: []
related_tasks: [T-2002, T-2003, T-2004, T-1991, T-1988, T-1987]
arc_id: watchtower-redesign
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-23T15:14:04Z
last_update: '2026-08-16T22:24:51Z'
date_finished: 2026-05-25T14:52:39+02:00
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
  - ts: '2026-05-23T15:15:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-05-23T15:15:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:24:05Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 2
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=2 
      (body:lightly-promoted); F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:51Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=2 
      (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2005: arc-007 ux-review multi-page theme sweep — verify headline mechanic across Cockpit Tasks Approvals Fabric Arcs

## Context

arc-007's headline mechanic promises: pick a theme in `/settings/appearance` and "re-load
any other page (Cockpit/Tasks/Approvals/Fabric/Arcs) and observe the same applied theme
without manual reapply." The ux-review agent (T-2002) only checks `/settings/appearance` +
**one** content page (`/tasks`). T-2003 fixed the pico-bridge so app chrome follows the
palette, but we have no executed-browser evidence that the fix holds across all 5 pages —
or that ad-hoc per-page styling doesn't override the foundation tokens on some of them.

This task extends the agent to sweep **all 5 arc pages** under a non-default palette and
emit a per-page bridge + token-fidelity verdict. The output is (a) the executed-browser
first pass for the arc's headline-mechanic [REVIEW], and (b) the prioritization signal for
which redesign slice (S2-S6) has the most broken theme state. As a permanent guard it also
catches theme regressions when those slices later touch each page.

Routes verified live (200): `/` (Cockpit), `/tasks`, `/approvals`, `/fabric`, `/arcs`.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] `ux-review.py` accepts `--content-pages` (comma-separated list); when set, the capture
      loops every page and runs the pico-bridge check (`--pico-primary` vs `--wt-accent`) on
      each. Back-compat: `--content-page` (singular) still works; default sweep (`--sweep`) is
      the 5 arc pages `/,/tasks,/approvals,/fabric,/arcs`. Verified: `bin/fw ux-review --content-pages "/,/arcs"` parsed the list and swept both; `--sweep` swept all 5
- [x] The report (`docs/reports/T-2002-ux-review-arc-007-s0-s1.md`) gained a **per-page
      theme-fidelity table** (one row per page, bridge ✅/⚠️ + observed `--pico-primary`/
      `--wt-accent`/`--wt-bg`). Verified: `grep -qE '/approvals|/fabric|/arcs'` matches; table
      shows **5/5 pages carry the theme** (all `#b87a17` under Bone)
- [x] Each swept page screenshotted under the Bone palette into the gallery. Verified: 5 frames
      `sweep-root.png / sweep-tasks.png / sweep-approvals.png / sweep-fabric.png / sweep-arcs.png`
- [x] `python3 -m py_compile agents/ux-review/ux-review.py` passes; `bash -n bin/fw` OK (bin/fw
      not touched — the `ux-review)` case already passes `"$@"` through)

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
- [ ] [REVIEW] The cross-page gallery shows the picked theme applied consistently across all
      5 pages (or clearly reveals which page breaks it)
  **Steps:**
  1. Open `http://192.168.10.107:3000/static/ux-review/index.html`
  2. Look at the per-page frames captured under a non-default palette (e.g. Bone/Midnight)
  3. Compare chrome (accent buttons, headers), background, and text against /settings/appearance
  4. Cross-check the per-page table in the run report for any CONCERN rows
  **Expected:** Cockpit/Tasks/Approvals/Fabric/Arcs all carry the same palette, accent, and
  density — no page falls back to the Pico default blue/grey
  **If not:** Note which page(s) ignore the theme and tell the agent; that page's redesign
  slice (S2-S6) is the priority

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
python3 -m py_compile agents/ux-review/ux-review.py
bash -n bin/fw
grep -qE '/approvals|/fabric|/arcs' docs/reports/T-2002-ux-review-arc-007-s0-s1.md

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

### 2026-05-23 — the sweep confirmed the fix instead of finding new breakage
- **What changed:** I filed this expecting the sweep to *find* pages where the theme
  breaks (the prioritization signal for S2-S6). Instead it found the opposite: the
  T-2003 pico-bridge fix is global in foundations.css, so all 5 pages already carry the
  palette (`--pico-primary == --wt-accent == #b87a17` everywhere). The headline mechanic
  at the *token/bridge* level already holds.
- **Plan impact:** "which page is most broken" is no longer the question for the redesign
  slices — chrome theming is solved app-wide. The remaining S2-S6 work is *layout/structure*
  (nav flatten, cockpit, board, fabric/arcs, command palette), not theme plumbing. The
  sweep's lasting value flips from "find broken pages now" to "regression guard" — it will
  catch the first time a slice introduces page-local CSS that overrides a foundation token.
- **Triggered:** Noted a latent dual-source-of-truth: base.html injects server-side
  `data-theme` from the persisted pref, but an inline `localStorage('wt-theme')` script can
  override it — a stale localStorage value could fight the saved preset for a real user
  (the sweep's fresh browser context has empty localStorage, so it passed). Candidate
  follow-up if the human hits theme flicker/mismatch on their own browser; not filed yet
  (one-bug-one-task — needs a reproduced symptom first).

### 2026-05-25 — the guard caught a data-growth regression; the sweep itself needed hardening
- **What changed:** Re-running the sweep this session (after the T-2035 cockpit perf
  fix unblocked it) hard-failed with `Page.screenshot: Timeout 15000ms exceeded`. I
  first assumed the cockpit (`/`, first page) or the Cytoscape `/fabric` page; both were
  fine. Localising with per-page progress prints (`python3 -u`, no pipe) showed the hang
  was on **`/approvals`** — `scrollHeight = 37,247px` (a single DIV with 120 children:
  the review backlog rendered with no pagination). A `full_page=True` capture of a ~53-
  megapixel image does NOT honour its timeout — it WEDGES the browser until the OS kills
  the process (EPIPE). One tall page took down the whole sweep.
- **Plan impact:** This was NOT a code regression — it's **data growth** (the review
  backlog piled up to ~120 items, pushing /approvals past the un-screenshottable
  threshold). The sweep's stated job as a regression guard worked; the tool just wasn't
  antifragile to it. Fixed in-scope with `_safe_shot()`: measure scrollHeight, clip
  pages > 8000px to the top 8000px (`clip=`), fall back to viewport on any error, and
  record the capture mode per row so the report/gallery flag the tall page instead of
  aborting. Applied to the sweep AND the `capture()` content-page shots (same wedge
  risk). Verified: sweep now completes (verdict PASS, 5/5 carry theme); report shows
  `/approvals → ⚠️ clipped @36938px`; all 5 frames present.
- **Triggered:** Filed **T-2038** — /approvals renders 37k px because the review queue
  has no pagination/virtualization (the real page bug; sibling to T-2035 cockpit perf).
  Captured `feedback_playwright_fullpage_wedge` to memory (reusable Playwright gotcha).

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

## Recommendation

**Recommendation:** GO

**Rationale:** All 4 Agent ACs pass with executed-browser evidence. The sweep extends the
arc's first-pass review tool to cover the whole headline mechanic and now stands as a
regression guard for the S2-S6 redesign slices. Net finding is reassuring: the T-2003
bridge fix holds app-wide — every page already carries the picked palette. Only the human
taste call (does each page *look* consistently themed) remains.

**Evidence:**
- `bin/fw ux-review --sweep` → **5/5 pages carry the theme**: `/`, `/tasks`, `/approvals`,
  `/fabric`, `/arcs` all show `--pico-primary == --wt-accent == #b87a17` under Bone
- Per-page table in `docs/reports/T-2002-ux-review-arc-007-s0-s1.md`; 5 gallery frames
  `sweep-*.png` for visual review
- `--content-pages "/,/arcs"` proves the custom-list parse path; `--axes` and the preset
  capture unaffected (back-compat)
- Overall verdict CONCERN(1) = the **pre-existing** Editorial/linen contrast only; sweep
  contributed zero broken pages
- Gallery: http://192.168.10.107:3000/static/ux-review/index.html

## Updates

### 2026-05-23T15:14:04Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2005-arc-007-ux-review-multi-page-theme-sweep.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-dd506d44
- **Timestamp:** 2026-06-02T15:00:48Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
