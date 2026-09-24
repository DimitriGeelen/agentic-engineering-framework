---
id: T-3445
name: "Reviewer-closeable delegation: fw task delegate converts a human-owned task's
  deterministic [REVIEW] criteria to [REVIEWER] Agent criteria, refuses carve-outs
  (taste, inception decision, act-in-the-world, tier0/bypass, sovereignty field, render
  surface), takes agent ownership, and lets a PASS verdict from fw reviewer close
  it (operator ruling 2026-09-23)"
description: >
  Reviewer-closeable delegation: fw task delegate converts a human-owned task's deterministic
  [REVIEW] criteria to [REVIEWER] Agent criteria, refuses carve-outs (taste, inception
  decision, act-in-the-world, tier0/bypass, sovereignty field, render surface), takes
  agent ownership, and lets a PASS verdict from fw reviewer close it (operator ruling
  2026-09-23)

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
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
created: 2026-09-23T11:45:08Z
last_update: '2026-09-24T15:15:11Z'
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
bvp_scores_proposed:
  - ts: '2026-09-23T11:47:27Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 3
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 1
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=3
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=1 
      (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-09-24T15:15:11Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=326,acs=9)
    rubric_sha: e4a00f38e801
---

# T-3445: Reviewer-closeable delegation: fw task delegate converts a human-owned task's deterministic [REVIEW] criteria to [REVIEWER] Agent criteria, refuses carve-outs (taste, inception decision, act-in-the-world, tier0/bypass, sovereignty field, render surface), takes agent ownership, and lets a PASS verdict from fw reviewer close it (operator ruling 2026-09-23)

## Context

Operator ruling 2026-09-23, recorded as the decision this task cites (see `bin/fw decisions`,
"Reviewer-closeable delegation"): "if it is not high risk, agent can use the reviewer agent
which is critical for review and with a positive outcome close it." Measurement behind it:
832's `tools/_t770-delegation-boundary.py` over 342 open criteria found REVIEWER-CLOSEABLE 0,
AGENT-SELF 130, OPERATOR-ONLY 212, with every deterministic Human criterion written `[REVIEW]`
(84 of 84); our corpus on 2026-09-23 shows 43 of 43 above-median now-tasks `owner: human`
(join over `fw bvp --include-proposed`). The delegation the operator grants reaches nothing.

