# T-3535 — Project objectives draft (999, Agentic Engineering Framework)

**Status:** agent draft for independent review, then shown once to the operator
(T-3535 rollout ruling (d), option C1). Not yet written to
`.context/project/objectives.yaml`. Drafted 2026-09-30 by agent `t3535-objectives`.

**Method.** Objectives are taken from the project's stated intent (001-Vision.md
§The Vision, T-010 audience), the operator's recent rulings (T-3535, T-3557, T-3558,
T-3563) and the arcs' own headline mechanics. The four directives (D1–D4) are *how*
work is judged, not *where* it is going, so no objective restates one. Every
objective is written so that at least one current arc serves none of it.

## 1. Proposed `.context/project/objectives.yaml`

```yaml
headline: >-
  A governance framework that lets developers work with AI coding agents:
  every action traced to intent, knowledge kept across sessions, humans deciding only what matters.
objectives:
  - id: O-1
    text: >-
      In a governed project, every agent change traces to a task, and an agent
      cannot silently bypass a gate or take a consequential action without human approval.
    measure: >-
      Partly measurable now. Commit-to-task traceability from `fw metrics` (git log
      vs task refs); Tier-2 bypass entries per week in
      .context/working/.gate-bypass-log.yaml and .context/bypass-log.yaml (should
      be few, and each one logged). "Silent" bypasses are by definition not in any
      ledger, so the real outcome is not yet measurable; CLAUDE.md §Enforcement
      Tiers states Tier 0 only sees the typed command string (T-2742).
    sources:
      - 001-Vision.md §The Vision ("Nothing gets done without a task", "Humans retain sovereignty")
      - CLAUDE.md §Core Principle, §Authority Model, §Enforcement Tiers
      - 005-DesignDirectives.md AD-009, AD-010
      - .context/arcs/payload-mediation.yaml headline_mechanic
  - id: O-2
    text: >-
      A new session resumes from recorded state without re-discovery, and a
      failure the framework has already witnessed is recorded and retrievable, so it is not repeated.
    measure: >-
      Outcome not yet measurable (T-010's "<1 minute pickup" and 001-Vision's
      "rework rate decreasing" were never instrumented). Computable proxies:
      learnings/patterns in .context/project/learnings.yaml and healing patterns
      (`fw healing patterns`); tasks carrying an escalation-ladder entry after a
      witnessed failure (arc-018 description: set on 0 of 2416 tasks).
    sources:
      - 001-Vision.md §The Problem (Learning, Memory), §The Vision ("Failures become learning", "Context persists")
      - .tasks/completed/T-010-define-framework-scope-and-audience.md §Primary audience, success looks like
      - 005-DesignDirectives.md AD-002
  - id: O-3
    text: >-
      Operator attention is spent only on risk and direction: high-risk decisions
      stay human, other review goes to independent agent reviewers, and arcs serving no objective can be declined.
    measure: >-
      Computable now. (a) Tasks awaiting human review: `fw review-queue` count
      (325 at T-3535 filing). (b) Open Human criteria by class: `fw reviewer surface`
      (353 open, 11 tier-0/bypass, per T-3557). Direction of travel: (b) total
      approaches the risk-class subset. (c) In-progress arcs with a non-empty
      `supports:` (0 of 20 today; every arc YAML has `supports: []` or no field).
    sources:
      - .tasks/active/T-3557-human-review-is-for-risk-only---everythi.md (Problem Statement, IW-1, IW-2)
      - docs/reports/T-3535-per-project-objectives.md §The reframe
      - docs/reports/T-3563-arc-story.md §Dialogue Log segment 2
      - .context/project/decisions.yaml D-662
  - id: O-4
    text: >-
      A person or agent can install the framework into a new or existing project
      of any shape, reach a working first task, and upgrade it later without breakage.
    measure: >-
      Partly computable: pass/fail of tests/unit/upgrade_fresh_machine_simulation.bats,
      tests/integration/readme_five_minute_by_hand.bats and
      tests/unit/greenfield_seed_audit_prototype.bats (arc-015 notes the last was
      RED and unwired at arc creation; current state not checked for this draft).
      Real-world success in consumer projects is not measurable from this repo.
    sources:
      - 005-DesignDirectives.md Directive 4 (environment agnosticism)
      - CLAUDE.md §Consumer-Facing Command Hygiene, §Release-Train Branch Model (master = consumer install surface)
      - docs/reports/T-3535-per-project-objectives.md §Per-project, not framework-owned
      - .context/arcs/project-shape-resilience.yaml, readme-first-run.yaml, onboarding-shape-detection.yaml headline_mechanic
  - id: O-5
    text: >-
      Agents can reach, identify and hand work to each other across sessions,
      projects and hosts, reliably and securely, and parallel work does not corrupt governed state.
    measure: >-
      Partly computable: dispatch verification pass rate by workflow_type, joined
      from .context/dispatches.jsonl and .context/dispatch-outcomes.jsonl (the
      CLAUDE.md §Execution Model table). Not yet measured routinely: age of unread
      peer consults (T-3558 F-3 found 23.6h), identity collisions (OBS-567, OBS-574).
    sources:
      - docs/reports/T-3558-circuit-address-everywhere.md §Segment 2 (operator: circuit model applies everywhere)
      - CLAUDE.md §Execution Model: Dispatch by Default, §Sub-Agent Dispatch Protocol
      - .context/arcs/arc-020.yaml description, parallel-execution-aef.yaml headline_mechanic
out_of_scope:
  - "Enterprise project management; this is not Jira (T-010 §Out of Scope, item 2)."
  - "Non-AI development workflows (T-010 §Out of Scope, item 1)."
  - "Removing or weakening Tier 0 / consequential-action human gates (continuous-run non_goals; T-3557 IW-1 keeps Tier 0 human)."
  - "Unbounded autonomous operation with no ceiling or run cap (continuous-run non_goals)."
  - "Shipping this project's own objectives, goals or state into consumer projects (T-3535 §Per-project; Directive 4)."
  - "Real-time multiplayer collaboration; turn-based by design (T-010 §Out of Scope, item 5)."
```

