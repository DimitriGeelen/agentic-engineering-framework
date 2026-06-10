# T-1950: Reviewer auto-tick — implementation inception

**Status:** active inception, S-2026-0521-resume
**Parent decision:** T-1443 (GO 2026-04-25), Decisions 3 + 36 + 113 + 213
**Closes:** G-066 prong 2 of 3 (T-1442/T-1443 GO scope half — reviewer auto-tick)

## Framing — what's already decided

T-1443's inception already sanctioned reviewer auto-tick of Agent ACs as a
principle. The decisions list captured this in three places:

> 36. Reviewer authority = **mechanical tick on Agent ACs only** (NOT Human ACs).
> 113. Reviewer NEVER auto-ticks a `### Human` AC. Original classification is inviolable.
> 213. Sovereignty preservation: reviewer NEVER ticks `### Human` ACs — structurally enforced.

v1.3 shipped the substrate: `Finding.ac_index/ac_subhead/ac_text` populated by
AC-bound detectors (`static_scan.py:49, 257, 703, 810, 906`). Per-AC verdicts
already group findings under each AC. **The capability is wired; only the write
is missing.** The guard at `static_scan.py:7, 1130` ("NEVER modifies AC
checkboxes") is leftover v1.0 scope-cut text — not a load-bearing axiom.

What T-1443 did **not** spell out:
- *Where* the tick fires (which command, which lifecycle moment)
- *Which* Agent ACs are tick-eligible (all, or only [REVIEWER]-prefixed introduced by T-1811)
- *What* finding-state counts as evidence (PASS verdict alone? Plus Verification command match? Plus explicit AC mapping?)
- *How* human-overridden ticks are preserved (don't re-tick what human un-ticked)

T-1950 answers these four questions and files the build child.

## Question 1 — Trigger: when does auto-tick fire?

**Candidates:**

| Trigger | Where | Cost | Risk |
|---------|-------|------|------|
| A. Inside `bin/fw reviewer T-XXX` (manual scan) | `lib/reviewer/static_scan.py` write-back | Low — already runs end-to-end | Tick happens on every manual scan; surprises during exploratory scans |
| B. Inside `update-task.sh --status work-completed` (post-verification, pre-gate) | `update-task.sh` calls reviewer, ticks before P-010 counts checkboxes | Medium — wires reviewer into completion path | P-010 sees ticked ACs → gate passes silently. ↔ this IS the point; T-1831 C-4 is the pattern. |
| C. Manual `fw reviewer T-XXX --tick` (opt-in flag) | New flag on reviewer CLI | Low | Opt-in defeats the purpose — agent has to remember to ask |
| D. Cron / audit pass | `fw reviewer audit` (Layer 3) | Low | Latency — agent has moved on; ticks appear in next session |

**Chose: A + B.** Tick happens **in `static_scan.py` always when scan runs**,
making B trivial: `update-task.sh` already calls reviewer post-verification
(line 11 docstring). Triggers A and B are the same code-path, just different
callers. C is rejected — opt-in defeats antifragility; the human always learns
about a tick after-the-fact via the Reviewer Verdict block and feedback-stream
entry, both already shipped. D is rejected — wrong latency for a completion
gate.

**Sovereignty rail:** the tick must be visible to the user post-hoc.
Mechanism: each auto-tick writes an entry to feedback-stream.yaml
(`action: auto_tick`) AND adds a `## Reviewer Verdict` line citing the AC
number, the matched evidence, and the override path (`fw reviewer override
add T-XXX --ac N --pattern auto-tick`). Same path that already exists for
findings (`lib/reviewer/overrides.py`).

## Question 2 — Scope: which Agent ACs are eligible?

**Candidates:**

| Scope | Coverage | Risk |
|-------|----------|------|
| All Agent ACs | Maximal — anything not `### Human` is tick-eligible | High — many Agent ACs aren't structurally verifiable (e.g. "code reads clearly to the next maintainer") |
| [REVIEWER]-prefixed Agent ACs only | Narrow — only ACs explicitly tagged for static-scan verification (T-1811) | Low — author opt-in; signal-rich |
| Agent ACs with a matching `## Verification` command | Medium — verification command exit code is the evidence | Medium — Verification commands aren't AC-bound by line; mapping is heuristic |
| Hybrid: [REVIEWER] OR (Verification-bound AND no findings) | Medium | Low — both gates additive |

**Chose: [REVIEWER]-prefixed Agent ACs only (v1.0).** Rationale:

- T-1811 was filed precisely as the "explicitly verifiable by reviewer" prefix.
  Auto-tick scope aligning with that prefix is the **dual** of [REVIEWER]: the
  prefix says "reviewer can verify this", auto-tick says "reviewer did verify
  this".
- T-1878 nudges authors at AC write-time toward [REVIEWER] when their Expected
  is deterministic. The audit ecosystem is converging on the prefix as the
  marker of structural verifiability.
- Conservative — easy to widen, hard to narrow. v2 can extend to "Agent AC with
  matching Verification command" if signal is good. v3 to all Agent ACs if v2
  is stable.
- Failure mode is bounded: a [REVIEWER] AC that auto-ticks falsely is
  detectable by `fw reviewer audit` (Layer 3 Pass-B re-scan, T-1443 v1.4),
  and the human can override with TTL.

**Rejected alternatives:** "all Agent ACs" — too broad for v1.0; risks false
tick on prose-quality Human-class ACs misfiled as Agent (the T-1947 case).
"Verification-bound" — Verification commands aren't 1:1 with ACs; mapping is
heuristic and conflicts with T-1831 C-4 (which says ticks are progressive, not
batch-on-verify).

## Question 3 — Evidence sufficiency rule

For a [REVIEWER]-prefixed Agent AC at index N, **auto-tick fires iff ALL hold**:

1. `verdict.overall == "PASS"` (no FAIL anywhere; CONCERN is not sufficient)
2. `findings[ac_index == N]` is empty (zero pattern hits on this specific AC)
3. AC checkbox is currently `[ ]` (unticked) — see Q4
4. No active override for `(task_id, "auto-tick", N)` with `action: suppress`
5. The AC text matches the [REVIEWER] prefix regex (i.e. starts with
   `- [ ] [REVIEWER]` or `- [ ] [REVIEWER]:` after frontmatter-aware parsing)

Conjunction is **AND**, not OR — every condition must hold.

**Rejected:**
- "Tick on PASS even with CONCERN on other ACs" — global PASS means every AC
  passed, so a CONCERN elsewhere means the global verdict isn't PASS. The check
  is implicit but worth pinning.
- "Tick on CONCERN if no findings on this specific AC" — CONCERN signals
  reviewer-found ambiguity somewhere; not safe to extrapolate "but this AC is
  fine". Wait for the human to clear the CONCERN, or wait for the v2
  per-AC-verdict surface.
- "Tick when verdict + Verification exit 0" — couples reviewer to verification
  runner; v1.0 reviewer doesn't run verification, only reads task. Keep
  separation of concerns until v1.5 ("Pass A drift re-verification").

## Question 4 — Sovereignty rails: don't re-tick what human un-ticked

This is the most subtle question. The state machine:

```
[ ] (unticked)    ← initial
[x] (ticked)      ← human ticked OR auto-tick fired
[ ]* (unticked-by-human, post-tick)  ← human deliberately un-ticked
```

Auto-tick must distinguish `[ ]` (initial) from `[ ]*` (post-untick). The
**markdown surface has no state** — both render as `[ ]`. We need an
out-of-band signal.

**Chose: feedback-stream as the source-of-truth for human-untick.**

When the reviewer auto-ticks AC N, it writes to feedback-stream:
```yaml
- ts: <iso>
  task_id: T-XXX
  action: auto_tick
  ac_index: N
  evidence_digest: <sha>
```

When the **human un-ticks** (detected by reviewer on next scan: AC N was
previously ticked, evidence-digest unchanged, now unticked), the reviewer
**must not re-tick**. Detection rule: scan feedback-stream for prior
`auto_tick` of `(task_id, N, evidence_digest=current)`. If found AND
AC is now `[ ]`, treat as **human-revoked** and write
`- action: human_untick_observed` to feedback-stream; do not re-tick.

The bound on tick attempts: at most one auto-tick per (task, AC, evidence-digest)
**ever**. If the digest changes (task body edits change the AC text or
verification artefact), the (task, AC, new-digest) is a fresh tuple and auto-tick
re-evaluates.

**Why digest-keyed:** the human's untick was a judgment on the evidence-at-that-time.
If the underlying evidence changes (the AC text was rewritten, the verification
command edited, the source files re-fixed), the human's revoke is stale —
re-evaluation is correct.

**Why feedback-stream:** it's already the durable structured record (decision 6).
Adding a new `action: auto_tick` row reuses the existing audit substrate
(`agents/reviewer/AGENT.md`, Watchtower analytics from T-1443 Spike I) instead
of inventing a sidecar file.

**Rejected:**
- "HTML comment marker in markdown" — `[ ] <!-- auto-ticked-then-untick -->` —
  pollutes the body, brittle to manual edits, conflicts with the
  comment-blindness pattern that audit/G-006 already had to work around.
- "Force human to add `[REVIEWER]:NO-AUTO` to opt out" — friction-additive,
  violates 7 UX principles (decision 6 in T-1443 — frictionless feedback).
- "Side-file `.context/working/auto-tick-state.yaml`" — duplicates
  feedback-stream and risks divergence.

## Recommendation

**GO** — file a single build child T-1950A scoped to:
- v1.0 reviewer auto-tick: `[REVIEWER]`-prefixed Agent ACs only
- Triggered inside `static_scan.py` whenever scan runs (covers manual `fw
  reviewer T-XXX` and auto invocation by `update-task.sh --status
  work-completed`)
- Evidence rule: overall PASS + zero findings on AC + currently unticked + no
  suppress override + AC text starts with `[REVIEWER]`
- Sovereignty rail: digest-keyed audit via feedback-stream; never re-tick
  same (task, ac, digest) tuple
- Tests: bats + Playwright; including the "human un-ticks, reviewer respects"
  flow

Out-of-scope for v1.0, file as follow-ups if v1.0 is stable:
- v2.0: extend to "Agent AC with matching Verification command exit 0"
- v3.0: extend to all Agent ACs (high-bar — needs the v2 dogfood signal)

## Rejected at inception level

- **"Skip inception, go straight to build"** — initial impulse, corrected.
  Even though T-1443 GO'd the principle, four implementation questions had no
  shipped answer. A build task without the design would have spec-creep on
  q4 (sovereignty rail) — the hardest of the four. Forcing the design pass
  before the build saves a re-architecture later.
- **"Inception should redo the whole reviewer auto-tick design"** — also
  initial impulse, corrected. T-1443 stands; T-1950 is the implementation
  inception, not the policy inception.

## Decisions Made (final)

1. **Trigger** — `static_scan.py` performs the write whenever scan runs (covers manual + completion-gate callers)
2. **Scope** — `[REVIEWER]`-prefixed Agent ACs only at v1.0
3. **Evidence rule** — PASS + zero per-AC findings + currently unticked + no suppress override + AC text starts with `[REVIEWER]`
4. **Sovereignty rail** — digest-keyed audit via feedback-stream; one auto-tick per (task, ac, evidence-digest) tuple; human-untick observed → record + never re-tick

## Anchor files

| Artifact | Path |
|---|---|
| Inception task body | `.tasks/completed/T-1950-g-066-deliverable-2--reviewer-auto-tick-.md` |
| Parent decision | `docs/reports/T-1443-independent-reviewer-agent.md` (decisions 36, 113, 213) |
| Substrate to extend | `lib/reviewer/static_scan.py` v1.4 |
| Override mechanism | `lib/reviewer/overrides.py` (T-1443 Spike I) |
| Feedback stream | `.context/working/feedback-stream.yaml` |