What already exists and is reused, not rebuilt: `[REVIEWER]` Agent criteria auto-tick on a
PASS verdict with zero findings (T-1985, `lib/reviewer/static_scan.py`); the routing ladder
T-1878 / T-1947 / T-2143 / T-2147 classifies criteria at author and reviewer time; the
render-surface gate (T-1766) and the prose-vocabulary detector (T-1947) define two of the
carve-outs; `fw reviewer T-XXX` writes `## Reviewer Verdict`. What is missing is the act of
delegation itself: a verb that classifies a human-owned task's open Human criteria, converts
the deterministic ones, refuses the carve-outs, moves ownership, logs it, and makes the
delegable surface visible. There is no `fw` verb that sets `owner:` today (found while
assigning T-3440/T-3442/T-3443/T-3444 by file edit under the operator's explicit approval).

## Acceptance Criteria

### Agent
- [x] `lib/delegation.py` (or bash + embedded python matching neighbours) classifies one
      criterion into exactly one class: `deterministic` (Expected is a shell check, curl, grep,
      file-exists, exit code, or a `[RUBBER-STAMP]`/`[REVIEWER]`-shaped step list),
      `taste` (T-1947 vocabulary: reads clearly, tone, voice, rhythm, intuitive, feels right,
      cohesive, cleanly, unambiguous, actionable, layout reads clean), `inception-decision`
      (task is `workflow_type: inception`, or the criterion asks for go/no-go/defer),
      `act-in-the-world` (publish, deploy, send, post to an external service, pay,
      delete remote state), `tier0-or-bypass` (Tier 0 approval, force/skip flags,
      `FW_ALLOW_*`), `sovereignty-field` (`bvp confirm`, arc close/approve-driver/abandon,
      ownership change), `render-surface` (task components or diff touch the Watchtower
      render paths). Unit tests: at least two
      fixtures per class plus one ambiguous fixture that must resolve to the human-side class
      ("when in doubt, human" stays the tie-break).
      **Evidence:** `lib/delegation.py` — 9 classes (the 7 above, plus `agent-self` for the
      T-2143 audience axis which AC 4's three-way roll-up needs, plus `unclassified` as the
      tie-break sink), each mapping to exactly one delegation class via `CLASS_TO_DELEGATION`.
      Vocabularies imported from `lib/reviewer/static_scan.py`; render patterns parsed out of
      `lib/render_surface.sh`. `tests/unit/test_delegation_classifier.py` — 27 tests, two
      fixtures per class, a control leg on render-surface, and
      `test_ambiguous_resolves_to_the_human_side`.
- [x] `fw task delegate T-XXX [--dry-run]` on a Human-criteria-bearing task: prints one line per
      Human criterion with its class; converts every `deterministic` one to an Agent
      criterion prefixed `[REVIEWER]` keeping Steps/Expected/If-not verbatim; leaves every
      carve-out criterion under the Human subhead untouched; adds the reviewer-PASS line to the
      Verification block once; sets
      `owner: agent` only when no Human criterion remains, otherwise leaves `owner: human` and
      says so; writes an Updates entry naming the ruling decision id, the converted
      indices and the refused classes; appends one JSON line to
      `.context/working/delegations.jsonl` (task, ts, converted, refused, ruling). `--dry-run`
      writes nothing. Refuses with exit 2 on inception tasks and on tasks in `completed/`.
      **Evidence:** `lib/delegation_cli.py:cmd_delegate`, routed from `bin/fw` `route_task`.
      Pinned by `tests/unit/t3445_delegation_close_path.bats` tests 1, 5, 7, 8, 9, 10. The
      emitted Verification line deviates from the literal string this criterion named — see
      Decisions, "the prescribed verification line is self-defeating".
- [x] Close path proven end to end on a fixture: a human-owned task with two deterministic
      Human criteria → `delegate` → `fw reviewer` PASS auto-ticks both → `fw task update
      --status work-completed` closes it with no human tick; the same fixture plus one `taste`
      criterion → `delegate` converts two, keeps one, owner stays human, and the close is
      refused by the sovereignty gate. Both as bats, `TEST_TEMP_DIR` set, no bare `! grep -q`.
      **Evidence:** `tests/unit/t3445_delegation_close_path.bats`, 10 tests, 0 skips, nothing
      stubbed — the real verb, the real `fw reviewer`, the real `update-task.sh`. Test 4 is the
      control leg (skip the reviewer → close refused), without which the suite could not tell
      "the reviewer closed it" from "delegation closed it". `tools/bats-dead-negation-lint.py`
      clean. The mixed fixture lands at sovereignty-refusal rather than partial-complete — see
      Decisions, "partial-complete is unreachable from owner: human".
- [x] `fw reviewer surface` (or `fw audit` section) reports the corpus counts
      reviewer-closeable / agent-self / operator-only by class, and WARNs when
      reviewer-closeable is 0 while operator-only exceeds a threshold (default 50,
      `FW_DELEGATION_SURFACE_WARN` in the config registry with a description) — 832's ask (a);
      `fw doctor` mirrors the WARN line.
      **Evidence:** `bin/fw reviewer surface [--json|--facts|--warn-threshold N]`;
      `agents/audit/audit.sh:check_delegation_surface` (structure section); the
      delegation-surface block in `bin/fw do_doctor`. Both rails read one scan
      (`surface --facts`, one TSV line) so they cannot disagree. Both verdict paths measured
      on a 60-task fixture: WARN at threshold 50, PASS at 500. Live corpus today: OK —
      reviewer-closeable 16, agent-self 1, operator-only 327 across 315 active tasks.
- [x] CLAUDE.md §Human Task Completion Rule and §AC Classification Guidance gain one paragraph
      each citing the ruling decision id and the verb; `tests/lint/config-registry-parity.bats`
      stays green for the new key.
      **Evidence:** §Human Task Completion Rule — "Delegation, when the open criteria are
      deterministic (D-626, T-3445)"; §AC Classification Guidance — "Getting it wrong at
      author time is now recoverable (D-626, T-3445)". config-registry-parity 3/3 green
      (`FW_DELEGATION_SURFACE_WARN` added to `lib/config.sh` AND `web/blueprints/config.py`,
      which is what makes this task trip the T-1766 render gate).
- [x] Vendored copies synced for every touched file under `lib/ agents/ bin/ policy/`;
      `bin/fw vendor self --check` clean; new files registered with `fw fabric register`;
      the verb listed in `fw help` and `bin/fw task --help` (help-router-parity lint green).
      **Evidence:** `bin/fw vendor self --check` → "vendored .agentic-framework/ in sync with
      source". Four fabric cards registered (`lib-delegation`, `lib-delegation_cli`,
      `tests-unit-t3445_delegation_close_path`, `tests-unit-test_delegation_classifier`).
      `bin/fw task --help` lists `delegate T-XXX [--dry-run]`; `bin/fw reviewer --help` lists
      `surface`; help-router-parity 2/2 green.
