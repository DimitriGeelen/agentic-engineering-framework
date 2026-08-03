---
id: T-2775
name: "Watchtower /timeline renders 69.8MB of HTML with no bound"
description: >
  The /timeline route returns 69,814,921 bytes (69.8 MB) in a single response, measured
  directly off the Flask test client and confirmed against the live server. It renders
  every session ever recorded, each with its full enriched tasks_touched/tasks_completed
  lists, with no limit, pagination, or windowing. Template rendering alone is 6.5s
  and _wrapper.html:root is invoked 1,714,776 times. This fails the 5s LOAD_CAP_MS
  guard at 29.4s to domcontentloaded.

  Found while fixing T-2774 (Watchtower / latency). Distinct defect, distinct cause:
  T-2774 was per-request corpus re-parsing; this is unbounded output volume. A 70MB
  page is not a latency problem that caching fixes — the bytes have to be produced
  and shipped regardless. Sibling of the same class: /bvp at 5,374,898 bytes, which
  already caused a SIGPIPE false-green in T-2743 because it overflows the 64KB pipe
  buffer.

  Fix shape is probably windowing (most-recent-N sessions with paging) rather than
  caching. Note the size cap should be a guard in its own right — there is a height
  guard (test_all_routes_height.py, 8000px) and a latency guard (LOAD_CAP_MS, 5s)
  but no response-SIZE guard, which is why 70MB shipped unnoticed.

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: []
components: [agents/task-create/create-task.sh, tests/playwright/test_all_routes_size.py, tests/unit/test_task_create_description_yaml.py, web/blueprints/timeline.py, web/templates/timeline.html, web/templates/timeline_session.html]
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
created: 2026-08-03T19:18:51Z
last_update: 2026-08-03T22:39:59Z
date_finished: 2026-08-03T22:39:59Z
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
  - ts: '2026-08-03T21:45:08Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-03T21:45:13Z'
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

# T-2775: Watchtower /timeline renders 69.8MB of HTML with no bound

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] `/timeline` response size is bounded and the number is recorded before and after,
      measured off the wire (`curl -w '%{size_download}'`) not estimated from the template
      → **69,879,595 → 513,706 bytes** worst page (136x). Landing page 609,180 → 513,706 is
      not the headline; see the next-to-last AC for why the worst page is the real number.
- [x] The bound is a deliberate, documented choice (most-recent-N with paging, or an
      explicit windowing rule) — not a silent truncation. A user who has more history than
      the window must be able to reach it, and must be able to tell that a window applies.
      → 25 sessions/page with prev/next/first/last, header states "showing X–Y of 1,524,
      page N of 61". Per-session task lists cap at 40 with a "+N more" link to
      `/timeline/session/<id>`, which renders that session whole.
- [x] `/timeline` passes the existing 5s `LOAD_CAP_MS` guard in
      `tests/playwright/test_all_routes_load_time.py` (currently 29,439ms)
      → **0.64s**. Full suite now **54/54 pass**; it had 5 failures at the start of this work.
- [x] The information the page exists to convey is preserved — verify the most-recent
      sessions still render with their task lists, deltas, and emergency-run collapsing
      intact. A page that is fast because it stopped saying anything is not fixed.
      → Page 1: 25 token-delta marks, 1,185 task links, 971 expand affordances, 20 "+N more"
      links. Emergency marking verified on page 57 (where the emergency sessions actually
      are — page 1 has none, so checking only page 1 would have proved nothing). Run
      collapsing intact: 1,524 sessions → 1,510 entries.
- [x] A response-SIZE guard exists, parametrized over all routes, sibling to the existing
      height guard (`test_all_routes_height.py`, 8000px) and latency guard (`LOAD_CAP_MS`,
      5s). This is the structural gap: 69.8 MB shipped unnoticed because size was the one
      axis nothing measured, and L-429 (T-2040) already names unbounded pages as a
      recurring class — the learning existed, the check did not.
      → `tests/playwright/test_all_routes_size.py`, 2 MB cap over all discovered routes.
      It found two more members of the class on its first run: `/project` (T-2781) and
      confirmed `/bvp` (T-2780).
