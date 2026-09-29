```
VERDICT: amber

FIDELITY:
Checked 001-Vision.md §The Vision; T-010's audience, success criteria and Out of Scope;
005-DesignDirectives.md Directive 4; T-3557 (Problem, IW-1..IW-7, status); D-662;
T-3558 Segment 2; T-2209; and all 20 arc YAMLs (headline_mechanic, objective,
non_goals, supports).
Supported: O-1 (Vision + Core Principle + Authority Model), O-2 (Vision + T-010
"success looks like"), O-4 (onboarding arcs, Directive 4 environment agnosticism), and
the quoted numbers (353/11 from T-3557, 0 of 2416 from arc-018, `supports: []` on the
arcs that carry the field).
Not supported or stretched:
 (a) O-3 writes the review-routing design from T-3557 into the objective. T-3557 is
     still `started-work` with no go/no-go recorded and IW-7 open, so a top-level
     objective would rest on an undecided inception.
 (b) O-3's clause "arcs serving no objective can be declined" talks about the
     objectives mechanism itself, and D-662 is a doctrine for judging BVP scores and
     arc drivers. Both are weak sources for an operator-attention outcome.
 (c) O-1's measure points at `fw metrics`, but commit-to-task traceability is
     computed by `fw audit --section traceability` (lib/traceability.sh).
 (d) O-5 leans on T-3558 Segment 2, which is a voice transcript about the
     identity/address ladder. It does not mention parallel-state corruption or hand-off.
     That half of O-5 comes from arc-011's headline only.
 (e) O-5's main measure (dispatch verification pass rate) measures the quality of
     worker output. It does not measure reach, identity or hand-off.
 (f) out_of_scope drops T-010 item 4 ("Non-technical users") without saying so.
     Nothing supersedes it: arc-016 still assumes a shell user.
 (g) The O-4 source "T-3535 §Per-project" is about where objectives live, not about
     installing the framework. It is a mis-attribution.
 (h) T-010's "Framework is faster than not using it" is the one success criterion that
     no objective or measure picks up.

CORRECTIONS:
  - target: headline
    replace_with: >-
      A governance framework for developers and small teams working with AI coding agents:
      every change traces to a task, what was learned survives the session, and humans keep
      authority over what matters while agents carry the rest.
    why: puts back T-010's "for whom" and 001-Vision's sovereignty, which "humans deciding only what matters" had weakened into an efficiency claim.

  - target: O-1 measure
    replace_with: >-
      Partly measurable now. Commit-to-task traceability from `fw audit --section traceability`
      (lib/traceability.sh); Tier-2 bypass entries per week in .context/working/.gate-bypass-log.yaml
      and .context/bypass-log.yaml. Silent bypasses are by definition in no ledger; Tier 0 sees only
      the typed command string (CLAUDE.md §Enforcement Tiers, T-2742), so script-borne actions are unmeasured.
    why: `fw metrics` is not where traceability is computed.

  - target: O-3
    replace_with:
      id: O-3
      text: >-
        The operator's queue holds only decisions that need a human, meaning consequential risk and
        project direction. Everything else reaches a defensible verdict without waiting on the operator,
        and the operator's time costs less than the work it unblocks.
      measure: >-
        Computable now: (a) `fw review-queue` count (325 at T-3535 filing); (b) `fw reviewer surface`
        open Human criteria vs its tier-0/bypass subset (353 vs 11, T-3557). Target: (a) falls and
        (b)'s total converges on its risk subset. Not yet measured: operator time per week
        (T-010 "faster than not using it").
      sources:
        - .tasks/active/T-3557-*.md Problem Statement (353/11); IW-1 (risk set, operator 2026-09-29)
        - docs/reports/T-3535-per-project-objectives.md §The reframe (325 awaiting review)
        - .tasks/completed/T-010-*.md §Primary audience, "Framework is faster than not using it"
    why: states the outcome and leaves out the undecided T-3557 mechanism and the self-referential "arcs can be declined" clause. Measure (c) (supports coverage) tracks the T-3535 rollout, so it belongs on T-3535's build, not on an objective.

  - target: O-5
    replace_with:
      id: O-5
      text: >-
        An agent can reach a named peer, in another session, project or host, and hand it work
        without the operator relaying, and concurrent agents never corrupt governed state.
      measure: >-
        Not measured routinely. Available by hand: age of unread peer consults (23.6h, T-3558 F-3);
        identity-collision observations (OBS-567, OBS-574); merge conflicts in .tasks/ or
        .context/audits/ during concurrent dispatch (arc-011 headline). Dispatch verification pass
        rate (.context/dispatches.jsonl ⋈ dispatch-outcomes.jsonl) is a secondary signal of hand-off quality.
    why: drops the untestable "reliably and securely" and makes the measure match the text. The operator should also know that part of arc-020's fix belongs in TermLink (§Gap Homing).

  - target: out_of_scope
    replace_with:
      - "Enterprise project management; this is not Jira (T-010 §Out of Scope, item 2)."
      - "Non-AI development workflows (T-010 §Out of Scope, item 1)."
      - "Non-technical users; the framework assumes command-line and git comfort (T-010 §Out of Scope, item 4)."
      - "One framework instance governing several repositories. Each project keeps its own instance, tasks and objectives; agents in different projects cooperate as peers (T-010 item 3, narrowed by T-3535 §Per-project and T-3558)."
      - "Removing or weakening Tier 0 / consequential-action human gates (continuous-run non_goals; T-3557 IW-1)."
      - "Unbounded autonomous operation with no ceiling or run cap (continuous-run non_goals)."
      - "Shipping this project's own objectives, goals or state into consumer projects (T-3535 §Per-project; Directive 4)."
      - "Real-time multiplayer collaboration; turn-based by design (T-010 §Out of Scope, item 5)."
    why: puts back the dropped item 4 and settles the T-010/T-3558 conflict without discarding item 3. T-3535's own per-project ruling reaffirms "one repo, one instance"; only "no cross-repo cooperation" is superseded.

  - target: O-4 sources
    replace_with: replace "docs/reports/T-3535-per-project-objectives.md §Per-project, not framework-owned" with ".tasks/completed/T-010-*.md §Primary audience (success: new session productive fast)" and "CLAUDE.md §Consumer-Facing Command Hygiene (T-1633)"
    why: the cited section is about where objectives live, not about installation.

  - target: mapping:dispatch-safety
    replace_with: "O-5, O-3"
    why: the headline is pause, then operator answers, then re-dispatch. That is about when a human is needed (O-3) as much as hand-off (O-5); the draft admits this in prose but leaves it out of `supports:`.

  - target: mapping:inception-review-loop
    replace_with: "O-3, with an operator note that the headline ('operator decides an inception in two clicks') contradicts T-3557 IW-2 (inceptions go to the agent reviewer by default); candidate for abandon or re-scope"
    why: turns a quiet "possibly superseded" into something the operator can act on. The arc is a draft.

  - target: mapping:arc-grooming
    replace_with: "O-3 (weak: only its stale-arc audit and `fw arc abandon` slices serve it; the ID-allocation and arc_id-parity slices serve none)"
    why: most of the headline is plumbing, so the operator should see that the link is weak.

AUTHOR'S DOUBTS:
 1. T-010 item 3 is narrowed, not superseded. Keep "one project, one instance" (reaffirmed by T-3535) and drop only the ban on cross-repo cooperation; see the out_of_scope correction.
 2. Keep O-3 as one objective, but make it outcome-only (correction above). Splitting adds an objective and gives nothing new to decline.
 3. The headline synthesis is fair, but it had lost "for whom" and "sovereignty". Use the replacement.
 4. orchestrator-rethink → NONE is correct. Its own non_goals defer cost-aware selection (T-1637), so no source supports an "efficient model use" objective. Ask the operator; don't invent one.
 5. capability-overlay → NONE is correct. T-2209 frames it as a typed interface for agents already on Claude Code, not as runtime portability. Do not widen O-4.
 6. ewcr-arc0 and designer-corpus → NONE are correct for this project. Their stated beneficiaries are another initiative (ewcr-v1) and another project (832's designer). Flag them to the operator as candidates to decline or rehome, per §Gap Homing.
 7. horizon-axis-hardening → O-2 holds: an accurate handover WIP list is resume-from-recorded-state. arc-grooming → O-3 is weak; label it as such.
 8. The measures are mostly honest. Fix O-1 (wrong command) and O-5 (measure does not match the text). O-2's admission that nothing is instrumented is right and should stay.
 9. A three-day-old stale flag is fine for a draft. Re-read the audit when writing objectives.yaml.

OVERALL: Fit to show the operator after these corrections: the structure is sound and the NONE set does real declining. As drafted, O-3 would quietly steer every arc under it by an inception nobody has decided yet.
```
