# T-2204 — Recommendation-completeness gate has bypass paths

**Workflow:** inception
**Recommendation (filed):** GO
**Origin:** T-2201 + T-2203 (this session, 2026-06-04) — third recurrence of the §"Presenting Work for Human Review" rule decay (T-679 family).

## Why this artifact exists

User pushback (2026-06-04, mid-session): *"2201 and 2203 again surface without recommendation and rationale, we worked on this but routing/enforcement is not working yet consistently — clearly or would you say otherwise?"*

The agent has been here before. Multiple times. The fixes have been partial. This artifact pins the full landscape — what shipped, what remains — so the next iteration doesn't lose the chain.

## What's already shipped (the bypass map)

| Surface / verb | Gate? | Origin |
|---|---|---|
| `fw inception start` (filing) | ✅ requires `--recommendation` + `--rationale` under `$CLAUDECODE=1` | T-1715 (meta-RCA) → T-1716 (implementation) |
| `fw inception decide` | ✅ requires non-empty `## Recommendation` block | T-974 |
| `fw inception decide` under `$CLAUDECODE=1` | ✅ refuses (operator-only) | T-1259 / T-1260 |
| `fw inception retrofit-recommendations` | ⚠️ EXISTS but manual-only (`--apply`); no cron, no hook, no auto-fire | T-1716 Stream C |
| Cross-surface render parity (Playwright invariant) | ✅ pins Recommendation+Verdict on `/approvals` `/review` `/tasks` `/inception` | T-1586 (L-316 closure) |
| Verdict surfacing on review surfaces | ✅ multiple surface tasks | T-1530, T-1531, T-1533, T-1537, T-1569, T-1575, T-1580, T-1583, T-1584, T-1585 |
| `[NO-REC]` handover marker (distinguish from `[?]`) | ✅ | T-1576 (inception side T-1570) |
| Reviewer extension to needs_human signals | ✅ | T-1572 |
| DEFER-as-hedge (author-time discipline) | ✅ codified in CLAUDE.md | T-2144 |
| DEFER-as-hedge (reviewer detector) | ✅ static-scan backstop | T-2145 |
| `fw task review` URL class correctness | ✅ class-correct `/inception/<id>` vs `/review/<id>` | T-2125, T-2127, T-2129 |
| Multi-task chat-handoff verbatim helper | ✅ `fw task review-batch` | T-2181, T-2182 |

That's 12+ shipped fixes on this surface area. The recurring failure is therefore **not** an empty landscape — it's a producer/consumer split (L-399 class) where the producer-side fix shipped on one path but bypass paths multiplied.

## What's missing (the gap)

### Producer side: bypass paths to filing-time recommendation requirement

T-1716's gate is wired into `lib/inception.sh:do_inception_start` only. Every other path that creates a task with `workflow_type: inception` skips it:

| Bypass path | Coverage |
|---|---|
| `fw task create --type inception` | ❌ no gate |
| `fw work-on "..." --type inception` | ❌ no gate (calls task-create) |
| Direct YAML write — `workflow_type: inception` in frontmatter | ❌ no gate |
| `fw task update T-XXX` that flips `workflow_type` to `inception` post-hoc | ❌ no gate |

**Repro from this session:**
- `T-2201` (pre-flight Claude CLI config) — filed via task-create path, Recommendation block = template comment only.
- `T-2203` (structural-observation harvester) — filed via task-create path, Recommendation block = template comment only.

Both files at the time of writing this artifact:

```
T-2201 lines 171-181: ## Recommendation
                      <!-- REQUIRED before fw inception decide... -->
                      ## Decisions
T-2203 lines 157-167: same shape
```

### Consumer side: handoff emission has no completeness pre-check

`fw task review` / `fw task review-batch` (T-2181/T-2182) emit the class-correct URL via task type → URL routing. They do NOT inspect the `## Recommendation` body. Result: agent posts `/inception/<id>` URLs to operator chat as "awaiting decision" handoffs that resolve to a blank decision form.

