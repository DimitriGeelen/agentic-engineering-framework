---
id: T-2729
name: "episodic generator emits invalid YAML when a commit subject contains a backslash"
description: >
  episodic generator emits invalid YAML when a commit subject contains a backslash

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
created: 2026-08-02T08:51:34Z
last_update: '2026-08-02T09:00:11Z'
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
  - ts: '2026-08-02T09:00:06Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-02T09:00:11Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 1
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 1
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=1 
      (body:episodic-only); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=1 (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
---

# T-2729: episodic generator emits invalid YAML when a commit subject contains a backslash

## Context

Closing T-2728 emitted `.context/episodic/T-2728.yaml` that PyYAML refuses to parse.
The offending row is a mined git subject containing `\x`:

```
action: "T-2728: ... (reviewer crashes on \x in task text, pre-existing)"
```

`agents/context/lib/episodic.sh:370` escapes only the double quote
(`sed 's/"/\\"/g'`) before writing into a **double-quoted** YAML scalar, where
backslash is the escape introducer. `\x` is an invalid escape (hard error); `\n`,
`\t` would parse but silently mean something other than the literal text.

Third instance of this class in this same file (L-005 T-1236 regex-in-episodic,
L-392 T-1873 unescaped emission), so per the escalation ladder the fix must be
structural, not another field-specific patch.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] The git-timeline `action:` row is emitted as a **single-quoted** YAML scalar
      (`''` doubling, no escape sequences at all) — the same idiom already used by
      the artifacts block twelve lines above at `episodic.sh:352`.
- [x] Regression test: an episodic generated from a commit subject containing
      `\x`, `\n`, a double quote and a single quote parses under `yaml.safe_load`
      **and** round-trips the subject byte-for-byte (not merely "parses").
      → `tests/unit/episodic_yaml_timeline_escape.bats` tests 1-2. The expectation
      is read from `git log` itself, never a re-typed literal.
- [x] Negative control: the test fails against the pre-fix emitter, proving it has
      teeth rather than passing because the fixture never reached the writer.
      → Two controls, both exercised: (a) test 3 rewrites the emitted row back into
      the pre-fix double-quoted shape and requires PyYAML to reject it — if the
      fixture ever loses its teeth this goes green and says so; (b) the fix was
      reverted in place and the suite re-run: tests 3 and 4 went red, naming
      `episodic.sh:380-381` as the offending lines, then restored byte-clean.
      An earlier attempt at a symlink-farm framework root was **discarded** — it
      silently resolved back to the real framework and reported the fixed output,
      i.e. it measured the wrong object (same trap as T-2726).
- [x] The whole file is swept for other free-text-into-double-quoted-scalar sites;
      each is either converted or recorded as safe-by-construction with the reason.
      → See `## Sweep` below. One converted; four recorded safe with reasons; one
      unrelated defect found and filed as OBS-129 rather than folded in.
- [x] `.context/episodic/T-2728.yaml` (the corrupt artifact that surfaced this) is
      regenerated and parses — 3 timeline rows, the `\x` row carrying the literal
      two characters.
- [x] Every existing episodic under `.context/episodic/` parses — establishing
      whether the blast radius is one file or many. → 2427 scanned, blast radius
      for **this** defect is exactly 1 (T-2728). The sweep also surfaced T-100202,
      a different generator defect, now OBS-129.
- [x] The guard is source-derived with no maintained allowlist, and is itself
      controlled: test 4 asserts no interpolated double-quoted scalar exists in the
      writer; test 5 appends one to a **copy** and requires the guard to catch it.

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

bats tests/unit/episodic_yaml_timeline_escape.bats
bats tests/unit/episodic_yaml_decision_escape.bats
bats tests/unit/context_episodic.bats
python3 -c "import yaml; yaml.safe_load(open('.context/episodic/T-2728.yaml'))"
bash -n agents/context/lib/episodic.sh

## Sweep

Every site in `agents/context/lib/episodic.sh` that writes an interpolated value
into the episodic, and its disposition:

