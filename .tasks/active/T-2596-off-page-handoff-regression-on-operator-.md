---
id: T-2596
name: "Off-page handoff regression on operator surface — reproduce + RCA"
description: >
  Off-page handoff regression on operator surface — reproduce + RCA

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: []
components: [tests/web/test_designer_landing.py, web/templates/designer_landing.html]
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
created: 2026-07-22T05:39:13Z
last_update: 2026-07-22T05:59:00Z
date_finished: 2026-07-22T05:59:00Z
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
  - ts: '2026-07-22T05:45:05Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-07-22T05:45:08Z'
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
---

# T-2596: Off-page handoff regression on operator surface — reproduce + RCA

## Context

Operator reports (2026-07-22, 3rd recurrence of the off-page class): "THE HANDOFF IS STILL NOT WORKING — EVEN WORSE THE ONE EXAMPLE THAT WAS WORKING HAS REGRESSED." The known-good example is the T-2589-verified path: /designer landing card aef-task-lifecycle v2 → off-page handoff node → jump lands aef-dispatch-loop. Initial live probe reproduces a state where the browser's `aefAutosaveDoc` holds `{src: /api/version?id=aef-task-lifecycle&v=2, id: aef-dispatch-loop}` — jump-follow appears to poison the autosave (content swapped, recorded src not updated), so the same-src deep-link later restores the WRONG diagram. Prior RCAs: T-2584 (visibility), T-2589 (entry-point shadowing / B1 autosave).

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] Regression reproduced mechanically on the operator's default entry path (Playwright, live :3001), with the exact failing state captured (localStorage autosave record + rendered diagram id vs deep-linked id) — captured: `aefAutosaveDoc {id: aef-dispatch-loop, src: /api/version?id=aef-task-lifecycle&v=2}`; rendered `metaId: aef-dispatch-loop` under URL `?load=...aef-task-lifecycle&v=2`
- [x] RCA written in ## RCA: root cause named at the code line(s) in the load/jump/autosave precedence chain, and why T-2589's fix did not cover it
- [x] Fix implemented on OUR surface only (vendored 0.3.0 bundle stays byte-pinned READ-ONLY) — `web/templates/designer_landing.html`: click-time nonce inside the load value + `hx-boost="false"` (first fix attempt was silently discarded by htmx boost — live-disproven, then corrected)
- [x] Post-fix live re-verify: fresh browser AND poisoned-autosave browser both land the correct diagram for card deep-link + jump both directions (task-lifecycle→dispatch-loop via tl_handoff_dispatch, inception-flow→task-lifecycle via if_handoff_tl); post-jump re-entry (the exact regression loop) lands the correct map; pinned by `tests/web/test_designer_landing.py::test_card_links_mint_clicktime_nonce`

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

- [ ] [REVIEW] The regressed example works again in YOUR browser (which holds the poisoned autosave state this bug is about)
  **Steps:**
  1. Open http://192.168.10.107:3001/designer
  2. Click "Open in editor →" on the **AEF task lifecycle** card
  3. Confirm the diagram shown IS the task lifecycle (look for the "Handoff →" node near the dispatch edge)
  4. Double-click the "Handoff →" node — it should open the dispatch-orchestration loop
  5. Go back to http://192.168.10.107:3001/designer and click the **AEF task lifecycle** card again
  **Expected:** Step 3 and step 5 BOTH show the task-lifecycle diagram (step 5 is the exact spot that regressed — it used to silently show the dispatch loop); step 4 lands the dispatch loop
  **If not:** Note which step showed the wrong diagram + hard-refresh (Ctrl+Shift+R) once and retry; if still wrong, reopen this task — the fix did not cover your browser state

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
out=$(curl -s "$(bin/fw watchtower url)/designer"); grep -q 'hx-boost="false"' <<< "$out"
out=$(curl -s "$(bin/fw watchtower url)/designer"); grep -q "Date.now()" <<< "$out"

## RCA

**Symptom:** Operator's known-good example (T-2589-verified: /designer card "AEF task lifecycle" → handoff node → jump lands dispatch loop) regressed: clicking the card silently rendered the dispatch-orchestration loop (or whatever map was last jumped to) instead of the task lifecycle, so the expected handoff node "wasn't there" — perceived as "handoff still not working, the working example regressed."

