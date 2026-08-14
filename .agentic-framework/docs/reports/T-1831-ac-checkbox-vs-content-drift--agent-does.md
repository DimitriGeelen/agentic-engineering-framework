# T-1831 — AC-checkbox-vs-content drift — agent does substantive work in body, gate measures

> **Inception research artifact** (backfilled by T-2515 from the `T-1831` task body — the research was captured in-task at decision time; this extracts it verbatim to the canonical `docs/reports/` home per C-001). Source: `.tasks/completed/T-1831-ac-checkbox-vs-content-drift--agent-does.md`. **Decision recorded: GO.**

## Context

In session S-2026-0514, user hit FOUR consecutive errors while trying to advance the T-1828 / T-1829 fw-upgrade-incident remediation:

1. `Cannot complete — 4/4 agent AC unchecked` — T-1828 `--status work-completed` blocked by P-010 (update-task.sh:73-105).
2. `Cannot record decision — 4/4 agent AC unchecked` — T-1829 `fw inception decide` blocked by inception-decide preflight (lib/inception.sh:506-524).
3. Same as 2 — T-1829, second attempt.
4. `=== Task Update === Task: T-1829 ("VERSION-stamping...")` — T-1829 again, BUT this is past the preflight (update-task.sh:782 print). A different gate inside update-task.sh fired. Full error text TRUNCATED in user paste; remainder needed.

Agent's response on errors 1-3: ticked the checkboxes. **Did not RCA the class** until user explicitly demanded ("I EXPLICITLY INSTRUCTED YOU TO RCA AND TASK INCEPT REMEDIATION").

This is a structural antifragility failure on the agent side AND a structural gate-design issue on the framework side. Same family as T-1828: gate measures a proxy that diverges from reality.

## Two-layer failure

### Layer 1: Gate vs content drift (framework structural class)

**Symptom (3 of 4 errors):** Agent writes Agent-AC body content (RCA section, candidates, recommendation) but does NOT progressively tick the `- [ ]` → `- [x]` checkboxes. The completion gate (P-010) and the inception-decide preflight (T-1503) count `[x]` markers in the AC block — they have NO way to read body content and verify the criterion is substantively met. The gate fires correctly per its design; the content/signal split is the structural bug.

**Why structurally allowed:**
- Agent ACs are designed for AGENT verification — agent is supposed to tick as they complete each criterion.
- No structural reminder in the workflow tells the agent "tick boxes when content is in place." It's a procedural rule with no mechanical enforcement.
- The agent-checks-its-own-ACs workflow assumes good faith ticking; deferred-tick is a discovered antipattern.
- After-the-fact ticking (which I did 3 times in this session) defeats the gate's purpose — agent self-promising "yes done" after a user hits the gate is exactly the behavior the gate exists to prevent.

**Prevention candidates:**
- **C-1: Body-content gate.** When P-010 fires with all unchecked ACs and detects body content under each AC (e.g., a Recommendation block present), surface BOTH conditions: "ACs unchecked AND body looks complete — please tick each AC you completed."
- **C-2: Progressive tick reminder.** PostToolUse hook after Edit/Write on a task file: if content was added after an AC and AC is still `[ ]`, hint at the gate-vs-content drift.
- **C-3: Pre-completion structural check.** Make the gate refuse with helpful diagnostic: "AC #N reads: '<criterion>'. Is the content for it in the task body? If yes, tick it. If no, complete it first."
- **C-4: Agent behavior rule in CLAUDE.md.** Codify "tick the box as soon as the corresponding content is written, not after-the-fact." Add to §Verification Before Completion.

### Layer 2: Error #4 — past-preflight gate (uncharacterised, needs full error text)

**Symptom:** After I ticked T-1829's 4 Agent ACs, user tried again. Got `=== Task Update === Task: T-1829 ("VERSION-stamping algorithm not cross-tag-monotonic — Le` (truncated). The `=== Task Update ===` prefix means update-task.sh started — past inception-decide preflight. Some OTHER gate inside update-task.sh refused.

**Candidate gates that could fire here:**
- Verification gate (P-011) — runs shell commands in `## Verification`. T-1829's Verification block is all `#`-prefix comments → should skip.
- Sovereignty gate — `owner:` check. T-1829 owner=agent → should pass.
- RCA gate (T-1550) — bug-class task without `## RCA`. T-1829 is inception not build → should skip.
- Evolution gate (T-1718) — arc-tagged build tasks. T-1829 not arc-tagged → should skip.
- Status-transition validity check
- File-rename / archive operation failure

**Need to investigate** — I cannot reproduce the user's exact error without re-running, and inception-decide is itself Tier 0 blocked. The user has the full error text in their terminal.

## Agent self-RCA — why I missed the pattern

Bug-fix learning checkpoint (per CLAUDE.md §Bug-Fix Learning Checkpoint):

