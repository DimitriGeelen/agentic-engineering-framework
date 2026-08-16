---
id: T-3041
name: "AEF under multiple uids — de-rooting the framework's shared state"
description: >
  Inception: AEF under multiple uids — de-rooting the framework's shared state

status: started-work
workflow_type: inception
owner: human
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-08-16T16:32:07Z
last_update: 2026-08-16T16:34:21Z
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
  - ts: '2026-08-16T16:34:22Z'
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

# T-3041: AEF under multiple uids — de-rooting the framework's shared state

## Problem Statement

<!-- What problem are we exploring? For whom? Why now? -->

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

- **IW-1: Which users are agent runtimes, and is `root` staying a principal at all?**
  confidence: 0
  disposition:
  rationale:
  <!-- Operator-only. Determines whether the end state is "root + others share a
       group" (A) or "no agent runs as root" (a much larger migration: cron,
       systemd units, Watchtower, /opt ownership). Everything downstream forks
       on this answer, so it is asked first and not guessed. -->

- **IW-2: Does a shared POSIX group + setgid + umask actually hold, or does it
  convert hard failures into silent lost updates?**
  confidence: 2
  disposition:
  rationale:
  <!-- The concern is specific, not vague: `.context/working/*` files that are
       rewritten wholesale via temp+mv are single-writer by construction. Today a
       second principal gets a clean EACCES. Group-writable, it gets a successful
       write that silently discards the other principal's state. That is strictly
       worse for D2/Reliability, and it is why A is not recommended alone. Needs a
       spike: two uids, concurrent `fw context focus` + counter writes, measure
       lost updates. -->

- **IW-3: Which `.context/` state is genuinely shared and which is per-principal?**
  confidence: 2
  disposition:
  rationale:
  <!-- T-3038 already answered this for focus (shared file + per-key override +
       one resolver + reader fallback). The open part is the inventory: rows 5/6
       of the artifact's table are a guess until each write site is read. The
       append-only JSONL logs (row 7) are already multi-writer safe and need no
       change — lib/outcome.py documents the O_APPEND property explicitly. -->

- **IW-4: Is host provisioning (creating the group, umask, setgid) in `fw init` /
  `fw upgrade`'s remit, or is it operator setup the framework only *checks*?**
  confidence: 1
  disposition:
  rationale:
  <!-- Bears on Portability (D4): a framework that chgrps a consumer's tree is
       making a host-policy decision it has no authority to make. Leaning toward
       "fw doctor checks and reports, fw init documents" — but that is a
       disposition to record, not an assumption to bury. Live evidence this
       session: the agent could not perform the chmod itself (classifier block),
       so any design that *requires* the agent to provision is already known to
       fail in practice. -->

- **IW-5: Does the TermLink fix belong upstream, and does that block us?**
  confidence: 3
  disposition:
  rationale:
  <!-- Gap-homing (T-1333) says the socket/auth-model fix lives in the TermLink
       repo, not here. Confidence 3 because the code is not ours. The real
       question is whether our A+B work is independently useful while that sits
       upstream — believed yes, since group+setgid fixes our side of the socket
       without TermLink changing anything. -->

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

Forced by evidence, not preference: a non-root Codex agent cannot reach the TermLink hub on its own host while a remote host authenticates in fine, and three hubs now exist on this box purely because each uid that could not reach an existing hub silently started its own (OBS-296). The uid-coupling is not one bug; it runs through the socket, the repo tree, git object ownership, the .context write path and cron. Doing nothing means every additional non-root agent fragments the substrate further and silently. The shape of the fix is known (shared group + setgid + umask + per-principal vs shared state split, the T-3038 focus-isolation pattern generalised), so this is scoping and sequencing work, not open research.

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

### 2026-08-16T16:34:21Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
