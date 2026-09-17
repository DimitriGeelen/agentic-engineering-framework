---
id: T-3380
name: "Watchtower outage ran 5h35m unreported: the 1-minute liveness rail was committed
  100644 and had been dying Permission denied for 34 days, invisible to the exec-bit check"
description: >
  Watchtower died with the 2026-09-17 17:09 reboot and stayed down 5h35m with no rail
  reporting it. Root cause: agents/monitor/liveness-check.sh is committed 100644, so
  every cron exec (1-minute + @reboot) died Permission denied — 13,680 of them — and it
  had produced no output since 2026-08-14. The T-3317 exec-bit check examines only
  index-100755 files, so it printed PASS throughout. Fixes the bit, and adds a check
  that joins from the deployed crontab instead of the git index.
  NOTE: this task was filed under the name "liveness-check records stopped every minute
  and nothing consumes it" — that framing was wrong and the measurement corrected it;
  see ## Context. The delivery gap is real but separate, filed as OBS-435.

status: work-completed
workflow_type: build
owner: agent
horizon: null
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
created: 2026-09-17T20:42:51Z
last_update: 2026-09-17T20:58:36Z
date_finished: 2026-09-17T20:58:36Z
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
  - ts: '2026-09-17T20:45:10Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=299,acs=8)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-09-17T20:45:20Z'
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
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=3
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-3380: Watchtower stayed down 5h after host reboot: liveness-check records stopped every minute and nothing consumes it

## Context

The host rebooted at 17:09:04 on 2026-09-17. This project's Watchtower died with it
and never came back. It was still down ~5h later, which is how T-3379 was found: a
human-review handoff could not reach a server, and the placeholder URL named a port
another project held.

**The first framing of this task was wrong, and the measurement corrected it.**
It was filed believing `agents/monitor/liveness-check.sh` had been faithfully
recording `"watchtower":"stopped"` every minute with nobody consuming the signal —
a delivery gap. That is not what happened, and the correction is kept here rather
than quietly rewritten, because the wrong version is the more tempting story.

What the log actually shows: the liveness rail's **last sample is 2026-08-14
21:29:59** — silent for 34 days — and its last `running` sample is 2026-06-12.
The script was not recording anything at all.

Why: `agents/monitor/liveness-check.sh` is committed **100644**. Cron execs it
directly, so every invocation dies `Permission denied`. Syslog carries 13,680 such
CRON lines. The `@reboot` leg fails the same way, so the one rail that would have
noticed the reboot could not run *because of* the reboot's own crontab entry.

The rail that WAS alive is the 5-minute RSS sampler, and it measured the outage
precisely: `state: down` from **17:10:01** (the reboot was 17:09:04) through
**22:45:01** — 68 contiguous samples, 5h35m. Nothing consumes that either, so the
delivery gap is real; it simply is not what made this outage invisible.

The audit could not see any of it. The T-3317 exec-bit check examines files whose
**git index mode is 100755**, so a file committed 100644 is outside its candidate
set entirely: it printed `Exec-bit parity: every 100755-indexed script is
executable on disk — examined 60 script(s)` while a scheduled job had been dead
for a month. The PASS is true, and answers a narrower question than the reader
hears — the T-3105 / T-1828 class, and a sibling of T-3302 (a green line about
`tests/lint` read as covering the test corpus).

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] Watchtower is running again and is **this** project's — an identity probe on the
      triple-file port returns `project_root` equal to this repo, not a foreign server
      running the same Flask app (the T-1376/T-2732 wrong-server class)
      → `{"pid":1141196,"project_root":"/opt/999-Agentic-Engineering-Framework",...}`
      on `:3002`, restarted 22:45:13Z.
- [x] The outage is **measured, not asserted**, from a rail that was actually running:
      68 contiguous `state: down` samples, first `2026-09-17T17:10:01`, last
      `2026-09-17T22:45:01` (5h35m), from `.context/monitors/watchtower-rss.jsonl`.
      The liveness log could NOT supply this — it stops at 2026-08-14, which is the
      finding below, not a gap in the measurement.
