# Agent-to-Human Handoff Patterns: Research Findings

**Research scope:** How production systems handle "human action required" states, manual approval gates, actionable runbook steps, verification criteria, and agentic coding tool handoffs.

**Date:** 2026-03-05

---

## 1. Task Management Systems: "Human Action Required" States

### Linear

Linear organizes workflow into five fixed categories: **Backlog > Todo > In Progress > Done > Canceled**, plus an optional **Triage** inbox. There is no built-in "Awaiting Human" or "Blocked" status category. Teams must create custom statuses within the "In Progress" category (e.g., "In Review", "Ready to Merge", "Needs Input") to represent human-action-required states.

**Key pattern:** Linear treats the status category as structural (fixed) and the status name as semantic (customizable). The system does not enforce what "In Review" means — it's a label, not a gate. The Triage category is the closest to a structural handoff: issues land there from integrations (Slack, support tickets) and require human triage to move forward.

**What works:**
- Triage-as-inbox: external inputs enter a holding area, not the main workflow
- Custom statuses within categories let teams model their own handoff points
- Auto-close/auto-archive for done states reduces stale work

**What's missing:**
- No structural enforcement that "In Review" actually gets reviewed
- No context attachment to the status transition (why does this need review?)
- No deadline/SLA on human-action states

### Jira / Jira Service Management

Jira provides explicit approval workflow mechanisms:
- **"Awaiting Approval"** status with **"Block transition until approval"** condition — a structural gate, not just a label
- Conditional routing: issues can skip approval for low-risk changes, require it for others
- Automation rules that transition issues to "Awaiting Approval", set approver groups, and notify
- **Dead-end detection:** statuses like ON HOLD or PARKED accumulate stale items; automation rules can periodically remind assignees

**Key pattern:** Jira separates the *gate* (block transition until approved) from the *status* (Awaiting Approval). The gate is mechanical enforcement; the status is the human-visible label. This is analogous to the framework's Tier 0/Tier 1 enforcement + task status.

**What works:**
- Structural blocking: transition literally cannot happen without approval
- Approver groups: specific people/roles are notified, not "someone"
- Automation-driven reminders for stale blocked items
- Conditional approval: not everything needs a human gate

**What's missing:**
- Context for the approver is limited to the issue description — no "here's what changed and why you need to look"
- Approval is binary (approve/reject) with optional comment, not structured decision input

### Synthesis: Task Management Handoff Patterns

| Pattern | Description | Actionability |
|---------|-------------|---------------|
| **Status-as-label** | Custom status name (Linear) | Low — relies on humans noticing |
| **Status-as-gate** | Blocked transition (Jira) | High — mechanically enforced |
| **Triage inbox** | Separate holding area for external inputs | Medium — ensures nothing skipped |
| **Stale reminders** | Automation pings on aged blocked items | Medium — prevents rot |
| **Conditional routing** | Skip approval for low-risk | High — reduces approval fatigue |

---

## 2. CI/CD Manual Approval Gates

### Spinnaker Manual Judgment

Spinnaker's Manual Judgment stage is the gold standard for approval gates with context:
- **Instructions field:** Free-text guidance displayed to the approver explaining what to check and how to decide
- **Input options:** Structured choices (e.g., "deploy another", "clean up", "do nothing") — not just approve/reject
- **Downstream branching:** Selected options drive conditional logic in later stages via `#judgment()` helper
- **Role-based:** Specific roles can be required to execute the judgment
- **Auth propagation:** The approver's identity propagates to subsequent stages, so their permissions govern what happens next

**Key pattern:** The instructions field transforms approval from "click yes/no" to "read this context, then choose from these options." The structured input options make the decision machine-readable for downstream stages.

### GitHub Actions Environment Protection

- **Required reviewers:** Specific people or teams must approve before a job proceeds
- **Wait timers:** Configurable delay before jobs can proceed (gives reviewers time)
- **Custom protection rules:** Third-party services (Datadog, Honeycomb) can provide automated approval signals
- **Self-approval prevention:** Can prevent the person who triggered the workflow from approving it
- **Comment field:** Reviewers can leave optional context when approving or rejecting

**What's limited:** The reviewer sees the job name and environment name but limited structured context about *what* will be deployed and *why* this needs human eyes. Context must be inferred from the PR or commit messages.

### Terraform Plan-then-Apply

The Terraform pattern is perhaps the most instructive for agent handoffs:
1. `terraform plan` generates a **complete, deterministic diff** of what will change
2. Plan output is **posted as a PR comment** for the reviewer to read
3. The **saved plan file** ensures what was reviewed is exactly what gets applied
4. Human reviews the diff, then approves or rejects

