---
id: T-2730
name: "reviewer crashes with re.error bad escape on task text containing backslash-x"
description: >
  reviewer crashes with re.error bad escape on task text containing backslash-x

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [lib/reviewer/drift.py, lib/reviewer/recommendation_claims.py, lib/reviewer/static_scan.py, tests/unit/reviewer_verdict_replacement_escape.bats]
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
created: 2026-08-02T09:07:13Z
last_update: 2026-08-02T09:16:00Z
date_finished: 2026-08-02T09:16:00Z
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
  - ts: '2026-08-02T09:15:06Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-02T09:15:10Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=0 
      (no-signal); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal);
      F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2730: reviewer crashes with re.error bad escape on task text containing backslash-x

## Context

`bin/fw reviewer T-XXXX` aborts with `re.error: bad escape \x` instead of
emitting a verdict, on tasks whose body contains a backslash escape — including
the ANSI-stripping idiom `sed 's/\x1b\[[0-9;]*m//g'` that CLAUDE.md itself tells
authors to write.

Filed as OBS-128 during T-2728 and confirmed pre-existing there (reproduced
against `git show b1388a442~1:lib/reviewer/static_scan.py`), so it is not a
regression from the toothless-http detector.

Same escape family as T-2729, opposite direction: T-2729 wrote data into a
context that interprets escapes (a double-quoted YAML scalar); this one passes
data into a context that interprets escapes (an `re.sub` replacement template).

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] The crash is **located**, not guessed: the exact call site that raises
      `re.error: bad escape \x` is named with file:line, and the mechanism is
      stated (a task-derived string reaching a position where Python parses
      backslash escapes — a regex pattern or an `re.sub` replacement template).
