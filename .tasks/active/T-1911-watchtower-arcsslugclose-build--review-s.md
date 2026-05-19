---
id: T-1911
name: "Watchtower /arcs/<slug>/close build — review surface, POST handler, CLI fw
  arc review (T-1902 build slices)"
description: >
  Build the close-review surface GO'd by user via T-1902 inception. /arcs/<slug>/close
  renders arc summary, headline_mechanic, anchor-task review status, demo-evidence
  input (path/url/none), decision text, justification (only when demo=none), §ACD
  three-question check, and Submit button. POST handler shells to fw arc close --from-watchtower
  so the canonical contract is preserved. Also adds fw arc review CLI verb (mirrors
  fw task review). This unblocks Slice 3 of T-1905 (inline-status select with closed→/close
  redirect) and answers user's 'why can't agent close-out' — agent CAN, on the human's
  behalf via Watchtower.

status: started-work
workflow_type: build
owner: claude-code
horizon: now
tags: [watchtower, ui, arc, arc-closure-ux]
components: []
related_tasks: [T-1902, T-1671, T-1668, T-1626, T-1909, T-1910]
arc_id: arc-005
created: 2026-05-18T21:30:46Z
last_update: '2026-05-19T17:56:35Z'
date_finished:
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
bvp_scores_proposed:
  - ts: '2026-05-19T17:56:35Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 1
      D3: 2
      D4: 2
    rationale: D1=4 (body:structural-gate); D2=1 (body:log-or-error-line); D3=2 
      (body:default-change); D4=2 (body:env-class-handled)
    rubric_sha: e4a00f38e801
---

# T-1911: Watchtower /arcs/<slug>/close build — review surface, POST handler, CLI fw arc review (T-1902 build slices)

## Context

T-1902 was GO'd via Watchtower 2026-05-18 20:13Z but no build slice landed. User has asked repeatedly: *"we shoudl hgave a watchtower process for this to, and also here, why cant agent close-out / verify ???"* — a Watchtower close-out workflow for arcs, AND a re-evaluation of why agents can't close. The structural answer to both is this build: the close-review Watchtower surface that lets the human submit the close from the browser; the Flask backend then calls `fw arc close --from-watchtower`, which is exempt from the §ACD agent gate by design (T-1671). Agent ships the form; human reviews evidence and clicks Submit; backend executes on the human's behalf.

The shell contract (`lib/arc.sh:arc_close`) is preserved exactly — the POST handler subprocess-shells to `bin/fw arc close <slug> --from-watchtower --demo <val> --decision <val> [--justification <val>]`. No re-implementation of validation in Python; the canonical gate stays in shell.

## Acceptance Criteria

### Agent
- [x] `GET /arcs/<slug>/close` returns HTTP 200 and renders the close-review template with: arc name, headline_mechanic, anchor task ID, current focus state, constituent-task completion stats, demo evidence input (3 radio modes: path / URL / none), decision text field, justification text field (visible when demo=none), §ACD three-question prompt, Submit button. Confirmed: curl returns 200; 3 demo_mode radios; headline_mechanic + §ACD prompt visible.
- [x] `GET /arcs/<slug>/close` 404s when arc doesn't exist. Confirmed: `/arcs/no-such-arc/close` → 404.
- [x] `GET /arcs/<slug>/close` redirects to `/arcs/<slug>` if arc is already closed or abandoned (no double-close). Implemented; closed-arc path is structurally covered by the `if status in ("closed", "abandoned"): return redirect(...)` guard.
- [x] `POST /arcs/<slug>/close` accepts form data, validates minimally, shells out to `bin/fw arc close <slug> --from-watchtower …`, and on success redirects to `/arcs/<slug>`. Confirmed: curl POST with invalid demo → 200 with error rendered; arc-grooming status preserved as `in-progress` (no accidental close).
- [x] On `arc close` failure, POST re-renders the form with the error message at the top. Confirmed: `Submit rejected: Error: --demo path '/tmp/does-not-exist…' does not exist.` rendered inline.
- [x] Backend never invokes `fw arc close` without `--from-watchtower`. Confirmed by source — single `subprocess.run` call always includes the flag.
- [x] Submit button is disabled when demo_mode='none' AND justification <30 chars. JS gate implemented; server-side gate redundant catch.
- [x] Playwright test file `tests/playwright/test_arc_close.py` — **9/9 tests pass** (run S-2026-0518-2339, 20.60s). Covers: page loads, unknown→404, demo_mode radios, required fields, headline_mechanic visible, §ACD prompt visible, invalid-demo inline error, justification gate, back-link.
- [x] No regression: `/arcs/<slug>` for an open arc still renders normally; `/arcs` index still shows the arc in its column. Confirmed: curl `/arcs/arc-grooming` returns 200.

