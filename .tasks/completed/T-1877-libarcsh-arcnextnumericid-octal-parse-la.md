---
id: T-1877
name: "lib/arc.sh _arc_next_numeric_id octal-parse latent bug fix (T-NEW-13)"
description: >
  _arc_next_numeric_id stores max as a leading-zero string (e.g. '008') after the POSIX test comparison; the trailing $((max+1)) arithmetic expansion then octal-errors on arc-008/009. Caught in T-1851 Evolution as cheap latent-bug fix. Currently at arc-005 — 3 creations from blowing up. Force base-10 with 10# prefix.

status: work-completed
workflow_type: build
owner: claude
horizon: null
tags: [arc, arc-grooming, lib-arc, bug, T-NEW-13]
components: [lib/arc.sh, tests/unit/arc_next_numeric_id_octal.bats]
related_tasks: [T-1687, T-1848, T-1851]
arc_id: arc-grooming
created: 2026-05-17T07:01:10Z
last_update: 2026-05-17T07:05:28Z
date_finished: 2026-05-17T07:05:28Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
---

# T-1877: lib/arc.sh _arc_next_numeric_id octal-parse latent bug fix (T-NEW-13)

## Context

`_arc_next_numeric_id` (lib/arc.sh:119-131) allocates the next sequential arc-NNN ID:

```bash
local max=0 cur
for f in "${ARCS_DIR}"/*.yaml; do
    cur=$(awk '...' "$f")           # cur = "001", "002", … "009" (string with leading zeros)
    if [ -n "$cur" ] && [ "$cur" -gt "$max" ] 2>/dev/null; then
        max="$cur"                  # max becomes the leading-zero string after iter 1
    fi
done
printf 'arc-%03d\n' $((max + 1))    # ← arithmetic expansion: BREAKS on max="008"/"009"
```

POSIX `[ ]` integer comparison handles leading-zero strings fine. Bash arithmetic expansion `$(( ))` does NOT — it interprets `008` and `009` as invalid octal and errors out. Reproduced:

```
$ bash -c '[ "008" -gt "7" ] && echo yes'      # yes
$ bash -c 'printf "%03d\n" $((008 + 1))'        # bash: 008: value too great for base
```

We're at arc-005 today. When arcs 008 and 009 exist in `.context/arcs/`, `_arc_next_numeric_id` will fail with a noisy stderr line AND emit a wrong/empty NNN — possibly allocating a duplicate. D-Immutability axiom (rule 2) is at risk: the next call may return an ID that collides with an existing one.

Fix: force base-10 with `10#` prefix on the arithmetic expansion. Single character touch on the printf line. Also normalize `cur` immediately after the awk extract so any future caller can rely on integer-form. Add bats coverage for the 008/009/099/100 edge cases.

## Acceptance Criteria

### Agent
- [x] `_arc_next_numeric_id` no longer fails when arc-008 or arc-009 exist in `.context/arcs/`. `cur` is base-10-forced via `$((10#$cur))` immediately after extract; arithmetic stays integer-form throughout the loop.
- [x] `cur` is normalized to integer form immediately after the awk extract so the loop-internal `max="$cur"` stores integer-form, not a leading-zero string.
- [x] `tests/unit/arc_next_numeric_id_octal.bats` reproduces the bug WITHOUT the fix (verified by `git stash`/run/pop: octal-boundary tests FAIL on unfixed code), and verifies the fix handles arc-001 through arc-099 contiguously (including 008, 009, 010, 099→100 transitions).
- [x] All new bats cases pass: `bats tests/unit/arc_next_numeric_id_octal.bats` exits 0. 8/8 pass with fix in place.
- [x] No regression on the existing arc creation flow: empty→001, 001..005→006, 007→008, gap-handling honors D-Immutability.



## Verification

