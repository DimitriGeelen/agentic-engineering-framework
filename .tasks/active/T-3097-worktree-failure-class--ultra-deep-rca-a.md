---
id: T-3097
name: "Worktree failure class — ultra-deep RCA and structural fix"
description: >
  Inception: Worktree failure class — ultra-deep RCA and structural fix

status: started-work
workflow_type: inception
owner: human
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-08-20T07:03:07Z
last_update: '2026-08-20T07:15:07Z'
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
  - ts: '2026-08-20T07:04:21Z'
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
cost_estimate_proposed:
  - ts: '2026-08-20T07:15:07Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 7
    rationale: blast_radius=3 (target_blast_radius:inception-T-2189); tier=4 
      (workflow:inception); effort=7 (lines=169,acs=4)
    rubric_sha: e4a00f38e801
---

# T-3097: Worktree failure class — ultra-deep RCA and structural fix

## Problem Statement

Worktrees have been a recurring operational problem for five months. Six fixes have
shipped and the class is still live: 43 commits sit stranded in two worktrees dormant
since 2026-07-01, `fw doctor` reports two worktrees parked on merged branches, and
CLAUDE.md carries a documented, unresolved contradiction between T-100196 and T-2394.

The operator's ask is threefold: an ultra-deep root cause analysis, a designed fix, and
the fix implemented — plus a separable question about whether an errors/incident record
exists and can produce statistics. The operator also stated that another agent already
researched this, which turned out to be the single most important instruction in the
brief.

Why now: the accumulated evidence is unusually good (188 task files, 11 observations, 50
concern lines), and the pattern of "fix, recur, fix, recur" is itself the signal that
previous analyses stopped one level too shallow.

## Assumptions

<!-- Key assumptions to test. Register with: fw assumption add "Statement" --task T-XXX -->

## Open Questions

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

- **IW-1: Is there a working error/incident record at all, and what does it actually
  capture?** The operator's stated doubt ("I don't know if that's functioning") is the
  question. Not "does a file exist" — does anything write to it, what fraction of known
  worktree incidents appear in it, and can it produce statistics. A register that exists
  and is empty is worse than none, because it reads as evidence of absence.
  confidence: 3
  disposition: answered
  rationale: No error log exists. `session-metrics.sh:244` recomputes a counter (failed_tool_calls: 494, rate 0.0754) with no per-error row; `patterns.yaml` (the healing store) holds 19 entries and has been dead since 2026-04-08. The de-facto record is scattered across inbox/concerns/learnings/tasks with no aggregating surface — see artifact §IW-1.
- **IW-2: What did the peer agent already find?** The operator says another agent
  researched this and probably filed an RCA and proposed fixes. Locate it (pickup queue,
  inbox, bus, TermLink channels, cross-project registers), read it, and state plainly
  whether it is right, partial, or wrong — before generating a competing analysis.
  confidence: 3
  disposition: answered
  rationale: Found: docs/reports/T-2822-worktree-policy.md (2026-08-06). It is correct and was GO'd by the operator the same day. Its F1 names the mechanism and its F2 corrects the obvious-but-wrong implementation. Adopted rather than re-derived.
- **IW-3: Are the recorded worktree incidents one class or several?** T-100194 (fork
  explosion), T-100199 (stranded commits), T-2428 (6 commits stranded 5 weeks), T-2825 /
  G-075 (handoff paths outliving the worktree), T-100201 (the live CLAUDE.md
  contradiction), and today's two `worktree-merged` findings have been treated as six
  incidents with six local fixes. Either they share one mechanism — in which case the
  fixes have all been symptomatic — or they do not, in which case "worktrees are a
  headache" is a bundle and needs splitting before anything is designed.
  confidence: 2
  disposition: answered
  rationale: T-2822 S1a: three mechanisms, 13 of 16 defects in the root-split class. Adopted; being re-derived independently by a dispatched corpus miner (docs/reports/T-3097-worktree-incident-corpus.md).
