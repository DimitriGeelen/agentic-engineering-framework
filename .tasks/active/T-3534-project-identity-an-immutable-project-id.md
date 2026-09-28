---
id: T-3534
name: "project identity: an immutable project id + name registered at fw init, and
  one verb that answers who-and-where from any cwd"
description: >
  project identity: an immutable project id + name registered at fw init, and one
  verb that answers who-and-where from any cwd

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
# write_set:                      # T-3512: optional — globs (relative to PROJECT_ROOT)
#                                 # naming the files this task intends to write. Declared
#                                 # at CAPTURE, unlike components: which the framework
#                                 # resolves from git history at close. Feeds TWO things:
#                                 #   1. `fw write-set check T-A T-B` — without it the
#                                 #      comparison has nothing to compare and every real
#                                 #      pair exits 2 (undecidable). 0 of 3032 tasks
#                                 #      declared it, so that gate has never had an input.
#                                 #   2. BVP blast_radius before close — the 0.6-weighted
#                                 #      cost term, unavailable for 85% of rankable tasks
#                                 #      because components: only exists once the task is
#                                 #      finished (T-3471).
#                                 # Example: write_set: ["lib/bvp.sh", "tests/unit/t*_bvp*"]
#                                 # An EMPTY list is a real declaration ("writes nothing"),
#                                 # which is not the same as omitting the field. Omitted
#                                 # means unknown, and unknown must never score as cheap.
arc_id: arc-020
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
created: 2026-09-28T13:17:13Z
last_update: '2026-09-28T13:30:37Z'
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
  - ts: '2026-09-28T13:30:13Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=298,acs=10)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-09-28T13:30:37Z'
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
      F2: 0
    rationale: identity-fidelity=? (unscored (no scorer for identity-fidelity; 
      not counted)); provisioning-safety=? (unscored (no scorer for 
      provisioning-safety; not counted)); D1=4 (body:structural-gate); D2=4 
      (body:fw-audit-or-doctor); D3=3 (body:component-discoverability); D4=2 
      (body:env-class-handled); F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-3534: project identity: an immutable project id + name registered at fw init, and one verb that answers who-and-where from any cwd

## Context

**Origin, operator 2026-09-28:** *"Here again I got another project asking me if it's you. So
we should also have mechanics to register project name and the project root directory so it
always knows who it is and where to find that."*

An agent in another project could not establish which project it was talking to. Identity is
currently *implied* in four places — `.framework.yaml`, `PROJECT_ROOT`/`FRAMEWORK_ROOT`,
TermLink session tags, and the T-559 project-boundary gate — and *answerable* in none. There
is no verb an agent can call to say who it is.

**Correction carried forward from the design conversation.** The agent initially argued that
two checkouts of one project both answering "yes, I'm 999" was the failure mode requiring an
immutable id. That is wrong: a clone *is* the same project and should share the id. The real
distinction is **project identity** (id + name, committed, shared across checkouts) versus
**instance identity** (project id + host + root, runtime, addressable). TermLink's existing
tag shape `host=107,project=<name>` is already exactly this, so the design follows a pattern
in use rather than inventing one.

**Why the id must not be the path or the name:** paths change under vendoring, relocation and
cloning; names collide across hosts. Deriving identity from either means a project silently
becomes a different project when someone moves a directory.

