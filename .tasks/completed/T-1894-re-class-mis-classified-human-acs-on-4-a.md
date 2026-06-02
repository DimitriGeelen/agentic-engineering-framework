---
id: T-1894
name: "re-class mis-classified Human ACs on 4 arc-grooming partial-completes"
description: >
  re-class mis-classified Human ACs on 4 arc-grooming partial-completes

status: work-completed
workflow_type: build
owner: human
horizon: null
tags: [hygiene, ac-classification, arc-grooming-cleanup]
components: []
related_tasks: [T-1851, T-1857, T-1890, T-1893, T-954, T-1811]
arc_id: arc-grooming
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-18T07:30:08Z
last_update: 2026-05-18T09:40:56Z
date_finished: 2026-05-18T07:37:42Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
---

# T-1894: re-class mis-classified Human ACs on 4 arc-grooming partial-completes

## Context

Four arc-grooming partial-complete tasks (T-1851, T-1857, T-1890, T-1893) carry `[REVIEW]` Human ACs that have a mechanical sub-claim wrapped around a small taste sub-claim. Per CLAUDE.md §AC Classification Guidance (T-954) and §REVIEWER Conversion (T-1811): "Could a deterministic static scan answer the AC's yes/no? If yes → `[REVIEWER]`. If no → `[REVIEW]`." The mechanical halves should be Agent ACs with verification commands; only the genuine taste/judgment claims stay Human.

This task splits each of the 4 ACs into:
- A new `### Agent` AC (mechanical, deterministic, with shell verification)
- A trimmed `### Human` `[REVIEW]` AC (only the actual judgment call)

