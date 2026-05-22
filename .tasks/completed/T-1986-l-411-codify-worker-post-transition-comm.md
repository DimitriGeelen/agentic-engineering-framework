---
id: T-1986
name: "L-419 codify worker post-transition commit rule in dispatch preamble"
description: >
  TermLink-dispatched workers exit right after fw bus completion-summary,
  leaving the post-`--status work-completed` frontmatter delta uncommitted.
  Both T-1985 and T-1951 hit this; parent had to sweep + commit. Codify
  in agents/dispatch/preamble.md so future dispatch prompts include the
  rule.

status: work-completed
workflow_type: build
owner: agent
horizon: now
tags: [dispatch, preamble, governance]
components: [agents/dispatch/preamble.md]
related_tasks: [T-1951, T-1985]
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-22T08:54:31Z
last_update: 2026-05-22T09:02:29Z
date_finished: 2026-05-22T09:02:29Z
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
  - ts: '2026-05-22T09:00:01Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-05-22T09:00:02Z'
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

# T-1986: L-411 codify worker post-transition commit rule in dispatch preamble

## Context

Origin: L-419 (captured 2026-05-22 from T-1951 + T-1985 worker dispatches). Both workers
hit the same exit-without-final-commit pattern: shipped their slices, ran
`bin/fw task update --status work-completed`, then exited — but the status/owner/
date_finished delta the transition writes was never committed. Parent had to
sweep + commit. With more TermLink-dispatched workers landing (G-066 prong 2+3,
arc-006 estimator), this pattern will recur.

`agents/dispatch/preamble.md` is the canonical doc included at the top of dispatch
prompts. Adding the "commit the post-transition diff" rule there fixes the next
batch of workers structurally (they'll see it in the preamble) without requiring
every dispatch author to remember.

## Acceptance Criteria

### Agent
- [x] `agents/dispatch/preamble.md` adds a paragraph (under "TermLink Workers — Different Output Rules" section) explaining: after running `bin/fw task update --status work-completed`, the worker MUST `git commit` the resulting frontmatter change before exiting. Cite L-419 + T-1985/T-1951 origin.
- [x] Paragraph includes the concrete pattern: `bin/fw task update T-XXX --status work-completed && git add .tasks/active/T-XXX-*.md && bin/fw git commit -m "T-XXX: work-completed transition"`.
- [x] `bash -n agents/dispatch/preamble.md` — doc has no syntax (n/a for markdown but confirm file readable).
- [x] `wc -l agents/dispatch/preamble.md` shows ≥145 lines (was 140; added 20 — now 160).

## Recommendation

**Recommendation:** GO — three-line doc edit fixes a recurring pattern observed twice in two days.

**Rationale:**
L-419 was captured from the T-1951 + T-1985 worker dispatches earlier today.
Both workers shipped their slice commits cleanly and ran the work-completed
transition, but exited before committing the resulting frontmatter delta —
parent had to sweep + commit both times. With G-066 prong 2+3 just landed,
the BVP estimator already running as TermLink workers, and the dispatch-safety
arc operational, this pattern will recur. Codifying in agents/dispatch/preamble.md
fixes it structurally for every future dispatch author (preamble is included
at the top of every dispatch prompt).

**Evidence:**
- Commit (this task) — agents/dispatch/preamble.md: 140 → 160 lines (+20)
- Origin: L-419 captured 2026-05-22, sourced P-009 (context budget management)
- Repeat sites: T-1985 (slice 7), T-1951 (slice 7) — both exited with uncommitted transition diff
- New "Worker exit protocol" subsection cites both origins inline

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

grep -q "Worker exit protocol" agents/dispatch/preamble.md
grep -q "L-419" agents/dispatch/preamble.md
grep -q "FW_SWITCH_FOCUS=1 bin/fw git commit" agents/dispatch/preamble.md
test $(wc -l < agents/dispatch/preamble.md) -ge 145
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

### 2026-05-22T08:54:31Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1986-l-411-codify-worker-post-transition-comm.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-c81bf1be
- **Timestamp:** 2026-05-22T09:02:30Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-05-22T09:02:29Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
