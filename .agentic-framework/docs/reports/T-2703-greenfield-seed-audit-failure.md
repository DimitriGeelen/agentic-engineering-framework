---
task: T-2703
title: Greenfield seeding emits tasks that fail the framework's own audit (CTL-027 + missing Updates)
workflow_type: inception
status: research-complete
authored: 2026-07-31
---

# T-2703: Greenfield seeding emits tasks that fail the framework's own audit

## 1. Reproduction

Reproduced cleanly from a fresh seed, independent of the /opt/2026-Mehdi-demo
report. Seeded via the framework's own `fw init` into a scratch directory
(never touched `/opt/2026-Mehdi-demo`, per the hard constraint), then ran the
seeded project's own vendored `fw audit`:

```
$ SCRATCH=/tmp/.../scratchpad/greenfield-seed-test
$ mkdir -p "$SCRATCH" && cd "$SCRATCH"
$ /opt/999-Agentic-Engineering-Framework/bin/fw init .
...
  [0;32m✓[0m  5 onboarding tasks (greenfield mode)
Done! Governance is active.

$ cd "$SCRATCH" && env -u PROJECT_ROOT -u FRAMEWORK_ROOT .agentic-framework/bin/fw audit
...
[FAIL] CTL-027: Inception T-002 missing required sections: ## Recommendation, ## Decision
       Evidence: fw inception decide will fail or duplicate decision blocks
       Mitigation: Add missing sections to task file: .../T-002-define-project-goals.md
...
[WARN] Task T-002-define-project-goals.md missing Updates section
[WARN] Task T-003-first-governed-commit.md missing Updates section
[WARN] Task T-004-complete-task-lifecycle.md missing Updates section
[WARN] Task T-005-generate-first-handover.md missing Updates section
[WARN] C-006: Inception T-002 has template-only Recommendation block
...
=== SUMMARY ===
Pass: 71
Warn: 8
Fail: 1
$ echo $?
2
```

**Exit code is 2 (FAIL).** Only `CTL-027` produces the FAIL; the four
missing-`## Updates` findings and the template-only-Recommendation finding are
WARNs (which alone would not block `test $? -le 1`). CTL-027 alone is what
breaks T-001's own gate.

Confirmed T-001's seeded Verification block literally gates on this:

```
## Verification

fw doctor
# fw audit exits 1 for warnings (expected on fresh projects) — only block on exit 2 (failures)
fw audit; test $? -le 1
```

So a fresh install's own T-001 (`Onboarding: orientation and framework health`)
cannot reach `work-completed` — its own Verification command fails on turn
one, before an agent has touched anything.

**A note on an unrelated wrinkle hit during reproduction:** the first two
`fw audit` attempts against the scratch project returned "Another audit is
already running — exiting" (exit 0) instead of reproducing the failure. Root
cause: this RCA session's dispatch environment pre-exports
`PROJECT_ROOT=/opt/999-Agentic-Engineering-Framework` (and `FRAMEWORK_ROOT`)
in the shell env; `bin/fw`'s resolver trusts a pre-set, non-stale
`PROJECT_ROOT` verbatim and never re-derives it from `$PWD`, so `cd`-ing into
the scratch project and invoking its vendored `fw` still operated on the
**framework repo's own** `.context/locks/audit.lock` (which a concurrent
process held). This is an artifact of how this RCA was run (a TermLink-spawned
worker inheriting env from its parent), not the T-2703 defect — reproduction
proceeded correctly once `PROJECT_ROOT`/`FRAMEWORK_ROOT` were stripped
(`env -u PROJECT_ROOT -u FRAMEWORK_ROOT`). Flagged here for completeness per
the "if you hit a framework gate, report it, don't route around it silently"
governance rule; not treated as in-scope for this task's fix. It exists as a
sibling class to the T-2390/T-2391/T-2446 "daemon-poison" guards already in
`bin/fw` (which cover `CLAUDE_PROJECT_DIR`), which do not yet cover a directly
pre-exported `PROJECT_ROOT`.

## 2. 5-Whys RCA

**1. Why does the seeded T-002 fail CTL-027?**
Because `## Recommendation` and `## Decision` headings are absent from the
seeded file's body — CTL-027 (`agents/audit/audit.sh:3128`) does a literal
`grep -qE '^## Recommendation[[:space:]]*$'` / `'^## Decision[[:space:]]*$'`
against every `workflow_type: inception` task in `.tasks/active/`, no grace
period for freshly-seeded or onboarding tasks.

