---
id: T-3204
name: "budget gauge divides by a constant window while knowing the model - continuous-run
  self-trigger fires at 2 percent of real capacity"
description: >
  budget gauge divides by a constant window while knowing the model - continuous-run
  self-trigger fires at 2 percent of real capacity

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: [T-2377, T-2885, T-3182]
arc_id: continuous-run
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
# demo_target: true               # T-2286: optional — marks task as reserved for an orchestrated demo
#                                 # worker (e.g. arc-010 HM-A dispatches via mcp__fw__work_on). When set,
#                                 # `fw work-on T-XXX` refuses unless --i-am-demo-orchestrator (CLI) or
#                                 # FW_I_AM_DEMO_ORCHESTRATOR=1 (env) is passed. Prevents the parent
#                                 # session from consuming the captured→started-work transition the demo
#                                 # worker expects to drive. Origin OBS-057.
created: 2026-08-28T12:39:01Z
last_update: '2026-08-28T12:45:16Z'
date_finished:
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── BVP scoring fields (T-1918, arc-006). See docs/reports/T-1915-bvp-inception.md for semantics. ──
# bvp_scores:                     # confirmed per-driver scores 0-5, set by `fw bvp confirm` (T-1924).
#                                 # Sovereignty boundary — only set after human or agent confirmation.
#                                 # Shape: {D1: <int 0-5>, D2: <int 0-5>, D3: <int 0-5>, D4: <int 0-5>, [<free-driver-id>: <int>]...}
# bvp_scores_proposed:            # estimator-proposed scores (T-1922 worker). Persists when ≥2 delta
#                                 # from bvp_scores: on any driver (M3 v2-delta). Shape: list of timestamped entries.
# cost_estimate:                  # F8 composite: 0.6×blast_radius + 0.3×tier + 0.1×effort.
#                                 # Q2 fallback: T-shirt S/M/L/XL mapped to 2/4/6/8 when blast_radius is not yet computable.
cost_estimate_proposed:
  - ts: '2026-08-28T12:45:09Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=277,acs=8)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-28T12:45:16Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      Discard fidelity: 0
      Loop closure (conditional): 0
      D1: 4
      D2: 0
      D3: 3
      D4: 3
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: Discard fidelity=0 (no-signal); Loop closure (conditional)=0 
      (no-signal); D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=3 (body:portability-abstraction); 
      F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-3204: budget gauge divides by a constant window while knowing the model

## Context

**This task was filed on a wrong premise and narrowed before any code changed.
The original framing is preserved in the Decisions section below, because the
correction is the more useful artefact.**

`CONTEXT_WINDOW` (default 300000) is a **deliberate cost-and-quality cap**, not an
estimate of the model's context window. Its own comment says so, identically in
both gauges (`agents/context/checkpoint.sh:29-31`,
`agents/context/budget-gate.sh:101-103`):

    # Context window size — conservative default, override via FW_CONTEXT_WINDOW.
    # Opus 4.6 supports 1M but 300K is a safe default for quality + cost control.
    CONTEXT_WINDOW=$(fw_config_int "CONTEXT_WINDOW" 300000)

So the number is not wrong. **What is wrong is that the reader-facing messages
report it as a measurement of the window** — five said "% of context window"
outright, and four more printed a bare `(~N%)` naming no denominator at all.

Measured on this session, 2026-08-28, before any change:

| quantity | value | source |
|---|---:|---|
| dominant model in transcript | `claude-opus-5` | 106/106 of last 400 usage entries |
| context tokens in scope | 155,120 | `lib/context_tokens.py` |
| `CONTEXT_WINDOW` in force | 300,000 | no `.framework.yaml` override; the default |
| gauge reading | **51%** | reported as "% of context window" |
| what 51% actually is | 51% **of the configured cap** | — |

And `lib/context_tokens.py` computes `dominant_model` (line 75) in order to scope
usage entries to this conversation (T-2885), then **discards it** — `main()` printed
only the token count. So nothing anywhere reported *which model* the cap was being
applied to, and the comment justifying the cap still named **Opus 4.6** while the
session ran **claude-opus-5**.

