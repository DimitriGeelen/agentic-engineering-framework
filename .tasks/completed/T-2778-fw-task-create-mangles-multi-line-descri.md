---
id: T-2778
name: "fw task create mangles multi-line descriptions into unparseable YAML"
description: >
  create-task.sh indents only the first line of --description when substituting into
  the 'description: >' folded scalar, so any newline in the description emits continuation
  lines at column 0. YAML ends the scalar there and parses the next paragraph as a
  mapping, producing a ScannerError. Three sites share the defect: inception template,
  default template, and the fallback heredoc. Instance: T-2775, filed this session,
  flagged by audit as T-2069 class.

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
created: 2026-08-03T21:30:27Z
last_update: '2026-08-03T21:45:13Z'
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
      D2: 4
      D3: 3
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=3
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2778: fw task create mangles multi-line descriptions into unparseable YAML

## Context

`fw task create --description` emitted frontmatter that YAML could not parse, whenever the
description contained a blank line. Found via the audit WARN on T-2775 (filed earlier the
same session). The defect is in the producer, present at three emission sites, and it has
two outcomes — only one of which anything detects.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] Repro established BEFORE the fix: a `--description` containing a blank line produces
      frontmatter that `yaml.safe_load` rejects. Recorded verbatim in `## RCA` with the
      ScannerError message and the offending column. Mutation discipline: if the repro does
      NOT fail on unfixed code, the premise is wrong and this task re-scopes (T-2776 pattern).
      → Reproduced by driving the real `create-task.sh` against a scratch `TASKS_DIR`:
      `ScannerError: while scanning a simple key … could not find expected ':'` at line 8.
- [x] All three emission sites in `agents/task-create/create-task.sh` indent EVERY line of
      the description, not just the first: inception template, default template, and the
      fallback heredoc. Each site exercised by the test below — a fix verified at only the
      default site would leave two live.
      → `indent_block()` at both python sites; `DESCRIPTION_INDENTED` (awk) at the heredoc.
- [x] Round-trip preserved, not merely parseable: the parsed `description` value contains
      text from every paragraph of the input. Escaping a mangled field into an empty string
      would also "parse" — that is the failure this AC excludes.
      → This AC earned its keep: the inception path already "parsed" before the fix, while
      silently truncating `description` to `'First paragraph.\n'` and injecting a junk key.
- [x] `tests/unit/test_task_create_description_yaml.py` pins the contract and is mutation-checked
      (reverting any one of the three sites turns the suite red).
      → 5 passed. Each of the 3 mutations killed exactly one test, disjointly: inception,
      build, fallback. No site is covered only incidentally by another site's test.
- [x] T-2775's existing frontmatter is repaired in place with its description content
      preserved, and `bin/fw audit --section structure` no longer emits the unparseable-YAML WARN.
      → Repaired; audit structure section emits no frontmatter line and no `[FAIL]`.
- [x] Corpus census: every task file under `.tasks/active/` and `.tasks/completed/` has
      frontmatter that parses to a non-empty dict. Count of files scanned is reported, so the
      denominator is visible rather than assumed.
      → 2,765 scanned (312 active / 2,453 completed): 0 unparseable, 0 truncated. The census
      predicate had to be widened first — see RCA; on the original predicate it read 1 of 5.

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

bash -n agents/task-create/create-task.sh
python3 -m pytest tests/unit/test_task_create_description_yaml.py -q > /tmp/.t2778-pytest.out 2>&1 && grep -q "5 passed" /tmp/.t2778-pytest.out
# Both python emission sites must call indent_block, and the heredoc must use the pre-indented var.
test "$(grep -c "indent_block(desc)" agents/task-create/create-task.sh)" = "2"
grep -q '^\$DESCRIPTION_INDENTED$' agents/task-create/create-task.sh
# Corpus census on BOTH predicates (parse failure AND silent truncation into junk keys)
# runs as test_corpus_frontmatter_is_intact inside the pytest line above; this asserts the
# test is actually present rather than trusting the suite's name.
grep -q "def test_corpus_frontmatter_is_intact" tests/unit/test_task_create_description_yaml.py

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

**Symptom:** `fw audit` WARNed that T-2775 had unparseable YAML frontmatter. Reproduced by
driving the real `create-task.sh` against a scratch `TASKS_DIR` with a three-paragraph
`--description`:

```
ScannerError: while scanning a simple key
  in "<unicode string>", line 8, column 1:
    Third paragraph.
    ^
could not find expected ':'
  in "<unicode string>", line 10, column 1:
    status: captured
```

**Root cause:** `description: >` is a folded scalar — every line of its value must be
indented. All three emission sites substituted with `'description: >\n  ' + desc`, indenting
only the first line. Any newline in the description therefore ended the scalar, and YAML read
the following paragraphs as frontmatter.

**The part that matters — the failure has two outcomes, and the loud one is the lucky one:**

| continuation paragraph | outcome | detected? |
|---|---|---|
| contains `word: word` | parses as a junk top-level key; `description` silently truncated to its first line | **no** — valid YAML, audit sees nothing |
| contains no colon | ScannerError | yes — audit WARNs |

So the observable rate understates the real rate, and does so *by construction*: the better
formed the prose, the likelier it contains a colon, and the likelier the corruption is silent.
My first census used the loud predicate — "does `yaml.safe_load` raise?" — and returned **1 of
2,765**. Re-run on "did a description paragraph become a frontmatter key?", the same corpus
returned **5**: T-2775 (loud), plus T-2776 ×2, T-2777, and T-452 (all silent, all invisible).
T-452 shipped in this state and has sat in `completed/` unnoticed ever since.

**Why structurally allowed:** the diagnosis was already written down — in the audit's own
warning text: *"T-2069 class (folded scalar 'description: >' terminated by blank line then
col-0 lines parsed as keys; quote the description string or move structured body out of
frontmatter)"*. The class was named, the mechanism was understood precisely enough to be
described in one sentence, and the mitigation offered was advice **to the author of the
description**. Nobody fixed the producer that generates the malformed block. This is the L-429
shape again (unbounded pages named as a recurring class while the check went unbuilt): a
learning recorded at the detector does not travel to the emitter on its own.

Second, the detector inherited the same blind spot as my census — `audit.sh:699` fires only on
the parse error, so the silent variant is out of its reach. A check written from the symptom
that was noticed can only ever find the symptom that was noticed.

**Prevention:**
1. `tests/unit/test_task_create_description_yaml.py` — drives the real script at all three
   sites and asserts **round-trip content**, not parseability. Mutation-checked: each of the
   three reversions kills exactly one test, disjointly. Asserting "it parses" would have
   passed against the pre-fix inception path, which parsed and lost two thirds of the value.
2. A standing corpus census in the same file, asserted on **both** predicates, so a future
   regression cannot hide in the silent half.
3. Follow-up filed for the audit detector, which still only sees the loud variant — the fix
   here stops this producer, but any other writer of task frontmatter has the same opening.

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

### 2026-08-03T21:30:27Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2778-fw-task-create-mangles-multi-line-descri.md
- **Context:** Initial task creation