- [x] Live proof, recorded in this task: `fw task delegate --dry-run` run over the
      human-owned above-median now-tasks (join regenerated, not typed from memory) and the
      class table printed — how many become reviewer-closeable, how many stay human and why. No
      task is delegated for real in this task except the two fixtures; the real sweep is a
      follow-up the operator sees first.
      **Evidence:** Updates, "live dry-run sweep (AC 7)". 37 tasks in the regenerated join
      (the 2026-09-23 join had 43 — the corpus moved, which is why the instruction was to
      regenerate). 4 refused at task level as inception; 27 of the remaining 33 carry no open
      Human criterion at all; 1 fully delegable; 5 have open criteria, none delegable. Nothing
      outside the two bats fixtures was delegated.

### Human
- [ ] [REVIEW] The delegation boundary is where you want it
  **Steps:**
  1. Read the class table in Updates → "live dry-run sweep (AC 7)" below, and the six
     carve-outs in Decisions → "precedence: every carve-out outranks deterministic".
  2. Run `cd /opt/999-Agentic-Engineering-Framework && bin/fw reviewer surface` to see the
     whole corpus, then `cd /opt/999-Agentic-Engineering-Framework && bin/fw task delegate T-100201 --dry-run`
     — the one task in the sweep that would move to `owner: agent` — and read the criterion
     it would convert.
  3. Decide whether that criterion is one you are content for a reviewer PASS to close
     without you, and whether the six carve-outs cover what you would have carved out.
  **Expected:** you agree the converted class is genuinely low-risk, and that nothing you would
  want to keep is being handed over. The tie-break is "when in doubt, human", so the failure
  mode to look for is over-conversion, not under-conversion.
  **If not:** name the class that is wrong and whether it should be narrower or wider — the
  precedence order and the vocabularies are in `lib/delegation.py` under "Carve-out
  vocabularies", one regex per class, each independently adjustable.
- [ ] [REVIEW] The new row renders correctly on the Watchtower config page
  **Steps:**
  1. Run `cd /opt/999-Agentic-Engineering-Framework && bin/fw watchtower url` and open the
     printed URL with `/config` appended.
  2. Find the `DELEGATION_SURFACE_WARN` row.
  **Expected:** the row sits in the table at its default of 50 without wrapping oddly or
  pushing the other columns out of alignment — a layout judgement, not a value check.
  **If not:** note which column breaks; the entry is one tuple in `web/blueprints/config.py`
  `SETTINGS` and the description can be shortened.

## Verification

# Rehearsed under the gate's own semantics (bash -c 'set -o pipefail; <line>'),
# 10/10 green, 2026-09-24. Redirect-then-grep throughout (L-387): each line's
# verdict is its own last assertion, and `&&` keeps the producing command's
# exit code in it (T-3203). Nothing here anchors on a live corpus count.

timeout 300 python3 -m pytest tests/unit/test_delegation_classifier.py -q > /tmp/.t3445-pytest.out 2>&1 && grep -q "passed" /tmp/.t3445-pytest.out
timeout 900 bats tests/unit/t3445_delegation_close_path.bats > /tmp/.t3445-bats.out 2>&1 && ! grep -q "^not ok" /tmp/.t3445-bats.out
test "$(grep -c "# skip" /tmp/.t3445-bats.out)" -eq 0
timeout 300 bats tests/lint/config-registry-parity.bats > /tmp/.t3445-crp.out 2>&1 && ! grep -q "^not ok" /tmp/.t3445-crp.out
timeout 300 bats tests/lint/help-router-parity.bats > /tmp/.t3445-hrp.out 2>&1 && ! grep -q "^not ok" /tmp/.t3445-hrp.out
timeout 120 python3 tools/bats-dead-negation-lint.py tests/unit/t3445_delegation_close_path.bats
bin/fw task --help > /tmp/.t3445-help.out 2>&1 && grep -q "delegate T-XXX" /tmp/.t3445-help.out
bin/fw reviewer --help > /tmp/.t3445-rhelp.out 2>&1 && grep -q "reviewer surface" /tmp/.t3445-rhelp.out
bin/fw reviewer surface --facts > /tmp/.t3445-surface.out 2>&1 && grep -qE "^(OK|WARN)[[:space:]]+[0-9]+" /tmp/.t3445-surface.out
bin/fw vendor self --check

