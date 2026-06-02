# T-2181: RCA + structural fix — bare-path review links in chat output

**Status:** inception — research artifact (C-001), updated incrementally
**Date opened:** 2026-06-02
**Predecessor:** T-2030 (GO Candidate C) → T-2138 (RCA recurrence) → T-2139 (transition gate) → T-2140 (reviewer detector)
**Origin incident:** 2026-06-02 S-2026-0602-2106+ — agent's session-summary table emitted
`/review/T-2174` etc. as bare paths despite three sibling memories explicitly forbidding it.

## Problem statement

When the agent hands work to the operator for [REVIEW], the rule (codified across
[[feedback_review_concrete_links]], [[feedback_handoff_url_per_class]],
[[feedback_human_review_links]], [[feedback_use_fw_task_review]]) is: emit **full
clickable URLs** like `http://192.168.10.107:3000/review/T-XXXX`, NOT bare paths like
`/review/T-XXXX`. Bare paths force the operator to construct URLs by hand, remember
the per-project port, or scroll back to find one.

T-2030 shipped the structural net for **file artifacts**:

| Surface | Mechanism | Status |
|---|---|---|
| Task `## Recommendation` Evidence URLs | `lib/review.sh` validates against `app.url_map` at `fw task review` time | shipped (T-2030 GO) |
| Task Human-AC `**Steps:**` URLs | Same `lib/review.sh` validation | shipped (T-2030 GO) |
| Reviewer static scan on task bodies | `review-link-homework` catalogue entry | shipped (T-2140) |
| Transition-time blocking | Gate at `--status work-completed` | shipped (T-2139) |

**The gap:** Agent chat output (session summary tables, mid-thread responses, hand-off
prose) is ephemeral — there is no file artifact for any of these hooks to scan. The
2026-06-02 regression hit precisely there.

## 5-Whys

1. **Why** did the agent emit `/review/T-2174` instead of `http://192.168.10.107:3000/review/T-2174`?
   Because in a "final session summary" markdown table, brevity reflexively wins —
   bare paths render visually shorter and feel more uniform in a `| Task | Link |` column.
2. **Why** didn't any memory catch this?
   Memories are *advisory*, not enforcing. The three sibling memories tell the agent
   what to do — but the agent doesn't pre-flight its own draft response against the
   rule before sending.
3. **Why** doesn't an enforcement hook catch this?
   All four T-2030 hooks (lib/review.sh, reviewer scan, transition gate, audit) scan
   **file content on disk** — task body, recommendations, handovers. Agent chat output
   is not on disk. It enters the transcript JSONL only after the message is sent and
   the user has seen it.
4. **Why** can't a hook see chat output mid-stream?
   Claude Code's hook events: PreToolUse, PostToolUse, UserPromptSubmit, Stop,
   SessionStart, PreCompact. None of these fire on assistant-message tokens during
   streaming. `Stop` fires AFTER the assistant turn completes — too late to prevent
   what the operator has already read, but in time to log + warn at next prompt.
5. **Why** has T-2030's structural fix held for file artifacts but not chat?
   Because the assumption baked into T-2030's scope ("scope to Watchtower URLs in
   Recommendation Evidence + Human AC Steps") was that hand-offs happen via task
   files, which `fw task review` then renders into chat. The 2026-06-02 incident
   shows hand-offs also happen **directly in chat** as session-summary tables,
   bypassing `fw task review` entirely. The agent shortcuts the helper when it has
   multiple tasks to surface — exactly when violation likelihood is highest.

