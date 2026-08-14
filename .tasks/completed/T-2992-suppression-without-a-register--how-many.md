---
id: T-2992
name: "suppression without a register — how many known-open root causes are parked
  in comments?"
description: >
  Inception: suppression without a register — how many known-open root causes are
  parked in comments?

status: started-work
workflow_type: inception
owner: human
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-08-14T17:28:13Z
last_update: '2026-08-14T17:30:08Z'
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
  - ts: '2026-08-14T17:29:51Z'
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
  - ts: '2026-08-14T17:30:08Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 6
    rationale: blast_radius=3 (no-signal); tier=4 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2992: suppression without a register — how many known-open root causes are parked in comments?

## Problem Statement

T-2990 removed 56MB of junk from the repo root and T-2991 closed the mechanism
that wrote it. Neither explains why it lasted **three months and four incidents**.

That part has its own cause, and it is not about ImageMagick. The first two
instances were silenced with `.gitignore` rules annotated:

> `# Gate blocks the COMMIT; CREATION is still un-prevented (root-cause task pending).`

That sentence is a correct diagnosis, an accurate statement of what remained
open, and a promise of future work. No task was ever filed. And the suppression
it annotates removed `git status` — the one surface that would have prompted
anyone to read it. Instances 3 and 4 were *not* covered by those rules, sat
visible as `??` for days, and were still not investigated, because by then the
class read as known and handled.

The generalisable shape: **a suppression carrying a deferral note, with no entry
in a register that anything checks.** The framework already has the right home —
`concerns.yaml` is scanned by audit and rendered in Watchtower. A comment beside
an ignore rule is read by nobody, and is worse than no comment, because it makes
the suppression look considered.

Explored now because the cost of being wrong is measured: three months of
blindness per instance, and we do not know whether this instance is one of one
or one of forty.

## Assumptions

- **A1:** Suppression sites with deferral notes exist elsewhere in this repo
  beyond the two `.gitignore` lines (testable by scan).
- **A2:** Where they exist, most do not name a task/gap id (testable by scan).
- **A3:** `concerns.yaml` is the correct destination rather than a new register
  — it is already audited and already rendered (testable by reading the audit).

## Open Questions

- **IW-1: How many suppression sites in this repo carry a deferral note with no task/gap id?**
  confidence: 3
  disposition: answered
  rationale: 12 sites carry deferral prose; ~2 are genuine unnamed deferrals. Full
  census table in docs/reports/T-2992-suppression-without-a-register.md §Spike 1.
  The class is real and rare — not the 40 the filing rationale allowed for.

- **IW-2: Is a mechanical rail possible, or does recognising "deferral note" require judgement?**
  confidence: 3
  disposition: answered
  rationale: Prose alone is NOT a discriminator — control probe found 184 comments
  in lib/+agents/ carrying identical vocabulary, nearly all ordinary explanation.
  A prose-keyed rail would be ~94% noise. Mechanical is only possible with the
  suppression SITE as the anchor and prose as the qualifier.

- **IW-3: Should the remedy gate at write time (refuse a suppression without a register ref) or audit at rest (WARN on drift)?**
  confidence: 3
  disposition: answered
  rationale: Audit-at-rest, scoped to .gitignore only. The census exposed the
  asymmetry that decides it: skips print their reason every run and allowlist
  entries are echoed by their scanner, but a .gitignore rule emits NOTHING when it
  fires — it is the only common suppression that deletes its own signal. A
  write-time gate over that surface would fire on every legitimate ignore rule; an
  audit WARN scoped to rules whose comment promises work but names no id fires on
  ~1 today and would have caught this incident.

<!-- original template guidance below -->

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

**IN:** why the T-2990 junk survived three months — the suppression-without-a-
register class. A census of suppression sites in this repo. A recommendation on
whether a rail is warranted and at which surface.

**OUT:**
- The mechanism that wrote the junk (T-2991, shipped).
- Detection of root pollution (T-2990, shipped).
- Consumer projects' suppression sites — this census is framework-repo only.
- The two genuine test-skip deferrals the census turned up
  (`t2924_update_task_owner_gate.bats:127`, `t2932_note_count_urgent_filter.bats:215`).
  They are recorded as findings, not fixed here; each is its own small task if
  the operator wants them chased.
