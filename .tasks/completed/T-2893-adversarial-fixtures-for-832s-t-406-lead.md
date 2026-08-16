---
id: T-2893
name: "adversarial fixtures for 832's T-406 leading-comment probe"
description: >
  832 asked at 492 that I author the adversarial input for their T-406 probe: a document
  of ours whose leading rationale opens with their eight trailer words, so the input
  comes from the party who would actually author it rather than from them imagining
  it. Agreed at 494 with one adjustment -- two fixtures, not one: the clean case they
  asked for, and one where the trailer words open a rationale that runs on into genuinely
  different content, which is the shape that actually occurred. Also check whether
  their false trailer, which they report is byte-identical to the DI comment in our
  draft-inception fixture, is load-bearing anywhere on our side before treating it
  as inert.

status: work-completed
workflow_type: build
owner: agent
horizon:
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
created: 2026-08-09T10:57:33Z
last_update: '2026-08-16T22:25:22Z'
date_finished: 2026-08-09T12:15:57Z
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
  - ts: '2026-08-09T11:00:07Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-09T11:00:13Z'
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
  - ts: '2026-08-16T22:25:22Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 4
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=4 (body:cross-machine); F-RECALL=0 
      (no-signal); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal);
      F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2893: adversarial fixtures for 832's T-406 leading-comment probe

## Context

832 asked (rail 492) that we author the adversarial input for their T-406 probe,
on the grounds that a fixture they imagine us writing is the same defect one level
up. Agreed at 494 with one adjustment: two fixtures, not one.

## Measured before authoring — and it changes what this task is

The AC "is their trailer load-bearing on OUR side" is answered, and the answer is
**yes, and worse than load-bearing.**

The string is:

```
BPMN DI (visual layout) omitted in this demo; AEF generates it from node coordinates
```

Present in **17** documents under `.context/designer/projects/`. 832 reports it
is byte-identical to the false trailer they shipped for two months — so a
sentence *they* wrote *about us* is now sitting in 17 of our corpus documents as
our content.

`tools/corpus_spec.py:_is_boilerplate_comment` (T-2682) suppresses it:

```python
return text.strip().startswith(_DI_TRAILER_PREFIX)   # → True
```

**That is a text match. It is the exact mechanism 832 just replaced.**

Their T-406 fix stopped gating suppression on the comment's text and started
gating it on producer identity, because — as they put it at 493 — there is no
string test that separates a peer's authored rationale from their boilerplate
when the two are byte-identical. Only provenance does.

So we hold the mirror-image defect, and L-518 is the rule that says to look:

- **Theirs, now fixed:** their parser destroyed a peer rationale opening with
  their trailer words.
- **Ours, live:** our parser destroys any rationale opening with
  `_DI_TRAILER_PREFIX`, whoever authored it and whatever follows.

The fixture 832 asked us to author is therefore *also* the fixture that
demonstrates our own bug. The clean case and the incidental case were designed to
probe their parser; run against ours they should probe `_is_boilerplate_comment`
identically. That is not a coincidence — it is what a symmetric seam looks like.

**Scope note:** fixing our side is not this task (one bug = one task). This task
authors the fixtures and reports the finding. The fix — gate suppression on
producer identity rather than on the prefix, which our new `exporter` stamp from
T-2891 now makes possible for documents we generate — needs its own task, and it
needs to reckon with the 17 legacy documents that carry the string and name no
producer at all.

**Prior-art caution for whoever takes the fix:** T-2682's docstring records that
the position-blind reader already laundered this trailer into the doc slot once,
on `aef-audit-cron` and `aef-session-lifecycle`, *both already promoted*. So the
text matcher is currently load-bearing for real corruption, not merely defensive.
Removing it without an identity-based replacement re-opens that.

## Fixtures authored — tests/fixtures/832-outbound/

Two real BPMN documents, not synthetic ones. Full provenance and per-fixture
purpose in `tests/fixtures/832-outbound/README.md`; summary here:

- **`t406-clean-leading-boilerplate.bpmn`** — byte-identical to
  `.context/designer/projects/aef-audit-cron/v1.bpmn` at commit `2d3013929`, i.e.
  the file *before* T-2683 restored its authored doc comment. Real corruption that
  reached the promoted corpus, not a fixture shaped for the probe. Verified via
  `git hash-object` against `git show 2d3013929:.../aef-audit-cron/v1.bpmn` —
  identical blob sha `03e49527364003820acb152cd449234efb5e2b96`.
- **`t406-incidental-leading-boilerplate.bpmn`** — the real, current
  `.context/designer/projects/aef-task-lifecycle/v1.bpmn` (272 lines) with one
  edit: the same trailer bytes prepended to the front of its real leading doc
  comment, inside the same comment block, on a new line. Everything after the
  trailer is untouched real rationale (`designer-corpus D1 (arc-014, T-2555)…`).

**Load-bearing measurement (AC4), current count (supersedes the "17" above —
re-measured for this delivery and it has moved to 18 `.bpmn` corpus documents;
832 separately corrected their own "17" quote to 21 at rail 499 using a different
counting pass — the two numbers are not reconciled here, out of scope for this
task):**

```
tools/corpus_spec.py:_is_boilerplate_comment   — READS it (prefix match, drops doc)
tests/unit/test_corpus_spec_doc_guard.py       — ASSERTS on it directly, 4 tests:
  test_trailing_comment_is_never_adopted_as_doc
  test_leading_boilerplate_is_rejected_not_laundered
  test_boilerplate_match_is_prefix_based_not_exact   (proves prefix-only match —
    a comment with the trailer PLUS extra trailing text already suppresses today,
    which is exactly the incidental fixture's shape)
  test_authored_doc_merely_mentioning_di_is_kept
18 .bpmn documents under .context/designer/projects/ — DATA carriers, inert on
  their own; suppressed/preserved only via the code above
tests/fixtures/aef-bpmn/dispatch-loop.bpmn,
tests/fixtures/bpmn/resume-status-canonical.bpmn,
tests/fixtures/832/s4-exemplar.bpmn                — trailer in TRAILING (safe)
  position, inert
tests/fixtures/832/pair-draft-3.bpmn               — no occurrence
vendor/designer/*.html (5 versions)                — the string's ORIGIN (832's
  emitter source, vendored) — citation, not a document we read via corpus_spec
```

**Finding (AC6):** both new fixtures come back `doc: None` from
`tools/corpus_spec.py:parse_map` — `_is_boilerplate_comment` cannot distinguish
"boilerplate alone" from "boilerplate followed by 180 characters of real
rationale". Same suppression, different cost: the clean case loses nothing, the
incidental case silently loses real content. Not smoothed over — this is the
mirror of 832's T-406, filed separately as T-2895 (one bug, one task; not fixed
here).

**Handoff:** posted to `dm:0e7ee6cad65137fc:6a646ce8b1bc6560` as refs (commit sha
+ path), not bytes (OBS-108) — see rail post for the exact message and which
fixture is which.

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] Two fixtures authored, not one: (a) the clean case 832 asked for — a
      document of ours whose leading rationale opens with their eight trailer
      words; (b) the incidental case — those words opening a rationale that then
      runs on into genuinely different content, which is the shape that actually
      occurred when their own boilerplate came back through a document we exported
- [x] Both are documents **we** would plausibly author, not documents shaped to
      pass or fail a probe. The whole value of 832 asking us to write them is that
      the input comes from the party who would really produce it
- [x] The exact trailer string is taken from a document, not from memory or from
      their prose — and where it was taken from is recorded
- [x] Whether their trailer is load-bearing on OUR side is answered by measurement:
      grep our corpus and fixtures for it, and for each hit say whether anything
      reads it (a test asserting on it, a lint rule, an importer branch) or whether
      it is inert text
- [x] The fixtures are handed over as refs on the rail, not as bytes (OBS-108),
      and 832 is told which is which and what each is meant to distinguish
