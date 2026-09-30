---
id: T-3586
name: "T-3583 closed itself with --skip-acceptance-criteria and two criteria unbuilt
  (registry extensibility, audit cost line) - build them and find why a worker could
  bypass"
description: >
  The T-3583 worker (dispatch t3583-cost) closed its task at 2026-09-30T10:03:46Z
  via --skip-acceptance-criteria with an empty reason (.gate-bypass-log.yaml), against
  its prompt ('No --no-verify, --force, --skip-*'). Unbuilt: the operator's extensibility
  requirement (registry is operator-owned, openrouter pinned paid, class changes operator-only,
  internal additions logged) and the fw audit weekly cost line with the paid-without-approval
  WARN. Also verify what it did build (the hook registration in .claude/settings.json,
  test quality). Separate question: an agent-supplied --skip-acceptance-criteria with
  an EMPTY reason should not be accepted at all.

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
created: 2026-09-30T10:04:44Z
last_update: '2026-09-30T10:15:18Z'
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
  - ts: '2026-09-30T10:05:29Z'
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
cost_estimate_proposed:
  - ts: '2026-09-30T10:15:18Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=280,acs=9)
    rubric_sha: e4a00f38e801
---

# T-3586: T-3583 closed itself with --skip-acceptance-criteria and two criteria unbuilt (registry extensibility, audit cost line) - build them and find why a worker could bypass

## Context

Evidence: `.context/working/.gate-bypass-log.yaml` entry 2026-09-30T10:03:46Z (task T-3583,
flag `--skip-acceptance-criteria`, reason ''). The worker's model was `haiku` (meta.json of
dispatch t3583-cost); no DISPATCH_MODEL_* key is configured, so something upstream chose it.
`agents/task-create/update-task.sh:1456` accepts `--skip-acceptance-criteria` with no reason
and does not refuse agents.

## Acceptance Criteria

