---
id: T-2085
name: "fix double numbering in /bvp driver rubric (T-2084 followup)"
description: >
  fix double numbering in /bvp driver rubric (T-2084 followup)

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: []
components: []
related_tasks: [T-2084]
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-29T08:56:40Z
last_update: 2026-05-29T09:00:01Z
date_finished: 2026-05-29T09:00:01Z
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

# T-2085: fix double numbering in /bvp driver rubric (T-2084 followup)

## Context

T-2084 shipped the 0-5 scoring rubric expand on `/bvp` with both an `<ol start="0">` (which auto-numbers each `<li>` as "0.", "1.", ...) AND an inline `<strong>{{ loop.index0 }}</strong>` prefix inside the `<li>` content (which also renders "0", "1", ...). Result on screen: "0. 0 — …", "1. 1 — …", etc.

Source: `policy/bvp-scoring-rubric.md` uses `| **N** | desc |` table rows (one inline number per row, no list-marker). The display should match: single bold number, em-dash, description — no list marker.

**Fix:** drop the `<ol>` list-marker (switch to `list-style:none` on the `<ol>`, or use `<ul style="list-style:none">`). Keep the inline `<strong>N</strong> —` form because it matches the rubric.md source convention and survives copy-paste.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] `web/templates/bvp.html` rubric `<ol>` no longer emits browser-rendered list markers (either `list-style:none` on the `<ol>` or `<ul>` swap).
- [x] Each rubric line still renders as `**N** — desc` (the inline `<strong>{{ loop.index0 }}</strong>` is preserved).
- [x] No regression on the existing `_driver_rubrics` parse contract — `tests/unit/test_driver_rubrics.py` still green.
- [x] `/bvp` GET still 200; rubric block still present (D1-D4 + F1/F2).

### Human
- [ ] [REVIEW] /bvp rubric expand reads cleanly — one number per line, no "0. 0 — …" double-numbering
  **Steps:**
  1. Open http://192.168.10.107:3000/bvp
  2. Click any driver's `(?)` expand widget (e.g. D1)
  3. Confirm each line shows as `**0** — desc`, `**1** — desc`, … with no preceding list marker
  **Expected:** Single bold number then em-dash; no "0. 0 — …" or "1. 1 — …" repetition
  **If not:** Screenshot the failing driver

<!-- legacy template guidance suppressed for brevity below -->
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
# Enforcement-baseline hint (L-398, T-1886): if you edited `.claude/settings.json`
# (added/removed/reorganised hooks), add `bin/fw enforcement baseline` to your
# Verification block. Otherwise the canonical hash diverges and `fw doctor`
# reports a FAIL ("Enforcement baseline CHANGED") that accumulates silently.
# Origin: T-1849/T-1730/T-1731 each added a legitimate hook without refreshing
# the baseline — FAIL sat for multiple sessions until T-1886 cleaned up.

python3 -m pytest tests/unit/test_driver_rubrics.py -q
curl -sf "$(bin/fw watchtower url)/bvp" -o /tmp/.t2085-vrf
grep -q 'driver-rubric-list' /tmp/.t2085-vrf
! grep -q '<ol start="0"' /tmp/.t2085-vrf
test "$(grep -oE '<strong>[0-9]</strong> —' /tmp/.t2085-vrf | sort -u | wc -l)" -ge 6

## RCA

**Symptom:** /bvp rubric expand widget rendered each line as "0. 0 — desc", "1. 1 — desc", … — the leading "N." was the browser's ordered-list auto-marker on top of the explicit `<strong>N</strong> —` template content.

**Root cause:** T-2084's template used `<ol start="0">` (which produces "0.", "1.", … list markers) AND `<strong>{{ loop.index0 }}</strong> —` (which produces "0 —", "1 —", … as content). Two number sources, both visible.

**Why structurally allowed:** T-2084's Verification commands grepped for the presence of `data-tooltip|<details` markup but did not eyes-on-render the visible-pixel output. The one [REVIEW] Human AC was filed for human eyes-on but the work was committed before the human review landed; the double-number defect lived in the rendered DOM until the user opened the page. UI verification without eyes-on Playwright/screenshot is L-403 territory (T-1575 origin) — grep-only on rendered HTML is necessary but not sufficient.

**Prevention:** Same class as L-403 — when adding numbered/marker list output, either use the list marker OR an inline number, never both. Future detector candidate: lint rule for `<ol|<ul>` containing `loop.index|loop.index0` in a `<strong>`/`<b>` prefix — exact double-numbering anti-pattern. Filed forward, not in scope for this hotfix.

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

## Recommendation

**Recommendation:** GO (complete — Agent ACs ticked; one Human [REVIEW] pending eyes-on)

**Rationale:** One-line CSS fix (swap `<ol start="0">` → `<ul style="list-style:none">`) eliminates the duplicate list-marker. Inline `<strong>N</strong> —` kept because it matches `policy/bvp-scoring-rubric.md`'s source format. T-2084's parse contract is unaffected (6/6 unit tests green). DOM grep confirms zero `<ol start="0">` remains and six `<strong>N</strong> —` markers (N=0..5) per driver block render.

**Evidence:**
- `web/templates/bvp.html:37-43` — `<ol start="0">` → `<ul class="driver-rubric-list" ... list-style:none ...>`
- `python3 -m pytest tests/unit/test_driver_rubrics.py -q` → 6 passed in 0.17s
- `curl /bvp` → 4481 lines; `grep -c driver-rubric-list` → 6; `grep -c '<ol start="0"'` → 0; `grep -oE '<strong>[0-9]</strong> —' | sort -u` → six lines (0-5)

Human eyes-on at http://192.168.10.107:3000/bvp closes the [REVIEW].

## Updates

### 2026-05-29T08:56:40Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2085-fix-double-numbering-in-bvp-driver-rubri.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-a51d8b4d
- **Timestamp:** 2026-05-29T09:00:02Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#1 (Agent)** — `web/templates/bvp.html` rubric `<ol>` no longer emits browser-rendered list markers (either `list-style:none` on the `<ol>` or `<ul>` swap).
  - **AC-verify-mismatch** (narrow, heuristic) — `path=web/templates/bvp.html in: `web/templates/bvp.html` rubric `<ol>` no longer emits browser-rendered list markers (either `list-style:none` on the `<ol>` or `<ul>` swap).`

### 2026-05-29T09:00:01Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