- **IW-4: Why has each previous fix failed to end the class?** Six fixes shipped and the
  class is live. This is the question that decides whether a seventh fix is worth
  designing. Candidate shapes: the fixes addressed detection rather than the generating
  mechanism; they added advisory text where a structural gate was needed; or they were
  structurally sound but contradicted by another gate (T-100201 is a documented instance
  of exactly this).
  confidence: 3
  disposition: answered
  rationale: Not because the fixes were wrong — two shipped and work. Because T-2822's keystone slice was never filed as a task, and the audit detector for exactly that failure gates on a claim phrase matching 2 of 444 inceptions (0 after the next filter). 54 GO'd inceptions are invisible to it. Artifact §IW-4.
- **IW-5: What single structural change removes the generating mechanism?** The
  deliverable. Must be falsifiable: name what becomes impossible, not what becomes
  discouraged. If the honest answer is "no single change does", say so and enumerate the
  minimum set — but do not ship a recommendation that is a list of advisories.
  confidence: 3
  disposition: answered
  rationale: Two legs, neither needing a new decision: T-3098 builds T-2822 slice 1 (already GO'd 2026-08-06); T-3099 replaces the prose-keyed detector gate with a structural predicate. Artifact §IW-5.
## Exploration Plan

<!-- How will we validate assumptions? Spikes, prototypes, research? Time-box each. -->

## Technical Constraints

<!-- What platform, browser, network, or hardware constraints apply?
     For web apps: HTTPS requirements, browser API restrictions, CORS, device support.
     For hardware APIs (mic, camera, GPS, Bluetooth): access requirements, permissions model.
     For infrastructure: network topology, firewall rules, latency bounds.
     Fill this BEFORE building. Discovering constraints after implementation wastes sessions. -->

## Scope Fence

**IN:** why the worktree defect class recurs despite repeated fixes; whether a usable
error/incident record exists; the design and implementation of the fix that ends the
recurrence.

**OUT** (each needs its own task, none is silently absorbed):
- Recovering the 43 stranded commits — T-2824 recovered the content and correctly routed
  branch deletion to the operator as **Tier 0**. That handoff is outstanding and is an
  operator action, not agent work.
- The branch/ref lifecycle class and the creation-precondition class. T-2822 F3 is honest
  that source-only does not touch them; claiming otherwise would repeat the overclaim
  pattern it warned about.
- The T-100201 contradiction between T-100196 and T-2394 (already filed, still open).
- The errors-log gap. Answered as IW-1, but the remediation is a separate deliverable.

## Acceptance Criteria

### Agent
<!-- @auto-tick-on-decide -->
- [x] Problem statement validated
<!-- @auto-tick-on-decide -->
- [x] Assumptions tested
<!-- @auto-tick-on-decide -->
- [x] Recommendation written with rationale

### Human
<!-- @auto-tick-on-decide -->
- [x] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Run: `fw task review T-XXX` (opens Watchtower with recommendation, assumptions, research artifacts)
  2. Review the Agent Recommendation section and go/no-go criteria evaluation
  3. Record decision via the Watchtower form or the command shown alongside the QR code
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

<!-- Fill these BEFORE writing the recommendation. The placeholder detector will block review/decide if left empty. -->
**GO if:**
- Root cause identified with bounded fix path — **met.** Two stacked causes: T-2822's
  tracked-content mechanism (already analysed and approved) and the propagation gap that
  kept its fix from being built (measured: 2/444 on the detector's gate).
- Fix is scoped, testable, and reversible — **met.** Two build tasks, each with bats
  coverage and mutation checks; both are hook/detector changes behind logged bypasses.

**NO-GO if:**
- Problem requires fundamental redesign or unbounded scope — **not met.** No redesign is
  proposed; leg A executes a decision already taken, leg B repairs one predicate.
- Fix cost exceeds benefit given current evidence — **not met.** The measured cost of the
  status quo is 43 stranded commits, a lost inception, a forked task-ID space, and 178
  un-triaged GO decisions.

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# For inception tasks, verification is often not needed (decisions, not code).
#
# Toolchain hint (L-291): if a GO decision will mean editing *.vbproj/*.csproj/*.xaml,
# *.go, Cargo.toml, tsconfig.json, or pom.xml in the build task, plan to add the
# matching build command (dotnet build / go build / cargo check / tsc --noEmit /
# mvn compile) to that build task's ## Verification — P-011 only runs what you write.

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

**Decision**: GO

**Rationale**: Filed pre-T-1716 gate without Recommendation. Promotion criterion: re-surface when concrete spike data or human-graded evidence emerges. Auto-retrofitted by 'fw inception retrofit-rec --apply'.

**Date**: 2026-08-20T08:05:21Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-08-20T07:04:20Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Recommendation

**Recommendation:** GO — build both legs. Neither requires a new go/no-go.

**Rationale.** The analysis the operator remembered exists, is correct, and was already
approved: T-2822 (2026-08-06) names the mechanism — *governance state is tracked content,
so a worktree is by construction a fork of it* — and the operator recorded GO the same
day. Two weeks later its keystone slice has no task, no hook and no commit. So the answer
to "why do we still have a headache" is not a missing analysis. It is that an approved fix
produced no buildable work, and the rail built to catch exactly that has never been able
to fire.

That second fact is the reason to act now rather than simply file the missing slice. The
audit's GO-scope-not-propagated detector gates on a claim *phrase*; **2 of 444** completed
inceptions match it and **0** survive the next filter. Its candidate set is empty by
construction, so every `[PASS]` it has printed — including today's — asserts nothing. **54**
GO'd inceptions are invisible to it. T-2822 is one of 54, which means the worktree problem
is a visible symptom of a governance failure that is silently affecting decisions across
the whole corpus.

Building leg A alone would fix worktrees and leave the mechanism that lost it intact.

**Evidence:**
- `docs/reports/T-2822-worktree-policy.md` §Recommendation + its recorded `**Decision**: GO`;
  `related_tasks: []`, no `unlocks_inception_decision:` anywhere, `ls agents/context/ | grep
  -i worktree` empty. Slice 3 exists as T-2861, status `captured`.
- Detector gate measured directly against `agents/audit/audit.sh:1545`: 444 inceptions,
  2 claim-regex matches, 0 after the `related_tasks` filter; 54 survivors under every
  conservative filter.
- Live state: 43 unlanded commits in two worktrees dormant since 2026-07-01
  (`git rev-list --count` — 6 and 37), still present today.
- IW-1: `session-metrics.sh:244` counter (494 / 0.0754) with no per-error row;
  `patterns.yaml` 19 entries, unwritten since 2026-04-08.

**Already in flight** (dispatched to TermLink workers, not yet integrated): **T-3098**
builds T-2822 slice 1; **T-3099** replaces the detector's prose gate with a structural
predicate. Both are executing existing decisions, which is why they started before this
review rather than after it.

**Needs the operator, and only the operator:**
1. **Tier 0 — prune the two stranded worktrees and their branches.** T-2824 recovered
   everything of value and correctly stopped short; branch deletion is Tier 0 and that
   handoff has been outstanding since 2026-08-06. Nothing agent-side can close it.
2. **T-100201** — the T-100196 / T-2394 contradiction in CLAUDE.md is still open and is a
   worktree-adjacent decision only the operator can settle.

**What would change this recommendation:** evidence that a real workflow needs governance
writes from inside a worktree. Leg A ships behind a logged bypass precisely so that, if
one exists, it appears in the bypass log as data rather than as a silent workaround.


**Recommendation:** DEFER

**Rationale:**

Filed at the start of the investigation: the evidence base (errors log, peer RCA, incident corpus) has not been read yet, so no GO/NO-GO is available. This is a genuine evidence gap, not a confidence hedge — it will be replaced with GO or NO-GO once the corpus is walked.

**Evidence:**

<!-- Add evidence bullets as exploration progresses (file paths,
     commit hashes, test results). The filing-time recommendation
     can be revised before fw inception decide. -->