## RCA

<!-- Not a bug-class task: workflow_type build, no bug tag, the title names a
     mechanism rather than a failure. Two defects WERE found while building it,
     and both are recorded where they belong — Decisions for the design call each
     forced, Updates for the verbatim failure. Neither is this task's own
     regression, so there is no root cause here to state. -->

## Evolution

### 2026-09-24 — the prescribed verification line could not work

- **What changed:** The close line this task specified — and that CLAUDE.md's
  `[REVIEWER]` conversion rule prescribes in two places — is flagged by the
  reviewer's own `l387-sigpipe-risk` detector, because it pipes a streaming
  command into a terminal `grep -q`. Writing it into the Verification block makes
  the reviewer emit a finding against the line that reads its verdict, so the
  verdict comes back CONCERN and the delegated task can never close. Found by
  running the fixture, not by reading the code.
- **Plan impact:** the verb emits the redirect form instead. The spec's literal
  string was the one thing in this task that could not be taken at face value.
- **Triggered:** nothing filed under this task. CLAUDE.md still teaches the flagged
  form to every author, which is a corpus-wide problem rather than this task's —
  recorded in Updates for the operator to decide on.

### 2026-09-24 — partial-complete is unreachable from `owner: human`

- **What changed:** AC 3 expected the partially-delegated fixture's close to "land
  partial-complete". It cannot: `check_human_sovereignty` (R-033) runs at
  `agents/task-create/update-task.sh:1849`, BEFORE the P-010 gate that sets
  `PARTIAL_COMPLETE` — so a task deliberately left `owner: human` is refused
  outright. Partial-complete is reachable only from `owner: agent`.
- **Plan impact:** kept AC 2's rule (ownership moves only when nothing is left for
  the operator) and asserted the state that actually obtains. The end state is the
  same one partial-complete produces; it is reached one gate earlier, and the
  refusal itself emits the review handoff.
- **Triggered:** nothing. The alternative — always take ownership and let the
  machinery hand it back — would have the agent briefly own a task carrying an open
  taste criterion, which is the wrong direction for a sovereignty boundary.

### 2026-09-24 — the join moved under the sweep

- **What changed:** the 2026-09-23 join named 43 human-owned above-median now-tasks.
  Regenerating it on 2026-09-24 gives 37. Same query, same corpus, one day apart.
- **Plan impact:** none — the task already said to regenerate rather than type the
  ids from memory. Worth recording as a live instance of the T-3326 mutable-corpus
  class: had those 43 ids been pinned into a test, it would be red today for reasons
  unrelated to any code.
- **Triggered:** nothing filed; the sweep is recorded as a dated measurement.

## Recommendation

**Recommendation:** GO

**Rationale:** The mechanism D-626 authorises now exists, is exercised end to end
against the real reviewer and the real close gates, and refuses every carve-out the
ruling named. The two open criteria are a genuine boundary judgement (is the
delegable class the one you want to be delegable) and the config-page row render —
the latter is why this task trips the T-1766 gate at all, which is the carve-out
working on this task's own body rather than an exception to it. Nothing in the live
corpus was delegated: the sweep ran `--dry-run` only, and the one task it found
fully delegable (T-100201) is left for you to see first.

The reason to GO rather than hold: the ruling has been live since 2026-09-23 and
reached nothing, which is indistinguishable from a ruling nobody has needed. The
rail now makes that state visible — `fw audit` and `fw doctor` WARN on the
conjunction — so if the boundary is wrong, you see it as a number rather than as
silence.

