---
id: T-3251
name: "pending Resolve button omits X-CSRF-Token so every click 403s before reaching
  the handler"
description: >
  pending Resolve button omits X-CSRF-Token so every click 403s before reaching the
  handler

status: work-completed
workflow_type: build
owner: human
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
created: 2026-09-01T22:27:25Z
last_update: 2026-09-01T22:34:28Z
date_finished: 2026-09-01T22:34:28Z
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
  - ts: '2026-09-01T22:30:09Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=260,acs=6)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-09-01T22:30:19Z'
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

# T-3251: pending Resolve button omits X-CSRF-Token so every click 403s before reaching the handler

## Context

Reported by a peer project (001-CashWeb) running the same vendored Watchtower, at
chat-arc offset 956, alongside a second unrelated defect in `extract_recommendation`
(filed separately — one bug, one task). Their operator hit it directly: *"I tried it
but could not resolve it."*

Confirmed here before any edit, in code and then live:

- `web/templates/pending.html` sent `{'Content-Type': 'application/json'}` and nothing
  else. Its POST carries a JSON body, so there is no `_csrf_token` form field either —
  the header was the only route available and it was not being used.
- `web/app.py:csrf_protect` requires one of the two on every state-changing request.
  The blanket `/api/*` exemption was removed by T-1343/G-048; this button did not
  follow.
- Live, against the running Watchtower:
  `POST /api/v1/pending/U-999-does-not-exist/resolve` with no token returned **403**.
  A nonexistent id returning 403 rather than 404 is the whole diagnosis in one line —
  CSRF fires before the lookup, so no click ever reached the handler.

**The peer's report was accurate and their scope was right.** A scan of every
state-changing `fetch()` in `web/templates/` found six; the other five all pass
`_csrf_token` in a `FormData` body and are fine. This is one site, not a class — the
scan is recorded as a test so that stays true.


## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] The `/pending` Resolve button sends a CSRF token on its POST, so the request reaches the handler instead of being rejected by `csrf_protect` before the lookup runs.
- [x] A regression test drives the rendered `/pending` page and asserts the token travels with the request — not merely that the template mentions `csrf-token`, which was already true and is exactly why nothing caught this.
- [x] The scan that found this is recorded: every state-changing `fetch()` in `web/templates/` either sends `X-CSRF-Token` or carries `_csrf_token` in a form body. Reported as a count, so a future template that omits both is a regression against a stated number rather than against nobody's memory.
- [x] The live repro from the report inverts: `POST /api/v1/pending/<nonexistent>/resolve` with a valid token returns 404 (reached the handler and found nothing) rather than 403 (rejected before the lookup).

### Human

- [ ] [REVIEW] The Resolve button on `/pending` actually resolves an entry in a browser.

  **Steps:**
  1. Open `http://192.168.10.107:3000/pending` (or run `cd /opt/999-Agentic-Engineering-Framework && bin/fw watchtower url` for the current address).
  2. Pick any entry in the Pending table and press **Resolve**.
  3. Enter a note (or leave it blank) and confirm.

  **Expected:** the page reloads and the entry moves out of Pending into the resolved list.

  **If not:** open the browser console, press Resolve again, and note the status code on the `/api/v1/pending/.../resolve` request. A **403** means the token still is not travelling; a **404** means it is travelling and the id was not found. The working fallback remains `cd /opt/999-Agentic-Engineering-Framework && bin/fw pending resolve <id> --note "..."`.

  **Why this one is human:** the four Agent ACs prove the token is present in the rendered page and that the server accepts it when sent. Neither can prove a real browser executes that JavaScript and the click completes — which is the only thing the reporting operator actually observed failing ("I tried it but could not resolve it").

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

python3 -m pytest tests/web/test_pending_resolve_csrf.py -q > /tmp/.t3251gate.out 2>&1 && grep -q '4 passed' /tmp/.t3251gate.out
# The '4 passed' clause pins the COUNT. A leg that stops running — renamed, skipped,
# deleted — would otherwise leave the file green on the survivors, which is the same
# shape as the defect being fixed: a check that passes for a reason unrelated to its
# subject.

## RCA

**Symptom.** Every press of Resolve on `/pending` failed, for every operator, on every
host running Watchtower. The button reported failure with a status code and nothing else.

**Root cause.** The fetch sent no CSRF token by either route `csrf_protect` accepts.
The page has carried `<meta name="csrf-token">` since base.html gained it, so the token
was available the whole time — it was simply never read or attached.

**Why it survived.** T-1343/G-048 removed a blanket `/api/*` CSRF exemption. That
change made every state-changing `/api/*` caller responsible for sending a token, and
the five callers using `FormData` already did. This one did not, and nothing joined the
two facts: the page *has* a token, and the request *sends* one. Any check written
against "does the page have a CSRF token" was green throughout — which is why the bug
reached an operator in another project rather than a test here.

That near-miss shape is worth naming, because this task's own regression test walked
into it. The first version asserted `"X-CSRF-Token" in page`, and the negative control
showed it still passed with the fix reverted: the *comment explaining the fix* contains
the string. A check satisfied by prose about a mechanism instead of by the mechanism is
the same defect at one remove. The assertions now strip JS comments before looking.

**Prevention.** Four legs, and the first is a control: without a token the route must
still 403 even for a nonexistent id, so the positive leg cannot pass on a route that
lost its CSRF protection entirely. Leg 4 scans the whole template corpus and asserts a
count, so a seventh state-changing fetch that omits both routes reddens against a
stated number rather than against nobody's memory.

**Not prevented.** Nothing asserts that a real browser executes the JavaScript and the
click completes; that is the one thing the reporting operator actually observed, and it
is the Human AC. A Playwright leg would close it but needs a seeded pending entry on a
live server, which is a bigger rig than this fix warrants.

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

**Rationale:** The defect is confirmed, the fix is one line of JavaScript reading a
token the page already carries, and the four Agent ACs are green with a negative
control proving they can go red. The one thing left is the one thing no test here can
do: press the button in a browser. That is why the Human AC exists and why this is GO
rather than DEFER — there is no missing evidence, only a step that requires a person.

**Evidence:**
- Pre-fix, live: `POST /api/v1/pending/U-999-does-not-exist/resolve` with no token
  returned **403**. A nonexistent id returning 403 rather than 404 proves CSRF fired
  before the lookup, so no click ever reached the handler.
- Post-fix, live, same request with the token: **404**. The header route works.
- `tests/web/test_pending_resolve_csrf.py` — 4 passed. Negative control: with the
  one-line fix reverted, 2 of the 4 go red (2 failed, 2 passed), so the suite can fail.
- The first version of that suite passed with the fix reverted, because the comment
  explaining the fix contained the string it was grepping for. The assertions now
  strip JS comments. Recorded in `## RCA` rather than quietly corrected.
- Corpus scan: 6 state-changing `fetch()` calls in `web/templates/`; the other 5 pass
  `_csrf_token` in a `FormData` body. One site, not a class.
- Credit: reported by 001-CashWeb at chat-arc offset 956, with an exact repro. Their
  diagnosis was correct on every point and was verified here in code and live before
  anything was edited.

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

### 2026-09-01T22:27:25Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3251-pending-resolve-button-omits-x-csrf-toke.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-0f9aaf9e
- **Timestamp:** 2026-09-01T22:34:33Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-09-01T22:34:28Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
