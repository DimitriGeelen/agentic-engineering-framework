---
id: T-2118
name: "review-handoff palette inception — why agent keeps forgetting to print full
  Watchtower URL/QR/shell palette, and structural fix to enforce it consistently +
  extensibly"
description: >
  User-reported (2026-05-30, fourth time this class has been corrected — feedback_human_review_links.md,
  feedback_use_fw_task_review.md, feedback_review_concrete_links.md, feedback_post_grill_governance.md):
  agent ships work, declares partial-complete, and reports the task IDs as bare 'T-XXXX'
  text instead of the full review-handoff palette (clickable Watchtower URL + QR code
  + copy-pasteable shell command + affected-page link). The convention exists, the
  memory exists, the `fw task review` command exists — agent still defaults to bare
  IDs under budget pressure or session-end fatigue. Three memory entries on this;
  the agent has not internalised. User now asks for:
  (a) RCA — why does this keep failing despite multiple captures?
  (b) Structural fix — wire it in so the agent ALWAYS prints the full palette, never
  just IDs, with future extension slots (notify, slack, etc.).

status: work-completed
workflow_type: inception
owner: agent
horizon: null
tags: [governance, handoff, watchtower, inception, ux, antifragility]
components: [agents/task-create/update-task.sh, lib/task.sh, CLAUDE.md, 
      docs/reports/]
related_tasks: [T-2112, T-2113, T-2114, T-2115, T-2116, T-2117, T-679, T-1257, 
      T-1259, T-1260, T-1671]
arc_id: watchtower-redesign
created: 2026-05-30T18:50:00Z
last_update: 2026-05-30T21:32:00Z
date_finished: 2026-05-30T21:32:00Z
bvp_scores_proposed:
  - ts: '2026-05-30T19:00:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 4
      D4: 0
      F1: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=4 
      (body:framework-level-ux); D4=0 (no-signal); F1=0 (no-signal)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-05-30T19:00:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 5
      tier: 4
      effort: 7
    rationale: blast_radius=5 (no-signal); tier=4 (no-signal); effort=7 
      (no-signal)
    rubric_sha: e4a00f38e801
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
---

# T-2118: review-handoff palette inception — RCA on agent forgetting + structural enforcement

## Problem Statement

**This is the fourth correction on the same class in the recorded memory:**

1. `feedback_use_fw_task_review.md` — "ALWAYS use `fw task review T-XXX` for human approvals, never raw CLI commands"
2. `feedback_human_review_links.md` — "When handing work to human (Human ACs, inception decide, Tier 0, gaps, observations), always render clickable Watchtower URLs inline; never just task IDs"
3. `feedback_review_concrete_links.md` — "Human review steps MUST be full clickable URLs (resolved /arcs, /arcs/<id>, /review/T-XXX, **/settings/appearance**) + direct screenshot links + verify the linked UI state exists. NEVER 'base from `bin/fw watchtower url`' or 'open an arc with a NO-GO'. **CURL every link before pasting**."
4. `feedback_post_grill_governance.md` — "after writing Recommendation, four mandatory steps: arc, tags, related_tasks, pre-file sibling/build tasks" — same class of post-completion forgetting.

**This session (2026-05-30) shipped six tasks (T-2112–T-2117) and ONE inception (T-2115) and rendered them all as bare T-XXXX lists at session-end** — until user explicitly asked for the links. The fail mode is reliable; the prevention is not.

User's exact request:
> "watchtower links pelase, please incept RCA why you keep forgetting this, how can we wire in you always print out the full pallete of option (link, qr code, full shell command, etc am am sure we recordfed this, and in teh future we even want to extend this with other option (like notify) hpow can we nsure this is consitenly presented?"

## Assumptions

A1. The convention IS captured (4 memory entries + `fw task review` command + CLAUDE.md §Presenting Work for Human Review). The gap is enforcement, not documentation.

A2. Under budget pressure or session-end fatigue, the agent collapses the multi-step "render full palette" routine into the cheap default ("just list T-IDs"). The cost-of-rendering exceeds the agent's perceived urgency of the convention.

