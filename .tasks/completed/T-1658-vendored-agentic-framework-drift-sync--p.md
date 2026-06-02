---
id: T-1658
name: "Vendored .agentic-framework/ drift sync — pull T-1620, T-1626/T-1627/T-1628, T-1542 fixes from upstream lib/ into .agentic-framework/lib/"
description: >
  The framework dogfoods consumer mode via .agentic-framework/. Upstream lib/inception.sh, lib/upgrade.sh, lib/verify-acs.sh have been changed since last vendor (e50b96bc2 'T-012: Resync vendored .agentic-framework/'). New file lib/hook-telemetry.sh (T-1628) is missing from the vendored copy. Hygiene resync — run fw vendor or copy 4 files manually. Low-risk; reversible.

status: work-completed
workflow_type: refactor
owner: agent
horizon: null
tags: [hygiene, vendoring, dogfood, framework-self-fix]
components: [.agentic-framework/lib/inception.sh, .agentic-framework/lib/upgrade.sh, .agentic-framework/lib/verify-acs.sh, .agentic-framework/lib/hook-telemetry.sh]
related_tasks: [T-1620, T-1626, T-1627, T-1628, T-1542, T-012]
created: 2026-05-01T16:39:49Z
last_update: 2026-05-01T16:48:01Z
date_finished: 2026-05-01T16:48:01Z
---

# T-1658: Vendored .agentic-framework/ drift sync — pull T-1620, T-1626/T-1627/T-1628, T-1542 fixes from upstream lib/ into .agentic-framework/lib/

## Context

The framework dogfoods consumer-mode by maintaining a vendored copy at `.agentic-framework/`. Upon inspection (T-1658 start), the working tree showed the four files already byte-identical to upstream — a prior `fw vendor` run had synced them but never committed. This task simply pins that synced state, with verification that each file matches upstream and that audit/doctor checks pass.

## Acceptance Criteria

### Agent
- [x] `.agentic-framework/lib/inception.sh` is byte-identical to `lib/inception.sh`
- [x] `.agentic-framework/lib/upgrade.sh` is byte-identical to `lib/upgrade.sh`
- [x] `.agentic-framework/lib/verify-acs.sh` is byte-identical to `lib/verify-acs.sh`
- [x] `.agentic-framework/lib/hook-telemetry.sh` is byte-identical to `lib/hook-telemetry.sh`
- [x] All four files are tracked in git (no untracked vendored files)

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

diff -q lib/inception.sh .agentic-framework/lib/inception.sh
diff -q lib/upgrade.sh .agentic-framework/lib/upgrade.sh
diff -q lib/verify-acs.sh .agentic-framework/lib/verify-acs.sh
diff -q lib/hook-telemetry.sh .agentic-framework/lib/hook-telemetry.sh

# Shell commands that MUST pass before work-completed. One per line.
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

### 2026-05-01T16:39:49Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1658-vendored-agentic-framework-drift-sync--p.md
- **Context:** Initial task creation

### 2026-05-01T16:40:18Z — status-update [task-update-agent]
- **Change:** horizon: now → next
- **Change:** status: started-work → captured (auto-sync)

### 2026-05-01T16:47:02Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-36ade7fc
- **Timestamp:** 2026-06-02T14:58:56Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-01T16:48:01Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
