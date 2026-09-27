# T-3527 — the arc-scoped-driver judge agent

D-662 slice 3 of 3 (T-3524 GO). Builds the second judge the operator ruled for:
an independent agent that judges an arc-scoped driver against the arc's own
goal, wrapping (not replacing) `lib/arc-driver-review.sh`'s static checks
(T-3429, D-586).

## What was built

| File | Role |
|---|---|
| `lib/arc_driver_judge.py` | The judge: `run_static_review()` (wraps the real, unmodified `_arc_driver_review_run` via subprocess), `resolve_arc_goal()` / `check_self_admission()` (the arc-goal yardstick), `judge_driver()` (combiner) |
| `lib/arc_driver_judge_cli.py` | Inline CLI (`python3 -m lib.arc_driver_judge_cli <arc-id> "<name>"\|--all [--json]`) |
| `lib/arc.sh` | Wiring: `judge-driver` verb (`arc_judge_driver`), help text |
| `tests/unit/test_arc_driver_judge.py` | 28 unit tests |
| `tests/unit/t3527_arc_driver_judge_entrypoint.bats` | 6 real-entrypoint reachability tests |

Usage: `fw arc judge-driver <arc-id> "<name>"` or `fw arc judge-driver <arc-id> --all`,
either with `--json`. Read-only, no §ACD gate (nothing here to approve or refuse
— it only reports a verdict).

## Design decisions and why

**The wrap is literal, not conceptual.** `run_static_review()` sources the real
`lib/arc-driver-review.sh` from its own on-disk location (`Path(__file__).parent`)
and calls `_arc_driver_review_run` directly via `bash -c`, always `--dry-run`.
Nothing about checks (a)/(b)/(c) is reimplemented — pinned by
`test_arc_driver_review_sh_is_not_reimplemented` (no local `check_a`/`check_b`/
`check_c`, no estimator import) and confirmed by `git diff --stat
lib/arc-driver-review.sh` showing zero changes.

**OBS-559 (the assigned defect) does not manifest the way its name suggests.**
Empirically (not assumed), `est is None` — the condition `check_a` actually
tests — is effectively unreachable for a normal missing/broken estimator file,
because `importlib.util.spec_from_file_location()` returns a valid spec for any
`.py`-suffixed path regardless of whether the file exists. What actually happens
when the estimator can't be executed is `est` ends up holding a broken,
partially-empty module object, and `check_a`'s later `est._handler_table()`
call raises `AttributeError`, producing the reason text `"handler table
unreadable (AttributeError: ...)"` — a different string than the docstring's
`"estimator unimportable"`. I verified this by literally breaking the import
(pointing `FRAMEWORK_ROOT` at a directory with no `agents/termlink/
bvp-estimator/` at all) and reading the real output, rather than assuming the
obvious-sounding failure mode was the actual one. `_is_tooling_failure()`
recognises both signatures, so the fix is not coupled to guessing right about
which one fires in the field.

**The arc-goal yardstick is NOT lexical overlap.** I tried it first: token
overlap between a driver's rationale and the arc's `description:`/
`headline_mechanic:`, excluding stopwords and D1-D4 tokens. Measured against 8
real, already-approved drivers across the live corpus, 3 (37.5%) shared ZERO
significant vocabulary with their own arc's goal text while being perfectly
good drivers (continuous-run's "Discard fidelity", onboarding-shape-detection's
"unknown-input-safety", watchtower-redesign's "aesthetic-cohesion") — good
drivers are *supposed* to contrast with D1-D4, not parrot the arc's phrasing
back. I rejected that approach before writing a single test for it and instead
mirrored `lib.bvp_judge`'s actual shape (structural checks, not semantic
matching): a **self-admission** check (does the rationale's own text admit
doubt — "weak candidate", "may prefer to", "likely to be withdrawn", etc.,
calibrated against every `proposed_scoped_drivers[]`/`scoped_drivers[]` entry
in `.context/arcs/` with exactly 2 hits, both genuine, zero false positives) and
a **level-match** check (a near-max-weight driver resting only on the
project-level D1-D4 fallback, mirroring bvp_judge's high-claim-on-fallback-only
rule). Both are AMBER/RED-worthy findings a keyword-matching static check
literally cannot make, and neither produced a false positive against live data.

