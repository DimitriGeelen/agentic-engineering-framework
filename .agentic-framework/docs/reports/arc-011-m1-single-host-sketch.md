# arc-011 M1 single-host reference sketch

**Task:** T-2326 (agent-side design sketch, no source change)
**Arc:** arc-011 parallel-execution-aef
**Companion artefact:** `docs/reports/arc-011-grill-me-responses.md` (T-2325 §3)
**ADR:** `docs/architecture/parallel-execution-aef.md`
**Written:** 2026-06-11 (agent-prep for operator's milestone-split decision)
**Posture:** **DESIGN SKETCH FOR GRILLING, NOT IMPLEMENTATION SPEC.** Each
workstream is "what M1 *could* look like," not "what M1 *is*." The operator
approves/rescopes/rejects each piece before any build task is filed.

---

## Intent

T-2325 §3 proposed treating arc-011 as a two-milestone arc:

- **M1** — single-host parallel + headline_mechanic demo, AEF-only,
  closeable without TermLink substrate primitives
- **M2** — ring20 multi-host scale-up, substrate-bound

§3 named 6 AEF-only workstreams but did not concretize them. Without
concretization, the milestone-split proposal can be grilled as hand-wave —
"single-host parallel" doesn't tell the operator what changes where, how
big it is, or how each piece moves toward the headline_mechanic firing.

This artifact concretizes the 6 workstreams so the operator can grill the
M1 proposal on **cost, scope, and headline-mechanic traceability** rather
than on "but is it real work?" The operator's three possible answers, in
ascending commitment:

1. **REJECT the split.** Keep arc-011 as one milestone, substrate-bound.
   This sketch becomes a discarded artifact. No build tasks filed.
2. **RESCOPE the split.** Approve some workstreams, defer/cut others.
   Build tasks filed only for approved workstreams.
3. **APPROVE the split as proposed.** File 6 build tasks per this sketch,
   sequence them per the §dependencies block below, ship M1.

The operator's decision goes nowhere agent-side. The agent has no authority
to approve the split or file the implementing build tasks.

---

## Common context for all 6 workstreams

**Substrate assumption.** Single-host AEF: two `claude -p` workers spawned
from one operator machine, dispatched by an in-process orchestrator script,
integrating through a shared local git working tree (no TermLink hub, no
remote integration queue). All "substrate primitives" needed (claim/exclusive
delivery, idle/busy registry) are replaced by local files + in-process
locks on the operator's box.

**Frontmatter contract.** Each AEF task carries a `write_set:` frontmatter
field naming the file globs the task will write. Optional `depends_on:`
remains as today. The orchestrator-graph spike (§1 below) reads both.

**Headline_mechanic restated.** From arc-011.yaml:
> "two agents on disjoint-write-set tasks run concurrently ... operator
> observes ... two dispatch IDs in flight at once in dispatches.jsonl ...
> absence of governance-plane corruption (no .tasks/ or .context/audits/
> merge conflicts)"

M1 ships when, on a single operator host:
- `.context/dispatches.jsonl` contains two `in_flight` rows whose `started_at`
  windows overlap; both reach `status: completed` `exit_code: 0`.
- `git -C .tasks/ status --porcelain` shows no merge-conflict markers
  during or after the parallel run.

Each workstream's exit criterion below traces back to one of these two
observable outcomes.

---

## 1. Orchestrator-graph spike (T-2303 IW-3 reopen on M1 path)

**T-2325 §3 ref:** workstream #1 ("orchestrator-graph spike").
**T-2303 ref:** IW-3 (parallel-execution-strategy-spike) deferred at GO.

**What it ships.** A new file `agents/orchestrator/orchestrator-graph.py`
that reads `.tasks/active/T-*.md` frontmatters, builds an in-memory
dependency+write-set graph, and emits a sequence of dispatch calls. Inputs:
the active task pool. Outputs: a list of `(task_id, dispatch_mode)` tuples
where `dispatch_mode ∈ {parallel, serial}`.

**Files touched.**
- `agents/orchestrator/orchestrator-graph.py` (new, ~150 lines)
- `tests/unit/test_orchestrator_graph.bats` (new) — file 3-4 tasks with
  declared write_sets, assert correct dispatch sequence
- `lib/orchestrator.sh` (new helper, optional — provides `fw orchestrator
  next-dispatch` CLI verb that invokes the python)
- `bin/fw` — `cmd_orchestrator()` extension for `next-dispatch` subverb (~5 lines)

**Size:** **M.** ~150 lines python + ~80 lines bats + ~30 lines fw plumbing.

**Cost rationale:** the parsing is straightforward (yaml frontmatters
already structured); the graph logic is standard topological + interval
overlap; no substrate primitive needed.

**Exit criterion.** `fw orchestrator next-dispatch` returns
`[(T-A, parallel), (T-B, parallel), (T-C, serial)]` for a hand-crafted
input where T-A and T-B have disjoint write-sets and T-C depends on T-A.
This is the AEF policy decision-maker the headline_mechanic needs — without
it, "two dispatch IDs in flight" can't be authored, only observed by
accident.

**Headline_mechanic traceability.** Direct: this workstream IS the
"orchestrator decides what runs in parallel" decision the headline_mechanic
fires on. Required for the parallel run to be intentional rather than racy.

---

## 2. Harness yield-point spike (T-2323 AEF-IC-1 collapse to M1-scoped)

**T-2325 §3 ref:** workstream #2 ("harness yield-point spike").
**T-2323 ref:** AEF-IC-1 inception deferred — yield-point granularity.

**What it ships.** A small instrumentation layer in `agents/dispatch/` that
checks a local flag file before each `Write` / `Edit` tool call. If the flag
is set, the agent pauses, reads a queued message, and decides whether to
yield. This is the §5 cooperative-poll mechanism in single-host form — no
TermLink presence, no sidecar — just a file the orchestrator writes when it
wants to inject a "stop writing there" signal.

**Files touched.**
- `agents/dispatch/yield-point.sh` (new, ~50 lines) — read flag, drain
  queued messages, exit non-zero to refuse write if "do not write" message
  matches the target path
- `agents/dispatch/preamble.md` (edit) — add yield-point invocation
  instructions for dispatched workers
- `tests/unit/test_yield_point.bats` (new, ~60 lines) — set flag, run a
  dispatch wrapper, assert correct refusal
- `.context/working/.dispatch-flag` (new convention) — orchestrator writes
  this; worker reads

**Size:** **S.** Pure shell + bats. Single-host doesn't need the sidecar +
heartbeat staleness mechanism (§5 of AEF ADR) — that's M2 territory.

**Cost rationale:** local file flag is the cheapest possible yield
mechanism. Worker process polls the file via `[ -e ... ]` between tool
calls — already at a natural shell boundary in the dispatch wrapper.

**Exit criterion.** Manual test: orchestrator writes `dispatch-flag` with
content `refuse-write:/path/to/SHARED.md`; worker about to write
`/path/to/SHARED.md` reads the flag, refuses the write, exits non-zero;
orchestrator captures the refusal in `dispatches.jsonl.outcome`. This
proves the §5 cooperative-poll claim on M1 scale.

**Headline_mechanic traceability.** Indirect: this workstream enables the
disjointness gate (§6 below) to act in real-time, not just at pre-flight.
Without it, a write_set declaration found to be wrong mid-flight has no
remediation path — the worker just collides.

---

## 3. Disjoint-write-set policy validator (T-2324 AEF-IC-2 collapse to M1-scoped)

**T-2325 §3 ref:** workstream #3 ("disjoint-write-set policy spike").
**T-2324 ref:** AEF-IC-2 inception deferred — policy shape.

**What it ships.** A pure static validator that reads two task frontmatters
and reports `disjoint | overlap | undecidable`. Implements the "static
declaration" candidate from T-2324's Problem Statement (operator picks
between static / dynamic / hybrid; M1 picks static, M2 may revisit).

