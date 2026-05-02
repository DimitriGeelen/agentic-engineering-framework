---
id: T-1693
name: "Ship baseline workflow files (default + inception/grilling/design-dialogue marked inline)"
description: >
  Ship the four baseline workflow files per CONTEXT.md (Q12): .context/project/workflows/default.yaml (TermLink + sonnet + medium + standard tools), inception.yaml + grilling.yaml + design-dialogue.yaml (all marked inline: true). Operator can override by editing these files. Build task — content is fully spec'd in CONTEXT.md, no scoping decisions remain.

status: captured
workflow_type: build
owner: agent
horizon: now
tags: [arc:orchestrator-rethink]
components: []
related_tasks: [T-1687]
created: 2026-05-02T22:56:11Z
last_update: 2026-05-02T22:56:11Z
date_finished: null
---

# T-1693: Ship baseline workflow files (default + inception/grilling/design-dialogue marked inline)

## Context

Ship four baseline workflow YAML files at `.context/project/workflows/` per CONTEXT.md (Q12 + ADR-0002): `default.yaml` (TermLink + sonnet + medium + standard tools — fallback for any task_type without an explicit file), and `inception.yaml` / `grilling.yaml` / `design-dialogue.yaml` (all `inline: true` — interactive task_types that must never dispatch). Operator overrides by editing. Content fully spec'd in CONTEXT.md.

## Acceptance Criteria

### Agent
- [ ] `.context/project/workflows/default.yaml` exists, parses as valid YAML, has all required fields per CONTEXT.md schema (`task_type`, `worker_kind: TermLink`, `model`, `effort`, `prompt_template`, `allowed_tools`, `cost_cap_usd`, `cwd`)
- [ ] `.context/project/workflows/inception.yaml` exists with `task_type: inception` + `inline: true`
- [ ] `.context/project/workflows/grilling.yaml` exists with `task_type: grilling` + `inline: true`
- [ ] `.context/project/workflows/design-dialogue.yaml` exists with `task_type: design-dialogue` + `inline: true`
- [ ] All four files parse cleanly via `python3 -c "import yaml; yaml.safe_load(open(...))"`
- [ ] Once T-1694 lands, `fw doctor` lints all four clean

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
python3 -c "import yaml; yaml.safe_load(open('.context/project/workflows/default.yaml'))"
python3 -c "import yaml; yaml.safe_load(open('.context/project/workflows/inception.yaml'))"
python3 -c "import yaml; yaml.safe_load(open('.context/project/workflows/grilling.yaml'))"
python3 -c "import yaml; yaml.safe_load(open('.context/project/workflows/design-dialogue.yaml'))"
grep -q "inline: true" .context/project/workflows/inception.yaml
grep -q "inline: true" .context/project/workflows/grilling.yaml
grep -q "inline: true" .context/project/workflows/design-dialogue.yaml
grep -q "worker_kind: TermLink" .context/project/workflows/default.yaml

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

### 2026-05-02T22:56:11Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1693-ship-baseline-workflow-files-default--in.md
- **Context:** Initial task creation
