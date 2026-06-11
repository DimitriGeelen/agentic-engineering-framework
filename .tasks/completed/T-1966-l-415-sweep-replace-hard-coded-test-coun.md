---
id: T-1966
name: "L-415 sweep: replace hard-coded test counts in 4 task ## Verification blocks
  (T-1909/T-1928/T-1929/T-1930)"
description: >
  L-415 sweep: replace hard-coded test counts in 4 task ## Verification blocks (T-1909/T-1928/T-1929/T-1930)

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: [verification, brittle-test, L-415-followup, arc:bvp]
components: []
related_tasks: []
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-20T19:12:54Z
last_update: '2026-06-11T22:24:04Z'
date_finished: 2026-05-20T19:15:49Z
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
  - ts: '2026-05-20T19:15:01Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-05-20T19:15:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:24:04Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=0 
      (no-signal); F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); 
      F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1966: L-415 sweep: replace hard-coded test counts in 4 task ## Verification blocks (T-1909/T-1928/T-1929/T-1930)

## Context

L-415: hard-coded test counts in task `## Verification` blocks break across sibling task additions (test_bvp_estimator.py grew 17→28→43 across T-1922/T-1923/T-1935; T-1922 and T-1923 closures hit it). 4 known remaining: T-1909, T-1928, T-1929, T-1930 — each greps for a literal "N passed" string that grows out from under them.

Sweep replaces with a count-agnostic pattern:
`grep -qE '[0-9]+ passed' <<<"$out" && ! grep -qE '[0-9]+ failed' <<<"$out"`

Here-string dodges SIGPIPE under pipefail (L-387). Accepts any positive count, refuses any failed count.

## Acceptance Criteria

### Agent
- [x] T-1909 verification: `grep -q "4 passed"` replaced with count-agnostic regex (line 122)
- [x] T-1928 verification: `grep -q "5 passed"` replaced with count-agnostic regex (line 69)
- [x] T-1929 verification: `grep -c '8 passed'` replaced with count-agnostic regex (line 68)
- [x] T-1930 verification: `grep -c '7 passed'` replaced with count-agnostic regex (line 66)
- [x] Detector sweep clean: scan returns 0 instances of the brittle pattern (`grep -qE '[0-9]+ passed' .tasks/active/T-{1909,1928,1929,1930}-*.md` matches 4 updated lines; `grep -E "grep[[:space:]]+-[qc]?[[:space:]]*['\"][0-9]+ passed"` on the same 4 returns nothing)

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

grep -q "grep -qE '\[0-9\]+ passed'" .tasks/active/T-1909-render-arcid-badge-on-task-surfaces--fin.md
grep -q "grep -qE '\[0-9\]+ passed'" .tasks/active/T-1928-bvp-watchtower-bvp-static-scatter-read-only.md
grep -q "grep -qE '\[0-9\]+ passed'" .tasks/active/T-1929-bvp-watchtower-bvp-live-sliders-commit-spli.md
grep -q "grep -qE '\[0-9\]+ passed'" .tasks/active/T-1930-bvp-watchtower-arcsid-extensions-bvp-displa.md
! grep -E "grep[[:space:]]+-[qc]?[[:space:]]*['\"][0-9]+ passed" .tasks/active/T-1909-*.md .tasks/active/T-1928-*.md .tasks/active/T-1929-*.md .tasks/active/T-1930-*.md

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

### 2026-05-20 — Scope was 4 tasks; corpus search found exactly 4
- **What changed:** Filing assumed 4 known instances. The corpus-wide detector (`grep -rE '[0-9]+ passed' .tasks/active/T-*.md`) returned 9 hits, but 5 of those were narrative mentions in body text (e.g., "10 passed in 0.05s" in T-1701's commit-evidence section), not commands in `## Verification` blocks. Only the original 4 needed fixing.
- **Plan impact:** None — confirms scope was correctly bounded. Adds a refinement to the detector: future scans should filter by `grep -E "grep[[:space:]]+-[qc]?[[:space:]]*['\"][0-9]+ passed"` to target Verification commands specifically rather than any "N passed" string.
- **Triggered:** No new task. Pattern recorded in L-415's `application` field via this Evolution entry.

## Recommendation

**Recommendation:** GO

**Rationale:** L-415 sweep complete. 4 brittle verification commands replaced with count-agnostic regex (`[0-9]+ passed` + `! [0-9]+ failed`). Detector confirms zero remaining instances of the old pattern in Verification blocks. Pattern survives sibling task additions (test files growing) and is SIGPIPE-safe (here-string per L-387).

**Evidence:**
- 4 lines edited: T-1909:122, T-1928:69, T-1929:68, T-1930:66
- Detector clean: `grep -E "grep[[:space:]]+-[qc]?[[:space:]]*['\"][0-9]+ passed"` returns 0 hits across the 4 task files
- L-415 captured for future authors

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

### 2026-05-20T19:12:54Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1966-l-415-sweep-replace-hard-coded-test-coun.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-1736c23f
- **Timestamp:** 2026-06-02T15:00:40Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-20T19:15:49Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
