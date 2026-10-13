---
id: T-4061
name: "Query text kept outside telemetry: resolver writes the rendered fw ask prompt
  to prompt.txt, and Watchtower GET ?q= search/ask put queries in request logs (arc-001
  F-9)"
description: >
  lib/resolver.py:791 capture_dispatch writes the rendered prompt (with the user's
  query) to <blob>/prompt.txt when a workflow resolves; Watchtower /api/v1/search,
  /api/v1/ask and /api/v1/ask/stream accept GET ?q=, so the query lands in access
  logs. Conflicts with the operator's data rule (arc-001 R-32). Checked in source
  2026-10-11.

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: [bug, security, privacy]
components: [lib/config.sh, lib/resolver.py, web/blueprints/api.py, 
      web/blueprints/config.py, C-003, web/static/command-palette.js, 
      web/static/js/search-qa.js, web/templates/_partials/search_input.html, 
      web/templates/_partials/search_results.html]
related_tasks: [T-4017]
origin: {kind: "peer", source: "dimitri-mint-dev", ref: "arc-001"}
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
created: 2026-10-11T18:06:03Z
last_update: '2026-10-12T18:30:32Z'
date_finished: 2026-10-11T19:48:10Z
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
  - ts: '2026-10-11T18:08:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 3
      D4: 2
      F-RECALL: 3
      F-AUTONOMY: 0
      F3: 1
      F1: 1
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=3
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=3 (body:fw-recall-or-memory-link); F-AUTONOMY=0 (no-signal); F3=1
      (body/components:prompt-incidental); F1=1 
      (body/components:context-fabric-incidental); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-10-11T18:15:35Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=278,acs=7)
    rubric_sha: e4a00f38e801
  - ts: '2026-10-12T18:30:32Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 7
      tier: 2
      effort: 8
    rationale: blast_radius=7 (9-components-large-blast); tier=2 
      (workflow:build); effort=8 (lines=334,acs=8)
    rubric_sha: e4a00f38e801
---

# T-4061: Query text kept outside telemetry: resolver writes the rendered fw ask prompt to prompt.txt, and Watchtower GET ?q= search/ask put queries in request logs (arc-001 F-9)

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] `lib/resolver.py` `capture_dispatch` no longer writes the rendered prompt text for an `fw ask` / user-query workflow: it stores a hash (and length) of the rendered prompt instead of `prompt.txt`, unless the project explicitly opts in (`fw config` key, default off, registered in BOTH lib/config.sh and web/blueprints/config.py). Non-query dispatches (task workers) keep their prompt capture unchanged.
- [x] Watchtower `/api/v1/search`, `/api/v1/ask` and `/api/v1/ask/stream` accept the query in a POST body; the Watchtower pages that call them use POST. GET `?q=` keeps working for compatibility but is no longer what Watchtower's own UI sends, and the docstrings name POST as the way.
- [x] Watchtower's own request log line does not contain the query string for these endpoints (path logged without the query, or `q` redacted).
- [x] Regression tests (`tests/unit/t4061_query_text_not_kept_test.py` or bats + `tests/web/`): an `fw ask`-type capture leaves no file containing the query text; a task-worker capture still writes its prompt; Watchtower UI search/ask send POST; the request log line for a GET `?q=secret` holds no `secret`. Each fails on the pre-fix code.
- [x] Watchtower restarted; `bin/fw watchtower current` exits 0.

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

- [ ] [REVIEW] Watchtower search box and ⌘K search still show results, and the address bar no longer carries the query
  **Steps:**
  1. Run `cd /opt/999-Agentic-Engineering-Framework && bin/fw watchtower url`, open that URL and append `/search`
  2. Type `healing loop` in the search box and press Enter; note the address bar
  3. Press Ctrl+K (⌘K on macOS), type `healing loop` and choose the "Search … in all content" row; note the address bar
  4. Reload the page once
  **Expected:** results render after steps 2 and 3. The address bar shows `/search` with no `q=` after both. Reload asks to resubmit the form (no query in the URL), which is the intended cost of keeping the query out of the URL.
  **If not:** Note which step fails, whether results or the address bar are wrong, and any browser console error. Check `bin/fw watchtower current` first; a stale server still serves the GET-only page.

## Verification

out=$(python3 -m pytest tests/unit/t4061_query_text_not_kept_test.py tests/unit/test_resolver.py -q -p no:cacheprovider 2>&1); echo "$out" | grep -q " passed" && ! echo "$out" | grep -q "failed"
out=$(bats tests/lint/config-registry-parity.bats 2>&1); echo "$out" | grep -q '^ok 3 ' && ! echo "$out" | grep -q '^not ok'
bin/fw vendor self --check
bin/fw watchtower current

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# The completion gate runs each command — if any exits non-zero, completion is blocked.
# Build/refactor/decommission tasks with NO command here are refused. If nothing can be
# run, add the line `# verification: none — <why nothing can be run>`; it is serviced
# (queued for review: add a check / other evidence / accept). See docs/reports/T-4024-servicing-loop.md.
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

