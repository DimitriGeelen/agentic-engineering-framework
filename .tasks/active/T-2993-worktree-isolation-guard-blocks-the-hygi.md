---
id: T-2993
name: "worktree isolation guard blocks the hygiene it exists to enable"
description: >
  Inception: worktree isolation guard blocks the hygiene it exists to enable

status: started-work
workflow_type: inception
owner: human
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-08-14T18:50:44Z
last_update: 2026-08-14T18:51:53Z
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
  - ts: '2026-08-14T18:51:53Z'
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

# T-2993: worktree isolation guard blocks the hygiene it exists to enable

## Problem Statement

A session running inside `.claude/worktrees/T-021-hygiene` on a consumer project
(005-Yellowtwig) was doing exactly what its name says: deciding whether three
sibling worktrees could be pruned. Two of them belonged to a finished task
(T-020). The safe way to answer that is to look for uncommitted work in each one
before removing it.

Both attempts were refused:

```
git -C …/.claude/worktrees/T-020-audit-remediation status --short
→ This session is isolated in the worktree …/T-021-hygiene, but this command
  redirects git to the shared checkout via -C. Refusing to run it — a
  worktree-isolated session's git operations must target its own worktree. Run
  the equivalent from …/T-021-hygiene without the redirect.
```

Three things are wrong with that, in increasing order of seriousness:

1. **The message misdescribes its own target.** The `-C` path was a *sibling
   worktree*, not the shared checkout. The guard appears to classify any `-C`
   away from `$PWD` as "the shared checkout".
2. **The suggested remedy cannot work.** "Run it from your own worktree without
   the redirect" answers a question about `T-021-hygiene`. The question was
   about `T-020-close`. There is no non-redirected form of it.
3. **The blocked command was the safety check.** `git status --short` is
   read-only. The guard permitted the session to proceed toward `worktree
   remove` while denying it the one observation that makes removal safe — so
   the guard's net effect on this session was to make a destructive action
   *less* informed, not more.

The session's own conclusion — "cross-worktree git is (correctly) blocked from
here — pruning happens after I exit" — is the tell. It accepted the refusal as
correct and deferred the work to a session that no longer had the context for
it. That is the streamlining question the operator is asking about.

## Assumptions

- **A1** — The guard is a framework artefact (ours to fix), not a Claude Code
  built-in or a Yellowtwig-local hook. *Untested; spike 1 settles it.*
- **A2** — The guard's predicate is "`-C` points outside `$PWD`", with no
  distinction between the shared checkout and a sibling worktree. *Inferred
  from the message being wrong about which one it hit.*
- **A3** — Read-only git verbs are blocked identically to mutating ones. *Both
  observed refusals were `status --short`.*
- **A4** — This is not a Yellowtwig-specific incident: `fw worktree gc` and
  `fw worktree remove` in this repo already inspect sibling worktrees with
  exactly the `git -C "$wt_path" status --porcelain` shape the guard refuses
  (`lib/worktree.sh:398`), so the same collision is reachable here. *Strong
  prior from grep; needs confirming the guard would fire on it.*

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

- **IW-1: Where does the guard live, and is it ours?**
  confidence: 3
  disposition: answered
  rationale: Not ours — absent from all framework/consumer source; carries none of the `PreToolUse:… hook error` + `Policy: P-XXX` shape every fw hook emits; harness owns worktree isolation via EnterWorktree/ExitWorktree. A1 refuted. See T-2993 report §Spike 1.

- **IW-2: Does its predicate distinguish a sibling worktree from the shared checkout, and read-only verbs from mutating ones?**
  confidence: 3
  disposition: answered
  rationale: Neither — it misnames a sibling worktree as "the shared checkout" and blocks `status --short`. But the blocked check was itself a false-green (status misses unpushed commits, the T-2428 strand class), so the defect matters less than it looked. A2, A3 hold.

- **IW-3: Does the framework's own worktree hygiene (`fw worktree gc` / `remove`, `lib/worktree.sh:398`) collide with it, or is 005-Yellowtwig's flow unusual?**
  confidence: 3
  disposition: answered
  rationale: No collision — the `git -C "$wt_path"` at lib/worktree.sh:398 is script-internal, outside a command-string guard's reach (same scope boundary as our Tier 0). `fw worktree gc` ran clean here: 4 reclaimable / 8 keep with unlanded-commit counts. A4 holds with that twist.

- **IW-4: Is the right remedy to narrow the guard, or to give isolated sessions a sanctioned cross-worktree read verb they don't have today?**
  confidence: 2
  disposition: answered
  rationale: Neither. Cannot narrow (not ours); the verb already exists (`fw worktree gc|status|remove`). The gap is routing to it, plus the absence of any worktree model in the designer corpus (0 of 8 maps mention worktrees). See report §The actual gap.

## Exploration Plan

