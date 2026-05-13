---
id: T-1806
name: "Resolver risk-policy preamble injection (dispatch-safety slice 2)"
description: >
  Resolver risk-policy preamble injection (dispatch-safety slice 2)

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-05-13T15:09:44Z
last_update: 2026-05-13T15:09:44Z
date_finished: null
---

# T-1806: Resolver risk-policy preamble injection (dispatch-safety slice 2)

## Context

Slice 2/5 of the dispatch-safety arc. Teaches the Resolver to inject a baseline risk-policy preamble at the front of every dispatch prompt when the workflow opts in via `allow_pause: true`. Without this, slice 1's substrate recognition is correct but inert — Workers don't know the protocol exists, and no `pause_requested` events will ever be emitted. The preamble instructs Workers to assess severity × likelihood before any irreversible action and emit a `pause_requested` terminal event (per ADR-0004) when the product crosses the workflow's `pause_threshold`. Workers spawn `--bare` (no CLAUDE.md, no hooks), so the envelope is the only governance channel they see; the preamble must live there.

Builds on [T-1805](T-1805) (substrate recognition). Unblocks slice 3 (workflow schema + doctor lint for `pause_threshold` / `allow_pause`).

## Acceptance Criteria

### Agent
- [ ] `lib/resolver.py` exposes a `_risk_policy_preamble(workflow)` function that returns the baseline preamble text. The preamble contains: (a) explicit reference to `pause_requested` as the terminal-event type, (b) the JSON shape for the event, (c) severity/likelihood as the trigger criteria, (d) the workflow's `pause_threshold` value (defaults to `high` when absent), (e) "DO NOT timeout-assume-default" guidance (grid-power rule per ADR-0004).
- [ ] `assemble_prompt(workflow, task_context)` prepends the preamble to the rendered output for all three strategies (static / assembled / meta-prompted) WHEN the workflow has `allow_pause: true`. When `allow_pause` is absent or `false`, no preamble is injected (no behavior change for existing workflows).
- [ ] Per-workflow override: if the workflow defines `pause_preamble: <path>` (path relative to PROJECT_ROOT), the Resolver reads that file as the preamble text instead of the baseline. Falls back to baseline when the path is missing or the file is unreadable (with a warning emitted via stderr).
- [ ] Unit test: workflow with `allow_pause: true` + assembled strategy → rendered prompt starts with the preamble; preamble mentions `pause_requested`, `severity`, `likelihood`, `pause_threshold`, and the rendered prompt body still follows.
- [ ] Unit test: workflow with `allow_pause: false` (or absent) → no preamble injected; rendered prompt is unchanged from the existing T-1689 behavior.
- [ ] Unit test: workflow with `allow_pause: true` + static strategy → preamble prepended to the static template body verbatim.
- [ ] Unit test: workflow with `allow_pause: true` + `pause_preamble: prompts/risk/custom.md` → custom preamble used. Missing file → warning + fallback to baseline.
- [ ] Unit test: `pause_threshold` value from workflow is substituted into the baseline preamble (test with `pause_threshold: medium` → text contains "medium"; with `pause_threshold` absent → text contains "high" as default).
- [ ] No regression in 11 existing `test_resolver_run.py` tests or 50+ assembled-prompt tests.

### Human
- [ ] [REVIEW] Confirm the preamble text strikes the right tone — clear, directive, not preachy; instructs without over-explaining; honors the grid-power rule (no timeout-fallback) explicitly.
  **Steps:**
  1. Read the preamble text in `lib/resolver.py:_risk_policy_preamble` (or call it: `python3 -c "import sys; sys.path.insert(0,'lib'); from resolver import _risk_policy_preamble; print(_risk_policy_preamble({'pause_threshold': 'high'}))"`)
  2. Read it as a Worker would: do you know what to do if you face ambiguity?
  3. Check: does it tell you to pause for trivial uncertainty (bad)? Does it tell you to NOT pause for stylistic preferences (good)?
  **Expected:** Tight, directive text. A Worker reading it understands the protocol in one pass.
  **If not:** Note the lines that read poorly so they can be tightened.

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

# Shell commands that MUST pass before work-completed.

python3 -m pytest tests/unit/test_resolver_run.py tests/unit/test_resolver.py -q 2>&1 | tail -5 || python3 -m pytest tests/unit/ -k resolver -q 2>&1 | tail -5
python3 -c "import sys; sys.path.insert(0, 'lib'); from resolver import _risk_policy_preamble; p = _risk_policy_preamble({'pause_threshold': 'high'}); assert 'pause_requested' in p and 'severity' in p and 'likelihood' in p and 'high' in p, f'preamble missing required content: {p[:200]}'"
python3 -c "import sys; sys.path.insert(0, 'lib'); from resolver import _risk_policy_preamble; p = _risk_policy_preamble({}); assert 'high' in p, 'default pause_threshold should be high'"
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

## Updates

### 2026-05-13T15:09:44Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1806-resolver-risk-policy-preamble-injection-.md
- **Context:** Initial task creation
