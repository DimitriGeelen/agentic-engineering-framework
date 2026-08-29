---
id: T-3217
name: "bats skips are invisible to the P-011 verification idiom — a skipped test reports
  ok"
description: >
  A bats test that calls skip prints 'ok N ... # skip' and is counted as passing.
  The repo-standard P-011 verification idiom '! grep -q "^not ok" out' therefore cannot
  distinguish a test that ran and passed from one that declined to run. Found while
  landing T-3213: a chmod-500 denial test guarded itself with 'skip when root', and
  this suite runs as root on the origin host and in CI — so that AC asserted nothing
  on every run that mattered, while the report said ok. Measured blast radius: 138
  verification lines use the not-ok idiom; 50 skip call sites across 27 bats files.
  The dangerous subset is skips whose guard is TRUE on the host that ships the suite;
  legitimate optional-dependency skips (termlink absent, etc) are not the target and
  must not be flagged.

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
arc_id: continuous-run
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
created: 2026-08-29T15:12:34Z
last_update: 2026-08-29T22:34:58Z
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
  - ts: '2026-08-29T15:14:38Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      Discard fidelity: 0
      Loop closure (conditional): 0
      D1: 4
      D2: 3
      D3: 3
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 1
    rationale: Discard fidelity=0 (no-signal); Loop closure (conditional)=0 
      (no-signal); D1=4 (body:structural-gate); D2=3 
      (body:component-silent-failure); D3=3 (body:component-discoverability); 
      D4=2 (body:env-class-handled); F-RECALL=2 (body:lightly-promoted); 
      F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=1 
      (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-08-29T15:15:08Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=257,acs=7)
    rubric_sha: e4a00f38e801
---

# T-3217: bats skips are invisible to the P-011 verification idiom — a skipped test reports ok

## Context

Found while landing T-3213 (arc-012 IW-6), not by looking for it.

That suite denied writes with `chmod 500` and guarded the test:

    if [ "$(id -u)" -eq 0 ]; then skip "chmod 500 does not deny root"; fi

The suite runs as root on the origin host and in CI. So the test reported
`ok 6 ... # skip` on every run that mattered, and the AC it covered — T-3209's
SECOND cause for an absent ledger — was measured nowhere. It was fixed in T-3213
by denying with a directory at the target path, which fails for root too.

**The generalisable defect is not that one test.** It is that the repo-standard
P-011 idiom cannot see the difference:

    timeout 300 bats <suite> > /tmp/.out 2>&1 && ! grep -q "^not ok" /tmp/.out

A skip is not a `not ok`. The gate passes. The report says ok. Nothing anywhere
distinguishes a suite that ran from one that declined to.

Measured 2026-08-29:

| | count |
|---|---|
| verification lines using the not-ok idiom | 138 |
| bats files containing `skip` | 27 |
| `skip` call sites | 50 |

**CORRECTION, 2026-08-29 (during the build).** The 27/50 figures above were
measured over `tests/unit/` only and are quoted here as filed rather than
silently replaced. Over the whole of `tests/`:

```
bin/fw test lint          # or, directly:
python3 tools/bats-silent-skip-lint.py --census tests/
```

| class | count | meaning |
|---|---:|---|
| DEPENDENCY | 49 | guard probes something optional (`command -v`, `docker info`, an import) |
| OTHER | 174 | guarded, but not by a dependency probe — a fixture, a live artefact, an operator state |
| STANDING | 0 | guard is fixed for a deployment (`id -u`, `$EUID`, `$CI`, `uname`) |
| UNCONDITIONAL | 0 | no guard at all |
| **total** | **223** | across 119 files |

STANDING was **1** when the detector was first run — `tests/unit/lib_preflight.bats:76`,
`skip "running as root — write perms always pass"`, the same shape as T-3213's
and firing on every run here. Fixed in this task by denying with a path that
does not exist, which `[ -w ]` reports false for root too. The count is 0
because the finding was fixed, not because nothing was found.

Reconciliation, since a census that quietly loses rows is this task's own
failure class: the detector counts 223 where a naive `grep` counts 225. Every
difference is accounted for — five continuation lines re-anchored to the guard
line above them, and one `skip = DUMPS | {...}` Python assignment that is not a
call site. No real call site is dropped.

**The target is a subset, and getting that wrong is the main risk.** Many skips
are correct: an optional dependency absent (termlink not installed), a platform
that genuinely cannot run the case. Those must NOT be flagged — a detector that
reddens them will be suppressed wholesale and protect nothing. The dangerous
class is a skip whose guard is TRUE on the configuration the suite actually ships
on, so the test never runs where it counts.

Same family as L-628 (`! cmd` inert in non-final bats position) and T-3203
(errexit suppressed in the P-011 gate): a construct that reads like an assertion,
is counted like one, and asserts nothing. Peer 577-CashWeb reached the same class
from the record-field direction (their G-069). The invariant across all of them:
**the green does not depend on the subject.**

