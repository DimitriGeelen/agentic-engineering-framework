---
id: T-3058
name: "vector reindex temp files are git-stageable and trip the large-file guard"
description: >
  vector reindex temp files are git-stageable and trip the large-file guard

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [tests/unit/t3058_reindex_scratch_ignored.bats]
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
created: 2026-08-16T23:36:40Z
last_update: 2026-08-16T23:43:04Z
date_finished: 2026-08-16T23:43:04Z
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
---

# T-3058: vector reindex temp files are git-stageable and trip the large-file guard

## Context

Found while committing T-3053's closure state. A routine `git add -A .context`
staged `.context/working/fw-vec-index.db.reindex.2753855.tmp` and its `-journal`
sibling — SQLite scratch files written by an in-flight vector reindex — and the
T-1845 large-file pre-commit guard refused the commit.

The guard did its job. The gap is upstream of it: a background reindex leaves
multi-megabyte scratch files inside a directory the session commits from on every
handover, and nothing in `.gitignore` covers them. The PID in the filename means
each run produces a new path, so no single stale entry accumulates — instead the
hazard reappears with a different name each time, which is why it has not been
noticed as a recurring pattern.

Cheap to fix, but the interesting question is whether the reindexer cleans up
after itself on crash, and whether the index db itself is (or should be) tracked.
Both are settled by A2 before touching `.gitignore`.

## Acceptance Criteria

### Agent
- [x] **A1** A reindex scratch file — `.context/working/fw-vec-index.db.reindex.<pid>.tmp`
  and its `-journal` sibling — is matched by `.gitignore`, verified with
  `git check-ignore -v` against a synthesized name (not only the one on disk now,
  whose PID will never recur).
  → `.gitignore:115-116`. Tests 1-2 use pid `987654`, which is not the live one.
- [x] **A2** The tracked-vs-ignored status of the *real* index (`fw-vec-index.db`
  and any `-journal`/`-wal` sibling) is established by citation before the ignore
  rule is written, and is unchanged by it. Widening the glob until it swallows the
  index itself is the way this fix goes wrong silently.
  → Before: `fw-vec-index.db` ignored by `.gitignore:99` (`*.db`), `-shm`/`-wal` by
  `:100-101`, manifest by `:103`, lock/resume by `:104-105`. After: unchanged —
  `check-ignore -v` still attributes the index to `:99`. `*.db-journal` was the one
  genuine omission in that set and is added at `:102`. Test 5 drops both new rules
  and asserts the index stays ignored.
- [x] **A3** The producer is identified by file:line, and either shown to remove its
  scratch file on both success and failure, or a stale-scratch cleanup is added.
  A crashed reindex must not leave the hazard behind for the next `git add -A`.
  → `web/embeddings.py:849` sweeps stale scratch at start; `:1083-1094` is a
  `finally` that parks partial work into `.reindex.resume` and unlinks any
  leftover. Cleanup is already correct on both paths — **no code change needed,
  and that finding is what reshaped A4.**
- [x] **A4** ~~Scratch files on disk are removed~~ — **revised after A3.** The
  scratch is not a leak and must not be deleted: `web/embeddings.py:855-1094`
  parks partial work in it so an hourly cron can finish a 29-58h bootstrap across
  many firings (OBS-258). A live reindex is running now and holds hours of work in
  that file. The AC becomes: `git status --porcelain .context/working/` lists no
  `reindex` artifact **while the scratch is still on disk** — i.e. the ignore rule
  does the work, not a delete.
  → Verified with the 1.78GB scratch of pid 2753855 present and being written to.
- [x] **A5** A regression test pins A1 — `git check-ignore` matches a synthesized
  scratch name and does **not** match the index db. Mutation: removing the
  `.gitignore` line turns the test red.
  → `tests/unit/t3058_reindex_scratch_ignored.bats`, 7 tests. Tests 3-4 delete each
  rule from a copy and assert the file becomes visible. Test 7 is the positive
  control required by L-616 — a `check-ignore` that matched everything would make
  every other test pass for the wrong reason.

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