**Evidence:**
- `lib/delegation.py` — 9 classes, 6 carve-outs outranking `deterministic`, tie-break
  `unclassified` → OPERATOR-ONLY. Vocabularies imported from the reviewer's own
  detectors; render patterns parsed out of `lib/render_surface.sh`. No second copy of
  any rule.
- 27 pytest fixtures (two per class, the render-surface control leg, the ambiguous
  fixture) plus 10 bats over the close path, 0 skips, nothing stubbed.
- Close proven: delegate → `fw reviewer` PASS auto-ticks → the task moves to
  `completed/` with no human tick. Control leg (skip the reviewer) → close refused, so
  the close is demonstrably driven by the verdict and not by the delegation.
- Carve-out proven: the taste criterion is not converted, ownership stays human, and
  the close is refused by the sovereignty gate with the review handoff emitted.
- Live sweep over the regenerated join (37 tasks): 4 refused as inception, 27 carry no
  open Human criterion, 1 fully delegable, 5 have open criteria none of which are
  delegable. 7 open criteria total — 1 REVIEWER-CLOSEABLE, 6 OPERATOR-ONLY.
- Two defects found by running it, both recorded: the prescribed verification line is
  self-defeating (fixed here; the corpus-wide half is in Updates for you), and
  partial-complete is unreachable from `owner: human` (asserted as it is).

## Decisions

### 2026-09-24 — the prescribed verification line is self-defeating

- **Chose:** emit `bin/fw reviewer T-XXX > /tmp/.fw-reviewer-T-XXX.out 2>&1 && grep -q "Overall:.*PASS" /tmp/.fw-reviewer-T-XXX.out`
  instead of the piped form AC 2 and CLAUDE.md both name.
- **Why:** measured on the T-9001 fixture. The reviewer's own `l387-sigpipe-risk`
  detector flags a streaming command piped into a terminal `grep -q`, so the piped
  form makes the reviewer emit a finding against the line that reads its verdict:
  `Overall: CONCERN`, the grep misses, the task cannot close. Every delegated task
  would have inherited that. The redirect form is the one that detector's own
  docstring names as the safe rewrite and that CLAUDE.md's Verification guidance
  calls THE DEFAULT; `&&` rather than `;` keeps the reviewer's exit code in the
  verdict (T-3203).
- **Rejected:** emitting the literal string and adding a reviewer override to suppress
  the finding — that suppresses a true positive on every delegated task forever, to
  preserve a string.

### 2026-09-24 — partial-complete is unreachable from `owner: human`

- **Chose:** keep AC 2's rule (ownership moves only when no Human criterion remains
  open) and assert the state that actually obtains for the mixed fixture: the close is
  refused by the sovereignty gate.
- **Why:** `check_human_sovereignty` (R-033) runs before the P-010 gate that sets
  `PARTIAL_COMPLETE`, so partial-complete is reachable only from `owner: agent`. The
  end state is identical to what partial-complete produces (stays in `active/`,
  `owner: human`, the criterion open) and the refusal emits the review handoff on its
  way out.
- **Rejected:** always moving ownership to agent and letting `update-task.sh` hand it
  back at the partial-complete transition. That satisfies AC 3's literal wording and is
  the wrong direction for a sovereignty boundary — the agent would briefly own a task
  carrying an open taste criterion.

### 2026-09-24 — precedence: every carve-out outranks deterministic

- **Chose:** render-surface → tier0-or-bypass → sovereignty-field → inception-decision
  → act-in-the-world → taste → deterministic → agent-self → unclassified, with
  `unclassified` mapping to OPERATOR-ONLY.
- **Why:** the ordering is by cost of being wrong. A criterion that is both grep-able
  and irreversible must not become delegable because its Expected clause happens to say
  "exit code 0" — `test_act_in_the_world_outranks_deterministic` pins exactly that.
  Taste before deterministic is T-1947's own rule, applied as a class rather than as a
  suppression.
- **Rejected:** scoring or confidence-weighting the classes. One class per criterion is
  what the report has to be readable as, and a tie-break that resolves to the human
  needs no confidence number.

### 2026-09-24 — agent-self is reported, never converted

- **Chose:** add a 9th class (`agent-self`, the T-2143 / T-2147 audience axis) because
  AC 4's three-way roll-up needs it, and never convert it.
- **Why:** an agent-audience criterion is a ROUTING defect — it should never have been a
  Human criterion at all. Fixing it is an author-time edit, not an act of delegation,
  and converting it would hide the defect behind a `[REVIEWER]` prefix.