**Symptom:** The operator's typed `fw ask` query sat in plain text in `.context/.../blobs/<month>/<dispatch>/prompt.txt`. Watchtower search queries sat in the URL, and so in werkzeug's access log, via GET `?q=`.

**Root cause:** `capture_dispatch` wrote every rendered prompt unconditionally, treating prompts as telemetry. The search endpoints modelled the query as a URL parameter, and werkzeug logs the full request target.

**Why structurally allowed:** No classification of workflow content as user-supplied. No check of what the request log holds. The API offered GET as the only query form, so the UI followed it. Nothing tested the stored or logged bytes, only the response.

**Prevention:** `carries_user_query: true` on the ask workflow, with the prompt reduced to `prompt_sha256` and `prompt_chars` unless `CAPTURE_QUERY_TEXT` is opted in (default off). POST is the documented query path for `/api/v1/search|ask|ask/stream` and `/search`, and the UI sends POST. A logging filter on the werkzeug logger redacts `q=` and `query=`. Regression tests in `tests/unit/t4061_query_text_not_kept_test.py` assert on stored and logged bytes.

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

**Recommendation:** GO

**Rationale:** Your query text is no longer kept: the `fw ask` prompt is stored as a hash unless a project opts in (`CAPTURE_QUERY_TEXT`, default off), Watchtower's own search box, ⌘K palette and ask send the query in a POST body, and the access log redacts `q=`/`query=`. Verified live after restart; your check of how the search box feels is the open item.

**Evidence:**
- Commit e337c41e5 (+ the log filter in 89c937fa6): lib/resolver.py, web/blueprints/api.py, discovery.py, search templates/JS, config key in both registries
- `tests/unit/t4061_query_text_not_kept_test.py` 10 pass; 3 behaviour tests fail on the old code
- Live 2026-10-11: POST /search (form + CSRF) 200 with results; POST /api/v1/search and /api/v1/ask (X-CSRF-Token) 200; `handover` appears 0 times in watchtower.log; GET `?q=` still works for scripts
- Residual: link fallbacks used only without JavaScript still carry `?q=`; a prompt hash is a fingerprint, not proof against a guessed query

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

### 2026-10-11T18:06:03Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-4061-query-text-kept-outside-telemetry-resolv.md
- **Context:** Initial task creation

### 2026-10-11T18:08:01Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-10-11 — pre-fix failure record (TermLink worker)
- On HEAD code (lib/resolver.py, web/blueprints/api.py, web/blueprints/discovery.py restored, then put back): 3 of the 4 behaviour tests fail — `test_user_query_capture_leaves_no_query_text` (prompt.txt holds the query), `test_api_search_accepts_query_in_post_body` and `test_search_page_accepts_post_form` (405). `test_api_get_search_still_works` passes on both, as a compatibility check.
- The two `web/app.py` log-redaction tests were not run on HEAD: that file is shared with T-4062, so it was not swapped. On HEAD, `QueryRedactFilter` does not exist, so they fail on import.
- Design choice: the palette and search box send POST. Full-page palette search submits a form, so the address bar shows `/search` with no query, and reload resubmits. The `[REVIEW]` Human criterion covers that trade.

## Reviewer Verdict (v1.5)

- **Scan ID:** R-0df3510b
- **Timestamp:** 2026-10-11T19:48:41Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 2

**Per-AC findings:**

- **AC#1 (Agent)** — `lib/resolver.py` `capture_dispatch` no longer writes the rendered prompt text for an `fw ask` / user-query workflow: it stores a hash (and length) of the rendered prompt instead of `prompt.txt`, unle
  - **AC-verify-mismatch** (narrow, heuristic) — `path=web/blueprints/config.py in: `lib/resolver.py` `capture_dispatch` no longer writes the rendered prompt text for an `fw ask` / user-query workflow: it stores a hash (and length) of`
- **AC#3 (Human)** — [REVIEW] Watchtower search box and ⌘K search still show results, and the address bar no longer carries the query
  - **human-ac-mechanical-signal** (partial, heuristic) — `matched='shows `/search`' in Expected: results render after steps 2 and 3. The address bar shows `/search` with no `q=` after both. Reload asks to resubmit the form (no query in t`

### 2026-10-11T19:48:10Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