Sequenced BEFORE the per-project objectives work (filed separately): an objectives artefact
cannot be trusted to show the right project's goals until "which project am I" has a reliable
answer.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [ ] A project carries an **immutable id**, generated once at `fw init`, stored in `.framework.yaml`, and distinct from both its display name and its root path. Regenerating it is refused, not silently re-rolled — a project that can change identity has none.
- [ ] **One verb answers who-and-where** from any cwd inside the project, and reports the addressing triple the messaging case actually needs: project id, display name, current root, and host. Works in a vendored consumer (`.agentic-framework/bin/fw`) exactly as in the framework repo.
- [ ] **Project identity and instance identity are distinguished, and both are reported.** A `git clone` legitimately shares the project id — it IS the same project — so the id alone cannot address a checkout. The instance is `project id + host + root`, which is the shape TermLink session tags already use (`host=107,project=001-…`). Pinned by a test that two checkouts of one project agree on id and differ on instance.
- [ ] `fw init` on a project that already has an id **preserves it, with no exception and no flag**. Re-running init must never mint a new identity over an existing one — that is the silent-corruption case, since nothing downstream would report the change. Multiple instances of one project sharing an id is the DESIGNED behaviour, not a tolerated side effect (operator ruling, below).
- [ ] **Forking to a new project is a separate verb, not a flag on `init`** — it (a) mints a fresh id, (b) records the `descended_from:` parent id so the lineage survives, (c) writes a Tier-2 log entry, and (d) is **refused under `$CLAUDECODE=1`**. Re-identifying a project is sovereignty-class: an agent that can change which project it is can walk out of the T-559 boundary gate. Pinned by a test that the agent path is refused and the human path succeeds — tested on the agent path, since a pass obtained with an override flag proves nothing (L-573).
- [ ] The id is resolved from `.framework.yaml`, never inferred from the directory name or path. A project moved or renamed keeps its identity; verified by a test that relocates a fixture project and re-reads it.
- [ ] `tests/unit/upgrade_fresh_machine_simulation.bats` stays green — `fw init` is one of the three consumer-facing setup commands, and this touches it (CLAUDE.md §Consumer-Facing Command Hygiene, T-1633).
- [ ] **The minted id replaces the path in slot 3 of the ratified five-part address** — `aef::host=<fqdn>::hub=<H>::project=<project-id>::@<agent>::` instead of `project=<path>`. This task does NOT invent a second identity notion beside `lib/aef_address.py`; it supplies the stable token that slot was always reaching for. Operator ruling, below.
- [ ] **The elision machinery is retired or justified, not left dangling.** `elide_path()`, the display-only ellipsis form, and `serialize()`'s refusal to emit it exist *because* slot 3 is a long, layout-leaking path. With an id, display and wire are the same string. Either remove that code or record in the task why it must stay — leaving a mechanism whose reason has gone is how dead guards accumulate.
- [ ] **Migration is answered, not assumed:** existing circuit-registry entries (`lib/aef_circuit.py`) carry path-form addresses. State whether path-form is accepted-and-upgraded, rejected, or dual-read during a window — and pin the chosen behaviour with a test over a real pre-migration entry, not a synthetic one.
- [ ] A **scoring spec** is written for arc-020's `identity-fidelity` driver from this use case, checked with `bin/fw bvp driver --validate-scoring`, so the driver stops being a live-looking axis with no mechanism (the audit WARN and today's RED verdict from `fw arc judge-driver`).
- [ ] `bin/fw vendor self --check` clean before close.

### Human
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
     Remove this section if all criteria are agent-verifiable.
     Each criterion MUST include Steps/Expected/If-not so the human can act without guessing.

     ── Prefix routing (T-1811, T-1878): default to [REVIEWER] if Expected is grep-able ──
     If your Expected clause is grep-able / file-exists / structural (a deterministic
     shell check), prefer [REVIEWER] — that AC should be an Agent AC with the reviewer
     command in `## Verification` instead of a Human AC here. Only keep [REVIEW] if
     verification genuinely needs human taste (tone, feel, layout rhythm).
     See CLAUDE.md §AC Classification Guidance for the conversion rule.

     [REVIEW] example (genuine human judgment):
       - [ ] [REVIEW] Dashboard renders correctly
         **Steps:**
         1. Open https://example.com/dashboard in browser
         2. Verify all panels load within 2 seconds
         3. Check browser console for errors
         **Expected:** All panels visible, no console errors
         **If not:** Screenshot the broken panel and note the console error

     [REVIEWER] example (static-scan-verifiable — convert to Agent AC + Verification):
       - [ ] [REVIEWER] Block message names both bypass mechanisms
         **Steps:**
         1. Run `bin/fw reviewer T-XXX`
         **Expected:** Verdict: PASS; no findings on `block-message-completeness`
         **If not:** Inspect hook block-message string and add missing mechanism
       Conversion: this AC should be moved to ### Agent and
       `bin/fw reviewer T-XXX 2>&1 | grep -q "Overall:.*PASS"` added to ## Verification.
