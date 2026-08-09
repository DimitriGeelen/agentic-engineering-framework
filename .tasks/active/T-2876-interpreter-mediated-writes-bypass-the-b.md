---
id: T-2876
name: "Interpreter-mediated writes bypass the Bash task gate — stop safe-listing python3"
description: >
  Inception: Interpreter-mediated writes bypass the Bash task gate — stop safe-listing
  python3

status: started-work
workflow_type: inception
owner: human
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-08-08T17:12:42Z
last_update: '2026-08-09T17:15:07Z'
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
  - ts: '2026-08-08T17:14:12Z'
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
  - ts: '2026-08-08T17:15:06Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 6
    rationale: blast_radius=3 (no-signal); tier=4 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-09T17:15:07Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 7
    rationale: blast_radius=3 (no-signal); tier=4 (no-signal); effort=7 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2876: Interpreter-mediated writes bypass the Bash task gate — stop safe-listing python3

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

- **IW-1: Is the safe-list's `python3 -c` entry removable, or does something depend on it
  that survives the P-011 argument?**
  confidence: 2
  disposition: answered
  rationale: ANSWERED NO — nothing depends on it that survives the P-011 argument. The only
    concrete dependency either project named was the yaml.safe_load idiom in Verification
    blocks, and 832 measured it away on their tree (rail 470 §3) — check-active-task is wired
    at PreToolUse only, matcher Write|Edit|Bash, and update-task.sh references it ZERO times,
    so Verification-block python never touches this hook. Caveat kept honest: that is a second
    TREE, not a second implementation (they vendor our hook — L-546), and it is still not
    observed end-to-end with python3 actually absent from the safe-list. Hence confidence 2,
    not 3. Original text below.
  original_rationale: §4 of the artifact argues the cited cost (yaml.safe_load in Verification blocks)
    is against a population this hook never gates, because PreToolUse fires on the agent's
    tool calls and not on subprocesses `update-task.sh` spawns. Structural and high-confidence,
    but not yet measured end-to-end. Not 3 until a Verification block is observed running with
    python3 absent from the safe-list.

- **IW-2: Does `grep`/`cat` actually substitute for interactive python one-liners in the
  no-task / drift / completed-focus states, or does removal create a new recovery deadlock?**
  confidence: 1
  disposition: deferred
  rationale: DEFERRED to the build slice, and it is the GATING question for that slice — an
    evidence gap, not a confidence hedge. Asked 832 to falsify it (rail 471); they answered
    honestly that they cannot, and explicitly declined to press their one datapoint into
    service (their base64-decode observation argues removal costs LESS in that specific case
    only, and they refused to inflate it — rail 473 §6). So it remains unmeasured on both
    sides. MUST be measured before the removal lands, because it decides whether the fix is
    cheap or relocates the deadlock.
    EVIDENCE ADDED 2026-08-08 (T-2879) — relocation is now OBSERVED, not projected, though
    still not the general answer. T-2878 exempted the capture verbs from the Bash gate and
    pinned it with bats. The first real use of that fix, one minute after closing the task
    and in the null-focus state it exists to serve, was BLOCKED — not by the verbs but by
    `2>&1`, which `_fw_chain_split` treated as a chain separator, splitting `fw note "x" 2>&1`
    into `fw note "x" 2>` and `1` and failing the compound. The bats suite stayed green
    throughout because it tested the bare verb form the fix was designed for. So a safe-list
    remedy DID relocate a deadlock rather than remove it, immediately, for the author, with
    green tests. That does not answer IW-2's actual question (whether grep/cat substitute for
    interactive python in recovery states) and must not be read as answering it — it raises
    the prior that safe-list surgery relocates rather than removes, and it demonstrates the
    specific failure mode to design the IW-2 measurement against: test the shape you will
    type, not the shape the fix was written for. Disposition stays DEFERRED. Original below.
  original_rationale: Explicitly the JUDGEMENT half of §4, separated from the structural half so it
    cannot ride on the latter's confidence. The framework has a documented history of remedies
    that relocate a deadlock rather than remove it (T-2821 moved the empty-worktree deadlock;
    T-2875 nearly substituted a second dead remedy). Unmeasured.

- **IW-3: Is the scope `python3` alone, or every interpreter on the safe-list?**
  confidence: 1
  disposition: deferred
  rationale: DEFERRED to the build slice as a scope decision, per the artifact §5 — the GO is
    on the DIRECTION (write-free by construction, not enumeration), and scope belongs to the
    slice that builds it. Sharpened since filing by 832 rail 473 §4: the safe-list groups
    curl|wget|date|uname|ps|... as read-only info commands, and curl genuinely satisfies "does
    not modify local state" — the CATEGORY is what fails, because a command can be perfectly
    read-only and still be the INPUT to something that writes. The list classifies by what
    commands DO; composition is about what they CARRY. So the scope question is not "which
    interpreters" but "which entries can carry", which is a wider set than the interpreter
    list. "Bound rather than close" remains legitimate (precedent
    tests/unit/tier0_scope_boundary.bats) and must not be assumed away. Original text below.
  original_rationale: `bash -n`, and any node/perl/ruby entries, sit on the same boundary — a safe-listed
    interpreter is a general computer. Fixing python3 alone may just move the traffic.
    `tests/unit/tier0_scope_boundary.bats` pins the analogous Tier 0 limit as a deliberate
    scope boundary, so precedent exists for BOUNDING rather than closing — that is a legitimate
    disposition for this question and should not be assumed away.

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

Measured, not argued: 7 write idioms reach the filesystem with no active task, skipping the task check, G-020 and focus-drift, leaving nothing in the bypass log. Direction is settled by 832's row-7 argument — subprocess.call(cmd, shell=True) carries no textual signature at all and re-admits the five os.* names the deny-list explicitly denies, so enumeration is not a slow fix, it is void. GO rather than DEFER because the evidence is complete on both sides and the remedy's assumed cost is illusory: Verification-block python runs inside P-011 via update-task.sh, where PreToolUse hooks do not fire, so removal does not touch that population. Open question is scope of removal, not whether.

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

**Rationale**: Measured, not argued: 7 write idioms reach the filesystem with no active task, skipping the task check, G-020 and focus-drift, leaving nothing in the bypass log. Direction is settled by 832's row-7 argument — subprocess.call(cmd, shell=True) carries no textual signature at all and re-admits the five os.* names the deny-list explicitly denies, so enumeration is not a slow fix, it is void. GO rather than DEFER because the evidence is complete on both sides and the remedy's assumed cost is illusory: Verification-block python runs inside P-011 via update-task.sh, where PreToolUse hooks do not fire, so removal does not touch that population. Open question is scope of removal, not whether.

**Date**: 2026-08-08T18:11:10Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-08-08T17:14:12Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-08-08T18:11:10Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Measured, not argued: 7 write idioms reach the filesystem with no active task, skipping the task check, G-020 and focus-drift, leaving nothing in the bypass log. Direction is settled by 832's row-7 argument — subprocess.call(cmd, shell=True) carries no textual signature at all and re-admits the five os.* names the deny-list explicitly denies, so enumeration is not a slow fix, it is void. GO rather than DEFER because the evidence is complete on both sides and the remedy's assumed cost is illusory: Verification-block python runs inside P-011 via update-task.sh, where PreToolUse hooks do not fire, so removal does not touch that population. Open question is scope of removal, not whether.