**Why this matters to arc-012 specifically.** The arc's bounded-autonomy ceiling is
this ladder: `TOKEN_CRITICAL = CONTEXT_WINDOW × 95 / 100`. An operator tuning that
ceiling — or an agent deciding whether to start one more piece of work — reads "95%
of context window" and understands *a hard limit is approaching*. It is in fact *a
policy dial sitting at its configured value*. Those two readings license opposite
actions: the first says stop because you must, the second says stop because we
chose to, and only the second is something the operator can revisit.

**What is NOT established, and is therefore not in scope.** Whether 300000 is still
the right cap for `claude-opus-5`. There is no trustworthy measurement of this
model's context window here — the harness figure first reached for decrements
per-turn like a cumulative session budget, not like a window — and a deliberate
cost-control policy should not be converted into a derived value on the strength of
a number that cannot be sourced. **That is an operator decision and it is surfaced,
not taken** (see the Recommendation section).

**Scope fence.** Make the cap legible as a cap and name the model it applies to. Do
not change its value, the ladder ratios (75/85/95), the numerator
(`compute_context_tokens` is correct), or the auto-restart mechanism.

## Acceptance Criteria

### Agent
- [x] **REPRODUCE FIRST.** Before changing anything, print the dominant model, the
      in-scope token count, the configured cap, and the reported percentage from the
      live transcript. If the messages already distinguish cap from window, this
      task is wrong and closes as such.
      → `claude-opus-5` / 155,120 tokens / cap 300,000 / reported "51% of context
      window"; five echo sites confirmed misleading. The task is not wrong.
- [x] `lib/context_tokens.py` can emit the dominant model, **opt-in**, leaving its
      default stdout byte-identical. Both gauges parse that stdout as a bare integer
      today; an unconditional extra field would silently corrupt `CONTEXT_TOKENS` in
      both callers at once.
      → `--with-model` prints tokens TAB model; default prints the bare integer.
- [x] All reader-facing messages name the denominator for what it is (a configured
      budget cap), not "context window". Verified by grep returning zero remaining
      misleading echo sites in those two files.
      → **9 sites**, not the 5 originally counted. The first count missed four
      `(~N%)` messages that named no denominator at all — ambiguous in the same
      direction, and leaving them would have half-done the fix.
- [x] The cap's **value is unchanged at 300000** and `FW_CONTEXT_WINDOW` /
      `fw config set CONTEXT_WINDOW` still override it. Pinned by test — this task
      must be provably non-behavioural on the ladder.
      → measured: default reports 63%, `FW_CONTEXT_WINDOW=1000000` reports 19% and
      names the new cap. Value and 75/85/95 ladder pinned by tests 10 and 11.
- [x] Mutation-tested. State which mutation reddened which test. A suite that stays
      green when the wording is reverted asserts nothing.
      → five mutations, table in the RCA section. **Two of them (M3, M4) reddened
      nothing on the first pass and the tests were repaired**, which is the finding.
- [x] **CONTROL LEG.** A test asserts the model IS emitted when asked for, paired
      with one asserting default stdout is unchanged. Without the pair, "opt-in
      works" and "the flag is ignored and nothing ever emits" are the same
      observation — the defect class this task belongs to.
      → test 1 (CONTROL, default is a bare integer) pairs with test 2 (opt-in
      emits). M2 reddens test 1, confirming the pair discriminates.