bash -n lib/arc.sh
bats tests/unit/arc_next_numeric_id_octal.bats
# L-394: capture-then-grep — pin that 10# normalisation lives in _arc_next_numeric_id's body
out=$(awk '/^_arc_next_numeric_id\(\)/,/^\}/' lib/arc.sh 2>&1); echo "$out" | grep -q '10#'
# Sanity: existing arc allocation still works on real corpus (returns valid arc-NNN form)
out=$(_FW_TEST=1 bash -c "source lib/arc.sh; ARCS_DIR='$PWD/.context/arcs' _arc_next_numeric_id" 2>&1); echo "$out" | grep -qE '^arc-[0-9]{3}$'

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

## RCA

**Symptom:** `_arc_next_numeric_id` will emit a wrong/duplicate arc-NNN once arc-008 or arc-009 exists in `.context/arcs/`. The arithmetic expansion `$((max + 1))` octal-errors when `max` is a leading-zero string like "008" or "009", because bash arithmetic interprets `0NN` as octal.

**Root cause:** Two-mode integer handling in a single function. The loop comparison uses POSIX `[ -gt ]` which IS leading-zero tolerant, but the printf at the end uses bash arithmetic expansion `$(( ))` which is NOT. `max` was being stored as a string ("008") and then mixed into arithmetic context — silent type drift across one function.

**Why structurally allowed:** The `2>/dev/null` on the comparison originally suppressed an octal error from `[ -gt ]` that would only fire on some shell variants — and that same suppression hid the new failure path at the printf line. No test exercised arc-008/009 because the corpus only had 1-5 arcs at the time T-1848 shipped. The "latent bug, fix when cheap" note in T-1851 Evolution flagged it but didn't gate it.

**Prevention:**
- bats test reproduces the bug on the un-fixed code (regression guard).
- `10#` prefix on the arithmetic expansion forces decimal base 10 — local idiom that makes the integer semantics explicit at the point of use.
- Normalize `cur=$((10#$cur))` immediately after extract so any future caller can rely on integer-form `max`.


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

### 2026-05-17 — bug confirmed real via stash-revert demonstrator

- **What changed:** Before claiming the fix worked, I ran the new bats test against the un-fixed code (`git stash -k -- lib/arc.sh` to peel off the fix, then `bats --filter "octal boundary"`, then `git stash pop`). The 008 and 009 cases FAILED on un-fixed code (`status -ne 0`), then PASSED with the fix re-applied. This is the difference between "I wrote a test that passes" and "I wrote a regression guard". Documented because future readers of this commit may otherwise assume the test only proves the fix forward — it also pins the failure mode.
- **Plan impact:** No change. Reinforces the value of "scope root, not symptom" — the fix is one character (`10#`), the test is the durable artefact.
- **Triggered:** No new sub-task. This is the cluster tail for arc-grooming (after the 9 numbered slices + 3 migration-blindness siblings).

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

**Rationale:** Minimal-surface latent-bug fix. One character changes the runtime semantics (`10#` prefix on the awk-extracted value); the rest of the diff is the bats regression guard. The bug was demonstrably real (stash-revert test passes/fails as expected). No render surface, no API change, no migration, no schema touch. All-Agent ACs — no Human review needed.

**Evidence:**
- Diff scope: `lib/arc.sh` (`_arc_next_numeric_id` only, +5 lines), `tests/unit/arc_next_numeric_id_octal.bats` (new, 8 tests).
- Bats: 8/8 pass with fix in place; 008/009 cases FAIL on un-fixed code (stash-revert demonstrated).
- Reproduction at the shell: `bash -c 'printf "%03d\n" $((008 + 1))'` → `value too great for base` (un-fixed); now wrapped via `10#`.
- D-Immutability axiom preserved: `arc_next_numeric_id` continues to return `max+1` (never reuses gaps).

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

### 2026-05-17T07:01:10Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1877-libarcsh-arcnextnumericid-octal-parse-la.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-f17579ca
- **Timestamp:** 2026-06-02T15:00:12Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-17T07:05:28Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