- **Rejected:** folding it into `deterministic` (would delegate criteria with no
  deterministic check behind them) or into `unclassified` (would lose the signal the
  surface report exists to show).

### 2026-09-24 — delegate writes owner directly rather than via fw task update

- **Chose:** write the frontmatter in `lib/delegation_cli.py`, with
  `.context/working/delegations.jsonl` as the audit trail.
- **Why:** `owner: human` is sticky under R-033, and `fw task update --owner agent`
  needs `--skip-human-ownership`, which is a LOGGED BYPASS. Delegation is not a
  circumvention of the sovereignty gate; it is the transfer the operator ruled for.
  Recording it as a gate bypass would put the wrong thing in the bypass log and make a
  sanctioned act indistinguishable from a circumvented one.
- **Rejected:** adding a `--delegated` flag to `update-task.sh` that skips the ownership
  check — same effect, but it widens the bypass surface of the close verb for every
  caller, not just this one.

### 2026-09-24 — the corpus surface report uses the git-free render predicate

- **Chose:** `fw task delegate` calls `lib/render_surface.sh:task_touches_render_surface`
  (the authoritative T-1766 predicate); `fw reviewer surface` uses the git-free
  components-plus-body scan.
- **Why:** the authoritative predicate runs `git log --all --grep` per task — right for
  one task at close time, and ~55s for a 37-task sweep. The report walks every active
  task on every `fw audit` and `fw doctor`. The approximation over-reports (L-435's
  false-positive class), and over-reporting pushes criteria toward OPERATOR-ONLY, which
  is the safe direction for an advisory count. The decision that actually converts a
  criterion is always the authoritative one, so a delegation can never disagree with the
  close gate that follows it.
- **Rejected:** the cheap predicate everywhere (a delegation could convert a criterion
  the close gate then demands back as `[REVIEW]`), or the expensive one everywhere (an
  11-second doctor check is a check that gets skipped).

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-09-23T11:45:08Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3445-reviewer-closeable-delegation-fw-task-de.md
- **Context:** Initial task creation

### 2026-09-24T15:17:33Z — live dry-run sweep (AC 7) [t3445-delegate-verb]

- **Action:** regenerated the join (`bin/fw bvp --include-proposed`, median BVP 62,
  joined against frontmatter for `horizon: now`, `owner: human`, status not
  `work-completed`) and ran `fw task delegate <id> --dry-run --json` over every task in
  it. 55s wall for 37 tasks. Nothing was written: `--dry-run` produced no file change and
  no ledger line.
- **Join size:** **37 tasks**, not the 43 the 2026-09-23 join produced. Same query, one
  day later — the corpus moved. This is why the instruction was to regenerate rather than
  type the ids, and it is a live instance of the T-3326 mutable-corpus class.

| Outcome | Tasks | Which / why |
|---|---:|---|
| Refused at task level (`workflow_type: inception`, exit 2) | 4 | T-2899, T-2963, T-3240, T-3447 — go/no-go is the operator's |
| Scanned, **no open Human criterion at all** | 27 | human-owned by ownership, not by carrying an open Human criterion |
| **Fully delegable** (`owner:` would move to agent) | 1 | T-100201 — one `deterministic` criterion, nothing refused |
| Partially delegable (`owner:` stays human) | 0 | — |
| Open criteria, **none** delegable | 5 | T-2268 (taste + sovereignty-field), T-2170 (render-surface), T-2420 (unclassified), T-3335 (taste), T-1062 (unclassified) |

- **Open Human criteria across the join: 7.** By delegation class:
  REVIEWER-CLOSEABLE **1**, AGENT-SELF **0**, OPERATOR-ONLY **6**. By criterion class:
  taste 2, unclassified 2, deterministic 1, sovereignty-field 1, render-surface 1.
- **Reading it:** the delegable surface in this slice of the corpus is one criterion on
  one task. That is the honest answer and it is not an argument against the mechanism —
  the reason 27 of 33 tasks show nothing is that they are human-owned without carrying an
  open Human criterion, which is a different problem (ownership assigned by hand, per the
  Context note that no `fw` verb set `owner:` before this one). Corpus-wide the picture is
  larger: `bin/fw reviewer surface` reports 16 reviewer-closeable of 344 open criteria
  across 315 active tasks.