### Human
- [ ] [REVIEW] Decide whether 300000 is still the right budget cap for
      `claude-opus-5`, now that the number is legible as a dial rather than a limit.
  **Steps:**
  1. `bin/fw config get CONTEXT_WINDOW`
     (empty output means the 300000 default is in force)
  2. `cd /opt/999-Agentic-Engineering-Framework && ./agents/context/checkpoint.sh status`
     — read the cap, the percentage, and the model it is being applied to
  3. Decide: keep 300000, or set a new value with
     `cd /opt/999-Agentic-Engineering-Framework && bin/fw config set CONTEXT_WINDOW <tokens>`

  **Expected:** a deliberate answer either way. The cap governs when the arc-012
  continuous loop self-restarts (`TOKEN_CRITICAL = cap × 95 / 100`), so it is the
  bounded-autonomy ceiling in practice — and it has not been revisited since its
  justifying comment named Opus 4.6.

  **If not:** leave it at 300000; nothing regresses. This AC exists because the
  agent explicitly declined to make this call — see the Context section, "What is
  NOT established". Tick it once you have decided, either way.

## Verification

bash -n agents/context/checkpoint.sh
bash -n agents/context/budget-gate.sh
python3 -c "import ast; ast.parse(open('lib/context_tokens.py').read())"
out=$(timeout 300 bats tests/unit/t3204_budget_cap_legibility.bats 2>&1); echo "$out" | grep -q "^ok 12" && ! echo "$out" | grep -q "^not ok"
if grep -q '^[[:space:]]*echo.*of context window' agents/context/checkpoint.sh agents/context/budget-gate.sh; then exit 1; fi
printf 'x' | python3 lib/context_tokens.py "" > /tmp/.t3204a 2>&1 && grep -qx "0" /tmp/.t3204a
grep -c 'fw_config_int "CONTEXT_WINDOW" 300000' agents/context/budget-gate.sh > /tmp/.t3204b && grep -qx "1" /tmp/.t3204b
diff -q lib/context_tokens.py .agentic-framework/lib/context_tokens.py
diff -q agents/context/checkpoint.sh .agentic-framework/agents/context/checkpoint.sh
diff -q agents/context/budget-gate.sh .agentic-framework/agents/context/budget-gate.sh

## RCA

**Symptom:** every reader-facing budget message reported the ratio as a fraction of
the "context window", when the denominator is a configured cost-and-quality cap.

**Root cause:** the variable is named `CONTEXT_WINDOW` and the messages were written
from the name rather than from the comment two lines above it, which has said "a safe
default for quality + cost control" since it was introduced. The name describes a
physical property; the value is a policy dial. Nine messages inherited the name's
meaning instead of the value's.

**Why structurally allowed:** nothing distinguishes the two readings *at the point of
use*. A percentage of a cap and a percentage of a window are both plausible
percentages, so the output is never anomalous, and the one thing that could have
disambiguated it — the model the cap is applied to — was computed by
`lib/context_tokens.py:75` and discarded before it reached any caller. The justifying
comment named **Opus 4.6** while the session ran **claude-opus-5**, and nothing
re-asked, because nothing consumed the model.

**Prevention:** `tests/unit/t3204_budget_cap_legibility.bats` — 12 tests. Test 7 fails
if any echo site reverts to the old phrasing; tests 10 and 11 fail if anyone converts
the cap into a derived value or moves the ladder, which is the change this task
explicitly refused to make on the operator's behalf.

### Mutation results

Five mutations. **Two reddened nothing on the first pass**, and that is the part worth
keeping:

| # | mutation | reddened | note |
|---|---|---|---|
| M1 | revert the wording in `checkpoint.sh` | tests 7, 8 | — |
| M2 | make `--with-model` unconditional | test 1 (CONTROL) | the contract-corrupting change |
| M3 | parse the flag positionally again | **nothing** → test 4 after repair | see below |
| M4 | report a model beside a refused count | **nothing** → test 5 after repair | see below |
| M5 | change the cap 300000 → 400000 | test 10 | — |

**M3 was not a mutation at all.** The test asserted that a positional parse would
swallow `--with-model` as a timestamp and filter every entry away. It does swallow it
— and filters nothing, because every flag starts with `-` (0x2D), which sorts *below*
every ISO-8601 digit, so `entry_ts < session_start_ts` is false for all entries. The
two implementations produce identical output for every flag. The test's own comment
stated the opposite and was wrong. Repaired by adding the case where they genuinely
differ: flag first, real timestamp second.

