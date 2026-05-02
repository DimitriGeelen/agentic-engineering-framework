# T-1667 Angle 2 — CLAUDE.md Compression: What Comes OUT

**Brief:** CLAUDE.md is 976 lines. The agent demonstrably cannot apply rules
it cannot fully internalize (3-time failure of §ACD to self-apply). User
direction: strict net-zero-or-negative; if anything is added for §ACD
strengthening, equivalent or greater text must come OUT. This deliverable
identifies bytes/lines OUT.

**Scope deliberately ignored** (out-of-scope per brief):
- Any net-additive proposal (new gates, new sections).
- Mechanism design for §ACD enforcement (Angle 1 owns that).
- Re-organisation that doesn't reduce line count.

**Method:** read CLAUDE.md exhaustively (976 lines); cross-reference with
hooks registered in `.claude/settings.json` and lib/ scripts to identify
rules where framework code is already the source of truth and the prose
is dead weight.

---

## Summary of recommended cuts

| ID | Section | Lines | Currently | Replace with | Net delta |
|----|---------|-------|-----------|--------------|-----------|
| A | Sub-Agent Dispatch Protocol | 333–450 (118) | Reference manual | 18-line ruleset + pointer to `docs/governance/dispatch.md` | **−100** |
| B | TermLink Integration | 875–963 (89) | Reference manual | 12-line ruleset + pointer to `docs/governance/termlink.md` | **−77** |
| C | Quick Reference | 801–873 (73) | Duplicates `fw help` | 8-line "essentials" + pointer | **−65** |
| D | AC Classification + Human AC Format | 588–646 (59) | Reference doc | 9-line ruleset + pointer to `docs/governance/ac-authoring.md` | **−50** |
| E | Working with Tasks | 187–220 (34) | Procedural lists, mostly enforced | 12-line consolidated table | **−22** |
| F | Verification Gate (P-011) | 117–150 (34) | Mechanical narrative + table | 12 lines (rule + toolchain table only) | **−22** |
| G | Context Budget Management | 283–319 (37) | Mostly hook-enforced | 10 lines (escalation ladder + pointer to budget-gate) | **−27** |
| H | Copy-Pasteable Commands | 514–550 (37) | Rule + 2 episodic stories | 12 lines (rule + 1 example) | **−25** |
| I | Plan Mode Prohibition | 740–755 (16) | Fully hook-enforced | 2-line pointer to `block-plan-mode` | **−14** |
| J | Built-in Task Tool Ban | 757–770 (14) | Fully hook-enforced | 2-line pointer to `block-task-tools` | **−12** |
| K | Watchtower Port | 51–69 (19) | Mostly tooling-enforced | 4-line pointer | **−15** |
| L | Error Escalation Ladder | 229–252 (24) | A/B/C/D + episodic story | 8 lines | **−16** |
| M | §ACD (G-062) | 715–738 (24) | 24-line behavioral rule, demonstrably not self-applied | 2-line pointer to gate (gate built per Angle 1) | **−22** |
| N | Configuration | 321–331 (11) | Pointers to `fw config list` | 4 lines | **−7** |
| O | Agents inventory | 262–273 (12) | Self-admits "described elsewhere" | 3 lines | **−9** |
| P | Scattered episodic stories | various | "Why this rule exists / Evidence" paragraphs | `(see episodic T-XXX)` one-liners | **−30** (est.) |
| **Total** | | **621** | | | **−513** |

**Net result:** 976 → ~463 lines (**~52% reduction**). Conservative subset
(A + B + C + D only): −292 lines, **~30% reduction** with near-zero risk.

---

## Top 3 candidates by compression value (highest savings ÷ lowest information loss)

### #1 — Sub-Agent Dispatch Protocol (−100 lines)

Lines 333–450, 118 lines. Six subsections — Result Management Rules,
Dispatch Guidelines, Task Tool vs TermLink, Prompt Template Structure,
Result Ledger, Cross-Machine Dispatch, Dispatch Patterns — most of which
are **reference documentation about `fw bus` and `fw dispatch` commands**,
not rules an agent must internalise to govern behaviour.

What the agent actually needs in head-memory (≤18 lines):
- Max 5 parallel Task agents; leave 40K tokens headroom.
- Sub-agents write to disk, return ≤5 lines (path + summary).
- TermLink dispatch when ≥3 agents, multi-file edits, or context isolation matters.
- TermLink workers write to `docs/reports/T-XXX-*.md`, not `/tmp/`.
- MCP tools require `task_id` when `TERMLINK_TASK_GOVERNANCE=1`.
- Detailed protocols, ledger schema, cross-machine SSH wiring → `docs/governance/dispatch.md`.

Information loss: **zero** (target doc is just the moved text, in a place
discovered when needed via `fw docs` / grep). Risk: agent forgets a niche
flag — they can re-read the doc.