## 2. Arc mapping (`supports:` proposal)

Staleness is from the 2026-09-27 audit (`.context/audits/2026-09-27.yaml`, no task
commits in 30 days).

| Arc | Id | Status | Stale | `supports:` | Reason |
|---|---|---|---|---|---|
| payload-mediation | arc-013 | in-progress | | O-1 | Headline: agent's self-authorising action is denied at the wire and blocked by the OS sandbox. |
| embeddings-strategy | arc-002 | in-progress | | O-2 | `fw recall` retrieval; headline names "amnesia incidents drop". |
| ladder-trigger-producer | arc-018 | draft | | O-2 | Witnessed failures (P-011, bypasses, Tier-0 blocks) produce escalation entries without self-report. |
| horizon-axis-hardening | arc-009 | in-progress | yes | O-2 | Handover WIP list shows correct state; a narrow slice of "resume from recorded state". |
| continuous-run | arc-012 | in-progress | | O-2, O-3 | Session resumes across budget boundaries, without operator relay, within bounds. |
| inception-review-loop | arc-008 | draft | | O-3 | Operator decides inceptions with less friction. Possibly superseded: T-3557 IW-2 moves inception go/no-go to agent review by default. |
| value-prioritisation | arc-006 | in-progress | | O-3 | Ranking basis for choosing and declining work. |
| arc-grooming | arc-005 | in-progress | | O-3 | Stale-arc audit and `fw arc abandon` are the existing declining mechanism. |
| project-shape-resilience | arc-004 | in-progress | yes | O-4 | Any fw verb behaves sensibly in all four project shapes. |
| onboarding-shape-detection | arc-015 | in-progress | yes | O-4 | `fw init` in an existing project seeds a workable task set. |
| readme-first-run | arc-016 | in-progress | yes | O-4 | By-hand five-minute path reaches a first task. |
| onboarding-curriculum | arc-017 | in-progress | | O-4 | New operator starts real work; gated set cannot deadlock. |
| arc-020 (identity & circuits) | arc-020 | in-progress | | O-5 | Durable agent identity; circuits self-heal. |
| parallel-execution-aef | arc-011 | in-progress | | O-5 | Concurrent agents without governance-plane corruption. |
| dispatch-safety | arc-001 | in-progress | | O-5 | Workers pause on ambiguity and resume via re-dispatch. Also touches O-3 (only risk crosses the threshold to the operator). |
| **capability-overlay** | arc-010 | in-progress | **yes** | **NONE** | Headline: agent calls fw verbs over MCP instead of Bash. That is D4 (prefer MCP) as a means; no objective's outcome changes. |
| **designer-corpus** | arc-014 | in-progress | | **NONE** | Documents AEF processes as BPMN in the designer; serves 832's designer development, not an outcome above. |
| **ewcr-arc0-contract-evidence** | arc-019 | in-progress | | **NONE** | Evidence baseline for initiative ewcr-v1 (T-3147: "produces a number and a written disposition; it does not act on either"). No objective names that initiative. |
| **orchestrator-rethink** | arc-003 | in-progress | | **NONE** | Outcome-informed model routing. Nearest is O-2 "learning from recorded outcomes", but O-2 is about sessions not repeating failures, not model choice. Not stretched. |
| **watchtower-redesign** | arc-007 | in-progress | | **NONE** | Headline is a theme/appearance picker. T-3535 IW-4 may fold the objectives page into this arc; if so, that slice would serve O-3, the arc as written does not. |

