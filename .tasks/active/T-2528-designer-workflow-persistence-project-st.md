---
id: T-2528
name: "designer workflow persistence: project store + browser + save routes"
description: >
  Inception: designer workflow persistence: project store + browser + save routes

status: started-work
workflow_type: inception
owner: human
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-07-10T21:58:09Z
last_update: 2026-07-10T22:00:26Z
date_finished:
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── Inception scoring exception (T-2186 Slice 2 / T-2188). See 050-Inceptions.md §Scoring Exception. ──
target_blast_radius: 3            # int 0..9. Anticipated component count of the build work this inception would authorise on GO.
                                  # Substitutes for the absent components: list in the F8 cost formula (040). Required.
                                  # Guide: 0=docs only, 1=single file, 3=small subsystem (S), 5=cross-subsystem (M), 7=multi-arc (L), 9=framework-wide (XL).
voi_score: 0.5                    # float 0..1. Value of Information — expected value of resolving this question,
                                  # independent of build cost. Higher when answer affects many tasks or unblocks a strategic decision. Required.
cost_estimate_proposed:
  - ts: '2026-07-10T22:00:06Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 6
    rationale: blast_radius=3 (no-signal); tier=4 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-07-10T22:00:10Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 2
      F3: 2
      F1: 2
      F2: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-AUTONOMY=2 (no-signal); F3=2 
      (no-signal); F1=2 (no-signal); F2=2 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2528: designer workflow persistence: project store + browser + save routes

## Problem Statement

The deployed 0.2.0 workflow designer (`/designer`) is a **stateless single-file editor** — it
diagrams and does single-file `.bpmn` import/export, but has **no project/workflow browser** (can't
list or open existing workflows) and **cannot save into a project/library**. Operator hit both gaps
during live use of the freshly-shipped T-177 build.

For AEF, a workflow authored in the designer should be a **first-class, repo-tracked artifact** — the
input to the Child 2 (diagram→tasks) compiler and a durable part of the task/arc system it exists to
author. Today the designer can draw a workflow but the workflow evaporates on reload, so it can't yet
participate in the framework it's meant to feed. Why now: T-177/0.2.0 just went live; the surface is
usable but non-persistent, and the persistence-owner decision must land before *either* AEF or 832
builds — otherwise 832 could ship a browser-local store AEF would have to unwind (see IW-8 in
`docs/reports/T-2522-bpmn-aef-mapping-contract.md`).

This is an AEF-side subsystem question, distinct from the 832-side build-nits IW-6/IW-7: `/designer`
is currently a static serve (`web/blueprints/designer.py` → reads the pinned read-only HTML), so AEF
exposes **no save/list endpoint whatsoever**. The vendored editor is 832's SoT and AEF never edits it —
so any client-side save/browse UI is 832's build, but the *store* it talks to is AEF's to design.

## Assumptions

<!-- Register with: fw assumption add "Statement" --task T-2528 -->
- A workflow is worth persisting as a repo artifact (not just an ephemeral diagram).
- The 832 editor can be extended (upstream) to POST/GET against AEF endpoints — i.e. the split is buildable on both sides.
- "Project" maps onto something the framework already has (arc / directory) rather than a new top-level concept.

## Open Questions

- **IW-1 (KEYSTONE): Where do workflows persist, and who owns the store?**
  candidates: (a) AEF backend — repo-tracked store under `.context/` or a tracked dir + `GET /designer/projects` (list) + `POST /designer/projects/<id>` (save); 832 editor is the thin client. (b) 832 build localStorage / File System Access API — zero AEF backend, but workflows trapped per-browser, not repo-tracked (violates Portability + SoT). (c) file-round-trip only (status quo) — export `.bpmn`, manual re-import; operator reports insufficient.
  confidence: 1 (lean (a), not yet validated with a spike)
  disposition: deferred
  rationale: the persistence-owner decision is the whole point of this inception; a route spike + a "what is a project" answer (IW-2) must land before recommending.
- **IW-2: What is a "project"?** A directory of `.bpmn` files? A manifest mapping workflows→arcs/tasks? Reuse the arc concept, or a new store?
  confidence: 1
  disposition: deferred
  rationale: shapes the store schema and the list/save route surface; decide alongside IW-1.
- **IW-3: Does saving a workflow create framework artifacts (tasks/arcs), or only store the diagram?** Relation to the Child 2 (diagram→tasks) compiler — is "save" pure persistence, or the compile trigger?
  confidence: 1
  disposition: deferred
  rationale: determines whether IW-8 overlaps Child 2 or stays a clean persistence layer beneath it.