- **Not delegated:** every task above is untouched. The real sweep is a follow-up the
  operator sees first, per AC 7.

### 2026-09-24T15:17:33Z — two assumptions in the spec were false, verbatim [t3445-delegate-verb]

Per the standing order, recorded as they were hit rather than smoothed over.

1. **The prescribed verification line cannot work.** AC 2 named
   `bin/fw reviewer T-XXX 2>&1 | grep -q "Overall:.*PASS"`. Run against the T-9001
   fixture, the reviewer's verdict on the task carrying that line was, verbatim:

   ```
   - **Overall:** CONCERN
   - **Needs Human:** no
   - **Findings:** 1

   **Verification-level findings:**

     1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 2
        - evidence: `bin/fw reviewer T-9001 2>&1 | grep -q "Overall:.*PASS"`
   ```

   The line the delegation writes to read the verdict is the line that spoils the
   verdict. Fixed in this task by emitting the redirect form (see Decisions). **The
   corpus-wide half is NOT fixed here:** CLAUDE.md prescribes the flagged form in
   §Three Human-AC prefixes and in the REVIEWER conversion rule, so every author who
   follows the documented conversion writes a line their own reviewer will flag. That is
   a separate defect with a blast radius well beyond this task — one bug, one task — and
   it is left for the operator to scope rather than folded in here.

2. **A partially delegated task cannot reach partial-complete.** AC 3 expected the mixed
   fixture's close to "land partial-complete". The actual refusal, verbatim:

   ```
   ERROR: Cannot complete human-owned task
   Sovereignty gate (R-033): owner is human.
   The human must review and approve via Watchtower:
   ```

   `check_human_sovereignty` runs before the AC gate that sets `PARTIAL_COMPLETE`, so
   partial-complete is reachable only from `owner: agent`. The end state is the same one
   partial-complete produces and the refusal emits the review handoff; asserted as it is
   (see Decisions, and `tests/unit/t3445_delegation_close_path.bats` test 6).

### 2026-09-24T15:18:57Z — reviewer verdict on this task is CONCERN, deliberately [t3445-delegate-verb]

`bin/fw reviewer T-3445` returns `Overall: CONCERN`, `Needs Human: no`, one finding:
`mock-only-integration` (partial, heuristic) — "AC promises integration but verification
only exercises `tests/unit/`". The finding is accurate about the path and wrong about the
substance: `tests/unit/t3445_delegation_close_path.bats` IS the integration suite — it
shells the real `fw task delegate`, the real `fw reviewer` and the real `update-task.sh`
against a temp-dir project, nothing stubbed. It lives under `tests/unit/` because that is
where this repo puts such suites (`tests/unit/t3443_audit_structure_framework_scope.bats`
shells `audit.sh` the same way), and the detector's escape hatch is a literal spawn token
(`subprocess.run`, `playwright`, `termlink spawn`) that a bats file driving `run "$FW" …`
does not contain.

Left as CONCERN rather than suppressed with `fw reviewer override add`. No criterion on
this task requires a PASS verdict, the finding is `needs_human: no`, and filing a 90-day
override to make my own task read clean would be the wrong instinct to record. Noted here
so the verdict is not read as an unresolved defect.

### 2026-09-24T15:17:33Z — working-tree note [t3445-delegate-verb]

`VERSION` and `.agentic-framework/VERSION` show a `1.7.0` → `1.7.1` change that this task
did not author, and deliberately leaves unstaged. First noticed when
`bin/fw vendor self` reported `synced VERSION (1.7.1)`, which means the source file was
already at 1.7.1 before that sync ran. No hook in `.git/hooks/` bumps it, and no commit
in this task changed it. I do not know what wrote it or when — flagging it rather than
committing or reverting, since the repo cut v1.7.0 today and VERSION was out of scope.

## Reviewer Verdict (v1.5)

- **Scan ID:** R-f3bf4d21
- **Timestamp:** 2026-09-24T15:18:42Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **mock-only-integration** (partial, heuristic) @ AC vs Verification cross-check
     - evidence: `timeout 300 python3 -m pytest tests/unit/test_delegation_classifier.py -q > /tmp/.t3445-pytest.out 2>&1 && grep -q "passed" /tmp/.t3445-pytest.out`