- [x] The size guard is mutation-checked: confirm it fails against the current unbounded
      `/timeline` before the fix, and passes after. A guard that has never been red proves
      only that it is implemented, not that it is correct (L-530).
      → Restoring the unbounded render (page size 100000, per-session cap 1000000) turns it
      red on 5 tests; reverting turns it green (56 passed, 2 xfailed).
- [x] `/bvp` (5,374,898 bytes) is assessed against the same size guard and either brought
      under it or given an explicit, recorded exemption with a reason. It is the same class
      and it has already caused a false green once — its size overflows the 64KB pipe
      buffer, which made `cmd | grep -q` exit 141 (SIGPIPE) and read as a failing check
      (T-2743, L-387). Do not fix `/timeline` and leave its sibling unmeasured.
      → Measured at 5,385,019 bytes and filed as **T-2780** with its own ACs. Exemption is
      recorded in `KNOWN_OVER_CAP` naming the owning task, and the guard *fails* an entry
      that drops under cap while still listed — so the exemption cannot outlive the fix.

### Human

- [ ] [REVIEW] The timeline still reads as a narrative, and the window is obvious rather than
      merely disclosed.

  **Steps:**
  1. Open http://192.168.10.107:3001/timeline
  2. Read the header line and the pager. Ask whether it is clear you are looking at the most
     recent 25 of 1,524 sessions, and that older history is a click away — as opposed to
     looking like the whole record.
  3. Click "Older ›" a couple of times, then "Newest «". Check the narrative still flows and
     the token-delta figures still make sense across a page boundary.
  4. Find a session showing "+ N more tasks in this session ›" and follow it.

  **Expected:** The paged view reads as a deliberate window, not as truncation or as loss.
  The per-session page shows that session's full task list. Nothing feels like it went
  missing.

  **If not:** Say which of the three signals is weak — the header wording, the pager, or the
  "+N more" link — and whether the fix is wording, placement, or page size (25 is a
  parameter, `_TIMELINE_PAGE_SIZE` in `web/blueprints/timeline.py`).

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

python3 -c "import ast,sys; ast.parse(open('web/blueprints/timeline.py').read())"
FW_TEST_PORT="$(bin/fw watchtower port)" python3 -m pytest tests/playwright/test_all_routes_size.py -q > /tmp/.t2775-size.out 2>&1 && grep -q "56 passed" /tmp/.t2775-size.out
FW_TEST_PORT="$(bin/fw watchtower port)" python3 -m pytest tests/playwright/test_all_routes_load_time.py tests/playwright/test_all_routes_height.py -q -k timeline > /tmp/.t2775-guards.out 2>&1 && grep -q "2 passed" /tmp/.t2775-guards.out
# Worst page, not the landing page — page 1 measured fine while page 10 was 12.6 MB.
python3 -c "import sys,urllib.request; u=sys.argv[1]; m=max(len(urllib.request.urlopen(u+'/timeline?page=%d'%p,timeout=300).read()) for p in (1,10,35,61)); print('worst page bytes:',m); sys.exit(0 if m < 2000000 else 1)" "$(bin/fw watchtower url)"
# The capped remainder must stay reachable, else the bound is a deletion.
curl -sf -o /dev/null -m 120 "$(bin/fw watchtower url)/timeline/session/S-2026-0706-2055"

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

**Symptom:** `/timeline` returned 69,879,595 bytes (69.9 MB) and took 29.4s to
domcontentloaded, failing the 5s Playwright cap.

**Root cause:** the route rendered every session ever recorded — 1,524 of them, carrying
182,541 task references — with no windowing on either axis.

