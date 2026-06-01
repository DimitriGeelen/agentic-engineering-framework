---
id: T-1873
name: "fix episodic generator YAML escape — extend T-1871 single-quote fix to outcomes/challenges/artifacts (L-392 class recursion)"
description: >
  fix episodic generator YAML escape — extend T-1871 single-quote fix to outcomes/challenges/artifacts (L-392 class recursion)

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [agents/context/lib/episodic.sh, tests/unit/episodic_yaml_decision_escape.bats, tools/episodic-corpus-check.py]
related_tasks: []
created: 2026-05-16T07:49:46Z
last_update: 2026-05-16T07:55:13Z
date_finished: 2026-05-16T07:55:13Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
---

# T-1873: fix episodic generator YAML escape — extend T-1871 single-quote fix to outcomes/challenges/artifacts (L-392 class recursion)

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] `agents/context/lib/episodic.sh` outcomes emission writes single-quoted YAML scalars matching the T-1871 pattern. Same L-392 class — AC text mined from source tasks contains backticks/backslashes; T-1871's own AC mentions `` `markdown2.markdown(f"\`\`\`{lang}...\`\`\`")` `` — that's what made T-1871.yaml unparseable at line 30 col 260.
- [x] `agents/context/lib/episodic.sh` challenges emission switches to single-quoted (commit messages can contain backticks too).
- [x] `agents/context/lib/episodic.sh` artifacts emission switches to single-quoted (uniform escape strategy across all emission sites).
- [x] `tests/unit/episodic_yaml_decision_escape.bats` extended with source-level invariants for outcomes + challenges + artifacts. 9/9 tests pass (was 6/6 before T-1873).
- [x] Regenerated `.context/episodic/T-1871.yaml`; `yaml.safe_load` succeeds.
- [x] Audited all `.context/episodic/*.yaml` — found 19 pre-existing parse failures (same class, latent since various dates). Mass-regenerated all 19 (T-1369, T-1415, T-1454, T-1527, T-1528, T-1530, T-1541, T-1543, T-1552, T-1553, T-1567, T-1579, T-1628, T-1629, T-1630, T-1676, T-1679, T-1747, T-1750). Final corpus: 1760 OK, 0 FAIL.
- [x] `bash -n agents/context/lib/episodic.sh` clean.

### Human
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
     Remove this section if all criteria are agent-verifiable.
     Each criterion MUST include Steps/Expected/If-not so the human can act without guessing.
     Optionally prefix with [RUBBER-STAMP] or [REVIEW] for prioritization.
     Example:
       - [ ] [REVIEW] Dashboard renders correctly
         **Steps:**
         1. Open https://example.com/dashboard in browser
         2. Verify all panels load within 2 seconds
         3. Check browser console for errors
         **Expected:** All panels visible, no console errors
         **If not:** Screenshot the broken panel and note the console error
-->

## Verification

bash -n agents/context/lib/episodic.sh
bats tests/unit/episodic_yaml_decision_escape.bats
python3 -c "import yaml; yaml.safe_load(open('.context/episodic/T-1871.yaml'))"
python3 tools/episodic-corpus-check.py

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

**Symptom:** Closing T-1871 (itself a fix for the decision-field instance of this class) emitted `.context/episodic/T-1871.yaml` that `yaml.safe_load` rejected at line 30 col 260 with `found character '\`' that cannot start any token`. The state machine completed (task moved to `completed/`), but the episodic artefact was unreadable. Audit of the full corpus revealed **19 pre-existing unparseable artefacts** going back to T-1369 — the bug was already endemic, just invisible without an audit.

**Root cause:** T-1871 fixed only the *decisions* emission site. Three other YAML-emitting sites in `agents/context/lib/episodic.sh` retained the same L-392 anti-pattern — `field: "$value"` with `sed 's/"/\\"/g'`:
- `outcomes:` (line 283-294) — AC text mined from the source task; contains markdown inline code with backticks.
- `challenges:` (line 296-311) — commit-message-derived text; also can contain backticks.
- `artifacts:` (line 343-354) — file paths; not vulnerable in practice but still inconsistent.

The script had **four sibling emission sites with the same anti-pattern**; T-1871 scoped narrowly to one of them.

**Why structurally allowed:**
1. The original L-392 capture (after T-1764 close) sized the bug as "decisions section" — true at the symptom but not at the root. The fix shipped with the same narrow scope.
2. No corpus-level parse audit existed. The first 18 victims accumulated silently between 2026-04 and 2026-05; only T-1764 (containing the exact L-392 origin case as its Chose value) made the error vocal enough at task-close time to be noticed.
3. The episodic generator's output was treated as fire-and-forget — nothing downstream re-parses every artefact, so corrupt ones just become invisible to `fw recall`/`fw timeline` without raising any alarm.

**Prevention:**
- **Structural:** All four emission sites now use single-quoted YAML scalars with the `'→''` escape — a uniform, known-narrow escape strategy. New emission sites added later will look at the existing three for pattern-match; deviating would be visible in diff.
- **Test:** `tests/unit/episodic_yaml_decision_escape.bats` extended from 6 → 9 cases (T-1873/outcomes, T-1873/challenges, T-1873/artifacts source-level invariants alongside the 4 hostile-input parse cases from T-1871).
- **Audit:** New `tools/episodic-corpus-check.py` walks `.context/episodic/*.yaml` and exits non-zero on any parse failure. Added to T-1873 Verification block — future regressions surface at task-close time, not when an operator notices a missing episodic three weeks later.
- **Mass-remediation:** All 19 pre-existing failures regenerated against the fixed substrate. Corpus state: 1760 OK / 0 FAIL.

**Why the fix didn't recurse on T-1873 itself:** This task's Decisions section is empty, and its AC/RCA text does not contain backticked code that the outcomes-emission would have to escape. The corpus audit confirms parse-clean.

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

### 2026-05-16T07:49:46Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1873-fix-episodic-generator-yaml-escape--exte.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.4)

- **Scan ID:** R-68b603e9
- **Timestamp:** 2026-05-16T07:55:21Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-05-16T07:55:13Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