## Exploration Plan

1. **Spike the AEF store + routes** (time-box 1 session): minimal `GET /designer/projects` + `POST` backed by a tracked dir of `.bpmn`; prove save→list→reopen round-trips server-side.
2. **Confirm the 832-side reach** (cross-boundary): can the vendored editor be extended upstream to call those endpoints? Relay the endpoint contract to 832 on thread T-175; don't assume.
3. **Resolve IW-2/IW-3 on paper**: define "project" and whether save compiles. Decide reuse-arc vs new-store.

## Technical Constraints

- `/designer` serves a **read-only (0444) vendored single-file build** AEF never edits; browse/save *UI* is a 832 upstream change, only the *store + routes* are AEF's.
- Browser **File System Access API requires https/localhost**; a POST-to-AEF path needs **CORS** consideration (served same-origin today, so likely fine).
- A save endpoint that writes repo artifacts must respect the **task gate / write governance** — persisting a workflow is a Write; decide whether it needs a task context or is a Tier-3 pre-approved store write.
- Cross-boundary: 832 must ship editor support for whatever contract AEF defines — the AEF half can't go live alone.

## Scope Fence

**IN:** the persistence-owner decision (IW-1), a thin AEF-side store + list/save route design, the "what is a project" definition (IW-2), and the save-vs-compile boundary (IW-3).
**OUT:** building the 832 editor browse/save UI (832 owns, upstream), the diagram→tasks compiler itself (Child 2, separate task), multi-user concurrency / workflow versioning / access control (future).

## Acceptance Criteria

### Agent
<!-- @auto-tick-on-decide -->
- [ ] Problem statement validated
<!-- @auto-tick-on-decide -->
- [ ] Assumptions tested
<!-- @auto-tick-on-decide -->
- [ ] Recommendation written with rationale

### Human
<!-- @auto-tick-on-decide -->
- [ ] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Run: `fw task review T-XXX` (opens Watchtower with recommendation, assumptions, research artifacts)
  2. Review the Agent Recommendation section and go/no-go criteria evaluation
  3. Record decision via the Watchtower form or the command shown alongside the QR code
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

<!-- Fill these BEFORE writing the recommendation. The placeholder detector will block review/decide if left empty. -->
**GO if:**
- Persistence owner decided (IW-1) with a bounded route surface AEF can build without editing the vendored 832 build
- "Project" (IW-2) maps onto an existing framework concept or a small tracked store; save-vs-compile boundary (IW-3) is clear
- The 832-side reach is confirmed buildable (editor can call the AEF endpoints)

**NO-GO if:**
- Persistence can only live in the vendored build (entirely 832-side) → this isn't an AEF inception, hand wholly to 832
- Store/route surface is unbounded (multi-user, versioning, access control demanded up front) or duplicates Child 2

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# For inception tasks, verification is often not needed (decisions, not code).
#
# Toolchain hint (L-291): if a GO decision will mean editing *.vbproj/*.csproj/*.xaml,
# *.go, Cargo.toml, tsconfig.json, or pom.xml in the build task, plan to add the
# matching build command (dotnet build / go build / cargo check / tsc --noEmit /
# mvn compile) to that build task's ## Verification — P-011 only runs what you write.

## Recommendation

**Recommendation:** GO

**Rationale:**

Operator-reported blocking UX gap: the deployed 0.2.0 designer cannot save to a project and has no workflow browser — the editor is stateless per load. This needs an AEF-side persistence subsystem (/designer is currently a static single-file serve with zero save/list endpoints). Real fix-space to explore: WHERE workflows persist (AEF repo-tracked store vs 832 localStorage vs file-only) is a genuine design decision, and workflows-as-first-class-repo-artifacts fits the framework's SoT model. One question, real go/no-go, decomposable after — the inception shape.

**Evidence:**

- `web/blueprints/designer.py` — `/designer` is a static single-file serve (`_pin()` → `vpath.read_text()`); no save/list route exists.
- Operator report (2026-07-10, live 0.2.0 review): "missing the project (workflow) browser and cannot save to project."
- `docs/reports/T-2522-bpmn-aef-mapping-contract.md` §IW-8 — full candidate matrix (a/b/c) + cross-boundary reasoning.
- Relayed to 832 on `agent-chat-arc` thread T-175, offset 6862 (asked 832 to confirm the AEF-store/832-thin-client split).

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

<!-- Filled at completion via: fw inception decide T-XXX go|no-go --rationale "..." -->

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-07-10T22:00:26Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