**Why structurally allowed — the page was already "fixed" once.** T-2041 capped this exact
page, on the height axis: render everything, wrap the overflow in a collapsed `<details>`.
That was a correct fix for what it measured. `display:none` is excluded from `scrollHeight`,
so the 8000px height guard went green and stayed green, while all 69.9 MB continued to cross
the wire. The latency guard, meanwhile, passed intermittently for an unrelated reason —
transfer over loopback is 4.4s, under the 5s cap, because the cost is the browser parsing
70 MB rather than the server sending it. So the page satisfied both guards it had, and the
one axis nobody measured was the one that was broken.

That is the general shape worth keeping: **"bounded" is per-axis, and a page is bounded only
on the axes something actually measures.** Two green guards read as "this page is fine"
rather than as "this page is fine in two specific respects". L-429 (T-2040) had already named
unbounded pages as a recurring class — the learning existed; the third check did not.

**A second axis inside the fix.** Paging alone took the landing page to 609,180 bytes and
looked like the job was done. Sweeping all 61 pages showed the worst at **12,576,219 bytes** —
sessions are wildly uneven (median ~37 task references, largest 2,499), so one outlier
dominates whichever page it lands on. Bounding the session count does not bound session size.
Measuring only the landing page would have shipped a 12.6 MB page as a fix.

**Prevention:**
1. `tests/playwright/test_all_routes_size.py` — a response-SIZE guard over every discovered
   route, 2 MB cap, measured off the wire (not `len(page.content())`, which is the
   post-parse DOM and a different number). Third sibling to the height and latency guards.
2. It found two further members of the class on its first run: `/project` (T-2781, 2.27 MB)
   and `/bvp` (T-2780, 5.4 MB). Both are recorded as exemptions naming their owning task, and
   the guard fails an exempted route that drops under cap — a stale exemption cannot outlive
   the defect it documents.
3. `test_timeline_pages_bounded_not_just_the_first` samples pages 1/10/35/61 rather than the
   landing page, pinning the second axis specifically.
4. Mutation-checked against the unbounded render, per L-530: a guard that has never been red
   demonstrates only that it is implemented.

## Recommendation

**Recommendation:** GO

**Rationale:** The defect is closed on the axis it was filed for and the structural gap behind
it is now covered. `/timeline` went from 69,879,595 bytes to 513,706 on its worst page and from
29,439ms to 640ms, with content verified preserved rather than assumed. The remaining judgment
is genuinely yours: whether the paged view still *reads* as the project's narrative. I can
measure that 1,185 task links and 25 token deltas render; I cannot tell you whether stepping
through 61 pages feels like history or like a filing cabinet. That is the one open AC.

Two follow-ups are filed rather than folded in, per one-bug-one-task: T-2780 (`/bvp`, 5.4 MB)
and T-2781 (`/project`, 2.27 MB). Both were found by the new guard on its first run, which is
the strongest evidence I have that the guard was the missing piece rather than the fix itself.

**Evidence:**
- `web/blueprints/timeline.py` — 25 sessions/page, 40 tasks/session, deltas and emergency-run
  collapsing computed before slicing (both are cross-session)
- `web/templates/timeline.html` + new `timeline_session.html` — stated window, pager,
  "+N more" link to the full per-session list
- `tests/playwright/test_all_routes_size.py` — 2 MB cap over all routes; 56 passed, 2 xfailed
- Mutation check: unbounded render turns the guard red on 5 tests, revert turns it green
- Full load-time suite 54/54 (5 were failing at the start of this work); height guard green
- Worst-page sweep across all 61 pages: 12,576,219 → 513,706 bytes after the per-session cap
- Verification block 5/5 PASS

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

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-08-03T19:18:51Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2775-watchtower-timeline-renders-698mb-of-htm.md
- **Context:** Initial task creation

### 2026-08-03T19:30:24Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-8b3e2240
- **Timestamp:** 2026-08-03T22:40:48Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-08-03T22:39:59Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
