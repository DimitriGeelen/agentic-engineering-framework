---
id: T-2589
name: "designer corpus landing page — /designer entry shows corpus cards, deep-link opens server-latest (autosave-shadow fix)"
description: >
  designer corpus landing page — /designer entry shows corpus cards, deep-link opens server-latest (autosave-shadow fix)

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
# demo_target: true               # T-2286: optional — marks task as reserved for an orchestrated demo
#                                 # worker (e.g. arc-010 HM-A dispatches via mcp__fw__work_on). When set,
#                                 # `fw work-on T-XXX` refuses unless --i-am-demo-orchestrator (CLI) or
#                                 # FW_I_AM_DEMO_ORCHESTRATOR=1 (env) is passed. Prevents the parent
#                                 # session from consuming the captured→started-work transition the demo
#                                 # worker expects to drive. Origin OBS-057.
created: 2026-07-21T13:29:34Z
last_update: 2026-07-21T13:37:19Z
date_finished: 2026-07-21T13:37:19Z
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

# T-2589: designer corpus landing page — /designer entry shows corpus cards, deep-link opens server-latest (autosave-shadow fix)

## Context

Operator recurrence #2 of "off-page connectors still not working" (2026-07-21). Live
investigation proved the seam works but the ENTRY POINT shadows it: the vendored 0.3.0
bundle at /designer silently restores the browser's last localStorage draft (B1
autosave) or shows the built-in demo — the operator never sees the server corpus
unless they know to click "📂 Open project…". A stale local draft carries the same
title as the corpus diagram but predates the T-2586 handoff nodes → reads as broken.
Upstream in-editor fix requested from 832 (rail offset 115, T-218-gated). This task is
the AEF-side structural fix: make /designer land on a corpus overview whose links
deep-link the editor at the server's latest version (`?load=` differs from stored
autosave src → deep-link wins over the restore, per bundle line 8434).

Fix: `/designer` → landing page listing corpus projects (from the same project store
as /api/list: id, title, latest v, saved ts, thumbnail placeholder) + card links to
`/designer/app?load=<src>`; `/designer/app` serves the vendored bundle exactly as
/designer does today (pin contract untouched). Existing bundle-relative fetches
(/api/*) are origin-absolute so they keep working from /designer/app.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] `/designer` serves a corpus landing page listing every saved project (id/title, latest version, last-saved time) with per-project "Open in editor" links; `/designer/app` serves the vendored 0.3.0 bundle byte-identical to what /designer served before (served sha256 `36be033d66aa…` == `policy/designer-pin.yaml` sha, verified live on :3001)
- [x] Each landing card's editor link opens the SERVER-LATEST content: live on :3001 — seeded a stale v1 autosave (no handoff) for `aef-task-lifecycle`; `/designer/app` alone restored the stale draft (old failure reproduced), while the landing card's deep-link rendered the v2 `Handoff → dispatch loop` node AND the jump ("↗ Open target workflow") landed on `workflow:aef-dispatch-loop` — shadow defeated end-to-end
- [x] `/designer/ghosts` and all `/api/*` designer endpoints unchanged (ghosts 200; /api/list 8 maps + 1 ghost, live)
- [x] tests/web coverage: `tests/web/test_designer_landing.py` (4 tests: landing lists projects with URL-encoded deep-links, empty-store bundle fallback, /designer/app serves bundle, ghosts regression); full tests/web suite 108 passed

### Human
- [ ] [REVIEW] The new /designer landing makes the corpus obvious and the connectors reachable — this is the fix for your "off-page connectors still not working" report
  **Steps:** 1. Open http://192.168.10.107:3001/designer — you should now see corpus cards (not the editor) 2. On the `aef-task-lifecycle` card click "Open in editor →" — the diagram opens at the latest saved version with the "Handoff → dispatch loop" node 3. Click that node, then "↗ Open target workflow" (or double-click it) — you land in `aef-dispatch-loop`
  **Expected:** the landing reads clean, and the handoff/jump works for you first try with no local-draft surprises
  **If not:** say what you saw at each step (screenshot helps) — especially if step 3 still fails, that would point at something my harness can't reproduce

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

python3 -m pytest tests/web/test_designer_landing.py -q
grep -q "designer/app" web/blueprints/designer.py
grep -q "corpus-open" web/templates/designer_landing.html
curl -sf "$(bin/fw watchtower url)/designer" > /tmp/.t2589-landing.out 2>&1 && grep -q "Workflow Designer" /tmp/.t2589-landing.out
curl -sf "$(bin/fw watchtower url)/designer/app" > /tmp/.t2589-app.out 2>&1 && grep -q "aefAutosaveDoc" /tmp/.t2589-app.out

## RCA

**Symptom:** Operator twice reported "off-page connectors still are not working" after the
seam (T-2571) and corpus content (T-2586) were live-verified working.

**Root cause:** Entry-point shadowing, not the seam. The vendored 0.3.0 bundle at /designer
silently restores the browser's last localStorage draft on open (B1 autosave, wins over the
seed and over same-src ?load). The operator's stale draft carried the same title as the
corpus diagram but predated the handoff nodes — server truth was one un-signposted
"📂 Open project…" click away and never seen.

**Why structurally allowed:** the bundle is pinned read-only (improvements route upstream to
832), and AEF served it directly at the entry URL — so AEF had no surface of its own where
server-side corpus state was visible-by-default. All prior verification went through the
picker path, which never exercises the restore.

**Prevention:** /designer is now an AEF-owned landing page rendering server truth (latest
saved versions) with deep-links that structurally defeat the autosave restore (differing
?load src → deep-link wins, bundle B1 contract). The old behavior remains at /designer/app.
Upstream in-editor fix (stale-restore freshness check) requested from 832 at rail offset 115.
Pinned by tests/web/test_designer_landing.py.

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

**Recommendation:** GO

**Rationale:** The operator's twice-reported "off-page connectors not working" traces to
entry-point shadowing (stale browser autosave under the same title), not the seam. This
ships the AEF-side structural fix within the pin contract: /designer now lands on server
truth and its deep-links defeat the autosave restore; the editor is unchanged at
/designer/app. The failure mode and the fix were both reproduced live in one run.

**Evidence:**
- Old failure reproduced live: seeded stale v1 autosave → /designer/app restored it (no handoff node visible)
- Fix verified live: landing card deep-link → v2 with `Handoff → dispatch loop` → jump lands on `aef-dispatch-loop`
- Bundle untouched: /designer/app sha256 == designer-pin sha; ghosts + /api/* regression-checked live
- tests/web 108 passed incl. 4 new; upstream in-editor fix requested from 832 (rail offset 115)

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

### 2026-07-21T13:29:34Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2589-designer-corpus-landing-page--designer-e.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-abf7ec79
- **Timestamp:** 2026-07-21T13:37:22Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#1 (Agent)** — `/designer` serves a corpus landing page listing every saved project (id/title, latest version, last-saved time) with per-project "Open in editor" links; `/designer/app` serves the vendored 0.3.0 bund
  - **AC-verify-mismatch** (narrow, heuristic) — `path=policy/designer-pin.yaml in: `/designer` serves a corpus landing page listing every saved project (id/title, latest version, last-saved time) with per-project "Open in editor" lin`

### 2026-07-21T13:37:19Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
