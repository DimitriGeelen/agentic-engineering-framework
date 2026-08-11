---
id: T-2909
name: "Enforcement baseline cannot name what changed, so its own remedy launders a
  deleted gate"
description: >
  Inception: Enforcement baseline cannot name what changed, so its own remedy launders
  a deleted gate

status: work-completed
workflow_type: inception
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-08-10T19:34:59Z
last_update: 2026-08-10T20:10:00Z
date_finished: 2026-08-10T20:10:00Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── Inception scoring exception (T-2186 Slice 2 / T-2188). See 050-Inceptions.md §Scoring Exception. ──
target_blast_radius: 3            # int 0..9. Anticipated component count of the build work this inception would authorise on GO.
                                  # Substitutes for the absent components: list in the F8 cost formula (040). Required.
                                  # Guide: 0=docs only, 1=single file, 3=small subsystem (S), 5=cross-subsystem (M), 7=multi-arc (L), 9=framework-wide (XL).
voi_score: 0.5                    # float 0..1. Value of Information — expected value of resolving this question,
                                  # independent of build cost. Higher when answer affects many tasks or unblocks a strategic decision. Required.
bvp_scores_proposed:
  - ts: '2026-08-10T19:35:58Z'
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
  - ts: '2026-08-10T19:45:07Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 8
    rationale: blast_radius=3 (no-signal); tier=4 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2909: Enforcement baseline cannot name what changed, so its own remedy launders a deleted gate

## Problem Statement

The framework can lose an enforcement hook — including `check-tier0`, the only gate on
destructive Bash — and end up **green** at every surface that watches, having followed
its own printed instructions the whole way.

Three defects compose. None is dangerous alone; together they close the loop.

**D1 — no inverse verb.** `fw hook-enable` registers a hook (`bin/hook-enable.sh`, 188
lines, idempotent, atomic write). Nothing deregisters one. Removal is therefore
hand-edited JSON against `.claude/settings.json` — the single file holding `check-tier0`,
`check-active-task`, `budget-gate`, `block-plan-mode` and 13 others. An asymmetry like
that does not make removal *rare*; it makes removal *improvised*, on the
highest-consequence file in the repo, with no governed path to compare against.

**D2 — detection is one opaque bit.** `bin/fw:2248-2266` compares a single sha256 over
`json.dumps(hooks, sort_keys=True)`. Measured on a temp copy of the live file
(2026-08-10):

| scenario | hash | doctor says | tier0 still registered |
|---|---|---|---|
| baseline | `962690887ee10cb6` | `OK Enforcement baseline intact` | yes |
| benign ADD of one probe hook | `4a80de2ac8715e0e` | `FAIL Enforcement baseline CHANGED` | yes |
| `check-tier0` DELETED | `08341179c2aa8e4b` | `FAIL Enforcement baseline CHANGED` | **no** |

The two bottom rows are the same event as far as any operator or agent can observe.
The detector knows *that* the enforcement surface moved and cannot say *which way*.

**D3 — the printed remedy launders the loss.** The FAIL line's own next step is
`Run 'fw enforcement baseline' to update after review`. That writer (`bin/fw:7748-7770`)
recomputes the hash over whatever is currently on disk, prints `Enforcement baseline
saved`, and **never diffs against the prior baseline or names a single hook**. So the
sanctioned response to D2's ambiguous FAIL converts an accidental deletion into a
permanent, blessed state — and the next `fw doctor` reports `OK Enforcement baseline
intact` with Tier 0 gone. Worse, a PostToolUse hook (`check-settings-edit`, T-1886)
fires on every `Write|Edit` to settings.json specifically to *nudge* toward re-baselining.

D3 is what makes D1 and D2 more than untidy. The recovery path erases the evidence, so
the green reading afterwards is indistinguishable from a correct one — the same shape as
L-506 / L-570 / T-2902, but a new leg: **the detector's own remedy destroys the witness.**