-->

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# The completion gate runs each command — if any exits non-zero, completion is blocked.
#
# Toolchain hint (L-291): if you edited *.vbproj/*.csproj/*.xaml add `dotnet build`;
# *.go → `go build ./...`; Cargo.toml → `cargo check`; tsconfig.json → `tsc --noEmit`;
# pom.xml → `mvn -q compile`. P-011 runs only what you write — broken builds slip
# past otherwise (origin: 003-NTB-ATC-Plugin T-077, broken WPF DLL on master 5 days).
#
# ── Mutable-corpus anchor (T-3326) ────────────────────────────────────────────
# Do NOT anchor a verification line (or a unit test it runs) to MUTABLE corpus
# state — an exact live count, or a grep of live `fw audit`/`fw doctor` output
# for a specific corpus entity (a named arc, a task count, a census number).
# The corpus moves under the check, and the line rots: it goes red (or vanishes
# its pattern) for reasons unrelated to the code under test, blocking closes.
# Pin the INVARIANT (categories sum, count > 0, property holds) or run the code
# against a COMMITTED FIXTURE — never the live count or a live-audit line.
# Origin: T-2969 line grepping live audit for one arc's status; T-2871's census
# test pinning exact live counts (56→74 files) — both blocked closes (OBS-377).
#
# ── Pipefail/SIGPIPE: grepping a command's output (L-387, T-2090, T-2743, T-2738) ──
#
# THE DEFAULT — redirect to a file, then grep the file:
#     cmd > /tmp/.out 2>&1 && grep -q "PATTERN" /tmp/.out
#     curl -sf "$(bin/fw watchtower url)/page" -o /tmp/.out && grep -q "PAT" /tmp/.out
# Correct at any output size, and `&&` keeps the PRODUCING command's exit code in
# the verdict. Reach for this first; the alternative below is the special case.
#
# Why not `cmd | grep -q PAT` (L-387): P-011 runs each line with PIPEFAIL LIVE
# (errexit is not — see below). When grep matches it exits and closes stdin while cmd is still
# writing, cmd takes SIGPIPE, the pipeline exits 141 — verification "fails" with
# the pattern present. Captured 4× (T-1716, T-1838, T-1862, T-1863).
#
# THE EXCEPTION — capture first, grep the capture:
#     out=$(cmd 2>&1); echo "$out" | grep -q "PATTERN"
# Valid ONLY while "$out" fits the 65536-byte pipe buffer, and it is on you to
# know that it does. Above that the form inverts and becomes the very failure
# L-387 describes: echo blocks on the full pipe, grep -q exits, echo takes
# SIGPIPE, rc=141 (T-2743 — measured on a 146,366-byte Watchtower page, 3/3 runs,
# deterministic not racy; rendered routes run 50-200KB, so anything that curls a
# page is over the line). It also discards cmd's exit code, so a 404 yields an
# empty capture that grep merely fails to match rather than a failed line.
# If you do use it: single pipe only, no intermediate tail/awk/sed stage between
# capture and grep (T-2090) — the middle stage is what `grep -q` slams its stdin
# on, and grep scans the whole captured string anyway, so the `tail -3` was
# cosmetic. `echo "$out" | grep -q PAT`, nothing between.
#
# TEST RUNNERS need a guard either way (T-2738). `set -e` is suppressed inside the
# `if` condition the gate runs each line in, so in `cmd1; cmd2` only cmd2 is the
# verdict — and the pass marker you grep for survives a partial failure: a suite
# printing "3 failed, 9 passed" satisfies `grep -q "9 passed"`, and generalising
# to `grep -qE "[0-9]+ passed"` matches the same output. Keep the exit code:
#     python3 -m pytest <file> -q > /tmp/.out 2>&1 && grep -q passed /tmp/.out
# or add the guard the exit code used to supply:
#     out=$(python3 -m pytest <file> -q 2>&1); echo "$out" | grep -q passed && ! echo "$out" | grep -q failed
#     out=$(bats <file> 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
# The close gate refuses the unguarded form. Bypass: FW_ALLOW_UNJUDGED_TEST_RUN=1.
#
# ── A SKIPPED BATS TEST REPORTS `ok` (T-3217) ─────────────────────────────────
#
# `! grep -q "^not ok"` does NOT mean the suite ran. Bats emits a skip as
#     ok 6 <name> # skip <reason>
# which is not a `not ok`, so the gate passes and the report says ok while the
# thing the test covers was measured NOWHERE. Origin: T-3213 guarded a test with
# `[ "$(id -u)" -eq 0 ] && skip` — the suite runs as root here and in CI, so it
# skipped on every run that mattered, for as long as it existed.
#
# Add a skip clause to any bats verification line. `# skip` is the marker bats
# writes; counting it is the whole check:
#     timeout 300 bats <file> > /tmp/.out 2>&1 && ! grep -q "^not ok" /tmp/.out
#     test "$(grep -c '# skip' /tmp/.out)" -eq 0
# Two lines, because they answer different questions — "did anything fail" and
# "did everything run". If some skips are legitimate on your host (an optional
# dependency is genuinely absent), assert the COUNT you expect rather than zero,
# and say in the task why that number is right.
#
# Corpus-wide, the same check runs from `bin/fw test lint`
# (tools/bats-silent-skip-lint.py): static mode flags guards that are fixed for
# a deployment rather than probing an optional dependency, and `--tap FILE`
# reports the skips a real run actually fired.
#
# REHEARSING A LINE BY HAND DOES NOT REHEARSE THE GATE (T-2743). Your interactive
# shell has no pipefail. A line has returned 0 by hand and 141 under P-011, from
# the same directory, the same second. To rehearse for real:
#     bash -c 'set -o pipefail; <your verification line>'
#
# NOTE THE MISSING `-e` — it is not a typo (T-3203). This file used to prescribe
# `set -eo pipefail` here, which is NOT the gate: it adds errexit the gate does
# not have, so it FAILS lines the gate PASSES. Measured, 10 lines, 3 diverged:
#     line                            gate    set -eo (old)   set -o (this)
#     false; true                     PASS    FAIL  wrong     PASS  ok
#     cd /nonexistent; echo ok        PASS    FAIL  wrong     PASS  ok
#     grep -q MISS file; true         PASS    FAIL  wrong     PASS  ok
# The divergence is one-directional and that is the trap: the old rehearsal only
# ever fails lines the gate accepts, so it produces false REDS, and an author
# who "fixes" a line to satisfy it is fixing something that was never broken —
# while the line that actually is broken (`cmd1; cmd2` where cmd1 fails) passes
# both. Re-derive rather than trust this table — it is pinned, not asserted:
#     bats tests/unit/t3203_p011_gate_semantics.bats
#
# ── `cmd1; cmd2` IS JUDGED ONLY ON cmd2 (T-3203) ──────────────────────────────
#
# The gate runs each line as the CONDITION of an `if` (update-task.sh:1215), and
# POSIX suppresses errexit for a compound command in an `if` condition — through
# the subshell. So pipefail applies and `set -e` does not, and in a sequence only
# the LAST command's status reaches the verdict. `cd /nonexistent; echo ok` passes.
# 2,644 of 10,997 verification lines in this corpus contain `;` (re-derive with
# the query in docs/reports/T-3203-p011-gate-semantics.md).
#
# SAFE SHAPES — both verified biting, each against a passing control:
#   A. one command whose own status is the verdict (prefer this):
#        out=$(cmd 2>&1); echo "$out" | grep -q PAT && ! echo "$out" | grep -q BAD
#      the leading assignments are setup; the trailing `&&` chain is the verdict.
#   B. an explicit sub-shell, whose errexit the outer `if` cannot reach into:
#        bash -c 'set -eo pipefail; cmd1; cmd2'
#      use when you genuinely need every command in the sequence to count.
#
# The rule of thumb: put the assertion LAST, and make sure it is an assertion.
#
# Enforcement-baseline hint (L-398, T-1886): if you edited `.claude/settings.json`
# (added/removed/reorganised hooks), add `bin/fw enforcement baseline` to your
# Verification block. Otherwise the canonical hash diverges and `fw doctor`
# reports a FAIL ("Enforcement baseline CHANGED") that accumulates silently.
# Origin: T-1849/T-1730/T-1731 each added a legitimate hook without refreshing
# the baseline — FAIL sat for multiple sessions until T-1886 cleaned up.

