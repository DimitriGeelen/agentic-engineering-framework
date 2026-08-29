---
id: T-3218
name: "landing-mode v4: a 200 is not evidence the page was read"
description: >
  The landing-mode prompt says 'curl every URL for a 200 before printing it'. Followed
  literally that is insufficient and produced a false green this run: curl -o FILE
  reports the transfer's HTTP status via -w %{http_code} even when it cannot write
  the body. Measured: /tmp/.pg was a foreign file (owner dimitri-mint-dev, Aug 27,
  left by project 1023-portable-encrypted-chromium-vault); curl printed http=200 with
  its own exit code 23 (write error); the stale foreign page stayed on disk; five
  approval links verified 'OK' against another project's inception page, and the 404
  control also 'passed' at 87500B identical. Reproduced deterministically. The framework's
  documented idiom is NOT affected because it chains on curl's exit (curl -sf ...
  -o f && grep -q PAT f short-circuits on rc 23) - the defect is in the prompt's wording,
  which names the status code rather than the exit code.

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
arc_id: continuous-run
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
created: 2026-08-29T15:21:02Z
last_update: 2026-08-29T15:23:25Z
date_finished: 2026-08-29T15:23:25Z
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
  - ts: '2026-08-29T15:21:33Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-3218: landing-mode v4: a 200 is not evidence the page was read

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] `policy/prompts/landing-mode.md` is v4: the revision table gains a row naming what this run measured, consistent with the file's own rule that each version records a measurement rather than an opinion.
- [x] §The Prompt's operator-actions rule names the FETCHER'S EXIT CODE rather than the status code, gives the working shape, and requires a deliberately-bad control that must fail.
- [x] A `## What v4 changes` section records the measurement verbatim — the commands, curl's rc 23, the foreign file's owner and date — so the claim is checkable rather than asserted.
- [x] The section states explicitly that the framework's documented `curl -sf … && grep` idiom was NOT affected, so the fix is not mistaken for a repo-wide defect.
- [x] The v3 prompt text is superseded in place, not appended to — a prompt carrying both the old and new rule would leave the wrong one quotable.

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

grep -q 'prompt (v4)' policy/prompts/landing-mode.md
grep -q "| v4 | T-3218 |" policy/prompts/landing-mode.md
grep -q "FETCHER'S EXIT CODE" policy/prompts/landing-mode.md
grep -q '## What v4 changes' policy/prompts/landing-mode.md
grep -q 'CURLE_WRITE_ERROR' policy/prompts/landing-mode.md
grep -q 'documented idiom was never affected' policy/prompts/landing-mode.md
test "$(grep -c 'curl every URL for a 200 before printing it' policy/prompts/landing-mode.md)" -eq 0
curl -sf "$(bin/fw watchtower url)/review/T-3204" -o /tmp/.t3218v && grep -q 'T-3204' /tmp/.t3218v


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

### 2026-08-29T15:21:02Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3218-landing-mode-v4-a-200-is-not-evidence-th.md
- **Context:** Initial task creation

### 2026-08-29T15:21:32Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-2832d204
- **Timestamp:** 2026-08-29T15:23:28Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-08-29T15:23:25Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