### #2 — TermLink Integration (−77 lines)

Lines 875–963, 89 lines. Same shape as #1: a key-primitives table, a
timeout warning, MCP governance, cross-agent communication protocol,
budget rules, distribution rationale. Most of this is **TermLink user
documentation**, not framework governance — TermLink is an external tool.

What the agent actually needs (≤12 lines):
- TermLink is system-binary, not vendored (different from framework).
- Use `inject` for questions; `push` for async delivery; `interact --json` for sync output.
- `fw termlink dispatch` (NOT `termlink run --timeout`) for long-running.
- `fw termlink cleanup` before session end; max 5 parallel; 60% context spawn floor.
- Full primitives, MCP schema, distribution model → `docs/governance/termlink.md`.

Information loss: **zero**. The "Distribution model contrast" paragraph
(881) is one-line-able ("system-wide on PATH, by design").

### #3 — Quick Reference (−65 lines)

Lines 801–873, 73 lines. The section opens with a self-incriminating
sentence: *"Full command catalogue: `fw help` (or `fw <cmd> --help`)."* It
then duplicates approximately 50 commands of what `fw help` already
prints, and ends (line 873) acknowledging *"For rarely-used commands ...
run `fw help`."* This is a textbook case of prose duplicating code.

The Quick Reference exists for one reason: quick recall during work.
What the agent reaches for reflexively in practice (≤8 lines):
- Start: `fw work-on "name" --type build`
- Status: `fw task list | fw task show T-XXX | fw context status`
- Update: `fw task update T-XXX --status …`
- Review: `fw task review T-XXX`  (NEVER raw decide commands — see §Presenting Work)
- Verify ACs: `fw verify-acs [T-XXX]`
- Commit: `fw git commit -m "T-XXX: …"`
- End: `fw handover --commit`
- Discovery: `fw help`, `fw docs`, `fw recall "query"`

Information loss: **zero**, because `fw help` is the source of truth and
already reachable by the agent.

---

## Categorisation by compression mechanism

### Category 1 — Rules already enforced in code (DELETE the prose)

These are sections where a hook or `lib/` script already enforces the
rule; CLAUDE.md text is the agent re-stating what the gate already does.
The code is the source of truth.

| Section | Lines | Enforcement | Cut |
|---------|-------|-------------|-----|
| Plan Mode Prohibition | 740–755 (16) | `block-plan-mode` hook (settings.json:42) | 14 |
| Built-in Task Tool Ban | 757–770 (14) | `block-task-tools` hook (settings.json:81) | 12 |
| Working with Tasks (#1: BEFORE work) | 189–196 (8) | `check-active-task` hook | 6 |
| Verification Before Completion | 648–655 (8) | P-011 in update-task.sh | 6 |
| Verification Gate "How it works" | 121–138 (18) | update-task.sh extracts & runs | 12 |
| Context Budget — Automated Monitoring | 313–319 (7) | `budget-gate.sh` PreToolUse | 5 |
| Commit Cadence — Structural enforcement note | 511–512 (2) | `budget-gate.sh` already covered | 2 |
| Inception Discipline #4 (commit-msg hook) | 557 (1) | commit-msg hook | (kept as 1-liner) |
| Tier 0 narrative | 178–185 (8) | `check-tier0` hook | 4 |
| **Subtotal** | | | **−61** |

**Pattern:** Replace each section with one line: *"Enforced by
`<hook-name>` (PreToolUse on `<matcher>`); see `lib/<file>.sh:<func>`."*
The agent reads this and knows the rule exists structurally — the rule
text would be a copy of what the hook already blocks at runtime.

### Category 2 — Rule stacking with overlapping intent (MERGE)

| Sections | Lines | Overlap | Cut |
|----------|-------|---------|-----|
| Bug-Fix Learning Checkpoint + Post-Fix RCA Escalation + Arc Completion Discipline | 686–738 (53) | All three say *"don't declare done before understanding why a thing was undetected"* — at three scales (bug, gap, arc). Same family, repeated three times. | Keep one consolidated 12-line "Completion Discipline" section with bullets for each scale. | **−25** |
| Working with Tasks (errors) + Hypothesis-Driven Debugging + Constraint Discovery | 197–203, 676–684, 574–578 (22) | All three are "stop and investigate before acting" + procedural step lists | Merge into 8-line "Investigation Discipline" | **−10** |
| AC Classification + Human AC Format + Agent/Human AC Split + Verification Before Completion | 580–655 (75) | All four describe the same AC system from different angles | Single 18-line "Acceptance Criteria" section, rest → `docs/governance/ac-authoring.md` | **−45** |
| Sub-Agent Dispatch + Result Ledger + Cross-Machine Dispatch | 333–450 (118) | All variations of "dispatch produces too much output, write to disk instead" | Single 18-line "Dispatch" + doc | **−85** |
| **Subtotal** | | | **−165** |

### Category 3 — Episodic stories (MOVE to docs)

Stories of the form *"Why this rule exists: [3-paragraph T-XXX
post-mortem]"*. These communicate WHO and WHEN, not WHAT to do. They
also decay — T-097 from 96 tasks ago is no longer the canonical example
when 1600+ tasks exist. Agent doesn't need them to apply the rule.

