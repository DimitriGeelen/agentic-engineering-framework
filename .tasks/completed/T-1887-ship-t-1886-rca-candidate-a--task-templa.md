---
id: T-1887
name: "ship T-1886 RCA Candidate A — task-template hint to remind .claude/settings.json editors to refresh enforcement baseline + L-398 learning"
description: >
  ship T-1886 RCA Candidate A — task-template hint to remind .claude/settings.json editors to refresh enforcement baseline + L-398 learning

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: [arc-grooming, prevention, governance]
components: [.tasks/templates/default.md, .context/project/learnings.yaml]
related_tasks: [T-1886, T-1849, T-1730, T-1731, T-1687]
arc_id: arc-grooming
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-17T20:35:18Z
last_update: 2026-05-17T20:38:03Z
date_finished: 2026-05-17T20:38:03Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
---

# T-1887: ship T-1886 RCA Candidate A — task-template hint to remind .claude/settings.json editors to refresh enforcement baseline + L-398 learning

## Context

T-1886 RCA identified three prevention candidates (A/B/C) for the enforcement-baseline drift class — the omission that allowed three legitimate hook additions (T-1849/T-1730/T-1731) to land without a baseline refresh, leaving `fw doctor` in FAIL for unknown duration. Candidate A is the lightest: add a one-line reminder to the task template's `## Verification` comment block, alongside the existing L-291 (toolchain) and L-387 (pipefail) hints, so any future task editing `.claude/settings.json` is nudged to include `bin/fw enforcement baseline` in its Verification.

Captures the learning as L-398 with explicit "if you edited X, add Y" pattern matching the L-291 style.

## Acceptance Criteria

### Agent
- [x] L-398 added to `.context/project/learnings.yaml` (enforcement-baseline-drift class, with prevention pattern)
- [x] `.tasks/templates/default.md` `## Verification` comment block extended with the new hint, citing L-398 / T-1886 in the L-291 style
- [x] `learnings.yaml` parses cleanly (`python3 -c "import yaml; yaml.safe_load(open(...))"`)
- [x] Template file is otherwise unchanged (single-purpose edit)

### Human
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
     Remove this section if all criteria are agent-verifiable.
     Each criterion MUST include Steps/Expected/If-not so the human can act without guessing.
     Optionally prefix with [RUBBER-STAMP] or [REVIEW] for prioritization.
     Example:
       - [ ] [REVIEW] Dashboard renders correctly
         **Steps:**
         1. Open https://example.com/dashboard in browser
         2. Verify all panels load within 2 seconds
         3. Check browser console for errors
         **Expected:** All panels visible, no console errors
         **If not:** Screenshot the broken panel and note the console error
-->

## Verification

python3 -c "import yaml; data=yaml.safe_load(open('.context/project/learnings.yaml')); ids=[l['id'] for l in data['learnings']]; assert 'L-398' in ids, 'L-398 missing'; print('L-398 present')"
grep -q "L-398" .tasks/templates/default.md
grep -q "fw enforcement baseline" .tasks/templates/default.md

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

### 2026-05-17 — closes T-1886 RCA Candidate A loop
- **What changed:** T-1886 surfaced three prevention candidates (A/B/C) in its RCA. Candidate A is the lightest — task-template hint in the L-291 style. Shipped immediately here rather than parking it, since the edit footprint is tiny (one comment paragraph + one learning entry) and the next hook-authoring task benefits.
- **Plan impact:** B (PostToolUse nudge on `.claude/settings.json` edits) and C (pre-push block on baseline drift) remain in reserve. If L-398's textual hint proves insufficient (recurrence detected), the next slice can ship B or C with L-398 as evidence that the lightest path failed.
- **Triggered:** No new sub-task. L-398 is the captured learning; the template hint is the deployment.

## Recommendation

**Recommendation:** GO — task ready for `--status work-completed`.

**Rationale:** Smallest meaningful prevention slice from T-1886's RCA candidate set. Four deterministic ACs all ticked: L-398 added to learnings, template hint added in the L-291 / L-387 style, YAML parses cleanly (431 learnings total), template footprint is single-purpose. Matches the same hint-pattern that already exists for toolchain and pipefail — future hook-authoring tasks will see the reminder in the very file they're filling in.

**Evidence:**
- `.context/project/learnings.yaml` — L-398 entry, source: P-011, task: T-1887, application: ship — task template extended
- `.tasks/templates/default.md` — new comment block "Enforcement-baseline hint (L-398, T-1886)" with copy-pasteable command `bin/fw enforcement baseline`
- `yaml.safe_load` → 431 learnings (was 430)
- Verification commands all pass (`grep -q "L-398"`, `grep -q "fw enforcement baseline"`)

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

### 2026-05-17T20:35:18Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1887-ship-t-1886-rca-candidate-a--task-templa.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-290f4cd6
- **Timestamp:** 2026-06-02T15:00:17Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-17T20:38:03Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
