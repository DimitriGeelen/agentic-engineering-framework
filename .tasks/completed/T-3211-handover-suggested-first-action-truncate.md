---
id: T-3211
name: "handover Suggested First Action truncates the task name at the first line of
  a folded YAML scalar"
description: >
  Split from T-3210 (one bug, one task). The selector reads the task name with re.search(r'^name:\s*(.+)',
  content, re.M), which captures only the FIRST line of the frontmatter value. Most
  task names are folded YAML scalars spanning two or more lines, so the suggestion
  renders cut mid-phrase and with a leading double quote: 'Continue T-1719: "Embeddings
  strategy V1 - Slice 1 (post-write hook + happiness signal + one-provider'. Both
  T-3181 IW-4 cold-resume arms flagged the truncation as blocking - the reader cannot
  tell what the task is. Distinct root cause from T-3210 (which fixed WHICH task is
  named, not how its name is rendered). Fix shape: consume indented continuation lines
  and strip surrounding quotes. Note for whoever takes it: bash -n does NOT catch
  an unescaped quote inside that python3 -c block - see T-3210 Evolution, mutation
  M3.

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [agents/handover/handover.sh, tests/unit/t3211_handover_sfa_full_name.bats]
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
created: 2026-08-29T10:06:43Z
last_update: 2026-09-22T20:45:44Z
date_finished: 2026-09-22T20:45:44Z
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
  - ts: '2026-08-29T10:15:09Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=235,acs=4)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-29T10:15:15Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-3211: handover Suggested First Action truncates the task name at the first line of a folded YAML scalar

## Context

The handover's Suggested First Action prints `Continue <id>: <name>` but the name is
extracted with a single-line regex over the raw task file, so any task whose YAML `name:`
folds over several lines (the template's normal shape for long names) is cut at the first
physical line, mid-sentence, with its opening quote left unclosed. Localised 2026-09-22
(parent session, autonomous run) at `agents/handover/handover.sh` ~line 1341; a fresh
example is `S-2026-0922-1642.md`. Scored before start: BVP 69 proposed (median 61).

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] Root cause pinned: `agents/handover/handover.sh` (Suggested First Action block, ~line 1341)
      reads the task name with `re.search(r'^name:\s*(.+)', content, re.M)`, which returns only
      the first physical line of a folded or double-quoted multi-line YAML `name:` — so
      S-2026-0922-1642's line reads `Continue T-3435: "Fabric card quality, second pass: header
      comments for the 32 files that describe` (cut mid-sentence, opening quote unclosed).
      (Evidence: `## RCA`; the regex is gone — `grep -c "re.search(r'^name:"` = 0.)
- [x] The Suggested First Action line carries the full task name: the name is read by parsing the
      frontmatter as YAML (`yaml.safe_load` on the block between the `---` fences) with a fallback
      that joins continuation lines when the frontmatter does not parse; the same extraction is
      used for the `## Work in Progress` task headers if they share the defect (check, and record
      which in `## Decisions`). (Evidence: `extract_frontmatter_name()` added to both python
      blocks — the Work in Progress block shared the defect; see `## Decisions`. Worker diff
      98+/6−; `tests/unit/t3211_handover_sfa_full_name.bats` 4/4 ok, incl. the one-line control.)
- [x] A bats test builds a fixture project with one started-work task whose `name:` folds over
      three lines and asserts the generated handover's Suggested First Action contains the last
      words of the name and no dangling opening quote; a control task with a one-line name is
      unchanged. `TEST_TEMP_DIR` set in setup. (Evidence:
      `tests/unit/t3211_handover_sfa_full_name.bats` — 4/4 ok on 2026-09-22 19:25Z: folded name
      in full, one-line control unchanged, regex absent, `bash -n` clean.)
- [x] `bin/fw handover` (non-commit) regenerated once on the live corpus and the resulting
      `LATEST.md` Suggested First Action line is complete; `tests/unit/*handover*` stay green;
      vendored copy synced (`bin/fw vendor self --check` clean). (Evidence: regenerated
      `S-2026-0922-2118.md`; line now reads `Continue T-3211: handover Suggested First Action
      truncates the task name at the first line of a folded YAML scalar` — whole, no quote.
      Suite: no regression — see `## Decisions` for the exact accounting: the fixed commit's
      archive runs `handover.bats` + `handover_digest.bats` 20/20; every red in the live-tree
      sweep is pre-existing at the parent commit or a live-tree timeout. Vendored copy
      byte-identical (`cmp -s`).)

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

# T-3211 seed (parent): the fixed extraction must not be the one-line regex, and the live line must be whole.
[ "$(grep -c "re.search(r'^name:" agents/handover/handover.sh)" -eq 0 ]
[ "$(grep -c "def extract_frontmatter_name" agents/handover/handover.sh)" -ge 1 ]
bash -n agents/handover/handover.sh
timeout 600 bats tests/unit/t3211_handover_sfa_full_name.bats > /tmp/.t3211-bats.out 2>&1 && [ "$(grep -c '^not ok' /tmp/.t3211-bats.out)" -eq 0 ] && [ "$(grep -c '^ok' /tmp/.t3211-bats.out)" -eq 4 ]
sfa=$(sed -n '/^## Suggested First Action/,/^## /p' .context/handovers/LATEST.md | grep -m1 '^Continue'); [ -n "$sfa" ] && [ "$(printf '%s' "$sfa" | grep -c '"$')" -eq 0 ] && [ "$(printf '%s' "$sfa" | tr -cd '"' | wc -c)" -ne 1 ]
cmp -s agents/handover/handover.sh .agentic-framework/agents/handover/handover.sh

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

**Symptom:** the handover's Suggested First Action printed
`Continue T-3435: "Fabric card quality, second pass: header comments for the 32 files that describe`
— cut mid-sentence with the opening quote unclosed. Both T-3181 cold-resume arms had already
flagged it as blocking: the reader cannot tell what the task is.

**Root cause:** two python blocks in `agents/handover/handover.sh` (Suggested First Action, and
the Work in Progress headers) read the task name with `re.search(r'^name:\s*(.+)', content,
re.M)` over the raw file — the first physical line only. The template writes long names as
folded or quoted multi-line YAML scalars, so most names have a second line the regex never saw.

**Why structurally allowed:** the handover is generated text nobody parses back; no test built
a fixture with a multi-line name, and the truncation looked like a style quirk rather than a
defect until a cold reader had to act on it. T-3210 fixed WHICH task is named and left HOW its
name is rendered untouched (different root cause, split out here).

**Prevention:** `extract_frontmatter_name()` parses the frontmatter as YAML with a
continuation-joining fallback and is the only name reader in both blocks;
`tests/unit/t3211_handover_sfa_full_name.bats` pins a three-line folded name against a one-line
control, and asserts the truncating regex is absent from the script. The handover-suite bats
files run the same generator, so a regression re-opens red there too.

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

### 2026-09-22 — both python blocks shared the defect; one helper, added to each
- **Chose:** the Work in Progress header block used the same one-line regex, so the worker added
  the same `extract_frontmatter_name()` helper to both embedded python blocks (they are separate
  `python3 -c` programs and cannot import each other) rather than fixing only the Suggested
  First Action.
- **Why:** the AC asked to check and record; the check said "shared". Two copies of a 25-line
  helper beat two behaviours for the same field.
- **Rejected:** a shared python module under `lib/` — a larger change to a script the operator
  reads at every session start, for a helper with exactly two callers.

### 2026-09-22 — "stay green" accounted for exactly, not asserted
- **Measured:** the 14-file `tests/unit/*handover*` sweep in the live tree: 101 ok, 7 not ok
  (598 s). The 7: (a) `handover_push_timeout.bats` 64/65/68 grep for strings
  (`timed out after`, `FW_HANDOVER_PUSH_TIMEOUT:-60`, `timeout "$_ah_total_timeout"`) that are
  absent from `handover.sh` at the parent commit AND now — stale tests, red before this task,
  filed as an observation; (b) `t100144_handover_divergence.bats` 90 — red at the parent commit
  too (archive of `0eddfe08e~1`: 25 ok / 1 not ok, that one); (c) `handover.bats` 3/5 and
  `handover_digest.bats` 27 — green in an archive of the fixed commit (20/20, 17 s) and
  green-so-far in the live tree until the 300 s ceiling (10 ok, 0 not ok, then timeout): the
  live tree's generator is slow under its runtime state, not wrong.
- **Chose:** tick AC 4 on the archive evidence and the pre-existence proofs; do not touch the
  four stale/pre-existing tests here (one bug, one task).
- **Rejected:** widening this task to repair `handover_push_timeout.bats`; asserting "green"
  from the fixture test alone.

### 2026-09-22 — worker cut off before its close; parent finished it (third instance today)
- **What happened:** the Sonnet worker made the fix and wrote the test, then ended its turn
  "waiting for the background test run to notify me". A `claude -p` worker has no next turn.
  Filed as an observation under this task (the background-wait pattern, three workers on
  2026-09-22); the parent ran the tests inline, ticked the ACs with the evidence, and closed.

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-08-29T10:06:43Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3211-handover-suggested-first-action-truncate.md
- **Context:** Initial task creation

### 2026-09-22T18:20:38Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-d450eff0
- **Timestamp:** 2026-09-22T20:45:47Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-09-22T20:45:44Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
