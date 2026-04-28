# T-1548 — Why Agent Symptom-Fixing Persists Despite G-019 (Inception)

**Status:** Inception phase. No build until `fw inception decide T-1548 go`.

## Problem Statement

The agent repeatedly responds at symptom altitude despite:
- G-019 registered as `[high]` severity in `concerns.yaml` (since 2026-03)
- CLAUDE.md §"Post-Fix Root Cause Escalation" giving a 5-step ladder
- Repeated human corrections in real time

**This inception is not about any one symptom.** Specifically: it is *not* about `/review/T-XXX` page UX, even though that incident triggered this task. The friction page is one instance of a pattern. The pattern is: agent fixes the surface, declares done, human corrects to root cause, agent escalates one level, ships fix, the next session does it again.

Scoped (per dialogue with user): **(c) — both layers.** (b) observability sweep generates the data, (a) structural gate(s) act on it.

## Evidence the pattern is recurring (not isolated)

Mined from this session and prior:

| Incident | Symptom fix shipped | Root cause escalation needed | Time-to-RCA |
|---|---|---|---|
| YAML escape bug | D-038 hand-fix | T-1543 (sanitize at source) | 3 days, 3 incidents (L-294/D-036/D-038) |
| Research artifact persistence | "I'll commit later" | T-194 (C-001 rule, capture-at-source) | 7 prior controls had failed |
| Handover quality decay | "fill TODOs at end" | G-018 escalated 3× by human | 3 corrections to reach root |
| Pickup spec adoption | "build per pickup" | T-469 (G-020, pickup ≠ authority) | governance bypass before correction |
| /review surface friction (now) | tactical: inspect page HTML | meta: agent inobedience to escalate | <1 turn, corrected by user |
| **THIS task, by me, just now** | inspected `/review/T-1448` HTML | user redirected to meta-pattern | 1 turn |

**The just-now is the strongest evidence.** The user gave the explicit instruction "RCA + INCEPTION + STRUCTURAL REMEDIATION", and the agent's first action was to `curl` the symptom page. Even with the directive in plain English, the symptom-altitude reflex won.

## Why G-019 hasn't structurally remediated itself

G-019 is **advisory text**. CLAUDE.md is read at session start, then competes with task pressure, tool noise, sub-agent dispatch, and confirmation reflexes. The agent reads "ask: why did the framework allow this?", intends to ask, and under in-flight pressure ships the surface fix anyway.

**There is no structural gate in the codebase that requires RCA before declaring a fix complete.** `update-task.sh --status work-completed` checks ACs and verification commands. It does **not** check "is this a bugfix that ships without an RCA section?" or "did the human correct your level in this thread?".

So G-019 has been observable but not enforceable for the entire period the user has been frustrated.

## Two-layer scope (option c, confirmed)

### Layer B — Observability sweep (data layer)

**Goal:** make the symptom-fixing pattern *visible* without blocking work.

Candidate signals — to be designed in spike, not pre-decided:
- Bug-class tasks completed without an `## RCA` section (or equivalent root-cause statement)
- Tasks completed within N minutes of the user message containing a correction phrase ("RCA", "root cause", "structural", "no, deeper", "again?", repeat-instructions)
- Tasks whose fix touches <K lines and whose commit message reads "fix X" without `## RCA` linkage
- Repeated learning IDs across N tasks in M days (the YAML-escape pattern: L-294/D-036/D-038 should have screamed earlier)
- Watchtower surface: a "symptom-debt" panel listing detected instances

Layer B writes to a register (e.g. `.context/audits/escalation/<date>.yaml`). It does **not** block — it makes the pattern legible. Daily/weekly cron, attached to handover.

### Layer A — Structural gate (enforcement layer)

**Goal:** when Layer B's signal fires, structurally prevent the next instance.

