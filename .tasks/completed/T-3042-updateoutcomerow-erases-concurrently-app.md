---
id: T-3042
name: "update_outcome_row erases concurrently-appended dispatches.jsonl rows"
description: >
  update_outcome_row erases concurrently-appended dispatches.jsonl rows

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [bin/fw, lib/keylock.py, lib/resolver.py, lib/spawn.py, lib/write_set.py, tests/unit/t3039_write_set_implicit.bats, tests/unit/test_spawn.py]
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
created: 2026-08-16T16:54:50Z
last_update: 2026-08-17T06:57:40Z
date_finished: 2026-08-17T06:57:40Z
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
  - ts: '2026-08-16T17:00:08Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-16T17:00:15Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 2
      D3: 3
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=2 
      (body:telemetry-or-audit-entry); D3=3 (body:component-discoverability); 
      D4=2 (body:env-class-handled); F-RECALL=0 (no-signal); F-AUTONOMY=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:15Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 2
      D3: 3
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 1
    rationale: D1=4 (body:structural-gate); D2=2 
      (body:telemetry-or-audit-entry); D3=3 (body:component-discoverability); 
      D4=2 (body:env-class-handled); F-RECALL=0 (no-signal); F-AUTONOMY=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=1 
      (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
---

# T-3042: update_outcome_row erases concurrently-appended dispatches.jsonl rows

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] A regression test in `tests/unit/test_spawn.py` reproduces the race: a row
      appended to `dispatches.jsonl` concurrently with `update_outcome_row()`
      survives. It **fails against the pre-fix code** — verified by stashing the
      fix and running it — and passes after. Both directions stated in the task.
      → `test_concurrent_append_survives_update_outcome_row`. Pre-fix (fix
      patched out, `lib/keylock.py` moved aside): **FAILED** on the symptom, not
      on a missing symbol — `AssertionError: concurrently-appended row was
      ERASED by update_outcome_row's os.replace — ledger holds ['row-1',
      'row-2']`. Post-fix: **PASSES** (33/33 in the file).
- [x] `lib/spawn.py:update_outcome_row` takes an exclusive `fcntl.flock` on a
      **sidecar** lock path (never on `dispatches.jsonl` itself, whose inode
      `os.replace` swaps) around the read→replace window.
      → `lib/spawn.py:243` wraps the whole read→replace window in
      `keylock.guarding(DISPATCHES_LOG)`; the lock lives at
      `.context/locks/dispatches.lock`. Pinned by
      `test_ledger_lock_is_a_sidecar_not_the_ledger_itself`.
- [x] The appender at `lib/resolver.py:813` takes the **same** lock. Locking only
      the rewriter does not close the race; both sides or neither.
      → extracted to `lib/resolver.py:append_dispatch_row` (line 746), which
      takes `keylock.guarding(DISPATCHES_LOG)` — the same sidecar path derived
      from the same ledger. Pinned by
      `test_appender_blocks_while_rewriter_holds_the_ledger_lock`.
- [x] Lock acquisition is bounded (no indefinite block) and a timeout degrades
      **loudly** — never silently skips the outcome write.
      → `LOCK_NB` poll to a deadline (`FW_LEDGER_LOCK_TIMEOUT`, default 30s);
      on expiry a stderr banner is printed and `keylock.LockTimeout` is raised.
      It never returns "did not get the lock" as an ordinary value. Pinned by
      `test_lock_timeout_is_bounded_and_raises_loudly`.
- [x] The lock file is created with a mode a future non-root principal can open
      for writing (T-3041 de-rooting is in flight; do not regress it).
      → `os.open(..., 0o666)` plus an explicit `chmod` (umask 022 would
      otherwise mask it to 0644 and lock out every later non-root principal);
      lock dir 0o777, both best-effort. Asserted in the sidecar test.
- [x] The four existing `test_update_outcome_row_*` tests stay green.
      → `_rewrites_match`, `_no_match_returns_false`, `_no_log_returns_false`,
      `_empty_dispatch_id_returns_false` all pass, unmodified.
- [x] `## RCA` answers the structural question: whether the ~24-site
      `# T-100190/T-100191 … atomic write (L-493 class)` comment — which means
      *crash*-atomic and is silent on concurrency — contributed to this site
      being written this way.
      → answered under **Why structurally allowed** below: yes, contributory
      but not causal at this site — the comment is absent here, the *framing*
      was reproduced in prose.
- [x] The ledger format is unchanged. Append-only + derived view is T-3041's
      recommendation and is explicitly out of scope here.
      → no schema field added, removed or renamed; rows are byte-identical in
      shape. The only new file is a zero-byte sidecar lock outside the ledger.

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

# The regression suite, including the four pre-existing update_outcome_row tests.
python3 -m pytest tests/unit/test_spawn.py -q > /tmp/.t3042-spawn.out 2>&1 && grep -q "passed" /tmp/.t3042-spawn.out
# The race test specifically — the one that fails against pre-fix code.
python3 -m pytest tests/unit/test_spawn.py -q -k "concurrent_append_survives or appender_blocks or sidecar or lock_timeout" > /tmp/.t3042-race.out 2>&1 && grep -q "4 passed" /tmp/.t3042-race.out
# The appender side is the half that is easy to forget; resolver must stay green.
python3 -m pytest tests/unit/test_resolver.py tests/unit/test_outcome.py -q > /tmp/.t3042-resolver.out 2>&1 && grep -q "passed" /tmp/.t3042-resolver.out
# Both sides of the pairing take the lock — a lock on one side protects nothing.
grep -q "keylock.guarding(DISPATCHES_LOG)" lib/spawn.py
grep -q "keylock.guarding(DISPATCHES_LOG)" lib/resolver.py
# The lock is a sidecar: os.replace swaps the ledger inode, so locking the
# ledger itself would leave the appender holding a lock on a dead inode.
python3 -c "import sys; sys.path.insert(0,'lib'); import keylock; from pathlib import Path; p=keylock.lock_path_for(Path('.context/dispatches.jsonl')); assert p==Path('.context/locks/dispatches.lock'), p"
# Ledger format unchanged: every existing row still parses as one JSON object.
python3 -c "import json,pathlib; p=pathlib.Path('.context/dispatches.jsonl'); [json.loads(l) for l in p.read_text().splitlines() if l.strip()] if p.exists() else None"

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

