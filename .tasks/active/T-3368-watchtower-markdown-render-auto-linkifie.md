---
id: T-3368
name: "Watchtower markdown render: auto-linkifier rewrites inside an existing anchor
  href, producing nested <a>"
description: >
  render_markdown_safe / _render_md_inline linkifies a repo-relative path that already
  sits inside a markdown link's href, emitting '<a href="./<a href="/file/PATH">PATH</a>">text</a>'
  — invalid nested anchors, broken links on any task body that links a repo path.
  Pinned by tests/unit/test_review_markdown_render.py::test_parse_ac_body_renders_steps_as_html,
  which FAILS in isolation. Discovered via T-3363: the test was a FALSE GREEN in the
  full suite — a dangling web.shared.PROJECT_ROOT made the file-existence check miss
  so the linkifier never fired and the assertion saw the plain href it expected. Fixing
  the contamination unmasked it. T-1575 rendering-contract territory.

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
created: 2026-09-15T17:49:30Z
last_update: 2026-09-15T18:51:27Z
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
  - ts: '2026-09-15T17:50:35Z'
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
  - ts: '2026-09-15T18:49:22Z'
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
      F2: 1
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=3
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=1 
      (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-09-15T17:51:03Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=269,acs=4)
    rubric_sha: e4a00f38e801
---

# T-3368: Watchtower markdown render: auto-linkifier rewrites inside an existing anchor href, producing nested <a>

## Context

**Diagnosis complete (read-only, during T-3367's verification run). Not yet fixed.**

`web/shared.py:653 _auto_link_files()` runs `_ARTEFACT_PATH_RE.sub()` over
**already-rendered HTML** with no tag awareness. When a markdown link's target is
a repo path that exists, the path inside the emitted `href="..."` attribute is
itself matched and rewritten, nesting an anchor inside the attribute:

```html
<a href="./<a href="/file/.context/working/feedback-stream.yaml">.context/working/feedback-stream.yaml</a>">feedback-stream</a>
```

The same test shows the contrast: `[the report](docs/reports/X.md)` renders
correctly, because that path does **not** exist on disk and the gate at
`web/shared.py:668` — `if (PROJECT_ROOT / path).exists():` — declines to
substitute. So the defect fires only for links whose target actually exists,
which is the majority of real task bodies.

**Why this was invisible until now.** That same existence gate is what made the
test a FALSE GREEN under contamination: with `web.shared.PROJECT_ROOT` left
pointing at a deleted tmp dir by a reload-based test (T-3363 cause 1),
`.exists()` returned False, the linkifier never fired, and the assertion saw the
plain href it wanted. Fixing the contamination unmasked a live rendering bug.
The bug is older than its visibility.

**Fix direction (not authorization — this is discovery).** Substitute only in
text nodes, not inside tags: split the HTML on `<[^>]*>` and run the regex on the
between-tag segments, or reject any match whose surrounding context places it
inside a tag. A blunt "skip if preceded by `href=\"`" would miss the general case
(`src=`, `title=`, and any future attribute).

**Blast radius.** Every Markdown surface — `/review`, `/tasks`, `/approvals`,
`/inception` — since T-1722 promoted `_auto_link_files` into `render_markdown_safe`.
T-1575 rendering-contract territory.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] **The mechanism is demonstrated, not inferred.** A probe shows
      `_auto_link_files` rewriting a path that sits inside an `href="./…"`
      attribute, and shows *why* the three existing lookbehinds at
      `web/shared.py:633-635` do not stop it: T-1551 normalises leading-dot
      relative paths to `./`, so the six characters before the match are `ef="./`
      rather than `href="`. Without this the fix is a guess.
- [x] **The fix is structural, not another fixed-string guard.** No nested anchor
      is produced for **any** of `href="p"`, `href="./p"`, `href="../p"`, or
      `src="p"`. A fourth lookbehind would pass the current test and leave the
      class open — that is precisely how this bug survived T-1722.
- [x] **Control leg:** with the fix reverted, the new regression test fails.
      Distinguishes "the fix works" from "the test never exercised the path" —
      the T-3363/T-3367 lesson applied to this task.
- [x] **The feature still works.** A path in ordinary prose still becomes a
      `/file/` link, and a backticked path still renders `<a …><code>…</code></a>`
      per the T-1575 contract. Disabling linkification would pass the failing
      assertion while destroying the feature; that is not a fix.
- [ ] `tests/unit/test_review_markdown_render.py` passes in full, and the suite's
      failure count drops from 7 to 6 with no new red.

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

- [ ] [REVIEW] A task page whose body contains a Markdown link to a real repo path
      renders as one clean clickable link — no visible `<a href=` fragments, no
      doubled link text, nothing that looks like escaped HTML leaking into the page.

  **Steps:**
  1. `cd /opt/999-Agentic-Engineering-Framework && bin/fw watchtower url` to get the base URL
  2. Open `<that URL>/tasks/T-3368` in a browser
  3. Look at the **Context** section — it contains Markdown links to real repo
     paths (`web/shared.py`), which is exactly the shape that triggered the bug
  4. Click one of the rendered path links

  **Expected:** each path shows once, as a single underlined link; clicking opens
  the file view. No stray `">` or `href=` characters visible in the page text.

  **If not:** screenshot the mis-rendered line and note which path shape it used
  (`p`, `./p`, `../p`), then reopen this task — the tag-splitting fix missed a shape.

  *Why this is [REVIEW] and not [REVIEWER]:* the Agent ACs already pin the
  structural facts by assertion (no nested `<a>`, all four attribute shapes). What
  a static scan cannot answer is whether the rendered page *looks* right to the
  operator reading it — the audience for this judgement is the human using
  Watchtower, which is the T-2143 audience test coming out on the Human side.