- [x] Every rail that could report "Watchtower is not running" is enumerated with
      evidence per rail — see the table in `## Rail survey`. No fix was written before
      that table existed.
- [x] **AMENDED after the survey** (original text below). A scheduled rail reports a
      script the deployed crontab cannot execute — `fw audit --section structure` now
      emits `Cron exec-bit: every script cron execs directly is executable — examined
      3 directly-invoked script(s) in the deployed crontab`, and FAILs when one cannot.
      *Original AC: "a scheduled rail reports a Watchtower that is not running."* The
      survey showed that is a second, real gap but NOT the one that made this outage
      invisible — a Watchtower-down consumer added today would have been scheduled
      into the same crontab and could have died the same silent death. The root cause
      is a scheduled job that cannot run and says nothing. The Watchtower-down
      consumer is filed separately rather than folded in (one task, one deliverable).
- [x] Regression test pins the new behaviour with a recorded **control leg**:
      `tests/unit/t3380_cron_exec_bit.bats`, 9/9 green, 0 skips. Test 2 is the control
      (same crontab red, then green once the bit is restored), and test 7 went
      genuinely red first — catching a real bug in the predicate. See `## Verification`.
- [x] `## RCA` filled: symptom, root cause, why the framework allowed it, and what
      prevention is distinct from the fix itself

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

timeout 300 bats tests/unit/t3380_cron_exec_bit.bats > /tmp/.t3380.out 2>&1 && ! grep -q "^not ok" /tmp/.t3380.out
test "$(grep -c '# skip' /tmp/.t3380.out)" -eq 0
bash -n agents/audit/audit.sh
python3 -c "import ast; ast.parse(open('lib/cron_exec_bit.py').read())"
test -x agents/monitor/liveness-check.sh
out=$(git ls-files -s agents/monitor/liveness-check.sh); echo "$out" | grep -q '^100755'
test ! -f /etc/cron.d/agentic-audit-999-agentic-engineering-framework || test -z "$(python3 lib/cron_exec_bit.py /etc/cron.d/agentic-audit-999-agentic-engineering-framework)"
curl -sf --max-time 5 "$(bin/fw watchtower url)/api/_identity" -o /tmp/.t3380id.out && grep -q "999-Agentic-Engineering-Framework" /tmp/.t3380id.out
bin/fw vendor self --check

## Rail survey

Which rails could have reported "Watchtower is not running", as measured on
2026-09-17 — not as assumed. This table is what AC 3 required before any fix.

| Rail | Cadence | Did it detect? | Is it delivered? |
|---|---|---|---|
| `agents/monitor/liveness-check.sh` | 1 min + `@reboot` | **No — could not run.** Committed 100644; 13,680 `Permission denied` CRON lines; no output since 2026-08-14 | Writes a JSONL + snapshot. No notify, no restart, no escalation — nothing reads either file |
| `agents/monitor/watchtower-rss-sample.sh` | 5 min | **Yes.** 68 contiguous `state: down` samples, 17:10:01 → 22:45:01 | No consumer. Same delivery gap, still open — filed separately |
| `fw doctor` | on demand | **Yes** — `WARN Stale Watchtower triple (pid … not running)` | On demand only. Nothing schedules it; nobody ran it during the outage |
| `fw audit` (T-3282 staleness) | daily cron + pre-push | **No, by design.** `fw watchtower current` exits 0 when nothing is running — deliberately, so headless/CI hosts pass | n/a |
| `fw audit` (T-3317 exec-bit parity) | daily cron + pre-push | **No.** Candidate set is index-100755 only, so the 100644 file was never examined; printed PASS over 60 others | Delivered, but blind to this |
| ntfy / `fw notify` | event | **No.** Nothing in the Watchtower or liveness path calls `fw_notify` | n/a |

Two distinct gaps fall out, and only the first is this task's:

1. **A scheduled job that cannot run reports nothing, and no rail notices.** This is
   what made the outage invisible, and it is generic: it would have silently killed
   any new rail added to the same crontab. Closed here.