- `|| true` and `2>/dev/null`, the pervasive shell suppression idioms. They carry
  no deferral note and are not the class — sweeping them in would make this
  unbounded, which is the NO-GO criterion below.

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

T-2990 found 56MB of junk that survived three months. The mechanism is now fixed (T-2991), but the mechanism is not why it survived. It survived because the first two instances were silenced with a .gitignore rule annotated 'root-cause task pending' — a task that was never filed. That note is a known-open root cause parked in a comment, and the suppression it annotates deleted the one signal (git status) that would have prompted anyone to read it. Instances 3 and 4 then sat visible in git status for days and were still not investigated, because by then the class had been normalised. The framework already has the right home for this: concerns.yaml is checked by audit and rendered in Watchtower, where a comment beside an ignore rule is read by nobody. Recommending GO because the specific instance is proven and the generalisation is cheap to test — a scan for suppression sites (gitignore rules, skip markers, xfail, allowlists, disabled hooks) that carry a deferral note but no register entry is a bounded piece of work, and the answer is useful whether the count is 1 or 40. NO-GO would assert the class is one-off, which the four-instance history contradicts; DEFER would be a hedge, since the evidence for the class is already in hand.

**Rationale (revised after the spike — the recommendation held, its scope did not):**

The filing rationale above predicted the census would justify a broad rail, and
said the answer would be useful "whether the count is 1 or 40". It came back ~2,
with a 184-hit false-positive surface. That cuts against the rail I had in mind
when filing, and the honest thing is to say so rather than quietly restate it.

Still **GO**, for a **narrower** thing:

> An audit WARN over `.gitignore` only, firing on a rule whose comment promises
> future work but names no task / gap / observation id.

The census is what narrowed it, by exposing an asymmetry the original framing
missed. Not all suppressions are equal:

- a `skip "…"` **prints its reason every run** — it announces itself;
- an allowlist entry is **echoed by the scanner** that consults it;
- a `.gitignore` rule emits **nothing, ever**.

`.gitignore` is the only common suppression that deletes its own signal. That is
precisely what happened here: `/os` and `/sys` did not merely fail to remind
anyone, they removed `git status` — the surface that would have. The two later
instances, uncovered by any rule, did keep appearing as `??` for days.

So the target is not "suppression sites"; it is the subclass that is
structurally silent. Population ~1 today, cost ~20 lines in audit, and it would
have caught this exact incident three months and 56MB ago.

Why not the alternatives: a **write-time gate** would fire on every legitimate
ignore rule (most have no deferral and need none). A **prose-keyed scan** across
the repo is the 184-hit version — noise that trains people to ignore it, which is
how the original note got ignored. **NO-GO** would assert the class is one-off;
the four-incident history and the explicit written "root-cause task pending"
contradict that. **DEFER** would be a hedge — the census is done, the asymmetry
is established, and the scope is decided.

**Evidence:**

- Origin instance: `.gitignore` `/os` + `/sys`, annotated *"Gate blocks the
  COMMIT; CREATION is still un-prevented (root-cause task pending)"*. No task was
  ever filed. Four incidents, 2026-05-04 → 2026-08-12, 56MB.
- Census: 12 suppression sites carry deferral prose; ~2 are genuine unnamed
  deferrals. Table in `docs/reports/T-2992-suppression-without-a-register.md`.
- Control probe: 184 deferral-prose comments in `lib/` + `agents/` — prose alone
  cannot be the discriminator.
- Register health: `concerns.yaml` holds 87 gap entries and is read by
  `fw audit` (`agents/audit/audit.sh:1175`) and Watchtower. The register works;
  routing into it is what failed.
- Two genuine test-skip deferrals found and deliberately left out of scope:
  `tests/unit/t2924_update_task_owner_gate.bats:127`,
  `tests/unit/t2932_note_count_urgent_filter.bats:215`.
- Both parents shipped and verified this session: T-2990 (`2d6d7c668`),
  T-2991 (`e35e47d6f`).

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

### 2026-08-14T17:29:51Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