**Key pattern:** **Show the exact change, not a summary.** The plan output is the artifact; the approval is a gate on that specific artifact. There's no gap between "what I reviewed" and "what will execute."

### Synthesis: CI/CD Approval Patterns

| Pattern | Description | Actionability |
|---------|-------------|---------------|
| **Instructions field** | Tell approver what to check (Spinnaker) | Very high — directs attention |
| **Structured options** | Named choices, not just approve/reject | Very high — machine-readable decisions |
| **Deterministic diff** | Show exact changes (Terraform plan) | Very high — no ambiguity |
| **Role-scoping** | Only specific people can approve | Medium — ensures right person |
| **Auth propagation** | Approver's identity carries forward | Medium — accountability |
| **Wait timers** | Give humans time before auto-proceeding | Low-medium — passive |

---

## 3. Runbook-Driven Systems: Actionable Steps

### Rootly's 5A Framework

Rootly defines five principles for effective runbooks:
1. **Actionable** — Every step is a command, not a paragraph. Copy-pasteable, unambiguous, executable under pressure.
2. **Accessible** — Visible where teams work (Slack, PagerDuty, incident platforms), not buried in a wiki.
3. **Accurate** — Current and verified through quarterly reviews. Stale runbooks are worse than none.
4. **Authoritative** — Single source of truth. No conflicting procedures.
5. **Adaptable** — Evolving with systems, refined through post-incident reviews.

**Key insight:** "Every step should be a command, not a paragraph. Long narratives slow decision-making."

### Rootly's Seven-Step Structure