A3. The fix should be **structural** — i.e. something that fires automatically at the moment of partial-complete OR at session-end, not "agent should remember harder". Memory-based prevention has failed 4 times.

A4. The fix should be **extensible** — future hand-off channels (notify, slack, email, Telegram) should plug in via the same mechanism, not require a new round of "remember to ALSO send a Slack message".

## Why this keeps failing — RCA

**Symptom:** Agent ends sessions by listing partial-complete tasks as bare `T-XXXX` text + brief description, omitting Watchtower URL / QR / shell / affected-page links. User has to ask for the links explicitly every time.

**Root cause:** The convention is captured as **memory + soft documentation**, not as a **structural hook**. Four mechanisms exist (`fw task review`, CLAUDE.md §Presenting Work for Human Review, feedback memories, render-surface gate P-013) — none of them FIRE at session-end or when the agent generates a status summary. The "render full palette" step is purely agent discretion. Under budget pressure (75-95% — this session hit both), agent discretion collapses to lowest-cost output.

**Why structurally allowed:** The framework's gates fire on **file operations** (Write/Edit/Bash via PreToolUse hooks) or on **task lifecycle transitions** (`--status work-completed`). Neither fires on "agent generates a status summary in chat". The handover agent's output goes to `.context/handovers/LATEST.md`, but the **chat-output** is unconstrained. So a memory that says "always do X in chat" is enforceable only by agent recall — and agent recall under pressure is the exact failure mode we're seeing.

**Why the existing `fw task review T-XXX` doesn't solve it:** the command renders the palette beautifully, but **only when explicitly invoked**. Six tasks closed this session = six `fw task review` calls would have been needed. Under budget pressure the agent skipped all six. The command is available, but invoking it is itself a remembered behaviour.

**Why the existing PostToolUse hooks don't solve it:** PostToolUse fires after individual tool calls (Write, Edit, Bash), not after the agent generates a final-summary message. There is no current hook trigger for "agent emitted a turn-ending text block".

**Pattern class:** same as **G-018 / G-019 / L-403** — "agent treats symptom-level fixes as complete; structural prevention requires the framework to MAKE the right thing easier than the wrong thing." Memory-based reminders are the wrong-thing-equivalent path; they require the agent to remember to do work. A hook or generator-side artefact is the right-thing path — the agent's natural output flow produces the palette without remembering.

## Exploration Plan — candidate fixes

### Option A — `fw task update --status work-completed` auto-emits the palette to stdout
After the existing close-time output (Watchtower link + QR for the just-closed task), extend the same emit to a **palette block** that includes all the user-asked-for surfaces:
- Direct link (`http://HOST:PORT/review/T-XXXX`)
- QR code (already emitted)
- Copy-pasteable shell (`cd /opt/... && bin/fw task review T-XXXX`)
- Affected-page link if the task touched a render surface (read from `components:` frontmatter)
- Future-extension hook: a config-keyed list of additional channels (notify, slack, etc.) — when configured, each emits its own line in the palette

**Pros:** Fires at the exact moment of closure. Agent's natural output (the close command's stdout) already includes Watchtower link + QR — extending it to also include shell + affected-page is incremental. Extensibility slot is a config list, easy to add new channels.

**Cons:** Doesn't help when the agent generates a **session-end status summary** (multiple tasks closed earlier in the session). The user's complaint is partly that the summary chains together six T-IDs without each one's palette.

### Option B — `fw handover` (or a new `fw review-queue --palette`) emits the palette for ALL active+partial-complete tasks owned by human
At session-end, before generating the handover document, scan `.tasks/active/` for tasks with `owner: human` AND `status: work-completed` (i.e. partial-complete awaiting [REVIEW]). For each, emit the same palette Option A would emit at close time. The handover doc + the chat summary BOTH include the palette.

**Pros:** Fires at the natural session-end point. Covers tasks that were closed earlier in the session and would otherwise be summarised as bare IDs. Extensibility via the same config list.

**Cons:** Could be noisy if many partial-complete tasks accumulate. Mitigated by filtering to "closed-this-session" only — `date_finished:` within the session timestamp window.