The retrofit verb (`fw inception retrofit-recommendations`) is the right shape — it scans active inceptions for template-only Recommendation blocks and can inject DEFER stubs. But it's manual: no cron, no commit hook, no task-create hook, no automatic invocation anywhere. So a freshly-filed inception sits in the bypass state until a human or a manual sweep catches it.

## Root-cause class (L-399 echo)

**Producer/consumer parity for governance contracts.** T-1716 shipped the producer-side gate on one filing path. Three other producers and one consumer emission verb were not updated. The pattern matches L-399 verbatim — "a hook that recommends a flag whose downstream parser rejects it as 'Unknown option' is a silent governance failure; the agent's workaround escapes the regex and bypasses the gate with no audit trail."

Here: the producer that *should* require `--recommendation` doesn't ask for it (workaround: `fw task create --type inception` instead of `fw inception start`); the consumer that *should* refuse emission on empty Recommendation emits anyway; the operator opens the page and sees the blank decision form.

## Candidate solutions (working set, pre-grilling)

### A. Extend T-1716 contract to all task-create producers

Patch `agents/task-create/create-task.sh` (and update-task.sh on workflow_type flip) to mirror the T-1716 check: when `workflow_type: inception` AND `$CLAUDECODE=1`, require `--recommendation` + `--rationale` or refuse with a block message that names the bypass mechanism.

**Pros:** symmetric with T-1716; one well-understood pattern; closes the three producer bypasses in one place.
**Cons:** task-create is a hot path with many call sites; needs careful test coverage; `fw work-on` and direct-edit (Write/Edit on `.tasks/active/T-*.md`) need different hooks.

### B. PreToolUse hook on Write/Edit of `.tasks/active/T-*.md`

When the file frontmatter parses to `workflow_type: inception` AND the `## Recommendation` block is empty/template-only AND `$CLAUDECODE=1`, refuse the write with a named bypass (`--allow-empty-recommendation` flag or `FW_ALLOW_EMPTY_RECOMMENDATION=1` env). Covers all four producer paths uniformly (including direct YAML write).

**Pros:** symmetric with existing hook architecture (`check-arc-id`, `check-inception-decisions`); single enforcement point.
**Cons:** filing a fresh inception requires the agent to write the body section twice (once initially, once after the Recommendation lands); the hook fires on every save during exploration.

### C. Consumer-side gate on `fw task review` / `fw task review-batch`

Pre-check `## Recommendation` body before emitting the URL. Refuse with a named bypass when block is template-only AND task is `workflow_type: inception` with `status` ∈ {started-work, captured}.

**Pros:** smallest blast radius (one verb, one check); the handoff verb is the *natural* surface for this check; bypasses still possible via direct URL paste (but harder to skip accidentally).
**Cons:** doesn't catch the upstream filing failure — only the downstream handoff; agent can still file empty inceptions that sit silently.

### D. Cron retrofit (auto-fire `fw inception retrofit-recommendations`)

Hourly cron runs `fw inception retrofit-recommendations --apply` to inject DEFER stubs on active inceptions with template-only Recommendation blocks.

**Pros:** safety net for everything else; existing verb, just wire it.
**Cons:** injects DEFER even when GO is what the agent intended; a delayed half-fix (hour-scale lag); doesn't change the agent's filing-time behaviour.

### E. Hybrid: B + C + D

Hook stops the producer at filing time. Review-batch refuses to emit unprepared handoffs. Cron retrofit catches anything that slips. Three defensive layers.

**Pros:** producer/consumer parity restored on all known surfaces; matches the §Hook Bypass Contract Parity discipline (T-1890/L-399).
**Cons:** three things to ship; coordination cost.

## Provisional recommendation (pre-grilling)

Candidate **E** (B + C + D) — the parity discipline from L-399 says "when a hook introduces a bypass contract, every consumer of every command pattern the hook gates must honour that contract." T-1716 introduced the contract on one producer; the parity job is to extend it to every producer AND every consumer. E is exactly that.

If E is too heavy for one slice, ship in order **B → C → D** (producer fix first, consumer gate second, cron safety net third). Each leg is independently valuable.

## Dialogue Log