**Why now.** 832 reported D1 on rail 517 §5 after their probe-hook cleanup took
`check-tier0` down for two tool calls (restored byte-exact; they added a regression guard
asserting `check-tier0` is still registered — a guard written by the task that removed it).
They filed their side as OBS-014 + PL-144 and explicitly did not fix it in our tree. D2 and
D3 are ours, were not in their report, and were found by checking whether their finding
was worse here than there. It is: their accident was caught by a human within two calls;
ours has a documented path that would have made it silent.

**Blast radius note.** Our `.claude/settings.json` currently has a `PreToolUse /
Write|Edit` group with **7 co-tenants** (`check-human-ac-tick`, `check-active-completed-dup`,
`check-arc-id`, `check-heredoc-cmd-sub`, `check-inception-decisions`,
`check-inception-schema`, `check-onboarding-gate`). `hook-enable` merges into the **first**
block whose matcher matches, so any future `Write|Edit` hook joins that group. A
group-scoped removal there takes out six unrelated gates — including arc-017's
onboarding gate.

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

- **IW-1: Should the baseline record a set of named commands instead of one blob hash?**
  confidence: 3
  disposition: answered
  rationale: Yes, keyed on hook NAME alone, beside the hash (hash stays the fast "something moved" path). S1 measured the key: name-keyed = 0 removals across 28 revisions; (event,matcher,name)-keyed = 3 false alarms; raw-command-keyed = 4. See docs/reports/T-2909-enforcement-baseline-laundering.md §S1.

  A per-command manifest (event, matcher, command) makes D2's two bottom rows
  distinguishable — `doctor` could print `FAIL — check-tier0 no longer registered` and
  `INFO — 1 hook added`. This is the leg that kills D3 for free: a remedy that must
  name what it is accepting cannot silently accept a deletion. Open sub-question: does
  the manifest live *beside* the hash (hash stays the fast path) or replace it?

- **IW-2: Is "hook removed" a FAIL that `fw enforcement baseline` may accept at all?**
  confidence: 3
  disposition: answered
  rationale: No. S1 — zero legitimate removals of a framework-owned hook in 28 revisions over 5 months; all 3 apparent removals are renames (T-496) or matcher moves (T-1364, T-1730). There is no case to accommodate, so removal warrants an explicit --accept-removal <name> logged Tier-2, not a silent recompute.

  Additions are routine (this session added none, but T-1849/T-1730/T-2815 each added
  one). Removals of a *framework-owned enforcement* hook are, as far as I can measure,
  never routine. If so the right shape is not "diff and confirm" but "additions
  re-baseline freely; removals require an explicit `--accept-removal <name>` that logs
  Tier-2". Needs evidence: has any legitimate removal ever happened here?

- **IW-3: Does `fw hook-disable` need to exist, or does D1 dissolve once D2/D3 are fixed?**
  confidence: 3
  disposition: dissolved
  rationale: Dissolved for framework-owned hooks — S1 shows the verb would have zero work to do, ever. Remains useful for project-local --script hooks (832's probe case) but is NOT the load-bearing fix: a hook-disable verb shipped without D2/D3 would still let a by-hand mistake be laundered green. Demoted to a follow-on nicety.

  832's remedy direction is a `hook-disable --script/--matcher/--event` that removes the
  *command* and drops the group only when it empties. That is clearly right if removal
  is a supported operation. But if IW-2 lands on "framework-owned enforcement hooks are
  never removed", the verb is only needed for project-local `--script` hooks (the probe
  case that started this), which is a much smaller thing. Answer IW-2 first.

