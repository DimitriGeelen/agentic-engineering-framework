# T-2123: why [REVIEWER] auto-routing isn't clearing the partial-complete backlog

## Problem Statement

User: *"i also see a lot of unclosed work-completed items, did we not agree we
would route ACs more to agents, we even have a termlink reviewer agent for
this, please incept why this is not structurally working yet (rubber-stamping
should be agent where sensible and risk acceptable correct, we said on
high-impact UX and high-risk change, ok this is all UX)."*

**Hard data captured at filing time (2026-05-30):**

| Prefix in unticked Human ACs across `.tasks/active/T-*.md` | Count |
|------------------------------------------------------------|-------|
| `[REVIEW]` (human judgment)                                | **152** |
| `[REVIEWER]` (static-scan-verifiable via `fw reviewer`)     | **0** |
| `[RUBBER-STAMP]` (mechanical → should be Agent AC)         | **4** |

**152 : 0 : 4.** The codification (T-1811 + T-1878 conversion rule + T-1896
default-bias detector + T-1985 reviewer auto-tick) is on paper; **zero**
Human ACs in flight today are tagged for the reviewer agent path. Even where
the agreement was *"default to [REVIEWER] when Expected is grep-able /
file-exists / structural"*, the prefix never appears.

The reviewer infrastructure exists and works: `lib/reviewer/static_scan.py`
runs 12+ detectors, `fw reviewer T-XXX [--dispatch]` works in TermLink
isolation (T-1951), and auto-tick (T-1985) atomically ticks `[REVIEWER]` ACs
with full sovereignty-rail consent. **The plumbing is wired, the prefix is
absent — so the plumbing carries zero traffic.**

This pairs with T-2118 (chat-side palette emission gap) and T-2122 (arc-close
recommendation gap) as the **third member** of the §ACD-class-at-the-AC-level
cluster surfaced this week.

## Assumptions

- **A1.** The conversion rule (T-1811/T-1878) exists in CLAUDE.md but the
  agent doesn't run a classifier at AC-write time — so the *author-time
  default* never fires unless the agent thinks about it deliberately.
- **A2.** T-1896 default-bias detector exists but is **advisory-only at
  close** — emits CONCERN findings, doesn't refuse the close, doesn't
  retroactively scan existing partial-completes.
- **A3.** `fw reviewer T-XXX` requires **manual invocation** — no daemon
  scans the 152 partial-completes; no PostToolUse hook runs the reviewer
  on tasks tagged `owner: human` daily.
- **A4.** Auto-tick (T-1985) only fires for ACs that ALREADY have the
  `[REVIEWER]` prefix — it cannot retroactively reclassify a [REVIEW] AC,
  so 152 [REVIEW] ACs stay [REVIEW] forever unless the agent rewrites them.
- **A5.** The user's stated agreement: *"rubber-stamping should be agent
  where sensible and risk acceptable; we said on high-impact UX and
  high-risk change"* — implies the **default** should be agent-checked,
  not human-checked, with `[REVIEW]` reserved for high-impact UX / high-risk.
  Current ratio 152:4 inverts this default.

## Exploration Plan

- **Spike 1 (data, done):** Count [REVIEW] : [REVIEWER] : [RUBBER-STAMP]
  prefixes in `.tasks/active/T-*.md`. **Done — 152 : 0 : 4.**
- **Spike 2 (data, 5min):** Of the 152 [REVIEW] ACs, how many have
  grep-able / file-exists / structural Expected clauses (i.e. would convert
  to [REVIEWER] per T-1811 rule)? Sample 20 randomly.
- **Spike 3 (mechanism, 10min):** Trace why T-1896 default-bias detector
  doesn't trip on these. Is it (a) prefix-blind by design (only scans
  `[REVIEWER]` for prose mismatches), (b) absent from the close gate, or
  (c) silently CONCERN-only?
- **Spike 4 (option synthesis):** Three structural levers below.

## Technical Constraints

- The classifier must run **at AC author time** (PreToolUse Write|Edit on
  task files) AND **retroactively** on the backlog (cron + audit). Neither
  hook exists today.
- The agent's PreToolUse gates today look at task-existence, focus, arc-id
  validity, render-surface, RCA presence — not at AC prefix routing.
- Reclassifying an AC from [REVIEW] to [REVIEWER] retroactively must pass
  the sovereignty boundary: who decides the AC is mechanically verifiable?
  The agent can propose; auto-tick only fires after PASS.

## Scope Fence

**IN.** Define the placement of the prefix-routing enforcement (PreToolUse
gate vs daily audit vs close-gate refusal), the policy for backlog
retroactive reclassification (who proposes, who confirms), and the chat-side
counterpart (`fw review-queue --reviewer-candidates`).

**OUT (for this inception — file as separate builds on GO).**
- The PreToolUse gate implementation
- The audit / cron job that scans backlog
- Migration of the 152 existing [REVIEW] ACs