1. Define scope, trigger, and impact
2. Collect context automatically (don't make responders hunt for logs/dashboards)
3. Build a quick triage checklist
4. Document the exact fix with precise commands
5. Include a communications checklist
6. Verify resolution with measurable metrics
7. Close the loop via post-mortem review

**Key pattern:** Context should be **pulled automatically**, not gathered manually. Rootly attaches metrics, deployment histories, and monitoring links directly into the incident channel.

### FireHydrant: Turn-by-Turn Navigation

FireHydrant uses a GPS analogy: tasks provide "turn-by-turn directions" through incidents. Key structural elements:

**Two-tier action items:**
- **Tasks** — Mid-incident, urgent action items. Assigned to a responder, can have due times (relative: "15 minutes from now" or absolute). Auto-triggered by runbooks based on incident conditions.
- **Follow-ups** — Post-incident items uncovered during response. States: Open > In Progress > Done > Cancelled. Synced to external issue trackers (Jira, Shortcut).

**What makes them actionable:**
- Tasks are auto-populated from pre-configured runbooks when incident conditions match
- Commanders can add ad-hoc tasks as new information emerges
- Tasks live inside the incident workspace (Slack), not in a separate doc
- Each task has: assignment, clear instructions, due time, completion state

**Key pattern:** **Bring the playbook to the responder, not the responder to the playbook.** Tasks surface inside the communication channel where work happens.

### incident.io

Slack-native approach: action items captured directly in Slack, assigned to team members, synced to issue trackers. AI transcribes meetings and creates summaries. The emphasis is on capturing action items *where the conversation happens* rather than requiring context-switching.

### Synthesis: Runbook Actionability Patterns

| Pattern | Description | Actionability |
|---------|-------------|---------------|
| **Commands, not paragraphs** | Each step is executable | Very high |
| **Auto-context injection** | Pull logs/metrics into the workspace | Very high — eliminates hunting |
| **Two-tier actions** | Mid-incident (urgent) vs. follow-up (later) | High — prevents priority confusion |
| **In-channel tasks** | Actions appear where communication happens | High — no context switching |
| **Due times** | Relative or absolute deadlines | Medium-high — creates urgency |
| **Runbook auto-trigger** | Conditions match → tasks populate | High — consistency, no memory dependence |

---

## 4. Acceptance Criteria & Verification Literature

### Definition of Done vs. Acceptance Criteria

The literature draws a clear distinction:
- **Definition of Done (DoD):** Team-level quality checklist applied to ALL items (e.g., "tests pass", "docs updated", "reviewed"). Stable across sprints.
- **Acceptance Criteria (AC):** Item-specific conditions for THIS feature/bug. Varies per item.

Both are needed. DoD prevents "it works on my machine" drift. AC prevents "it does what I think, not what you need."

### Given-When-Then (GWT) / BDD Format

The most actionable format for verification criteria:
```
Given [context/precondition]
When [action/trigger]
Then [observable outcome]
```

**Why it works:**
- **Given** sets up the test data and system state — eliminates "it depends" ambiguity
- **When** defines the exact user interaction — prevents "check that it works" vagueness
- **Then** specifies a verifiable result — can be directly translated to an automated test

**Key insight from the literature:** "Each acceptance criterion must be independently testable and thus have clear pass or fail scenarios." The criterion is actionable when it can be directly translated into a test. If it can't, it's too vague.

### Machine-Checkable Criteria

BDD/Gherkin turns human-readable criteria into executable tests:
```gherkin
Scenario: Login with valid credentials
  Given the user is on the login page
  When they enter "admin" and "password123"
  Then they should see the dashboard
```

This is both human-readable AND machine-executable. The gap between "what to verify" and "how to verify it" is zero.

### Quantifiable Measures

Best practice: use quantifiable measures where possible:
- Bad: "The page should load quickly"
- Good: "The page should load in under 3 seconds"
- Bad: "The search results should be relevant"
- Good: "The first 3 search results should contain the query term"

### Synthesis: Verification Actionability Patterns

| Pattern | Description | Actionability |
|---------|-------------|---------------|
| **GWT format** | Given/When/Then structure | Very high — directly testable |
| **Quantifiable thresholds** | Numbers, not adjectives | Very high — no interpretation |
| **DoD + AC split** | Team-level vs. item-level | High — prevents both drift types |
| **Machine-executable** | Criteria ARE the tests (Gherkin) | Maximum — zero verification gap |
| **Independent testability** | Each criterion stands alone | High — prevents compound ambiguity |

---

## 5. Agentic Coding Tools: Agent-to-Human Handoffs

### Devin (Cognition)

**Handoff mechanism:** Pull requests with descriptions explaining decisions.
- Opens PRs, writes detailed descriptions, responds to human code review comments
- "Devin Review" adds a self-review layer — catches ~30% more issues before human review
- Logs thoughts in `notes.txt` during work (thinking trail / memory)
- Builds a knowledge base per repo — persistent context for future sessions
- Stores structured "knowledge entries" as persistent context
- Async model: human kicks off work, reviews when convenient
- Multiple parallel instances, each with its own cloud IDE
- "Whether you prefer closely tracking progress or a hands-off approach, Devin actively brings you in as needed"

**What makes it actionable:**
- PR descriptions explain *why* decisions were made, not just *what* changed
- Self-review catches obvious issues before human's time is spent
- Knowledge base means context accumulates across sessions

**What's missing:**
- No structured "here are the 3 things you need to verify" in the PR
- No explicit distinction between "I'm confident about this" and "I need your judgment on this"
- The notes.txt thinking log is available but not structured for human consumption

### GitHub Copilot Workspace (sunset May 2025, but patterns are instructive)

**Handoff mechanism:** Multi-stage workflow with human checkpoints at every stage.

The workflow: **Issue → Specification → Plan → Implementation → PR**

At each stage:
1. **Spec stage:** Shows current state and desired state as bullet points. Human can edit both.
2. **Plan stage:** Shows every file to create/modify/delete with bullet-point actions per file. Human can edit any part.
3. **Implementation stage:** Shows diffs per file. Diffs are editable. Human can tweak code directly.
4. **Validation:** Integrated terminal for running build/lint/test against changes.
5. **PR creation:** Includes link to read-only Workspace showing the full development context.

**Key pattern:** **Human can intervene at every stage, not just at the end.** The spec/plan/implement separation means the human can catch direction errors before code is written. The PR links back to the full workspace context.

**What makes it actionable:**
- Each stage shows exactly what will happen next (plan), then exactly what happened (diff)
- Human edits are incorporated, not overwritten
- Validation commands can be run before creating the PR

### Claude Code

**Handoff patterns (from community/documentation):**
- Permission system: fine-grained control over what the agent can do autonomously
- Approval gates before destructive actions
- Configurable autonomy levels per task type
- Audit trails of every agent action
- Loop guards: max iterations, token budgets, diff-size thresholds that trigger human escalation
- Checkpoints and subagents with human-in-the-loop review between stages
- Build-then-validate pattern: specialist agent completes, quality agent inspects before marking done

**Key pattern:** Structural enforcement of boundaries. The agent doesn't decide when to hand off — the *system* enforces it via hooks, gates, and permission boundaries.

### Synthesis: Agentic Tool Handoff Patterns

| Pattern | Description | Actionability |
|---------|-------------|---------------|
| **PR-as-handoff** | Agent submits PR for human review | Medium — standard but context-poor |
| **Self-review before handoff** | Agent reviews own work first (Devin) | High — reduces human review burden |
| **Multi-stage checkpoints** | Human can intervene at spec/plan/code (Copilot WS) | Very high — catches errors early |
| **Thinking trail** | Agent's reasoning available (notes.txt, workspace link) | Medium — available but unstructured |
| **Structural gates** | System enforces handoff points (Claude Code hooks) | Very high — not agent discretion |
| **Knowledge persistence** | Context accumulates across sessions (Devin KB) | High — reduces re-explanation |
| **Confidence signaling** | Agent indicates certainty level | Low — no tool does this well yet |

---

## 6. Cross-Cutting Patterns: What Makes a Handoff Actionable vs. Vague

### The Actionability Spectrum

Based on all five domains, handoffs range from vague to actionable along these dimensions:

**Vague handoff characteristics:**
- Status label only ("In Review") with no context about what to review
- Prose paragraphs requiring interpretation under pressure
- No clear assignee — "someone should look at this"
- No deadline or urgency signal
- No distinction between "verify this is correct" vs. "decide between these options"
- Reasoning and context buried in conversation history or separate documents

**Actionable handoff characteristics:**
- **Specific assignee or role** — not "someone" but "the person responsible for X"
- **Structured context** — what changed, why, what to check (Spinnaker instructions field)
- **Deterministic artifact** — the exact thing to review, not a summary (Terraform plan)
- **Executable verification** — commands that produce pass/fail, not subjective assessment (GWT, runbook commands)
- **Structured options** — named choices, not open-ended "what do you think?" (Spinnaker judgment inputs)
- **Deadline/urgency** — when this needs to happen (FireHydrant due times)
- **In-context delivery** — the handoff appears where the human works (Slack, PR, IDE), not in a separate system

### The Five Properties of an Actionable Handoff

Synthesizing across all domains:

1. **WHO** — Specific person or role, not "someone." (Jira approver groups, Spinnaker role-scoping, FireHydrant assignment)

2. **WHAT** — The exact artifact to review/act on, not a summary. (Terraform plan output, Copilot Workspace diffs, GWT scenarios)

3. **WHY** — Why this needs human judgment, not just "please review." What specifically can't the automation/agent decide? (Spinnaker instructions, Devin PR descriptions, inception go/no-go)

4. **HOW** — Concrete steps to verify or decide. Commands to run, criteria to check, options to choose from. (Runbook commands, Spinnaker input options, BDD Given/When/Then)

5. **WHEN** — Urgency/deadline signal. (FireHydrant due times, GitHub wait timers, Jira SLAs)

### The "Command, Not Paragraph" Principle

The single most impactful pattern across all domains: **replace prose with executable actions.**

| Domain | Vague | Actionable |
|--------|-------|------------|
| Runbooks | "Check if the service is healthy" | `curl -sf http://service:8080/health \|\| echo FAIL` |
| Acceptance | "Search should work correctly" | `Given a product "Widget" exists, When user searches "Wid", Then "Widget" appears in results` |
| CI/CD | "Review the changes" | "Verify the plan adds 3 resources and deletes none. Choose: deploy / rollback / hold" |
| Agent handoff | "Please review my changes" | "I changed auth logic in 2 files. Verify: 1) login works with test creds, 2) session expires after 30min. Run: `npm test -- --grep auth`" |
| Task mgmt | "Blocked — needs input" | "Blocked: need decision on OAuth provider. Options: A) Auth0 (faster, $$$), B) Keycloak (free, more work). See trade-off analysis in docs/decisions/T-042-oauth.md" |

### Anti-Patterns to Avoid

1. **The Status-Only Handoff:** Setting status to "needs review" without any context about what to review or why.
2. **The Wall-of-Text Handoff:** Dumping the agent's entire reasoning as a handoff, forcing the human to extract the action items.
3. **The Implicit Handoff:** The agent stops working without explicitly signaling what the human needs to do next.
4. **The Vague Ask:** "Please review" without specifying what to look for.
5. **The Missing Deadline:** No urgency signal, causing the handoff to rot in a queue.
6. **The Wrong-Channel Handoff:** Putting the action item where the human won't see it (e.g., deep in a task file when they work in Slack/PR).

---

## 7. Implications for Agentic Engineering Framework

### Current Framework Handoff Mechanisms

The framework already has several handoff patterns:
- **`owner: human` on tasks** — signals human ownership
- **Agent/Human AC split** — distinguishes agent-verifiable from human-verifiable criteria
- **`partial-complete` state** — task stays in active/ with owner: human after agent ACs pass
- **Handover documents** — session-end context transfer

### Gaps Identified by This Research

1. **No structured "why" in the handoff.** When a task enters partial-complete, the human sees unchecked ACs but not *why* the agent couldn't check them or *what specifically* to verify.

2. **No structured options.** When the agent is blocked on a decision, it should present named options with trade-offs (like Spinnaker's judgment inputs), not prose.

3. **No executable verification for human ACs.** Agent ACs often have verification commands; human ACs are purely descriptive. Could we provide "suggested verification" commands even for human ACs?

4. **No urgency/deadline signal.** The horizon field (now/next/later) approximates priority but doesn't signal "this handoff will become stale after X."

5. **No in-channel delivery.** Handoffs live in task files and handover docs. If the human works in a different context (terminal, PR review), they may not see the handoff.

6. **Missing confidence signal.** The agent doesn't distinguish "I'm 95% sure this is correct, just rubber-stamp it" from "I genuinely don't know which option is better, I need your judgment."

### Recommended Patterns to Adopt

1. **Instructions field on human ACs:** Add a brief "what to check and how" note to each human AC, like Spinnaker's instructions field.

2. **Structured decision requests:** When blocked on a decision, use a template: Options (lettered), Trade-offs per option, Recommendation (if any), Deadline for decision.

3. **Suggested verification commands for human ACs:** Even when only a human can judge the result, provide the command to set up the verification scenario.

4. **Staleness timeout on handoffs:** Add a TTL to handoff items so they surface in audits if not acted on.

5. **Confidence signaling:** Agent indicates: "rubber-stamp" (high confidence, minor human check), "judgment needed" (genuine decision point), or "blocked" (cannot proceed without human input).

---

## Sources

- [Linear - Issue Status Docs](https://linear.app/docs/configuring-workflows)
- [Jira - Approval Stage Setup](https://support.atlassian.com/jira/kb/how-to-set-up-an-approval-stage-for-when-a-ticket-is-re-assigned/)
- [Spinnaker - Pipeline Stages Reference](https://spinnaker.io/docs/reference/pipeline/stages/)
- [GitHub Actions - Reviewing Deployments](https://docs.github.com/actions/managing-workflow-runs/reviewing-deployments)
- [Rootly - Incident Response Runbook 2025](https://rootly.com/blog/incident-response-runbook-template-2025-step-by-step-guide-real-world-examples)
- [FireHydrant - Turn-by-Turn Navigation](https://firehydrant.com/blog/firehydrant-tasks-provide-turn-by-turn-navigation-during-an-incident/)
- [FireHydrant - Managing Follow-Ups](https://firehydrant.com/docs/managing-incidents/adding-action-items-to-incidents)
- [Scrum.org - DoD vs Acceptance Criteria](https://www.scrum.org/resources/blog/what-difference-between-definition-done-and-acceptance-criteria)
- [AltexSoft - Acceptance Criteria Best Practices](https://www.altexsoft.com/blog/acceptance-criteria-purposes-formats-and-best-practices/)
- [GitHub Next - Copilot Workspace](https://githubnext.com/projects/copilot-workspace)
- [Cognition - Devin 2.0](https://cognition.ai/blog/devin-2)
- [Devin AI Guide 2026](https://aitoolsdevpro.com/ai-tools/devin-guide/)
- [GitHub Copilot Workspace vs Cursor vs Devin Comparison](https://agileleadershipdayindia.org/blogs/agentic-ai-sdlc-agile/github-vs-copilot-vs-cursor-vs-devin-comparison.html)
- [Claude Code - Human in the Loop](https://medium.com/@spacholski99/human-in-the-loop-where-claude-codes-autonomy-ends-and-the-architect-s-responsibility-begins-57aff6b30539)
- [Praxent - Software Handover Documentation](https://praxent.com/blog/software-handover-documentation-checklist)
- [DZone - Waste: Handoffs](https://dzone.com/articles/waste-4-handoffs)
- [Terraform - Deployment Approval Patterns](https://blog.devops.dev/implementing-manual-approval-in-github-terraform-pipelines-7c01e6946ead)
- [incident.io vs FireHydrant Comparison](https://incident.io/blog/incident-io-vs-firehydrant-slack-native-incident-management-2025)