**Self-admission is AMBER, not RED.** The static checks (a/b/c) already passed
by the time this branch is reached — this is the candidate's own text
expressing doubt, not a structural defect, so amber's contract meaning
("proceed, and record the guidance") fits better than a hard block. The
operator's `--i-am-human` override on `approve-driver` remains available to
approve it having read the flag.

## Verdicts against every live in-progress arc

Ran `fw arc judge-driver <slug> --all --json` against all 19 arcs in
`.context/arcs/` (2026-09-27). Nothing crashed; no arc produced an exception.

| Arc | Drivers | Verdicts |
|---|---|---|
| arc-020 | identity-fidelity, provisioning-safety | RED, RED (both: no scoring spec) |
| continuous-run | Discard fidelity, Loop closure (conditional) | RED (no spec), RED (no spec **and** rationale names no D1-D4 directive — genuine pre-existing check (c) finding, confirms check (c) still fires through the wrap) |
| designer-corpus | vocabulary-coverage, corpus-fidelity, seam-fluidity | RED × 3 (no spec) |
| dispatch-safety | uncertainty-recognition, severity-likelihood-calibration | GREEN, GREEN |
| dispatch-safety | operator-resolution-latency | RED (no spec) |
| onboarding-shape-detection | unknown-input-safety, first-run-recoverability | RED, RED (no spec) |
| parallel-execution-aef | Disjoint Write-Set Discipline, Wire-Evidence Falsifiability | GREEN, GREEN |
| value-prioritisation | sovereignty-preservation, estimator-fidelity | GREEN, GREEN |
| value-prioritisation | adoption-friction | RED (no spec) |
| watchtower-redesign | aesthetic-cohesion, render-fidelity, theme-portability | GREEN × 3 |
| inception-review-loop | feedback-loop-completeness | GREEN |
| 9 other arcs | (none) | skipped: no proposed/scoped drivers |

**What surprised me:** nothing crashed, and the RED count (11 drivers, all for
the same reason — no scorable handler/spec) matches `fw doctor`'s independent
"six live drivers unscorable" warning almost exactly once scoped correctly: 6
of the 11 are on **approved** `scoped_drivers[]` (arc-020 ×2, continuous-run
×2, onboarding-shape-detection ×2 — the count the existing audit already
tracks), and the remaining 5 are on **proposed** `proposed_scoped_drivers[]`
entries the audit doesn't count because they haven't been through
`approve-driver` yet. That the two calibrated self-admission fixtures
(`dispatch-safety/operator-resolution-latency`, `continuous-run/Loop closure
(conditional)`) both also fail the wrapped static check first (self-admission
is checked *after* the static wrap, and both happen to fail check (a) or (c)
too) meant the self-admission branch itself was never exercised by live data —
only by the unit tests. No arc hit the project-level-fallback branch (every
in-progress arc currently has a non-empty `description`/`headline_mechanic`),
confirming that branch is a real but currently-dormant edge case, exactly as
its sibling in `bvp_judge.py` is.

## Reachability

`tests/unit/t3527_arc_driver_judge_entrypoint.bats` runs the real `bin/fw arc
judge-driver` subprocess — no `--i-am-human`, no `--from-watchtower`, no
`FW_ALLOW_*` — against probe arc files dropped into `.context/arcs/` (cleaned
up in teardown). This verb carries no §ACD gate (it never mutates the arc
YAML), so there was no gate-vs-reachability gap to find here; the tests instead
pin that the command is wired end-to-end through `lib/arc.sh` and produces the
real verdict shape. Also manually exercised in this same session (itself an
agent session, `$CLAUDECODE=1`) against `arc-020` and all 19 live arcs, above.

## Out of scope, confirmed by diff

`git diff --stat` shows no changes to `agents/termlink/bvp-estimator/
estimator.py`, `lib/judge_verdict.py`, or any `arc_close`/`arc_abandon` code
path in `lib/arc.sh`. No multi-model panel code was added anywhere.

## Tests

- `tests/unit/test_arc_driver_judge.py` — 28 tests (contract imports, the wrap,
  OBS-559 tooling-vs-genuine distinction — including one test against a REAL
  unimportable estimator state, not a mock — the self-admission/level-match
  yardstick, population scoping, the always-green mutant kill, helper
  functions).
- `tests/unit/t3527_arc_driver_judge_entrypoint.bats` — 6 tests, real
  entrypoint, no override flags.
- `bin/fw vendor self --check` — clean.
