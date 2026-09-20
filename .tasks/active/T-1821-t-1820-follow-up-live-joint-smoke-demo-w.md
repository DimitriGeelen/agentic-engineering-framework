---
id: T-1821
name: "T-1820 follow-up: live joint-smoke demo when TermLink wires aggregator handler
  at hub startup"
description: >
  T-1820 partial-shipped substrate (deploy + framework subscriber operational). Headline
  mechanic (live binary-to-binary observation of inbox.queued) NOT yet demonstrated
  — three CLI posts to inbox:<id> with file.init produced no event. Working hypothesis:
  the handler that injects inbox.queued into the aggregator runs inside the integration
  test (via init_aggregator), not at hub startup. Needs TermLink-side fix (wire init_aggregator
  at hub boot OR add a CLI command that triggers the existing path). When TermLink
  resolves, re-run the smoke against the live hub: spawn consumer, drive the trigger,
  observe event on framework subscriber, capture transcript, file demo artefact. Related:
  T-1820, T-1636, T-1818, T-1819, T-1804.

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: [termlink, peer-consult, cross-repo, joint-smoke]
components: []
related_tasks: [T-1820, T-1636, T-1818, T-1819, T-1804, T-2918]
arc_id: orchestrator-rethink
created: 2026-05-14T05:48:29Z
last_update: 2026-09-20T11:02:31Z
date_finished: 2026-09-20T11:02:31Z
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
  - ts: '2026-05-28T20:15:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
      F1: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled); F1=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-05-28T22:54:10Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-05T18:00:03Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T16:00:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:23:26Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-13T18:00:03Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal);
      F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-07-07T10:45:03Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled); F-RECALL=0 (no-signal); F-AUTONOMY=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-11T12:45:03Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled); F-RECALL=2 (body:lightly-promoted); 
      F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 
      (no-signal)
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
  - ts: '2026-08-11T12:45:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 5
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=5 
      (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-17T12:36:04Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 5
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=5 (lines=108,acs=3)
    rubric_sha: e4a00f38e801
---

# T-1821: T-1820 follow-up: live joint-smoke demo when TermLink wires aggregator handler at hub startup

## Context

**Superseded premise (2026-08-11):** this task's title and description assume
the aggregator handler is "not wired at hub startup." A live rerun of T-1820's
joint smoke on 2026-08-11 disproved that hypothesis directly (the aggregator
is wired at hub boot — `crates/termlink-hub/src/server.rs:279`) and found
the real, conclusive root cause: `lib/peer.py::poll_once` polls a
per-session event bus, which structurally cannot see hub-aggregator-injected
events, plus a topic-name mismatch (`dm.queued` vs `inbox.queued`) on the DM
rail. Full reproduction trail: `docs/reports/T-1820-joint-smoke-demo.md`
§"2026-08-11 — conclusive rerun". **Follow-up work is now tracked in T-2918**
(fixes `lib/peer.py` + resolves the topic question + reruns this smoke).
Recommend closing this task as superseded by T-2918 rather than duplicating
scope, pending operator confirmation.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] Superseded premise confirmed disproven with a file:line citation — the
      aggregator is wired at hub boot (`crates/termlink-hub/src/server.rs:279`,
      per T-1820's 2026-08-11 conclusive rerun), so "TermLink hasn't wired
      `init_aggregator` at startup" was never the real gate this task was
      filed to wait on.
- [x] T-2918 confirmed as the task now carrying this scope: `related_tasks:`
      is cross-linked both directions (this file line 22; T-2918's own
      frontmatter names T-1820/T-1818). T-2918 is `started-work`, and this
      session's own TermLink-source-dispatch investigation on T-2918
      (2026-09-20) independently reinforces the same root cause — hub-mode
      `event watch --hub` has zero cursor/replay capability and
      `lib/peer.py::poll_once` calls per-session `event poll`, which
      structurally cannot observe hub-aggregator-injected events. No new
      information found this session that reopens T-1821's original premise.
- [x] Verified no orphaned scope: T-1821's stated deliverable ("re-run the
      smoke once TermLink wires the handler at hub startup") has no
      remaining referent — the handler was never missing, so there is
      nothing for this task to wait on or re-trigger independently of
      T-2918's fix landing.

### Human
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking. -->
- [ ] [REVIEW] Confirm T-1821 should close as superseded by T-2918 rather
      than continue tracking independently.
  **Steps:**
  1. Read this task's Context section and the three Agent ACs above.
  2. Open T-2918 (`fw task show T-2918`) and confirm it covers the same
     technical scope (framework-side `lib/peer.py` fix + topic-name
     resolution) that T-1821 was filed to eventually re-test.
  3. If T-2918 is superseded/abandoned/redirected before it lands, decide
     whether T-1821 should be reopened (`--horizon now`) or stay closed.
  **Expected:** Agreement that T-1821 is a stale duplicate tracker, not
  live independent scope, and closing it avoids two tasks pointing at the
  same fix with no coordination between them.
  **If not:** Reopen with `fw task update T-1821 --horizon now` and note
  what independent scope remains that T-2918 does not cover.

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

### 2026-09-20 — formalizing the standing supersession note

- **What changed:** This task's Context section already recorded (2026-08-11,
  a prior session) that its filing premise was disproven and that T-2918
  carries the real fix. That finding sat with placeholder ACs (`[First
  criterion]` / `[Second criterion]`) ever since — never formalized into a
  closeable state. This session's independent TermLink-source-dispatch
  investigation on T-2918 (surfacing the hub-aggregator cursor/replay gap
  as a Sovereign architecture question) touched the same code path and
  found nothing that contradicts T-1821's supersession note — so this
  session filled in real Agent ACs citing the existing evidence and added
  a Human AC for operator confirmation, rather than self-closing (consistent
  with T-1820's own discipline: a scope/closure call on this cross-repo
  question is surfaced, not decided, per §Autonomous Mode Boundaries).
