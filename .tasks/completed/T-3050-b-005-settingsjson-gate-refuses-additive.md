---
id: T-3050
name: "B-005 settings.json gate refuses additive PreToolUse matchers because it never
  reads the diff"
description: >
  From T-3047 triage M-14 (ring20-management, 2026-05-21). agents/context/check-active-task.sh:331-349
  blocks every write to .claude/settings.json on a bare path match, before any content
  is read, so ADD-NEW-MATCHER and MODIFY-EXISTING-MATCHER are indistinguishable. A
  consumer cannot add a purely additive project-local hook without an operator paste-in.

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: [upstream-pickup, T-3047-triage]
components: [agents/context/check-active-task.sh, tests/unit/t3050_b005_block_message.bats]
related_tasks: [T-3047]
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
created: 2026-08-16T22:30:03Z
last_update: 2026-08-17T06:36:29Z
date_finished: 2026-08-17T06:36:29Z
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
  - ts: '2026-08-16T22:45:05Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-16T22:45:08Z'
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

# T-3050: B-005 settings.json gate refuses additive PreToolUse matchers because it never reads the diff

## Context

**The filed premise is false, and the fix it implies is unsafe. Both matter, so
both are recorded here rather than quietly reinterpreted.**

Filed claim: *"A consumer cannot add a purely additive project-local hook without
an operator paste-in"*, with the proposed fix being to make the B-005 gate
diff-aware so ADD-NEW-MATCHER passes while MODIFY-EXISTING is still refused.

**1. The capability already exists.** `fw hook-enable`
(`bin/fw:8116` → `bin/hook-enable.sh`, shipped 2026-04-22 under T-1189) registers
a hook into `.claude/settings.json` idempotently and atomically, validates the
event name, and has a `--script <abs-path>` mode built specifically for
project-local hook scripts living outside the framework tree
(`bin/hook-enable.sh:29,37`). Additions survive later regeneration via
`lib/settings_merge.py` (`lib/init.sh:1153-1167`). No operator paste-in is
required, and none has been required for four months.

**2. Diff-awareness would not be safe even if the capability were missing.** A
matcher entry carries `{"type": "command", "command": "<arbitrary shell>"}`. An
"additive" edit therefore adds arbitrary code that runs automatically before
every matching tool call, with the agent's own privileges — and that command can
rewrite `settings.json` to delete the other matchers, or delete the gate scripts.
*Additive* describes the declarative shape; the effect is unbounded. A gate that
permits ADD-NEW-MATCHER is one hop from permitting REMOVE-ALL-MATCHERS, which is
precisely what B-005 exists to prevent. So the relaxation is not implemented here
and should not be implemented later without an explicit operator decision.

**3. What the actual defect is.** The block message
(`agents/context/check-active-task.sh:339-345`) is a dead end. It refuses, states
"Changes to hook configuration require human review", and then names no
mechanism: no command, no proposal path, no bypass. An agent that hits it has
nowhere to go but the operator, which is exactly the paste-in the filing
complains about. The wall is real; the missing capability is not. This is a
discoverability failure with a measured cost — a consumer project filed it as a
missing feature.

**4. And the message's claim is not true.** "Requires human review" is false for
the very case the message is refusing: `fw hook-enable` is a Bash command, and
the B-005 gate matches on `tool_input.file_path` for Write/Edit only
(`:334-337`), so it never sees it. Two other paths also write the gated file
without B-005 involvement — `fw hook-enable` itself, and editing the
`generate_claude_code_config` heredoc (`lib/init.sh:928-1149`) followed by
`fw upgrade` (`lib/upgrade.sh:1645`). B-005 is a speed bump against incidental
Write/Edit modification, not a boundary. That is a defensible scope — it is the
same boundary CLAUDE.md already documents for Tier 0, where a command that
becomes a file stops being seen — but a control that *describes itself* as
stronger than it is, is worse than one known to be weak, because it gets trusted
past its reach. The message should say what the gate actually covers.