**Files touched.**
- `lib/write_set.py` (new, ~80 lines) — read frontmatter, expand globs
  against the working tree, compare path sets
- `bin/fw` — `cmd_write_set()` for `fw write-set check T-A T-B` (~15 lines)
- `tests/unit/test_write_set.bats` (new, ~80 lines) — disjoint case,
  overlap case, glob-collision case (e.g. `**/T-*.md` vs `.tasks/active/T-X.md`),
  empty-write-set case
- `agents/orchestrator/orchestrator-graph.py` (extend from §1) — call
  `write_set.is_disjoint(t1, t2)` when computing parallelism

**Size:** **M.** ~80 lines python + ~80 lines bats + plumbing.

**Cost rationale:** glob expansion is cheap and bounded; the comparison
is set intersection on path strings; the "undecidable" case (write_set
not declared) is a single test against frontmatter presence.

**Exit criterion.** `fw write-set check T-PAR-A T-PAR-B` returns `disjoint`
when T-PAR-A's write_set is `[docs/reports/T-PAR-A.md]` and T-PAR-B's is
`[docs/reports/T-PAR-B.md]`. Same call on T-COL-A + T-COL-B (both writing
`docs/SHARED.md`) returns `overlap`. The validator is the AEF policy
decision-maker that the orchestrator-graph spike consults.