## RCA

<!-- REQUIRED for bug-class tasks (workflow_type=build with bug-tag, OR title matches
     fix/bug/rca/broken/crash/error/regression/fail/hotfix).
     Non-bug-class tasks may leave this section empty or remove it.

     For bug-class, fill in:
       **Symptom:** what was observed (the user-facing manifestation).
       **Root cause:** the specific structural/logical gap — not "the code was wrong".
       **Why structurally allowed:** what in the framework/code/tooling let this go undetected.
       **Prevention:** what catches the next instance (test/lint/gate/doc/learning) — distinct from the fix itself.

     The completion gate (T-1550, G-019) blocks --status work-completed when
     bug-class AND this section is empty/template-only. Use --skip-rca to bypass (logged).
-->

## Evolution

<!-- REQUIRED for arc-tagged build tasks (tags include arc:*). Captures how
     understanding evolved during build — what was learned that wasn't known at
     filing, what in the original plan no longer fits, what triggered pivots
     or new sub-tasks. Mandatory at slice boundaries (when applicable) and
     before --status work-completed.

     Origin: T-1717 grill Q4 — "the understanding of what we need and want
     evolves with the process of materialisation." Structural counter to §ACD:
     spec-vs-build divergence is logged as soon as it happens, not lost as
     folklore.

     Format (one entry per slice boundary or significant insight):
       ### YYYY-MM-DD — [topic]
       - **What changed:** [what we learned that we didn't know at filing]
       - **Plan impact:** [what in the plan no longer fits]
       - **Triggered:** [new sub-task / pivot / scope cut, with task ID if filed]

     The completion gate (T-1718) blocks --status work-completed when this
     section exists but is empty/template-only. Use --skip-evolution to bypass
     (logged Tier-2). Non-arc tasks may leave this empty.
-->

## Recommendation

<!-- T-2945: same shape as inception.md's block — the gate that reads it
     (audit_inception_recommendation, lib/task-audit.sh:117) is shared, so the
     shape is copied rather than reinvented.

     REQUIRED once this task reaches partial-complete: Agent ACs done, at least
     one `### Human` AC still unticked. `lib/review.sh:205-211` (T-2421) BLOCKS
     `fw task review` emission for build/refactor/test/decommission tasks in that
     state with no substantive block here — the operator would otherwise open
     /review/<id> to a blank Recommendation card and be asked to approve a form.

     Not required while every Human AC is ticked or the task has none: the gate
     only fires on the partial-complete transition. It is here from the start so
     you write it while you still have the evidence, not when the gate refuses.

     Format (the parser wants the `**Recommendation:**` line at the start of a
     line; a leading `-` or `*` bullet is also accepted):
     **Recommendation:** GO / NO-GO / DEFER
     **Rationale:** Why (cite evidence — what shipped, what was proven, what remains)
     **Evidence:**
     - Finding 1
     - Finding 2

     DEFER is for evidence gaps, not confidence gaps (CLAUDE.md §Presenting Work
     for Human Review). If the artefact is complete and you still don't want to
     commit, that is a calibration failure — recommend GO or NO-GO.
-->

## Decisions

### 2026-09-28 — where identity lives, and how a fork differs from an instance

- **Chose:** an immutable id in `.framework.yaml`, minted once at `fw init`. Instances of a
  project (clones, checkouts, deployments) **share it by design**. Forking to a new project
  is a **separate verb**, sovereignty-gated.
- **Operator ruling, verbatim:** *"Sometimes we also want to have different instances of a
  project and we definitely want the same id, right? Only if you fork it, then it should be
  a separate process. So I think to make that a separate verb makes perfect sense."*
- **Why a verb and not `fw init --new-identity`:** a flag on `init` puts re-identification on
  the same code path as routine setup, where it is one typo away from firing. A separate verb
  makes the intent explicit at the call site and gives the `$CLAUDECODE=1` refusal somewhere
  to live. The framework has this shape already — `fw arc close` and `fw inception decide`
  are agent-refused for the same reason: they are decisions, not operations.
- **Rejected — derive identity from the git remote URL:** fails on a fact about this repo,
  which has two remotes (OneDev `origin` plus a GitHub mirror), so there is no non-arbitrary
  answer to which is the identity. A remote migration would also change identity, which is
  the single thing identity must never do. Excludes local-only and non-git projects entirely.
- **Rejected — make TermLink's `project=` tag authoritative:** makes a core governance
  property depend on an explicitly optional tool (CLAUDE.md requires graceful degradation
  when TermLink is absent), and TermLink is deliberately machine-wide, the inverse of the
  per-project isolation this is meant to establish. Directive 4 violation.
### 2026-09-28 — the id IS slot 3 of the five-part address (operator)

- **Operator ruling, verbatim:** *"For communications sake, or identity sake, we can still use
  the five part identity that we minted before, that we also use for agent to agent
  communication… Even if it's up to running on the same host, it will have a different session
  ID then. And instead of the path that we minted, maybe we use the project ID and replace
  step 3 in that 5 part identity by the project ID instead of the path."*
- **Chose:** `project=<project-id>` replaces `project=<path>` in the V9 address. This task
  does not create a parallel identity concept — it supplies the stable token the ratified
  scheme was already reaching for.
- **What it already is:** `host / hub / project / session / agent`, ratified twice (T-3287
  D1–D7 GO 2026-09-07; D-599 on T-3433 2026-09-22) and BUILT — arc-020's seven slices are all
  `work-completed`: `lib/aef_address.py` (V9 library with `climb()`/`ladder()`),
  `lib/aef_circuit.py`, `lib/aef_resolve.py`, plus election, governor, repo-source and
  provision audit.
- **Why the path was always the weak slot, from the code itself:** `lib/aef_address.py` carries
  `elide_path()` for display, refuses the elided form in `serialize()`, and comments that
  otherwise *"the wire would re-collapse two projects into one correspondent"*. That entire
  mechanism exists because slot 3 is a path. An id makes display and wire the same string —
  nothing to elide, nothing to collapse — and stops every address leaking filesystem layout to
  every other host on the circuit.
- **Why the instance case is safe:** two instances of one project on one host share the project
  id and are separated by the `session` token, which is what that slot is for. The operator
  made this point explicitly, and it is why sharing the id across instances costs nothing.
- **Agent near-miss, recorded because it is the point:** this task was filed proposing a
  project identity with no reference to the five-part address at all. Had it been built as
  filed, the repo would have gained a SECOND project-identity notion beside a ratified, shipped
  one — the same five-readers-of-one-predicate defect that cost a day on arc membership, and
  that `lib/ac_placeholder.py` was written this morning to stop repeating. The operator caught
  it; no check would have.

- **Agent correction recorded:** the filed ACs originally required only that `fw init`
  preserve an existing id. That rule is right, and on its own it makes a fork silently
  inherit its parent's identity — two different projects, one id, nothing saying so. The
  preservation rule and the fork case had to be separated; they were not, until this
  exchange.

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-09-28T13:17:13Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3534-project-identity-an-immutable-project-id.md
- **Context:** Initial task creation