## Acceptance Criteria

### Agent
- [x] The current skip inventory is classified, not just counted: every call site is labelled legitimate (optional dependency) or silent (guard fixed for the deployment / no guard). The split is recorded with the command that produced it — see the CORRECTION table in Context. The filed figure of 50 was `tests/unit/` only; the real corpus is 223 across 119 files, and the reconciliation against a naive grep is stated so a census that lost rows could not read as clean.
- [x] A detector reports silent skips and stays quiet on legitimate ones. `tools/bats-silent-skip-lint.py`. Of 223 call sites it flags the shapes with no legitimate reading and leaves 223 alone; 6 of the 17 test legs are false-positive controls (dependency guard, else-branch, backslash continuation, Python assignment, two heredoc-mention cases).
- [x] The detector is wired into `bin/fw test lint`, and the wiring is asserted twice: statically (the invocation is in `bin/fw`) and behaviourally (running `fw test lint` emits the `Silent-Skip` section).
- [x] A corrected P-011 verification idiom is documented in `.tasks/templates/default.md` next to the pipefail guidance — the two-line form (`! grep -q "^not ok"` for failures, `grep -c '# skip'` for coverage), with the T-3213 origin and the note that a non-zero expected skip count must be justified.
- [x] MUTATION CONTROL: the standing-guard fixture is detected by the live tool (exit 1) and NOT detected by a mutant with the `STANDING` pattern emptied (exit 0), with the mutation asserted to have changed bytes. Test 11, `removing the STANDING comparison stops the standing skip being detected`. The behavioural counterpart is test 15, where static and TAP modes converge on one fixture by independent evidence.
- [x] The 138 existing verification lines are NOT bulk-rewritten. Nothing in this task touches a `## Verification

timeout 900 bats tests/lint/bats-silent-skip.bats > /tmp/.t3217.out 2>&1 && grep -q "^ok 17" /tmp/.t3217.out && ! grep -q "^not ok" /tmp/.t3217.out
test "$(grep -c '# skip' /tmp/.t3217.out)" -eq 0
python3 tools/bats-silent-skip-lint.py tests/
timeout 300 bats tests/unit/lib_preflight.bats > /tmp/.t3217pf.out 2>&1 && ! grep -q "^not ok" /tmp/.t3217pf.out
test "$(grep -c '# skip' /tmp/.t3217pf.out)" -eq 0
grep -q "bats-silent-skip-lint.py" bin/fw
grep -q "A SKIPPED BATS TEST REPORTS" .tasks/templates/default.md
python3 -c "import ast; ast.parse(open('tools/bats-silent-skip-lint.py').read())"
python3 tools/bats-dead-negation-lint.py tests/lint/bats-silent-skip.bats
bash -n bin/fw
test -f .fabric/components/tools-bats-silent-skip-lint.yaml && test -f .fabric/components/tests-lint-bats-silent-skip.yaml
bin/fw vendor self --check > /tmp/.t3217v.out 2>&1 && grep -q "in sync" /tmp/.t3217v.out

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

**Symptom.** `ok 6 <name> # skip <reason>` satisfies the repo-standard
verification line `! grep -q "^not ok"`. A suite that declined to run its test
and a suite that ran it produce output the gate reads identically. T-3213's
root-guarded test skipped on every run that mattered, for as long as it existed,
while reporting ok.

**Root cause.** The idiom asserts the ABSENCE OF FAILURE and was read as
evidence of COVERAGE. Those coincide only when every test ran, and nothing
anywhere checked that. TAP is explicit about it — the skip directive is right
there in the line — so this is not a missing signal, it is an unread one.

**Why structurally allowed.** The idiom was written into the task template, so
every task inherited it, and it is correct for what it claims. Nothing was
wrong enough to notice: no failing check, no warning, no drift. A skip's cost
is invisible by construction, because the thing it hides is a test that did not
run, and a test that did not run produces no evidence of anything — including
of its own absence. The only surface where it could have shown up is a coverage
delta nobody computes.

**Prevention.** Two layers, deliberately different in kind.
`tools/bats-silent-skip-lint.py` static mode reads guard SHAPE and runs on every
`fw test lint`, flagging only the two shapes with no legitimate reading; `--tap`
mode reads what a real run DID and has no false positives by construction. The
template now carries the two-line idiom so new tasks inherit a check for
coverage alongside the check for failure.

**What this does not do.** The 138 existing verification lines are unchanged —
retrofitting them is a separate decision with its own blast radius, and the
lint answers the corpus-wide question without touching any of them. The static
mode is a line scan: a standing-configuration test hidden inside a helper
function is invisible to it, which is why the empirical mode exists and why the
static shape list is two entries rather than ten. A scan that guessed at the
rest would produce the noise that gets a lint disabled.

## Evolution

### 2026-08-29 — the detector reproduced the defect it was written to find

