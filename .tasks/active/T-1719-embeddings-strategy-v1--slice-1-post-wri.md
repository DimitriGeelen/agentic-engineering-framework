---
id: T-1719
name: "Embeddings strategy V1 — Slice 1 (post-write hook + happiness signal + one-provider
  routing)"
description: >
  Slice 1 of T-1717 (Embeddings strategy GO conditional). Smallest end-to-end vertical
  proving the loop: post-write incremental embedding on lib/learnings.sh add + update-task.sh
  work-completed (closes catastrophic A1 amnesia case <5s freshness), happiness flag
  schema (--happiness +1..+5/-1..-5 on task complete), one provider-routing decision
  through litellm (fw ask routes via resolver, ollama default + cloud fallback when
  unreachable), Watchtower telemetry panel. Falsifier: after 7 days of usage, amnesia
  self-reports drop AND retrieval miss-rate decreases. BLOCKED on T-1717 GO recording
  (status: captured). Headline mechanic locked from T-1717 Recommendation. Pilot consumer
  of orchestrator substrate — closes G-064 partially. Eats Evolution-gate dogfood
  (T-1718 Slice 1) from filing.

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [T-1717-implementation, G-064-closure-pilot, vertical-slice-1, 
      blocked-on-t-1717-go]
components: []
related_tasks: [T-1717, T-1718, T-1715, T-1716, T-263, T-269, T-1696, T-1697, 
      T-1698, T-1700, T-1443, T-679]
