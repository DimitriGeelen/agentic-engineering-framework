---
id: T-1847
name: "Scaffold arc-grooming workspace + file 10 build slices (T-1846 decide-go propagation)"
description: >
  Scaffold arc-grooming workspace + file 10 build slices (T-1846 decide-go propagation)

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: [governance, scaffold, post-decide-go]
components: [".context/arcs/"]
related_tasks: ["T-1846"]
arc_id: arc-grooming
created: 2026-05-15T14:47:20Z
last_update: '2026-08-16T22:24:46Z'
date_finished: 2026-05-15T19:55:03+02:00
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:00Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 0
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=0
      (no-signal); D4=2 (body:env-class-handled); F-RECALL=0 (no-signal); 
      F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:46Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 0
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=0
      (no-signal); D4=2 (body:env-class-handled); F-RECALL=0 (no-signal); 
      F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1847: Scaffold arc-grooming workspace + file 10 build slices (T-1846 decide-go propagation)

## Context

T-1846 inception decide-go (GO) recorded. Per L-329, post-decision propagation is
agent work, not human-gated. This task creates the arc workspace and files the 10
build slices as captured tasks (each with real ACs traceable to
handoff §7 + T-1846 dialogue log). Build slices will be picked up via
`fw work-on T-XXXX` individually; this task does not start their work, only their
scaffolding.

Source decisions to honour (from T-1846):
- D-Immutability: arc records never deleted, IDs never renumber, abandonment is a
  status update.
- Q1=Tier-1 block, Q2=committable migration report, Q3=T-1717+T-1719 →
  `arc_id: embeddings-strategy`.
- T-NEW-1.5 added: sequential `arc-NNN` IDs (matches T-NNNN model).

## Acceptance Criteria

### Agent
- [x] `.context/arcs/arc-grooming.yaml` exists with status:in-progress, headline_mechanic
      populated, decision: GO referencing T-1846, anchor_task: T-1846
- [x] 10 build-slice tasks filed in `.tasks/active/` (status: captured, owner: agent):
      T-1848 (T-NEW-1.5 arc-NNN IDs), T-1849 (T-NEW-2 arc_id field+block), T-1850
      (T-NEW-3 tags→arc_id migration), T-1851 (T-NEW-4 deprecate constituent_tasks),
      T-1852 (T-NEW-5a state machine), T-1853 (T-NEW-5b Watchtower UI), T-1854
      (T-NEW-6 fw arc abandon), T-1855 (T-NEW-7 stale-arc audit), T-1856 (T-NEW-8
      anchor-task audit), T-1857 (T-NEW-9 canonical doc)
- [x] Each filed task has: real ACs traceable to handoff §7 (no placeholders), tags
      [arc:arc-grooming, build, …], components, related_tasks set; dependencies
      encoded in description and arc YAML comment block
- [x] `bin/fw audit` passes — Pass: 370, Warn: 36, **Fail: 0**
- [x] Dependency chain commented in `.context/arcs/arc-grooming.yaml` for reader clarity

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# The completion gate runs each command — if any exits non-zero, completion is blocked.
#
# Toolchain hint (L-291): if you edited *.vbproj/*.csproj/*.xaml add `dotnet build`;
# *.go → `go build ./...`; Cargo.toml → `cargo check`; tsconfig.json → `tsc --noEmit`;
# pom.xml → `mvn -q compile`. P-011 runs only what you write — broken builds slip
# past otherwise (origin: 003-NTB-ATC-Plugin T-077, broken WPF DLL on master 5 days).
test -f .context/arcs/arc-grooming.yaml
python3 -c "import yaml; yaml.safe_load(open('.context/arcs/arc-grooming.yaml'))"
test $(grep -lE 'arc:arc-grooming' .tasks/active/*.md | grep -v T-1846 | grep -v T-1847 | wc -l) -ge 10
# T-1870: CTL-013 chicken-and-egg — running `bin/fw audit` from inside audit's
# own CTL-013 verify-rerun loop hits the audit lock and returns "Another audit
# is already running", so grep "Fail: 0" never matches. Check the last audit
# YAML report instead (same evidence, no nested audit).
ls -t .context/audits/[0-9]*.yaml 2>/dev/null | head -1 | xargs -I{} grep -q "fail: 0" {}

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

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-05-15T14:47:20Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1847-scaffold-arc-grooming-workspace--file-10.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-53a05f6c
- **Timestamp:** 2026-06-02T14:59:59Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
