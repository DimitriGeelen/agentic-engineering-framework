---
id: T-3369
name: "Human AC Steps/Expected/If-not render escaped HTML — missing | safe in task_detail.html"
description: >
  web/templates/task_detail.html renders Human-AC Steps (line 507), Expected (513)
  and If-not (517) as bare {{ ... }}, so Jinja autoescapes them. But _parse_ac_body
  returns RENDERED HTML — it runs _render_md_inline/_render_md_block, which call _auto_link_files.
  The operator therefore sees literal markup: '&lt;code&gt;&lt;a href=&#34;/file/web/shared.py&#34;&gt;...'
  instead of a clickable link. Violates the T-1575 contract, which states the caller
  must mark the returned string | safe. Pre-existing and long-lived: the template
  last changed 2026-07-29 (T-2674) and these three fields have never carried | safe.
  Invisible until now because escaping only shows when the content CONTAINS markup
  — i.e. when the linkifier fires, which it only does for paths that exist on disk.
  Found while live-verifying T-3368 on /tasks/T-3368; separate root cause (missing
  filter in template) from T-3368 (regex applied over rendered HTML), so filed separately
  per one-bug-one-task. NOTE the fix is not a blind '| safe': that would make it an
  XSS surface for task-file content, so it needs the same safe_mode-escape guarantee
  render_markdown_safe already provides, and a test that a literal '<script>' in an
  AC step stays inert.

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
created: 2026-09-15T18:58:54Z
last_update: 2026-09-16T03:09:42Z
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
  - ts: '2026-09-15T19:00:11Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=269,acs=4)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-09-15T19:00:24Z'
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

# T-3369: Human AC Steps/Expected/If-not render escaped HTML — missing | safe in task_detail.html

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] **XSS safety established BEFORE adding `| safe` — this is the gate on
      whether the fix is legitimate at all.** `| safe` on attacker-influenced
      content is how an XSS hole is made, and task files are content. Two
      independent facts must be shown, not assumed:
      (a) `_render_md_inline` / `_render_md_block` run
      `markdown2.markdown(text, safe_mode='escape')`, so raw HTML arriving from a
      task file is escaped *before* any linkifier runs;
      (b) the linkifiers emit only framework-constructed anchors
      (`/file/…`, `/tasks/T-…`), never attacker-supplied markup.
      Demonstrated by a probe feeding `<script>` and an `onerror=` payload
      through the real helper, not by reading the code.
- [x] **All six sites fixed, not the one that was noticed.**
      `task_detail.html` (steps/expected/if_not) and `_approvals_content.html`
      (steps/expected/if_not). `_review_acs.html` already has all three and is
      the reference implementation — fixing only the page I happened to look at
      would leave `/approvals` broken in exactly the same way, which is how this
      became a 6-site divergence in the first place.
- [x] **Regression test pins both halves:** a literal `<script>` in an AC field
      renders INERT (escaped), and a Markdown link to a real repo path renders as
      a single clickable anchor. The first without the second would be satisfied
      by reverting the fix; the second without the first would be satisfied by an
      XSS hole.
- [x] **Control leg:** with `| safe` removed again, the "renders as an anchor"
      assertion fails. Proves the test observes the template, not just the helper.
- [x] Live-verified on the running Watchtower after restart, and the suite shows
      no new red. **Both halves done 2026-09-16 — see `## Resolution`.** The live
      half is an AC-REGION audit (not the whole-page grep that was inconclusive at
      park time); the suite half is set parity, not merely count parity.

## Resolution (2026-09-16)

Parked at the 300k session cap, not stalled; resumed after compaction reset the
budget and `bin/fw work-on T-3369` lifted the park-ordering interlock.

### Half 1 — live check, AC region specifically

The park note recorded the earlier whole-page grep as **inconclusive** and said
why: `/tasks/T-3368` legitimately contains both escaped and unescaped markup,
because T-3368's own `description:` frontmatter quotes example markup that
*must* stay escaped. A page-wide count therefore measures the wrong thing.

Re-run scoped to the `human-ac-card` body only:

