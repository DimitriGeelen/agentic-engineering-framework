---
id: T-2822
name: "worktree policy: what may live inside a worktree"
description: >
  Inception: worktree policy: what may live inside a worktree

status: started-work
workflow_type: inception
owner: human
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-08-06T10:47:14Z
last_update: 2026-08-06T10:48:16Z
date_finished:
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── Inception scoring exception (T-2186 Slice 2 / T-2188). See 050-Inceptions.md §Scoring Exception. ──
target_blast_radius: 3            # int 0..9. Anticipated component count of the build work this inception would authorise on GO.
                                  # Substitutes for the absent components: list in the F8 cost formula (040). Required.
                                  # Guide: 0=docs only, 1=single file, 3=small subsystem (S), 5=cross-subsystem (M), 7=multi-arc (L), 9=framework-wide (XL).
voi_score: 0.5                    # float 0..1. Value of Information — expected value of resolving this question,
                                  # independent of build cost. Higher when answer affects many tasks or unblocks a strategic decision. Required.
bvp_scores_proposed:
  - ts: '2026-08-06T10:48:17Z'
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

# T-2822: worktree policy: what may live inside a worktree

## Problem Statement

A git worktree is a **different PROJECT_ROOT**. The framework's governance state —
`.context/working/`, `.tasks/`, the Watchtower triple-file, the budget transcript
pointer — lives in the main checkout. Every worktree defect on record is some
consumer of that state resolving to the wrong root, or to no root at all.

We have been paying for this repeatedly (30+ tasks reference worktrees; the
concentrated reliability run alone is T-2463 → T-2469 → T-2474 → T-2479) because
**two contradictory premises are simultaneously live in the codebase**:

- *Share governance state into the worktree* — the premise `fw_reanchor_from_cwd`
  (T-2464) and the worktree-aware audit/doctor checks (T-2435, T-2437) were built on.
- *Governance state belongs only in the main checkout* — the premise CLAUDE.md
  §Trunk-Based Session Flow (T-100196) is written on: session runs on master,
  worktrees exist to build and land source.

Neither is wrong on its own. Holding both is what produces defects at the joins.

**Why now:** T-2821 (`fw init` leaves no HEAD → `git worktree add` impossible →
harness `bgIsolation` refuses all writes → hard deadlock in a brand-new project) is
the newest instance, and it surfaced a second, larger question the operator raised
directly: *why is a worktree being created at all*, when the recorded decision was
that worktrees are for special circumstances. Fixing T-2821 removes the deadlock but
leaves the policy unresolved, which is how this accumulated in the first place.

## Assumptions

<!-- Key assumptions to test. Register with: fw assumption add "Statement" --task T-XXX -->

- **A1** — Every recorded worktree defect traces to the PROJECT_ROOT split, not to N
  independent causes. (Testable: classify the corpus by seam; if a large residual
  class does not fit, A1 is false and the policy question is the wrong frame.)
- **A2** — Source-only is implementable: a worktree can build and land without ever
  writing `.context/` or `.tasks/`. (Testable: spike it and find what actually breaks.)
- **A3** — Claude Code's `bgIsolation` worktree creation is a harness default AEF
  never chose — `.claude/settings.json` has no `worktree` key. (Verified once already
  this session; re-verify, since it is load-bearing for IW-2.)

## Open Questions

- **IW-1: What may live inside a worktree — source only, or shared governance state?**
  confidence: 1
  disposition:
  rationale:

- **IW-2: Should ambient/automatic worktree creation (harness `bgIsolation`) be turned off, leaving an explicit trigger?**
  confidence: 2
  disposition:
  rationale:

- **IW-3: If source-only wins, is it enforced structurally (a PreToolUse gate refusing `.context/`/`.tasks/` writes when cwd is a worktree) or by convention?**
  confidence: 1
  disposition:
  rationale:

- **IW-4: What happens to the code already built on the opposite premise — `fw_reanchor_from_cwd` (T-2464), worktree-aware audit/doctor (T-2435/T-2437), the budget-gauge worktree fixes (T-2375/T-2377/T-2400)? Retire, keep as fallback, or re-target?**
  confidence: 0
  disposition:
  rationale:

<!-- T-2190 (T-2186 Slice 4): every IW-N question must be disposed before
     --status work-completed. Disposition gate (agents/task-create/update-task.sh
     check_disposition_gate) refuses on under-disposed inceptions.

     Per-question shape:

       - **IW-1: <question text>**
         confidence: 0-3      (your confidence in your current answer; 0=guess, 3=verified)
         disposition: answered | deferred | dissolved
         rationale: <one-line evidence — file:line, decision id, dialogue ref>

     Never bare yes/no — the gate refuses bare checkboxes. See 050-Inceptions.md
     §Disposition Gate. Bypass: --skip-disposition-gate "rationale" (direct) or
     FW_SKIP_DISPOSITION_GATE=1 (env-var, T-1890 producer/consumer parity).