- [x] A reproduction exists that fails before the fix and passes after, driving
      the **real** `bin/fw reviewer` (or the real function) against a task
      containing the framework's own documented ANSI idiom `sed 's/\x1b\[…'`.
      Not a re-typed excerpt of the offending expression.
- [x] The fix removes the escape interpretation rather than sanitising the input:
      task text is data, so it must reach `re` via `re.escape` (pattern position)
      or a callable / literal replacement (replacement position), never as a
      template. Stripping backslashes out of the task text is **not** acceptable —
      it would corrupt the very idiom CLAUDE.md tells authors to write.
- [x] The whole reviewer package is swept for sibling sites where task-derived
      text reaches `re` in an escape-interpreting position; each is converted or
      recorded as safe with the reason. (L-533: a sweep by inspection whose
      completeness is unrepresentable is what let T-2729 sit for eleven weeks.)
- [x] `bin/fw reviewer` returns a verdict for every task that currently crashes it
      — enumerated by scanning all tasks, so the population is measured, not
      assumed.

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
# stdin on. `echo "$out"` is small and immediate; grep scans the whole captured
# string anyway, so the tail-3 was cosmetic. Drop it: `echo "$out" | grep -q PAT`.
#
# Enforcement-baseline hint (L-398, T-1886): if you edited `.claude/settings.json`
# (added/removed/reorganised hooks), add `bin/fw enforcement baseline` to your
# Verification block. Otherwise the canonical hash diverges and `fw doctor`
# reports a FAIL ("Enforcement baseline CHANGED") that accumulates silently.
# Origin: T-1849/T-1730/T-1731 each added a legitimate hook without refreshing
# the baseline — FAIL sat for multiple sessions until T-1886 cleaned up.

bats tests/unit/reviewer_verdict_replacement_escape.bats
bats tests/unit/reviewer_toothless_http.bats
python3 -c "import ast,sys; ast.parse(open('lib/reviewer/static_scan.py').read())"
python3 -c "import ast,sys; ast.parse(open('lib/reviewer/drift.py').read())"
python3 -c "import ast,sys; ast.parse(open('lib/reviewer/recommendation_claims.py').read())"

## Sweep

Every `.sub()` in `lib/reviewer/`, by replacement-argument kind:

| Site | Replacement | Disposition |
|------|-------------|-------------|
| `static_scan.py:2761` | `new_section` (rendered verdict) | **CONVERTED** — the crash site |
| `recommendation_claims.py:282` | `new_section` (rendered claims verdict) | **CONVERTED** — same shape, same exposure, not yet witnessed |
| `drift.py:185` | `marker` (JSON of `{path: hash}`) | **CONVERTED** — `json.dumps` emits `\\` and `\uXXXX`; `\u` is not a valid template escape |
| `drift.py:192` | `rf"\1{marker}\n"` | **CONVERTED** — `\1` is a real backreference, so the group lookup moved into the callable and `marker` stopped riding inside a template |
| `static_scan.py:232` | `""` literal | safe: constant |
| `static_scan.py:437` | `""` literal | safe: constant |
| `static_scan.py:725` | `lambda m: …` | safe: already a callable |
| `static_scan.py:762` | `""` literal | safe: constant |
| `static_scan.py:2382` | `""` literal | safe: constant |

`lib/resolver.py:291` (`VAR_PAT.sub(repl, template)`) passes a **callable** and is
outside the reviewer package; noted, not touched.

## RCA

**Symptom:** `bin/fw reviewer T-XXXX` aborted with a traceback instead of a
verdict:

```
File "lib/reviewer/static_scan.py", line 2761, in write_verdict_to_task
    new_text = _VERDICT_SECTION_RE.sub(new_section, text)
re.error: bad escape \x at position 386 (line 13, column 99)
```

No verdict written, non-zero exit, and any Verification block containing
`bin/fw reviewer T-XXXX` fails for a reason unrelated to the task's quality.

**Root cause:** `re.sub(repl, string)` parses `repl` as a *template* — `\1`
splices a capture group, `\n` becomes a newline, and an unrecognised escape like
`\x`, `\s` or `\d` raises. The reviewer passed its rendered verdict directly as
`repl`, and the verdict quotes evidence lines out of the task body. So every
backslash an author wrote in a Verification command was re-interpreted by the
regex engine at write time. The verdict is data; it was being used as code.

**Why structurally allowed:**

1. *The hazard is in the argument's role, not its content.* `PAT.sub(x, y)` and
   `re.sub(p, x, y)` put the replacement in different positions, and neither
   reads as "this string will be parsed". Nothing in the call site distinguishes
   a template from data, so the author sees a string substitution and gets an
   escape interpreter.
2. *The framework instructs authors to write the trigger.* CLAUDE.md's own
   guidance for stripping ANSI from captured output is
   `sed 's/\x1b\[[0-9;]*m//g'`. Following the documented idiom is what broke the
   reviewer — so the tasks most likely to crash it were the well-formed ones. The
   measured population confirms this: of 7 crashing tasks, 4 carry `\x1b` and 3
   carry `\s`/`\d` from regex idioms.
3. *It only fires on the second scan.* A task with no `## Reviewer Verdict`
   section takes the append branch, which is plain concatenation and cannot
   crash. The `.sub()` branch is reached only once a verdict already exists — so
   the failure looked intermittent and task-specific rather than structural.

**Prevention:**

- **All four sites converted to callable replacements** — a callable's return
  value is never parsed, so this is a property of the call, not of the input. No
  sanitising of task text: stripping backslashes would corrupt the very idiom
  CLAUDE.md tells authors to use.
- **AST guard, source-derived, no allowlist** (`reviewer_verdict_replacement_escape.bats`
  test 4): every `.sub()` in `lib/reviewer/` must take a `lambda` or a literal
  string constant as its replacement, with the argument index chosen by whether
  the call is `re.sub(...)` or a compiled pattern's `.sub(...)`. A `Name`, an
  f-string or a call result fails. Controlled by test 5, which builds a
  regressed module in a temp dir and requires the guard to catch it.
- **End-to-end regression** (tests 1-3): drives the real `bin/fw reviewer`
  against a fixture task carrying the documented `\x1b` idiom, asserts the file
  was actually rewritten (Scan ID present) *and* the idiom survived unchanged.
  Test 3 renders the real verdict and applies the pre-fix shape, which must
  raise — so if the fixture ever stops being hostile the suite says so.
- **Population named, not counted** (test 6): the 7 tasks measured at fix time
  are listed by id, so a regression reports which one broke. Tasks that have
  since been archived are reported as informational rather than skipped silently.

**Measurement:** 2717 task files scanned; 486 contain a backslash; 478 of those
already have a verdict section; **7 crashed**. Latent second-run exposure among
the remaining 8: **0**. Not an estimate — the real scanner and renderer were run
over every candidate.

**Related:** T-2729 / L-533 (the sibling-sweep lesson applied here from the
start — the sweep table above enumerates every `.sub()` rather than the ones that
crashed).

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

### 2026-08-02T09:07:13Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2730-reviewer-crashes-with-reerror-bad-escape.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-dd5ce047
- **Timestamp:** 2026-08-02T09:16:05Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-08-02T09:16:00Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
