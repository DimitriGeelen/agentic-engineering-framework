---
id: T-1738
name: "resolver dispatch: --var KEY=VALUE for custom prompt-template substitution
  (T-1737 prep)"
description: >
  T-1737 needs to pass user prompt through dispatch; resolver currently only knows
  TASK_ID/NAME/TYPE/DESCRIPTION/AC. Add --var KEY=VALUE flag (repeatable) to inject
  arbitrary UPPERCASE vars into task_context before _assembled_substitute. Enables
  prompt-triage to receive $PROMPT_UNDER_TRIAGE without overloading TASK_DESCRIPTION.

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: [lib/resolver.py]
related_tasks: [T-1737, T-1733, T-1689]
arc_id: orchestrator-rethink
created: 2026-05-05T07:42:18Z
last_update: '2026-06-11T22:23:57Z'
date_finished: 2026-05-05T07:44:30Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:57Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
      F3: 1
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal); F3=1 (body/components:prompt-incidental); F1=0 (no-signal); 
      F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1738: resolver dispatch: --var KEY=VALUE for custom prompt-template substitution (T-1737 prep)

## Context

T-1733 Spike A surfaced that `$PROMPT_UNDER_TRIAGE` in the prompt-triage workflow renders as
empty because the resolver only knows about the 5 hardcoded task-frontmatter vars (TASK_ID,
TASK_NAME, TASK_DESCRIPTION, TASK_TYPE, ACCEPTANCE_CRITERIA). For a UserPromptSubmit hook to
pass the actual user prompt through, the dispatcher needs a generic injection mechanism.

This task adds `--var KEY=VALUE` (repeatable) to `fw resolver dispatch`. T-1737 (Slice 2) will
consume it from the UserPromptSubmit hook.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] `lib/resolver.py:cmd_dispatch` accepts repeated `--var KEY=VALUE`
- [x] Validates KEY is UPPERCASE matching `[A-Z][A-Z0-9_]*` (rejects lowercase, digits-first, dashes)
- [x] `--var` errors return exit 1 with a clear stderr message, not a stack trace
- [x] Injected vars appear substituted in the rendered prompt blob (verified end-to-end on a real dispatch with `--var PROMPT_UNDER_TRIAGE='hello world'`)
- [x] No regression: existing dispatches without `--var` continue to work (test by re-running the prompt-triage dispatch from T-1733 without `--var`)
- [x] Help text on `bin/fw resolver dispatch --help` documents `--var` with the KEY=VALUE format and an example

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
bin/fw resolver dispatch --help 2>&1 | grep -q -- "--var"
bin/fw resolver dispatch T-1738 prompt-triage --dry-run --var PROMPT_UNDER_TRIAGE="test prompt" 2>&1 | grep -q "dispatch_id"
{ bin/fw resolver dispatch T-1738 prompt-triage --dry-run --var lowercase=bad 2>&1 || true; } | grep -q "UPPERCASE"
{ bin/fw resolver dispatch T-1738 prompt-triage --dry-run --var BADFORMAT 2>&1 || true; } | grep -q "KEY=VALUE"
bin/fw resolver dispatch T-1738 prompt-triage --dry-run 2>&1 | grep -q "dispatch_id"

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

### 2026-05-05 — prompt template double-substitution observed
- **What changed:** With `--var PROMPT_UNDER_TRIAGE="..."`, the rendered blob substitutes the literal twice — once in the explanatory paragraph ("The agent will substitute it into `$PROMPT_UNDER_TRIAGE` below — if that placeholder is the literal string...") and once in the actual placement. The substitution is doing exactly what `VAR_PAT` says: replace every `$PROMPT_UNDER_TRIAGE` token. The prompt template's defensive language about "if that placeholder is the literal string" no longer applies because there's no placeholder — both instances become the literal value.
- **Plan impact:** None for this task (substrate works). Prompt template needs a small cleanup: drop the defensive paragraph since the placeholder always renders. Folded into Spike B (T-1736) scope.
- **Triggered:** prompt-template cleanup note added to T-1736 Evolution.


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

### 2026-05-05T07:42:18Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1738-resolver-dispatch---var-keyvalue-for-cus.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-86dbb738
- **Timestamp:** 2026-06-02T14:59:25Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 6

**Per-AC findings:**

- **AC#1 (Agent)** — `lib/resolver.py:cmd_dispatch` accepts repeated `--var KEY=VALUE`
  - **AC-verify-mismatch** (narrow, heuristic) — `path=lib/resolver.py in: `lib/resolver.py:cmd_dispatch` accepts repeated `--var KEY=VALUE``

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 9
     - evidence: `bin/fw resolver dispatch --help 2>&1 | grep -q -- "--var"`
  2. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 10
     - evidence: `bin/fw resolver dispatch T-1738 prompt-triage --dry-run --var PROMPT_UNDER_TRIAGE="test prompt" 2>&1 | grep -q "dispatch_id"`
  3. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 11
     - evidence: `{ bin/fw resolver dispatch T-1738 prompt-triage --dry-run --var lowercase=bad 2>&1 || true; } | grep -q "UPPERCASE"`
  4. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 12
     - evidence: `{ bin/fw resolver dispatch T-1738 prompt-triage --dry-run --var BADFORMAT 2>&1 || true; } | grep -q "KEY=VALUE"`
  5. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 13
     - evidence: `bin/fw resolver dispatch T-1738 prompt-triage --dry-run 2>&1 | grep -q "dispatch_id"`
### 2026-05-05T07:44:30Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