Scope: fix the message (3 and 4). Do not loosen the gate (2). Record the scope
asymmetry so it is known rather than assumed (4).

## Acceptance Criteria

### Agent
- [x] **A1 — the refusal names the way forward.** The B-005 block message names
      `fw hook-enable` and carries a copy-pasteable single-line example including
      the `cd` prefix and the framework-repo-vs-consumer `fw` path rule
      (§Copy-Pasteable Commands), so an agent that trips the gate can register an
      additive hook without routing through the operator.
- [x] **A2 — the message stops overclaiming.** It no longer asserts that hook
      changes require human review without qualification. It states what B-005
      actually covers (Write/Edit on `.claude/settings.json`) and that the
      governed CLI path is the sanctioned route, so nobody reads the gate as a
      boundary it is not.
- [x] **A3 — the gate itself is unchanged in behaviour.** Write/Edit on
      `.claude/settings.json` still exits 2. No diff-reading, no allow-list, no
      new bypass env var. A test pins the exit code alongside the new message, so
      a future "make it helpful" edit cannot soften the refusal.
- [x] **A4 — the message content is pinned by test, not by hope.** Tests assert
      the block names `fw hook-enable`; a mutation removing that mention turns
      them red, with a positive control (L-616) proving the harness can still
      distinguish pass from fail.
- [x] **A5 — the scope asymmetry is registered, not just described here.** The
      two non-B-005 write paths (`fw hook-enable`; `lib/init.sh` heredoc +
      `fw upgrade`) are recorded in the concerns register or as an observation,
      so the gate's reach is documented where someone assessing enforcement
      coverage will actually look.

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
# ── Pipefail/SIGPIPE: grepping a command's output (L-387, T-2090, T-2743, T-2738) ──
#
# THE DEFAULT — redirect to a file, then grep the file:
#     cmd > /tmp/.out 2>&1 && grep -q "PATTERN" /tmp/.out
#     curl -sf "$(bin/fw watchtower url)/page" -o /tmp/.out && grep -q "PAT" /tmp/.out
# Correct at any output size, and `&&` keeps the PRODUCING command's exit code in
# the verdict. Reach for this first; the alternative below is the special case.
#
# Why not `cmd | grep -q PAT` (L-387): P-011 runs each line under `set -eo
# pipefail`. When grep matches it exits and closes stdin while cmd is still
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
# REHEARSING A LINE BY HAND DOES NOT REHEARSE THE GATE (T-2743). Your interactive
# shell has no `set -eo pipefail`. A line has returned 0 by hand and 141 under
# P-011, from the same directory, the same second. To rehearse for real:
#     bash -c 'set -eo pipefail; <your verification line>'
#
# Enforcement-baseline hint (L-398, T-1886): if you edited `.claude/settings.json`
# (added/removed/reorganised hooks), add `bin/fw enforcement baseline` to your
# Verification block. Otherwise the canonical hash diverges and `fw doctor`
# reports a FAIL ("Enforcement baseline CHANGED") that accumulates silently.
# Origin: T-1849/T-1730/T-1731 each added a legitimate hook without refreshing
# the baseline — FAIL sat for multiple sessions until T-1886 cleaned up.
#
# NOTE: this task edits agents/context/check-active-task.sh, which IS a hook
# script — but it does not touch .claude/settings.json, so the enforcement
# baseline (which hashes the `hooks` block) is unchanged. No `fw enforcement
# baseline` needed; confirmed by fw doctor showing no "baseline CHANGED".

out=$(bats tests/unit/t3050_b005_block_message.bats 2>&1); echo "$out" | grep -q "^ok 12 " && ! echo "$out" | grep -q "^not ok"
out=$(bats tests/integration/check_active_task.bats 2>&1); echo "$out" | grep -q "^ok 1 " && ! echo "$out" | grep -q "^not ok"
rc=0; echo "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$PWD/.claude/settings.json\"}}" | PROJECT_ROOT="$PWD" bash agents/context/check-active-task.sh > /tmp/.t3050v.out 2>&1 || rc=$?; [ "$rc" -eq 2 ] && grep -q "hook-enable" /tmp/.t3050v.out && ! grep -q "require human review" /tmp/.t3050v.out
bin/fw hook-enable --name check-active-task --event PreToolUse --matcher "Write|Edit" --dry-run > /tmp/.t3050hd.out 2>&1 && grep -q "PreToolUse" /tmp/.t3050hd.out

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

