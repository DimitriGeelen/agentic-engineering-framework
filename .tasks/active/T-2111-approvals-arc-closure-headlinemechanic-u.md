---
id: T-2111
name: "/approvals arc-closure headline_mechanic uses .approval-meta — muted on dark,
  unreadable (T-2110 sibling)"
description: >
  User screenshots 2026-05-30 show /approvals 'Arcs ready for review' section rendering
  the arc headline_mechanic as small (0.75rem) muted-color (var(--pico-muted-color))
  italic text — unreadable on dark backgrounds. _approvals_content.html line 235 uses
  class .approval-meta (defined in approvals.html line 40-44). Same content T-2110
  just fixed on /arcs/<slug>/review with the .headline-mechanic-box callout (body
  text + accent stripe on tinted bg). Bring _approvals_content.html to parity: hoist
  headline_mechanic out of .approval-meta into the same callout shape.

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: [watchtower, contrast, arc-007, ui-bug, approvals]
components: [web/templates/_approvals_content.html, web/templates/approvals.html]
related_tasks: [T-2110, T-1968, T-1970, T-2006]
arc_id: watchtower-redesign
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-30T14:42:35Z
last_update: '2026-08-16T22:24:06Z'
date_finished: 2026-05-30T14:46:15Z
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
bvp_scores_proposed:
  - ts: '2026-05-30T14:45:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 2
      D4: 2
      F1: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=2
      (body:default-change); D4=2 (body:env-class-handled); F1=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:23:32Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 2
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 1
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=2
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=0 
      (no-signal); F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); 
      F2=1 (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:06Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 2
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 1
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=2
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=0 
      (no-signal); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal);
      F2=1 (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-05-30T14:45:03Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 2
      effort: 8
    rationale: blast_radius=3 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2111: /approvals arc-closure headline_mechanic uses .approval-meta — muted on dark, unreadable (T-2110 sibling)

## Context

User screenshots 2026-05-30 show `/approvals` "Arcs ready for review" section rendering the arc `headline_mechanic` as small (0.75rem) muted-color italic text on the dark background — visually a *footnote*, but it IS the deliverable the reviewer must judge against. The text the user could not read:

> agent runs fw arc create test → arc-005 sequential ID auto-allocated; agent writes arc_id: arc-005 on a task → save blocks if arc-005 doesn't exist (Tier-1); fw audit reports tag→arc_id parity and 30-day stale-arc warnings; fw arc abandon flips status without deleting YAML — observable: every task has one canonical arc_id resolving to an immutable arc, lifecycle has draft/in-progress/closed/abandoned tabs in Watchtower, 012-ArcSystem.md exists at repo root and FRAMEWORK.md indexes it

CSS today:
- `_approvals_content.html:235` wraps `{{ a.headline_mechanic }}` in `<p class="approval-meta" style="...font-style:italic;...">`
- `approvals.html:40-44` defines `.approval-meta { font-size: 0.75rem; color: var(--pico-muted-color); }`

`.approval-meta` is the right class for true metadata (timestamps, IDs). The `headline_mechanic` is mis-classified — it's the **central reviewer artefact**, not meta.

Fix shape: same callout as T-2110 (`.headline-mechanic-box`), but the styles already live inside `arc_review.html` (template-scoped). Lift the class into a shared place so both surfaces stay in sync, OR re-declare the same callout in `approvals.html`. Re-declare keeps blast radius minimal; promotion to shared CSS waits for a 3rd consumer (per the same "no premature promotion" rule T-2102 applied).

## Acceptance Criteria

### Agent
- [x] `_approvals_content.html` no longer renders the arc `headline_mechanic` inside `.approval-meta`. It uses a callout matching the T-2110 shape: tinted primary background, body-text colour, left accent stripe, italic.
- [x] Callout class is named `.headline-mechanic-box` (same name as T-2110 — keeps grep-discoverable) and declared in `approvals.html` (template-scoped `<style>`); body text + left accent stripe + italic match T-2110 exactly.
- [x] T-2111 forensic comment in the CSS block names the class drift this fixes (referenced from T-2110 RCA prevention paragraph).
- [x] `/approvals` HTTP 200 with `.headline-mechanic-box` present in the body whenever an arc has a `headline_mechanic`.

### Human
- [ ] [REVIEW] `/approvals` "Arcs ready for review" section — headline mechanics now read as full-prominence callouts, not muted footnotes. Visually consistent with `/arcs/<slug>/review`.
  **Steps:**
  1. Open <http://192.168.10.107:3000/approvals> and scroll to the "Arc Closure" section.
  2. Read the headline mechanic for each arc — should appear in a tinted callout box with a primary-coloured left stripe, body text size (not 0.75rem muted).
  3. Click "Review" on one of the arcs and confirm `/arcs/<slug>/review` shows the same callout style (consistency check — same class).
  4. Compare against the captured shot at <http://192.168.10.107:3000/static/ux-review/T-2111-approvals-headline-fixed.png>.
  **Expected:** Both surfaces render the headline mechanic identically — readable, visually weighted as content not metadata.
  **If not:** Note which surface looks wrong and what differs (font size, colour, stripe presence).

<!-- generated template-stub removed by T-2111 -->
<!--
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

grep -q '.headline-mechanic-box' web/templates/approvals.html
grep -q 'class="headline-mechanic-box"' web/templates/_approvals_content.html
! grep -q 'class="approval-meta".*headline_mechanic\|headline_mechanic.*class="approval-meta"' web/templates/_approvals_content.html
grep -q 'T-2111' web/templates/approvals.html
curl -sf "$(bin/fw watchtower url)/approvals" > /tmp/.t2111-page.html && grep -q "headline-mechanic-box" /tmp/.t2111-page.html

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

## RCA

**Symptom:** On `/approvals` "Arcs ready for review" section, the arc `headline_mechanic` text rendered as small (0.75rem) muted-grey italic on a dark background — unreadable in the user's current visual configuration. T-2110 fixed the same content on `/arcs/<slug>/review` but didn't touch this sibling surface.

**Root cause:** `_approvals_content.html` rendered `{{ a.headline_mechanic }}` inside `<p class="approval-meta">`. The `.approval-meta` class (defined in `approvals.html`) is for legitimate metadata (timestamps, IDs) — small + muted is correct for that. But `headline_mechanic` is the central reviewer artefact, not metadata. Wrong CSS class for the role.

**Why structurally allowed:** Class-by-role mis-classification is invisible to grep-based contrast scans. Both the T-2002 ux-review engine's contrast check and the broader contrast sweep (T-1968/T-1970/T-2006) look at *computed token contrast* on rendered surfaces — but the issue here isn't contrast of the token pair; the muted-color/dark-bg pair often passes WCAG. The problem is that the content was given a *visual weight* (small + muted = "footnote") inappropriate for its semantic role (central artefact). No automated check covers semantic-role-vs-visual-weight mismatch.

**Prevention:** Two scopes:
1. **Local:** the class `.headline-mechanic-box` is now grep-discoverable across both surfaces (`arc_review.html` + `approvals.html`). A 3rd consumer that wants the same callout has a clear pattern to copy; if a 4th lands, that's the trigger to promote to shared CSS — same rule T-2102 applied.
2. **Class-level (not filed here per "one bug = one task"):** A heuristic in the T-2002 ux-review engine that flags template `headline_mechanic` / `recommendation` / `rationale` renderings using `.approval-meta` / `.muted` / similar minor-classes. Speculative — needs a 3rd recurrence before the heuristic-write cost is justified.

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

### 2026-05-30 — surface miss caught by user screenshot

- **What changed:** T-2110 only fixed `/arcs/<slug>/review`. The user's screenshots showed the *sibling* surface `/approvals` "Arcs ready for review" rendering the same content as a muted footnote via a different CSS class (`.approval-meta`). One symptom, two surfaces — caught only because the user explicitly screenshotted /approvals. Headline-mechanic visual treatment now consistent across both surfaces.
- **Plan impact:** Same fix shape as T-2110 (`.headline-mechanic-box` callout — body text + accent stripe on tinted bg); declared in `approvals.html` template-scoped style rather than promoted to shared CSS (single-line decl, blast radius minimal, T-2102's "no premature promotion" rule still applies — promote at 3rd consumer).
- **Triggered:** RCA item (2) flagged a heuristic in T-2002 ux-review engine for semantic-role-vs-visual-weight mismatch. Not filed yet — speculative until 3rd recurrence.

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

**Recommendation:** GO

**Rationale:** Same fix shape as T-2110, applied to the sibling surface caught by the user's screenshots. All 4 Agent ACs verified; only the `[REVIEW]` Human AC remains — a taste call on whether both surfaces feel consistent.

**Evidence:**
- `web/templates/approvals.html` — `.headline-mechanic-box` class declared with the canonical shape (body text + left accent stripe + tinted primary background).
- `web/templates/_approvals_content.html` — `<p class="approval-meta">` replaced with `<div class="headline-mechanic-box">` for the headline_mechanic rendering.
- `/approvals` warm render: HTTP 200 with `headline-mechanic-box` present in the body.
- Live screenshot: <http://192.168.10.107:3000/static/ux-review/T-2111-approvals-headline-fixed.png>
- Live page: <http://192.168.10.107:3000/approvals> (scroll to "Arc Closure" section)

**What's next:** Once you tick the `[REVIEW]` AC at <http://192.168.10.107:3000/review/T-2111>, the task moves to `.tasks/completed/`. Per RCA item (2), the broader "headline_mechanic mis-classed as .approval-meta" detector is deferred until a 3rd recurrence justifies the heuristic.

## Updates

### 2026-05-30T14:42:35Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2111-approvals-arc-closure-headlinemechanic-u.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-429fb1cf
- **Timestamp:** 2026-05-30T14:46:20Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-05-30T14:46:15Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