- **Plan impact:** None to the underlying fix — T-2918 remains the task
  that carries it. This task's only remaining action is the operator's
  one-line confirmation.
- **Triggered:** No new sub-task. T-1821 handed to `fw task review T-1821`
  once this session closes out.

## Recommendation

**Recommendation:** NO-GO (on T-1821's own original scope) — close as
superseded by T-2918, pending the one-line operator confirmation above.

**Rationale:** T-1821 was filed to wait for TermLink to wire the
`init_aggregator` handler at hub startup and then re-run the joint smoke.
A prior session's 2026-08-11 conclusive rerun on T-1820 proved that
precondition was never real — the handler was wired at hub boot the whole
time (`crates/termlink-hub/src/server.rs:279`) — and found the actual,
framework-side root cause (`lib/peer.py::poll_once` polls a per-session
bus that cannot see hub-aggregator-injected events; a second, independent
topic-name mismatch on the DM rail). That fix is scoped and owned by
T-2918, not this task. Continuing to carry T-1821 as a separate open item
duplicates tracking with no coordination between the two, which is exactly
the kind of stale-duplicate corpus noise the framework's own audit already
flags elsewhere (GO-scope-unpropagated class). There is no independent
deliverable left under T-1821's original title that T-2918 does not
already cover.

**Evidence:**
- `crates/termlink-hub/src/server.rs:279` — aggregator wired at hub boot
  (cited in T-1820's 2026-08-11 Evolution entry and this task's Context).
- `docs/reports/T-1820-joint-smoke-demo.md` §"2026-08-11 — conclusive
  rerun" — full reproduction trail for the disproven premise + real cause.
- T-2918 frontmatter `related_tasks:` names T-1820/T-1818; this task's
  `related_tasks:` (line 22) names T-2918 back — bidirectional cross-link
  already in place.
- This session's own T-2918 investigation (TermLink-source dispatch,
  2026-09-20) independently confirms the hub-aggregator has no
  cursor/replay primitive — consistent with, not contradicting, the root
  cause T-1821's Context already names.

**If NO-GO is confirmed:** operator ticks the Human AC above and runs
`fw task update T-1821 --status work-completed`.
**If not:** operator reopens (`fw task update T-1821 --horizon now`) and
names the independent scope T-2918 doesn't cover.

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

### 2026-05-14T05:48:29Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1821-t-1820-follow-up-live-joint-smoke-demo-w.md
- **Context:** Initial task creation

### 2026-09-20T11:01:29Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-8eadd699
- **Timestamp:** 2026-09-20T11:02:33Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-09-20T11:02:31Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