**Headline_mechanic traceability.** Direct: this workstream IS the "tasks
with disjoint write-sets" decision the headline_mechanic depends on. The
orchestrator can't dispatch two tasks in parallel without proof of
disjointness; this is the proof generator.

---

## 4. Single-host parallel demo

**T-2325 §3 ref:** workstream #4 ("single-host parallel demo").

**What it ships.** A scripted end-to-end demo that runs M1 headline_mechanic
on the operator's machine. Two file-write-only tasks are filed; the
orchestrator emits parallel dispatch; two `claude -p` workers spawn; both
complete; the dispatches.jsonl shows overlapping in-flight rows and the
.tasks/ tree stays clean.

**Files touched.**
- `agents/dispatch/single-host-parallel-demo.sh` (new, ~100 lines) —
  spawns two `claude -p` subprocesses via background `&`, captures their
  PIDs, polls until both `exit_code` rows appear in `dispatches.jsonl`,
  asserts the overlap predicate
- `tests/integration/test_single_host_parallel.bats` (new) — runs the demo
  in a sandbox tasks dir
- `docs/reports/arc-011-m1-headline-mechanic-evidence.md` (new) — captured
  dispatches.jsonl excerpt + screen-shot of clean .tasks/ status from a
  successful run

**Size:** **L.** Orchestrating two subprocess workers + parsing dispatches.jsonl
+ asserting overlap + capturing wire-evidence is the most complex piece.

**Cost rationale:** the worker spawning is simple; the parsing is jq +
awk; the overlap-window assertion is a 3-line condition. The complexity
is in repeatability under sandbox conditions (test tasks dir isolation,
git-state cleanup between runs).

**Exit criterion.** `bash agents/dispatch/single-host-parallel-demo.sh`
exits 0 AND the captured dispatches.jsonl excerpt + clean git status are
written to `arc-011-m1-headline-mechanic-evidence.md`. THIS workstream IS
the headline_mechanic firing — the others are infrastructure; this is the
demo.

**Headline_mechanic traceability.** Direct: this workstream IS the
headline_mechanic firing. arc-011's `demo_evidence:` field becomes
non-null when this artefact lands.

---

## 5. /orchestrator/parallel view (Watchtower)

**T-2325 §3 ref:** workstream #5 ("/orchestrator/parallel view").

**What it ships.** A new Watchtower page that reads `.context/dispatches.jsonl`
and renders all in-flight dispatches side-by-side, refreshing every 2s.
Lets the operator visually verify the headline_mechanic fired during a
live run.

**Files touched.**
- `web/blueprints/orchestrator.py` (new, ~80 lines) — Flask blueprint
  with `/orchestrator/parallel` route; reads dispatches.jsonl, filters
  rows without `completed_at`, returns JSON to the template
- `web/templates/orchestrator/parallel.html` (new, ~50 lines) — htmx-powered
  card-per-dispatch view, auto-refresh, color-code by elapsed time
- `web/app.py` (edit) — register the new blueprint
- `tests/playwright/test_orchestrator_parallel.py` (new, ~40 lines) —
  navigate to /orchestrator/parallel during a fake dispatch, assert
  expected DOM

**Size:** **M.** Flask + htmx + Playwright — standard Watchtower page
pattern, sibling of existing /dispatches and /tasks pages.

**Cost rationale:** read-only — no writes, no Tier-1 escalation. The
implementation is largely template work; the parsing is a simple
dispatches.jsonl filter.

**Exit criterion.** During a parallel run, opening `/orchestrator/parallel`
in a browser shows two cards (one per in-flight dispatch) with elapsed
timers. After both complete, the page shows "0 dispatches in flight"
within 2s of the second completion.

**Headline_mechanic traceability.** Indirect: this workstream makes the
"operator observes" clause user-friendly. The headline_mechanic technically
fires once dispatches.jsonl has the two rows; this workstream just makes
that observation visual instead of grep-based. Could be cut for M1 if
the operator accepts grep-based observation; recommended for inclusion
because it makes future operator engagement with arc-011 demos
substantially easier.

---

## 6. Disjointness gate pre-flight (orchestrator extension)

**T-2325 §3 ref:** workstream #6 ("disjointness gate pre-flight").

**What it ships.** A pre-dispatch hook inside the orchestrator that, before
emitting a dispatch envelope for T-X, scans all currently-in-flight
dispatches in `dispatches.jsonl` and refuses if any has a write_set
overlapping T-X's. Reuses §3's validator.

**Files touched.**
- `agents/orchestrator/orchestrator-graph.py` (extend from §1) —
  `pre_flight_check(task_id)` that scans dispatches.jsonl + calls
  write_set validator
- `lib/orchestrator.sh` (extend from §1) — `fw orchestrator dispatch T-XXX`
  routes through pre_flight_check