**OUT (deferred).** Auto-conversion (agent flips the prefix without human
confirmation) — propose-only first; auto-flip later if propose-rate proves
out without false-positive complaints.

## Acceptance Criteria

### Agent
<!-- @auto-tick-on-decide -->
- [x] Problem statement validated — 152:0:4 prefix ratio confirms agent never uses [REVIEWER] at AC author time despite T-1811/T-1878 codification.
<!-- @auto-tick-on-decide -->
- [x] Assumptions A1-A5 enumerated (one of each is testable in a 5-10min spike before build).
<!-- @auto-tick-on-decide -->
- [x] Recommendation written — see `## Recommendation` below; A+B+C combined.

### Human
- [ ] [REVIEW] Decide GO/NO-GO/DEFER on the structural enforcement approach. Optionally: pick a lever sub-set (A=author-time, B=retro backlog scan, C=close-gate refusal). Reply via Watchtower review form.
  **Steps:**
  1. Open http://192.168.10.107:3000/review/T-2123
  2. Read `## Recommendation` block (below) — three levers.
  3. Record decision via the Watchtower form.
  **Expected:** Decision recorded; sibling build task(s) created on GO.
  **If not:** Tell agent which lever is too narrow / too broad.

## Go/No-Go Criteria

**GO if:** prefix-ratio data shows the codification has not produced behavioural
change in 28+ days since T-1878 landed (CURRENT EVIDENCE: 152 [REVIEW] vs 0
[REVIEWER] — codification has produced 0% adoption).

**NO-GO if:** the 152 [REVIEW] ACs are demonstrably high-impact UX / high-risk
where human judgment is correct (a 20-AC sample audit would confirm or refute).

**DEFER if:** a broader review-queue redesign already underway supersedes this
scope (none known).

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# For inception tasks, verification is often not needed (decisions, not code).
#
# Toolchain hint (L-291): if a GO decision will mean editing *.vbproj/*.csproj/*.xaml,
# *.go, Cargo.toml, tsconfig.json, or pom.xml in the build task, plan to add the
# matching build command (dotnet build / go build / cargo check / tsc --noEmit /
# mvn compile) to that build task's ## Verification — P-011 only runs what you write.

## Reframe — 2026-05-30 (user-driven, after T-2074 AC critique)

User pushed back on the original framing: *"maybe you are writing the ACs
correctly (being for agent, in agent language) but it's being routed to
human (which is a leftover from work in the beginning where we said route
to human for verification because output quality was unreliable and we had
no enforced agentic means to validate; we have evolved in that space and
have way better enforcement and agentic verification capability in place).
Maybe this is still the remnant human-AC / rubber-stamping routing
leftover we need to sanitize."*