2. **Watchtower-down has no consumer** — the RSS sampler has been right, every five
   minutes, the whole time. Real, but a separate deliverable; folding it in here
   would have shipped the consumer into the same blind spot that killed the last one.

## RCA

**Symptom:** This project's Watchtower died with a host reboot at 17:09:04 on
2026-09-17 and stayed down 5h35m. No rail reported it. It surfaced only when a
human-review handoff could not reach a server (T-3379), i.e. by accident.

**Root cause:** `agents/monitor/liveness-check.sh` is committed with mode 100644.
The deployed crontab execs it directly (`* * * * * root cd … && …/liveness-check.sh`,
plus an `@reboot` leg), so every invocation died `Permission denied` — 13,680 of
them in syslog — and the script produced no output from 2026-08-14 onward. The rail
that samples Watchtower liveness had been dead for 34 days before the outage began.
The `@reboot` leg is the sharpest part: the one job whose entire purpose is to check
liveness *after a reboot* failed for the same reason, at the moment it mattered.

**Why structurally allowed:** the exec-bit check that exists (T-3317,
`lib/exec-bit-drift.sh`) compares on-disk mode against the git index, so its
candidate set is exactly "files the index marks 100755". A file committed 100644 is
not in that set, so it is not examined — the audit emitted `Exec-bit parity: every
100755-indexed script is executable on disk — examined 60 script(s)` on every run
throughout. That line is *true*. It answers "did the disk drift from the index?"
while the reader hears "the things we schedule can run." Same shape as T-3105 (the
audit had no check that it could itself run) and T-3302 (a green line about
`tests/lint` read as covering the test corpus). A false green is not noticed the way
a red is: a red gets chased, and a green that asserts less than it appears to is
indistinguishable from one that asserts everything.

**Prevention (distinct from the fix):** the fix is `chmod +x` — one file, and it
would rot again the moment any other script is committed without the bit. The
prevention is a check that joins from the **deployed crontab** instead of the git
index: `lib/cron_exec_bit.py`, wired into `fw audit --section structure`, FAILs when
a script cron execs directly cannot be executed, and reports the count it examined
when clean. It asks "can the things we schedule actually run?" — the question the
sibling check was being read as answering. It deliberately ignores interpreter-
prefixed invocations (`python3 foo.py` needs no bit): a first pass that did not
reported 50 broken paths on this host of which exactly 1 was real, so the
false-positive guard is load-bearing and is pinned by test 3.

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

### 2026-09-17 — amending AC 4 after the rail survey
- **Chose:** rewrite AC 4 to target the cron exec-bit gap, keep the original AC text
  visible inline, and file the Watchtower-down consumer as separate work.
- **Why:** AC 3 exists precisely to forbid fixing before measuring, and the
  measurement moved the target. Building the originally-specified consumer would
  have put a brand-new rail into the same crontab that had been silently killing
  the last one for 34 days — shipping a detector into a known blind spot.
- **Rejected:** (a) doing both in one task — violates one-task-one-deliverable and
  couples a generic prevention to a specific consumer; (b) quietly editing AC 4 to
  match what I built — that is scoring my own work against a moved goalpost, so the
  original wording stays in the file next to the amendment.

### 2026-09-17 — where the prevention lives
- **Chose:** a new predicate joining from the deployed crontab, beside the T-3317
  check in `fw audit --section structure`.
- **Why:** the crontab is the only source that knows what is *scheduled to exec*.
  The git index cannot answer it — that is exactly why the existing check was blind.
  Audit is already scheduled (daily cron) and runs pre-push, so it needs no new
  delivery channel of its own — which is the failure this task is about.
- **Rejected:** extending `lib/exec-bit-drift.sh` to include 100644 files — it would
  flag every non-executable tracked script in the repo, most of which are libraries
  nothing execs. The signal is "cron execs it", not "it ends in .sh".

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

### 2026-09-17T20:42:51Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3380-watchtower-stayed-down-5h-after-host-reb.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-1f88d760
- **Timestamp:** 2026-09-17T20:58:42Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-09-17T20:58:36Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