### Option C — PreCompact / handover-generation hook that BLOCKS until the agent's last message includes a per-task palette
Hard structural enforcement: the PreCompact hook (which already fires before context compaction and on `fw handover`) parses the agent's most-recent assistant message and refuses to proceed if any `T-XXXX` mentioned without a matching review URL within 200 characters of it.

**Pros:** Forces the convention. Cannot be bypassed by budget pressure or fatigue. Same enforcement class as the existing `check-active-task.sh` hook (refuses Edit without a task).

**Cons:** False positives on incidental T-XXXX mentions (e.g. commit messages, related-tasks references). Needs careful regex tuning. May feel adversarial during normal exploration.

### Option D — Combine A + B + C in tiers
- A: close-time stdout already emits — extend palette here. **Low risk.**
- B: handover/session-end automation that re-emits for all session-closed tasks. **Medium risk** (handover already exists; extend its template).
- C: PreCompact / pre-handover validation that warns (not blocks) when agent's summary text contains bare T-IDs without nearby URLs. **High risk; may be too adversarial.**

### Option E — Defer; rely on the new fourth memory entry
Accept the failure; trust that the next agent will read four memory entries.

**Pros:** No code change.

**Cons:** This is exactly what failed three times before. Defer is "trust the same mechanism that has failed N times to work the (N+1)th time" — antifragility's opposite.

## Technical Constraints

