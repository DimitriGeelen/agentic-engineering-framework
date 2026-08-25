---
id: T-3144
name: "fw vendor ships executable code into consumer trees without checking git can
  see it"
description: >
  fw vendor ships executable code into consumer trees without checking git can see
  it

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: []
components: [bin/fw, lib/vendor-visibility.sh, tests/unit/vendor_visibility.bats]
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
created: 2026-08-25T20:44:07Z
last_update: 2026-08-25T22:28:33Z
date_finished: 2026-08-25T22:28:33Z
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
  - ts: '2026-08-25T20:45:08Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=202,acs=4)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-25T20:45:14Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-3144: fw vendor ships executable code into consumer trees without checking git can see it

## Context

Reported by 010-termlink on the chat arc (2026-08-25, offsets 415 and 424),
addressed to 999-AEF. A consumer's `.gitignore` blanket-ignores
`.agentic-framework/*` and re-includes a FIXED allowlist of directories. The
file's own comment says that list "is exactly what `git ls-files
.agentic-framework` already tracks" — i.e. it was generated from a snapshot in
time. Any directory upstream adds LATER is dropped silently, forever, on every
vendor event.

`tools/` is not on that list. In their tree that silently dropped 30 files,
including `corpus_lint.py` (857 lines), `corpus_explain.py` (227) and
`corpus_spec.py` (799) — which `bin/fw` execs directly at lines 4901/4907/4909.
They report we had already seen the downstream symptom and left a comment at
`bin/fw:400-401` quoting the error verbatim, then fixed the *message*.

**Verified independently, 2026-08-25: this repo is NOT affected.** Their check
run here prints nothing; all nine vendored directories including `tools/` and
`vendor/` are git-visible. That is a measurement, not an assumption — and it is
worth stating because absent-from-`git log` and never-vendored read identically,
which is the instrument problem 010-termlink corrected themselves on twice on
this same thread.

So there is no generator in this repo emitting that allowlist; it is per-consumer
and hand-maintained. What belongs here is the other half: **we write executable
code into a consumer tree and never check the consumer can see it.** A vendor
step that cannot tell "written and tracked" from "written and ignored" reports
the same thing for both.

Not acted on from the same thread: their earlier VERSION-downgrade advice, which
they retracted in offset 424 ("wrong, and harmful if built"). No change was made
on it here.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] AC1 — Reproduce before fixing. Build a synthetic consumer whose
      `.gitignore` carries the snapshot-allowlist shape (`.agentic-framework/*`
      plus `!` re-includes for a fixed set of directories), vendor into it, and
      show that a file in a directory outside the allowlist lands on disk and is
      invisible to git. Report which directories of the current framework are
      NOT on the allowlist shape 010-termlink quoted — `tools/` is the reported
      one; do not assume it is the only one.
- [x] AC2 — `fw vendor` (and the vendoring leg of `fw upgrade`) checks, after
      writing, that every file it just wrote is visible to git in the target.
      The check must run in the TARGET repo, not ours: `git check-ignore` is
      answered by the consumer's `.gitignore`, which is the thing at fault.
- [x] AC3 — A dropped file is surfaced as a FAIL, naming the directory and the
      ignore rule responsible (`git check-ignore -v` gives both). Not a WARN:
      the framework is shipping code that `bin/fw` then execs by absolute path,
      so the consequence is a hard runtime error (`python3: can't open file
      '<proj>/.agentic-framework/tools/corpus_explain.py'`), not untidiness.
- [x] AC4 — The check cannot pass vacuously. If it enumerates zero written
      files it must refuse, not report success — a vendor run that wrote nothing
      and a vendor run whose file list was never populated are the same output
      otherwise. Pin that with a fixture, not a comment (L-575, T-3140).
- [x] AC5 — Say plainly whether OUR repo is affected, with the command's output
      either way. We self-vendor into `.agentic-framework/`, so the same class
      applies to us; "not affected" is a finding that has to be measured, since
      absent-from-`git log` and never-vendored read identically (the exact
      instrument problem 010-termlink corrected itself on, twice).
- [x] AC6 — A test fails against pre-change code. Fixtures only: a synthetic
      consumer, no assertion pinned to a live consumer project, since consumer
      `.gitignore` files are edited outside this repo and a control pinned to
      one is a report about them rather than a check on us.

### Human
- [ ] [REVIEW] Decide whether a legacy consumer should be BLOCKED or WARNED on upgrade
      **Steps:**
      1. Read the blast radius: this makes `fw vendor` — and therefore `fw upgrade`,
         which vendors through it — exit 1 in any consumer whose `.gitignore` hides
         part of the vendored tree. Every consumer carrying the snapshot-allowlist
         shape is in that state today and does not know it.
      2. Reproduce the operator experience in ten seconds:
         `rm -rf /tmp/t3144x && mkdir -p /tmp/t3144x && git -C /tmp/t3144x init -q . && printf '.agentic-framework/*\n' > /tmp/t3144x/.gitignore && bin/fw vendor --target /tmp/t3144x 2>&1 | tail -25`
      3. Judge the trade: a FAIL stops an upgrade that would otherwise leave the
         consumer with code git cannot see (T-2942's `python3: can't open file` class,
         which took three separate tasks to find). A WARN keeps upgrades flowing and
         re-enters the loop where each fix is silently re-dropped.
      **Expected:** a decision — keep FAIL, or downgrade to WARN for the `fw upgrade`
      leg only while `fw vendor` stays FAIL. The `FW_ALLOW_INVISIBLE_VENDOR=1` escape
      hatch exists either way and logs Tier-2.
      **If not:** if FAIL is too aggressive for the fleet, say so and it becomes a WARN
      plus a `fw doctor` check in a follow-up task — the detection is the durable part,
      the severity is the reversible part.
- [ ] [REVIEW] Decide whether our own 23 vendored `*.png` files should be tracked
      **Steps:**
      1. `cd /opt/999-Agentic-Engineering-Framework && source lib/vendor-visibility.sh && fw_vendor_check_visibility "$PWD/.agentic-framework" "$PWD"`
      2. Note it is 22 files under `docs/` and one `web/static/logo.png`, all hidden
         by our own project-wide `*.png` rule at `.gitignore:65`.
      **Expected:** either add `!.agentic-framework/docs` + `!.agentic-framework/web`
      to `.gitignore` and commit the 23 images, or accept that a clone's vendored docs
      have missing images. No executable code is affected either way.
      **If not:** leaving it is defensible; this AC exists so the choice is made rather
      than inherited.

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

## Results

**Reproduced first (AC1).** Synthetic consumer carrying the snapshot-allowlist
shape 010-termlink reported (`.agentic-framework/*` plus `!` re-includes for the
directories that existed when the snapshot was taken), vendored into with
`fw vendor --target`. Result: **62 of 2649 written files invisible to git**,
while `fw vendor` printed *Vendored successfully* and exited 0.

`tools/` is not the only one, and the pattern in the rest is the point:

| Path | Files | Added to `includes[]` by |
|---|---:|---|
| `tools/` | 33 | T-2942 — consumer `fw corpus explain` was dead |
| `.context/designer/projects/` | 21 | T-2942 — the maps that `tools/corpus_explain.py` reads |
| `vendor/…designer…html` | 1 | T-3064 — `/designer` rendered an error page in every consumer |
| `status-transitions.yaml` | 1 | T-2674 — consumer enums froze at seed time |
| `VERSION`, `.upstream`, `.secret-scan-{patterns,allowlist}`, `.fw-not-a-project`, `.gitignore` | 6 | various |

Every one of those entries was added by a task fixing a *"consumer is missing X"*
bug. A stale allowlist silently re-drops each of them the moment it ships, so the
fix and the regression are the same event. That loop is what this check breaks.

**The check (AC2–AC4).** `lib/vendor-visibility.sh:fw_vendor_check_visibility`,
called from `do_vendor` after `FRAMEWORK.md` — the completeness sentinel — so the
tree it inspects is the tree a consumer actually gets. `fw upgrade` reaches it
for free: `lib/upgrade.sh:1543` vendors through `do_vendor`. `fw vendor self` is a
different path (`_self_vendor_libs`) and is deliberately untouched.

FAIL, not WARN, per AC3: `bin/fw` execs several vendored files by absolute path,
so the consequence is a hard runtime error naming `python3` and a missing file,
never vendoring. Zero enumerated files REFUSES with exit 2 (AC4) — *"nothing was
looked at"* is not *"nothing was ignored"*. Override `FW_ALLOW_INVISIBLE_VENDOR=1`,
logged Tier-2.

The remedy it prints was re-run, not just printed: pasting its `!` lines into the
fixture's `.gitignore` takes the same call from exit 1 to exit 0.

**AC5 — our own repo IS affected, and this corrects the previous session's claim.**
That claim ("not affected, all nine vendored dirs are git-visible") was measured at
*directory* granularity and is wrong at *file* granularity:

    FAIL: 23 of 2505 vendored file(s) are invisible to git in the target.
        docs                             22 file(s)   .gitignore:65:*.png
        web                               1 file(s)   .gitignore:65:*.png

All 23 are images, hidden by our own project-wide `*.png` rule. **No executable
code is hidden** — `bin/fw` execs `.py`/`.sh`, all visible — so the T-2942/T-3064
class does not bite us. The consequence is a clone whose vendored docs have
missing images and no Watchtower logo. The one-line remedy is a `!` re-include,
deliberately NOT applied here: it commits 23 binary files, which is a repo-weight
decision for the operator, not a defect fix.

**AC6, and what the tests are actually worth.** 8/8 green. "Fails against
pre-change code" is true and nearly worthless — the function did not exist, so
every test fails by NameError rather than by disagreeing with a behaviour (same
degenerate control as T-3138). The three tests marked `[instrument]` are the ones
carrying weight, because each is a false positive this check **shipped with** and
that only running it against real trees exposed:

1. `git check-ignore -v` prints negation matches too, so files re-included by
   `!…` looked identical to hidden ones — `FRAMEWORK.md` and `metrics.sh` were
   reported invisible while git saw them fine. Fixed by two passes: plain
   `check-ignore` decides *which*, `-v` only then supplies *which rule*.
2. `find` under the destination sees `__pycache__/` that Python wrote at
   *runtime*, not the vendor. 10 of a reported 87 were runtime droppings.
3. The per-directory rule column printed whichever rule awk saw first, so
   `web  55 file(s)  *.png` appeared when 54 of the 55 were hidden by a different
   rule — and it misled its own author for a full step. Now grouped by
   (directory, rule), so every row's cause is true for that row.

All three read as findings about the repo and were findings about the instrument.

## Verification

bats tests/unit/vendor_visibility.bats > /tmp/.t3144 2>&1 && grep -q "^ok 8 " /tmp/.t3144
! grep -q "^not ok" /tmp/.t3144
bash -n lib/vendor-visibility.sh
bash -n bin/fw
grep -q "fw_vendor_check_visibility" bin/fw
tools/bats-dead-negation-lint.py tests > /tmp/.t3144l 2>&1 && grep -q "dead 0 in 0 file" /tmp/.t3144l

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
# Why not `cmd | grep -q PAT` (L-387): P-011 runs each line under `set -eo
# pipefail`. When grep matches it exits and closes stdin while cmd is still
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
# shell has no `set -eo pipefail`. A line has returned 0 by hand and 141 under
# P-011, from the same directory, the same second. To rehearse for real:
#     bash -c 'set -eo pipefail; <your verification line>'
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


**Recommendation:** GO — keep FAIL on both legs, and track the 23 images.

**Rationale:** The two Human ACs are genuine calls, so here is my position on
both rather than a blank form.

*FAIL, not WARN, including the `fw upgrade` leg.* A WARN re-enters exactly the
loop this task documents: `tools/`, the designer maps, the pinned build and
`status-transitions.yaml` were each ADDED to `includes[]` by a task fixing a
"consumer is missing X" bug, and a stale allowlist silently re-drops each fix on
the day it ships. It took three separate tasks (T-2942, T-3064, T-2674) to find
three instances of one class, because the symptom names `python3` and never names
vendoring. A WARN on an upgrade nobody reads is indistinguishable from the silence
we already had. The disruption is bounded and self-describing — the FAIL prints
the exact `!` lines to paste, and re-running with them takes the same call from
exit 1 to exit 0 (pinned by a test, not just asserted). `FW_ALLOW_INVISIBLE_VENDOR=1`
unblocks anyone who needs to ship now, and logs Tier-2 so the debt is visible
rather than absorbed.

*Track our 23 `*.png` files.* A vendored `docs/` whose images are absent from
every clone is a broken deliverable, and 23 small images is not a repo-weight
argument worth having. This is the cheaper half of the decision by a wide margin.

The one thing I would not do is quietly narrow the check to executable files to
dodge the png finding. The check is right and our repo is mildly wrong; that is
the correct way round.

**Evidence:**
- Reproduction: 62 of 2649 files invisible in a synthetic consumer while
  `fw vendor` printed success and exited 0 — `tests/unit/vendor_visibility.bats`
- Our own tree: 23 of 2505 invisible, all `*.png`, no executable code affected.
  This CORRECTS the previous session's "not affected", which was measured at
  directory granularity.
- 8/8 tests green; 6/6 P-011 verification commands green; reviewer PASS with a
  cross-project-blast escalation, which is what these two Human ACs answer.
- Three false positives found by running the check against real trees rather
  than reading it — each now pinned by an `[instrument]` test.

## Decisions

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

### 2026-08-25T20:44:07Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3144-fw-vendor-ships-executable-code-into-con.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-b2c00636
- **Timestamp:** 2026-08-25T22:28:35Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** yes
- **Findings:** none

- **Layer-1 escalations:** 1
  1. **cross-project-blast** (medium) — Cross-project or cross-repo change
     - matched: `consumer project`

### 2026-08-25T22:28:33Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