- **IW-4: Is the wiring verifiable, or does this share 832's §4 blind spot?**
  confidence: 1
  disposition: deferred
  rationale: Deferred to the build slice, where it is answerable and load-bearing — but note it does NOT apply the same way here: the D2/D3 remedy lives in `fw doctor` / `fw enforcement baseline`, which are ordinary CLI paths, not PreToolUse hooks. 832's blind spot was hook-config-snapshotted-at-session-start; a doctor check has no such surface and can be exercised directly in bats. Recorded so the build task does not inherit a fear that does not apply to it.

  832 could not prove their new gate was *registered and live* — only that its logic was
  right (15/15 mutation) — because hook config appears to be snapshotted at session
  start. They separated "my matcher is wrong" from "config is snapshotted" with a probe
  hook on an already-proven matcher, and only the second survived. Whatever this task
  ships has the same problem: a settings-integrity check that is itself unregistered is
  the exact failure it exists to catch. Do not claim this AC without the same discipline.

## Exploration Plan

| # | Spike | Time-box | Answers |
|---|-------|----------|---------|
| S1 | Enumerate every historical change to `.claude/settings.json` hooks in git history; classify each as add / remove / reorder | 45 min | IW-2 (is removal ever legitimate?) |
| S2 | Prototype the manifest predicate against the live file + the two temp-copy scenarios already measured; confirm it names `check-tier0` in scenario B and stays quiet in scenario A | 45 min | IW-1 |
| S3 | Read `lib/init.sh:generate_claude_code_config` and confirm the manifest survives `fw upgrade` / `fw init` regeneration (L-399 producer/consumer parity — two sites already flagged as must-change-together at `bin/hook-enable.sh:120`) | 30 min | IW-1 blast radius |

S1 is first and is the one that can dissolve IW-3 without any code.

## Technical Constraints

- `.claude/settings.json` is regenerated by `lib/init.sh:generate_claude_code_config` and
  merged by `lib/upgrade.sh`; `bin/hook-enable.sh:120` already declares those two sites
  must change together. A third consumer (a manifest) inherits that constraint.
- The emitted command string is `${CLAUDE_PROJECT_DIR}/bin/fw hook <name>` in the framework
  repo and `${CLAUDE_PROJECT_DIR}/.agentic-framework/bin/fw hook <name>` in consumers
  (T-1504 / T-2709). A manifest keyed on the raw command string would therefore **differ
  between framework and consumer** and produce false FAILs on every consumer. Key on the
  hook *name*, not the command string.
- Consumers vendor their own settings.json. Any new baseline format must degrade
  gracefully on a project whose baseline predates it (missing manifest ≠ FAIL).

## Scope Fence

**IN:** the integrity/detection surface for `.claude/settings.json` hooks — what the
baseline records, what `fw doctor` reports, what `fw enforcement baseline` accepts, and
whether a governed removal verb is needed.