| Line | Emission | Quoting | Disposition |
|------|----------|---------|-------------|
| 291 | `- '$text'` (outcomes) | single | already correct (T-1873) |
| 307 | `description: '$escaped'` (challenges) | single | already correct (T-1873) |
| 328-337 | decisions topic/chose/rationale/rejected | single | already correct (T-1871) |
| 353 | `- '$escaped'` (artifacts) | single | already correct (T-1873) |
| 380-381 | `time:` / `action:` (git timeline) | **double** | **CONVERTED — this task** |
| 393-394 | `description:` / `why:` (successes) | double | safe: literal `[TODO: …]`, no interpolation |
| 277 | `summary: \|` block scalar | block | safe: block scalars process no escapes, and `summary_text` is single-line by construction — the git path joins with `awk` (`:221`), the fallback is a single `grep` line (`:87`) |
| 265, 268 | `first_commit:` / `last_commit:` | bare | safe: git hashes, `[0-9a-f]` only |
| 400 | `tags: [$tags]` | flow | safe: copied verbatim out of the task's own already-valid `tags:` flow sequence with the brackets stripped and re-added (`:86`) |
| 409 | `source_file: $task_file` | bare | safe: framework-generated repo path, slugified, no `": "` |

Not in this writer but found by the corpus sweep and filed rather than folded in:
**OBS-129** — `T-100202.yaml` breaks because `$task_name` captured *multiple*
lines (`grep "^name:"` matched a continuation line). Unbounded multi-line capture
into a single-line scalar; distinct mechanism, distinct fix.

## RCA

**Symptom:** `fw task update T-2728 --status work-completed` closed the task but
its final step failed with

```
yaml.scanner.ScannerError: while scanning a double-quoted scalar
  expected escape sequence of 2 hexadecimal numbers, but found ' '
```

`.context/episodic/T-2728.yaml` was written to disk and is unreadable — invisible
to `fw recall`, `fw timeline` and every downstream episodic consumer.

**Root cause:** `episodic.sh:370` escaped only the double quote
(`sed 's/"/\\"/g'`) before writing a mined commit subject into a **double-quoted**
YAML scalar. In a double-quoted scalar the backslash is the escape introducer, so
`"` was never the dangerous character — the backslash was. The subject contained
`\x` (from a commit about the reviewer crashing on `\x`), which is an invalid
escape and a hard parser error. `\n` or `\t` would have been worse: they parse,
and silently mean something other than the literal text.

**Why structurally allowed:** two compounding gaps.

1. *The sibling sweep stopped one block short.* L-392 named this exact class in
   this exact file. T-1871 converted the decisions emitter; T-1873 converted
   outcomes, challenges and artifacts. The git-timeline emitter sits twenty lines
   below artifacts and was not converted. Nothing enumerated the sites, so
   "converted the ones we found" and "converted all of them" were
   indistinguishable — for eleven weeks.
2. *The regression test could not see an unknown site.* The behavioural half of
   `episodic_yaml_decision_escape.bats` re-types the writer's sed chain into a
   local `_emit_and_parse` helper rather than running the writer. A test that
   reimplements the producer can only ever check the sites its author already knew
   about; it was green throughout T-2728's corruption because the corrupt bytes
   never passed through it. This is the producer/consumer join class of L-399 with
   the *test* as the divergent consumer.

**Prevention:** structural, per the escalation ladder — this is the third instance
(L-005, L-392, now T-2729), so another field-specific patch would have been the
same move a third time.

- **Guard, source-derived, no allowlist:** the writer must contain no line matching
  `:\s*\"\$` — an interpolated value inside a double-quoted YAML scalar. The
  predicate is a property of the shape, not a list of known fields, so a *sixth*
  site fails the moment it is written. Test 4; controlled by test 5, which appends
  such a line to a copy and requires the guard to catch it.
- **End-to-end regression:** tests 1-3 drive the real `fw context
  generate-episodic` against a fixture repo whose commit subject carries `\x`,
  `\n`, `"` and `'`, and compare the parsed value against `git log` output rather
  than a re-typed expectation. Nothing about the emitter is reimplemented in the
  test.
- **Corpus assertion:** test 6 parses every episodic in `.context/episodic/`, so
  the next corruption of any mechanism surfaces at test time rather than at some
  future `fw recall`. OBS-129 is excluded **by name**, so the exclusion is visible
  rather than silent.

**Related:** L-005 (T-1236), L-385 (T-1861), L-392 (T-1873) — same class, three
prior visits.

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

### 2026-08-02T08:51:34Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2729-episodic-generator-emits-invalid-yaml-wh.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-10267477
- **Timestamp:** 2026-08-02T09:01:25Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
