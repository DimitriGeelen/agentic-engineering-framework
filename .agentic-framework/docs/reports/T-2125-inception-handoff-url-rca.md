# T-2125: inception decisions routed to /review/<id> not /approvals — RCA + structural remediation

## Problem Statement

When handing inception decisions back to the human, the agent's chat output reads:

> 2. T-2123 inception decision — http://192.168.10.107:3000/review/T-2123 (recommend GO on A+B+C…)
> 3. T-2118 inception decision — http://192.168.10.107:3000/review/T-2118 …
> 4. T-2122 inception decision — http://192.168.10.107:3000/review/T-2122 …
> 5. T-2115 inception decision — http://192.168.10.107:3000/review/T-2115 …

User feedback (verbatim, 2026-05-30):
> "inception decisions are not in review, they should be in approval properly filed"

The decisions belong on `/approvals` (the canonical decision queue) or `/inception/<id>` (the dedicated inception decide form). `/review/<id>` is the partial-complete task-review surface — wrong artefact class.

**For whom:** the human operator who decides inceptions. Wrong URL = either a 200-but-wrong-form, missing the Recommendation/Assumptions/Go-No-Go-Criteria render, or the form doesn't show the inception-specific decide POST action — wasted clicks per decision.

**Why now:** four inception decisions are stacked in the queue (T-2115, T-2118, T-2122, T-2123). Pointing the user at the wrong surface for all four is a friction tax on every handoff.

## Assumptions

- **A1:** All four inceptions ARE on `/approvals` already (no filtering bug). Validated below.
- **A2:** `fw task review T-XXX` already emits the correct surface (`/inception/<id>` for inceptions). Validated below.
- **A3:** The defect is purely in agent chat-output URL synthesis, not in framework routing. Validated below.
- **A4:** A render-side redirect from `/review/<inception-id>` → `/inception/<id>` would make the agent's typo idempotently safe.

## Investigation (RCA)

### Step 1 — Where are the 4 inceptions actually surfaced?

```
$ curl -s $url/approvals | grep -oE "T-(2115|2118|2122|2123)" | sort -u
T-2115
T-2118
T-2122
T-2123
```

**All four present on `/approvals`.** Frontmatter audit confirms they each have `workflow_type: inception`, `status: started-work`, and a `## Recommendation` block with GO + rationale. So `/approvals` already does the right thing — the queue is correctly populated by `web/blueprints/approvals.py:_load_pending_inceptions()`.

### Step 2 — What URL does `fw task review` actually emit?

```
$ bin/fw task review T-2123 2>&1 | head
══════════════════════════════════════════
  Inception Review: T-2123
  0/1 checked

  http://192.168.10.107:3000/inception/T-2123     ← CORRECT
```

`fw task review` (via `lib/review.sh`) **already routes inceptions to `/inception/<id>`** — labelled "Inception Review", with `bin/fw inception decide T-XXXX go` in the CLI block.

### Step 3 — What did the agent type in chat?

```
2. T-2123 inception decision — http://192.168.10.107:3000/review/T-2123
3. T-2118 inception decision — http://192.168.10.107:3000/review/T-2118
4. T-2122 inception decision — http://192.168.10.107:3000/review/T-2122
5. T-2115 inception decision — http://192.168.10.107:3000/review/T-2115
```

**All four wrong.** The agent synthesised `/review/<id>` from memory ("ALWAYS use `fw task review` → /review URL") without invoking the command and pasting the actual emitted URL.

### Step 4 — Three distinct surfaces, all 200, only one is correct per class

| URL pattern | Purpose | Correct for |
|-------------|---------|-------------|
| `/approvals` | Canonical decision queue (Tier-0 + inceptions + partial-completes) | Operator scanning what needs deciding |
| `/inception/<id>` | Dedicated inception detail + GO/NO-GO/DEFER POST | Deciding a single inception |
| `/review/<id>` | Task review (partial-complete with Human ACs) | Closing a partial-complete build/refactor task |

The three surfaces all return HTTP 200 for any task ID, which is why the typo is silent: the human gets *a* page, just not the one with the decide button.

### Root Cause

**Agent-side URL synthesis is class-agnostic.** Four CLAUDE.md memories ([[feedback_use_fw_task_review]], [[feedback_human_review_links]], [[feedback_review_concrete_links]], [[feedback_post_grill_governance]]) told the agent "always use `fw task review` + clickable links" — but didn't disambiguate that the *URL* emitted by `fw task review` is class-dependent. The agent over-fit to "review" as the verb in chat and synthesised `/review/T-XXX` for everything.

This is the same root pattern as T-2118 (review handoff palette), T-2122 (arc-close recommendation surface) and T-2123 (AC routing default). Four siblings of the **§ACD-at-handoff** class: agent defaults to *one* handoff URL across all decision classes that genuinely need distinct surfaces.

## Scope Fence

**In scope:**
- Agent URL discipline for inception handoffs (chat output → `/inception/<id>` or `/approvals`)
- Render-side forgiveness: `/review/<inception-id>` → `/inception/<id>` 302
- CLAUDE.md §Presenting Work for Human Review extension: per-class URL mapping

**Out of scope:**
- Wholesale UI redesign of `/approvals`, `/inception/`, `/review/`
- Auto-decide logic (CLAUDECODE-gated, T-1671 is in place)
- Cross-cutting refactor of `fw task review` / `fw inception status` / `fw review-queue` CLI surfaces

## Remediation Options

### Option A — render-side redirect (cheap, idempotent)