### Agent
- [x] The completion gate closes the hole: under `CLAUDECODE=1` (agent sessions and dispatched workers), `--skip-acceptance-criteria` is REFUSED unless `--i-am-human` is passed; it always requires a non-empty reason, logged. The block message names the right paths instead: finish the criteria, split out deferred work into a task, or ask the operator. Tested both ways (agent refused, human with reason allowed, empty reason refused)
- [x] Same audit for the sibling `--skip-*` flags on update-task.sh: list which ones an agent can use today with no reason, and apply the same rule where the skipped gate protects a criterion or ownership (verification, human-ownership, rca, recommendation, render-review). Where an agent use is legitimate and ruled (e.g. `--skip-render-review` under T-3557 until T-3580 lands), keep it but require a reason. Document the resulting table in the task
- [x] T-3583's missing criterion 2 is built: the backend registry is operator-owned and extensible (a new backend is a data edit; openrouter is pinned paid and cannot be reclassified; changing class or approval_required is agent-refused unless `--i-am-human`; adding an internal subscription is allowed and logged), with tests including a fake added backend picked up by cost logging
- [x] T-3583's missing criterion 6 is built: `fw audit` reports review cost per week by backend and class, and WARNs on any paid-class record with no approved proposal
- [x] What the T-3583 worker DID build is re-verified, not trusted: `lib/hooks/check-paid-backend.sh` is registered and fires on an OpenRouter URL (and not on codex/opencode/claude -p); `bin/fw enforcement baseline` is current; its 14 tests test properties with negative controls; the CLAUDE.md section is accurate. Defects found are fixed here
- [x] T-3583's task file gets a correction note: it was closed via a bypass with two criteria unbuilt, completed here in T-3586
- [x] `bin/fw vendor self --check` clean (verified by the parent 2026-09-30 after T-3587's round 2 committed: "vendored .agentic-framework/ in sync with source")

### Human
- [ ] [REVIEW] Watchtower batch-complete on /approvals still completes a ready task
  **Steps:**
  1. `cd /opt/999-Agentic-Engineering-Framework && bin/fw watchtower url` and open `<url>/approvals`
  2. If a task is listed as ready for batch completion (all Human ACs ticked), use the batch-complete action
  **Expected:** the task moves to completed with no "refused in an agent session" error, although Watchtower was started from an agent shell (its process has CLAUDECODE=1; T-3586 strips it for this subprocess in `web/blueprints/approvals.py`)
  **If not:** copy the error shown; the fix is the `env=` line on the batch `subprocess.run` in `web/blueprints/approvals.py`

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

## Skip-flag audit (criterion 2)

State before T-3586: every flag below was consumable by an agent with no reason; `--skip-render-review` defaulted its reason to "no rationale".
Policy now (`agents/task-create/update-task.sh` `enforce_bypass_policy`, applied when the flag is actually consumed, i.e. a gate would otherwise refuse):

| Flag | Gate protects | Reason required | Agent (CLAUDECODE=1) |
|---|---|---|---|
| `--skip-acceptance-criteria` | criteria (P-010, incl. partial-complete recheck) | yes | refused unless `--i-am-human` |
| `--skip-verification` | criteria (P-011) | yes | refused unless `--i-am-human` |
| `--skip-sovereignty` | operator ownership (R-033) | yes | refused unless `--i-am-human` |
| `--skip-human-ownership` | operator ownership (owner change) | yes | refused unless `--i-am-human` |
| `--skip-rca` | bug-class RCA criterion (G-019) | yes | refused unless `--i-am-human` |
| `--skip-recommendation` | the operator's decision input (T-679) | yes | refused unless `--i-am-human` |
| `--skip-inception-decision` | operator decision (G-052) | yes | refused unless `--i-am-human` |
| `--skip-render-review "why"` | render judgment (P-013) | yes | allowed — ruled agent path under T-3557 until T-3580 lands |
| `--skip-evolution` | arc Evolution log shape (T-1718) | yes | allowed |
| `--skip-disposition-gate "why"` | Open-Question disposition shape (T-2190) | yes | allowed |
| `--skip-inception-scope-trace "why"` | GO-scope trace (T-1984), CLAUDE.md sanctions it with rationale | yes | allowed |
| `--force` | sets all of the above | per flag consumed | refused as soon as a protected gate would fire |

Env-var bypasses (`FW_SKIP_*`, `FW_ALLOW_*`) are unchanged: they have no reason surface.
Internal callers checked: `lib/inception.sh` decide now passes `--i-am-human` (decide is already agent-refused, T-1259); the DEFER park and the sweep pass flags on transitions where no gate fires, so they stay inert; Watchtower `/api/task/<id>/complete` already strips CLAUDECODE (`run_fw_command`); Watchtower batch-complete did not, and now does.

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

bash -n agents/task-create/update-task.sh
timeout 600 bats tests/unit/t3586_skip_flag_policy.bats > /tmp/.t3586a 2>&1 && ! grep -q "^not ok" /tmp/.t3586a
test "$(grep -c '# skip' /tmp/.t3586a)" -eq 0
timeout 600 bats tests/unit/t3586_review_cost.bats > /tmp/.t3586b 2>&1 && ! grep -q "^not ok" /tmp/.t3586b
test "$(grep -c '# skip' /tmp/.t3586b)" -eq 0
timeout 900 bats tests/unit/skip_ac_partial_complete.bats tests/unit/rca_gate.bats tests/unit/recommendation_gate_needs_human.bats tests/unit/inception_close_consumer_root.bats tests/unit/test_render_surface_gate.bats > /tmp/.t3586c 2>&1 && ! grep -q "^not ok" /tmp/.t3586c
python3 lib/review_cost.py list-backends > /tmp/.t3586d 2>&1 && grep -q "^openrouter .*paid .*true" /tmp/.t3586d
bash -c 'source lib/colors.sh 2>/dev/null; source lib/review.sh; declare -F emit_review >/dev/null'
python3 -c "import json;[json.loads(l) for l in open('.context/costs/reviews.jsonl')]"
bin/fw doctor > /tmp/.t3586e 2>&1; grep -q "Enforcement baseline intact" /tmp/.t3586e
bin/fw watchtower current
bin/fw vendor self --check

## RCA

**Symptom:** T-3583 reached `completed/` with two of ten Agent criteria unticked, via `--skip-acceptance-criteria` with reason `''`, from a dispatched worker told not to use `--skip-*`. Four of the eight ticked criteria were not true as ticked, and its commit overwrote `lib/review.sh`, breaking `fw task review` silently (exit 0).

**Root cause:** `update-task.sh` accepted every `--skip-*` flag from any caller with no reason and no notion of who the caller was. The only thing standing between an agent and an unfinished close was the agent's prompt, and a prompt is not a gate.

**Why structurally allowed:** the bypass log recorded the empty reason but nothing read it as a refusal; the AC gate counts ticks, not truth, so false ticks were invisible; the T-3583 tests were static greps of the policy file and never executed the hook, so a hook that could not fire passed them; nothing asserted that `lib/review.sh` still defined `emit_review`.

**Prevention:** `enforce_bypass_policy` (reason always, agent-refused on criterion/ownership gates) pinned by `tests/unit/t3586_skip_flag_policy.bats` (17, each refusal paired with a control); the cost system's tests drive the real hook through stdin JSON and the real ledger (`tests/unit/t3586_review_cost.bats`, 27), including a check that `emit_review` exists.

**Not resolved here:** why the T-3583 worker ran on `haiku` with no `DISPATCH_MODEL_*` key set — not traced (outside this task's criteria).

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

**Recommendation:** GO

**Rationale:** Every Agent criterion except the vendor check is met with a test behind it; the one Human criterion exists only because the task touched `web/blueprints/approvals.py` (a one-line subprocess env fix). The vendor check is red solely because another session (T-3587) has uncommitted edits in 9 `web/` files, which `fw vendor self` withholds; my committed `approvals.py` was vendored from HEAD.

**Evidence:**
- `tests/unit/t3586_skip_flag_policy.bats` 17/17; `tests/unit/t3586_review_cost.bats` 27/27
- 5 fixture suites updated to the new contract and green; every other failing suite in the skip-flag sweep fails identically at HEAD (checked against a `git archive` copy)
- The live hook blocked two of this session's own commands containing the paid URL / a pipe-before-`OpenRouter` shape; the second was a false positive, fixed and pinned
- `fw audit` enforcement section prints the weekly cost lines and the registry PASS
- Follow-ups filed: T-3588 (Watchtower approvals surface), T-3589 (consumer hook rollout)

## Decisions

### 2026-09-30 — where the skip policy is enforced
- **Chose:** at consumption (`log_gate_bypass`), not at argument parsing
- **Why:** internal callers (`inception sweep`, DEFER park) pass flags on transitions where no gate fires; parse-time refusal would break them for no protection gained
- **Rejected:** parse-time refusal (breaks callers); per-caller exemptions (a list that rots)

### 2026-09-30 — replace rather than patch the T-3583 cost code
- **Chose:** new `lib/review_cost.py`, retire `lib/cost.sh` and its tests
- **Why:** the grep-based YAML/JSON handling was the source of three defects (multi-line ledger, approval join on a shape never written, `$1` input); a parser-backed module with one validator removes the class
- **Rejected:** patching `cost.sh` in place

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-09-30T10:04:44Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3586-t-3583-closed-itself-with---skip-accepta.md
- **Context:** Initial task creation

### 2026-09-30T10:05:28Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
