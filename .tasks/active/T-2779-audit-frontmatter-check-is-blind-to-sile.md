---
id: T-2779
name: "audit frontmatter check is blind to silently-truncated descriptions"
description: >
  audit.sh:699 flags task frontmatter only when yaml.safe_load raises. That catches
  one of the two ways a folded-scalar break manifests.

  The other way: a continuation paragraph containing "word: word" parses as a junk
  top-level key and silently truncates the description. Valid YAML, no warning. T-2778
  found 4 such files against 1 loud one, so the detector sees roughly 20 percent of
  its own class.

  Widen the check to flag prose-shaped frontmatter keys (containing whitespace, or
  absent from the known schema). T-2778 fixed the create-task.sh producer; any other
  writer of task frontmatter still has the same opening.

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
created: 2026-08-03T21:55:27Z
last_update: '2026-08-03T22:00:14Z'
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
  - ts: '2026-08-03T22:00:08Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-03T22:00:14Z'
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

# T-2779: audit frontmatter check is blind to silently-truncated descriptions

## Context

Follow-up to T-2778, which fixed the producer. This closes the detector half: the audit's
frontmatter check only ever saw the variant that raises, so it reported ~20% of its own class.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] Baseline recorded BEFORE the change: a fixture task carrying a silently-truncated
      description (prose-shaped frontmatter key, valid YAML) passes the current check
      unflagged. If the current check already catches it, the premise is wrong — re-scope.
      → Ran the real `web.shared.parse_frontmatter` over the fixture: returned a 10-key dict
      including junk key `'Second paragraph'`, so the classifier assigned **rc=0** — the
      "everything is fine" code. Blind confirmed by execution, not by reading.
- [x] `agents/audit/audit.sh` flags the silent variant, and reports it as a *distinct* class
      from the unparseable one. Two different repairs are needed (silent = content already
      lost and must be reconstructed; loud = file simply won't parse), so one merged count
      would hide which repair applies.
      → New rc=4 branch, own counter, own WARN naming the two-space re-indent repair.
- [x] Predicate is whitespace-in-key, NOT unknown-key. The frontmatter schema is openly
      extensible by design (audit treats unknown fields as silent additions, A2) — an
      unknown-key predicate would flag `bvp_scores_proposed` and every future field.
      → Pinned by `test_extensible_schema_fields_are_not_flagged`, parametrized over the two
      estimator-written fields that already exist.
- [x] Zero false positives across the full corpus: the check reports 0 on all 2,765 current
      task files, whose count is stated in the run rather than assumed.
      → `bin/fw audit --section structure` emits no frontmatter WARN over the live corpus.
- [x] Fixture test pins BOTH variants and is mutation-checked — reverting the check turns it
      red. A test that only exercises the loud variant would pass against today's blind code.
      → 6 passed. Disabling the rc=4 predicate fails exactly the two silent-variant tests;
      the loud and false-positive tests stay green, which is the correct blast radius.

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

bash -n agents/audit/audit.sh
python3 -m pytest tests/unit/test_audit_frontmatter_variants.py -q > /tmp/.t2779-pytest.out 2>&1 && grep -q "6 passed" /tmp/.t2779-pytest.out
# The silent-variant branch and its distinct warning must both be present.
grep -q "rc = 4" agents/audit/audit.sh
grep -q "description content parsed as frontmatter keys" agents/audit/audit.sh
# Predicate must stay whitespace-in-key, not unknown-key (schema is extensible by design).
grep -q "' ' in str(k) or" agents/audit/audit.sh
# T-2778's producer fix must remain in place — this check exists because that class recurs.
python3 -m pytest tests/unit/test_task_create_description_yaml.py -q > /tmp/.t2779-prod.out 2>&1 && grep -q "5 passed" /tmp/.t2779-prod.out

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

**Symptom:** the audit's task-frontmatter check reported 1 corrupted file while 5 were
corrupted. Not a miscount — the other 4 are outside what the check can express.

**Root cause:** the classifier assigns rc by asking "did parsing raise?" (rc=2/3) or not
(rc=0). A folded-scalar break whose orphaned paragraph contains `word: word` produces a
*valid* document — junk top-level key, `description` truncated to its first line — so it
scores rc=0, the same code as a healthy file. Confirmed by running the real
`web.shared.parse_frontmatter` over a fixture: 10-key dict including `'Second paragraph'`,
rc=0.

**Why structurally allowed:** the check was written from the instance that announced itself.
The note at `audit.sh:640` records *"T-2069 … 1 corpus victim (T-1845)"* — and T-2778's census,
run on the same loud predicate, also returned exactly 1. Two independent investigations, years
apart, both landed on 1, because both inherited the predicate rather than the phenomenon. The
number was never measuring the defect; it was measuring the check's reach, and it looked like
a defect rate because nothing distinguished them.

This is the general hazard with a detector built from a symptom: **it is bounded by the
failure mode that happened to be noticeable, and its output cannot reveal that bound.** A low
count reads as good news whether the population is small or the predicate is narrow. The two
are indistinguishable from inside the check — which is why the corrected census (5, on a
predicate derived from the *mechanism* rather than the symptom) had to come from re-deriving
what a folded-scalar break can do, not from re-running the existing check more carefully.

**Prevention:**
1. rc=4 branch with its own counter and its own WARN — the two classes need different repairs
   (re-indent recovers content that is still in the file; the loud class simply won't parse),
   so they are reported separately rather than summed.
2. `tests/unit/test_audit_frontmatter_variants.py` — 6 tests over the real `audit.sh` at a
   scratch PROJECT_ROOT, covering both variants, a correctly-indented multi-paragraph control,
   and the extensible-schema fields. Mutation-checked: disabling the predicate fails exactly
   the two silent-variant tests.
3. The predicate is whitespace-in-key, deliberately not unknown-key — the schema is open by
   design (A2), so an unknown-key check would drift into flagging every field added later and
   would end up measuring the schema's age instead of its integrity.

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

### 2026-08-03T21:55:27Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2779-audit-frontmatter-check-is-blind-to-sile.md
- **Context:** Initial task creation