`web/blueprints/review.py:/review/<task_id>` looks up the task's `workflow_type`; if `inception`, 302 to `/inception/<task_id>`. Same for `arc-close` → `/arcs/<slug>/close`. Cost: ~10 LoC. Benefit: any historical chat link works invisibly; agent typo is harmless.

**Risk:** masks the agent's bad habit. Mitigated by pairing with Option B.

### Option B — CLAUDE.md per-class URL mapping (codification)

Extend §Presenting Work for Human Review with a class→URL table:

| Decision class | Correct URL |
|----------------|-------------|
| Inception go/no-go | `/inception/<id>` or `/approvals` |
| Task partial-complete (Human ACs) | `/review/<id>` |
| Tier-0 approval | `/approvals` |
| Arc close | `/arcs/<slug>/close` |

Then: **"Never synthesise the URL from memory — run `fw task review T-XXX` and quote the emitted URL verbatim."**

Cost: doc-only. Benefit: removes the class of typo at the source.

### Option C — reviewer-agent pattern (overkill alone)

Add a static-scan pattern in the `fw reviewer` agent (T-1443) that flags `/review/T-XXXX` in chat-output-like contexts when the referenced task has `workflow_type: inception`. Hard to wire (no chat-output ingestion exists), and Option A makes it unnecessary because the URL works either way.

### Option D — behavioural: stop synthesising, always shell out

In chat, when listing decisions for the human:
1. Run `fw task review T-XXX` for each task.
2. Quote the emitted URL line verbatim (it's already class-correct).
3. Never hand-type `/review/T-XXX`, `/inception/T-XXX`, `/arcs/.../close` from memory.

This is the discipline pair to Option B. Already partially in [[feedback_use_fw_task_review]], but the existing rule didn't catch that the *URL* it emits is class-dependent.

## Go/No-Go Criteria

**GO if:**
- The three findings hold: (a) `/approvals` already surfaces inceptions correctly, (b) `fw task review` already emits the correct URL per class, (c) agent chat output is the only defect site
- Option A is implementable in `web/blueprints/review.py` without breaking the existing `/review/<id>` partial-complete flow
- The combined A+B+D fix fits one build task (≤ one session)

**NO-GO if:**
- `/approvals` filtering omits some inception class (e.g. captured-without-recommendation) — would require queue fix, not handoff fix
- `/review/<id>` has substantive partial-complete behaviour for inceptions that a redirect would break

**DEFER if:**
- The 4 backlog inceptions can be cleared by the human first (re-handing-off with correct URLs); fix lands after the queue drains

## Recommendation

**Recommendation:** GO on combined **A + B + D**.

**Rationale:**
- The RCA narrows the defect to one site (agent chat output). The framework's `fw task review` already does the right thing; the user has been clicking through to the *wrong-but-200* surface because I quoted the wrong URL.
- Option A (render-side 302) is the cheapest structural forgiveness — any historical `/review/T-XXX` chat link for an inception starts redirecting to `/inception/T-XXX` invisibly. ~10 LoC, no behavioural risk.
- Option B (CLAUDE.md per-class URL table) closes the agent-side gap that produced the bug in the first place. The four existing memories all said "use `fw task review`" — none disambiguated the emitted URL per workflow_type.
- Option D (always-shell-out discipline) is the behavioural pair to B: never hand-type these URLs from memory; quote the CLI's emitted line.
- Option C (reviewer detector) is unnecessary once A lands — the typo becomes a no-op.

**Evidence:**

- `curl -s $url/approvals | grep -oE "T-(2115|2118|2122|2123)"` → all four present (RCA Step 1)
- `bin/fw task review T-2123 | head` → emits `/inception/T-2123`, not `/review/T-2123` (RCA Step 2)
- Agent's chat output earlier this turn typed `/review/T-2123` for all four inceptions (RCA Step 3)
- Three URL classes all return HTTP 200, masking the typo (RCA Step 4)
- Sibling class: [[T-2118]], [[T-2122]], [[T-2123]] — §ACD-at-handoff (same root pattern across decision classes)

## Decisions

### 2026-05-30 — Where the fix lives
- **Chose:** Agent chat output (Option B+D) + render-side forgiveness (Option A)
- **Why:** Defect site is agent-side, but a 10-LoC redirect makes future agent typos harmless without behavioural reliance
- **Rejected:** Option C alone — no chat-ingestion surface exists; Option A makes it moot

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# These verify the RCA findings, not the build slices (those will have their own Verification on GO).
url=$(bin/fw watchtower url); curl -s "$url/approvals" > /tmp/.t2125-approvals.html && grep -q "T-2123" /tmp/.t2125-approvals.html
out=$(bin/fw task review T-2123 2>&1); echo "$out" | grep -q "/inception/T-2123"

## Recommended Build Slices (on GO)

1. **T-NEW-A**: `web/blueprints/review.py:/review/<task_id>` — early branch on `workflow_type`; 302 to `/inception/<id>` for inceptions, `/arcs/<slug>/close` if `workflow_type == arc-anchor` + arc-close intent. Playwright test pins the redirect.
2. **T-NEW-B**: CLAUDE.md §Presenting Work for Human Review — add per-class URL table + "never synthesise, always shell out" rule. Memory write [[feedback_handoff_url_per_class]].
3. **T-NEW-D**: Re-issue the 4 stacked handoffs (T-2115, T-2118, T-2122, T-2123) with `/inception/<id>` URLs to clear the immediate backlog.

## Decision

<!-- Filled at completion via: fw inception decide T-2125 go|no-go --rationale "..." -->

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-05-30T21:26:50Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-05-30 — RCA + structural remediation written
- **Change:** Problem statement, 4-step investigation, root cause, 4 remediation options, GO recommendation on A+B+D, build slices outlined
