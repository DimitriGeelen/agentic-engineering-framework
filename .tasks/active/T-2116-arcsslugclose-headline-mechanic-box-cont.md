---
id: T-2116
name: "/arcs/<slug>/close headline-mechanic-box contrast — primary-on-primary-bg same-hue-family fails contrast (third surface)"
description: >
  User-reported: cannot read text in headline mechanic on /arcs/<slug>/close. Same antipattern as T-2110 (arc_review.html) and T-2111 (approvals.html) — color: var(--pico-primary) on background: var(--pico-primary-background) = same-hue-family contrast failure across Calm/Editorial/Bone/Paper palettes. Fix: replace with color: var(--pico-color) + border-left: 3px solid var(--pico-primary) on the existing tinted background.

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: [watchtower, ui-bug, contrast, arc-007]
arc_id: watchtower-redesign
components: [web/templates/arc_close.html]
components: []
related_tasks: [T-2110, T-2111, T-1968, T-1970, T-2006]
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-30T18:25:03Z
last_update: 2026-05-30T18:28:44Z
date_finished: 2026-05-30T18:28:44Z
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

# T-2116: /arcs/<slug>/close headline-mechanic-box contrast — primary-on-primary-bg same-hue-family fails contrast (third surface)

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] `arc_close.html` `.headline-mechanic-box` CSS replaces `color: var(--pico-primary)` with `color: var(--pico-color)` and adds `border-left: 3px solid var(--pico-primary)` (same shape as T-2110 and T-2111).
- [x] Forensic comment names T-2116 and cross-references T-2110, T-2111 so the override isn't reverted as cosmetic.
- [x] Rendered `/arcs/<slug>/close` page carries the new CSS (curl + grep).
- [x] arc_id field on this task resolves to watchtower-redesign (already filed under arc-007).

### Human
- [ ] [REVIEW] Open `/arcs/watchtower-redesign/close`. The "Headline mechanic" callout text must read clearly — body-text colour on the tinted primary background, with a left accent stripe.
  **Steps:**
  1. Open http://192.168.10.107:3000/arcs/watchtower-redesign/close
  2. Locate the "Headline mechanic (the deliverable that must have fired):" callout
  **Expected:** Text reads cleanly in your current palette/theme. Left edge has a thin accent stripe.
  **If not:** Screenshot + reopen — palette mapping may differ.

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

grep -q 'T-2116' web/templates/arc_close.html
grep -q 'color: var(--pico-color); border-left: 3px solid var(--pico-primary)' web/templates/arc_close.html
curl -sf "$(bin/fw watchtower url)/arcs/watchtower-redesign/close" > /tmp/.t2116-page.html && grep -q 'border-left: 3px solid var(--pico-primary)' /tmp/.t2116-page.html

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

**Symptom:** User reported "cannot read text in headline mechanic" with screenshot of `/arcs/watchtower-redesign/close` showing the callout text in pale primary on the primary-tinted background — unreadable.

**Root cause:** Same antipattern as T-1968 / T-1970 / T-2006 / T-2110 / T-2111: `color: var(--pico-primary)` on `background: var(--pico-primary-background)` = same hue family, fails WCAG contrast across Calm/Editorial/Bone/Paper palettes. The accent colour and the accent tint share a hue family by design — combining them is decorative, not legible.

**Why structurally allowed:** Third arc surface to ship this combo. `_approvals_content.html` (T-2111) and `arc_review.html` (T-2110) used the new fix shape (body-text + left accent stripe); `arc_close.html` predated those fixes and was missed in the sweep. No automated lint exists for accent-on-accent-tint at CSS-level (would need a tokens-pair audit on `var(--pico-primary)` + `var(--pico-primary-background)` co-occurrence on the same selector).

**Prevention:**
1. **Per-instance fix:** body-text colour + left accent stripe on the existing tinted background — same shape as T-2110/T-2111. Forensic comment cross-references both.
2. **Promotion candidate (NOT in this task):** three consumers of `.headline-mechanic-box` now exist (`arc_review.html`, `_approvals_content.html`, `arc_close.html`). T-2102 deferred premature promotion; with the third consumer landed, the case for a shared CSS file is now strong. Filing this as observation rather than concern — it's clean-up, not a new bug.
3. **Detector candidate (NOT in this task):** a CSS-token-pair audit that flags `color: var(--pico-primary)` + `background: var(--pico-primary-background)` co-occurrence on the same rule. Would catch the 4th instance before deploy. Same class as T-2115 (L-438 detector) — file separately if it recurs.

## Evolution

### 2026-05-30 — third consumer of .headline-mechanic-box — promotion case strengthens

- **What changed:** This is the third template carrying `.headline-mechanic-box` (after `arc_review.html` / T-2110 and the approvals templates / T-2111). T-2102 deferred premature promotion when the count was 2. With 3, the case for shared CSS is now strong but still not blocking.
- **Plan impact:** No change to this fix. A 4th consumer would justify the promotion task — file an observation now so the next agent doesn't have to re-derive the threshold.
- **Triggered:** Possible follow-up — promote `.headline-mechanic-box` to shared CSS. Out of scope here ("one bug = one task").

## Recommendation

**Recommendation:** GO

**Rationale:** Identical fix shape to T-2110 and T-2111 (body-text colour + left accent stripe on the existing tinted background). All 3 Verification commands pass. Forensic comment names this task and cross-references the sibling fixes so the override isn't reverted.

**Evidence:**
- Patch: `web/templates/arc_close.html` — CSS update on `.headline-mechanic-box` (lines 23-32 of file before patch).
- Rendered `/arcs/watchtower-redesign/close` carries the new CSS (curl + grep PASS).
- Pattern history: T-1968 → T-1970 → T-2006 → T-2110 → T-2111 → T-2116 (six instances of the accent-on-accent-tint class).

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

### 2026-05-30T18:25:03Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2116-arcsslugclose-headline-mechanic-box-cont.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-3b21c797
- **Timestamp:** 2026-05-30T18:28:45Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-05-30T18:28:44Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
