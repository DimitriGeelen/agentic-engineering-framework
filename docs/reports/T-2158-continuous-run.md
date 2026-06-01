# T-2158 — continuous-run arc inception: agent-driven compact→resume loop

**Status:** DEFER pending evidence walk
**Filed:** 2026-06-01
**Workflow type:** inception
**Recommendation source:** human-proposed arc draft + agent walk

---

## Problem Statement

Today, continuous operation is **operator-gated**: a human runs `/compact` and `fw handover` when the context budget fills, then resumes. This caps how far the agent can run unattended and re-injects a human relay at every budget boundary.

The capability gap is the **agent autonomously crossing those boundaries** — self-compacting and self-resuming — *while remaining bounded* by tier/blast-radius ceiling, run-length cap, and a discard-manifest audit trail.

The proposed arc (`continuous-run`) closes the loop. The hard design question is **how to bound it safely without becoming "just run longer."**

---

## Proposed Arc YAML (verbatim — human-filed)

```yaml
# .context/arcs/continuous-run.yaml
#
# Arc inception -- DRAFT. Created via:
#   fw arc create continuous-run --headline-mechanic "..."
# Then driver suggestions are proposed, approved (fw arc approve-driver),
# which flips draft -> in-progress. Field names below should be confirmed
# against lib/arc.sh arc_create output before committing.

arc_id: continuous-run
status: draft
created: 2026-05-29

headline_mechanic: >
  The AGENT triggers the compact -> resume loop at the context-budget threshold,
  instead of the operator driving /compact and fw handover by hand. Sessions
  already derive state from .context/ on resume (criterion 55); this closes the
  loop so a long-running agent self-compacts and self-resumes across context-
  budget boundaries -- WITHIN a bounded tier/blast-radius ceiling.

problem: >
  Today, continuous operation is operator-gated: a human runs /compact and
  fw handover when the context budget fills, then resumes. This caps how far the
  agent can run unattended and re-injects a human relay at every budget boundary.
  The capability gap is the agent autonomously crossing those boundaries.

# --- The load-bearing design constraint. This is an autonomy capability, and
#     continuous self-resume is the strongest test of the Sovereignty tension:
#     self-compaction is LOSSY, and if the agent decides what to drop and runs on,
#     no operator reviewed what was discarded. The mechanic must be BOUNDED, not
#     truly unbounded.
constraints:
  - Bounded by tier/blast-radius: continuous operation permitted only below a
    configured ceiling. HARD STOP at Tier 0 / irreversible / high-blast-radius
    actions -- these still require a human gate (F7 Sovereignty).
  - A run-length / iteration cap as a second backstop, so a misbehaving loop
    cannot run indefinitely even within the tier ceiling.
  - Self-compaction must record WHAT was dropped (a discard manifest), so an
    operator can review post-hoc even though they did not review in-line. This
    preserves a portable (D4) audit trail of lossy decisions.
  - Respect the 90% context-budget gate (criterion 28) as the natural trigger
    point AND the safety boundary -- the loop fires at threshold, it does not
    disable the gate.

non_goals:
  - Removing or weakening any Tier 0 / consequential-action human gate.
  - Truly unbounded autonomous operation (no ceiling, no cap).
  - Introducing a new scoring/value-driver mechanic (that lives in value-drivers.yaml).

relation_to_existing_primitives:
  resume: agents/resume/ already derives state from .context/ on resume (crit 55).
  handover: fw handover is the manual version of the compaction half to automate.
  budget_gate: budget-gate hook (crit 28) is the trigger + safety boundary.
  orchestrator: squarely orchestrator-substrate work; sits under T-1643 territory.
  auto_promote: shares the same Sovereignty caveat; both are bounded-autonomy.

# Seeded by the primary agent at inception (D5/D6). Persistent reference material
# (D7) -- kept even after approval so focus can shift later. Each must distinguish
# something the GLOBAL drivers don't, since inside this arc everything scores
# "orchestration/autonomy-ish" and global scoring goes flat.
proposed_scoped_drivers:
  - name: Loop closure
    rationale: >
      Does this task close an open compact->resume->run loop, vs leaving one half
      open (e.g. self-compact with no self-resume)? Distinguishes a complete
      unattended cycle from a partial one -- globals can't see this.
  - name: Bounded-safety integrity
    rationale: >
      Does this task strengthen the tier/blast-radius ceiling and discard manifest,
      vs merely extend run-length? Rewards earning autonomy safely over removing
      friction -- the opposite incentive to "just run longer".
  - name: Discard fidelity
    rationale: >
      How recoverable is what self-compaction drops? Rewards lossless-where-possible
      and reviewable-where-lossy compaction over aggressive context shedding.

scoped_drivers: []          # populated on approval (max 3)
bvp_scores: {}              # populated after scoring
```