**Symptom:** Dispatch rows disappear from `.context/dispatches.jsonl` outright.
Not left stale, not left `pending` — gone, as if the dispatch never happened.
Nothing reports the loss, because the evidence of the loss is the thing that was
lost. Downstream, CLAUDE.md's measured pass-rate table (`workflow_type` × N ×
verification pass) is computed by joining this file against
`dispatch-outcomes.jsonl`, so the numbers agents consult when deciding whether
to dispatch at all are biased by an unknown, unreported amount.

**Root cause:** `lib/spawn.py:update_outcome_row` implemented an in-place field
update on an append-only log as *read-all → rewrite-all → `os.replace`*. That
sequence is not a read-modify-write of one row; it is a whole-file swap whose
input is a snapshot. `lib/resolver.py:813` appends with `O_APPEND` to the same
file. Any row appended after the read loop finishes and before `os.replace`
lands in the inode `os.replace` is about to unlink, and is destroyed by a
writer that never knew it existed. `os.replace` is the mechanism of loss, not a
protection that failed: the more reliably it swaps, the more reliably it erases.

The window needs no second uid and no unusual load. The framework runs up to 5
concurrent workers and cron dispatchers, and `spawn_dispatch` calls this on
*every* dispatch completion, so the window opens on every worker that finishes
while any other worker starts.

The fix pairs both sides on one sidecar lock (`.context/locks/dispatches.lock`,
the `lib/keylock.sh` directory). Locking only the rewriter would have been worse
than nothing — it would look like a fix and change no outcome.

**Why structurally allowed** — the question about the `L-493` idiom:

*Contributory, but not causal at this site.* The distinction matters for
prevention, so both halves are stated precisely.

Not causal: the `# T-100191: same-dir temp + os.replace — atomic write (L-493
class)` comment does **not** appear at `lib/spawn.py`. It sits at 15 canonical
sites (8 in `lib/`, 5 in `agents/context/`, 2 in `agents/audit/`), mirrored into
`.agentic-framework/` and the worktrees for ~90 textual occurrences. This site
was not written by copying that comment.

Contributory: it was written by copying that *framing*. The pre-fix docstring
read "Atomic via tmp + os.replace so a crash mid-rewrite leaves the original
intact" — the L-493 idiom restated in the author's own words, arrived at
independently, and reaching the identical conclusion that the write was now
safe. That is the more troubling form of influence: a shared comment can be
audited and amended at 15 sites, whereas an internalised idiom regenerates
itself at site 16 with no string to grep for.

What the idiom actually guarantees, and where it stops:

| Property | tmp + `os.replace` | Needed here |
|---|---|---|
| A reader never sees a half-written file (L-493's literal origin: `fw fabric drift` grepping a card mid-write) | yes | — |
| A crash mid-write leaves the previous version intact | yes | — |
| A concurrent *writer*'s work is preserved | **no** | **yes** |

L-493's own text names its scope exactly — "any framework writer of a file that
other tools **scan/grep** concurrently" — readers, not writers. The learning is
correct and was correctly applied everywhere it is cited. The failure is that
"atomic write" reads, in English, like a total safety property, so the unstated
half ("…against readers and crashes; it *destroys* concurrent appends") never
gets supplied. Applied to an append-only ledger the idiom inverts: for a file
whose other writer only ever appends, whole-file replacement is the single most
destructive way to update one field.

Second contributing factor, independent of the idiom: `lib/outcome.py:177`
documents the invariant this violated — "Append-only design: NEVER touches
dispatches.jsonl" — as a *comment in the module that honours it*, not as a test
or a gate. An invariant asserted only in the prose of the compliant module
cannot constrain a different module written later. `spawn.py` broke a rule that
was, from `spawn.py`'s vantage point, invisible.

**Prevention** (distinct from the fix):
1. `test_concurrent_append_survives_update_outcome_row` reproduces the real race
   with a real thread and a widened window; verified to fail on the erased row
   against pre-fix code, so it is a live oracle rather than a green rubber stamp.
2. `test_appender_blocks_while_rewriter_holds_the_ledger_lock` pins the *pairing*
   directly. Un-locking either side turns it red — the half-fix (rewriter only)
   is the plausible regression, and it is now the tested one.
3. `lib/keylock.py` exists as the Python sibling of `lib/keylock.sh`, so the next
   author who needs this reaches for a primitive instead of reasoning from
   scratch about flock and inode swaps. Its module docstring carries the
   sidecar-vs-inode reasoning at the point of use.
4. Follow-up not taken here (out of scope, worth filing): the ~15 `L-493` comment
   sites should say *crash-atomic and reader-atomic; NOT writer-safe* so the
   idiom stops implying a guarantee it does not carry. Every one of those sites
   should be checked for a concurrent appender; this task fixed the one site
   that provably had one.

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

### 2026-08-16T16:54:50Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3042-updateoutcomerow-erases-concurrently-app.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-26579e6a
- **Timestamp:** 2026-08-17T06:57:48Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-08-17T06:57:40Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
