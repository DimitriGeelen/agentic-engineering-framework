---
id: T-1897
name: "Widen T-1896 detector + re-class 5 block-message [REVIEW] ACs as [REVIEWER] (T-1878 C)"
description: >
  Widen reviewer pattern human-ac-mechanical-signal regex to include conformance-check dialect (names X / shows Y / points at Z / contains override flag / status:closed / row appended); re-class the 5 [REVIEW] ACs the wider detector should have caught: T-1730, T-1731, T-1762, T-1766, T-1893. Sibling to T-1895/T-1896 (T-1878 A+B); origin: 2026-05-18 audits of arc-grooming partial-completes found my T-1896 detector regex too narrow (twice — the 4 first, then T-1893 added after a user-led reviewer-agent sweep showed mech=0 on it despite being pure procedural-conformance).

status: captured
workflow_type: build
owner: agent
horizon: next
tags: [build, ac-routing, governance, reviewer, T-1878-C]
components: [lib/reviewer/static_scan.py, policy/anti-patterns.yaml]
related_tasks: [T-1878, T-1895, T-1896, T-1811, T-1730, T-1731, T-1762, T-1766, T-1893]
arc_id: arc-grooming
created: 2026-05-18T08:51:35Z
last_update: 2026-05-18T08:53:05Z
date_finished: null
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
---

# T-1897: Widen T-1896 detector + re-class 5 block-message [REVIEW] ACs as [REVIEWER] (T-1878 C)

## Context

T-1878's A+B intervention (T-1895/T-1896) shipped a structural catch for `[REVIEW]` Human ACs whose Expected reads as a deterministic shell check. The detector caught 2 historical hits on 1783 completed tasks (T-1116, T-1372) — good — but a 2026-05-18 audit of arc-grooming partial-completes found **4 currently mis-classed [REVIEW] ACs the detector should have flagged**: T-1730, T-1731, T-1762, T-1766. The detector regex (`_HUMAN_AC_MECHANICAL_RE`) only matches the **I/O-checking dialect** (grep / curl / exit-code / file contents / HTTP status / appended); it does not match the **conformance-checking dialect** (block message *names* X / *shows* Y / *points at* Z / *contains* the override flag). Both dialects are semantically grep-able — both should fire.

This task widens the regex AND re-classifies the 4 currently mis-classed ACs (T-1730/T-1731/T-1762/T-1766) to `[REVIEWER]` Agent ACs with `bin/fw reviewer T-XXX` in their `## Verification` blocks. T-1766 may need to be split (conformance portion → [REVIEWER]; "is the wording crisp?" residue → [REVIEW] kept).

Full reasoning: `docs/reports/T-1878-routing-default-bias.md` Phase 2 + the 2026-05-18 partial-completes audit in conversation log.

## Acceptance Criteria

### Agent
- [ ] `_HUMAN_AC_MECHANICAL_RE` in `lib/reviewer/static_scan.py` widened with conformance-check dialect: `\bnames?\s+(the\s+)?\w` / `\bshows?\s+(the\s+)?\w` / `\bpoints?\s+at\b` / `\bcontains?\s+the\s+\w+` / `\b(override|bypass)\s+(flag|env\s+var|mechanism)\b`. Keeps existing I/O dialect intact.
- [ ] Catalogue entry `policy/anti-patterns.yaml` `examples_positive` updated with one conformance-style example (e.g. "[REVIEW] block message names current focus and --switch-focus override") so the pattern's documented surface covers both dialects.
- [ ] Python unit tests `tests/unit/test_reviewer_human_ac_mechanical_signal.py` extended: ≥3 new positive cases for conformance dialect (names / shows / points at + override-flag). Negative cases stay clean (T-1851/T-1857/T-1893 still PASS).
- [ ] Bats test `tests/unit/reviewer_human_ac_mechanical_signal.bats` extended: add a conformance-style synthetic fixture (T-9899) that the widened detector catches; pin via positive bats case.
- [ ] Corpus regression: re-run `bin/fw reviewer audit` after the widening. New hits beyond the 2 historicals (T-1116/T-1372) are reported. Any genuine new mis-classes are either re-classed (preferred) or overridden with reason (if the AC is in a completed task).
- [ ] T-1730 [REVIEW] AC re-classed: move conformance portion to `### Agent` as `[REVIEWER]`; add `bin/fw reviewer T-1730 2>&1 | grep -q "Overall:.*PASS"` to `## Verification`. Retain a residual `[REVIEW]` only if a genuine taste judgment remains.
- [ ] T-1731 [REVIEW] AC re-classed (same pattern as T-1730 — block-message names current task + toggled checkbox text + override env var).
- [ ] T-1762 [REVIEW] AC re-classed (same pattern — gate refusal names missing deliverable + inception + bypass syntax).
- [ ] T-1766 [REVIEW] AC split: conformance portion → `### Agent` `[REVIEWER]` with reviewer Verification; residual taste ("crisp wording") stays as `[REVIEW]`.
- [ ] T-1893 [REVIEW] AC split: procedural-conformance portion (tick boxes / run `fw arc close` / verify `status: closed` + audit row appended) → `### Agent` `[REVIEWER]` with reviewer Verification + grep on `.context/audits/arc-close.jsonl`; residual *decision-quality* portion ("should this arc actually close?") → new `[REVIEW]` Human AC that asks the strategic question explicitly, not the closure mechanics.
- [ ] Each of the 5 re-classed tasks runs `bin/fw reviewer T-XXX` to PASS post-conversion, validating the widened detector + the re-class as a unit.
- [ ] `## Verification` block on this task passes.

### Human
- [ ] [REVIEW] Re-classed ACs preserve the spirit of the original — the [REVIEWER] Agent AC + Verification command genuinely covers what the original [REVIEW] was asking about, and the residual [REVIEW] (where kept, on T-1766) names only the truly taste portion
  **Steps:**
  1. Open each re-classed task (T-1730, T-1731, T-1762, T-1766) in Watchtower
  2. Read the original [REVIEW] text in the git diff vs the new [REVIEWER] AC + Verification command
  **Expected:** No conformance check is lost; the residual [REVIEW] on T-1766 reads as crisp-wording taste, not as smuggled mechanical
  **If not:** Note which AC fell on the wrong side; reopen with revised classification

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

### 2026-05-18T08:51:35Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1897-widen-t-1896-detector--re-class-4-block-.md
- **Context:** Initial task creation
