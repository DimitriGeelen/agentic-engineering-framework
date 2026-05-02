---
id: T-1694
name: "fw doctor extensions — pi-installed check (Q13) + workflow schema linter (Q14)"
description: >
  Extend fw doctor to (Q13) report 'pi not installed; workflows declaring worker_kind: pi will fail' with install command, no auto-install — and (Q14) lint all .context/project/workflows/*.yaml for schema correctness: required fields per tier, worker_kind in enum, prompt_template resolves to existing file, meta_model set iff prompt_strategy=meta-prompted, inline:true exclusive of dispatch fields, soft-warn if default.yaml missing. Build task — ACs are clear from CONTEXT.md.

status: captured
workflow_type: build
owner: agent
horizon: now
tags: [arc:orchestrator-rethink, doctor]
components: []
related_tasks: [T-1687]
created: 2026-05-02T22:56:15Z
last_update: 2026-05-02T22:56:15Z
date_finished: null
---

# T-1694: fw doctor extensions — pi-installed check (Q13) + workflow schema linter (Q14)

## Context

Per CONTEXT.md (Q13/Q14): extend `fw doctor` to (Q13) report "pi not installed; workflows declaring `worker_kind: pi` will fail" with the install command — **no auto-install** — and (Q14) lint all `.context/project/workflows/*.yaml` for schema correctness: required fields per tier, `worker_kind` in `{Task, TermLink, pi}`, `prompt_template` resolves to an existing file, `meta_model` set iff `prompt_strategy=meta-prompted`, `inline: true` exclusive of dispatch fields, soft-warn if `default.yaml` missing.

## Acceptance Criteria

### Agent
- [ ] `fw doctor` reports "pi not installed" when the `pi` binary is absent from PATH (test by temporarily renaming pi or running on a clean host)
- [ ] `fw doctor` does NOT auto-install pi — only warns and prints the install command
- [ ] `fw doctor` lints every file matching `.context/project/workflows/*.yaml`
- [ ] A deliberately broken workflow file (missing required field) produces an error with file path + key reference
- [ ] `fw doctor` exits 0 when all workflow files are valid AND optional dependencies (pi) are present
- [ ] `fw doctor` exits non-zero when at least one workflow file fails schema validation
- [ ] `fw doctor` warns (does not error) when `default.yaml` is missing
- [ ] `fw doctor` flags `inline: true` co-existing with dispatch fields (`worker_kind`, `model`, etc.) as a schema error

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
bin/fw doctor 2>&1 | tail -50
test -d .context/project/workflows && bin/fw doctor 2>&1 | grep -qE "(workflow|pi)" || true

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

### 2026-05-02T22:56:15Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1694-fw-doctor-extensions--pi-installed-check.md
- **Context:** Initial task creation
