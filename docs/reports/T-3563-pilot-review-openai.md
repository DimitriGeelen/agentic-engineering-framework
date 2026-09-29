# T-3563 pilot fit review — openai

Reviewer: OpenAI (codex, read-only sandbox, in repo). 2026-09-29. Input: T-3563-pilot-review-brief.md; read-only access to the repository. Verbatim.

---

ARC: continuous-run  
VERDICT: amber  
FIDELITY: Checked T-2158’s task and research report, T-3239’s report and E1/E8 transcripts, L-652, T-3200, T-3241, T-3254, T-3257, T-3283 and D-546. The purpose is specific; the objective complements the headline with safety and audit outcomes. However, category-level discard accounting became “every lossy discard”; the browser brake is already implemented; and E8 proves restart machinery but its relaunched agents exit with missing-input errors. Closure criteria omit discard fidelity and actual enforcement of the tier/blast-radius boundary. The September 5 history entry attributes T-3241’s completion to T-3257, which does not establish it.

CORRECTIONS:

```yaml
- field: objective
  replace_with: >-
    Armed sessions continue useful work across context-budget boundaries without
    operator relay, within tier/blast-radius limits, run caps and expiry, with
    an operator halt and category-level discard manifests available for review.
  why: Restores the inception's blast-radius constraint and its explicitly accepted category-level fidelity.

- field: context[6]
  replace_with:
    point: >-
      T-3200 added a Watchtower control that writes the existing halt file;
      browser access is implemented, while phone discoverability and legibility
      await human review.
    source: .tasks/active/T-3200-the-continuous-run-halt-has-no-watchtowe.md#recommendation
  why: The source's implementation and recommendation supersede its original shell-only problem statement.

- field: open_questions[5]
  replace_with:
    question: Is the implemented Watchtower halt control findable and legible to a worried operator on a phone?
    source: .tasks/active/T-3200-the-continuous-run-halt-has-no-watchtowe.md#recommendation
  why: The remaining question concerns usability, not whether the control exists.

- field: success_criteria[SC-1]
  replace_with:
    id: SC-1
    criterion: >-
      A real armed session crosses successive budget boundaries, hands over,
      restarts and resumes useful work without operator relay.
    evidence: >-
      T-3239 E8 demonstrates budget-triggered handover, restart and directive/counter
      state updates with three non-default dials. Its transcript then records
      missing-input errors and restart-budget exhaustion; productive continuation
      across successive budget boundaries is not established by that transcript.
  why: Repeated restart demonstrations do not establish the inception's multi-cycle working session.

- field: success_criteria[SC-5].evidence
  replace_with: >-
    T-3239 E3 reproduces false healthy readings. T-3241, completed 2026-09-05,
    adds unknown-state reporting for failed or insufficient measurements and a
    safe checkpoint.sh budget reader. Its acceptance criteria preserve the
    startup ok/0 seed and fast-path enforcement behavior, so the universal
    criterion is not established by that task alone.
  why: T-3241 explicitly limits its guarantee; its completion cannot prove "never."

- field: success_criteria (append)
  replace_with:
    - id: SC-6
      criterion: >-
        Each autonomous handover records a category-level discard manifest
        available for post-hoc operator review.
      evidence: >-
        Required by docs/reports/T-2158-continuous-run.md, S6 Q4 and build slice S4;
        the draft supplies no demonstration of this criterion.
    - id: SC-7
      criterion: >-
        After resume, work exceeding the configured tier/blast-radius boundary
        is prevented, and Tier 0 actions still require the human gate.
      evidence: >-
        Required by docs/reports/T-2158-continuous-run.md, S3 and build slice S5.
        T-3254's prerequisite section records a session continuing after a
        ceiling breach and requires T-3253; displaying the ceiling or disarming
        the state file alone is insufficient evidence.
  why: These are load-bearing inception constraints, including the approved Discard fidelity driver's closure target.

- field: history[2026-09-05]
  replace_with:
    date: 2026-09-05
    event: >-
      The external driver drove a real agent to completion on a direct tmux
      substrate; the production cron remained paused pending a drivable target.
    source: .tasks/completed/T-3257-real-agent-live-fire-for-continuous-driv.md
  why: Matches this source and preserves the deployment limitation without attributing another task's completion to it.
```

ARC: readme-first-run  
VERDICT: amber  
FIDELITY: Checked T-2715’s problem statement, F-5/F-7 and IW-11; T-2719’s measurements, acceptance criteria and recommendation; the complete Bats test; README’s walkthrough; and T-2883’s acceptance criteria and evolution. The persona distinction and purpose are specific and supported. The objective largely paraphrases the headline. More materially, `five_minute_block()` extracts text for assertions; the behavioral tests run separately authored commands, not the extracted walkthrough. The mutation proves a wording guard, not end-to-end walkthrough coverage. T-2883’s dismissal of OBS-170 is the newer finding, incorrectly marked superseded.

CORRECTIONS:

```yaml
- field: objective
  replace_with: >-
    The documented first-run path is independently usable without an agent:
    promised behavior matches a plain shell, blockers have actionable remedies,
    and by-hand regressions remain visible independently of agent-assisted success.
  why: Defines the durable outcome for scoring and closure without repeating the headline's demo script.

- field: success_criteria[SC-2]
  replace_with:
    id: SC-2
    criterion: >-
      The by-hand path has an executable scenario that runs commands extracted
      from README.md and is included in the integration runner.
    evidence: >-
      Partially established: tests/integration/readme_five_minute_by_hand.bats
      extracts the fenced block for text assertions, but its behavioral tests
      execute separately authored commands. T-2719 records runner inclusion
      through a count delta of four; execution of the extracted walkthrough
      remains unproven.
  why: Preserves the intended acceptance criterion while correcting the implementation claim.

- field: success_criteria[SC-3].evidence
  replace_with: >-
    T-2719 records that restoring the old edit-refusal wording makes test 2
    fail and restoring the correction makes it pass. This verifies the wording
    guard; no cited mutation demonstrates detection of a broken executable
    walkthrough step.
  why: The demonstrated mutation has narrower coverage than "the documented path regresses."

- field: decisions[3]
  replace_with:
    decision: Run README-extracted commands in the by-hand scenario; current extraction only supports text assertions.
    status: active
    date: 2026-08-05
    source: .tasks/completed/T-2719-keystone-readme-five-minute-path-tested-.md
  why: T-2719 supports the intended decision; the test file does not support claiming it fully implemented.

- field: decisions[7]
  replace_with:
    decision: Dismiss OBS-170 as stale; consolidate identity checks using Git's own resolution.
    status: active
    date: 2026-08-09
    source: .tasks/completed/T-2883-obs-170-surface-missing-git-identity-bef.md#evolution
  why: This supersedes the earlier blocker claim and does not establish that no other closure gaps remain.

- field: success_criteria[SC-4].criterion
  replace_with: >-
    Blocks on the documented by-hand path are cleared or have remedies the
    reader can execute; other discovered defects are recorded against owning tasks.
  why: Filing an uncleared walkthrough blocker cannot satisfy the arc's promised usable first-run outcome.
```

ARC: orchestrator-rethink  
VERDICT: amber  
FIDELITY: Checked T-1641’s task and aggregated findings, T-1642’s proposal and recorded GO, T-1643’s wiring evidence, the demo’s read/write/failure and closure sections, D-058, G-061/G-064, T-1671 and T-2303. The investigation, three-way split, autonomous-consumer gap and sibling-arc decision are supported. The purpose describes a past event rather than the intended value. The objective is an assessable outcome that complements the demo, but “every routing constant” exceeds the identified policy scope. SC-2 cites proposed defaults as evidence of explicit rulings. G-061 remains partially mitigated. The cited arc file does not independently establish the claimed 123-task census.

CORRECTIONS:

```yaml
- field: purpose
  replace_with: >-
    Make the framework use outcome-informed model routing in everyday operation,
    under explicit human policy and regression protection, so shipped infrastructure delivers observable orchestration.
  why: States this arc's specific what and why rather than retelling its reopening.

- field: objective
  replace_with: >-
    Ordinary framework workloads select models using recorded outcomes;
    the 13 identified routing-policy parameters have explicit human dispositions,
    including deferrals; and routing, cache and governance contracts have
    regression protection.
  why: Retains a judgeable outcome while bounding the policy obligation to the source's actual scope.

- field: success_criteria[SC-2].evidence
  replace_with: >-
    T-1642 records GO and a table of 13 proposed defaults, but its rationale
    still says explicit decisions remain to be recorded. The cited material
    does not establish a separate human disposition and rationale for each
    parameter; those records must be linked before this criterion passes.
  why: Approval to proceed and a proposal table are not evidence of 13 completed policy rulings.

- field: success_criteria[SC-3]
  replace_with:
    id: SC-3
    criterion: >-
      G-061's minimum defenses are evidenced: MCP task_id audit, an approved
      fallback-order regression test, governance-frame golden fixture,
      task-type tag validator and the Watchtower orchestrator page.
    evidence: >-
      .context/project/concerns.yaml#G-061 records partial mitigation:
      four of five minimum defenses shipped; the fallback-order test remains
      deferred pending policy consultation. Route-cache schema tests are
      additional protection, not a substitute for that missing test.
  why: Makes closure observable and prevents partial mitigation from reading as complete protection.

- field: open_questions (append)
  replace_with:
    question: Where are the human dispositions and rationales for all 13 T-1642 policy parameters, including explicit deferrals?
    source: .tasks/completed/T-1642-arc-a--orchestrator-routing-policy-consu.md#recommendation
  why: The unresolved policy record affects the whole consultation branch, not only fallback-order testing.

- field: open_questions[3]
  replace_with:
    question: Does constituent_tasks define the complete closure scope, or must tasks linked through arc_id also be reconciled?
    source: .context/arcs/orchestrator-rethink.yaml
  why: Retains the useful scope question without presenting an uncited repository census as established evidence.
```

OVERALL: The structure is fit to go live after these corrections distinguish intended outcomes from demonstrated results, restore omitted closure obligations, and replace stale claims.