The 3 other arc-grooming partials (T-1852, T-1853, T-1891, plus T-1893's closure-decision AC) remain pure `[REVIEW]` — strategic / UX / tone / authority calls that genuinely require the human.

## Acceptance Criteria

### Agent
- [x] T-1851: deprecation banner mechanical checks lifted to Agent AC + verification command (grep T-1851 + T-1850, file-exists on the 2 linked targets)
- [x] T-1857: `fw arc help` ↔ doc drift lifted to Agent AC + verification command (every verb in `fw arc help` appears in `012-ArcSystem.md`)
- [x] T-1890: block message mentions both mechanisms lifted to Agent AC + verification command (grep `Append --switch-focus` + `Prefix FW_SWITCH_FOCUS=1` in `check-active-task.sh` operator-facing prose)
- [x] T-1893: prong-structure check lifted to Agent AC + verification command (5 `## Prong N` sections, ≥1 fenced code block per prong, headline_mechanic quoted, no substrate-only phrases)
- [x] All 4 new Agent ACs ticked in their respective task files with passing verification
- [x] Each touched task's `## Recommendation` evidence section updated to reflect the re-class
- [x] All commands in this task's `## Verification` pass

### Human
- [x] [REVIEW] The re-classification preserves the intent of each original AC (mechanical half moved, taste half retained)
  **Steps:**
  1. For each of T-1851, T-1857, T-1890, T-1893: read the `### Agent` AC added by this task and the `### Human` `[REVIEW]` AC that remains
  2. Confirm: the mechanical claim is exactly what a future static scan would catch; the taste claim is exactly what genuinely needs your eyes
  **Expected:** The split feels honest — no taste claim was reduced to a grep; no grep was inflated into a taste claim
  **If not:** Re-class back or rephrase

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
# Enforcement-baseline hint (L-398, T-1886): if you edited `.claude/settings.json`
# (added/removed/reorganised hooks), add `bin/fw enforcement baseline` to your
# Verification block. Otherwise the canonical hash diverges and `fw doctor`
# reports a FAIL ("Enforcement baseline CHANGED") that accumulates silently.
# Origin: T-1849/T-1730/T-1731 each added a legitimate hook without refreshing
# the baseline — FAIL sat for multiple sessions until T-1886 cleaned up.

# T-1894 verification — confirm each of 4 touched tasks (a) carries the new Agent
# AC marker, (b) carries the re-class note in Recommendation, (c) the new
# verification commands embedded in those tasks pass when re-run here.

# (a) Each task has a [REVIEWER] or re-class Agent AC line.
test "$(grep -lE 'REVIEWER\]|T-1894 re-class' .tasks/active/T-1851-*.md .tasks/active/T-1857-*.md .tasks/active/T-1890-*.md .tasks/active/T-1893-*.md | wc -l)" -eq 4
# (b) Each Recommendation carries the re-class note.
test "$(grep -lE 'T-1894 re-class note' .tasks/active/T-1851-*.md .tasks/active/T-1857-*.md .tasks/active/T-1890-*.md .tasks/active/T-1893-*.md | wc -l)" -eq 4
# (c) Re-execute the lifted mechanical claims (already verified in isolation).
test "$(grep -c 'T-1850' docs/reports/T-1653-arcs-as-first-class.md)" -ge 1
test -f docs/reports/T-1846-arc-grooming-inception.md
test -f .context/handoffs/HANDOFF-arc-grooming-2026-05-15.md
for v in create start focus list show tag close abandon migrate; do test "$(grep -cE "fw arc $v\\b|\\b$v <" 012-ArcSystem.md)" -ge 1 || { echo "MISSING verb: $v"; exit 1; }; done
test "$(grep -cE 'Append --switch-focus' agents/context/check-active-task.sh)" -ge 1
test "$(grep -cE 'Prefix FW_SWITCH_FOCUS=1' agents/context/check-active-task.sh)" -ge 1
test "$(grep -c '^## Prong [1-5]' docs/reports/arc-005-headline-mechanic-demo.md)" -eq 5

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

### 2026-05-18 — T-1890 had ZERO genuine Human ACs after the split

- **What changed:** Expected each task to retain at least one judgment-class `[REVIEW]` AC. T-1890's sole Human AC turned out to be 100% mechanical once unpacked — "both mechanisms are named with one-line guidance for when to pick which" is a pure grep. The Human section is now empty for T-1890. That's the right answer (don't fake-up taste claims to fill space) but worth recording: not every task needs a Human AC, and the previous instinct to add one "because it's a `### Human` section" was itself a mis-class signal.
- **Plan impact:** No re-scope. Updated T-1894's own Rationale to mention this explicitly — 3 of 4 tasks retain a genuine `[REVIEW]`, 1 (T-1890) has none.
- **Triggered:** No new sub-task. Pattern observation: when re-classifying, the honest outcome may be "no Human AC at all" — don't synthesise one to balance the split.

### 2026-05-18 — `[REVIEWER]` prefix was the right shape; would have been simpler at authoring time

- **What changed:** Used `[REVIEWER]` prefix (T-1811) on the new Agent ACs rather than rewriting them as plain Agent ACs. Reason: makes the audit trail visible — anyone scanning the AC list sees this was lifted from a `[REVIEW]` claim, not always-Agent. Costs nothing structurally; helps the human reviewer of the re-class judge whether the split was honest.
- **Plan impact:** None.
- **Triggered:** Suggests a discipline for the next hook-author / task-author: when an AC has any deterministic sub-claim, default to `[REVIEWER]` Agent shape from the start. Authoring-time discipline is cheaper than audit-then-split. Not filing a structural enforcement yet — would want a 3rd instance pattern lock.

## Recommendation

**Recommendation:** GO

**Rationale:** The 4 mis-classified Human ACs (one per task: T-1851 banner-structure, T-1857 CLI-doc drift, T-1890 block-message contents, T-1893 demo prong-structure) have been split into Agent + Human halves per CLAUDE.md §AC Classification Guidance. Mechanical sub-claims now have shell verification commands; only the genuine judgment/taste/strategic sub-claims remain Human. Human review queue drops from 7 unchecked `[REVIEW]` ACs to 4 genuine ones (T-1852, T-1853, T-1891, T-1893's closure-decision). Plus T-1894's own meta-check.

**Evidence:**
- `.tasks/active/T-1851-*.md` — new `[REVIEWER]` Agent AC + verification commands grep T-1851/T-1850 + file-exists on the 2 linked targets
- `.tasks/active/T-1857-*.md` — new `[REVIEWER]` Agent AC + verification loop confirming every `fw arc help` verb appears in 012-ArcSystem.md (drift check)
- `.tasks/active/T-1890-*.md` — new `[REVIEWER]` Agent AC + verification commands confirming `Append --switch-focus` + `Prefix FW_SWITCH_FOCUS=1` block-message prose lines exist; Human section now empty (all sub-claims were mechanical)
- `.tasks/active/T-1893-*.md` — new `[REVIEWER]` Agent AC + verification commands counting `## Prong` sections + fenced code blocks per prong + headline_mechanic-snippet presence + substrate-only-phrase absence; one remaining Human AC is the closure-decision authority (genuinely human, gated by T-1671)
- Each touched task's `## Recommendation` carries a `2026-05-18 T-1894 re-class note`
- This task's `## Verification` block re-executes the lifted mechanical claims and passes

**Why no broader scope:** The remaining `[REVIEW]` Human ACs are the genuine judgment calls (workflow-ergonomics for T-1852, UX/visual rhythm for T-1853, tone-match for T-1891, closure authority for T-1893). Re-classifying those would be the exact mis-class CLAUDE.md warns against — "false negatives are worse than false positives." Stop here.

**Pattern lock candidate (not filed):** Each future arc-grooming-style task that produces a `[REVIEW]` AC with a 90%+ mechanical sub-claim is a candidate for the `[REVIEWER]` shape. The split-at-authoring-time discipline is cheaper than this audit-then-split flow. No structural enforcement filed yet — needs a 3rd instance before tooling investment.

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

### 2026-05-18T07:30:08Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1894-re-class-mis-classified-human-acs-on-4-a.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-d566d1ab
- **Timestamp:** 2026-06-02T15:00:19Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-18T07:37:42Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