| measurement | result | required |
|---|---:|---|
| live `/file/` anchors | 1 (`/file/web/shared.py`) | ≥1 |
| escaped `&lt;a href=` | 0 | 0 |
| live `<code>` tags | 9 | — |
| escaped `&lt;code&gt;` | 0 | 0 |
| live `<script>` tags | 0 | 0 |
| `on*` handlers | 0 | 0 |

The load-bearing line is the Steps entry rendering as
`<code><a href="/file/web/shared.py">web/shared.py</a></code>` — the exact shape
that appeared as `&lt;code&gt;&lt;a href=&#34;…` before the fix. The last two
rows are the XSS leg holding **live**, not merely in unit tests.

### Half 2 — suite, predicted before the run

Prediction committed at `b3cdcd274` *before* execution: `4 failed / 2725 passed /
2 skipped`, 2731 total (2715 + 16 new tests).

Result: **`4 failed, 2725 passed, 2 skipped in 1831.87s`** — 2731 total. Exact on
all four quantities.

Count parity is not set parity, so the failures were checked by identity:

| failing test | owner |
|---|---|
| `test_live_corpus_all_versions_census` | T-3326 / OBS-410 (Sovereign question) |
| `test_side_effect_warning_truncation_widened_to_1500` | T-2219 (`owner: human`) |
| `test_side_effect_warning_html_escaped` | T-2219 |
| `test_side_effect_warning_uses_pre_wrap_style` | T-2219 |

Identical to the documented set. `2709 + 16 = 2725` accounts for every new pass,
so all 16 new tests are green and nothing previously-green turned red.

### Filed, not folded in (one bug, one task)

- **OBS-411** — backticked *non-tag* placeholders render a literal `&lt;`:
  `` `<that URL>` `` → `<code>&amp;lt;that URL&gt;</code>`, while `` `<b>` `` →
  `<code>&lt;b&gt;</code>` is correct. Discriminator is whether the `<…>` is a
  recognised tag name. **Upstream of this task** — it is in the helper output,
  not the template; this fix is only what made it visible.
- **OBS-412** — OBS-397's pre-registered prediction confirmed: the nightly still
  times out, and its pytest leg reports `failed_count: 0` having run `tests: 0`.

### Human

- [ ] [REVIEW] Human-AC fields on a task page read as rendered prose, not as markup

  **Steps:**
  1. `bin/fw watchtower url` to get the base URL
  2. Open http://192.168.10.107:3002/tasks/T-3368 in a browser
  3. Scroll to the **Human** acceptance criterion (the one badged *Review*)
  4. Read its **Steps**, **Expected** and **If not** blocks
  5. Open http://192.168.10.107:3002/approvals and read the same three fields on any card there

  **Expected:** the three fields read as ordinary formatted text — inline code in a
  code style, `web/shared.py` as a single underlined link that opens the file view.
  No visible angle-bracket markup, no `&lt;`, no stray `href=` or `"&gt;` in the
  prose. Both pages look the same as each other.

  **If not:** note which page and which of the three fields, and whether the text
  shows escaped markup (regression of this task) or a stray `&lt;` in front of a
  placeholder word (that is OBS-411, a separate known defect — not this task).

  *Why this is [REVIEW] and not [REVIEWER]:* the Agent ACs already pin the
  structure by assertion — 9 interpolations carry `| safe`, zero bare, 16 tests
  green, XSS payloads inert. What a static scan cannot answer is whether the
  operator reading Watchtower sees prose that reads cleanly. Per the T-2143
  audience test, the subject here is the human's reading experience, so it lands
  on the Human side.

## Verification` instead of a Human AC here. Only keep [REVIEW] if
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

python3 -m pytest tests/unit/test_ac_field_render_safety.py -q
test "$(grep -hoE '(ac\.steps|step|ac\.expected|ac\.if_not)[^}]*\| *safe' web/templates/task_detail.html web/templates/_approvals_content.html web/templates/_review_acs.html | wc -l)" -ge 9
! grep -nE '\{\{ *(step|ac\.steps|ac\.expected|ac\.if_not) *\}\}' web/templates/task_detail.html web/templates/_approvals_content.html web/templates/_review_acs.html
bin/fw vendor self --check
bin/fw watchtower current


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

