---
id: T-1903
name: "audit-warn + fw task archive-eligible sweep — catch stuck-partial-complete
  after Human-AC re-class (L-403)"
description: >
  audit-warn + fw task archive-eligible sweep — catch stuck-partial-complete after
  Human-AC re-class (L-403)

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: [C-004, bin/fw, tests/unit/task_archive_eligible.bats]
related_tasks: []
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-18T18:39:58Z
last_update: '2026-06-11T22:24:02Z'
date_finished: 2026-05-18T18:58:02Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:02Z'
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
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=2
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=0 
      (no-signal); F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); 
      F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1903: audit-warn + fw task archive-eligible sweep — catch stuck-partial-complete after Human-AC re-class (L-403)

## Context

L-403 captured the class: tasks set to `work-completed` with Human ACs at the time → moved to active/ with `owner: human` (partial-complete). Later, a re-class operation (T-1894/T-1897 pattern: [REVIEW] → [REVIEWER] under ### Agent) drains those Human ACs to zero. The partial-complete recheck does not re-fire — the task sits in active/ with all checkboxes ticked, indistinguishable from real pending-review tasks until someone re-runs `--status work-completed` on it.

T-1890 was found this way during arc-grooming closure-prep sweep (this session). It was the 4th of 4 tasks re-classed by T-1894; the other three (T-1851, T-1857, T-1893) had been archived via separate flows before the trap could fire on them. T-1890 was the only one stuck.

Two-prong fix:
1. **`fw audit`** gains a structure-check that counts active/ tasks with `status: work-completed` AND zero unchecked checkboxes (HTML-comment-stripped). Reports WARN when count > 0 with file list.
2. **`fw task archive-eligible`** new verb: for each such task, re-runs the partial-complete recheck and moves the now-eligible ones to completed/. Idempotent. Safe to schedule.

The audit catches the state; the sweep clears it.

## Acceptance Criteria

### Agent
- [x] `agents/audit/audit.sh` (or wherever structure-checks live) gains a check that scans `.tasks/active/T-*.md` for `status: work-completed` files whose Acceptance Criteria section, after HTML-comment strip, contains zero `- [ ]` checkboxes. WARN when count > 0, lists task files, mitigation: `bin/fw task archive-eligible`.
- [x] `bin/fw task archive-eligible` new sub-verb in `lib/task.sh`. For each archive-eligible task (same detection as audit check), re-invokes the partial-complete recheck branch of `update-task.sh` (the existing line ~941 logic). Idempotent — running on an empty set is a no-op exit 0.
- [x] `bats tests/unit/task_archive_eligible.bats` covers: (a) detects a synthetic stuck task (active/, status work-completed, all ACs ticked, owner: human), (b) moves it to completed/ after sweep, (c) no-op when no stuck tasks, (d) leaves real partial-completes (with unchecked Human ACs) alone.
- [x] `fw audit` includes the new check; running `bin/fw audit 2>&1 | grep -q "archive-eligible\|stuck partial-complete"` returns 0 when the check is present (PASS or WARN — either is fine; absence is the failure mode).
- [x] [REVIEWER] Audit check WARN message names the mitigation (`bin/fw task archive-eligible`) on the same line as the count, not in a separate block. Verified by inspection of `agents/audit/audit.sh` CTL-029 warn() call — the WARN line itself contains "run: bin/fw task archive-eligible".

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

bats tests/unit/task_archive_eligible.bats
test "$(bin/fw audit 2>&1 | grep -cE 'archive-eligible|stuck.partial-complete')" -ge 1
bin/fw task archive-eligible --dry-run 2>&1 | grep -qE 'no .*stuck|0 task.* eligible|sweep'
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

### 2026-05-18T18:39:58Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1903-audit-warn--fw-task-archive-eligible-swe.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-e50b9673
- **Timestamp:** 2026-06-02T15:00:23Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 3
     - evidence: `bin/fw task archive-eligible --dry-run 2>&1 | grep -qE 'no .*stuck|0 task.* eligible|sweep'`
### 2026-05-18T18:58:02Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
