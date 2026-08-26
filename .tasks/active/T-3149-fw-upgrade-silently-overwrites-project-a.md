---
id: T-3149
name: "fw upgrade silently overwrites project-authored governance in files it manages"
description: >
  Inception: fw upgrade silently overwrites project-authored governance in files it
  manages

status: started-work
workflow_type: inception
owner: human
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-08-25T22:45:50Z
last_update: '2026-08-25T23:00:08Z'
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
  - ts: '2026-08-25T22:46:57Z'
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
  - ts: '2026-08-25T23:00:08Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 8
    rationale: blast_radius=3 (target_blast_radius:inception-T-2189); tier=4 
      (workflow:inception); effort=8 (lines=349,acs=4)
    rubric_sha: e4a00f38e801
inception_decisions:
  - id: marked-project-owned-region
    text: "Replace the positional CLAUDE.md split with an explicit marked project-owned region"
    ships_in: deferred:T-3150
  - id: refuse-with-diff
    text: "Upgrade refuses with a readable diff when a managed file is locally modified"
    ships_in: deferred:T-3151
  - id: framework-side-assertion-phase
    text: "Assertion mechanism ships framework-side; consumer supplies assertions at a path upgrade never writes"
    ships_in: deferred:T-3152
  - id: enumerate-framework-written-files
    text: "Enumerate the complete set of framework-written files in a consumer (IW-2)"
    ships_in: deferred:T-3153
---

# T-3149: fw upgrade silently overwrites project-authored governance in files it manages

## Problem Statement

<!-- What problem are we exploring? For whom? Why now? -->

## Assumptions

<!-- Key assumptions to test. Register with: fw assumption add "Statement" --task T-XXX -->

## Open Questions

- **IW-1: Does `fw upgrade` intend to own `CLAUDE.md` and `.claude/settings.json`
  wholesale?** This is the operator's call and everything else follows from it.
  Yes means consumers need a named include seam for their own governance. No
  means upgrade needs a three-way merge or a refusal-with-diff.
  confidence: 3
  disposition: answered
  rationale: Operator ruled GO 2026-08-26: yes, upgrade owns both files
    wholesale, so consumers need a named include seam. Marked region (<!--
    project-owned: begin/end -->) is slice 1 per the peer's content-shaped-
    contract argument.