## RCA

**Symptom:** Human-AC Steps / Expected / If-not rendered as literal markup to the
operator — `&lt;code&gt;&lt;a href=&#34;/file/web/shared.py&#34;&gt;…` instead of a
clickable link.

**Root cause:** `_parse_ac_body` returns *already-rendered HTML* (it runs
`_render_md_inline` / `_render_md_block`, which call `_auto_link_files`), but
`task_detail.html` and `_approvals_content.html` interpolated it as bare
`{{ … }}`, so Jinja autoescaped it a second time. `_review_acs.html` already had
`| safe` on all three fields — so this was a 6-site divergence, not a single miss.

**Why structurally allowed:** nothing ties the T-1575 rendering contract ("the
caller must mark the returned string `| safe`") to the templates that consume it.
The contract lives in prose; the templates were free to diverge silently. It
stayed invisible because double-escaping is only *visible* when the content
actually contains markup — i.e. when the linkifier fires, which it only does for
paths that exist on disk. Most ACs cite no real path, so most ACs looked fine.
The template last changed 2026-07-29 (T-2674) and these three fields never
carried `| safe` at all.

**Prevention** (distinct from the fix): `tests/unit/test_ac_field_render_safety.py`
pins both halves at once — a literal `<script>` in an AC field stays inert, AND a
Markdown link to a real repo path renders as a single clickable anchor. Either
assertion alone is satisfiable by the wrong code (the first by reverting the fix,
the second by an XSS hole), which is why they are paired. Cross-template parity is
enforced as an *absence* assertion (`_UNSAFE_INTERP`), so a seventh site added
later fails the test rather than silently joining the divergence. A control leg
confirms the test observes the template, not just the helper: removing `| safe`
from one of the six sites fails the parity test and names the template.


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

**Recommendation:** GO

**Rationale:** The fix is a template-level `| safe` on content that was already
being rendered to HTML upstream — it restores the T-1575 contract rather than
widening it. The XSS question was settled *before* the filter was added, by
probing the real helpers rather than reading the code: `markdown2` runs
`safe_mode='escape'` ahead of every linkifier, so raw markup from a task file is
escaped before anything else touches it, and the linkifiers emit only
framework-constructed `/file/` and `/tasks/` anchors. All six divergent sites were
fixed, not just the one that was noticed — fixing only `/tasks/` would have left
`/approvals` broken identically, which is how a 6-site divergence forms.

**Evidence:**
- 12 XSS payloads through both real helpers → 0 live tags, 0 dangerous attributes.
- 9/9 interpolations across 3 templates carry `| safe`; 0 bare (grep-verified).
- `tests/unit/test_ac_field_render_safety.py` — 16 passed.
- Control leg: removing `| safe` from 1 of 6 sites fails the parity test and names
  the template — so the test observes the template, not just the helper.
- Live AC-region audit on `/tasks/T-3368`: 1 live `/file/` anchor, 0 escaped
  anchors, 0 escaped `<code>`, 0 `<script>`, 0 `on*` handlers.
- Full suite: `4 failed, 2725 passed, 2 skipped` (2731) — exactly the prediction
  committed at `b3cdcd274` before the run, and the 4 failures are the same 4 by
  identity (T-3326 ×1, T-2219 ×3), not merely the same count.
- `fw vendor self --check` clean; `fw watchtower current` OK (server not stale).

**What this does NOT claim:** OBS-411 (a literal `&lt;` in front of backticked
non-tag placeholders) is still present. It is upstream of this task — in the
helper, not the template — and this fix is what made it visible. Filed separately.

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

### 2026-09-15T18:58:54Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3369-human-ac-stepsexpectedif-not-render-esca.md
- **Context:** Initial task creation

### 2026-09-15T20:56:06Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-09-15T21:02:16Z — status-update [task-update-agent]
- **Change:** horizon: now → next
- **Change:** status: started-work → captured (auto-sync)

### 2026-09-16T03:09:42Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)
