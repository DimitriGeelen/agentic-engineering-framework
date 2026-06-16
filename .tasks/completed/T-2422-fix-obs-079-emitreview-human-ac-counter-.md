---
id: T-2422
name: "fix OBS-079 emit_review human-AC counter false-enters on title containing ### Human"
description: >
  fix OBS-079 emit_review human-AC counter false-enters on title containing ### Human

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
created: 2026-06-16T14:39:49Z
last_update: 2026-06-16T14:39:49Z
date_finished: null
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
---

# T-2422: fix OBS-079 emit_review human-AC counter false-enters on title containing ### Human

## Context

OBS-079: `lib/review.sh:emit_review` counts Human ACs by walking the task file
looking for `### Human`, but the match (`echo "$line" | grep -q '### Human'`)
hits the literal string anywhere — including the YAML frontmatter `name:` and
`description:` fields. Tasks whose title literally references the heading
(T-2420's name field contains `### Human outside ## Acceptance Criteria`) flip
`in_human=true` while still in the frontmatter, then `break` at the very first
`^## ` heading (`## Context`), so the counter never reaches the real ACs and
the partial-complete render shows `Human ACs: 0/0`. Fix anchors the counter
on `^## Acceptance Criteria` and matches `^### Human` start-of-line.

## Acceptance Criteria

### Agent
- [x] `lib/review.sh` AC counter only enters human-mode after `^## Acceptance Criteria` AND a `^### Human` heading appears within that AC block
- [x] `### Human` substring elsewhere (frontmatter `name:`/`description:`, body prose) does NOT flip the counter
- [x] Existing T-2421 bats suite (`tests/unit/recommendation_gate_build_partial.bats`) still passes 10/10 (no regression of T-2419 GO build-leg gate)
- [x] New bats fixture `tests/unit/emit_review_ac_counter.bats` pins the OBS-079 class: a task with `### Human` in its `name:` field renders `human_total > 0` only when there's a real Human AC, `0` otherwise (6/6 PASS)

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

bash -n lib/review.sh
bats tests/unit/emit_review_ac_counter.bats
bats tests/unit/recommendation_gate_build_partial.bats

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

## RCA

**Symptom:** Watchtower `/review/T-2420` rendered `Human ACs: 0/0 checked` despite the task having a real `- [ ] [REVIEW]` Human AC under the `### Human` heading inside `## Acceptance Criteria`. Same class affects any task whose `name:`/`description:` text contains the literal string `### Human`.

**Root cause:** `lib/review.sh:122-136` counter loop:
```
in_human=false
while IFS= read -r line; do
    if echo "$line" | grep -q '### Human'; then in_human=true; continue; fi
    if $in_human && echo "$line" | grep -qE '^### |^## '; then break; fi
    if $in_human && echo "$line" | grep -qE '^\- \[[ xX]\]'; then ... fi
done
```
The first `grep -q '### Human'` has neither line-start anchor nor a check that we're inside the AC block. Frontmatter line `name: "PreToolUse hook: detect ### Human outside ## Acceptance Criteria"` matches → `in_human=true` while still on frontmatter line 3. The next `^## ` heading (`## Context`, line ~42) trips the `break`. The loop exits before reaching `## Acceptance Criteria → ### Human → - [ ] [REVIEW] ...`, so `human_total=0`.

**Why structurally allowed:** the counter was written when no task title ever contained `### Human`. The fix is anchoring discipline (`^## Acceptance Criteria` first, then `^### Human` start-of-line within the AC block) — the same discipline `agents/task-create/update-task.sh` uses via `sed -n '/^## Acceptance Criteria/,/^## /p'`. The two parsers diverged.

**Prevention:** the new bats fixture `emit_review_ac_counter.bats` pins the OBS-079 class — a task whose name field contains `### Human` must render `human_total=0` (when no real Human AC) and `human_total=N` (when N real Human ACs exist). Regression-guarded.

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
**Rationale:** Scoped CLI-only bug; fix anchors `lib/review.sh:emit_review` on `^## Acceptance Criteria` and `^### Human` start-of-line (parity with `web/blueprints/tasks.py:_parse_acceptance_criteria` and `agents/task-create/update-task.sh`). Watchtower's parser was always correct — only the CLI surface drifted. Test coverage: 6/6 new + 10/10 existing regression. No Human ACs (the fix is structural + bats-verified; no rendering surface to taste-check).
**Evidence:**
- `lib/review.sh:121-167` — new anchored counter using bash `case` patterns (no SIGPIPE risk, no grep -q on substring)
- `tests/unit/emit_review_ac_counter.bats` — 6/6 PASS (title with `### Human`, prose with `### Human`, vanilla, fully-ticked, multi-AC, no-Human-section)
- `tests/unit/recommendation_gate_build_partial.bats` — 10/10 PASS (regression-clean for T-2421's emit_review gate)
- Live: `bin/fw task review T-2420` emits `Open: .../review/T-2420`; `/review/T-2420` renders `Human ACs: 0/1` correctly
- `.context/concerns.yaml` OBS-079 marked `fixed_in: T-2422`

## Decisions

### 2026-06-16 — bash case patterns vs regex grep

- **Chose:** Bash `case` patterns (`"## "*`, `"### Human"*`, `"- [ ]"*`) on `$line` for the heading and checkbox detection.
- **Why:** Faster (no fork to grep per line), no SIGPIPE risk under `set -eo pipefail` (L-387), exact prefix match semantics that mirror what the regex `^### Human` was trying to express. Bash glob `*` after `"### Human"` is what handles trailing whitespace or descriptive text on the heading line.
- **Rejected:** Keeping grep with `^` anchors — would still fork per line; the original bug was unanchored grep, not "grep without `^`" — both anchored grep and `case` patterns fix it. `case` is the cheaper of the two.

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

### 2026-06-16T14:39:49Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2422-fix-obs-079-emitreview-human-ac-counter-.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-6972e945
- **Timestamp:** 2026-06-16T14:44:26Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
