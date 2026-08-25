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
last_update: 2026-08-25T22:46:56Z
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
  confidence: 2
  disposition:
  rationale:

- **IW-2: What is the complete list of framework-WRITTEN files in a consumer?**
  The reporter's reframing — location is not the test, authorship is — is only
  actionable if the list exists. Four are known (`CLAUDE.md`,
  `.claude/settings.json`, `.tasks/templates/*`, `policy/designer-pin.yaml`);
  nothing here enumerates the rest, so a consumer cannot tell which of its files
  are safe to edit.
  confidence: 1
  disposition:
  rationale:

- **IW-3: Should the post-upgrade assertion list live in the consumer or the
  framework?** The reporter offers to prototype it there. Consumer-side is
  cheaper and catches all four instances; framework-side is the only version
  that protects consumers who never write one. These are not the same product
  and picking the cheap one by default is how the seam ends up defined by one
  consumer's shape.
  confidence: 2
  disposition:
  rationale:

- **IW-4: Is the exec-bit loss on `agents/designer/designer.sh` the same defect
  or a separate one?** T-3051 gates exec bits and this is the second loss in one
  day in that consumer. Not reproduced here. If separate, it is its own task.
  confidence: 1
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

<!-- Filled at completion via: fw inception decide T-XXX go|no-go --rationale "..." -->

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