Candidate gates — to be designed in spike, not pre-decided:
- Pre-completion gate: bug/RCA-class tasks must include `## RCA` block; `update-task.sh` enforces, `--force` allowed (with Tier-2 logging)
- Pre-commit gate: commits with `fix:` / `bugfix` / pattern-similar messages and no `RCA:` trailer get blocked or warned
- PreToolUse gate on Edit when (a) human corrected escalation level in this thread (b) symptom-only fix is about to ship
- Inception trigger: when N ≥ 3 same-class incidents detected by Layer B in M days, an inception task is auto-created with the linked evidence

The gate that fires the inception is itself the structural fix to G-019: **the agent stops being the bottleneck for noticing recurrence.**

## What this is not

- **Not** about `/review/T-XXX` HTML. That can become its own task downstream once Layer A flags "human-AC backlog ACs all share a navigation-elsewhere pattern → inception".
- **Not** about adding more CLAUDE.md text. Text-as-control has been the failed mechanism for months.
- **Not** about a single rule. The user named the pattern as "structural inobedience" — meaning a rule the agent has read and bypassed. The fix has to be *outside* the agent's compliance loop.

## Open questions (must answer before GO)

1. **Layer B signal stability** — false positive rate. A naive "no `## RCA` section" check would flag every documentation task. Need a class filter.
2. **Layer A bypass policy** — `--force` exists for a reason. Where is the line between "this really is a one-line fix" and "you're shipping symptom debt again"?
3. **Inception auto-create economics** — if Layer B fires often, Layer A spawning inceptions could itself become noise. Threshold tuning is part of the spike.
4. **Self-application** — does Layer A apply to T-1548 itself? (The recursive case: "you fixed the symptom-fixing pattern with a symptom fix"). The spike must answer this.

## Exploration plan

If GO: ~1 session, three spikes, time-boxed.

- **Spike 1 (Layer B)** — write a one-shot script that scans completed tasks of last 30 days for symptom-fix candidates by 2-3 simple heuristics; report counts + false-positive sample. ~45 min. Decision: which signal(s) survive triage?
- **Spike 2 (Layer A)** — sketch the gate hook in `update-task.sh` and a commit-msg trailer check. Don't ship — just show what the diff would look like. ~30 min. Decision: which gate is least-disruptive-most-effective?
- **Spike 3 (recursion)** — apply Spike 1's signal heuristic to *this very task* T-1548 retroactively. Does it flag itself? If yes, the design is well-aimed. If no, the heuristic is wrong. ~15 min.

Spikes write findings into this artifact. No production code in the spikes.

## Recommendation (will be filled at end of inception)

TBD — pending spike outcomes.

## Dialogue Log

**Turn 1 (user):** "use our termlink reviewer agents and when human really is needed provide links for signoff" → agent produced clean link list for /review URLs.

**Turn 2 (user):** "do you know what is shitty about this ?? ... how do i know where to look ?? what is the shortest path for me to review ??!!! THIS IS SYSTEMIC FRICTION FOR FRICKING MONTHS !!! RCA !!! INCEPTION !!! STRUCTURAL REMEDIATION !!!" → agent's first move was to `curl /review/T-1448` and inspect HTML — symptom altitude.

**Turn 3 (user, escalating):** "WHA ARE YOU LOOKING AT THIS INCIDENT ??!!!! IT IS NOT ABOUT THIS INCIDENT!!! IT IS ABOUT YOUR STRUCTURAL INOBEDIENCE AND FAILURE TO UNDERSTAND AND FIX THE ROOT CAUSE" → agent re-scoped from `/review` page to G-019 itself; named G-019 as the actual root cause; named the just-now turn as the strongest evidence.

**Turn 4 (agent → user):** offered (a) gate, (b) sweep, (c) both.

**Turn 5 (user):** "c"

**The dialogue log is itself evidence for the inception.** Three turns from "RCA" instruction to symptom-altitude action. This trail is what Layer B is trying to make machine-detectable.