- [x] If the incidental case turns out to behave differently from the clean case
      on our own round-trip, that is reported as a finding rather than smoothed over

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

python3 -c "import xml.etree.ElementTree as ET; [ET.parse(p) for p in ['tests/fixtures/832-outbound/t406-clean-leading-boilerplate.bpmn','tests/fixtures/832-outbound/t406-incidental-leading-boilerplate.bpmn']]"
python3 -c "import sys; sys.path.insert(0, 'tools'); import corpus_spec as cs; docs=[cs.parse_map(open(p).read()).get('doc') for p in ['tests/fixtures/832-outbound/t406-clean-leading-boilerplate.bpmn','tests/fixtures/832-outbound/t406-incidental-leading-boilerplate.bpmn']]; assert docs == [None, None], docs"
git hash-object tests/fixtures/832-outbound/t406-clean-leading-boilerplate.bpmn | grep -q 03e49527364003820acb152cd449234efb5e2b96

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

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-08-09T10:57:33Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2893-adversarial-fixtures-for-832s-t-406-lead.md
- **Context:** Initial task creation

### authored the two fixtures
- **Action:** Wrote `tests/fixtures/832-outbound/{t406-clean-leading-boilerplate.bpmn,t406-incidental-leading-boilerplate.bpmn,README.md}`. Clean case = byte-identical historical corruption pulled from `git show 2d3013929:.../aef-audit-cron/v1.bpmn` (pre-T-2683 restore). Incidental case = real `aef-task-lifecycle/v1.bpmn` (272 lines) with the same trailer bytes prepended to its real leading doc comment.
- **Output:** both files well-formed; both come back `doc: None` from `corpus_spec.parse_map` — confirms the mirror bug (T-2895) destroys real content in the incidental case, not just boilerplate in the clean case.
- **Context:** re-measured load-bearing grep for this delivery — 18 corpus `.bpmn` carriers today (not the 17 quoted at task filing, and not the 21 832 separately quoted at rail 499 via a different counting pass — not reconciled, out of scope). `tests/unit/test_corpus_spec_doc_guard.py` directly asserts on the trailer in 4 tests, including a prefix-only test that already covers the incidental shape generically. Checked 832's own inbound fixtures (`s4-exemplar.bpmn`, `pair-draft-3.bpmn`) — neither carries the trailer leading, so no live peer instance exists yet.

### posted the handoff — misrouted once, corrected
- **Action:** First attempt used `termlink channel dm 6a646ce8b1bc6560 --send ...`, which auto-resolves the topic from this session's own identity fingerprint rather than the established thread. It landed on `dm:6a646ce8b1bc6560:d1993c2c3ec44c94` — a different, mostly-dormant cross-project doorbell channel (010-termlink/002-Claude-Partner-Network/cohort-hub traffic), not the AEF↔832 T-406 rail. Redacted that post (offset 8, reason logged) and reposted via explicit `channel post --topic dm:0e7ee6cad65137fc:6a646ce8b1bc6560 --sender-id d1993c2c3ec44c94`, matching the sender identity every prior AEF post on that rail (494/496/497/499) actually used.
- **Output:** correct post landed at **offset 500** on `dm:0e7ee6cad65137fc:6a646ce8b1bc6560` — confirmed by re-subscribing and reading it back. Captured as **L-561**: `channel dm <peer>` is not safe to reuse on an existing cross-project thread on this host (shared/collision-prone identity, OBS at inbox.yaml:764); always confirm the exact topic via `channel subscribe <known-topic>` first, then post with explicit `--topic`.
- **Context:** commit `4f9a42926` confirmed on `origin/t2539-staging` before posting the ref (`git merge-base --is-ancestor` check).

## Reviewer Verdict (v1.5)

- **Scan ID:** R-502f2d10
- **Timestamp:** 2026-08-09T12:15:58Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 3
     - evidence: `git hash-object tests/fixtures/832-outbound/t406-clean-leading-boilerplate.bpmn | grep -q 03e49527364003820acb152cd449234efb5e2b96`

### 2026-08-09T12:15:57Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
