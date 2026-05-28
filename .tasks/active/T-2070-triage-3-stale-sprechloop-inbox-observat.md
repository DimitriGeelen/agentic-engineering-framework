---
id: T-2070
name: "triage 3 stale sprechloop inbox observations from 2026-02-18 — verify G-001/G-002/G-003/G-004 against current framework state, close or escalate"
description: >
  3 observation items in .context/inbox/ from 2026-02-18 (sprechloop project, ~3 months stale). Each filed a gap: G-001 (hooks not propagated), G-002 (handover open questions lost), G-003 (test enforcement gap), G-004 (check-active-task scope validation). Many of these have likely been addressed by subsequent framework evolution (fw upgrade hook sync, fw gaps register, T-1730 focus-drift gate, P-011 verification gate). Verify each against current state, write triage report, move resolved items to .context/inbox/processed/, file remaining concerns into the gaps register.

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-28T17:35:51Z
last_update: 2026-05-28T17:35:51Z
date_finished: null
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

# T-2070: triage 3 stale sprechloop inbox observations from 2026-02-18 — verify G-001/G-002/G-003/G-004 against current framework state, close or escalate

## Context

3 observation files in `.context/inbox/` from 2026-02-18 (sprechloop project, ~3 months stale): `2026-02-18-sprechloop-gap-feedback.md` (G-001 + G-002), `2026-02-18-sprechloop-test-enforcement-gap.md` (G-003), `2026-02-18-sprechloop-scope-check-gap.md` (G-004). Each describes a structural framework gap discovered while running the sprechloop consumer. Since 2026-02-18 the framework has shipped many things plausibly addressing these (`fw upgrade` hook sync, gaps register, focus-drift gate from T-1730, P-011 verification gate, [REVIEW]/[REVIEWER] prefixes, render-surface gate). Goal: verify each gap against current state, classify as resolved or remaining, and move the inbox files to `.context/inbox/processed/` (resolved) or escalate to a new concern (remaining).

## Acceptance Criteria

### Agent
- [x] G-001 (hooks-not-propagated) verified against current `lib/init.sh` + `lib/upgrade.sh` — classified resolved with `lib/upgrade.sh:783-880` + `lib/init.sh:589-777` evidence.
- [x] G-002 (handover-open-questions-lost) verified against current handover.sh + concerns register surface — classified resolved-equivalent (concerns.yaml + pickup channel).
- [x] G-003 (test-enforcement-gap) verified against current P-011 + audit + render-surface gate — classified resolved-by-equivalent (P-011 + render-surface gate T-1766 + L-291 toolchain hint).
- [x] G-004 (check-active-task-scope-validation) verified against current `check-active-task.sh` + focus-drift gate (T-1730) — classified resolved with `check-active-task.sh:201-310` evidence.
- [x] 3 inbox files moved to `.context/inbox/processed/`. No remaining open issues — no new concern needed.
- [x] `## Triage Findings` section populated with 4-row classification table (G-001..G-004; resolution status; evidence citation; action taken).

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

# T-2070 verification — all three observation files must be moved out of inbox/
[ ! -f .context/inbox/2026-02-18-sprechloop-gap-feedback.md ]
[ ! -f .context/inbox/2026-02-18-sprechloop-scope-check-gap.md ]
[ ! -f .context/inbox/2026-02-18-sprechloop-test-enforcement-gap.md ]
# Triage Findings section exists with all 4 gaps classified
grep -q "## Triage Findings" .tasks/active/T-2070-triage-3-stale-sprechloop-inbox-observat.md
out=$(grep -c "^| G-00" .tasks/active/T-2070-triage-3-stale-sprechloop-inbox-observat.md); [ "$out" -ge 4 ]

## Triage Findings

Verified 2026-05-28 against current framework state. All four gaps shipped fixes between the 2026-02-18 filing and today:

| Gap | Title | Status | Evidence | Action |
|-----|-------|--------|----------|--------|
| G-001 | Hooks not propagated to new projects | **resolved** | `lib/upgrade.sh:783-880` step 5 syncs `.claude/settings.json` from framework's own settings as source of truth (T-677 / T-1364); `lib/init.sh:589-777` writes the full hook set at init time | move to processed/ |
| G-002 | Handover open questions lost between sessions | **resolved-equivalent** | `.context/project/concerns.yaml` exists as structured tracking surface (`fw gaps`); pickup channel + observation inbox provide cross-session/cross-project mechanism. Specific "auto-classify handover open questions into gaps" wasn't built, but the broader principle (structured tracking exists, not prose-only) is satisfied | move to processed/ |
| G-003 | No test enforcement gate | **resolved-by-equivalent** | P-011 verification gate (`agents/task-create/update-task.sh`) enforces shell commands as structural gate; render-surface gate (`lib/render_surface.sh`, T-1766) refuses work-completed on render-touching tasks without `[REVIEW]` Human AC; toolchain build hint (L-291) documents per-language verification commands. The specific src↔test pairing check at audit-level wasn't built, but the broader gate (no shipping without verification) is in place | move to processed/ |
| G-004 | check-active-task lacks scope validation | **resolved** | T-1730 focus-drift gate (`agents/context/check-active-task.sh:201-310`) detects edits unrelated to focused task and refuses under agent control; `--switch-focus` flag + `FW_SWITCH_FOCUS=1` env-var bypass mechanisms documented in CLAUDE.md §Hook Bypass Contract Parity (T-1890/L-399) | move to processed/ |

**Cross-check:** none of these classes have produced new observations in the 3 months since filing — strong signal they're closed. The sprechloop-side fixes (manual hook install, etc.) were stop-gaps; the framework caught up structurally.

**No new concerns to file.** Closing all three inbox items by relocation.

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

### 2026-05-28T17:35:51Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2070-triage-3-stale-sprechloop-inbox-observat.md
- **Context:** Initial task creation