---

## Prior-art finding (surfaced by briefing engine)

**T-111 — "Autonomous compact-resume lifecycle"** (completed 2026-02-17) already shipped half of the proposed loop:

- **PreCompact hook** → `fw handover --emergency` (106ms measured; saves structured handover before compaction's lossy summary)
- **SessionStart:compact hook** → injects `LATEST.md` as `additionalContext` (the agent self-orients without manual `/resume`)
- **Evidence:** `.claude/settings.json` carries both hooks; this very session was post-compacted at S-2026-0601-1130 and the SessionStart context block IS that injection in action.

**What T-111 closed:** the *data-preservation* half — handover is saved before compaction, structured context is re-injected after.

**What T-111 left open (continuous-run's actual scope):**
1. **Self-triggering compaction** — today `/compact` is operator-driven. T-111 hooks *react* to compaction events; they don't *cause* them. Continuous-run needs the agent to decide "I'm at threshold, compact now" without waiting for an operator.
2. **Bounded-autonomy ceiling** — T-111 has no tier/blast-radius check on whether the agent should *continue* post-resume. The agent simply resumes. Continuous-run requires a structural check that says "post-resume, if the queued work crosses Tier 0 or high-blast-radius, halt and wait for a human."
3. **Run-length cap** — T-111 has no iteration limit. A self-resuming loop could in principle run forever. Continuous-run requires a backstop counter.
4. **Discard manifest** — T-111's `--emergency` handover saves what it can preserve; it does not enumerate what was *dropped*. Continuous-run requires the lossy decisions to be enumerated for post-hoc operator review (the F4 Antifragility leg).

**The reframe:** continuous-run is **not** "build the compact-resume loop"; it is **"extend T-111's data-preservation loop with self-triggering + bounded-autonomy machinery + discard audit."**

This dramatically changes the slice shape and risk profile — it's incremental on a proven primitive, not greenfield.

---

## Cross-references to related in-flight inceptions

- **T-2157 — value-drivers.yaml v3 redesign** (filed earlier this session, DEFER). T-2157's proposal carves `F-AUTONOMY` as a *commented-out candidate* driver (deferred until "broad gate-reduction becomes focus"). Continuous-run **is** that focus shift. If continuous-run goes GO, F-AUTONOMY may need to flip from candidate to active in tandem.
- **T-1643 orchestrator-substrate** — the proposed arc explicitly sits under T-1643 territory. Need to confirm the boundary: does continuous-run depend on orchestrator v2 (which is currently a stub per `fw orchestrator improve`), or can it ship on the existing v1 dispatch substrate?
- **`auto_promote`** subsystem — per the user's draft, shares the same Sovereignty caveat (both are bounded-autonomy). Currently `auto_promote: {enabled: false}` in `policy/value-drivers.yaml`. Activation pattern is precedent.
- **Existing arc `orchestrator-rethink`** — already exists at `.context/arcs/orchestrator-rethink.yaml`. Need to determine whether continuous-run is a child arc or a sibling.

---

## Assumptions to validate

- **A1:** T-111's PreCompact + SessionStart:compact hooks remain functional and are the right substrate to extend (vs. a clean rebuild). *Validate:* trace this session's compact event end-to-end in `.context/working/.pre-compact.last-run` + hook output.
- **A2:** The "context-budget threshold trigger" already has a clean signal at criterion 28 (`budget-gate.sh` at 90%). Self-triggering compaction can hang off the same gate. *Validate:* read `agents/context/budget-gate.sh` and confirm it has an extension hook point.
- **A3:** Tier 0 / blast-radius enforcement primitives exist and can be queried before resumption decides to continue. `fw fabric blast-radius` exists; `check-tier0.sh` exists. *Validate:* both can be invoked from a hook context within the post-compact window.
- **A4:** A "discard manifest" can be produced cheaply during emergency handover (T-111 took 106ms — slack exists). The manifest format does not yet exist but the surface area is small.
- **A5:** Run-length cap can be a simple counter in `.context/working/` (similar pattern to `.tool-counter`). No need for a separate persistence layer.
- **A6:** F7 Sovereignty (operator-must-not-be-bypassed) is preservable: the human still gates Tier 0 *post*-resume, just doesn't gate compaction *itself*. The Sovereignty surface narrows, but doesn't disappear.

---

## Critical questions (open)

1. **Trigger placement** — does self-triggering compaction live in `budget-gate.sh` (block + auto-act), in `checkpoint.sh` (PostToolUse fallback), or in a new dedicated hook? Each has different failure modes.
2. **What "compact" means in this context** — is the agent calling `/compact` programmatically (via what mechanism?), or constructing an equivalent self-summary and re-launching via `claude -c`? T-179 auto-restart wrapper exists for the second shape.
3. **The Sovereignty pushback** — the strongest argument against continuous-run is that *the human compact-checkpoint is a natural review beat*. Removing it removes a moment of "wait, do I still want this to continue?" oversight. Counter-argument: the discard manifest + Tier 0 gate preserves the meaningful safety. Which framing wins?
4. **Discard-manifest format** — at-emergency-handover-time, what does the agent know about what is being dropped? The compaction is performed by the model itself; the agent does not have a pre-image to diff against the post-image. The manifest can only enumerate *categories* (e.g. "47 tool-results compressed", "12 turns summarised"), not the literal dropped tokens. Is that fidelity enough?
5. **Backstop interaction** — if run-length cap fires *inside* a long-running task (mid-edit), does the agent halt mid-write? Or does the cap only fire at compact-resume boundaries? The latter is safer.
6. **Test methodology** — T-111's GO criterion was satisfied by one manual `/compact` cycle. Continuous-run needs a multi-cycle test where the agent makes the compact decision itself. How is that simulated?
7. **`fw arc create` field-name validation** — the user's draft has a comment: "Field names below should be confirmed against `lib/arc.sh arc_create` output before committing." Walk `lib/arc.sh` and confirm `arc_id`, `status`, `headline_mechanic`, `constraints`, `non_goals`, `relation_to_existing_primitives`, `proposed_scoped_drivers` are all accepted shapes.
8. **Relation to `orchestrator-rethink` arc** — child arc, sibling arc, or merge? Read `.context/arcs/orchestrator-rethink.yaml` to decide.
9. **Scoped-driver critique** — three drivers proposed:
   - **Loop closure** — does this distinguish meaningfully from D1 Antifragility ("system strengthens under stress")? Closing a half-open loop *is* antifragility.
   - **Bounded-safety integrity** — does this distinguish from D2 Reliability + D3 Usability combined? Strong candidate for genuine new meaning ("rewards safety over friction-removal" is asymmetric, globals don't capture asymmetry).
   - **Discard fidelity** — does this distinguish from D4 Portability? D4 is "no provider/language lock-in", discard fidelity is "no operator-review lock-in." Adjacent but distinct.
10. **F-AUTONOMY tandem activation** — if T-2157 ships v3 with F-AUTONOMY commented out, and continuous-run goes GO, does F-AUTONOMY's activation happen *with* this arc, or as a follow-up? Sequencing matters for the value-drivers stability story.

---

## Exploration Plan (spikes)

| Spike | Time-box | Output |
|-------|----------|--------|
| S1: T-111 substrate trace | 25 min | End-to-end map of this session's compact: PreCompact firing point, what `fw handover --emergency` saved, SessionStart:compact injection contents. Update artifact §"Prior-art finding" with concrete file:line refs. |
| S2: Self-trigger surface walk | 20 min | Read `agents/context/budget-gate.sh`, `agents/context/checkpoint.sh`, `claude-fw` wrapper, T-179 auto-restart. Map every place a "compact now" decision could be wired. Update §"Critical questions" Q1+Q2 with answers. |
| S3: Bounded-autonomy primitives audit | 20 min | Read `agents/git/check-tier0.sh`, `fw fabric blast-radius`, `policy/value-drivers.yaml` (`auto_promote:` block as precedent). Confirm A3. Document the Sovereignty surface narrowing precisely. |
| S4: Scoped-driver critique | 15 min | Apply CLAUDE.md "new meaning, not louder D1-D4" criterion to each of Loop closure / Bounded-safety integrity / Discard fidelity. Refine or refute. Update §Q9. |
| S5: Arc-field validation + orchestrator-rethink delta | 15 min | Run `lib/arc.sh` field validation walk (Q7). Read `.context/arcs/orchestrator-rethink.yaml` and decide child/sibling/merge (Q8). |
| S6: Answer open questions 1-10 | 30 min | Each Q resolved with evidence cited or flagged as still-open. Flip Recommendation. |

Total: ~125 min read-only research. No source edits, no `fw arc create`, no hook changes until GO recorded.

---

## Scope Fence

**IN scope (this inception):**
- All six spikes above
- Reading the existing arc YAML format and confirming user's draft is parseable
- Cross-reference with T-2157 (F-AUTONOMY tandem question)
- Cross-reference with T-1643 / `orchestrator-rethink` arc
- Recommendation flip from DEFER → GO / NO-GO / GO-with-refinements

**OUT of scope (separate tasks if GO):**
- Running `fw arc create continuous-run --headline-mechanic ...` (only after GO)
- Implementing self-triggering compaction (separate build slice)
- Discard manifest format design (separate slice; may need its own inception if surface is bigger than spike S4 reveals)
- Run-length cap counter wiring (separate slice, small)
- Test harness for multi-cycle autonomous compact (separate slice; may need its own inception per Q6)
- F-AUTONOMY activation in `policy/value-drivers.yaml` (sits under T-2157's territory)

---

## Go/No-Go Criteria

**GO if:**
- T-111 substrate is intact and extensible (no rebuild required)
- A clean trigger surface exists in `budget-gate.sh` or equivalent (Q1 has a single-best answer)
- Tier 0 + blast-radius gates are invocable from the post-resume path (A3 holds)
- All three scoped drivers survive the "new meaning" critique (Q9), OR a refined set of ≤3 emerges
- Discard manifest can be produced at category-level fidelity (Q4) — even if not token-level
- Relation to `orchestrator-rethink` arc is unambiguous (child/sibling/merge decided)

**NO-GO if:**
- T-111 hooks are broken or have drifted from their 2026-02 baseline
- Sovereignty pushback (Q3) reveals that the operator compact-checkpoint is load-bearing oversight that can't be replaced by post-hoc manifest review
- Discard-manifest fidelity is so low (Q4) that the audit trail is theatre, not substance
- Scoped drivers all collapse into D1-D4 restatements — the arc adds no scoring signal globals can't already see

**GO-with-refinements if:**
- Proposal is structurally sound but specific machinery needs revision (e.g. trigger surface moved, run-length cap shape adjusted)
- Driver set reduces from 3 to 1-2 (the strongest one survives, weakest is refuted)
- Arc should ship as a *child* of `orchestrator-rethink` rather than as a sibling

---

## Recommendation

**Recommendation:** DEFER

**Rationale:**

Per T-2144 (DEFER is for evidence gaps, not confidence gaps): the human filed a structured arc draft with explicit constraints, non-goals, and proposed scoped drivers. That is already substantial evidence. But the inception's *job* per the user's wording — "**explore and investigate**" — is to walk the substrate (T-111, budget-gate, tier/blast-radius primitives, `orchestrator-rethink` arc) and critique the proposed drivers before committing.

The agent has *not yet* done that walk. Six spikes (~125 min) stand between filing and a defensible GO/NO-GO. DEFER honestly reflects that gap.

The walk is read-only and bounded; once complete, the Recommendation flips to GO / NO-GO / GO-with-refinements with concrete evidence.

**Evidence (filing-time):**

- T-111 prior-art confirmed via briefing-engine surface + `.tasks/completed/T-111-*.md` read — PreCompact + SessionStart:compact hooks shipped 2026-02-17; this session's compact at S-2026-0601-1130 fired them successfully (proof-of-life)
- Existing arc `orchestrator-rethink` is present at `.context/arcs/orchestrator-rethink.yaml` — confirms the orchestrator-substrate framing the user invokes
- T-2157 (value-drivers v3) is in-flight DEFER with F-AUTONOMY commented-out candidate — confirms the F-AUTONOMY tandem-activation question is live
- Three scoped-driver candidates filed in artifact, each with rationale that *appears* to distinguish from D1-D4 — critique deferred to S4

---

## Dialogue Log

### 2026-06-01 — Human files arc draft as inception

Human filed the full `continuous-run.yaml` draft (verbatim above) with explicit instruction: "*add this as an inception to explore and investigate :: please save the artefact*"

Reading: not a build instruction; an exploration request. Per CLAUDE.md §Inception Discipline (C-001) the research artifact is created BEFORE any source edits. This file IS that artifact.

The draft itself does substantial inception work already — the constraints/non_goals/relation_to_existing_primitives blocks read as well-formed exploration output. The agent's task is to **walk the evidence the draft asserts**, not to redo the framing.

Course correction recorded: the artifact reframes the work as "extend T-111" (not "build the loop from scratch"), based on the briefing engine surfacing T-111 unprompted. This is a meaningful narrowing — needs to be confirmed in S1 before the recommendation flips.

---

## Next Steps

1. ✅ Filed inception T-2158 (this artifact)
2. Hand off to human via `fw task review T-2158` for first-pass review of framing (optional — human can wait for full evidence walk)
3. Conduct S1 (T-111 substrate trace) — read-only, 25 min
4. Conduct S2 (self-trigger surface walk) — read-only, 20 min
5. Conduct S3 (bounded-autonomy primitives audit) — read-only, 20 min
6. Conduct S4 (scoped-driver critique) — read-only, 15 min
7. Conduct S5 (arc-field validation + orchestrator-rethink delta) — read-only, 15 min
8. Conduct S6 (answer Q1-10) — synthesis, 30 min
9. Update §Recommendation with GO / NO-GO / GO-with-refinements + concrete evidence bullets
10. Hand off to human via `fw task review T-2158` → Watchtower `/inception/T-2158` for final GO/NO-GO

— end —
