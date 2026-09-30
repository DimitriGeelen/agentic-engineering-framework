# T-3535: Project objectives, version 2 (after three-vendor review)

**Status:** reviewed draft, to be shown to the operator once. It is not yet written to
`.context/project/objectives.yaml`.

**How it was made:**
- v1 (`T-3535-objectives-draft.md`) was drafted by an agent from the sources it cites.
- Three independent reviewers checked it against those sources: OpenAI (codex), Z.ai
  (GLM-5.2) and Anthropic (claude -p). All three returned **amber**. Their reviews are in
  `T-3535-objectives-review-{openai,zai,anthropic}.md`.
- Corrections that two or more reviewers made, or that one made with no dissent, are
  applied below.
- Real splits between reviewers are not settled here. They are listed in §3 as the
  operator's calls.

## 1. Objectives

```yaml
headline: >-
  A governance framework for developers and small teams working with AI coding agents:
  every change traces to a task, what was learned survives the session, and humans keep
  authority over what matters while agents carry the rest.
objectives:
  - id: O-1
    text: >-
      In a governed project, every agent change traces to a task, and an agent cannot
      bypass a gate or take a consequential action without it being recorded and, for
      Tier 0, approved by a human.
    measure: >-
      Partly measurable. Commit-to-task traceability comes from `fw audit --section
      traceability` (lib/traceability.sh); `fw metrics` only checks that a T-number appears
      in commit subjects, not that the task exists or authorised the change. Bypass logs
      count recorded exceptions, not undetected ones. Tier 0 sees only the typed command
      string (T-2742), so actions carried out inside scripts are unmeasured.
  - id: O-2
    text: >-
      A new session resumes the recorded task, decisions and next steps without
      reconstructing prior work, and lessons from witnessed failures are available when
      relevant and reduce recurrence.
    measure: >-
      Not instrumented. Pickup time and repeat-failure rate have never been measured.
      Counts of learnings, patterns and escalation entries show coverage only; they are
      not evidence of retrieval or of reduced recurrence. arc-018's "0 of 2416" is a
      historical diagnosis, not a current baseline.
  - id: O-3
    text: >-
      The operator's queue holds only what needs a human: Tier 0, irreversible external
      acts, sovereignty and project direction, and escalations. Other review gets an
      independent agent verdict, and work that advances no objective can be declined.
    measure: >-
      Proxies, computable now:
      (a) `fw review-queue` count;
      (b) `fw reviewer surface`, open Human criteria against their risk subset.
      Target: (a) falls and (b) converges on its risk subset. No end-to-end measure of
      correct routing exists yet. Arc `supports:` coverage is reported, not targeted:
      maximising it would reward forced mappings.
  - id: O-4
    text: >-
      A developer can install AEF in a new or existing project, complete a first governed
      task, and upgrade later while preserving project-owned state.
    measure: >-
      Bounded fixture checks: tests/unit/upgrade_fresh_machine_simulation.bats,
      tests/integration/readme_five_minute_by_hand.bats and
      tests/unit/greenfield_seed_audit_prototype.bats. These do not prove every project
      shape works, and they say nothing about real consumer success.
  - id: O-5
    text: >-
      An agent can reach a named peer in another session, project or host and hand it
      work without the operator relaying, and concurrent agents never corrupt governed
      state.
    measure: >-
      Not measured routinely. Partial diagnostics:
      - age of unread peer consults (23.6h, T-3558 F-3);
      - identity collisions (OBS-567, OBS-574);
      - merge conflicts in .tasks/ or .context/ during concurrent dispatch.
      Dispatch verification pass rate is a secondary signal of hand-off quality. It needs
      a stated window and a duplicate-event rule.
out_of_scope:
  - "Enterprise project management; this is not Jira (T-010 item 2)."
  - "Non-AI development workflows (T-010 item 1)."
  - "Non-technical users; the framework assumes command-line and git comfort (T-010 item 4)."
  - "One framework instance governing several repositories. Each project keeps its own instance, tasks, objectives and approval authority; agents in different projects cooperate as peers (T-010 item 3, narrowed, not repealed, by T-3558)."
  - "Removing or weakening Tier 0 / consequential-action human gates (T-3557 IW-1)."
  - "Unbounded autonomous operation with no ceiling or run cap (continuous-run non_goals)."
  - "Shipping this project's own objectives or state into consumer projects (T-3535; Directive 4)."
  - "A real-time multiplayer human editing product; concurrent agent execution and peer communication remain in scope (T-010 item 5, narrowed by arc-011)."
```

