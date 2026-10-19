---
id: T-4414
name: "Adopt dimitri-mint-dev's Perplexity browser seat as a standing framework capability
  (one question -> answer + sources, through the operator's own logged-in Chrome)"
description: >
  Inception: Adopt dimitri-mint-dev's Perplexity browser seat as a standing framework
  capability (one question -> answer + sources, through the operator's own logged-in
  Chrome)

status: started-work
workflow_type: inception
owner: human
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-10-19T17:16:37Z
last_update: 2026-10-19T17:19:17Z
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
  - ts: '2026-10-19T17:19:17Z'
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
---

# T-4414: Adopt dimitri-mint-dev's Perplexity browser seat as a standing framework capability (one question -> answer + sources, through the operator's own logged-in Chrome)

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

- **IW-1: Is driving the operator's logged-in Perplexity web UI acceptable under Perplexity's terms of use, or should a framework capability use the official (paid) API as a registry backend instead?**
  confidence: 1
  disposition: deferred
  rationale: An operator decision, not an agent one: the seat drives the operator's personal account through a consumer web UI, and the alternative is a paid API backend that needs operator approval per request (docs/reports/T-4414-perplexity-seat.md, gap 4). Put to the operator in the Recommendation.
- **IW-2: Is the brief screening sufficient for questions that leave the estate (hostnames, internal domains, project names, IPv6, e-mail, ports), and does it fail closed?**
  confidence: 3
  disposition: answered
  rationale: No. seat_ask.py DENY covers IPv4, credential assignments, PEM keys and four token prefixes only (seat_ask.py.txt:29-34), and a missing SEAT_DENY_FILE silently falls back to the defaults (:43-48). The sender confirmed it (msg 6e0622a6). The AEF version needs a seeded estate deny list and fail-closed loading.
- **IW-3: Where does it live and who consents: one seat per operator plus a request path, consent recorded where the operator clicks?**
  confidence: 2
  disposition: answered
  rationale: One seat per operator plus a TermLink/sidecar request path (the login is per operator and per desktop). Consent is recorded where the operator clicks (Watchtower approval or fw review approve, like paid proposals), never relayed by a peer message.
- **IW-4: Generic browser-seat core with per-site adapters and a page-drift self-test, or a Perplexity-only tool?**
  confidence: 2
  disposition: answered
  rationale: Start with one adapter and extract a core only when a second seat exists. The drift self-test (seat_ask.py --check) belongs in a canary, not in fw doctor, which must not reach the internet.

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

GO, with conditions, after reading all three files (verbatim in docs/reports/T-4414-inputs/, artefact docs/reports/T-4414-perplexity-seat.md).

The seat is carefully built:
- dedicated profile kept out of git;
- CDP on loopback only, actively checked;
- never root;
- stops at every login, captcha or check, with no retry;
- one page per question.

The AEF version reuses it as is, opt-in, and adds:
- a fail-closed brief screen with a seeded estate deny list (hostnames, domains, project names, IPv6, e-mail, more token formats);
- consent recorded where the operator clicks;
- a record of which account answered;
- a drift canary.

**One choice is the operator's:** whether driving the consumer web UI under the operator's own account is acceptable. The alternative is the official Perplexity API, registered as a paid backend with per-request approval. If the operator prefers the API, the recommendation becomes NO-GO for the seat and GO for that backend.

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

<!-- Filled at completion via: fw inception decide T-XXX go|no-go --rationale "..." -->

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-10-19T17:19:17Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