**Root cause:** Chat output is the only hand-off surface T-2030 did not gate. The
fix-ladder needs a chat-surface coverage extension. Memory-as-advisory cannot
substitute for structural enforcement (CLAUDE.md "Structural enforcement over
agent discipline").

## Candidate analysis

### Candidate A — Stop-hook post-turn scanner

**Mechanism:** Add a `Stop` hook in `.claude/settings.json` that reads the just-completed
assistant turn from the session JSONL, greps for chat-side patterns (`(?<!http[s]?://[^/\s]+)/(review|inception|approvals|arcs|gaps|fabric|cockpit|settings)/T?-?[\w-]+` in bullet/cell positions), and writes a warning to `.context/working/.bare-path-violations.yaml`. A `UserPromptSubmit` hook reads that file on the next turn and injects a `<system-reminder>` block flagging the prior violation. The detection is in the agent's next conversation slot, so the agent learns at the earliest possible moment **after** emission.

**Pros:**
- Reuses existing Claude Code hook contract (Stop + UserPromptSubmit already wired for other features).
- Zero impact on file-artifact workflows; only ADDS coverage.
- Per-violation feedback at next prompt = fast feedback loop (sub-minute).
- Self-clearing: once warning is shown, the YAML entry is consumed.

**Cons:**
- Catches the violation **after** emission — operator has already seen the bare paths once.
- False positives possible on prose like "the `/review/<id>` route" (used as a code/path reference, not a clickable link). Mitigation: require the regex match to appear in a `^\s*[-*|]` line context (markdown list / table cell), not mid-sentence.
- Requires `Stop` hook to access the transcript file — Claude Code passes session JSONL path via hook input, so feasible.

**Evidence-of-working test:**
- Hook bats test: synthesise a `transcript.jsonl` with a bare-path table, run the Stop hook script, assert `.bare-path-violations.yaml` gets a new entry.
- Hook bats test: synthesise the UserPromptSubmit injection; assert the next prompt's stdout contains the warning block.
- E2E manual: write a chat response with `/review/T-XXX`, send, observe at next user prompt the system-reminder fires.

**Evidence-of-not-breaking test:**
- Existing Stop hook handlers preserved (`agents/context/post-stop-handover.sh` if any). Check `.claude/settings.json` Stop array length unchanged or +1.
- `.context/working/.bare-path-violations.yaml` lives in `.context/working/` — does not collide with any existing state file (verify with `ls -la .context/working/ | grep bare-path`).
- The bats simulation T-1633 `tests/unit/upgrade_fresh_machine_simulation.bats` must remain green (consumer-fresh test) — the new hook script lives in `agents/context/`, picked up by `fw upgrade` rsync.
- `bin/fw doctor` enforcement-baseline (L-398) refreshed via `bin/fw enforcement baseline` after hook insertion.
- 30 most recent assistant turns in the transcript: dry-run the scanner against them, count FPs, target <5% FP rate before shipping.

### Candidate B — Session-capture-time scan

**Mechanism:** Extend `agents/session-capture/` to scan the transcript JSONL for chat-side bare-path patterns when the session ends. Findings get logged to the handover file. Next session's SessionStart:resume hook surfaces them.

**Pros:**
- Reuses existing session-capture machinery; no new hook event.
- Captured as part of normal session-end discipline.

**Cons:**
- Feedback is delayed until next session — could be hours/days. Long feedback loop.
- Catches at session end, by which time the agent has emitted MANY bare paths potentially.
- Doesn't help operator within the active session (still has to manually verify URLs).

### Candidate C — `fw task review-batch` helper + CLAUDE.md ladder rule

**Mechanism:** Add `fw task review-batch T-A T-B T-C` that emits a markdown-formatted
table:

```
| Task | Link |
|------|------|
| T-A  | http://192.168.10.107:3000/review/T-A |
| T-B  | http://192.168.10.107:3000/review/T-B |
| T-C  | http://192.168.10.107:3000/review/T-C |
```

Plus add a CLAUDE.md §Presenting Work for Human Review rule: "When summarising N
review handoffs in chat, you MUST use `fw task review-batch` and paste its output
verbatim. Hand-typed tables are forbidden."

**Pros:**
- Lowers cost of doing the right thing below the cost of doing the wrong thing —
  the table comes pre-formatted.
- No new hook plumbing; pure tooling + docs.
- The helper output IS the structural enforcement (agent quotes it verbatim).

**Cons:**
- Discipline-based: agent must remember to invoke the helper.
- Doesn't catch the case where agent forgets and types the table by hand.
- Single-task hand-offs (the more common case) still need the regular `fw task review`.

### Candidate D — Combine A + C

**Mechanism:** Ship Candidate C (the helper) as the cheap-and-easy path, AND
Candidate A (the Stop-hook scanner) as the structural backstop. C reduces the
likelihood of regression; A catches what slips through.

**Pros:** Layered defence. Easy path + structural net. Maps to the T-2030 architecture
(documentation + tooling + hook).

**Cons:** Two slices of work, not one. Higher build complexity. But each slice is small
and independently testable.

### Recommendation (preliminary — pending operator GO)

**GO — Candidate D (A + C combined).**

Candidate A alone catches regressions but doesn't reduce their rate. Candidate C alone
relies on agent discipline that we've seen fail. Together: C cuts the regression rate
by making the right thing easy; A catches the residual.

Build slices proposed:
- **Slice 1 (Candidate C):** `bin/fw task review-batch T-A T-B …` emits a markdown table
  with full URLs. Add to CLAUDE.md §Presenting Work for Human Review.
- **Slice 2 (Candidate A):** `agents/context/post-stop-chat-scan.sh` + corresponding
  UserPromptSubmit injector. Wire into `.claude/settings.json` Stop + UserPromptSubmit
  arrays.

**Evidence requirements per slice:**
- Slice 1: bats test asserts table shape + URL correctness; integration test where the
  agent runs the helper and pastes output, observed to match the spec.
- Slice 2: bats test for the scanner regex (positive + negative cases including the
  "code/path reference" FP exemption); E2E test where a bare-path message triggers a
  next-prompt system-reminder.

**Non-breakage requirements:**
- Existing `fw task review T-XXX` single-task flow unchanged.
- All `Stop` hooks already in `.claude/settings.json` continue to fire.
- Consumer-fresh simulation (`tests/unit/upgrade_fresh_machine_simulation.bats`) green.
- `fw doctor` enforcement-baseline refreshed.
- 30-message transcript backtest for FP rate <5%.

## Dialogue Log

### 2026-06-02 — user feedback prompted inception

- **Question/correction:** "we have to printout approval or review for [...]. We just
  recently discussed this — seems the encoding got lost or has failed. Search using
  component / context fabric tools."
- **Response:** Acknowledged regression; re-issued 4 review handoffs with full curl-verified
  URLs; updated `[[feedback_review_concrete_links]]` memory with the "session-summary
  brevity is the regression slot" lesson.
- **User course correction:** "no that is not enough I want you to RCA inception, RCA
  and devise a structural remediating fix, this must be evidenced working also be
  evidenced not to break other workflow."
- **Interpretation:** Memory update alone is insufficient — needs structural fix +
  end-to-end evidence + regression net. Opening this inception.

## Empirical evidence — detector prototype against transcript

Prototype regex run against this session's transcript JSONL (5 days, 1843 turns
containing `/review/T-` or `/inception/T-`):