**Symptom:** a consumer project reported that it could not add a project-local
PreToolUse hook without the operator hand-pasting JSON into
`.claude/settings.json`, and filed it as the B-005 gate being too coarse.

**Root cause:** not coarseness — **discoverability**. `fw hook-enable` has done
exactly this job since T-1189 (2026-04-22), including a `--script` mode built for
project-local hooks outside the framework tree. The gate's refusal never
mentioned it. It said "Changes to hook configuration require human review" and
stopped, so the only move it left an agent was to escalate. **A gate with no exit
is a gate people route around**, and the reported cost is the routing-around.

**Why structurally allowed:** three things, in order of how much they matter.

1. **A block message is a UI, and nothing treats it as one.** It is the entire
   interface between a refusal and whoever hit it, yet nothing verified it was
   actionable. Hooks are tested for verdict — does it exit 2 — and a wrong
   verdict is loud. An unhelpful *message* still exits 2, so it is invisible to
   every test and to the author, who already knows the answer the message
   omits. B-005 shipped in T-229 and no test ever read its text.
2. **The message's claim was false, in the direction that suppresses questions.**
   "Requires human review" is untrue for the case it refuses: `fw hook-enable`
   is a Bash command, and B-005 matches `tool_input.file_path` on Write/Edit, so
   it never sees it. Anyone who believed the message stopped looking — the claim
   was load-bearing for the conclusion "there is no way to do this", and that
   conclusion is what got filed as a bug.
3. **The fix the report proposed would have been an escalation path.** "Read the
   diff and allow additive matchers" sounds conservative, and is not: a matcher
   carries `{"type":"command","command":"<arbitrary shell>"}`, so an addition
   introduces code that runs before every matching tool call and can delete the
   other matchers. Additive is a property of the JSON shape, not of the effect.
   Had the premise in (1) not been checked, the plausible fix was to weaken the
   control the report was really complaining about.

The class: **a control's message is part of the control.** When it under-informs,
people work around it; when it over-claims, they trust it past its reach. B-005
did both at once — it hid the sanctioned route AND described itself as human
review it does not perform.

**Prevention** (distinct from the fix):

- The message now names `fw hook-enable` with copy-pasteable lines for both the
  framework-repo and consumer `fw` paths, and 12 tests read the text — so the
  message is now pinned like behaviour, not left as prose nobody asserts on.
- Tests assert both directions simultaneously: still exits 2, AND names the
  route. The failure mode of "make the gate helpful" is making it optional, so
  one test greps the block for any `FW_*SKIP/ALLOW/BYPASS` identifier and fails
  if a bypass was smuggled in beside the friendlier wording.
- The mutation (redacting `hook-enable`) has a positive control per L-616,
  because a mutant that failed to run would print no `hook-enable` either.
- OBS-315 registers B-005's real reach — Write/Edit only; `fw hook-enable` and
  `lib/init.sh:928-1149` + `fw upgrade` both write the gated file without it —
  so the next enforcement-coverage assessment reads the boundary instead of
  inferring it from the policy name.

**Deliberately not done:** the gate was not made diff-aware and ADD-NEW-MATCHER
is still refused, for the reason in (3). If that relaxation is still wanted it
needs an operator go/no-go on the direction, not a build task that assumes the
answer — the ACs here would have been written to implement a privilege
escalation.

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

### 2026-08-16T22:30:03Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3050-b-005-settingsjson-gate-refuses-additive.md
- **Context:** Initial task creation

### 2026-08-17T06:26:35Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-5769a815
- **Timestamp:** 2026-08-17T06:36:43Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-08-17T06:36:29Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
