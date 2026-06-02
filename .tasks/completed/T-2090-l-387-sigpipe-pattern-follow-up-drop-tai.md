---
id: T-2090
name: "L-387 SIGPIPE pattern follow-up: drop tail-3 middle pipe from verification"
description: >
  Reviewer (T-1443) flagged 4 l387-sigpipe-risk CONCERN findings on T-2088 + T-2089
  Verification: the pattern 'out=$(cmd); echo "$out" | tail -3 | grep -qE PAT' re-introduces
  SIGPIPE risk via the middle pipe even though the capture-first part was correct.
  Safe pattern from L-387 hint is single-pipe: 'echo "$out" | grep -qE PAT' (grep
  scans whole captured string; tail-3 was cosmetic). Fix: amend Verification in both
  closed tasks, update task default template hint to call out 'single pipe only —
  no intermediate tail/awk/sed stages'.

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: []
related_tasks: [T-2088, T-2089, T-2057]
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-29T10:20:36Z
last_update: 2026-05-29T10:24:01Z
date_finished: 2026-05-29T10:24:01Z
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
  - ts: '2026-05-29T10:20:45Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled)
    rubric_sha: e4a00f38e801
---

# T-2090: L-387 SIGPIPE pattern follow-up: drop tail-3 middle pipe from verification

## Context

Reviewer agent flagged 4 `l387-sigpipe-risk` CONCERN findings across T-2088 (2) and T-2089 (2),
plus surfaced a wider authoring gap: the L-387 hint in the task default template documents the
safe single-pipe pattern but doesn't explicitly forbid the `out=$(cmd); echo "$out" | tail -3 | grep -qE`
shape, which I just shipped twice. The middle `tail -3` re-introduces pipe-SIGPIPE risk under
`set -eo pipefail` even though the `$(cmd)` capture closed off the original stdin race.

Smallest fix: amend the four Verification lines in T-2088 + T-2089 to drop the middle pipe
(`echo "$out" | grep -qE ...`) and update the L-387 hint to call out "single pipe only — no
intermediate tail/awk/sed stages between capture and grep".

## Acceptance Criteria

### Agent
- [x] **A1** T-2088 Verification: two `out=$(...); echo "$out" | tail -3 | grep -qE ...` lines
  converted to `out=$(...); echo "$out" | grep -qE ...` (single-pipe safe variant). Verified:
  both `T-2088 v1 OK` and `T-2089 v1 OK` print on direct run.
- [x] **A2** T-2089 Verification: same conversion applied to its one verification line plus
  inline comment noting the single-pipe rule and T-2090 origin.
- [x] **A3** Reviewer re-scan: T-2088 CONCERN(3)→CONCERN(1) (remaining finding is unrelated
  AC-verify-mismatch advisory, not L-387); T-2089 CONCERN(1)→**PASS** (no findings).
  L-387 SIGPIPE risk cleared on both Verification blocks.
- [x] **A4** `.tasks/templates/default.md` L-387 hint extended with verbatim block: "Single pipe
  only — no intermediate tail/awk/sed stages between capture and grep (T-2090): \`echo \"\$out\"
  | tail -3 | grep -q PAT\` re-introduces the SIGPIPE risk the capture step closed off …".
  Future tasks created from this template will see the warning at authoring time.

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

# T-2090 verification — single-pipe pattern itself; meta-test that the fix uses
# the very pattern it's documenting.
# Both task files must have ZERO `tail -3 | grep` occurrences after the cleanup.
out=$(grep -c "tail -3 | grep" .tasks/active/T-2088-parametrized-route-height-guard-sample-a.md 2>&1); echo "$out" | grep -qE "^0$"
out=$(grep -c "tail -3 | grep" .tasks/active/T-2089-revieweroverrides-renders-8628px--10th-u.md 2>&1); echo "$out" | grep -qE "^0$"
# Template hint must contain the new "Single pipe only" warning line.
out=$(grep -c "Single pipe only" .tasks/templates/default.md 2>&1); echo "$out" | grep -qE "^1$"

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

**Recommendation:** GO — close at Agent-AC boundary; no Human ACs (mechanical text fix
plus template hint update; nothing visual or subjective).

**Rationale:** Reviewer surfaced 4 `l387-sigpipe-risk` CONCERNs across T-2088 + T-2089 the
moment they shipped. Closing them clears the immediate concerns and updates the template
hint so the next agent authoring Verification doesn't repeat the pattern. Antifragility loop:
reviewer (T-1443) catches, agent fixes, template prevents recurrence.

**Evidence:**
- `.tasks/templates/default.md` L-387 hint extended with "Single pipe only" warning block
- T-2088 Verification single-pipe: `out=$(...); echo "$out" | grep -qE "9 passed"` (was `... | tail -3 | grep ...`)
- T-2089 Verification single-pipe: same shape (was `... | tail -3 | grep ...`)
- `bin/fw reviewer T-2089` post-fix: PASS (0 findings, was CONCERN/1)
- `bin/fw reviewer T-2088` post-fix: CONCERN(1) — single remaining finding is unrelated
  `AC-verify-mismatch` advisory on the AC text path mention (not L-387)
- `grep -c "tail -3 | grep" .tasks/active/T-208[89]-*.md` → 0 (both)

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

### 2026-05-29T10:20:36Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2090-l-387-sigpipe-pattern-follow-up-drop-tai.md
- **Context:** Initial task creation

### 2026-05-29T10:20:45Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-da5376d4
- **Timestamp:** 2026-06-02T15:01:03Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-29T10:24:01Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
