---
id: T-1660
name: "G-015 Option B: PreToolUse hook to redirect /tmp/fw-agent-*.md sub-agent writes through fw bus post"
description: >
  Companion task to T-1645 GO Option A. T-1645 narrowed T-1061's G-015 claim to 'partial mitigation' via the bus protocol convention. Structural closure requires a PreToolUse hook that intercepts Write/Bash tool calls touching /tmp/fw-agent-*.md and redirects them through 'fw bus post --task T-XXX'. Three feasibility paths to evaluate: (a) FUSE overlay on /tmp/, (b) Linux user namespace + bind-mount, (c) Claude Code PreToolUse hook reading the Write file_path and rejecting if it matches /tmp/fw-agent-*.md (with hint to use fw bus post). Path (c) is by far the cheapest. Inception first, design afterwards. Closes G-015 fully when shipped.

status: work-completed
workflow_type: inception
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-05-01T17:18:21Z
last_update: 2026-05-02T08:39:55Z
date_finished: 2026-05-02T08:39:55Z
---

# T-1660: G-015 Option B: PreToolUse hook to redirect /tmp/fw-agent-*.md sub-agent writes through fw bus post

## Context

Companion to T-1645 (which shipped G-015 Option A — the bus protocol
convention as partial mitigation). T-1660 explores Option B: a PreToolUse
hook that intercepts `Write`/`Bash` tool calls writing to
`/tmp/fw-agent-*.md` and redirects them through `fw bus post --task T-XXX`.

Three feasibility paths considered:
- (a) FUSE overlay on `/tmp/`
- (b) Linux user namespace + bind-mount
- (c) Claude Code PreToolUse hook reading Write `file_path` and rejecting
      on match (with hint to use `fw bus post`)

Path (c) is far the cheapest. Inception first; design afterwards.
Closes G-015 fully when shipped.

## Acceptance Criteria

### Agent
<!-- @auto-tick-on-decide -->
- [x] Problem statement validated (Option A vs B trade-off articulated)
<!-- @auto-tick-on-decide -->
- [x] Three feasibility paths evaluated (FUSE / namespace / PreToolUse hook)
<!-- @auto-tick-on-decide -->
- [x] Recommendation written with promotion criteria for re-watching

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

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# The completion gate runs each command — if any exits non-zero, completion is blocked.
#
# Toolchain hint (L-291): if you edited *.vbproj/*.csproj/*.xaml add `dotnet build`;
# *.go → `go build ./...`; Cargo.toml → `cargo check`; tsconfig.json → `tsc --noEmit`;
# pom.xml → `mvn -q compile`. P-011 runs only what you write — broken builds slip
# past otherwise (origin: 003-NTB-ATC-Plugin T-077, broken WPF DLL on master 5 days).

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

## Recommendation

**Recommendation:** DEFER

**Rationale:** T-1645 already shipped Option A (bus protocol convention) as partial G-015 mitigation. Option B (PreToolUse hook) is the structural closure — cheaper than FUSE/namespaces (Path c is far the cheapest of the three feasibility paths) but currently unjustified: the partial mitigation is in place, and no observed bypass of bus convention has produced lost results. Promotion criteria: ≥1 incident where a sub-agent writes to /tmp/fw-agent-*.md and the result is lost to context compaction, OR Option A coverage gap measured ≥10% of dispatch results. Until then, this remains parked.

**Evidence:**
- T-1645 work-completed (bus protocol convention is the documented path; preamble.md updated)
- Path c (Claude Code PreToolUse hook reading Write file_path + rejecting on /tmp/fw-agent-*.md match) is the cheapest of three explored options
- No observed loss incidents since T-1645 shipped (2026-05-01)

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

**Decision**: DEFER

**Rationale**: Recommendation: DEFER

Rationale: T-1645 already shipped Option A (bus protocol convention) as partial G-015 mitigation. Option B (PreToolUse hook) is the structural closure — cheaper than FUSE/namespaces (Path c is far the cheapest of the three feasibility paths) but currently unjustified: the partial mitigation is in place, and no observed bypass of bus convention has produced lost results. Promotion criteria: ≥1 incident where a sub-agent writes to /tmp/fw-agent-.md and the result is lost to context compaction, OR Option A coverage gap measured ≥10% of dispatch results. Until then, this remains parked.

Evidence:
- T-1645 work-completed (bus protocol convention is the documented path; preamble.md updated)
- Path c (Claude Code PreToolUse hook reading Write file_path + rejecting on /tmp/fw-agent-.md match) is the cheapest of three explored options
- No observed loss incidents since T-1645 shipped (2026-05-01)

**Date**: 2026-05-02T08:39:23Z

## Updates

### 2026-05-01T17:18:21Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1660-g-015-option-b-pretooluse-hook-to-redire.md
- **Context:** Initial task creation

### 2026-05-01T17:18:47Z — status-update [task-update-agent]
- **Change:** horizon: now → later
- **Change:** status: started-work → captured (auto-sync)

### 2026-05-01T17:18:47Z — status-update [task-update-agent]
- **Change:** workflow_type: build → inception

### 2026-05-02T08:35:39Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: later → now (auto-sync)

### 2026-05-02T08:39:23Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** DEFER
- **Rationale:** Recommendation: DEFER

Rationale: T-1645 already shipped Option A (bus protocol convention) as partial G-015 mitigation. Option B (PreToolUse hook) is the structural closure — cheaper than FUSE/namespaces (Path c is far the cheapest of the three feasibility paths) but currently unjustified: the partial mitigation is in place, and no observed bypass of bus convention has produced lost results. Promotion criteria: ≥1 incident where a sub-agent writes to /tmp/fw-agent-.md and the result is lost to context compaction, OR Option A coverage gap measured ≥10% of dispatch results. Until then, this remains parked.

Evidence:
- T-1645 work-completed (bus protocol convention is the documented path; preamble.md updated)
- Path c (Claude Code PreToolUse hook reading Write file_path + rejecting on /tmp/fw-agent-.md match) is the cheapest of three explored options
- No observed loss incidents since T-1645 shipped (2026-05-01)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-eda46f65
- **Timestamp:** 2026-06-02T14:58:57Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-02T08:39:55Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