**What changed from v1, and why:**
- **Headline:** puts back "for whom" and human authority.
  *Anthropic; Z.ai and OpenAI accept the synthesis.*
- **O-1:** the measure named the wrong command.
  *Anthropic, OpenAI.*
- **O-2:** now says "available and reduces recurrence", not "is not repeated". The
  sources support continuity, not prevention.
  *OpenAI; Anthropic accepts O-2's honesty about measures.*
- **O-3:**
  - it no longer rests on T-3557's undecided mechanism;
  - it names every human category, not only Tier 0;
  - its measure no longer rewards filled-in `supports:`.
  *All three.*
- **O-4:** "any shape" and "without breakage" went further than the tests can prove.
  *OpenAI.*
- **O-5:** "reliably and securely" could not be tested, and the measure did not match
  the text.
  *Anthropic, OpenAI.*
- **Out of scope:**
  - T-010's "one repo, one instance" is narrowed, not dropped;
  - "non-technical users" is restored;
  - "real-time" now excludes human multiplayer editing only.
  *Anthropic, OpenAI. Z.ai wanted "superseded", and was outvoted.*

## 2. Arc mapping

| Arc | Status | Stale* | `supports:` | Note |
|---|---|---|---|---|
| payload-mediation | in-progress | | O-1 | |
| embeddings-strategy | in-progress | | O-2 | |
| ladder-trigger-producer | draft | | O-2 | |
| horizon-axis-hardening | in-progress | yes | O-2 | thin, but kept by all three |
| continuous-run | in-progress | | O-2, O-3 | |
| value-prioritisation | in-progress | | O-3 | |
| arc-grooming | in-progress | | O-3 | Z.ai and OpenAI say the link is solid; Anthropic says weak (only its abandon/stale slices serve it) |
| dispatch-safety | in-progress | | O-3, O-5 | all three agree |
| project-shape-resilience | in-progress | yes | O-4 | |
| onboarding-shape-detection | in-progress | yes | O-4 | |
| readme-first-run | in-progress | yes | O-4 | |
| onboarding-curriculum | in-progress | | O-4 | |
| arc-020 (identity & circuits) | in-progress | | O-5 | part of its fix belongs in TermLink (Gap Homing) |
| parallel-execution-aef | in-progress | | O-5 | |
| inception-review-loop | draft | | **split, see §3** | |
| capability-overlay | in-progress | yes | **split, see §3** | |
| ewcr-arc0-contract-evidence | in-progress | | **split, see §3** | |
| orchestrator-rethink | in-progress | | **NONE** | all three agree; its own non_goals defer cost-aware routing |
| designer-corpus | in-progress | | **NONE** | all three agree. Reason, corrected per OpenAI: it documents AEF's own processes, but that serves none of the five outcomes |
| watchtower-redesign | in-progress | | **NONE** | the objectives page slice would serve O-3; the arc as written does not |

\*From the 2026-09-27 audit, re-read before writing objectives.yaml.

## 3. The operator's calls (the reviewers split, and no source settles it)

1. **capability-overlay** (stale; agents call fw verbs over MCP instead of Bash).
   - Anthropic and Z.ai: NONE. It is a typed interface for agents already on Claude
     Code, not runtime portability.
   - OpenAI: widen O-4 to "through supported CLI or MCP agent interfaces, without
     dependence on a single agent runtime", and map this arc to O-4.
   - Question: is portability across agent runtimes a project objective, or a directive
     (D4) that work is judged by?
