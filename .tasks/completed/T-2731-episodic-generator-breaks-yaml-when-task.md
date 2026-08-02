---
id: T-2731
name: "episodic generator breaks YAML when task name spans multiple lines (OBS-129)"
description: >
  episodic generator breaks YAML when task name spans multiple lines (OBS-129)

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [agents/context/lib/episodic.sh, lib/yaml.sh, tests/unit/episodic_frontmatter_extraction.bats]
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
created: 2026-08-02T09:16:25Z
last_update: 2026-08-02T09:41:27Z
date_finished: 2026-08-02T09:41:27Z
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
  - ts: '2026-08-02T09:30:06Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-02T09:30:09Z'
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

# T-2731: episodic generator breaks YAML when task name spans multiple lines (OBS-129)

## Context

`.context/episodic/T-100202.yaml` is unparseable: `task_name:` spans two lines.
Found by T-2729's corpus sweep (2 bad of 2427; the other was T-2729's own
defect), filed as OBS-129.

Two causes, only one of which raised. The task file has a body line beginning
`name:` at line 248, and the generator extracted with `grep "^name:"` over the
**whole file** — two matches, two lines, broken scalar. Independently, the same
grep kept only the first physical line, so the frontmatter's own multi-line
`name:` was already being truncated mid-sentence, silently, on every task.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] Both causes are addressed, not just the one that fired:
      (a) the frontmatter `name:` is a multi-line double-quoted scalar and the
      extractor keeps only its first physical line, truncating mid-sentence;
      (b) the extractor greps the **whole file**, so a body line beginning
      `name:` is captured too — T-100202 has one at line 248.
      Cause (b) is what produced two lines and broke the YAML; cause (a) was
      silently corrupting the value on its own.
- [x] `agents/context/lib/episodic.sh` stops rolling its own
      `grep "^field:" | sed …` extraction and uses the shared
      `lib/yaml.sh:get_yaml_field`, which exists precisely to "replace the
      inconsistent grep/sed/cut patterns duplicated across 30+ files".
      One extractor to harden, not thirty.
- [x] `get_yaml_field` is hardened to (i) read only the frontmatter block when
      the file begins with `---`, and (ii) return a single physical line for
      multi-line scalars.
- [x] The hardening's blast radius is **measured, not assumed**: old vs new
      extraction compared over every task file × every field the callers use,
      with every differing result listed. A silent behaviour change to a helper
      used by 30+ callers is not acceptable.
- [x] `.context/episodic/T-100202.yaml` regenerates and parses, and the corpus
      sweep from T-2729 goes to zero unparseable files with no name-based
      exclusion left in the test.
- [x] Guard + negative control: a test asserts episodic.sh contains no bare
      frontmatter grep, and the suite is shown to go red when the fix is
      reverted (L-533 — a sweep whose completeness is unrepresentable is what
      let T-2729 sit for eleven weeks).

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

python3 -c "import yaml; yaml.safe_load(open('.context/episodic/T-100202.yaml'))"
bats tests/unit/episodic_frontmatter_extraction.bats
bats tests/unit/context_episodic.bats
bats tests/unit/episodic_yaml_decision_escape.bats
bats tests/unit/episodic_yaml_timeline_escape.bats
bash -n lib/yaml.sh
bash -n agents/context/lib/episodic.sh

## Measurement

Old vs hardened `get_yaml_field`, over 2717 task files x 9 fields = 24462
comparisons, before the helper was changed:

| Field | Differing files | Read by a live caller? |
|-------|-----------------|------------------------|
| `id` | 0 | yes (resume, healing/suggest) |
| `status` | 0 | yes (resume, healing x2) |
| `owner` | 0 | yes (resume) |
| `workflow_type` | 0 | no |
| `created` | 0 | no |
| `last_update` | 0 | no |
| `tags` | 15 | no |
| `name` | 1041 | **yes** (resume, healing x3) |
| `description` | 2717 | no |

So the live behaviour change is exactly one field: `name`, in
`agents/resume/resume.sh` and the three `agents/healing/lib/*.sh` call sites,
which now print the whole task name instead of one truncated to its first
physical line. `description` moves from a bare `>` to the folded content, but no
current caller reads it through this helper.

## RCA

**Symptom:** `.context/episodic/T-100202.yaml` cannot be loaded —

```
expected '<document start>', but found '<block mapping start>'
```

The file is invisible to `fw recall` / `fw timeline`, and its header comment is
broken across lines too.

**Root cause:** `grep "^name:" "$task_file"` is not a frontmatter reader. It
matched a body line at T-100202:248 as well as the frontmatter key, so the shell
variable held two lines and `task_name: "$task_name"` emitted a scalar spanning
lines. The second, quieter defect in the same expression: it kept only the first
physical line of a value, so a wrapped `name:` was truncated and a folded
`description:` came back as the literal `>`.

**Why structurally allowed:** the shared helper `lib/yaml.sh:get_yaml_field`
exists and its own header says it is there to "replace the inconsistent
grep/sed/cut patterns duplicated across 30+ files" — and the episodic generator
never adopted it, keeping six bespoke greps. Nothing represented that gap: a
file that ignores a shared helper looks identical to one that has no need of it.
The helper itself had the truncation bug too, so adopting it would have fixed
only the crash and left the silent corruption.

Compounding: `episodic.sh` relied on its *caller* to have sourced the helper
chain. `context.sh` does, but `tests/unit/context_episodic.bats` sources the
module directly and does not — so the first adoption attempt left every field
empty, and only one downstream grep assertion noticed.

**Prevention:**
- **One extractor, hardened once.** `get_yaml_field` is now frontmatter-scoped
  and folds continuations. Both defects die at the single site rather than being
  patched per caller.
- **Blast radius measured before the change**, not asserted after — table above.
  Six of nine fields are provably byte-identical, and the one live behavioural
  change is named.
- **Guard, source-derived, no allowlist** (test 7): `episodic.sh` may contain no
  `grep "^field:" "$task_file"` extraction; test 8 appends one to a copy and
  requires the guard to catch it.
- **Dependency declared, not assumed** (test 9): the module sources
  `lib/yaml.sh` itself, and a test sources the module in isolation to prove it.
- **Corpus assertion with the exclusion removed** (test 10): T-2729's version of
  this check excluded T-100202 by name. That exclusion is gone — 2429 episodics,
  zero unparseable.

**Found and NOT folded in:** `tests/unit/update_task_episodic_gen.bats` tests 1
and 4 are red, and were red at HEAD before this task touched anything (verified
by reverting both files and re-running). Filed as **OBS-130** — same class as the
T-2696/T-2697 orphaned guard suite.

**Related:** L-533 (T-2729) — the enumerating-guard lesson, applied here from the
start rather than after a third visit.

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

### 2026-08-02T09:16:25Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2731-episodic-generator-breaks-yaml-when-task.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-dbb07d6b
- **Timestamp:** 2026-08-02T09:42:03Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-08-02T09:41:27Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
