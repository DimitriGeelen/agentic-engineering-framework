---
id: T-1499
name: "Pickup: Advies gevraagd: Ring20 hosting pattern voor Novis simulator + REST proxy (from 003-NTB-ATC-Plugin)"
description: >
  Auto-created from pickup envelope. Source: 003-NTB-ATC-Plugin, task T-045. Type: feature-proposal.

status: captured
workflow_type: inception
owner: agent
horizon: next
tags: [pickup, feature-proposal]
components: []
related_tasks: []
created: 2026-04-26T11:13:13Z
last_update: 2026-04-26T11:13:13Z
date_finished: null
source_task_id_in_origin: T-045
source_project_in_origin: "003-NTB-ATC-Plugin"
---

# T-1499: Pickup: Advies gevraagd: Ring20 hosting pattern voor Novis simulator + REST proxy (from 003-NTB-ATC-Plugin)

## Problem Statement

**Misrouted hosting-topology advice request.** The 003-NTB-ATC-Plugin consumer (T-045) emitted a pickup envelope (P-004) asking where to host two .NET Core services on Ring20 (Novis SOAP simulator + REST proxy). The envelope landed in the framework's inbox, but the framework is not the addressee — Ring20 deployment topology, registry choice, reverse-proxy routing, TLS provisioning, and identity federation all live with **ring20-management (.122)**, not with this governance project.

**Why now / why this matters:** the framework's authority is governance over agentic engineering — task gates, learning capture, episodic memory. It has zero authority over Ring20 host selection or deployment policy. Auto-creating a feature-proposal task here entered the wrong queue. Answering would require either (a) consulting ring20-management on the consumer's behalf (relay) or (b) fabricating advice the framework has no grounding for.

**Stale time-box:** envelope requested response by 2026-04-20 14:00 CET. Today is 2026-04-26. The question is six days past its window — by now the consumer has either re-routed directly to ring20-management, accepted YellowTwig Azure as the alternative, or moved on. Acting now in the framework adds noise, not signal.

## Assumptions

- **A1:** Ring20 hosting decisions are owned by ring20-management (.122), not by this framework. Falsifiable by checking authority on Ring20 fleet — confirmed: ring20-management hosts the cert/secret rotation, fleet-doctor, and deploy patterns; this repo only governs the agentic workflow layer.
- **A2:** The consumer's T-045 has progressed in six days (decision recorded directly with ring20-management OR pivoted to YellowTwig Azure). No way to verify from this side without cross-project query, but the time-box was 1 day — anything still pending here is by definition stale.
- **A3:** Re-routing this from the framework is worse than declining: framework relay adds latency, loses accountability, and pollutes governance signal with infrastructure questions. Falsifiable — but the precedent "framework is not a relay for hosting questions" preserves separation of concerns.
- **A4:** The pickup-router that auto-created this task did not check addressee semantics; any "feature-proposal" type lands here regardless of whether the framework is the right responder. (Latent gap — pickup envelopes lack a `target_project` field.)

## Exploration Plan

(No exploration warranted — this is a routing decision, not a substantive technical question this project is qualified to answer.)

## Technical Constraints

- **Authority constraint:** the framework cannot make Ring20 host selection commitments — those decisions and their consequences are owned by ring20-management. Any "advice" from here would be speculative.
- **Time-box constraint:** envelope was 1-day-bounded; six days late, the answer (if any) belongs in 003-NTB-ATC-Plugin's own decision log, not as a fresh inception here.
- **Scope-of-knowledge constraint:** this project does not maintain Ring20 fleet inventory, registry policy, Traefik routing config, or identity federation rules. Those live in ring20-management.

## Scope Fence

**IN scope:**
- Decline the request as misrouted.
- Record the latent pickup-router gap (no addressee filter) as an observation for future routing improvements.
- Suggest the consumer re-issue directly to ring20-management.

**OUT of scope:**
- Substantive hosting advice for Ring20.
- Cross-project relay to ring20-management on the consumer's behalf.
- Fixing the pickup-router today (separate concern; covered by future routing work).

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

## Recommendation

**Recommendation:** NO-GO (close as misrouted)

**Rationale:** This pickup envelope asks for Ring20 hosting topology advice (host selection, registry pattern, reverse-proxy routing, TLS provisioning, identity federation). None of those domains are owned by this framework — they live with ring20-management (.122). The framework's role is governance over agentic engineering workflows, not infrastructure decisions. Furthermore, the envelope's 1-day time-box expired on 2026-04-20; it is six days stale. Acting now would either (a) require relaying to ring20-management — adding latency and losing accountability — or (b) fabricating advice without grounding. Neither serves the consumer. The cleanest answer is to decline as misrouted and let the consumer re-issue directly to ring20-management or accept the YellowTwig Azure alternative their architect already proposed.

**Evidence:**
- Pickup envelope: `.context/pickup/processed/P-004-feature-proposal-from-ntb-atc.yaml` — addressed to "ring20-management" in the body, but routed to framework inbox.
- Time-box: envelope requested response by 2026-04-20 14:00 CET (1 day window). Today: 2026-04-26 (+6 days).
- Authority boundary: this repo's CLAUDE.md scope is task gates, learning capture, episodic memory — not Ring20 host selection.
- Latent gap: pickup envelope schema (`.context/pickup/schemas/`) has no `target_project` field, so the router cannot reject misaddressed envelopes today. Worth a separate inception if this recurs.

**Alternatives considered:**
- *DEFER pending re-route to ring20-management*: rejected — re-routing from the framework adds a hop without adding value. The consumer can address ring20-management directly via TermLink remote inject.
- *GO and answer best-effort*: rejected — the framework has no authoritative knowledge of Ring20 deployment topology. Speculative advice is worse than declining.
- *Open a new task to fix the pickup-router*: noted as latent gap, but not blocking this decision. Track separately if framework starts seeing recurrent misroutes.

**Suggested next step after NO-GO:** the consumer (003-NTB-ATC-Plugin) should re-issue the question directly to ring20-management (TermLink session on .122) or proceed with the YellowTwig Azure alternative the external architect proposed.

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
