---
id: T-1834
name: "Purge MS_OAUTH client secret from framework git history — filter-repo commit 79e3361 (T-1828 follow-up, Tier 0)"
description: >
  Follow-up to T-1828 mirror-unstick. Secret (Azure AD OAuth client secret originally from 050-email-archive .env) is embedded in framework git history at commit 79e3361 (T-1736: Spike B), file .context/spikes/T-1736-prompts.jsonl line 1581. The file was removed from HEAD in commit 7fba568e7 but remains in history. GitHub secret-scanning blocks push of any commit range containing 79e3361. Plan: git filter-repo --invert-paths --path .context/spikes/T-1736-prompts.jsonl, then force-push to BOTH OneDev (origin) and GitHub. Tier 0 — requires explicit human approval before history rewrite. All framework consumers must re-clone or hard-reset after force-push. Sequence with: (a) verify MS_OAUTH_CLIENT_SECRET rotated in 050-email-archive Azure app first (b) snapshot current refs to .git/refs-backup (c) filter-repo (d) force-push origin (e) force-push github (f) notify consumers via framework:pickup. Blocks T-1828 closure.

status: captured
workflow_type: build
owner: agent
horizon: next
tags: [bug, fw-upgrade-incident-2026-05-14, security, tier0, git-history, follow-up]
components: []
related_tasks: []
created: 2026-05-14T20:42:14Z
last_update: 2026-05-14T20:42:14Z
date_finished: null
---

# T-1834: Purge MS_OAUTH client secret from framework git history — filter-repo commit 79e3361 (T-1828 follow-up, Tier 0)

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [ ] [First criterion]
- [ ] [Second criterion]

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

### 2026-05-14T20:42:14Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1834-purge-msoauth-client-secret-from-framewo.md
- **Context:** Initial task creation