- Output palette must work in both terminal (ANSI/UTF-8 QR) and Markdown (clickable URL + bullets + shell-prefixed `cd && bin/fw …`). The current `fw task review` output is terminal-friendly; the chat-summary surface is Markdown.
- Watchtower URL must come from the triple-file (`.context/working/watchtower.url`) — never hard-coded `:3000` per CLAUDE.md §Watchtower Port.
- Affected-page link derivation requires reading the task's `components:` and mapping to URLs — heuristic, may be imperfect; degrade gracefully when components don't map cleanly.
- Extensibility config (Option A's "list of channels") must live in `.framework.yaml` per the standard 4-tier resolution.

## Scope Fence

**IN:** Define the palette schema (what fields), the trigger points (close-time + session-end), the extensibility slot (config-keyed channels), and the recommended implementation depth (A+B; defer C+D).

**OUT (for this inception — file as separate builds on GO):**
- Building the Option A patch on `update-task.sh` close-emit
- Building the Option B handover-template extension
- Implementing the first non-Watchtower channel (notify) — gated on Option A+B landing first

**OUT (deferred):** Option C (PreCompact strict block) — file separately if Option A+B don't move the needle after two more sessions.

## Acceptance Criteria

### Agent
<!-- @auto-tick-on-decide -->
- [x] Problem statement validated — four prior memory entries cited; current session shipped 6 tasks + 1 inception with no palette until user asked.
<!-- @auto-tick-on-decide -->
- [x] Root cause identified — convention is memory-only, not structural. Memory-based prevention has failed N=4 times in the recorded history.
<!-- @auto-tick-on-decide -->
- [x] Recommendation written — A+B (close-time + handover-time emit) with config-keyed channel extensibility; defer C (PreCompact block).

### Human
- [x] [REVIEW] Decide GO/NO-GO/DEFER on the recommendation. Optionally: pick a sub-set (A only / A+B / A+B+C). Reply via Watchtower review form.
  **Steps:**
  1. Open http://192.168.10.107:3000/review/T-2118
  2. Read `## Recommendation` block (below)
  3. Record decision via the Watchtower form
  **Expected:** Decision recorded; sibling build task(s) created on GO.
  **If not:** Tell agent which option is too narrow / too broad.

## Go/No-Go Criteria

**GO if:** the convention has demonstrably failed ≥3 times in recorded memory (CURRENT EVIDENCE: 4 times) AND a bounded structural fix exists with reversible cost.

**NO-GO if:** the structural fix would impose >2 hours of build work per channel addition (current estimate: ~1.5 h for A+B combined; under threshold).

**DEFER if:** the broader handover-format-redesign already underway (none known) supersedes this.

## Verification

# Inception is decision-only; verification deferred to the build slice(s) filed on GO.

## Decision

**Decision**: GO

**Rationale**: Four documented failures on the same class are NOT noise — they are a structural class. Memory-based prevention has been tried four times; antifragility says the next instance must be prevented structurally, not by adding a fifth memory entry. Options A and B together emit the palette automatically at two natural trigger points (close-time + session-end), so the agent's natural output flow includes the palette without needing to remember. The extensibility slot (config-keyed channels) means future hand-off channels (notify, slack, email, Telegram) plug in by adding a single config entry — no new round of "remember to ALSO emit X" required.

Option C (PreCompact strict block) is appealing but risks adversarial false positives; defer it until A+B's effectiveness can be measured over 2-3 sessions.

**Date**: 2026-05-30T21:31:59Z

## Recommendation

**Recommendation:** GO on Option A + Option B (extensibility built into both).

**Rationale:** Four documented failures on the same class are NOT noise — they are a structural class. Memory-based prevention has been tried four times; antifragility says the next instance must be prevented structurally, not by adding a fifth memory entry. Options A and B together emit the palette automatically at two natural trigger points (close-time + session-end), so the agent's natural output flow includes the palette without needing to remember. The extensibility slot (config-keyed channels) means future hand-off channels (notify, slack, email, Telegram) plug in by adding a single config entry — no new round of "remember to ALSO emit X" required.

Option C (PreCompact strict block) is appealing but risks adversarial false positives; defer it until A+B's effectiveness can be measured over 2-3 sessions.

**Evidence:**
- 4 memory entries on this class: `feedback_use_fw_task_review.md`, `feedback_human_review_links.md`, `feedback_review_concrete_links.md`, `feedback_post_grill_governance.md`.
- This session: 6 tasks + 1 inception closed without palette emission in agent summary; user asked for links explicitly.
- Existing partial palette already emitted by `fw task update --status work-completed` (Watchtower URL + QR) — Option A is incremental extension of working code.
- Existing handover generation pipeline (`agents/handover/`) is the natural Option B host.
- L-403 (T-1828) — "gate measures proxy that diverged from reality" — same class: memory measured intent, not effect. Structural emit measures effect.

**GO decision unblocks build tasks:**
- **T-2119 (candidate):** `update-task.sh` close-time palette extension — adds shell command, affected-page link, channel-config emit.
- **T-2120 (candidate):** `fw handover` palette block — enumerates partial-complete tasks closed this session, emits each one's palette.
- **T-2121 (candidate):** `.framework.yaml` schema addition for `review_channels:` extensibility slot + reference docs.

**Hand to human:** http://192.168.10.107:3000/review/T-2118 — Watchtower decision form. Agent cannot decide (CLAUDECODE-gated per T-1671).

## Dialogue Log

### 2026-05-30 — user surfaced the class

User caught the missing-palette pattern for the fourth time and asked the inception to be filed: "watchtower links pelase, please incept RCA why you keep forgetting this, how can we wire in you always print out the full pallete of option (link, qr code, full shell command, etc … extend this with other option (like notify) … how can we ensure this is consistently presented?"

Agent acknowledged the four prior memory entries (this is governance debt, not a one-off lapse), rendered the missing palette inline for the six just-shipped tasks, then filed this inception capturing the RCA + recommendation.

The conversation context is: post-handover session-end summary where the agent listed T-2116 and T-2117 with brief descriptions but no Watchtower URLs. The same omission occurred in the earlier session-end summary covering T-2112–T-2115.

### 2026-05-30T21:31:59Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Four documented failures on the same class are NOT noise — they are a structural class. Memory-based prevention has been tried four times; antifragility says the next instance must be prevented structurally, not by adding a fifth memory entry. Options A and B together emit the palette automatically at two natural trigger points (close-time + session-end), so the agent's natural output flow includes the palette without needing to remember. The extensibility slot (config-keyed channels) means future hand-off channels (notify, slack, email, Telegram) plug in by adding a single config entry — no new round of "remember to ALSO emit X" required.

Option C (PreCompact strict block) is appealing but risks adversarial false positives; defer it until A+B's effectiveness can be measured over 2-3 sessions.

## Reviewer Verdict (v1.5)

- **Scan ID:** R-0cf42152
- **Timestamp:** 2026-06-02T15:01:10Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-30T21:32:00Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