**Spike 1 (15 min) — locate the guard.** Grep the consumer, its vendored
`.agentic-framework/`, its `.claude/settings*.json` hook wiring, and this repo.
Settles IW-1 and A1. If it is not ours, the deliverable is a filed report to
whoever owns it, not a code change here.

**Spike 2 (15 min) — read its predicate.** Determine what it matches on:
`-C` presence, path-outside-`$PWD`, verb class. Settles IW-2, A2, A3.

**Spike 3 (10 min) — test the collision against our own tooling.** `fw worktree
gc --dry-run` from inside a worktree in this repo. If it refuses, A4 holds and
the blast radius is every consumer, not one. Settles IW-3.

## Technical Constraints

<!-- What platform, browser, network, or hardware constraints apply?
     For web apps: HTTPS requirements, browser API restrictions, CORS, device support.
     For hardware APIs (mic, camera, GPS, Bluetooth): access requirements, permissions model.
     For infrastructure: network topology, firewall rules, latency bounds.
     Fill this BEFORE building. Discovering constraints after implementation wastes sessions. -->

## Scope Fence

**IN:** locating the guard; characterising its predicate; measuring whether our
own worktree tooling collides with it; a recommendation on narrow-the-guard vs
sanctioned-read-verb.

**OUT:** rewriting the worktree lifecycle; the T-100201 session-on-master vs
T-2394 merge-only conflict (adjacent, separately tracked); anything in the
005-Yellowtwig repo itself — findings there get reported, not fixed from here
(§Gap Homing).

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

**Recommendation:** GO — model the worktree lifecycle in the designer corpus
first, then route to the verb we already have.

**Rationale:**

Re-filed from DEFER. The DEFER was honest at filing (I could not say who owned
the guard) and the spikes closed that gap in three greps — but they also
displaced the frame I filed under, so the change is substantive, not a
confidence upgrade.

**What I expected to find and did not:** an over-broad framework guard to
narrow. The guard is the Claude Code harness's, not ours. We cannot change it,
and the whole "narrow the predicate" branch is unreachable.

**What is actually true:** the blocked command was `git status --short`, which
reports uncommitted files. The thing that strands work in a worktree is
*unpushed commits* — the T-2428 class. So the harness blocked a check that
would have returned a **false green** on a worktree holding unpushed work. The
session was not stopped from doing something necessary; it was stopped from
doing something weaker than `fw worktree gc`, which we already ship and which
reports exactly the unlanded-commit state `status` cannot see.

**So the loss is routing, not capability.** A capable session hit a refusal
that named no alternative — the harness has no idea `fw worktree gc` exists —
believed it, and deferred real work out of the session that had the context
for it.

**And underneath that, the finding worth acting on.** This is the third
recorded instance of one class — teardown driven from inside the thing being
torn down (§Trunk-Based Session Flow's "never run integrate from inside the
worktree it will remove"; T-2825/G-075's ephemeral-worktree handoff rule; this).
Each was patched as its own paragraph. The general form is one line:
*operations on the set of worktrees belong to the main checkout; operations
within one worktree belong to that worktree.*

The corpus grep is what makes this a GO rather than another paragraph. Eight
canonical designer maps — task, session, inception, dispatch, audit, tier-0,
two onboarding — and **zero** mention worktrees, while §Trunk-Based Session
Flow makes the worktree the mandatory path for all real code. The one
lifecycle every code change must traverse is the one lifecycle nothing models.
That is a direct yes to the operator's "should we start with a workflow
design?", and it is the artefact prose has now failed to substitute for three
times.

Scoped deliberately small: a map plus a routing nudge, not a rewrite of the
worktree lifecycle. Reversible, and the map is the cheap half.

**Evidence:**

- Guard absent from `lib/`, `agents/`, `bin/`, consumer `.agentic-framework/`
  (v1.6.212), and the whole 005-Yellowtwig tree — 4 message fragments, 0 hits.
- Consumer hook wiring enumerated: 25 hooks, all `fw hook <name>`, none this.
- Framework refusals carry `PreToolUse:… hook error` + `Policy: P-XXX`; this
  one carries neither (4 live examples produced during this session).
- `EnterWorktree`/`ExitWorktree` are harness built-ins governing exactly this.
- `fw worktree gc` here: `4 reclaimable, 8 to keep (unlanded work)`, with
  per-branch unlanded counts and Tier-0-held branch deletes.
- `lib/worktree.sh:398` already uses `git -C "$wt_path" status --porcelain`,
  script-internal — the same scope boundary CLAUDE.md documents for Tier 0.
- Designer corpus: 8 canonical maps, `grep -io worktree` → **0**.
- Prior instances of the class: T-2428 (6 commits stranded 5 weeks),
  T-2825/G-075, T-100194/T-100199.

**Known limit:** the script-internal-survives-the-guard claim is a structural
inference, not a measurement — it was not run from inside an isolated worktree
session, because this session is in the main checkout and cannot reproduce the
guard. A build task should verify it before depending on it.

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

### 2026-08-14T18:51:53Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