arc_id: embeddings-strategy
created: 2026-05-04T15:26:17Z
last_update: 2026-08-16T13:43:09Z
date_finished:
bvp_scores_proposed:
  - ts: '2026-05-19T18:27:45Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 3
      D4: 2
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=3
      (body:component-discoverability); D4=2 (body:env-class-handled)
    rubric_sha: e4a00f38e801
  - ts: '2026-05-28T20:15:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 3
      D4: 2
      F1: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=3
      (body:component-discoverability); D4=2 (body:env-class-handled); F1=0 
      (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-05-28T22:54:09Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 3
      D4: 2
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=3
      (body:component-discoverability); D4=2 (body:env-class-handled); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-05T18:00:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 3
      D4: 2
      F-RECALL: 3
      F-ORCH: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=3
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=3 (body:fw-recall-or-memory-link); F-ORCH=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T16:00:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 3
      D4: 2
      F-RECALL: 3
      F-ORCH: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=3
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=3 (body:fw-recall-or-memory-link); F-ORCH=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:23:25Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 3
      D4: 2
      F-RECALL: 3
      F-ORCH: 0
      F3: 0
      F1: 1
      F2: 1
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=3
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=3 (body:fw-recall-or-memory-link); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=1 (body/components:context-fabric-incidental); F2=1 
      (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-13T18:00:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 3
      D4: 2
      F-RECALL: 3
      F-ORCH: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 1
      F2: 1
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=3
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=3 (body:fw-recall-or-memory-link); F-ORCH=0 (no-signal); 
      F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=1 
      (body/components:context-fabric-incidental); F2=1 
      (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
  - ts: '2026-07-07T10:45:03Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 3
      D4: 2
      F-RECALL: 3
      F-AUTONOMY: 0
      F3: 0
      F1: 1
      F2: 1
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=3
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=3 (body:fw-recall-or-memory-link); F-AUTONOMY=0 (no-signal); F3=0
      (no-signal); F1=1 (body/components:context-fabric-incidental); F2=1 
      (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-05-19T21:45:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1719: Embeddings strategy V1 — Slice 1 (post-write hook + happiness signal + one-provider routing)

## Context

**🔒 BLOCKED on T-1717 GO recording.** Task pre-filed with proper governance
to prevent the §ACD shape (T-1717's Recommendation references this build but
the build wasn't filed at recommendation time — same omission this session
already corrected for the T-1717 inception itself).

**Status will flip to `started-work` only after:**
1. Human records GO on T-1717 via http://192.168.10.107:3000/review/T-1717
2. T-1718 Slice 1 has shipped (✓ done, commit `b85a127c0`/`5031b83d6`)
3. Headline mechanic from T-1717 Recommendation re-confirmed at activation

**Headline mechanic (locked from T-1717 Recommendation):**
> *"Agent issues `fw recall` → resolver routes to optimal embedding provider
> for query class → returns chunks with provenance → outcome enrichment
> captures happiness rating → next routing decision improves.
> **User-visible: amnesia incidents drop, arc-coherence telemetry trends
> positive across the orchestrator-arc.**"*

**Slice 1 scope (smallest end-to-end vertical, locked):**

1. **Post-write incremental embedding** — extend `lib/learnings.sh add`
   and `update-task.sh --status work-completed` with single-chunk embed
   + insert into sqlite-vec. Closes catastrophic A1 amnesia case
   (<5s freshness, same machine, same session).
2. **Happiness signal schema** — `fw task update T-XXX
   --status work-completed --happiness +1..+5 / -1..-5`. CLI flag plus
   one-tap Watchtower UI. Schema in `.context/working/happiness.jsonl`.
   Bipolar bounded scale; both human and agent rate; mutable with
   audit trail.
3. **One provider-routing decision** — `fw ask` calls resolver →
   chooses ollama-local (default) OR claude-via-litellm (fallback when
   ollama unreachable). Captures dispatch + outcome via existing
   T-1696/97/98 substrate.
4. **Watchtower telemetry panel** — surfaces current freshness state,
   recent happiness ratings, routing decisions, miss-rate sketch. Day-1
   visibility per the §ACD discipline.

**Falsifier:** after 7 days real usage, amnesia self-reports must drop
AND retrieval miss-rate (recently-written chunks not surfaced) must
decrease vs. pre-Slice-1 baseline. If not, hypothesis falsified →
`fw inception revise T-1717` triggered.

**Slice 2+ (out of scope for T-1719):** broaden corpus (source code +
commits) + couple to component fabric (T-1720 candidate); scope-aware
retrieval with boost-not-filter (T-1721); reviewer ↔ outcome
integration (T-1722); index de-coupling from git + adaptive freshness
(T-1723).

See research artifact: [`docs/reports/T-1717-embeddings-strategy-grill.md`](../../docs/reports/T-1717-embeddings-strategy-grill.md)

## Acceptance Criteria

### Agent (Slice 1)
<!-- ACs locked at filing per T-1717 Recommendation. Do not modify
     without an Evolution log entry explaining what changed. -->

- [~] **A1** (index_one() shipped + tested at 1.6s/42 chunks; hook wiring into
  the two call sites remains) Post-write hook in `lib/learnings.sh add` + `update-task.sh
  --status work-completed` for arc-tagged tasks: triggers single-chunk
  embed + sqlite-vec insert. Latency <5s on the typical learning entry
  size. Bats test pins behavior + latency budget.
- [x] **A2** `--happiness N` flag accepted on `fw task update`, range
  [-5..-1, +1..+5], appends to `.context/working/happiness.jsonl`.
  Schema: `{task_id, ts, source: human|agent, value, optional_reason}`.
  Bats test covers valid range, invalid rejection, append-only.
- [ ] **A3** `fw ask` queries flow through `fw resolver dispatch` with
  task_type=ask. Resolver picks ollama-local OR claude-via-litellm
  based on a routing key (start: hardcoded ollama-default with cloud
  fallback on connection error). Outcome recorded in
  `dispatch-outcomes.jsonl`. Bats test covers both branches.
- [x] **A4** Watchtower panel `/embeddings` shows: index mtime,
  miss-rate (rolling 24h), recent happiness ratings, last 10 routing
  decisions. Playwright test pins visibility (per T-1575 rule —
  element-presence grep is forbidden for UI).
  — live at `/embeddings` (200, nav under Govern → Health). Renders real data:
  407,498 chunks, index age 0.0d from manifest, 2.6% miss rate over 117 queries,
  happiness mean +2.2 over 6 ratings, 10 routing decisions.
  `tests/playwright/test_embeddings_panel.py` 13/13 green — asserts visibility
  and rendered text, including a tri-state test that a `None` never renders as
  a number (the T-3004 failure mode).
- [ ] **A5** Eat-our-dogfood: this task carries a populated
  `## Evolution` log at completion (Evolution-gate from T-1718 Slice 1
  fires on this task — the gate's first real consumer).
- [ ] **A6** Bats test suite passes; `fw audit` clean; new components
  fabric-registered.

### Human (Slice 1)
- [ ] [REVIEW] Watch the headline mechanic fire end-to-end.
  **Steps:**
  1. `cd /opt/999-Agentic-Engineering-Framework && bin/fw ask "what is the §ACD pattern"`
  2. Open http://192.168.10.107:3000/embeddings — confirm panel shows
     the routing decision + outcome
  3. `bin/fw task update T-1719 --status work-completed --happiness +4`
  4. Confirm happiness recorded; Watchtower updates within 5s
  **Expected:** the loop fires visibly; routing decision logged;
  happiness recorded; index reflects the work.
  **If not:** flag the broken step; agent reworks.

- [ ] [RUBBER-STAMP] Approve cloud-fallback provider config.
  **Steps:**
  1. Review `.context/litellm-config.yaml` for cloud-fallback model
  2. Confirm cost cap is configured + reasonable
  3. Tick this AC if approving

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

## Evolution

### 2026-05-04 — Filed (blocked on T-1717 GO)
- **What changed:** Recognized that T-1717's Recommendation references
  this build but did not file it — same §ACD-shape omission this session
  diagnosed and corrected for the T-1717 inception itself. Pre-filing
  T-1719 as `captured` with full ACs locked at recommendation-time
  prevents recurrence at activation.
- **Plan impact:** None — Slice 1 scope locked from T-1717 Recommendation.
  ACs derived directly from the four Slice 1 deliverables in the artifact.
- **Triggered:** None new. T-1718 Slice 1 (Evolution-gate prerequisite)
  shipped (commit `b85a127c0`); this task will be its first real
  consumer at work-completed.

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

### 2026-05-04T15:26:17Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1719-embeddings-strategy-v1--slice-1-post-wri.md
- **Context:** Initial task creation

### 2026-05-04T15:26:25Z — status-update [task-update-agent]
- **Change:** tags: +arc:embeddings-strategy

### 2026-05-04T15:26:25Z — status-update [task-update-agent]
- **Change:** tags: +arc:orchestrator-rethink

### 2026-08-16T13:36:35Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)