# 1. Regression suite: both rules mutation-checked, plus the L-616 positive control.
out=$(bats tests/unit/t3058_reindex_scratch_ignored.bats 2>&1); echo "$out" | grep -q '^ok 7 ' && ! echo "$out" | grep -q '^not ok'

# 2. A synthesized pid — not the one on disk, which will never recur.
git check-ignore -q .context/working/fw-vec-index.db.reindex.987654.tmp && git check-ignore -q .context/working/fw-vec-index.db.reindex.987654.tmp-journal

# 3. A2: the real index is still ignored, and by its own *.db rule.
git check-ignore -q .context/working/fw-vec-index.db

# 4. A4: clean status while the multi-GB scratch is on disk — the ignore rule does
#    the work, no delete. Passes trivially if no reindex is running; test 1 is the
#    load-bearing check.
#    Redirect-then-grep (the L-387 default form) rather than capture-then-grep:
#    the capture form is safe here (tiny output, and a negated grep -q reads to
#    EOF so nothing closes the pipe early), but the reviewer's heuristic cannot
#    tell that from the general case, and the default form costs nothing.
git status --porcelain .context/working/ > /tmp/.t3058-status.out 2>&1 && ! grep -qi reindex /tmp/.t3058-status.out

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

**Symptom:** `git add -A .context` during a routine closure commit staged a 1.78GB
`fw-vec-index.db.reindex.2753855.tmp` plus its journal, and the T-1845 large-file
pre-commit guard refused the commit.

**Root cause:** an enumeration gap in `.gitignore`. The reindex writes six sidecar
artifacts; five were listed (`*.db`, `*.db-shm`, `*.db-wal`, `*.db.manifest.json`,
`*.db.reindex.lock`, `*.db.reindex.resume`) and the scratch copy plus its journal
were not. `*.db-journal` was missing too.

**Why structurally allowed:** the omitted file is the one the listed ones are *made
of*. `web/embeddings.py:1092` does `shutil.move(tmp_path, resume_path)` — the
scratch and `.reindex.resume` are the same bytes at two moments of one run, and
only the second had a rule. Whoever wrote `:104-105` was looking at the artifacts
left behind *after* a run and enumerated those; the scratch only exists *during*
one, so it was not in view.

Three things then kept it invisible:

1. **The filename carries `os.getpid()`.** No stable path ever accumulates in
   `git status`, so there was no single `??` line to get used to and eventually
   investigate — just a different one, occasionally, months apart.
2. **The window looks small and is not.** A scratch file reads as seconds-long.
   `web/embeddings.py:857-861` deliberately parks partial work in it so an hourly
   cron can finish a 29-58h bootstrap across many firings (OBS-258). It sits on
   disk for *days*, at index size, in the directory every handover commits from.
3. **Cleanup being correct removed the remaining suspicion.** `:849` sweeps stale
   scratch at startup and `:1083-1094` is a `finally` that parks-or-unlinks. Read
   in isolation, that is a well-behaved temp file. It is well-behaved — it is just
   also long-lived, and only the second property matters to `git add -A`.

**Prevention:** `.gitignore:115-116` (narrow — `.db.reindex.*` would work but the
T-2990 note directly above is specifically about ignore rules that blind
git-status, so the rules name only what they cover), plus
`tests/unit/t3058_reindex_scratch_ignored.bats` with both rules mutation-checked.
Note the prevention is *not* a cleanup change: A3 established the producer already
does the right thing, so a code change there would have been motion without effect.

**Detection remains where it was, and that is the honest limit of this fix.** The
T-1845 large-file guard is what caught this, and it will catch the next unignored
multi-GB artifact the same way. Nothing here makes the framework notice a *small*
generated file leaking into `.context/working/` — the T-2990 note above documents
exactly that gap for a different file class, and this task does not close it.

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

### 2026-08-16T23:36:40Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3058-vector-reindex-temp-files-are-git-stagea.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-5248ea96
- **Timestamp:** 2026-08-16T23:43:05Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-08-16T23:43:04Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