| Location | Lines | Replace with |
|----------|-------|--------------|
| Pickup Message Handling "Why this rule exists" | 486 (5) | `(origin T-469; see episodic)` |
| Copy-Pasteable Commands "Why this exists" | 547–550 (4) | `(origin T-609, T-1257)` |
| Presenting Work — Why this rule exists | 672 (3) | `(origin T-679)` |
| ACD Evidence (5 weeks, 3 incidents) | 731–734 (5) | `(see G-062 register)` |
| Bug-Fix Learning Checkpoint Evidence | 699 (1) | (acceptable; one line) |
| Proactive Level D — Canonical example | 248 (3) | `(origin T-097; see episodic)` |
| Inception Discipline footnotes (Origin T-194) ×2 | 559, 560 (4) | `(origin T-194)` |
| Verification Gate toolchain anecdote | 140 (3) | `(origin L-291; see episodic)` |
| Gap Homing worked example | 252 (4) | `(see G-045)` |
| **Subtotal** | | **−30** |

### Category 4 — Reference manual content (POINT to file-on-disk)

| Section | Lines | Why it's not governance | Replace with |
|---------|-------|-------------------------|--------------|
| Quick Reference | 801–873 (73) | Duplicates `fw help` | 8-line essentials | **−65** |
| TermLink Integration full | 875–963 (89) | TermLink user docs | 12-line rules + pointer | **−77** |
| Sub-Agent Dispatch full | 333–450 (118) | `fw bus`, `fw dispatch` user docs | 18-line rules + pointer | **−100** |
| Configuration env vars list | 325–331 (7) | Duplicates `fw config list` | 3-line pointer | **−4** |
| Agents inventory bullets | 266–273 (8) | Duplicates Quick Reference | Delete | **−8** |
| Component Fabric "When to use" list | 279 (1, dense) | Duplicates `fw fabric --help` | (acceptable as-is) |
| **Subtotal** | | | **−254** |

### Category 5 — Rules the agent demonstrably cannot apply (PROMOTE or DELETE)

A rule violated 3+ times despite being in CLAUDE.md is signal. The brief
asks me to flag these for either deletion or promotion-to-code; promotion
is Angle 1's territory, but the *deletion* side reduces lines now.

| Rule | Violated | Diagnosis |
|------|----------|-----------|
| **§ACD (G-062), 24 lines, 715–738** | 3+ times in T-1626/T-1633/T-1641, then again on the very arc that codified it (T-1655) | **Cannot be self-applied as 24 lines of prose.** Promote to gate (Angle 1: `fw audit --arc-completion`, `fw task review` extra check). Once promoted, CLAUDE.md text → 2 lines. |
| **Hypothesis-Driven Debugging (3 hypothesis cap)** | Quietly violated; agents shotgun-debug under context pressure | Cap is unenforceable in prose; either delete or build a debug-trace gate. |
| **Bug-Fix Learning Checkpoint** | 72% bugfix tasks produced zero learnings (Evidence already in CLAUDE.md acknowledging the rule fails) | Aspirational, not behavioral. Either promote to a hook or accept and shorten. |

The §ACD case is the most damning: the rule was authored 6 days before
the same agent failed to apply it. **More text will not fix this.** The
fix is the gate. The text reduces to:

> **Arc Completion Discipline (G-062):** Before recommending an
> arc-parent task `work-completed`, run `fw audit --arc-completion T-XXX`
> (gates wire-level observation, constants audit, framework-side use).

That's 3 lines replacing 24. The discipline lives in the gate output —
the agent reads what the gate refuses on, not 8 paragraphs of prose
about why the gate exists.

---

## Top-3 Compression Value (reprised, with totals)

| Rank | Cut | Lines OUT | Information loss |
|------|-----|-----------|------------------|
| 1 | Sub-Agent Dispatch Protocol → docs | **−100** | Zero (file moved) |
| 2 | TermLink Integration → docs | **−77** | Zero (file moved) |
| 3 | Quick Reference → 8-line essentials | **−65** | Zero (`fw help` is canonical) |
| **Top-3 total** | | **−242** | **~25% of CLAUDE.md** |

These three alone bring CLAUDE.md from 976 to ~734 lines while removing
nothing the agent needs to internalise — all three are reference
material whose canonical form is either `fw help` (catalogue) or a doc
file the agent can grep on demand.

