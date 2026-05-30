---
id: T-2117
name: "/arcs/<slug> scoped-driver display consistency — humanized name + slug across approved + proposed sections"
description: >
  User-reported on screenshot: 'please be consistent in also showing labels / names of arc drivers'. Currently arc_detail.html shows approved scoped drivers as <code>name</code> (monospace) and proposed scoped drivers as <strong>name</strong> (bold) — inconsistent styling. Arc-scoped drivers do NOT get F-ids on approval (they stay in scoped_drivers: with only the kebab name as identifier), so the /bvp 'F1 — Antifragility' pattern cannot literally apply. Closest faithful fit: show humanized title (e.g. 'Aesthetic Cohesion') alongside the kebab slug (e.g. 'aesthetic-cohesion') in BOTH approved and proposed sections. Mirrors T-2080's spirit: human-readable label next to canonical id.

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: [watchtower, bvp, ui, arc-006, arc-007]
components: [web/templates/arc_detail.html]
related_tasks: [T-2080, T-1926]
arc_id: watchtower-redesign
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-30T18:36:14Z
last_update: 2026-05-30T18:39:31Z
date_finished: 2026-05-30T18:39:31Z
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

# T-2117: /arcs/<slug> scoped-driver display consistency — humanized name + slug across approved + proposed sections

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] `arc_detail.html` approved scoped-drivers Name column renders `<strong>{Humanized Name}</strong> <code class="muted">{kebab-slug}</code>` (or equivalent two-tier markup).
- [x] `arc_detail.html` proposed scoped-drivers heading renders the same two-tier markup so both sections read consistently at a glance.
- [x] Humanization: kebab-case `aesthetic-cohesion` → title-cased "Aesthetic Cohesion" via Jinja `replace('-', ' ')|title` filter (no Python-side change required).
- [x] Rendered `/arcs/value-prioritisation` carries the new markup (curl + grep on known scoped drivers — Aesthetic Cohesion / Estimator Fidelity / Sovereignty Preservation all confirmed present).

### Human
- [ ] [REVIEW] Open `/arcs/value-prioritisation`. Both the "Scoped drivers" table (top) and the "Proposed scoped drivers" section (below the Add-custom-driver form) should show the same two-tier display: humanized title + muted kebab slug.
  **Steps:**
  1. Open http://192.168.10.107:3000/arcs/value-prioritisation
  2. Compare the "Scoped drivers" table's Name column with the "Proposed scoped drivers" cards' headers
  **Expected:** Same pattern in both — bold humanized title with the kebab slug rendered in muted monospace next to it. Reads like 'Aesthetic Cohesion `aesthetic-cohesion`'.
  **If not:** Screenshot the inconsistency; the Jinja filter may have rendered differently for one section.

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

grep -q 'T-2117' web/templates/arc_detail.html
grep -q "replace('-', ' ')|title" web/templates/arc_detail.html
curl -sf "$(bin/fw watchtower url)/arcs/value-prioritisation" > /tmp/.t2117-page.html && grep -q 'Aesthetic Cohesion\|Estimator Fidelity\|Sovereignty Preservation' /tmp/.t2117-page.html

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

### 2026-05-30 — user-chosen format collided with framework data model

- **What changed:** User selected "Mirror /bvp pattern with assigned ID" expecting `F1 — name`. On implementation, confirmed via `lib/arc.sh:1168` that arc-scoped drivers never get F-ids — they live in `scoped_drivers:` with only `name`/`weight`/`approved_at`. The /bvp `Fn — name` pattern applies to GLOBAL free drivers, which are a different storage shape.
- **Plan impact:** Pivoted from literal F-id rendering to "humanized title + muted kebab slug", which preserves the user's intent (consistency + readable label) within the existing data model. Documented this adaptation explicitly in the `## Decisions` section so the choice is auditable.
- **Triggered:** Possible follow-up inception — "should arc-scoped drivers get F-ids on approval?" — would require scoping F-id collision/scope-bound vs global semantics. Captured here, not filed.

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

**Rationale:** User asked for consistency between approved and proposed scoped-driver displays. Both sections now render identically: bold humanized title + muted kebab slug. Jinja-only change (no Python data-model modification); no DB migration; reversible by template edit.

**Evidence:**
- Patch: `web/templates/arc_detail.html` — two locations updated (approved table, proposed cards) with matching markup + cross-referenced T-2117 forensic comments.
- Verification: all 3 commands pass — code has T-2117 + filter + page renders humanized names.
- Live: `curl /arcs/value-prioritisation | grep "Aesthetic Cohesion"` returns hits across both sections.

**Adaptation note:** The user picked "Mirror /bvp pattern with assigned ID" expecting `F1 — name`. The framework does not assign F-ids to arc-scoped drivers (they live in `scoped_drivers:` with `name:` as canonical id, no F-id mapping). The shipped fit is the closest faithful translation: humanized title + kebab slug, applied consistently. If the user wants F-id assignment on approval, that's a deeper data-model change (`scoped_drivers:` schema + `fw arc approve-driver` + policy/value-drivers.yaml integration) — would be a separate inception.

## Decisions

### 2026-05-30 — Why humanized-title + kebab-slug instead of F-id

- **Chose:** Humanized title (`Aesthetic Cohesion`) + muted kebab slug (`aesthetic-cohesion`), applied identically to approved + proposed sections.
- **Why:** Arc-scoped drivers don't get F-ids in the framework's data model (verified in `lib/arc.sh:1168` approve-driver — appends to `scoped_drivers:` with only name/weight/timestamp). The user's chosen "F1 — name" preview cannot literally be implemented without redesigning scope-driver storage. This adaptation preserves the user's intent (consistency + human-readable label) within the existing data model.
- **Rejected:** Adding F-id assignment in `fw arc approve-driver` and updating policy/value-drivers.yaml — too large a change for an immediate user-visible fix; would need its own inception to scope data-model implications (F-id collision between arcs? scope-bound vs global F-counter?).

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

### 2026-05-30T18:36:14Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2117-arcsslug-scoped-driver-display-consisten.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-231303d5
- **Timestamp:** 2026-05-30T18:39:32Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-05-30T18:39:31Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
