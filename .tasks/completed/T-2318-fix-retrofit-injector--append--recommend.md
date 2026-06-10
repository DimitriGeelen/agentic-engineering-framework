---
id: T-2318
name: "fix retrofit injector — append ## Recommendation when section missing (OBS-069)"
description: >
  fix retrofit injector — append ## Recommendation when section missing (OBS-069)

status: work-completed
workflow_type: build
owner: agent
horizon: null
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
created: 2026-06-10T16:46:12Z
last_update: 2026-06-10T16:49:12Z
date_finished: 2026-06-10T16:49:12Z
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

# T-2318: fix retrofit injector — append ## Recommendation when section missing (OBS-069)

## Context

OBS-069 (T-2313): T-2121 inception is detected by `find_inceptions_without_recommendation` (correct) but `do_inception_retrofit_recommendations` silently skips it under `--apply` because the injector's regex (`template_pat` + `empty_pat`) only matches a pre-existing `## Recommendation` section. T-2121 has no such section at all (filed pre-T-1716 gate, only 8 sections: Context, AC, Verification, RCA, Evolution, Decisions, Decision, Updates).

OBS-069 hypothesised a status filter (`captured` skipped); verified empirically that hypothesis is wrong — the scanner already iterates every inception regardless of status. The real bug is in the injector's missing-section append path.

## Acceptance Criteria

### Agent
- [x] `lib/inception.sh` injector (around line 957-991) handles missing-section case by APPENDING `## Recommendation\n\n**Recommendation:** <REC>\n\n**Rationale:**\n\n<RAT>\n\n**Evidence:**\n\n<!-- Pre-gate retrofit. Add concrete evidence when re-surfacing. -->\n` to the end of the file (after stripping trailing whitespace), distinct from the existing template-replace + empty-replace paths.
- [x] `bin/fw inception retrofit-rec --apply` mutates T-2121 (after backup), adds `## Recommendation` section with DEFER stub; pre-existing 8 sections preserved; `has_real_recommendation` returns 0 (true) after retrofit.
- [x] `tests/unit/t2318_retrofit_injector_append_missing.bats` exercises three cases (template-present → replace, empty-present → replace, missing → append) and asserts post-state `has_real_recommendation` returns 0 in all three.
- [x] [REVIEWER] Reviewer PASS — `bin/fw reviewer T-2318` returns Overall:.*PASS.

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

bats tests/unit/t2318_retrofit_injector_append_missing.bats
out=$(bin/fw reviewer T-2318 2>&1); echo "$out" | grep -qE "Overall:.*(PASS|CONCERN)" && ! echo "$out" | grep -q "Overall:.*FAIL"

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

**Symptom:** T-2121 (inception filed pre-T-1716 gate) detected by retrofit scanner as missing `## Recommendation`, but `fw inception retrofit-rec --apply` silently leaves it untouched. The retrofit cron `inception-retrofit-rec-hourly` reports work done but T-2121 keeps tripping CTL-027 FAIL ("inception missing Recommendation") in audit.

**Root cause:** Asymmetric coverage between detector and corrector. `find_inceptions_without_recommendation` correctly emits T-2121 (no real Recommendation found). The injector then runs two regexes — `template_pat` (matches `## Recommendation\n<!--…-->`) and `empty_pat` (matches `## Recommendation\n\n`) — both of which REQUIRE the section heading to exist. When the section is entirely missing, both fail to match, and the Python block exits 0 with a `SKIP: …` stderr message swallowed by the surrounding shell loop. Net: detector flags, corrector no-ops, status quo persists.

**Why structurally allowed:** The retrofit corrector was authored to cover the post-T-1716 case (template stub injected by `do_inception_start`); the pre-T-1716 backlog (where `## Recommendation` doesn't exist at all) was out of design scope. No assertion on "every detected task got corrected" closes the symmetry gap. T-2208 (hourly cron) layered on top without re-verifying the corrector covers all scanner emissions.

**Prevention:** A bats test that walks every scanner-emitted task through `--apply` and asserts post-state `has_real_recommendation` returns 0. This pins the detector↔corrector symmetry — any future detector class that the corrector can't handle would fail loudly. See AC #3.

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

### 2026-06-10T16:46:12Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2318-fix-retrofit-injector--append--recommend.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-86cb545e
- **Timestamp:** 2026-06-10T16:49:15Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-06-10T16:49:12Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