### 2026-06-04 — Operator pushback that triggered this inception

> **Operator:** "ok structural issue, 2201 and 2203 aghain service without recommendation andrationaloy, we worked on this but routing / enforment is not working yet consistenly cleary or woudl you say otherwise?"

> **Agent:** Agreed concretely. Mapped the gate landscape (T-1715/T-1716/T-974/T-1259-60/T-1530/T-1531/T-1533/T-1537/T-1569/T-1572/T-1575/T-1576/T-1580/T-1583/T-1584/T-1585/T-1586/T-2125/T-2127/T-2129/T-2144/T-2145/T-2181/T-2182) and identified four producer bypasses + one consumer gap.

> **Operator:** "2 make an inception buit look back and teh work / and dioscussuin / design we already did for this, its getting lost !!!!"

> **Agent:** Filed T-2204 via `fw inception start --recommendation GO --rationale ...` (dogfooding the gate this inception is about). This artifact pins the prior work chain so the chain stops getting lost between iterations.

## Cross-refs (the chain that was getting lost)

**Foundational (gate exists at decide time):**
- T-974 — inception recommendation gate (require ## Recommendation before fw inception decide)
- T-1259 / T-1260 — `fw inception decide` refuses under `$CLAUDECODE=1`

**Filing-time gate (one producer covered):**
- T-1715 — Meta-RCA: agent files inception artefacts without ## Recommendation block (T-679 rule recurring violation)
- T-1716 — Filing-time `--recommendation` gate on `fw inception start` (T-1715 implementation)

**Cross-surface rendering parity (already shipped):**
- T-1530 — inline recommendation verdict in handover
- T-1531 / T-1533 / T-1537 / T-1569 — verdict surfacing on /approvals, landing, inception cards
- T-1575 — structural recommendation rendering (unification)
- T-1580 — fix recommendation extractor (accept bullet form)
- T-1583 / T-1584 / T-1585 — verdict cards on /review, /tasks, /inception
- T-1586 — Playwright invariant pinning Recommendation+Verdict on all 4 surfaces (L-316 closure)

**Handover annotation:**
- T-1570 — distinguish NO-REC from DEFER on inception side
- T-1576 — same, build-task side (F9 parity)

**Reviewer extensions:**
- T-1572 — extend gate to fire on reviewer.needs_human signals (F6 from T-1565 audit)

**DEFER-as-hedge discipline:**
- T-2144 — DEFER is for evidence gaps, NOT confidence gaps (author-time)
- T-2145 — reviewer detector `defer-as-hedge` (static-scan backstop)

**URL class + handoff verb:**
- T-2125 — handoff URL class-dependent (per-class /inception, /review, /approvals, /arcs/<slug>/close)
- T-2127 — Open / Decide URL affordances under QR
- T-2129 — class-correct URL render
- T-2181 — chat-bare-path Stop-hook scanner (in flight)
- T-2182 — `fw task review-batch` for multi-task chat handoffs

**Parent governance:**
- T-679 — origin rule ("write your recommendation into the task file")
- L-399 — producer/consumer parity for hook bypass contracts (T-1890)
- L-316 — cross-surface drift class
- §"Presenting Work for Human Review" — CLAUDE.md anchor

**Repro cases (this session):**
- T-2201 — pre-flight Claude CLI config inception (Recommendation block: template comment only at handoff time)
- T-2203 — structural-observation harvester inception (Recommendation block: template comment only at handoff time)

## What to do next (after operator decides T-2204)

If GO ships:
1. Write the producer-side Write/Edit hook (Candidate B) — small slice, mirrors T-1716 surface
2. Write the consumer-side `fw task review` / `fw task review-batch` pre-check (Candidate C) — single-verb gate
3. Wire `fw inception retrofit-recommendations --apply` to hourly cron (Candidate D) — safety net
4. Update CLAUDE.md §"Presenting Work for Human Review" to name all four producer paths + the consumer gate
5. **Tactical close**: write the missing Recommendations for T-2201 (GO — Candidate B from its own artifact) and T-2203 (DEFER — evidence gap, IW-1..IW-4 untested)