2. **ewcr-arc0-contract-evidence.**
   - Anthropic and Z.ai: NONE. It serves another initiative (ewcr-v1).
   - OpenAI: O-1. It builds contracts and evidence fences for task binding and
     unskippable human gates.
   - Question: does this repo pursue ewcr-v1 as its own direction, or host it for
     someone else?
3. **inception-review-loop** (draft). Its headline ("operator decides an inception in
   two clicks") contradicts your ruling that inceptions go to the agent reviewer by
   default (T-3557 IW-2).
   - Anthropic: O-3, but flag it to abandon or re-scope.
   - OpenAI: O-2, because its durable operator feedback survives into later sessions.
   - Question: re-scope it, or abandon it?
4. **Missing objective?** All three agree that no source supports an "efficient model
   use / cost" objective. That is why orchestrator-rethink maps to NONE. If you want one,
   it is yours to add; the reviewers declined to invent it.

## 4. Recommendations: one ratification instead of four questions

Added 2026-10-01 by the parent session, so that §3 can be settled in one pass. Each item
is a recommendation with its evidence; a reply of "accept" takes all four. New evidence
since the three reviews ran is marked **(new)**.

1. **capability-overlay → NONE.** Portability across agent runtimes is Directive D4:
   every objective is *judged by* it, so it is not an objective of its own. Mapping it
   to O-4 would widen O-4 ("install and upgrade") into a portability goal no test
   measures. The arc is stale; park it (horizon later) rather than abandon it.
   *Agrees with Anthropic and Z.ai.*
2. **ewcr-arc0-contract-evidence → O-1.** **(new)** The arc YAML says it was
   "authorized by the human on 2026-08-26" in this repo, and it is the current focused
   arc. Its headline mechanic (a finding traced to a contract, a refusal scenario, a
   component and an executable verification fence) is O-1's substance: traceable
   changes and gates that cannot be skipped. *Agrees with OpenAI.* **Flip to NONE only
   if** ewcr-v1 is someone else's initiative that this repo merely hosts; that fact is
   yours alone.
3. **inception-review-loop → abandon, as superseded.** **(new)** Its headline, "operator
   decides an inception in two clicks", is replaced by your T-3557 GO (2026-09-30):
   inception decisions are reviewer-judged, and the path that lets a reviewer's verdict
   close one is being built in T-3580 slice 3. Re-scoping would duplicate T-3580. Its one
   durable idea, operator feedback that survives into later sessions (OpenAI's O-2
   point), is captured as a note on T-3580, not kept as an arc.
4. **Add O-6, cost.** **(new)** The reviewers found no source; there is one now. On
   2026-09-30 you ruled that every review or dispatch records its cost, that internal
   means low-cost and never free, and that paid use needs your per-request approval. It
   is codified in T-3583/T-3586 (CLAUDE.md §Review and Dispatch Cost Ruling, a hook, and
   an audit line). The IW-7 spend ceiling (T-3557) also ties review strength to spend.
   ```yaml
     - id: O-6
       text: >-
         Every agent review and dispatch has a recorded cost, paid use happens only with
         the operator's per-request approval, and review strength follows risk within a
         stated spend ceiling.
       measure: >-
         `fw review cost report` (cost per week by backend and class); `fw audit` WARNs
         on paid records with no approved proposal and on every ceiling step-down.
         Coverage is only as good as logging discipline: unlogged use is invisible.
   ```
   orchestrator-rethink stays NONE: its own non_goals defer cost-aware routing.

**If you accept:** the agent writes `.context/project/objectives.yaml` from §1 plus O-6,
sets `supports:` on each arc per §2 and this section, parks capability-overlay, and
files the inception-review-loop abandonment through `fw arc` (the Watchtower arc page is
the operator surface for that). Any item you reject, say which, and it stays open.