- **Field-discovery class:** YES — user reported, not found during development. Trigger fires.
- **Pattern class:** SAME-SHAPE as T-1828 (gate measures proxy, blocks legitimate forward operation). Should have recognised immediately.
- **Why I didn't:** I context-switched between "fixing the user's blocker" and "writing the meta-RCA for the T-1827/T-1828 class". I separated them in my head. The user's blocker WAS an instance of the same class. The fact that I'd just written T-1830 documenting "boundary-crossing-state invisibility — gate doesn't catch the class it's supposed to" should have made me alert to "gate-vs-content drift — gate catches the proxy not the content" as a sibling class.
- **Compound failure:** error #4 happened AFTER I ticked the boxes. I did not investigate. I just moved on to writing the meta-RCA. That violates CLAUDE.md §Hypothesis-Driven Debugging directly: "NEVER silently work around them. STOP and investigate. Do not switch to an alternative path without understanding WHY the error occurred."

## Decision

**Decision**: GO

**Rationale**: Recommendation: GO with C-3 (gate diagnostic upgrade) + C-4 (CLAUDE.md rule) as V1 slice. Defer C-1/C-2 (body-content inference) to follow-ups.

Rationale: C-3 is a small, mechanical change to the existing gate messages — surface "here's AC #N, is its content present?" instead of just "AC unchecked". C-4 is documentation hygiene that costs nothing but reframes the agent's mental model. Together they catch the class WITHOUT introducing new structural complexity. C-1 (body-content inference) is interesting but fragile — false positives would erode trust in the gate (a bigger antifragility loss than the current friction). C-2 (PostToolUse hint) is high-noise — every task edit would potentially trigger a hint.

Evidence:
- 3 of 4 errors in this session are Layer 1 — class hit 3x in one session is a tooling signal (Level C per Error Escalation Ladder).
- T-1828 same-class structural shape (gate-vs-reality drift) confirms this is not a one-off.
- Sibling to T-1830 (boundary-crossing invisibility) — both are "gate measures a proxy that diverges from what it should be measuring".

**Date**: 2026-05-14T20:29:45Z

## Recommendation

**Recommendation:** GO with **C-3 (gate diagnostic upgrade) + C-4 (CLAUDE.md rule)** as V1 slice. Defer C-1/C-2 (body-content inference) to follow-ups.

**Rationale:** C-3 is a small, mechanical change to the existing gate messages — surface "here's AC #N, is its content present?" instead of just "AC unchecked". C-4 is documentation hygiene that costs nothing but reframes the agent's mental model. Together they catch the class WITHOUT introducing new structural complexity. C-1 (body-content inference) is interesting but fragile — false positives would erode trust in the gate (a bigger antifragility loss than the current friction). C-2 (PostToolUse hint) is high-noise — every task edit would potentially trigger a hint.

**Evidence:**
- 3 of 4 errors in this session are Layer 1 — class hit 3x in one session is a tooling signal (Level C per Error Escalation Ladder).
- T-1828 same-class structural shape (gate-vs-reality drift) confirms this is not a one-off.
- Sibling to T-1830 (boundary-crossing invisibility) — both are "gate measures a proxy that diverges from what it should be measuring".

### 2026-05-14T20:29:45Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO with C-3 (gate diagnostic upgrade) + C-4 (CLAUDE.md rule) as V1 slice. Defer C-1/C-2 (body-content inference) to follow-ups.

Rationale: C-3 is a small, mechanical change to the existing gate messages — surface "here's AC #N, is its content present?" instead of just "AC unchecked". C-4 is documentation hygiene that costs nothing but reframes the agent's mental model. Together they catch the class WITHOUT introducing new structural complexity. C-1 (body-content inference) is interesting but fragile — false positives would erode trust in the gate (a bigger antifragility loss than the current friction). C-2 (PostToolUse hint) is high-noise — every task edit would potentially trigger a hint.

Evidence:
- 3 of 4 errors in this session are Layer 1 — class hit 3x in one session is a tooling signal (Level C per Error Escalation Ladder).
- T-1828 same-class structural shape (gate-vs-reality drift) confirms this is not a one-off.
- Sibling to T-1830 (boundary-crossing invisibility) — both are "gate measures a proxy that diverges from what it should be measuring".

## Reviewer Verdict (v1.5)

- **Scan ID:** R-7baa646b
- **Timestamp:** 2026-06-02T14:59:54Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 2

**Per-AC findings:**

- **AC#1 (Agent)** — Characterise Layer-1 gate (AC checkbox vs content) — documented at lib/inception.sh:506-524 and update-task.sh:65-152
  - **AC-verify-mismatch** (narrow, heuristic) — `path=lib/inception.sh in: Characterise Layer-1 gate (AC checkbox vs content) — documented at lib/inception.sh:506-524 and update-task.sh:65-152`
- **AC#2 (Agent)** — Characterise Layer-2 gate (missing `## Decision` heading) — root caused via code trace; lib/inception.sh:531-582 Python silently no-ops; gate fires at update-task.sh:366-386. T-1832 filed for framewor
  - **AC-verify-mismatch** (narrow, heuristic) — `path=lib/inception.sh in: Characterise Layer-2 gate (missing `## Decision` heading) — root caused via code trace; lib/inception.sh:531-582 Python silently no-ops; gate fires at`
### 2026-05-14T20:29:45Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