- **What changed:** the first working version silently went blind. A `<<TAG`
  inside a COMMENT (a file header describing the heredoc hook it tests) and
  inside QUOTED STRINGS (`run has_write_pattern "cat <<EOF > f"`) each opened a
  heredoc that never closed, so the scanner skipped the rest of those files and
  reported clean. Four real call sites lost, in a tool whose entire purpose is
  reporting things that are silently not measured.
- **How it was caught:** not by review. By reconciling the detector's census
  against a naive grep and requiring every difference to be explained — the same
  count-reconciliation move as T-3219, applied to this tool's own output. Five
  differences were continuation re-anchors, one was a Python assignment, and
  four were the bug.
- **Plan impact:** three guards added (comments excluded, a quote state machine
  that tracks which quote opened a span, and a lookahead that refuses to enter
  heredoc mode unless the delimiter is actually closed later), plus three
  regression legs. The `SKIPCALL` fixture trick was needed for the same reason
  the sibling lint needs `BATSTEST`: the lint's own test data was being reported
  as the lint's own findings.
- **Triggered:** nothing new filed. Peer 832 named this exact class on the chat
  arc at @804 — *a character-level scan standing in for shell structure, so an
  argument that merely MENTIONS a thing is treated as an action on it* — and
  this reproduced it within the hour. Their advice, taken: the question is not
  "is the pattern right" but "is it reading an argument or an action".

## Recommendation

**Recommendation:** GO

**Rationale:** The detector is built, wired, tested with its false-positive
controls and its mutation control, and the one real finding it produced is
fixed rather than suppressed. The remaining Human AC asks whether the
legitimate/silent boundary matches your judgement — that is a taste call about
where the line sits, and it is the one thing here I should not settle alone. It
does not block the mechanism: if you move the boundary, the heuristic narrows,
and the tests that hold it are already written.

**Evidence:**
- `tools/bats-silent-skip-lint.py`, two modes; `tests/lint/bats-silent-skip.bats`, 17 legs, 0 skips.
- Census: 223 call sites across 119 files — 49 DEPENDENCY, 174 OTHER, 0 STANDING, 0 UNCONDITIONAL. Reconciled against a naive grep with every one of the 5 differences accounted for.
- STANDING was 1 before the fix (`lib_preflight.bats:76`, the T-3213 shape, firing on every run here). Fixed, not allowlisted.
- Wiring asserted both statically and behaviourally: `fw test lint` emits the `Silent-Skip` section and returns OK.
- Mutation control: emptying the `STANDING` pattern stops detection (test 11). Convergence: static and TAP modes reach the same fixture by independent evidence (test 15).
- The detector's own heredoc-blindness bug was found by census reconciliation, not review, and is pinned by three regression legs.

## Decisions

### 2026-08-29 — two modes, because the question has a cheap half and an honest half

- **Chose:** a static shape scan cheap enough for `fw test lint`, plus a
  `--tap` mode that reports what a real run actually skipped.
- **Why:** the honest answer to "is this skip dangerous" is empirical — does its
  guard hold on the host the suite ships on — and that needs a run. But a check
  that needs a full bats run will not survive on the lint pass, and one that
  never runs protects nothing. The static half catches the shapes that cannot be
  anything but blind; the empirical half catches the rest when a run happens.
- **Rejected:** static only (cannot see a guard hidden in a helper); TAP only
  (nothing would run it by default, which is the failure being fixed).

### 2026-08-29 — flag two shapes, not ten

- **Chose:** UNCONDITIONAL and STANDING only. Everything else — 223 of 223 call
  sites after the fix — is left alone by the static mode.
- **Why:** most skips in this corpus are correct. A detector that reddens an
  absent optional dependency gets suppressed wholesale, and then it protects
  nothing at all. Six of the seventeen test legs exist to hold that line.
- **Rejected:** classifying by the skip's REASON TEXT in static mode. It is
  prose, it is gameable, and it would have flagged legitimate skips whose author
  worded them tersely. Reason text IS used in `--tap` mode, where the guard is
  not available — and there it is deliberately generous, because mislabelling a
  missing dependency as a defect is the expensive error.

### 2026-08-29 — fix the one finding rather than ship a lint that fails

- **Chose:** repair `lib_preflight.bats:76` in this task, using T-3213's pattern
  (deny with a path that does not exist, which `[ -w ]` reports false for root).
- **Why:** wiring a detector into `fw test lint` while it reports a finding
  trains everyone to read that section as noise on its first day.
- **Rejected:** an allowlist entry for it. The finding was real and the fix was
  four lines; suppressing it would have been the first entry in exactly the
  mechanism that makes such tools useless.

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-08-29T15:12:34Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3217-bats-skips-are-invisible-to-the-p-011-ve.md
- **Context:** Initial task creation

### 2026-08-29T15:14:38Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-08-29T15:15:09Z — status-update [task-update-agent]
- **Change:** horizon: now → next
- **Change:** status: started-work → captured (auto-sync)

### 2026-08-29T22:34:58Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)