-->

## Exploration Plan

Three spikes. If a fourth appears, the inception is too big and must split
(§Task Sizing Rules: 3+ spikes is the decomposition signal).

**S1 — Mine the corpus (60 min, load-bearing).**
Classify every worktree-referencing task by *which seam leaked*: PROJECT_ROOT
resolution, branch/ref lifecycle, cleanup/pruning, or harness-vs-`fw worktree`
conflation. Output: a table in the research artifact. This spike alone may decide
IW-1 — if ~all defects are root-resolution, source-only is indicated by the evidence
rather than by taste. Tests A1.

**S2 — Spike source-only (45 min).**
In a scratch worktree, make `.context/`/`.tasks/` writes fail, then attempt a normal
build-and-land cycle. Record what legitimately breaks — that breakage *is* the cost
of this option, and it is the number the decision turns on. Tests A2.

**S3 — Spike shared-state (45 min).**
Symlink or re-anchor governance into a scratch worktree and run the same cycle. The
question is not "does it work once" but whether the seams close or merely move — e.g.
does the budget transcript still resolve, does the Watchtower triple-file still point
at one server, do two concurrent worktrees corrupt each other's focus.

**Cross-cutting test (not a spike — the acceptance shape for whichever option wins):**
one end-to-end lifecycle run, `create → work → integrate → prune`. Every defect on
record lived at a *join* while the per-verb tests stayed green; a per-verb test suite
is what let this accumulate.

## Technical Constraints

- **Two distinct worktree systems exist and must not be conflated.** Claude Code's
  harness (`EnterWorktree`/`ExitWorktree`, `bgIsolation` in `.claude/settings.json`)
  and AEF's own `fw worktree`. They create worktrees for different reasons and only
  one of them is ours to change. Any finding must state which system it is about.
- **`git worktree add` requires a resolvable HEAD.** This is the T-2821 constraint and
  it bounds every option: no policy can assume a worktree is always creatable.
- **The harness guard is outside our control.** When background isolation is active,
  writes are refused until the session isolates. AEF can choose whether to *ask* for
  isolation; it cannot change what the guard does once asked.
- **PROJECT_ROOT is resolved independently by many consumers** — hooks, `bin/fw`,
  Python (`lib/paths.py`), and the budget gauge each resolve it their own way. A
  policy that requires changing all of them at once is not a bounded fix path.

<!-- What platform, browser, network, or hardware constraints apply?
     For web apps: HTTPS requirements, browser API restrictions, CORS, device support.
     For hardware APIs (mic, camera, GPS, Bluetooth): access requirements, permissions model.
     For infrastructure: network topology, firewall rules, latency bounds.
     Fill this BEFORE building. Discovering constraints after implementation wastes sessions. -->

## Scope Fence

**IN**
- The single question: what may live inside a worktree (IW-1), and the three
  questions that fall out of it (IW-2 trigger, IW-3 enforcement, IW-4 existing code).
- Both worktree systems, kept explicitly distinct (harness vs `fw worktree`).
- A recommendation with a bounded, testable fix path — not the fix itself.

**OUT**
- **T-2821** (`fw init` leaves no HEAD). Already a separate build task with ACs.
  Folding it in would make an almost-done fix hostage to a policy decision, and it is
  a bug under either policy.
- Building anything. This is an inception; build slices are filed after the decision.
- `fw integrate` / landing mechanics beyond what the lifecycle run exercises.
- The T-100196 ↔ T-2394 master-merge-only conflict — that is **T-100201**, already
  filed. Adjacent, separately tracked, and it does not gate this question.

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
- Root cause identified with bounded fix path
- Fix is scoped, testable, and reversible

**NO-GO if:**
- Problem requires fundamental redesign or unbounded scope
- Fix cost exceeds benefit given current evidence

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

**Recommendation:** DEFER

**Rationale:**

Filed at session start; the three spikes (corpus mine, source-only spike, shared-state spike) have not run yet, so no evidence exists to recommend GO or NO-GO. Converge to GO/NO-GO once the corpus mine lands.

**Evidence:**

<!-- Add evidence bullets as exploration progresses (file paths,
     commit hashes, test results). The filing-time recommendation
     can be revised before fw inception decide. -->

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

### 2026-08-06T10:48:16Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