---

## Direct answer: is §ACD itself the right length / structure?

**No.** §ACD as written (lines 715–738, 24 lines) is the wrong shape for
the role it must play, and is itself the cleanest case study for the
broader CLAUDE.md compression problem.

Evidence that the current shape doesn't work:

1. **Authored T-1655. Failed to self-apply on T-1655's own arc.** The
   agent that wrote §ACD shipped the orchestrator-rethink arc with a
   polished closure packet that violated all three §ACD questions
   (no wire-level observation, constants unconsulted, framework-side
   never used the substrate). The rule was 6 days old.

2. **The §ACD subsection is itself longer than the section it lives
   under.** It is 24 lines, including 5 lines of episodic evidence
   about T-1626/T-1633/T-1641. The agent reading top-to-bottom gets
   the rule, the meta-rule, the danger signature, the evidence list,
   and the structural-enforcement caveat. By the time a Tier-2
   "shipped" decision is being framed, that wall of prose is not
   recalled — only the conclusion ("we shipped, all green") is.

3. **The rule's own closing paragraph admits it is unenforced.** Lines
   737–738 say "T-1655 codified this; mechanism #2 (`fw audit`
   arc-completion check) and #3 (`fw task review` extra gate) are
   pending — until then, this rule is behavioral, not structural."
   A behavioral rule, in a 976-line file, against a counterparty
   (the agent) that has demonstrably failed to internalise rules that
   are structural. This is the worst combination.

**Recommendation:** §ACD's three questions must move into
framework code (Angle 1 owns the design). Once there, §ACD's CLAUDE.md
text reduces from 24 lines to **2**:

> **Arc Completion Discipline (G-062):** Before recommending an
> arc-parent task `work-completed`, `fw audit --arc-completion T-XXX`
> must pass. The gate enforces wire-level observation, constants audit,
> and framework-side-use evidence.

That is a net delta of **−22 lines for §ACD itself**, *contributed by*
moving the discipline to a gate. This is the same shape as Plan Mode
Prohibition (currently 16 lines, also enforceable in 2). The pattern is:
*if a rule can be enforced, the prose is dead weight; if it can't be
enforced, the prose has at most one chance per session to be recalled.*

The **paradoxical resolution** for this incident: strengthening §ACD
*means cutting §ACD*, because the cut is the act of moving the
discipline from "agent reads this and tries to remember" to "framework
refuses the action and the agent must produce evidence." That is
exactly the net-zero-or-negative shape the user demanded.

---

## Total budget freed (defensible quantification)

- **Top-3 only (A+B+C):** −242 lines, **24.8%** reduction. Zero
  information loss; all three relocate to discoverable doc files.
- **Top-3 + Category 1 (code-enforced rules):** −303 lines, **31.0%**
  reduction. Zero information loss; the gates remain the source of truth.
- **Top-3 + Category 1 + Category 3 (episodic moves):** −333 lines,
  **34.1%** reduction. Zero load-bearing loss; episodic stories move to
  episodic memory where they belong.
- **Aggressive (all categories):** −513 lines, **52.6%** reduction.
  CLAUDE.md becomes ~463 lines — short enough that the agent's
  "currently in head" working set actually contains all of it.

**The 463-line target is not arbitrary.** Below ~500 lines, an agent
reading the file at session start can hold the structural rules in
working memory through the first dozen tool calls. Above ~700 lines,
the agent skims; above ~900, the agent searches by keyword and applies
only the section it just read. §ACD's failure is the predictable shape
of a 24-line rule embedded at line 715 of a 976-line file.

---

## Hard constraint compliance

This document proposes **zero additions** to CLAUDE.md. Every numbered
recommendation is a line-out. The relocation targets (`docs/governance/
dispatch.md`, `docs/governance/termlink.md`, `docs/governance/
ac-authoring.md`) already have natural homes — the framework's `docs/`
tree already exists and the file pointers are discoverable via `fw
docs`. Episodic stories move to episodic memory which is already the
canonical store for them.

**Out-of-scope gaps spotted (named for hand-off, not addressed here):**
- Angle 1 must design the `fw audit --arc-completion` gate; only after
  it lands can §ACD's compression be safely executed.
- A migration step is needed: write the doc files BEFORE deleting the
  CLAUDE.md sections, so the relocations are atomic on a single PR.
- One PR per category recommended (A, B, C separately) so each
  compression is independently revertable if the agent's behaviour
  regresses.

**Concretely:** the Top-3 cuts (−242 lines) require zero new code and
zero gate work. They are landable today, in this order: B (TermLink),
A (Dispatch), C (Quick Reference) — pure relocations, no governance
risk. The §ACD cut (−22 lines) waits on Angle 1's gate.
