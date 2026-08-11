---
id: T-2917
name: "autonomous worker commits are signed with the operator's git identity — no
  way to tell agent work from human work"
description: >
  autonomous worker commits are signed with the operator's git identity — no way to
  tell agent work from human work

status: started-work
workflow_type: build
owner: agent
horizon: now
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
created: 2026-08-11T11:28:47Z
last_update: '2026-08-11T11:30:14Z'
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
  - ts: '2026-08-11T11:30:07Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-11T11:30:14Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 2
      D3: 3
      D4: 3
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=2 
      (body:telemetry-or-audit-entry); D3=3 (body:component-discoverability); 
      D4=3 (body:portability-abstraction); F-RECALL=0 (no-signal); F-AUTONOMY=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2917: autonomous worker commits are signed with the operator's git identity — no way to tell agent work from human work

## Context

Commit `d3d759b41` created T-2913, shipped `agents/context/check-rail-mcp-label.sh`, edited
`lib/rail-identity.sh` and `.claude/settings.json`, and refreshed the enforcement baseline —
10 files, 923 insertions. It was written by a `resolver-loop.timer` worker dispatched at
2026-08-10T19:56:55Z. Its git record:

```
Author:    Dimitri Geelen <dimitirgeelen@hotmail.com>
Committer: Dimitri Geelen <dimitirgeelen@hotmail.com>
```

Byte-identical, in every field git records, to a commit the operator typed by hand.

**A distinct identity exists and was used.** Three commits in April 2026 (`a5923a301`,
`1812b10b8`, `71db19b58`) carry `termlink-dispatch <agent@termlink>`. Nothing in the current
dispatch or spawn path sets it — grep finds no surviving reference outside those rows and
some episodic filenames. The mechanism was lost, not omitted.

**The framework already does this correctly elsewhere.** `lib/init.sh:752` sets
`GIT_AUTHOR_NAME="fw init" GIT_AUTHOR_EMAIL="fw-init@localhost"` for its own bootstrap
commit. So a one-line scaffolding commit is correctly attributed to the tool that made it,
while an autonomous agent's 923-line source change is attributed to the human.

Across all history: **7804 commits** under the operator's identity, an unknown fraction of
them authored by workers. There is no query that separates them.