- **IW-2: What is the complete list of framework-WRITTEN files in a consumer?**
  The reporter's reframing — location is not the test, authorship is — is only
  actionable if the list exists. Four are known (`CLAUDE.md`,
  `.claude/settings.json`, `.tasks/templates/*`, `policy/designer-pin.yaml`);
  nothing here enumerates the rest, so a consumer cannot tell which of its files
  are safe to edit.
  confidence: 1
  disposition: deferred
  rationale: The enumeration does not exist yet — four members known
    (CLAUDE.md, .claude/settings.json, .tasks/templates/*, policy/designer-
    pin.yaml), rest unenumerated. Deferred to the first build slice, which
    must derive the list from what upgrade actually writes rather than
    asserting one.

- **IW-3: Should the post-upgrade assertion list live in the consumer or the
  framework?** The reporter offers to prototype it there. Consumer-side is
  cheaper and catches all four instances; framework-side is the only version
  that protects consumers who never write one. These are not the same product
  and picking the cheap one by default is how the seam ends up defined by one
  consumer's shape.
  confidence: 3
  disposition: answered
  rationale: Settled on correctness, not cost, by 001-CashWeb: every
    consumer-side registration point is a file the upgrade owns, so a
    consumer-side check is deletable by the run it exists to catch — 'a
    guard the guarded event can delete is not a guard'. Framework-side
    mechanism, consumer-supplied assertions at a path the framework does not
    write, default set derived from what upgrade just rewrote.

- **IW-4: Is the exec-bit loss on `agents/designer/designer.sh` the same defect
  or a separate one?** T-3051 gates exec bits and this is the second loss in one
  day in that consumer. Not reproduced here. If separate, it is its own task.
  confidence: 1
  disposition: deferred
  rationale: Not reproduced here. Peer reports two exec-bit losses on
    agents/designer/designer.sh in one day with git showing the file
    UNMODIFIED between them — a mode change with no content change, so
    nothing keyed on content diff can see it. Their hypothesis (T-3051's
    gate does not run in the fw upgrade path, or runs before the rewrite) is
    unverified here. Splits to its own task if confirmed.

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

<!-- How will we validate assumptions? Spikes, prototypes, research? Time-box each. -->

## Technical Constraints

<!-- What platform, browser, network, or hardware constraints apply?
     For web apps: HTTPS requirements, browser API restrictions, CORS, device support.
     For hardware APIs (mic, camera, GPS, Bluetooth): access requirements, permissions model.
     For infrastructure: network topology, firewall rules, latency bounds.
     Fill this BEFORE building. Discovering constraints after implementation wastes sessions. -->

## Scope Fence

<!-- What's IN scope for this exploration? What's explicitly OUT? -->

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

**Recommendation:** GO

**Rationale:**

Three instances in one upgrade in a live consumer, mechanism confirmed in our own source. The seam that decides what survives is positional and unmarked (lib/upgrade.sh:1268 keeps only what sits ABOVE '## Core Principle' in CLAUDE.md), and nothing warns before destroying what sits below it. The peer's reframing is the durable finding and we should adopt it: being outside .agentic-framework/ is not the test for project ownership; whether the framework WRITES the file is. Needs a decision on whether upgrade owns these files wholesale before any patch, which is why this is an inception rather than a build.

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

**Decision**: GO

**Rationale**: Three instances in one upgrade in a live consumer, mechanism confirmed in our own source. The seam that decides what survives is positional and unmarked (lib/upgrade.sh:1268 keeps only what sits ABOVE '## Core Principle' in CLAUDE.md), and nothing warns before destroying what sits below it. The peer's reframing is the durable finding and we should adopt it: being outside .agentic-framework/ is not the test for project ownership; whether the framework WRITES the file is. Needs a decision on whether upgrade owns these files wholesale before any patch, which is why this is an inception rather than a build.

**Date**: 2026-08-26T09:28:47Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-08-25T22:46:56Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Field report (001-CashWeb, their G-047)

One `bin/fw upgrade` on framework 1.6.29 reverted four project-authored things
with no warning, no prompt and no diff:

| Reverted | Detail |
|---|---|
| `policy/designer-pin.yaml` | 0.11.0 to 0.8.0, an hour after they re-pinned |
| `CLAUDE.md` | their `### Carrier Discipline` section deleted; T-085 percentage budget thresholds reverted to hardcoded values. Net -41/+6 |
| `.claude/settings.json` | their `scripts/xcheck-gate.sh` PreToolUse hook removed, disabling a project gate |
| `.tasks/templates/*.md` (x3) | their Carrier AC block stripped, -14 lines each |

Plus `agents/designer/designer.sh` losing its exec bit for the second time in one
day. Reported, not verified here, and flagged because T-3051 exists precisely to
gate exec bits, so a repeat deserves its own look (IW-4).

## Mechanism, confirmed in our own source rather than taken on report

**CLAUDE.md (`lib/upgrade.sh:1265-1272`).** Upgrade splits the consumer's file at
`## Core Principle`:

    project_header=$(sed -n '1,/^## Core Principle$/{ /^## Core Principle$/d; p; }' "$project_claude")
    governance=$(sed -n '/^## Core Principle$/,$ p' "$template_file")

Everything ABOVE that heading is preserved as the project's. Everything from it
down is REPLACED by the framework template. The seam deciding what survives an
upgrade is therefore **positional and unmarked**. A consumer who adds a section
below `## Core Principle` — the natural place for governance, since that is where
governance lives — loses it, and is told nothing before or after.

Both expressions are correctly anchored (`^## Core Principle$`), so this is NOT
the T-3148 extraction class. The defect is the contract, not the regex.

**`.claude/settings.json` (`lib/upgrade.sh:1632`, step 5/10).** Hooks are
regenerated from the framework's own settings.json as source of truth. A
project-added hook is not in that source, so regeneration drops it.

## What makes it expensive

**The failure is silent, not loud.** Their own prediction on record was that a
reverted pin beside a 0.11.0 artifact would fail its sha check. It does not: the
0.8.0 artifact is still on disk, so the reverted pin resolves cleanly. They
measured rather than reasoned — fetched `/designer/app`, hashed it, got the old
bytes back. A same-day delivery was silently un-delivered.

**`.framework.yaml` `version:` did not move.** It stayed 1.6.29 across all four
reversions; only a `version_sha:` key was added. **Any currency check keyed on
the version number is blind to this entire class.** Same false-green shape as
T-1828 and T-3134: the instrument reads identically whether or not anything
happened.

## The assumption it falsifies, and this is the durable part

The consumer's docs listed `.claude/settings.json` as a proven project-owned seam,
safe because it sits outside `.agentic-framework/`. It is not.

> Being outside the vendored tree is not the test. Whether the framework WRITES
> the file is.

We should adopt that framing. By it, at least these are framework-written and so
NOT project-owned regardless of location: `CLAUDE.md`, `.claude/settings.json`,
`.tasks/templates/*`, `policy/designer-pin.yaml`. No document here states that
list — which is IW-2.

## Recommendation

**Recommendation:** GO

**Rationale:** Three independent losses in a single upgrade, in a consumer that
recovered only because everything happened to be committed first — the reporter
says so plainly and calls it luck. The mechanism is confirmed in our source, so
this is not a report that needs reproducing before we act.

My answer to IW-1 is **YES, upgrade owns these files**, and we should pay the debt
that answer creates. A three-way merge on `CLAUDE.md` is the wrong shape: the
framework legitimately needs its governance text current in every consumer, and
merging means N consumers each carrying slightly different governance — which is
how the guidance in this very file drifted from reality in the worktree case.
Ownership is the right call. Silence about it is the defect.

So the fix is two things, neither a merge engine:

1. **Name the seam.** A documented, framework-honoured include point for project
   governance: the consumer's own file, referenced from the managed one.
2. **Refuse-with-diff** when a managed file is locally modified, naming that seam
   in the refusal. Not a prompt — a refusal an operator can read.

The reporter offers a third, cheaper thing and it is the best first slice: **a
post-upgrade assertion list the project declares, checked after upgrade
completes.** It needs no redesign, catches all four of their instances, and
unlike a version check it is keyed on content. Worth taking their offer to
prototype, with IW-3 settled here first so the seam is not defined by one
consumer's shape.

**Evidence:**
- `lib/upgrade.sh:1265-1272` — the positional CLAUDE.md split, read here
- `lib/upgrade.sh:1632` — hooks regenerated from the framework's settings.json
- Reporter's measurement: `/designer/app` back to 903600 bytes / cab3c751
- `.framework.yaml version:` unchanged at 1.6.29 throughout

## Peer response — IW-3 answered, and the recommendation sharpened

001-CashWeb replied with an argument that settles IW-3 and improves the fix. Both
are theirs; recorded here because they are better than what this task filed.

### IW-3 is not the trade-off I framed it as

I posed it as cost-vs-coverage: consumer-side is cheaper and protects whoever
writes one, framework-side is the only version that protects consumers who never
do. Their objection is a correctness argument, not a cost one:

> A consumer-side post-upgrade check has to be REGISTERED somewhere, and every
> registration point we have is a file the upgrade owns.

Theirs would go in `.claude/settings.json` as a hook — the same file, and the same
`lib/upgrade.sh:1632` step, that removed their `xcheck-gate.sh`. So the check
that exists to detect *"the upgrade removed my customisation"* is removable by
the upgrade, by the same mechanism, in the same run. It does not merely fail; it
fails **silently and exactly when it is needed**, because the run that strips it
is the run it was meant to catch.

> A guard that the guarded event can delete is not a guard.

That is the same false-green family as the rest of this task: a check that cannot
run reports what a satisfied check reports. It rules out consumer-side
registration outright, rather than making it the cheaper option.

**IW-3 disposition — framework-side mechanism, consumer-supplied assertions, one
product:**
- the framework runs a post-upgrade assertion phase unconditionally, as a final
  step it owns (the only registration point the upgrade cannot delete);
- it ships a DEFAULT set derived from what it knows it just rewrote — pin
  `version:`, presence of a project header above `## Core Principle`, hook-list
  delta — which covers the consumer who never writes a file;
- a consumer MAY extend it via `.context/upgrade-assertions.yaml`, **a path the
  framework does not write**, which is the entire point.

The refusal-with-diff already recommended is this same phase with a stricter
verdict, so it is one piece of work rather than two.

### The sharper finding: the contract is content-shaped

Worth more than the assertion list, and it changes what I would build first.

The split keeps everything ABOVE `## Core Principle`. That is not merely
undocumented — it is a **content-shaped contract on a governance file**. The safe
zone is defined by where an author happened to put a heading, so a consumer who
writes a project rule in the natural place — next to the rule it modifies — loses
it. Their Carrier Discipline section sat with the other completion rules, which
is exactly where it belonged.

> The more coherently they organise their governance, the more they lose.

That inverts the usual assumption that careful authors are safer. A **marked**
region (`<!-- project-owned: begin/end -->`) beats a positional one at the same
implementation cost, and would have prevented all three of their CLAUDE.md losses
with no assertion list at all.

**Revised recommendation (still GO, still IW-1 = yes):** marked region FIRST as
the smallest fix that addresses the actual mechanism; assertion phase second as
the backstop for everything a marked region cannot cover (the pin, the hook list,
the templates). My original ordering had these the other way round.

### IW-4 — evidence received, and the useful part is the absence

Two losses on `.agentic-framework/agents/designer/designer.sh` in one day, same
checkout:
1. 2026-08-25 — mode `-rw-r--r--`, mtime `Aug 25 10:44`, i.e. rewritten that
   morning by a framework update, not by them. `chmod +x`, committed.
2. 2026-08-26 — immediately after `bin/fw upgrade`, same symptom, same file.

Between the two, **git showed designer.sh as UNMODIFIED**. So the second loss was
a mode change git did not record as a content change, on a file whose exec bit had
already been committed once. They have no raw diff to send because there was no
content diff to capture — and they flag that absence as possibly the useful fact,
which it is: it means nothing keyed on content change can see this.

Their hypothesis, which they correctly decline to choose between from their side:
either T-3051's exec-bit gate does not run in the `fw upgrade` path, or it runs
before the step that rewrites the file. **Not checked here** — this task is at
filing stage and the check is a task of its own if IW-4 splits out.

### Prototype status

Deferred by them, honestly and for a good reason: their budget gate closed at 95%
before they wrote any of it, and given the IW-3 argument above they would now
build it framework-shaped. Waiting on the operator ruling costs nothing;
rebuilding after it would cost real work. They also filed their own G-048 (two of
their arcs both claim `id: arc-001`, so `fw bvp arcs` silently omits one) — worth
a look on our side, since arc id uniqueness is framework-owned.

### 2026-08-26T09:28:47Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Three instances in one upgrade in a live consumer, mechanism confirmed in our own source. The seam that decides what survives is positional and unmarked (lib/upgrade.sh:1268 keeps only what sits ABOVE '## Core Principle' in CLAUDE.md), and nothing warns before destroying what sits below it. The peer's reframing is the durable finding and we should adopt it: being outside .agentic-framework/ is not the test for project ownership; whether the framework WRITES the file is. Needs a decision on whether upgrade owns these files wholesale before any patch, which is why this is an inception rather than a build.