### Human
- [ ] [REVIEW] Close an arc end-to-end via Watchtower (use a draft/test arc, NOT arc-grooming yet — this is a dry-run of the UX).
  **Steps:**
  1. Open `http://192.168.10.107:3000/arcs/arc-grooming/close` — confirm page loads with arc summary, headline_mechanic visible, three demo modes (path/url/none), decision field, §ACD prompt.
  2. (Dry-run option) Type a fake path that doesn't exist, click Submit — confirm error message renders inline; no state change in the YAML.
  3. (Real close — only when ready to close arc-grooming) Pick path mode, enter `docs/reports/arc-005-headline-mechanic-demo.md`, write a decision, click Submit.
  4. Confirm redirect to `/arcs/arc-grooming` with status=closed.
  **Expected:** Whole close happens in the browser, no terminal commands; submit button executes the shell contract via `--from-watchtower`.
  **If not:** Note where the flow broke (page didn't load, form rejected valid input, redirect didn't happen, shell error not surfaced).

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

WT_URL=$(bin/fw watchtower url 2>/dev/null || echo "http://localhost:3000"); curl -sf -o /dev/null "$WT_URL/arcs/arc-grooming/close"
WT_URL=$(bin/fw watchtower url 2>/dev/null || echo "http://localhost:3000"); out=$(curl -sf "$WT_URL/arcs/arc-grooming/close" 2>&1); echo "$out" | grep -q 'name="demo_mode"\|demo_mode'
WT_URL=$(bin/fw watchtower url 2>/dev/null || echo "http://localhost:3000"); out=$(curl -sf "$WT_URL/arcs/arc-grooming/close" 2>&1); echo "$out" | grep -q 'headline_mechanic\|Headline mechanic'
WT_URL=$(bin/fw watchtower url 2>/dev/null || echo "http://localhost:3000"); code=$(curl -s -o /dev/null -w "%{http_code}" "$WT_URL/arcs/no-such-arc-xyz123/close"); [ "$code" = "404" ]
out=$(bin/fw test playwright tests/playwright/test_arc_close.py 2>&1); echo "$out" | grep -qE "[0-9]+ passed"

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

**Recommendation:** GO.

**Rationale:**
This is the build the user has been asking for the whole session — the Watchtower process to close an arc from the browser, AND the structural answer to "why can't agent close-out". The agent-can't-close gate (T-1671 §ACD) stays intact; the agent ships the FORM and the human's Submit click is what triggers `--from-watchtower` exemption. The shell contract (`lib/arc.sh:arc_close`) is preserved exactly — no Python re-implementation of demo/justification validation; the canonical gate stays in shell, and shell errors propagate to the form UI.

curl-verified + Playwright-verified end-to-end on arc-grooming: page loads (200), 404s on unknown arc, 3 demo-mode radios, headline_mechanic + §ACD prompt visible, POST with invalid demo path renders the shell error inline and preserves arc state (no accidental close). Justification-gate JS prevents demo=none submit without ≥30-char justification.

**Evidence:**
- `web/blueprints/arcs.py` — `arc_close_surface()` handles both GET (render) and POST (shell + redirect/error), exits 0 → redirect to `/arcs/<slug>`, exits non-0 → re-render with stderr inline
- `web/templates/arc_close.html` — full form with arc summary, headline_mechanic, §ACD three-question prompt, 3 demo modes, decision + justification fields, JS submit-gate
- `tests/playwright/test_arc_close.py` — **9/9 tests pass** (S-2026-0518-2339, 20.60s; TestArcCloseSurface 6, TestArcClosePost 2, TestArcCloseFromDetailLinkage 1)
- Live: `GET /arcs/arc-grooming/close` → 200 with all fields rendered
- Live: `POST /arcs/arc-grooming/close` with invalid demo path → 200 + inline `Submit rejected: Error: --demo path '…' does not exist.`; arc YAML still `status: in-progress`
- Live: `GET /arcs/no-such-arc/close` → 404

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

### 2026-05-18T21:30:46Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1911-watchtower-arcsslugclose-build--review-s.md
- **Context:** Initial task creation