**Root cause (two layers):**
1. **In-bundle (832's 0.3.0, root):** `jumpToWorkflow` (vendor/designer/aef-workflow-designer-0.3.0.html:6535) switches maps **in-place** (`loadFromLibrary` / `openProjectMap`) without touching the URL's `?load`. `autosaveNow` (:8412) records `src: currentLoadSrc()` — so every post-jump autosave persists `{content: JUMPED-TO map, src: original card deep-link}`. `autoLoadStored` (:8437) restores whenever stored src === current `?load` (with `_suppressDeepLink=true`), so the next entry via the SAME card silently renders the wrong map. The jump working once is what breaks the card thereafter — self-poisoning.
2. **Our layer (first fix attempt, disproven live):** an inline `onclick` nonce-minter alone did NOT work — the landing renders inside an `hx-boost` container and htmx 2.0.4 boosted anchors navigate off htmx's cached href, silently discarding the onclick's href mutation. `hx-boost="false"` on the card links is load-bearing.

**Why structurally allowed:** T-2589's fix relied on B1's src-comparison staying in sync with document content — the jump violates that invariant, and T-2589's Playwright verification was a single pass on a fresh profile that never re-entered via the same card AFTER a jump (the poisoning needs the jump→re-entry sequence). The bundle is a read-only vendored artifact, so its B1×jump interaction sat outside our test surface.

**Prevention:** (a) `test_card_links_mint_clicktime_nonce` pins both the nonce-minter and `hx-boost="false"` per card; (b) rail escalation to 832 for the in-bundle root fix in 0.3.1 (key the autosave by active map id, or update the recorded src on in-place map switch); (c) learning: UI flows must be verified across RE-ENTRY sequences (enter → act → re-enter), not single-pass — state written by the first pass is part of the surface under test.

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

## Recommendation

**Recommendation:** GO

**Rationale:** The regression was reproduced live on first attempt, root-caused to a two-layer interaction (in-bundle B1 autosave src-keyed restore self-poisoning after `jumpToWorkflow` switches maps in-place, plus an htmx-boost swallowing the first onclick-only counter-fix), and the fix was live-verified across both browser states (fresh and poisoned) and both jump directions, including the exact post-jump re-entry sequence that caused the original regression. A regression test (`test_card_links_mint_clicktime_nonce`) pins the fix. The remaining Human AC only asks the operator to re-confirm the fix in their own already-poisoned browser session — no further agent work is possible on that AC since it exercises state private to their browser.

**Evidence:**
- `tests/web/test_designer_landing.py` — 5/5 passing, including the pinning test
- Live verify: `curl -s "$(bin/fw watchtower url)/designer" | grep -q 'hx-boost="false"'` and `Date.now()` nonce both present
- RCA section names exact in-bundle line numbers (vendor/designer/aef-workflow-designer-0.3.0.html:6535, 8412, 8437) and why T-2589's single-pass verification missed the re-entry sequence
- In-bundle root cause escalated to 832 for their 0.3.1 fix (our fix is a counter-measure on our surface only, per the byte-pinned vendored bundle constraint)

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

- 2026-07-22: Operator confirmed in chat: **"2 works"** — the landing-card flow (this task's fix) verified personally by the operator. The [REVIEW] tick remains with the operator (T-1731 guard): one tap at /review/T-2596. Note: the "handoff node back does not work" part of the same message was a SEPARATE corpus gap (dispatch-loop had no return handoff at all) — fixed as T-2600 (v3 authored, round-trip live-verified).

### 2026-07-22T05:39:13Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2596-off-page-handoff-regression-on-operator-.md
- **Context:** Initial task creation

### 2026-07-22T05:52:00Z — reproduced, fixed, live-verified [agent]
- **Action:** Reproduced the regression on the live surface first try (poisoned `aefAutosaveDoc` rendered dispatch-loop under the task-lifecycle deep-link). RCA'd to jump-follow poisoning B1's src-keyed autosave restore (in-bundle, lines 6535/8412/8437). Shipped our-layer counter in `designer_landing.html`: click-time nonce inside the load value + `hx-boost="false"` (the first onclick-only attempt was silently eaten by htmx boost — caught live, corrected). Watchtower restarted on :3001 (note: `fw watchtower restart` DROPPED the port and tried :3000 default — observation filed separately).
- **Verification:** tests/web 115 passed, 2 expected skips; live Playwright: poisoned browser + card → correct map; jump both directions (tl_handoff_dispatch, if_handoff_tl); post-jump re-entry (the regression loop) → correct map; fresh profile → correct map.
- **Context:** 3rd operator recurrence of the off-page class (T-2584 visibility, T-2589 entry shadowing, T-2596 jump poisoning) — each a different layer of the same B1 autosave interaction.

## Reviewer Verdict (v1.5)

- **Scan ID:** R-81fc5144
- **Timestamp:** 2026-07-22T05:59:03Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#3 (Agent)** — Fix implemented on OUR surface only (vendored 0.3.0 bundle stays byte-pinned READ-ONLY) — `web/templates/designer_landing.html`: click-time nonce inside the load value + `hx-boost="false"` (first fix 
  - **AC-verify-mismatch** (narrow, heuristic) — `path=web/templates/designer_landing.html in: Fix implemented on OUR surface only (vendored 0.3.0 bundle stays byte-pinned READ-ONLY) — `web/templates/designer_landing.html`: click-time nonce insi`

### 2026-07-22T05:59:00Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
