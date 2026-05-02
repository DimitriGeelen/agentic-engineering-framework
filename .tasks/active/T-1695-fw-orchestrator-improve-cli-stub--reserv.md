---
id: T-1695
name: "fw orchestrator improve CLI stub — reserve namespace, exit with v2-pending message"
description: >
  Per CONTEXT.md (ADR-0003 v2-readiness): ship a stub 'fw orchestrator improve' that exits 0 with 'v2: not yet implemented; data is being captured at .context/dispatches.jsonl and .context/dispatch-blobs/'. Reserves the CLI namespace so it can't be claimed by an unrelated feature; gives operators visibility into the v2 path. Trivial build task — ~15 lines.

status: captured
workflow_type: build
owner: agent
horizon: now
tags: [arc:orchestrator-rethink, cli]
components: []
related_tasks: [T-1687]
created: 2026-05-02T22:56:20Z
last_update: 2026-05-02T22:56:20Z
date_finished: null
---

# T-1695: fw orchestrator improve CLI stub — reserve namespace, exit with v2-pending message

## Context

Per CONTEXT.md (ADR-0003 v2-readiness): ship `fw orchestrator improve` as a CLI stub that exits 0 with the message "v2: not yet implemented; data is being captured at .context/dispatches.jsonl and .context/dispatch-blobs/". Reserves the namespace so unrelated features can't claim it; gives operators visibility into the v2 self-improvement path. Trivial — ~15 LOC.

## Acceptance Criteria

### Agent
- [ ] `bin/fw orchestrator improve` is wired into the fw command router
- [ ] Running it exits 0
- [ ] Output mentions "v2", "not yet implemented", AND the data paths (`.context/dispatches.jsonl`, `.context/dispatch-blobs/`)
- [ ] Appears in `fw orchestrator --help` (or `fw help orchestrator`) output
- [ ] Does NOT actually read or analyze any dispatch data (it's a stub)

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
bin/fw orchestrator improve | grep -q "v2"
bin/fw orchestrator improve | grep -q "dispatches.jsonl"
bin/fw orchestrator improve

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

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Updates

### 2026-05-02T22:56:20Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1695-fw-orchestrator-improve-cli-stub--reserv.md
- **Context:** Initial task creation