## Measurements

### AC 1 — mechanism (probe, before any code change)

| input | before fix |
|---|---|
| `<a href="PATH">` | clean — T-1722's guard catches this one shape |
| `<a href="./PATH">` | **nested `<a>`** |
| `<a href="../PATH">` | **nested `<a>`** |
| `<img src="./PATH">` | **anchor injected into the `src` attribute** |
| bare prose | correct |
| backticked | correct (`<a><code>`, T-1575) |

Why the guard misses, measured directly rather than reasoned about — for
`<a href="./.context/working/feedback-stream.yaml">` the match begins at offset
11 and the six preceding characters are `ef="./`, not `href="`. T-1551
normalises leading-dot relative paths to `./` for safe_mode; those two
characters are the whole defect. Neither feature is wrong on its own.

### AC 2/4 — after the fix, all ten shapes

`href="p"`, `href="./p"`, `href="../p"`, `src="./p"`, `title="p"` all untouched;
anchor *text* no longer double-linked; bare prose, backticked, and `<code>`
spans still linkify; text after a `">`-terminated tag now linkifies (a false
negative the old `(?<!">)` guard caused); malformed `</a></a>` clamps instead of
re-enabling rewriting.

### AC 3 — control leg

`git checkout web/shared.py` (revert to HEAD), same tests:

```
5 failed, 37 passed
  test_no_rewrite_inside_a_tag[<a href="./{p}">text</a>]
  test_no_rewrite_inside_a_tag[<a href="../{p}">text</a>]
  test_no_rewrite_inside_a_tag[<img src="./{p}">]
  test_no_rewrite_inside_a_tag[<span title="{p}">x</span>]
  test_parse_ac_body_renders_steps_as_html
```

The `href="{p}"` shape passes **even reverted** — correct, and the reason the
parametrisation matters: a fourth lookbehind would have turned the other four
green while leaving the class open. Restore verified byte-identical (`diff -q`),
then 42 passed.

### Lookbehind removal (measured, not assumed)

The three lookbehinds are subsumed by the tag/text split, so they were removed.
Checked across `test_render_artefact_paths`, `test_review_markdown_render`,
`test_extract_recommendation`, `test_render_page_guard`: **79 passed, 1 failed**,
and the one failure is `test_guard_skipped_on_htmx_request`
(`TemplateNotFound: _breadcrumb.html`) — T-3365's pre-existing standing failure,
item 6 of the 7 the suite already reports. Not caused by this change.

Removal is not tidying: `(?<!">)` was suppressing legitimate links whenever text
followed any `">`-terminated tag, so the guards cost false negatives while never
providing complete coverage.

### Pre-registered prediction (AC 5, written before the run was launched)

The suite reported **7 failed / 2697 passed / 2 skipped / 2706 total** at T-3367
close. This task fixes exactly one of those seven and adds seven tests, so:

- **failed: 6** — the remaining standing causes: `test_corpus_lint` (T-3326),
  `test_file_route_extensions` (T-3364), `test_inception_decide_warning_widen`
  ×3 (T-2219), `test_render_page_guard` (T-3365).
- **total: 2713** — 2706 + 7 new (5 parametrised shapes + link-text control +
  feature-still-works).
- **passed: 2707**, skipped 2.

Interpretation fixed in advance:

- **More than 6, or a node id not on that list** — the tag/text partitioning
  broke a surface these four test files do not cover. The lookbehind removal is
  the most likely culprit and should be reverted first, since it was the one
  change made for tidiness rather than to fix the reported defect.
- **Fewer than 6** — something else got fixed or suppressed as a side effect;
  investigate rather than bank it.
- **total != 2713** — a collection error, which a green-looking failure count
  would otherwise hide (T-3217 class: a test that never runs reports nothing).

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

# T-3368 — the render-surface file under test.
o=$(mktemp); timeout 600 python3 -m pytest tests/unit/test_review_markdown_render.py -q -p no:cacheprovider --color=no > "$o" 2>&1 && grep -q "passed" "$o"

# The T-1575 rendering contract must survive the tag-splitting change.
c=$(mktemp); timeout 600 python3 -m pytest tests/unit/test_extract_recommendation.py -q -p no:cacheprovider --color=no > "$c" 2>&1 && grep -q "passed" "$c"

# web/ is a vendored path (CLAUDE.md §Vendored-path-touching tasks): sync BEFORE close,
# not after — closing clears focus and there is no route back (OBS-250, widened OBS-408).
bin/fw vendor self --check

# web/ is a deployment surface: Flask runs debug=False, so a fix can be on disk,
# unit-green and closed while the running process still serves the pre-fix bytes
# (G-104, T-3282). Exits 0 when current OR when no Watchtower is running.
bin/fw watchtower current

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

### 2026-09-15T17:49:30Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3368-watchtower-markdown-render-auto-linkifie.md
- **Context:** Initial task creation

### 2026-09-15T18:49:22Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