Totals: 15 arcs mapped to at least one objective, **5 mapped to NONE**. One of the
NONE arcs is also stale (capability-overlay), which is the exact pairing T-3535 IW-5
names as the audit signal.

Objectives with thin coverage: O-1 is served by one arc (payload-mediation). That
fits: the core gates it describes were built early (001-Vision §Current State) and
are not arc-shaped work. It is not a reason to invent arcs.

## 3. What I was unsure about

1. **O-5 conflicts with T-010.** T-010 §Out of Scope item 3 says "Multi-repo
   orchestration — one repo, one framework instance". T-3558 (operator, 2026-09-29)
   says the circuit model applies across sessions, projects, hub and machine, and
   arc-020 and arc-011 are in progress on it. I took the newer operator ruling as
   current intent and dropped T-010 item 3 from out_of_scope. The operator should
   confirm T-010 item 3 is superseded.
2. **O-3 is compound.** It joins two same-week rulings (T-3557 review routing,
   T-3535 declinability) because both address the operator being the bottleneck
   (325 tasks awaiting review). A reviewer may prefer them split; that would make
   six objectives, over the 3–5 limit.
3. **The headline is my synthesis.** No source states a one-sentence headline.
   It combines 001-Vision §The Vision's four bullets and T-010's primary audience
   (solo developer or small team using AI coding agents). "For whom" is from T-010
   (2026-02); nothing newer restates the audience.
4. **orchestrator-rethink as NONE** is the mapping most likely to be contested. Its
   own `objective:` field (outcome-informed routing) could be read as O-2-style
   learning, or as an efficiency objective (model cost/quality) that this draft does
   not have. If the operator considers efficient model use a project objective, it
   is missing here, not a mapping error.
5. **capability-overlay as NONE.** If the operator reads Directive 4 portability
   (agent runtimes other than Claude Code, via MCP) as an outcome, O-4 could be
   widened to "any project and any agent runtime", and this arc would then serve it.
   I kept O-4 to project shape because that is what the onboarding arcs and T-3535's
   per-project constraint describe.
6. **ewcr-arc0 and designer-corpus** involve other initiatives or projects (ewcr-v1,
   832) whose goals I did not read (the ewcr source packet is under
   docs/research/executable-workflow/). They may serve an objective of a
   cross-project collaboration kind that this repo does not state.
7. **Weak mappings.** horizon-axis-hardening → O-2 and arc-grooming → O-3 are the
   thinnest links in the "serves" column. Both are defensible from their headlines,
   but a stricter reading would make them NONE (7 total).
8. **Measures.** O-2's real outcome (repeat failures, pickup time) has never been
   instrumented; the listed measures are proxies. O-1's "silent bypass" is by
   definition not in a ledger. I did not run any command to get current values;
   the numbers quoted (325, 353/11, 0 of 2416, 23.6h, 0 of 20 `supports:`) are
   copied from the cited files or read from arc YAML on 2026-09-30.
9. **Stale data.** Stale flags come from the 2026-09-27 audit, three days old.
   001-Vision §Current State is dated 2026-02-14 and was used for intent only.