**This is why the "second operator" diagnosis was reached twice.** All three signals the
operator reported were real and correctly observed — an off-cadence source edit at 22:14:35
(inside the worker's 21:56→22:24 run), a `fw vendor self` VERSION bump nobody ran, and
`focus.yaml` flipped to a task nobody created. Every one is a worker. But the audit trail
they were checked against says a human did it, because that is literally what git records.
The inference was correct reasoning over a corrupt record.

P-002 enforces that every commit names its **task**. Nothing enforces that a commit names its
**author-class**. Third of three defects found re-verifying T-2914 live; siblings T-2915
(in-flight latch) and T-2916 (inert stall guard).

## Acceptance Criteria

### Agent
- [x] Dispatch-spawned workers commit under a distinct identity (name + email) that is not
      the operator's — matching the `fw init` precedent at `lib/init.sh:752`
- [x] The identity names the mechanism, not just "agent" — a reader must be able to tell a
      resolver-loop worker from a TermLink dispatch from an MCP-driven session
- [x] The dispatch_id is recoverable from the commit (trailer or identity), so a worker
      commit joins back to its row in `.context/dispatches.jsonl`
- [x] A query exists that answers "what did the loop commit on my behalf this week" —
      surfaced by a verb, not left as a `git log --author` incantation to remember
- [ ] Test pins BOTH directions: a worker commit is attributed to the worker identity, and
      an operator commit in the same repo is NOT — so the fix cannot pass by relabelling
      everything
- [ ] Historical worker commits are NOT rewritten (Tier 0, and the record is evidence) —
      the fix is forward-only, and that boundary is stated in the task's Decisions

**Progress (session cut off at budget-critical, commit `0c6e237c1`):**

Implemented and unit-tested (Python side, green):
- `lib/worker_identity.py` — `mechanism_from_origin(origin)` + `worker_git_env(mechanism, dispatch_id)`.
  Identity shape: `fw worker (<mechanism>)` / `dispatch+<8-char-dispatch-id>@aef.local`.
- `lib/resolver.py:capture_dispatch` — computes mechanism from `row["origin"]` (existing
  T-2914 taxonomy: `systemd:resolver-loop.service` → `resolver-loop`, `interactive:*` →
  `resolver-manual`, `cli:*` → `resolver-cli`, else `resolver`), merges the identity env
  into `envelope["env"]` (workflow-declared `env:` still overrides if ever needed).
- `lib/spawn.py` + `lib/pi_worker.py` + `lib/ollama_thin_loop.py` — closed two env-passthrough
  gaps found while wiring this: `PiWorker` never accepted an `env` overlay at all (now does,
  merged onto `os.environ` for the `pi` Popen call); `ollama_thin_loop`'s `_tool_bash` ignored
  `self._env_overlay` entirely (now merges it into the `subprocess.run` env). `ollama-loop`
  and `TermLink` already plumbed correctly.
- `agents/termlink/termlink.sh:cmd_dispatch` — direct (non-resolver) `fw termlink dispatch`
  now defaults to mechanism `termlink-dispatch`, dispatch-id-equivalent = the `--name` value
  (no dispatches.jsonl row to join to on this path; the `/tmp/tl-dispatch/<name>/` dir is the
  join target instead). Written via `lib/git-identity.sh:fw_worker_git_identity_env` (bash
  mirror of the python format, same string shape) FIRST into `env.sh`, so a resolver-forwarded
  `--env GIT_AUTHOR_NAME=...` (later in the same file) overrides it — sourcing is top-to-bottom,
  later `export` wins.
- `agents/git/lib/worker-commits.sh` + `agents/git/git.sh` routing — new
  `fw git worker-commits [--days N] [--task T-XXX] [--json]`. Filters `git log --author`
  against the `dispatch+[0-9a-f]+@aef\.local` shape; table/JSON output shows sha, date,
  mechanism (parsed from author name), dispatch-id prefix (parsed from email), subject.
  Manually verified in a scratch repo: worker commit surfaced, operator commit excluded,
  both directions, `--task` filter, `--json` round-trips through `json.load`.
- `tests/unit/test_worker_identity.py` (9 tests, green) — mechanism mapping, env shape,
  dispatch_id recoverability, mechanism-distinguishes-identity.
- `tests/unit/test_resolver.py` — two new tests (green): `capture_dispatch` sets a worker
  identity distinct from any operator string, and origin distinguishes mechanism
  (`resolver-loop` vs `resolver-cli`) — this is `test_capture_dispatch_mechanism_distinguishes_origin`.

**Remaining (next session):**
1. **AC5 (both-directions test) is not fully closed.** Python side covers the identity
   computation; the bash side (`fw git worker-commits` end-to-end against a real repo with
   both an operator commit and a worker commit) was drafted but never landed — the
   budget-gate hit before the `Bash` heredoc creating
   `tests/unit/git_worker_commits.bats` could run. The full draft (9 `@test` cases: surfaces
   worker commit, excludes operator commit, `--json` shape, `--task` filter both ways,
   `--days` window, help, unknown-option) is reproduced verbatim below this block — the
   file was manually verified to work in a scratch repo during this session
   (`/tmp/t2917test`, since cleaned up), just never written to disk. Recreate it verbatim
   and run `bats tests/unit/git_worker_commits.bats`.
2. **AC6 (Decisions boundary statement)** — not yet written. Add a `## Decisions` entry:
   forward-only fix, historical worker commits (including `d3d759b41` cited in Context)
   are NOT rewritten — Tier 0, and the misattributed record is itself evidence for this
   task's RCA.
3. **MCP-driven session** — AC2's third named mechanism was scoped OUT this session.
   `agents/mcp/framework_mcp_server.py` is a generic `fw <subcommand>` subprocess wrapper
   that runs inside the *current* interactive session's own process — it doesn't spawn a
   separate worker with its own identity, so "operator identity" is arguably already
   correct for that path. The `demo_target` / `mcp__fw__work_on` orchestration mentioned
   in this task's own frontmatter comment ultimately re-enters `fw resolver`/`fw termlink
   dispatch`, which this fix already covers. Confirm this reasoning (or find the actual
   gap) before closing — don't just tick the box.
4. Run the full verification block below once (3) is resolved, then close.

<!-- Draft bats file, recreate verbatim at tests/unit/git_worker_commits.bats:

#!/usr/bin/env bats
# Unit tests for agents/git/lib/worker-commits.sh (T-2917)
#
# Pins BOTH directions: a worker commit (GIT_AUTHOR_EMAIL matching the
# dispatch+<id>@aef.local shape minted by lib/worker_identity.py /
# lib/git-identity.sh:fw_worker_git_identity_env) is attributed to the worker
# identity and surfaced by `worker-commits`; an operator commit in the SAME
# repo is not — so the fix cannot pass by relabelling everything as a worker.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    guard_project_root
    mkdir -p "$PROJECT_ROOT/.tasks/active" "$PROJECT_ROOT/.context"
    export TASKS_DIR="$PROJECT_ROOT/.tasks"
    export CONTEXT_DIR="$PROJECT_ROOT/.context"
    RED='' GREEN='' YELLOW='' CYAN='' NC=''

    cd "$PROJECT_ROOT"
    git init -q
    git config user.email "operator@example.com"
    git config user.name "The Operator"

    echo "a" > file.txt && git add . && git commit -q -m "T-2917: operator commit, typed by hand"
    OPERATOR_SHA="$(git rev-parse --short=8 HEAD)"
    export OPERATOR_SHA

    echo "b" > file.txt
    GIT_AUTHOR_NAME="fw worker (resolver-loop)" \
    GIT_AUTHOR_EMAIL="dispatch+a398504a@aef.local" \
    GIT_COMMITTER_NAME="fw worker (resolver-loop)" \
    GIT_COMMITTER_EMAIL="dispatch+a398504a@aef.local" \
        git add . && \
    GIT_AUTHOR_NAME="fw worker (resolver-loop)" \
    GIT_AUTHOR_EMAIL="dispatch+a398504a@aef.local" \
    GIT_COMMITTER_NAME="fw worker (resolver-loop)" \
    GIT_COMMITTER_EMAIL="dispatch+a398504a@aef.local" \
        git commit -q -m "T-2917: worker commit, dispatched by the resolver loop"
    WORKER_SHA="$(git rev-parse --short=8 HEAD)"
    export WORKER_SHA

    source "$FRAMEWORK_ROOT/agents/git/lib/common.sh"
    source "$FRAMEWORK_ROOT/agents/git/lib/worker-commits.sh"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

@test "do_worker_commits: surfaces the worker commit" {
    run do_worker_commits --days 3650
    [ "$status" -eq 0 ]
    [[ "$output" == *"$WORKER_SHA"* ]]
    [[ "$output" == *"resolver-loop"* ]]
    [[ "$output" == *"a398504a"* ]]
}

@test "do_worker_commits: does NOT surface the operator commit" {
    run do_worker_commits --days 3650
    [ "$status" -eq 0 ]
    [[ "$output" != *"$OPERATOR_SHA"* ]]
    [[ "$output" != *"operator@example.com"* ]]
    [[ "$output" != *"The Operator"* ]]
}

@test "do_worker_commits: --json emits valid JSON with only the worker commit" {
    run do_worker_commits --days 3650 --json
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
rows = json.load(sys.stdin)
assert len(rows) == 1, rows
assert rows[0]['mechanism'] == 'resolver-loop', rows[0]
assert rows[0]['dispatch_id_prefix'] == 'a398504a', rows[0]
"
}

@test "do_worker_commits: --task filters to matching task ref" {
    run do_worker_commits --days 3650 --task T-2917
    [ "$status" -eq 0 ]
    [[ "$output" == *"$WORKER_SHA"* ]]
}

@test "do_worker_commits: --task with nonexistent ID returns none" {
    run do_worker_commits --days 3650 --task T-9999
    [ "$status" -eq 0 ]
    [[ "$output" == *"None"* ]]
    [[ "$output" != *"$WORKER_SHA"* ]]
}

@test "do_worker_commits: --days window excludes commits outside it" {
    run do_worker_commits --days 0
    [ "$status" -eq 0 ]
    [[ "$output" == *"None"* ]]
}

@test "do_worker_commits: no worker commits in window prints None, not an error" {
    cd "$PROJECT_ROOT"
    git config user.email "second-operator@example.com"
    git config user.name "Second Operator"
    echo "c" > file.txt && git add . && git commit -q -m "T-2917: another operator commit"
    run do_worker_commits --days 0
    [ "$status" -eq 0 ]
    [[ "$output" == *"None"* ]]
}

@test "show_worker_commits_help: outputs usage text" {
    run show_worker_commits_help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Worker Commits"* ]]
    [[ "$output" == *"--days"* ]]
    [[ "$output" == *"--task"* ]]
    [[ "$output" == *"--json"* ]]
}

@test "do_worker_commits: -h shows help and exits 0" {
    run do_worker_commits -h
    [ "$status" -eq 0 ]
    [[ "$output" == *"Worker Commits"* ]]
}

@test "do_worker_commits: unknown option exits with error" {
    run do_worker_commits --bogus
    [ "$status" -eq 1 ]
    [[ "$output" == *"Unknown option: --bogus"* ]]
}
-->


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
# Pipefail/SIGPIPE hint (L-387): P-011 runs each command under `set -eo pipefail`.
# `cmd | grep -q PATTERN` exits 141 (SIGPIPE) when grep matches and closes stdin
# while the upstream is still writing — verification then "fails" even though
# the pattern was present. Safe pattern: capture first, grep the capture:
#     out=$(cmd 2>&1); echo "$out" | grep -q "PATTERN"
# Or:
#     cmd > /tmp/.out 2>&1 && grep -q "PATTERN" /tmp/.out
# Origin: L-387, captured 4× (T-1716, T-1838, T-1862, T-1863) before this hint.
#
# Single pipe only — no intermediate tail/awk/sed stages between capture and grep
# (T-2090): `echo "$out" | tail -3 | grep -q PAT` re-introduces the SIGPIPE risk
# the capture step closed off — the middle stage is what `grep -q` slams its
# stdin on. grep scans the whole captured string anyway, so the tail-3 was
# cosmetic. Drop it: `echo "$out" | grep -q PAT`.
#
# AND ONLY WHILE THE CAPTURE IS SMALL (T-2743). The two hints above are correct
# for the captures they were written about, and both invert above the pipe
# buffer. `echo "$out" | grep -q PAT` is NOT SIGPIPE-free — it is SIGPIPE-free
# only while "$out" fits in the 65536-byte pipe buffer. Above that, with an
# early match: echo blocks on the full pipe, grep -q exits, echo takes SIGPIPE,
# pipeline exits 141 under pipefail — the exact failure L-387 exists to prevent.
# Measured: a Watchtower page is 146,366 bytes, rc=141 on 3/3 runs, deterministic
# not racy. Any line that curls a rendered page is exposed (routes run 50-200KB).
# For anything that might be large, redirect to a file:
#     cmd -o /tmp/.out && grep -q "PATTERN" /tmp/.out
#     curl -sf "$(bin/fw watchtower url)/page" -o /tmp/.out && grep -q "PAT" /tmp/.out
# This is the better default even when size is not a concern: `&&` keeps the
# PRODUCING command's exit code in the verdict, where `out=$(cmd)` discards it —
# the T-2738 problem one layer down. A 404 from curl fails the line instead of
# silently producing an empty capture for grep to not-match.
#
# REHEARSING A LINE BY HAND DOES NOT REHEARSE THE GATE (T-2743). Your interactive
# shell has no `set -eo pipefail`. The line above returned 0 when run by hand and
# 141 under P-011, from the same directory, the same second. To rehearse for real:
#     bash -c 'set -eo pipefail; <your verification line>'
#
# BUT NOT for a test runner (T-2738): the capture above discards the command's
# exit code, and `set -e` is suppressed inside the `if` condition the gate runs
# each line in — so in `cmd1; cmd2` only cmd2 is the verdict. For pytest/bats
# that exit code WAS the verdict, and the pass marker you grep instead survives
# a partial failure: a suite printing "3 failed, 9 passed" satisfies
# `grep -q "9 passed"`. Generalising to `grep -qE "[0-9]+ passed"` matches the
# same output. Either keep the exit code:
#     python3 -m pytest <file> -q > /tmp/.out 2>&1 && grep -q passed /tmp/.out
# or add the guard the exit code used to supply:
#     out=$(python3 -m pytest <file> -q 2>&1); echo "$out" | grep -q passed && ! echo "$out" | grep -q failed
#     out=$(bats <file> 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
# The close gate refuses the unguarded form. Bypass: FW_ALLOW_UNJUDGED_TEST_RUN=1.
#
# Enforcement-baseline hint (L-398, T-1886): if you edited `.claude/settings.json`
# (added/removed/reorganised hooks), add `bin/fw enforcement baseline` to your
# Verification block. Otherwise the canonical hash diverges and `fw doctor`
# reports a FAIL ("Enforcement baseline CHANGED") that accumulates silently.
# Origin: T-1849/T-1730/T-1731 each added a legitimate hook without refreshing
# the baseline — FAIL sat for multiple sessions until T-1886 cleaned up.

## RCA

**Symptom:** an autonomous worker's 923-line source commit is indistinguishable from an
operator's hand-typed commit. The operator observed three anomalies in their own working tree,
checked the audit trail, and the trail said they did it themselves.

**Root cause:** dispatch-spawned workers inherit the repo's git identity because nothing in the
spawn path overrides it. A distinct identity (`termlink-dispatch <agent@termlink>`) was in use
as recently as April 2026 and is now referenced nowhere in live code — a silent regression, not
a missing feature.

**Why structurally allowed:** P-002 is the framework's commit-governance gate and it checks
that a commit names its **task**. Author-class was never in scope, so no gate, no audit section,
and no doctor check ever looks at it. The failure is also invisible by construction: the wrong
attribution produces a *plausible* record rather than a broken one. A missing `T-XXX` gets
rejected at the commit-msg hook; a commit falsely attributed to the operator passes every check
and reads as normal history forever.

Compounding it: dispatch provenance is null on the JSONL side too (T-2914 fixed only `origin`,
to the degraded value `systemd:unlabeled-unit`). So neither surface — not the commit, not the
dispatch row — can name who did the work. The two blind spots are independent, which is why
neither backstops the other.

**Consequence beyond confusion:** this is a sovereignty-model defect, not just a forensics one.
The Authority Model rests on the human being accountable for what lands. If autonomous commits
are recorded as human commits, the operator is accountable for work they cannot enumerate, and
`git log --author` — the obvious way to audit one's own history — actively misleads. Two full
investigations were spent reaching a conclusion the record contradicted.

**Prevention:** (a) restore a distinct worker identity in the spawn path, per the `fw init`
precedent; (b) carry the dispatch_id into the commit so worker commits join back to their
dispatch row; (c) a verb that answers "what did autonomy commit on my behalf" without needing
the operator to know the identity string; (d) test both directions, so the fix cannot pass by
relabelling every commit. (a) is the fix; (b)-(d) are what make the next regression visible.

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

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

### 2026-08-11 — Forward-only fix; historical commits are not rewritten
- **Chose:** the identity fix (`lib/resolver.py:capture_dispatch` + the termlink-dispatch
  default) applies to every dispatch from this point forward. Historical worker commits —
  including `d3d759b41`, the commit cited in this task's own Context section — are left
  exactly as they are: authored/committed as the operator, forever.
- **Why:** rewriting history is Tier 0 (rebase/force-push territory) for a repo with 7800+
  commits and an unknown number of consumers/mirrors tracking it. Beyond the mechanical risk,
  the misattributed record is itself evidence — it's what let two live investigations
  conclude "a second operator session" from data that was wrong in exactly the way this task
  now explains. Erasing that record would erase the RCA's own supporting evidence.
- **Rejected:** any retroactive `git filter-branch`/`git-filter-repo` rewrite to reattribute
  historical worker commits by heuristic (e.g. "commits during known resolver-loop dispatch
  windows"). Even if the heuristic were reliable, Tier 0 + shared-history risk outweighs the
  forensic value, and the "wrong-but-honest" historical record is more useful than a
  "corrected-by-guess" one.

### 2026-08-11 — "MCP-driven session" scoped out this session (see Progress note above)
- **Chose:** implement identity injection for resolver-mediated dispatch (all worker_kinds)
  and direct `fw termlink dispatch`, and leave MCP-tool-driven work as inheriting the current
  interactive session's own identity.
- **Why:** `agents/mcp/framework_mcp_server.py` runs `fw <subcommand>` inside the *current*
  session's process — it is the human's own session acting through a tool, not a spawned
  worker with independent provenance. Where MCP orchestration (e.g. `mcp__fw__work_on` per
  the `demo_target` frontmatter field) leads to an actual spawned worker, that path re-enters
  `fw resolver` or `fw termlink dispatch`, both of which this fix covers.
- **Rejected:** deferred outright — flagged for the next session to confirm this reasoning
  holds (rather than assumed correct) before AC2 is considered fully closed, since "a reader
  must be able to tell ... an MCP-driven session" apart was written into the AC text
  explicitly and this task has not independently verified there is no live MCP-spawned-worker
  path outside the two covered here.

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-08-11T11:28:47Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2917-autonomous-worker-commits-are-signed-wit.md
- **Context:** Initial task creation