- `tests/unit/test_orchestrator_preflight.bats` (new, ~60 lines) —
  manually inject an in-flight dispatch into a sandbox dispatches.jsonl,
  attempt to dispatch a colliding task, assert refusal
- `docs/architecture/parallel-execution-aef.md` (no edit — already
  describes this in §3 "conservative launch")

**Size:** **S.** Mostly extends §1's orchestrator-graph code. ~30 lines
extension + bats.

**Cost rationale:** the dispatches.jsonl scan is bounded by current
in-flight count (typically 1-3); the validator is already shipped in §3.

**Exit criterion.** A test scenario: T-COL-A is in flight; orchestrator
attempts to dispatch T-COL-B (same write_set as T-COL-A). The dispatch
returns refused with reason "write_set overlap with in-flight dispatch
D-001". This is the AEF-ADR §3 "conservative launch policy" made
operational.

**Headline_mechanic traceability.** Direct: this workstream IS the gate
that protects "absence of governance-plane corruption." Without it, two
workers writing the same file just race; with it, the second never starts.

---

## §dependencies — what must ship before what

The 6 workstreams have an implicit DAG:

- **§3 (disjoint validator)** depends on nothing — purely shell+yaml. SHIPS FIRST.
- **§1 (orchestrator-graph)** consumes §3 — needs the disjoint check to compute
  parallel-vs-serial. SHIPS SECOND.
- **§6 (disjointness gate pre-flight)** extends §1 + reuses §3 — SHIPS THIRD.
- **§2 (harness yield-point)** is independent of §1/§3/§6 — pure worker-side.
  SHIPS IN PARALLEL with §3.
- **§4 (single-host parallel demo)** consumes §1+§3+§6 + optionally §2 —
  SHIPS PENULTIMATELY.
- **§5 (/orchestrator/parallel view)** is independent — pure Watchtower. SHIPS
  WHENEVER (recommend after §4 so the demo's data feeds the view).

**Sequencing recommendation for build tasks (if operator approves split):**

```
T-2327 §3 disjoint validator (S)         ──┐
T-2328 §2 harness yield-point (S)        ──┤
                                            ├──→  T-2330 §1 orchestrator-graph (M)
                                            │     ──→  T-2331 §6 pre-flight gate (S)
                                            │             ──→  T-2332 §4 demo (L)
                                            │                       ──→  T-2333 §5 view (M)
```

**Total size estimate:** S+S+M+S+L+M = roughly **M+L+M+L** ≈ 4-7 build sessions.
Three workstreams could ship in parallel (§3, §2 in early phase; §5 alongside §4).

---

## What this is NOT

This artifact is a **DESIGN SKETCH FOR GRILLING**, not an implementation spec.
Concretely:

- **NOT a milestone-split decision.** T-2325 §3 *proposed* the split. The
  operator has not approved. This sketch describes what M1 *could* look
  like IF the operator approves the split. If REJECTED, this artifact is
  filed and not built.
- **NOT a build task batch.** No T-23XX build tasks have been filed under
  this sketch's authority. The sequencing table above is a recommendation
  block, not pre-emptive filing. Filing 6 build tasks before operator
  approval would be the cluster-bombing anti-pattern T-2303's grill page
  warned against.
- **NOT a contract with the substrate side.** The "single-host" framing
  means M1 ships without TermLink primitives. M2 (substrate-bound multi-
  host) remains a separate decision; this artifact takes no position on
  M2 timing or shape.
- **NOT a §6-question resolver for the AEF ADR.** The §6 open questions
  in the AEF ADR (yield-point granularity, heartbeat tick/threshold, flag
  shape, scale ceiling, optimistic-flip criteria) are inception territory
  (T-2323/T-2324). This sketch picks an M1-scope answer for yield-point
  granularity (§2 picks "before every file-write tool call" — the leading
  candidate already named in the ADR), but does not resolve the questions
  for M2.
- **NOT a commit-to-ship.** Size estimates are nominal Q-sizes. Real cost
  emerges during build. The operator's right to rescope mid-stream is
  preserved.

## Cross-references

- T-2325 grill responses: `docs/reports/arc-011-grill-me-responses.md` (§3
  is the workstream listing this sketch concretizes)
- AEF ADR: `docs/architecture/parallel-execution-aef.md` (§N references
  in each workstream above)
- arc-011 yaml: `.context/arcs/parallel-execution-aef.yaml`
- Anchor task: `.tasks/completed/T-2303-scoping-inception--parallel-execution-ar.md`
- Sibling parked inceptions: T-2323 (collapsed to §2 here for M1 scope),
  T-2324 (collapsed to §3 here for M1 scope)