- **22 flagged occurrences** of bare paths in markdown bullet/table contexts after
  stripping code blocks + inline code.
- **Zero apparent FPs** in the inspected sample — all matches were genuine bare-path
  regressions in "For your review" / "Operator-pending" sections (one from a prior
  session pre-dating this fix-track day; pattern recurs across sessions).
- Detector found my own 2026-06-02 session-summary table regression cleanly.

This empirical hit rate validates Candidate A's structural feasibility: the regex
catches the real pattern without obvious FP noise. Final FP-rate calibration belongs
to Slice 2's bats test corpus (positive + negative cases).

Regex shape (preliminary):
```
(?:^|\|)\s*[-*]?\s*(/(?:review|inception|approvals|arcs|gaps|fabric|cockpit|settings)/[A-Za-z0-9_-]+)
```
Run AFTER stripping fenced code blocks (```` ``` ````) and inline code (`` ` ``), AND only when
not preceded on the same line by `http`.

## Open questions (operator)

1. **Slice 1 vs Slice 2 priority** — if budget forces choosing one first, which does the
   operator prefer? (Recommendation: Slice 1 first — cheaper, immediate win.)
2. **FP-exemption strictness for Slice 2** — strict (only flag in `| ... |` table cells
   and `- ` bullets) or permissive (flag any bare path that *could* be a link)?
   Trade-off: strict = lower FP, higher FN; permissive = more catches, more noise.
3. **Should Slice 1 also format the agent's `fw task review T-XXX` output to include
   a "for multiple tasks use `fw task review-batch …`" hint?** Bootstraps adoption.