**Diagnosis sharpened.** The original wording of this inception ("[REVIEW]
→ [REVIEWER]") was too narrow. The real gap is broader:

- The framework today has **four** agent-verification channels:

  | Channel | Lands as | Lives in |
  |---------|----------|----------|
  | Tier 1 — shell | Agent AC + commands in `## Verification` | P-011 gate |
  | Tier 2 — static scan | Agent AC + `bin/fw reviewer T-XXX` in Verification | `lib/reviewer/static_scan.py` + `--dispatch` (T-1951) |
  | Tier 3 — Playwright | Agent AC + `tests/playwright/test_X.py` | `fw test playwright` |
  | Tier 4 — TermLink-dispatched worker | Agent AC + dispatched verifier | `fw termlink dispatch` |

- The [REVIEW] prefix was the **safe default** before any of these channels
  existed. It is now technical debt.

- The agent's mental model still defaults to [REVIEW] because the
  *routing question is never asked at AC author time*. Even when the
  agent literally writes the Playwright test in the same session (T-2120
  → T-2074), the AC stays [REVIEW] — the routing decision is invisible.

**Concrete proof in this session:** T-2074's "[REVIEW] toast appears on
4xx" was pinned structurally by T-2120's
`tests/playwright/test_htmx_toast_extraction.py` (shipped 40 min before
the user critique). Agent verification was on disk, passing, ignored.
Re-routed under T-2074 commit `da6bed7a` (2026-05-30) — proof of the
principle on one task.

**Reframed backlog narrative.** The 152 [REVIEW] ACs are not *"ACs to
reclassify [REVIEW]→[REVIEWER]"*. They are *"ACs to **sanitize**: for
each, ask the routing question against the four current channels."* Most
will route away from `[REVIEW]`. The genuine taste / high-impact UX /
high-risk-change ACs that remain are the real ones the user wanted to
spend attention on.

**Recommendation revised:**

## Recommendation

**Recommendation:** GO on combined **A + B + C** with the routing question
broadened from prefix-conversion to **channel selection across all four
agent-verification tiers**.

**Rationale:**

The codification exists (T-1811 + T-1878 + T-1896 + T-1985), and the
reviewer infrastructure works (`fw reviewer T-XXX [--dispatch]`). What's
missing is the **enforcement loop** that connects them. Three levers, each
addressing a different temporal phase:

### Lever A — Author-time **channel-selection** gate (broadened from prefix-routing)
**PreToolUse hook on Write|Edit to `.tasks/active/T-*.md`:** when the diff
adds a `### Human` AC, run the **routing question** against the AC text:

  1. Does Expected resolve to a shell-checkable assertion (file exists,
     exit code, grep)? → **Tier 1** — convert to Agent AC + `## Verification`.
  2. Does Expected resolve to a static-scan pattern the reviewer agent
     handles (anti-pattern, block-message conformance, naming)? → **Tier 2**
     — convert to Agent AC + `bin/fw reviewer T-XXX` in `## Verification`.
  3. Does Expected resolve to a deterministic DOM/UI assertion
     (element-visible, text-present, URL-stable, count, attribute)? →
     **Tier 3** — convert to Agent AC + `tests/playwright/test_X.py`.
  4. Does verification need an isolated worker context (cross-process,
     E2E CLI, multi-step substrate)? → **Tier 4** — convert to Agent AC
     + `fw termlink dispatch` invocation in Verification.
  5. **Only if no tier applies** (genuine taste, layout rhythm, blast-radius
     judgment, strategic call, irreversible external action) → `[REVIEW]`
     Human AC.

Block message names the matched tier(s) and offers conversion hint. Override:
`FW_ALLOW_REVIEW_PREFIX=1` (logged Tier-2) only when the agent has
genuinely considered all four tiers and rejected each. Same shape as
`check-render-surface.sh`.

### Lever B — Backlog **sanitization** pass (broadened from reclassification)
**Daily cron / `fw audit` check:** scan partial-complete tasks for `[REVIEW]`
ACs and run the **same four-tier routing question** as Lever A. For each
AC where any of Tier 1-4 applies, emit an observation: *"T-XXXX AC#N looks
Tier-K-eligible; propose conversion to Agent AC with `<channel command>`
in `## Verification`."* The agent or the human via Watchtower accepts/
rejects per AC. Output: WARN in `fw audit` + observation entries in
`.context/inbox.yaml`.

Critically: this is **sanitization, not bulk reclassification.** Each AC
gets one observation; taste-decisions survive untouched.

### Lever C — Close-gate refusal (escalation of T-1896 to BLOCK)
**`update-task.sh` close gate:** when render-surface or [REVIEW] AC fires,
also run T-1896's prose-mismatch detector. If a [REVIEWER] candidate is
found (Expected is grep-able + AC text contains no taste vocabulary from
L-409 list), refuse close with the same conversion-block message. Same
escalation pattern as G-019 (CONCERN → BLOCK once the data shows the warning
isn't acted on).

**Combined effect:** Lever A stops new [REVIEW]-by-default ACs at write
time. Lever B works through the 152-deep backlog one observation at a time.
Lever C catches the cases that slip past A (e.g. agent overrides) before
they ship as partial-completes.

**Why all three, not one:**

- A alone closes the future-tap but leaves the backlog of 152 untouched.
- B alone is slow and depends on the agent / human triaging observations
  daily.
- C alone is too late (work is already done, just blocked from closing).
- Together they form a closed feedback loop the user explicitly named:
  *"rubber-stamping should be agent where sensible and risk acceptable …
  on high-impact UX and high-risk change [it stays human]."*

**Evidence:**

- 152 : 0 : 4 [REVIEW] : [REVIEWER] : [RUBBER-STAMP] in partial-completes
  (commands: `grep -lE "^- \[ \] \[REVIEW\]" .tasks/active/T-*.md | wc -l`
  and parallels).
- T-1878 (≈21d old) showed 412:7 ratio at the time, 13% mis-classification.
  Today's data: **rate has worsened** to 152:0 (denominator different
  because newer tasks were filed; numerator is the active-only subset).
- The reviewer dispatch path (T-1951) provides ~5-second per-task isolated
  worker scans — cost is bounded.
- L-409 lists the taste-vocabulary signals (reads clearly, tone, voice,
  rhythm, intuitive, feels right, …) that DISQUALIFY a [REVIEWER]
  classification. A simple regex check answers the routing question.
- This inception is itself a third member of the §ACD-class-at-AC-level
  cluster (T-2118, T-2122) — the broader pattern of *"convention captured
  in text, not in structural enforcement"*.

**GO decision unblocks build tasks:**

- **T-NEW-A:** PreToolUse hook `check-ac-prefix-routing.sh` (parallel to
  `check-render-surface.sh`).
- **T-NEW-B:** `fw audit` check + `.context/inbox.yaml` observation
  emitters for reviewer-candidate [REVIEW] ACs in partial-completes.
- **T-NEW-C:** `update-task.sh` close-gate escalation of T-1896 from
  CONCERN-only to BLOCK with `--skip-ac-routing` override (logged Tier-2).

**Hand to human:** http://192.168.10.107:3000/review/T-2123 — Watchtower
decision form. Agent cannot decide (CLAUDECODE-gated per T-1671).
     - Finding 2
-->

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