**OUT:**
- The *content* of any individual hook. This is about the registry, not the gates.
- 832's tree. Their OBS-014 / PL-144 is theirs; this task does not propose changes there.
- The hook-config-snapshotted-at-session-start behaviour itself (IW-4 only asks whether
  it blocks verification here; changing Claude Code's snapshot semantics is not ours).
- `fw enforcement status` output formatting, except where it must name the same set.

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

Measured on a temp copy of the live settings.json: a benign hook ADD and a check-tier0 DELETE both produce byte-identical doctor output (FAIL Enforcement baseline CHANGED) because the baseline is a single sha256 over the whole hooks blob. The printed remedy, fw enforcement baseline, recomputes unconditionally and never diffs against the prior baseline — so following the framework's own instruction after an accidental deletion makes the loss permanent and the next doctor run green. A PostToolUse hook (check-settings-edit) actively nudges toward that remedy after every settings.json edit. Origin: 832 rail 517 s5 reported the missing-inverse half (fw hook-enable has no fw hook-disable) after their probe cleanup took check-tier0 down for two tool calls; the detection and laundering halves are ours and were not in their report.

**Evidence:**

- **D2 measured, not reasoned** (temp copy, live file never touched): baseline
  `962690887ee10cb6` / benign-add `4a80de2ac8715e0e` / tier0-deleted `08341179c2aa8e4b`.
  Bottom two both print `FAIL Enforcement baseline CHANGED`. `bin/fw:2248-2266`.
- **D3 read in source**: `bin/fw:7748-7770` recomputes unconditionally, prints
  `Enforcement baseline saved`, never diffs. The "after review" in the FAIL message has
  no code behind it.
- **D1 confirmed absent**: `grep -rn "hook-disable\|hook_disable\|hook remove" bin/ lib/ agents/`
  returns nothing. `bin/hook-enable.sh` is 188 lines with no inverse.
- **S1 — the fix direction is measured**: all 28 revisions of `.claude/settings.json`
  diffed pairwise. Name-keyed: **0 removals in 5 months**. `(event,matcher,name)`-keyed:
  3 false alarms. Raw-command-keyed: 4. Every apparent removal is a rename (T-496) or a
  matcher move (T-1364, T-1730). Full table in the artifact.
- **Blast radius**: `PreToolUse / Write|Edit` currently holds **7 co-tenants** including
  `check-onboarding-gate` (arc-017's shipped mechanic). `hook-enable` merges into the
  first matching block, so the next `Write|Edit` hook joins that group.
- **Artifact**: `docs/reports/T-2909-enforcement-baseline-laundering.md`
- **Registered**: G-080 in `.context/project/concerns.yaml`, with the closure test
  written as a falsifiable procedure (delete tier0 → run the printed remedy → if doctor
  says OK, the gap is open).

**Scope of the GO.** Build the name-keyed manifest + the removal refusal (D2/D3). Do
**not** build `fw hook-disable` as part of it — S1 dissolved that; it is a separable
nicety for project-local `--script` hooks and is not what makes the accident silent.

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

**Rationale**: Recommendation: GO

Rationale:

Measured on a temp copy of the live settings.json: a benign hook ADD and a check-tier0 DELETE both produce byte-identical doctor output (FAIL Enforcement baseline CHANGED) because the baseline is a single sha256 over the whole hooks blob. The printed remedy, fw enforcement baseline, recomputes unconditionally and never diffs against the prior baseline — so following the framework's own instruction after an accidental deletion makes the loss permanent and the next doctor run green. A PostToolUse hook (check-settings-edit) actively nudges toward that remedy after every settings.json edit. Origin: 832 rail 517 s5 reported the missing-inverse half (fw hook-enable has no fw hook-disable) after their probe cleanup took check-tier0 down for two tool calls; the detection and laundering halves are ours and were not in their report.

Evidence:

- D2 measured, not reasoned (temp copy, live file never touched): baseline
  `962690887ee10cb6` / benign-add `4a80de2ac8715e0e` / tier0-deleted `08341179c2aa8e4b`.
  Bottom two both print `FAIL Enforcement baseline CHANGED`. `bin/fw:2248-2266`.
- D3 read in source: `bin/fw:7748-7770` recomputes unconditionally, prints
  `Enforcement baseline saved`, never diffs. The "after review" in the FAIL message has
  no code behind it.
- D1 confirmed absent: `grep -rn "hook-disable\|hook_disable\|hook remove" bin/ lib/ agents/`
  returns nothing. `bin/hook-enable.sh` is 188 lines with no inverse.
- S1 — the fix direction is measured: all 28 revisions of `.claude/settings.json`
  diffed pairwise. Name-keyed: 0 removals in 5 months. `(event,matcher,name)`-keyed:
  3 false alarms. Raw-command-keyed: 4. Every apparent removal is a rename (T-496) or a
  matcher move (T-1364, T-1730). Full table in the artifact.
- Blast radius: `PreToolUse / Write|Edit` currently holds 7 co-tenants including
  `check-onboarding-gate` (arc-017's shipped mechanic). `hook-enable` merges into the
  first matching block, so the next `Write|Edit` hook joins that group.
- Artifact: `docs/reports/T-2909-enforcement-baseline-laundering.md`
- Registered: G-080 in `.context/project/concerns.yaml`, with the closure test
  written as a falsifiable procedure (delete tier0 → run the printed remedy → if doctor
  says OK, the gap is open).

Scope of the GO. Build the name-keyed manifest + the removal refusal (D2/D3). Do
not build `fw hook-disable` as part of it — S1 dissolved that; it is a separable
nicety for project-local `--script` hooks and is not what makes the accident silent.

**Date**: 2026-08-10T20:09:59Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-08-10T19:35:58Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-08-10T20:09:59Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO

Rationale:

Measured on a temp copy of the live settings.json: a benign hook ADD and a check-tier0 DELETE both produce byte-identical doctor output (FAIL Enforcement baseline CHANGED) because the baseline is a single sha256 over the whole hooks blob. The printed remedy, fw enforcement baseline, recomputes unconditionally and never diffs against the prior baseline — so following the framework's own instruction after an accidental deletion makes the loss permanent and the next doctor run green. A PostToolUse hook (check-settings-edit) actively nudges toward that remedy after every settings.json edit. Origin: 832 rail 517 s5 reported the missing-inverse half (fw hook-enable has no fw hook-disable) after their probe cleanup took check-tier0 down for two tool calls; the detection and laundering halves are ours and were not in their report.

Evidence:

- D2 measured, not reasoned (temp copy, live file never touched): baseline
  `962690887ee10cb6` / benign-add `4a80de2ac8715e0e` / tier0-deleted `08341179c2aa8e4b`.
  Bottom two both print `FAIL Enforcement baseline CHANGED`. `bin/fw:2248-2266`.
- D3 read in source: `bin/fw:7748-7770` recomputes unconditionally, prints
  `Enforcement baseline saved`, never diffs. The "after review" in the FAIL message has
  no code behind it.
- D1 confirmed absent: `grep -rn "hook-disable\|hook_disable\|hook remove" bin/ lib/ agents/`
  returns nothing. `bin/hook-enable.sh` is 188 lines with no inverse.
- S1 — the fix direction is measured: all 28 revisions of `.claude/settings.json`
  diffed pairwise. Name-keyed: 0 removals in 5 months. `(event,matcher,name)`-keyed:
  3 false alarms. Raw-command-keyed: 4. Every apparent removal is a rename (T-496) or a
  matcher move (T-1364, T-1730). Full table in the artifact.
- Blast radius: `PreToolUse / Write|Edit` currently holds 7 co-tenants including
  `check-onboarding-gate` (arc-017's shipped mechanic). `hook-enable` merges into the
  first matching block, so the next `Write|Edit` hook joins that group.
- Artifact: `docs/reports/T-2909-enforcement-baseline-laundering.md`
- Registered: G-080 in `.context/project/concerns.yaml`, with the closure test
  written as a falsifiable procedure (delete tier0 → run the printed remedy → if doctor
  says OK, the gap is open).

Scope of the GO. Build the name-keyed manifest + the removal refusal (D2/D3). Do
not build `fw hook-disable` as part of it — S1 dissolved that; it is a separable
nicety for project-local `--script` hooks and is not what makes the accident silent.

## Reviewer Verdict (v1.5)

- **Scan ID:** R-fb46d343
- **Timestamp:** 2026-08-10T20:10:01Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

## Recommendation Verdict (v1.0)

- **Scan ID:** RC-3cf5e9c9
- **Timestamp:** 2026-08-10T20:10:01Z
- **Overall:** CONFIRMED
- **Claims:** 7

| Claim | Type | Status |
|-------|------|--------|
| `bin/hook-enable.sh` | file | ✓ pass |
| `.claude/settings.json` | file | ✓ pass |
| `docs/reports/T-2909-enforcement-baseline-laundering.md` | file | ✓ pass |
| `.context/project/concerns.yaml` | file | ✓ pass |
| `T-496` | task | ✓ pass |
| `T-1364` | task | ✓ pass |
| `T-1730` | task | ✓ pass |

### 2026-08-10T20:10:00Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