**2. Why are those headings absent from the seed?**
Because the seeded task files are not generated from
`.tasks/templates/inception.md` (the real, current inception template used by
`fw task create --type inception`) — they are static files at
`lib/seeds/tasks/greenfield/T-002-define-project-goals.md`, copied verbatim by
`lib/init.sh` (`seed_dir="$FRAMEWORK_ROOT/lib/seeds/tasks/greenfield"`, then
`cp` per template — see `lib/init.sh:490-513`). `.tasks/templates/inception.md`
**does** have `## Recommendation`, `## Decisions`, `## Decision`, and
`## Updates` sections (confirmed by inspection); the greenfield seed has
`## Context`, `## Acceptance Criteria` (Human/Agent), `## Verification` and
nothing else.

**3. Why does a static hardcoded copy exist instead of deriving from the real
template?**
Because `lib/seeds/tasks/greenfield/T-002-define-project-goals.md` was
authored once, as its own artifact, in T-460 ("Create onboarding task
templates for fw init — 6 existing-project + 5 greenfield tasks with template
copying in init.sh", commit `4e70ce9bf`, 2026-03-13). It was designed to be a
**worked example** for a first-time user (real Context/AC prose specific to
"define your project's goals"), not a mechanical instantiation of
`inception.md`. That design choice — bespoke onboarding prose over template
derivation — is defensible on its own, but it created a second, independent
copy of "what sections an inception task must have," with no link back to the
canonical template.

**4. Why was the seed never updated when CTL-027 shipped?**
Because CTL-027 was added by T-1263 on 2026-04-25 (`95b1449e9`, "T-1263:
Complete — inception template validation fix"), over **six weeks after** the
seed was authored, and nothing in T-1263's scope touched `lib/seeds/`. `git
log --follow` on the seed file shows exactly one commit ever
(`4e70ce9bf`, T-460) — it has not been modified since creation, across 138
days and at least one intervening rule change that directly invalidates its
structure. This is a textbook instance of the producer/consumer parity gap
documented in L-399/T-1890: a structural rule (CTL-027) shipped on the
consumer side (audit.sh, which reads *any* inception task in `.tasks/active/`)
without a corresponding update on every producer side that emits inception
tasks. `fw task create --type inception` (producer #1, via
`.tasks/templates/inception.md`) already has the sections and passes. `fw
init` greenfield mode (producer #2, via `lib/seeds/tasks/greenfield/`) does
not, and nothing enforced that the two producers stay in sync.

**5. Why did no gate catch this for 3+ months?**
Because the one test that exercises the seeding path
(`tests/unit/upgrade_fresh_machine_simulation.bats`) only asserts that the
audit **scripts** are present in the vendored tree (payload completeness —
see the `G-001 payload completeness` test, lines 173-183); it never actually
**invokes** `fw audit` against a freshly seeded project and checks the exit
code. `tests/e2e/onboarding-test.sh` seeds the tasks and counts them
(`TASK_COUNT onboarding tasks`) but has zero references to `audit`,
`CTL-027`, `Recommendation`, or `Decision` — it validates that files appear,
not that the seeded state is internally consistent with the framework's own
governance rules. There is no test anywhere in the repo that runs `fw audit`
against a just-seeded greenfield project. The gap is structural, not
incidental: the fresh-machine simulation suite (T-1633/T-1635, see
CLAUDE.md §Consumer-Facing Command Hygiene) was built to catch "works on dev
host, fails on fresh machine" — a different failure axis (environment
portability) — not "seeded state fails its own governance," which is a
content/drift axis nobody was watching.

**Root cause, stated once:** two independent, un-synchronized sources of
truth for "what sections must an inception task have" (`.tasks/templates/inception.md`
vs `lib/seeds/tasks/greenfield/T-002-*.md`), combined with zero test coverage
that exercises the seed against the audit that governs it. CTL-027 is not
itself wrong; the seed is stale relative to a rule that has existed for over
three months.

## 3. Candidate fixes

**(a) Patch the seed templates directly — add the missing sections.**
Add `## Recommendation` / `## Decisions` / `## Decision` to
`lib/seeds/tasks/greenfield/T-002-define-project-goals.md`, and `## Updates`
to all five greenfield seeds (T-001 already has it; T-002-005 don't) plus the
`existing-project` seeds T-002-006 (same gap, currently WARN-only since none
of those are `workflow_type: inception`, but still real drift).
- **Fixes:** the FAIL, immediately, with a minimal diff.
- **Leaves open:** the underlying duplication. The next audit rule that
  inspects *any* task-file structure (inception or not) can silently break the
  seed again, the same way CTL-027 did, because there is still no structural
  link between the seed and the canonical templates.
- **Regression risk:** low. Pure content addition, no code path changes.

**(b) Derive greenfield/existing-project seeds from `.tasks/templates/` at
init time, splicing in the bespoke onboarding prose as a header/body
overlay rather than a full standalone file.**
`lib/init.sh` would read `.tasks/templates/inception.md` (or `default.md` for
the `build`-typed seeds) as the section-structure source of truth, and inject
the onboarding-specific Context/AC content into the matching sections,
instead of maintaining five (or eleven, counting existing-project) fully
independent files.
- **Fixes:** the root cause — one source of truth for section structure,
  the duplication that let this recur cannot recur the same way again.
- **Leaves open:** implementation cost and risk. `init.sh`'s seeding is
  currently a dumb `cp`; templating in bespoke prose per-task means either a
  section-merge script (new code, new failure surface) or restructuring the
  seed files as diffs/overlays against the templates (less dumb but more
  moving parts). This is real engineering, not a one-line fix, and is exactly
  the kind of thing that should get its own scoped build task after this
  inception's GO, not be done inside T-2703.
- **Regression risk:** medium — touches the init code path that every fresh
  install depends on; needs the fresh-machine simulation (extended per
  Prevention below) as a safety net before shipping.

**(c) Change CTL-027's scope (e.g., skip freshly-seeded/onboarding tasks,
or downgrade to WARN).**
- **Argued against.** CTL-027 exists because `fw inception decide` genuinely
  needs those sections to not fail or duplicate decision blocks — the
  consequence CTL-027 protects against (T-1263's own stated rationale) is
  just as real for a seeded T-002 as for any hand-authored inception. Carving
  out an exception for seeded tasks doesn't fix the actual problem (a seeded
  inception task genuinely cannot go through `fw inception decide` cleanly
  today); it hides the FAIL while leaving the underlying breakage in place.
  This is the "fix the audit, not the seed" trap the task brief warned against
  — recommend explicitly rejecting this option.

**(d) Have T-001's Verification block stop gating on `fw audit` exit code.**
- **Fixes:** the immediate symptom of "T-001 can't reach work-completed,"
  cheaply.
- **Leaves open:** everything. This removes the only signal a first-time user
  gets that their fresh install is broken — it doesn't fix CTL-027 failing,
  it just stops anyone from noticing. This actively regresses the framework's
  own stated value (P-011 Verification Gate, "structural gate... not the
  agent self-assessing") by weakening the one onboarding task that exists
  specifically to prove the install is healthy. Reject.

## 4. Recommendation

**GO — ship (a) now, scope (b) as a separate follow-on build task, reject (c)
and (d).**

Rationale: (a) is a small, safe, immediately-correct fix for the actual FAIL
blocking every fresh install today — there's no reason to leave a known-broken
onboarding experience live while a larger refactor is designed. (b) is the
right long-term shape (single source of truth removes this whole class of
recurrence) but is a genuine build-scope task with its own design tradeoffs
(section-merge mechanism, migration of 11 existing seed files, testing burden)
— it does not belong inside this inception, and gating (a) on (b) being fully
designed would leave the FAIL live for no good reason. (c) and (d) are both
argued against above as failure modes explicitly named in the task brief
(hiding the failure vs. removing the only detector of it) — not recommending
either. This is not a DEFER: the evidence is complete (reproduced, root
cause traced to a single authored commit and a single unenforced rule, three
credible fixes evaluated) and there is no missing information that changes
which of the four options is right.

## 5. Prevention

Distinct from the content fix: what stops the *next* seed/audit-rule drift
from recurring silently for months, regardless of which fix is chosen for
this instance.

Wrote and proved a prototype guard:
**`tests/unit/greenfield_seed_audit_prototype.bats`** — seeds a real
greenfield project via the framework's own `fw init`, then runs the seeded
project's own vendored `fw audit` (scrubbed env, same `fresh_run` pattern as
`upgrade_fresh_machine_simulation.bats`, to sidestep the `PROJECT_ROOT`
pre-export artifact noted in §1) and asserts exit `<= 1`.

**Proved RED against the current (unfixed) seed**, per the mutate-then-check
rule — a guard not seen to fail is not a guard:

```
$ env -u PROJECT_ROOT -u FRAMEWORK_ROOT bats tests/unit/greenfield_seed_audit_prototype.bats
1..1
not ok 1 T-2703 PROTOTYPE: fresh greenfield seed passes its own audit (exit <= 1)
#   `[ "$status" -le 1 ]' failed
# audit exit: 2
# [FAIL] CTL-027: Inception T-002 missing required sections: ## Recommendation, ## Decision
```

This is a prototype only (per T-2703 inception governance — no production fix
without a human GO). It is **not** wired into the CI/bats-all suite yet. Once
(a) lands, re-running this file should flip it GREEN; it should then be
renamed (drop `_prototype`) and added to whatever suite
`upgrade_fresh_machine_simulation.bats` runs under, so any *future* audit rule
that inspects task-file structure gets exercised against the seed
automatically, closing exactly the gap identified in 5-Whys step 5.

This test only covers the seed-vs-audit axis. It does not by itself prevent a
*third* producer of inception tasks from diverging in the future (e.g. if a
new onboarding path is added later) — the deeper structural fix for that is
candidate (b) (single template source), which turns "stay in sync" from a
convention into an invariant.
