---
id: T-1728
name: "post-compact budget injection: warn agent that prior budget assertions are
  stale + cite live gauge path"
description: >
  post-compact budget injection: warn agent that prior budget assertions are stale
  + cite live gauge path

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: [post-compact, context-recovery, budget-gate]
components: [agents/context/post-compact-resume.sh]
related_tasks: [T-1087, T-1088, T-179, T-188, T-111]
created: 2026-05-04T22:00:07Z
last_update: 2026-05-28T15:22:07Z
date_finished: 2026-05-28T15:22:07Z
bvp_scores_proposed:
  - ts: '2026-05-19T18:27:45Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-05-19T21:45:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 4
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=4 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1728: post-compact budget injection: warn agent that prior budget assertions are stale + cite live gauge path

## Context

After /compact, the SessionStart:compact hook (`agents/context/post-compact-resume.sh`) injects handover content verbatim into the fresh session. The handover's Suggested First Action or narrative often contains budget-state assertions baked into it at handover time — e.g. "Budget at 92%, stopping new work" — which were TRUE at the moment the handover was written but are STALE the instant the new session starts (the budget gauge has been reset by the hook at line 47-49 to `{ok, 0, now}`). The agent reads the injected handover, sees the stale assertion, and may falsely defer to it ("the prior session said budget was 92%, I should stop"). T-1087 + T-1088 already fixed the cache-side of this class (seed `.budget-status` with `{ok,0,now}` + write fresh `.session-start-ts`); what's missing is a one-line note in the injected context that explicitly tells the agent "these prior budget statements are stale; consult the live gauge".

## Acceptance Criteria

### Agent
- [x] `agents/context/post-compact-resume.sh` appends a Post-Compact Budget Note stanza to `$CONTEXT` that (a) tells the agent any prior-session budget assertions in the handover are stale, (b) cites `.context/working/.budget-status` as the live gauge, (c) cites `bin/fw doctor` and `./agents/context/checkpoint.sh status` as on-demand probes.
- [x] The stanza is added unconditionally on every compact/resume fire (the cost is ~6 lines of injected context; the benefit is one explicit anti-misread cue).
- [x] Existing hook output (handover, focus, arc, tasks, git, fabric, discoveries, broken-hook probe) preserved unchanged — the new stanza is additive.
- [x] `bash -n agents/context/post-compact-resume.sh` passes; manual JSON-output dry-run shows valid JSON with new stanza inside `additionalContext`.

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

bash -n agents/context/post-compact-resume.sh
out=$(bash agents/context/post-compact-resume.sh 2>&1); echo "$out" > /tmp/.t1728-verify.json && python3 -c "import json; ctx=json.load(open('/tmp/.t1728-verify.json'))['hookSpecificOutput']['additionalContext']; assert 'Post-Compact Budget Note (T-1728)' in ctx; assert '.budget-status' in ctx; assert 'checkpoint.sh status' in ctx; assert 'fw doctor' in ctx"

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

### 2026-05-04T22:00:07Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1728-post-compact-budget-injection-warn-agent.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-470033f3
- **Timestamp:** 2026-06-02T14:59:22Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#1 (Agent)** — `agents/context/post-compact-resume.sh` appends a Post-Compact Budget Note stanza to `$CONTEXT` that (a) tells the agent any prior-session budget assertions in the handover are stale, (b) cites `.cont
  - **AC-verify-mismatch** (narrow, heuristic) — `path=agents/context/checkpoint.sh in: `agents/context/post-compact-resume.sh` appends a Post-Compact Budget Note stanza to `$CONTEXT` that (a) tells the agent any prior-session budget asse`
### 2026-05-28T15:22:07Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