**M4 never reached the mutated line.** The test fed an *empty* transcript, which
returns from `if not entries` and never touches the `len(in_scope) < 2` floor the
mutation edits. Repaired with a one-entry fixture; the empty case kept as a separate
test, since it pins a different branch.

Both are the same shape as the defect above, and as T-3199's inert `!` assertions: **a
check that passes for a reason unrelated to the thing it names.** A mutation that
fails to mutate is a false green about the test, not about the code — and neither
would have been caught by reading the suite, only by breaking the thing it covers.

## Evolution

### 2026-08-28 — the finding inverted under checking

- **What changed:** the defect as filed does not exist. `CONTEXT_WINDOW` is a
  deliberate cap, documented as such in its own comment, and the evidence for the
  "real" window was an unsourced harness number. What does exist is narrower and
  still real: nine messages report the cap as a measurement, and the model it is
  applied to was computed and thrown away.
- **Plan impact:** the model-to-window resolution table, which was the centre of the
  original plan, is gone entirely. No value changes. The task became wording plus an
  opt-in field, and the interesting decision moved to the operator.
- **Triggered:** no new tasks. The one open question — whether 300000 is still the
  right ceiling for `claude-opus-5` — is a Human AC on this task rather than a
  filing, because it is a decision, not a defect.

## Recommendation

**Recommendation:** GO

**Rationale:** The code change is complete, non-behavioural on the budget ladder, and
pinned by a mutation-tested suite. What remains is a single decision that is yours by
construction: the cap governs when the arc-012 continuous loop restarts itself, and I
declined to change it on the strength of a number I could not source. Everything
needed to make that call in thirty seconds is now printed by `checkpoint.sh status`,
which it was not before.

**Evidence:**
- 9 reader-facing messages reworded; 0 misleading echo sites remain in either gauge.
- `lib/context_tokens.py` emits the dominant model opt-in; default stdout is
  byte-identical, pinned by the CONTROL test that mutation M2 reddens.
- Cap value (300000) and the 75/85/95 ladder pinned unchanged by tests 10 and 11.
- `FW_CONTEXT_WINDOW` override measured working: 63% → 19%, message names the new cap.
- 12/12 tests green; five mutations each redden a named test — after two of them (M3,
  M4) exposed tests that asserted nothing and were repaired.
- Three vendored copies synced and verified identical.

## Decisions

### 2026-08-28 — filed on a wrong premise, narrowed before any code changed

- **Chose:** retract the original framing and reduce the task to legibility.
- **Why:** the task was filed as *"the gauge divides by a constant while knowing the
  model; the loop self-triggers at 1.9% of real capacity"*, on two claims that did not
  survive checking. First, `CONTEXT_WINDOW` is a **deliberate** cap — its own comment
  says "a safe default for quality + cost control" — not a stale guess at the window,
  so there was no derivation bug to fix. Second, "real window = 15,000,000" came from
  a harness figure that decrements per turn, i.e. behaves like a cumulative session
  budget rather than a context window. It could not be sourced, so it was dropped.
- **Rejected:** deriving the cap from a model-to-window table, which was the original
  plan and would have been the more impressive change. It converts a cost-control
  policy into a computed value — an authority change the operator owns (CLAUDE.md
  §Autonomous Mode Boundaries) — on the strength of a number that had just failed
  verification. Surfaced as a Human AC instead.
- **Note:** the task title still describes the original premise. Left as filed so the
  correction is legible in the record rather than tidied out of it.

### 2026-08-28 — nine sites, not five

- **Chose:** reword four additional `(~N%)` messages that named no denominator.
- **Why:** they are ambiguous in the same direction. Fixing only the five that said
  "context window" would leave a reader with a bare percentage of nothing named.
- **Rejected:** holding to the AC's literal count of five. The AC records the
  discrepancy rather than being quietly satisfied.

## Updates

### 2026-08-28T12:39:01Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Context:** Initial task creation
